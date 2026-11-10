// Web のクライアントの FCM トークン（fcmTokens/{自動 ID}）と、そこへの送信。
// Web の FCM SDK はトピックを直接購読できない（購読はサーバーの API でしかできない）。
// そのため、モックが通知の許可を得たときにトークンを Firestore に書き、サーバーがトピック送信に加えて
// 有効期限内のトークンへ sendEachForMulticast で送る（architecture.md 10.4）。
//
// fcmTokens は認証なしで誰でも作れるので、偽のトークンで本物が押し出されないよう次のようにしている。
// - 登録は 2 日以内に切れる（expireAt。ルールで上限を検査し、TTL で消す）。モックは開くたびに登録し直す
// - 読むのは expireAt が未来のものだけ、新しい順に maxTokens 件。同じトークンは 1 回だけ送る
// - 形式の誤り（偽のトークン）や登録の切れたトークンは、送信の結果を見て削除する
import type { AlertState } from './alert.js';
import { log } from './log.js';
import { buildMulticastMessage, type MessagingLike } from './notify.js';

export const FCM_TOKENS = 'fcmTokens';

/** sendEachForMulticast の 1 回あたりの上限。 */
export const MULTICAST_MAX = 500;

/** fcmTokens の読み出しを待つ上限。超えたら Web への送信だけ諦める。 */
export const TOKEN_READ_TIMEOUT_MS = 3_000;

export interface TokenDoc {
  /** ドキュメント ID（削除に使う） */
  id: string;
  token: string;
}

/** 送り先のトークンの一覧と、無効になったトークンの削除。 */
export interface TokenStore {
  /** expireAt が now より後のものを、expireAt の新しい順に最大 max 件。 */
  list(max: number, now: Date): Promise<TokenDoc[]>;
  /** ドキュメント ID で消す。 */
  remove(ids: string[]): Promise<void>;
}

/** firebase-admin の Firestore のうち、TokenStore が使う部分。 */
export interface TokenFirestoreLike {
  collection(path: string): {
    where(field: string, op: '>', value: Date): {
      orderBy(field: string, direction: 'desc'): {
        limit(n: number): { get(): Promise<{ docs: { id: string; data(): Record<string, unknown> }[] }> };
      };
    };
    doc(id: string): { delete(): Promise<unknown> };
  };
}

export class FirestoreTokenStore implements TokenStore {
  constructor(private readonly db: TokenFirestoreLike) {}

  async list(max: number, now: Date): Promise<TokenDoc[]> {
    if (max <= 0) return [];
    // 範囲の条件と並べ替えが同じフィールドなので、単一フィールドのインデックスだけで済む
    const snap = await this.db
      .collection(FCM_TOKENS)
      .where('expireAt', '>', now)
      .orderBy('expireAt', 'desc')
      .limit(max)
      .get();
    const out: TokenDoc[] = [];
    for (const d of snap.docs) {
      const token = d.data().token;
      if (typeof token === 'string' && token !== '') out.push({ id: d.id, token });
    }
    return out;
  }

  async remove(ids: string[]): Promise<void> {
    await Promise.all(ids.map((id) => this.db.collection(FCM_TOKENS).doc(id).delete()));
  }
}

/**
 * 送信先から外す（削除する）エラーか。
 * - registration-token-not-registered / invalid-registration-token: 登録が切れた・無効
 * - invalid-argument: トークンの形式の誤り（偽のトークン）。メッセージ本体はトピックと同じでテスト済みなので、
 *   トークンごとの invalid-argument はトークンの問題として扱う
 * unavailable・internal・quota-exceeded などの一時的なエラーでは消さない。
 */
export function isInvalidTokenError(code: string | undefined): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}

export interface WebPushResult {
  /** 送り先のトークンの数（重複を除く） */
  tokens: number;
  success: number;
  failure: number;
  /** 無効になったので削除したドキュメントの数 */
  removed: number;
  /** 送らなかった理由（Firestore に届かない経路など） */
  skipped?: string;
  /** トークンの読み出しや送信そのものが失敗したときの理由 */
  error?: string;
}

function errorMessage(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`fcmTokens の読み出しが ${ms} ms で終わりませんでした`)), ms);
  });
  return Promise.race([p, timeout]).finally(() => clearTimeout(timer));
}

/** Web へ送らなかったときの結果。 */
export function skippedWebPush(reason: string): WebPushResult {
  return { tokens: 0, success: 0, failure: 0, removed: 0, skipped: reason };
}

/**
 * fcmTokens の有効なトークン（新しい順に最大 maxTokens 件）へ送る。失敗しても例外は投げない。
 * トピック送信がこの電文の送信の成否で、こちらは Web 向けの追加の経路（モックの状態は Firestore の購読で更新される）。
 * トピック送信のあとに呼ぶので、ここで失敗しても電文の再送は求めない（再送するとトピックに二重に送るため）。
 */
export async function sendToWebTokens(
  state: AlertState,
  deps: {
    tokens?: TokenStore;
    messaging: MessagingLike;
    maxTokens: number;
    now?: () => number;
    readTimeoutMs?: number;
  },
): Promise<WebPushResult> {
  const result: WebPushResult = { tokens: 0, success: 0, failure: 0, removed: 0 };
  if (!deps.tokens || deps.maxTokens <= 0) return result;
  let docs: TokenDoc[];
  try {
    const now = new Date((deps.now ?? Date.now)());
    docs = await withTimeout(deps.tokens.list(deps.maxTokens, now), deps.readTimeoutMs ?? TOKEN_READ_TIMEOUT_MS);
  } catch (e) {
    log('ERROR', 'fcmTokens を読めませんでした（Web への送信を省きます）', { error: errorMessage(e) });
    return { ...result, error: errorMessage(e) };
  }
  // 同じトークンが何度も登録されている（開くたびに登録し直す）ので、トークンごとにまとめる
  const idsByToken = new Map<string, string[]>();
  for (const d of docs) idsByToken.set(d.token, [...(idsByToken.get(d.token) ?? []), d.id]);
  const tokens = [...idsByToken.keys()];
  result.tokens = tokens.length;
  const invalidIds: string[] = [];
  for (let i = 0; i < tokens.length; i += MULTICAST_MAX) {
    const chunk = tokens.slice(i, i + MULTICAST_MAX);
    try {
      const res = await deps.messaging.sendEachForMulticast(buildMulticastMessage(state, chunk));
      result.success += res.successCount;
      result.failure += res.failureCount;
      res.responses.forEach((r, j) => {
        const token = chunk[j];
        if (!r.success && token !== undefined && isInvalidTokenError(r.error?.code)) {
          invalidIds.push(...(idsByToken.get(token) ?? []));
        }
      });
    } catch (e) {
      result.failure += chunk.length;
      result.error = errorMessage(e);
      log('ERROR', 'Web のトークンへの送信に失敗しました', { error: errorMessage(e), tokens: chunk.length });
    }
  }
  if (invalidIds.length > 0) {
    try {
      await deps.tokens.remove(invalidIds);
      result.removed = invalidIds.length;
    } catch (e) {
      log('WARNING', '無効なトークンを削除できませんでした', { error: errorMessage(e), docs: invalidIds.length });
    }
  }
  return result;
}
