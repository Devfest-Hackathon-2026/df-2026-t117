// 電文 1 通の処理: 解析 → 送信済みの記録（D6）→ 状態の更新 → FCM。
import { buildAlertState, relevantItems, type AlertState } from './alert.js';
import type { Config } from './config.js';
import { JmaParseError, parseTsunamiReport, UnsupportedReportError, type TsunamiReport } from './jma.js';
import { log } from './log.js';
import { buildMessage, type MessagingLike } from './notify.js';
import { isFirestoreUnreachable, sentAlertKey, type AlertStore } from './store.js';
import { sendToWebTokens, skippedWebPush, type TokenStore, type WebPushResult } from './tokens.js';

export type IngestResult =
  /** 送った。 */
  | { result: 'sent'; key: string; messageId: string; state: AlertState; webPush: WebPushResult }
  /** Firestore に届かなかったので、記録なしで送った（D7。重複はアプリ側で消す）。 */
  | { result: 'sent-unrecorded'; key: string; messageId: string; state: AlertState; webPush: WebPushResult }
  /** 同じ電文をもう処理した。 */
  | { result: 'duplicate'; key: string }
  /** 別の処理が送っている途中。 */
  | { result: 'in-progress'; key: string }
  /** 同じ EventID のより新しい続報がすでにある。 */
  | { result: 'superseded'; key: string; latestSerial: number }
  /** 配信の対象外（別の電文・訓練や試験の扱い・対象外の予報区）。 */
  | { result: 'ignored'; reason: string }
  /** 電文が読めない。 */
  | { result: 'invalid'; reason: string }
  /** FCM への送信に失敗した（再送で送り直せる）。 */
  | { result: 'failed'; key: string; reason: string }
  /**
   * FCM には送ったが、送信後の記録（sent と notified）を書けなかった。
   * 送信元に再送させ、古くなった sending を取り直して送り直すときに両方を書く（二重はアプリが消す）。
   */
  | { result: 'sent-unconfirmed'; key: string; messageId: string; reason: string; webPush: WebPushResult };

export interface IngestDeps {
  config: Config;
  store: AlertStore;
  messaging: MessagingLike;
  /** Web のクライアントのトークン。ないときはトピックにだけ送る。 */
  tokens?: TokenStore;
  /** 現在時刻（fcmTokens の有効期限の判定。テストで差し替える） */
  now?: () => number;
}

function errorMessage(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

export async function ingest(xml: string, deps: IngestDeps): Promise<IngestResult> {
  const { config, store, messaging } = deps;

  let report: TsunamiReport;
  try {
    report = parseTsunamiReport(xml);
  } catch (e) {
    if (e instanceof UnsupportedReportError) return { result: 'ignored', reason: e.message };
    if (e instanceof JmaParseError) return { result: 'invalid', reason: e.message };
    throw e;
  }

  if (!config.allowedStatuses.includes(report.status)) {
    return { result: 'ignored', reason: `運用種別が対象外です: ${report.status}` };
  }
  if (report.infoType !== '取消' && relevantItems(report, config).length === 0) {
    return { result: 'ignored', reason: '対象の津波予報区が含まれていません' };
  }

  const key = sentAlertKey(report.eventId, report.serial, report.infoType);
  const ctx = { key, eventId: report.eventId, serial: report.serial, infoType: report.infoType };

  let claim;
  try {
    claim = await store.claim(key, {
      eventId: report.eventId,
      serial: report.serial,
      infoType: report.infoType,
    });
  } catch (e) {
    // D7: Firestore に届かない（UNAVAILABLE / DEADLINE_EXCEEDED）ときだけ、記録なしで送る。
    // 届かないより二重の方がよい。権限の不足などそれ以外のエラーでは送らずに失敗させる（5xx）。
    if (!isFirestoreUnreachable(e)) throw e;
    log('ERROR', 'Firestore に記録できないため、記録なしで送ります', { ...ctx, error: errorMessage(e) });
    const state = buildAlertState(report, config, null);
    if (!state) return { result: 'ignored', reason: '対象の津波予報区が含まれていません' };
    try {
      const messageId = await messaging.send(buildMessage(state, config.fcmTopic));
      // Firestore に届かないので fcmTokens も読めない。Web への送信は省き、トピックだけに送る
      return { result: 'sent-unrecorded', key, messageId, state, webPush: skippedWebPush('firestore-unreachable') };
    } catch (sendError) {
      log('ERROR', 'FCM への送信に失敗しました', { ...ctx, error: errorMessage(sendError) });
      return { result: 'failed', key, reason: errorMessage(sendError) };
    }
  }

  if (claim.status === 'duplicate') return { result: 'duplicate', key };
  if (claim.status === 'in-progress') return { result: 'in-progress', key };

  let update;
  try {
    update = await store.updateAlertState(report.eventId, report.serial, report.infoType, (notified) =>
      buildAlertState(report, config, notified),
    );
  } catch (e) {
    await store.markFailed(key, `alerts の更新に失敗: ${errorMessage(e)}`).catch(() => undefined);
    throw e;
  }

  if (update.status === 'stale') {
    await store.markNotSent(key, 'superseded', { latestSerial: update.latestSerial });
    return { result: 'superseded', key, latestSerial: update.latestSerial };
  }
  if (update.status === 'not-applicable') {
    await store.markNotSent(key, 'skipped');
    return { result: 'ignored', reason: '対象の津波予報区が含まれていません' };
  }

  const state = update.state;
  let messageId: string;
  try {
    messageId = await messaging.send(buildMessage(state, config.fcmTopic));
  } catch (e) {
    log('ERROR', 'FCM への送信に失敗しました', { ...ctx, error: errorMessage(e) });
    await store.markFailed(key, errorMessage(e)).catch(() => undefined);
    return { result: 'failed', key, reason: errorMessage(e) };
  }
  // Web のクライアント（トピックを購読できない）へも送る。fcmTokens の読み出しは TOKEN_READ_TIMEOUT_MS で諦める。
  // 失敗してもこの電文の結果は変えない。
  const webPush = await sendToWebTokens(state, { ...deps, maxTokens: config.maxWebTokens });

  try {
    // sent への更新と、change の基準（notified）の更新は 1 つのトランザクションで書く。
    await store.completeSend(key, messageId, state);
  } catch (e) {
    // 送信は済んでいるが、記録は sending のまま、基準も前のまま残る。送信元に再送させ（503）、
    // 古くなった sending を取り直して送り直すときに両方を書く（二重はアプリが警報 ID で消す）。
    log('ERROR', '送信後の記録を書けなかったため、再送を求めます', { ...ctx, messageId, error: errorMessage(e) });
    return { result: 'sent-unconfirmed', key, messageId, reason: errorMessage(e), webPush };
  }
  log('INFO', '警報を送りました', { ...ctx, kind: state.kind, change: state.change, messageId, webPush });
  return { result: 'sent', key, messageId, state, webPush };
}
