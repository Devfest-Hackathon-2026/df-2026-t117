// FCM のメッセージを作る。表示する文言はクライアント側の多言語データから選ぶので、
// サーバーはデータだけを送る（architecture.md 3.1）。
import type { BatchResponse, Message, MulticastMessage } from 'firebase-admin/messaging';
import type { AlertState } from './alert.js';

/** firebase-admin の Messaging のうち使う部分。 */
export interface MessagingLike {
  send(message: Message): Promise<string>;
  /** Web のクライアント（トークン）へ送る。1 回に 500 件まで。 */
  sendEachForMulticast(message: MulticastMessage): Promise<BatchResponse>;
}

/** 通知の有効期限。古い警報を後から届けない。 */
const TTL_SECONDS = 60 * 60;

/** FCM の data に入れる値（すべて文字列）。 */
export function alertData(state: AlertState): Record<string, string> {
  const data: Record<string, string> = {
    type: 'tsunami',
    alertId: state.alertId,
    eventId: state.eventId,
    serial: String(state.serial),
    infoType: state.infoType,
    jmaStatus: state.jmaStatus,
    kind: state.kind,
    level: state.level ?? 'none',
    change: state.change,
    issuedAt: state.issuedAt,
    areaId: state.areaId,
  };
  if (state.expectedHeight != null) data.expectedHeight = String(state.expectedHeight);
  if (state.maxHeight?.meters != null) data.heightMeters = String(state.maxHeight.meters);
  if (state.maxHeight?.over) data.heightOver = 'true';
  if (state.maxHeight?.label) data.heightLabel = state.maxHeight.label;
  if (state.arrivalTime) data.arrivalTime = state.arrivalTime;
  if (state.arrivalCondition) data.arrivalCondition = state.arrivalCondition;
  return data;
}

/** トピック送信とトークン送信で共通の部分（data と各プラットフォームの設定）。 */
function messageBody(state: AlertState): Omit<MulticastMessage, 'tokens' | 'fids'> {
  // 同じ警報（EventID）の通知はまとめる。続報は前の通知を置き換える。
  const collapseKey = state.alertId;
  return {
    data: alertData(state),
    android: {
      priority: 'high',
      collapseKey,
      ttl: TTL_SECONDS * 1000,
    },
    webpush: {
      headers: {
        Urgency: 'high',
        TTL: String(TTL_SECONDS),
        // Web Push の Topic ヘッダーは 32 文字以内の URL セーフな文字。EventID はこれを満たす。
        Topic: collapseKey.slice(0, 32),
      },
    },
    apns: {
      // データだけの通知は、APNs ではバックグラウンド通知（優先度 5）としてしか送れない。
      // iOS での表示は、本番のアプリで Critical Alerts を使う（D10）。
      headers: {
        'apns-push-type': 'background',
        'apns-priority': '5',
        'apns-collapse-id': collapseKey,
        'apns-expiration': String(Math.floor(Date.now() / 1000) + TTL_SECONDS),
      },
      payload: { aps: { contentAvailable: true } },
    },
  };
}

export function buildMessage(state: AlertState, topic: string): Message {
  return { topic, ...messageBody(state) };
}

/**
 * Web のクライアントへのメッセージ。Web の FCM SDK はトピックを直接購読できないので、
 * モックが Firestore の fcmTokens に書いたトークンへ、同じ内容を送る（architecture.md 10.1 H2）。
 */
export function buildMulticastMessage(state: AlertState, tokens: string[]): MulticastMessage {
  return { tokens, ...messageBody(state) };
}
