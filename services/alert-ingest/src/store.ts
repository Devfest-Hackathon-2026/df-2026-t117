// Firestore への記録（D6）。
// テストで差し替えられるよう、firebase-admin の Firestore のうち使う部分だけを型にしている。
import type { AlertState, PreviousState } from './alert.js';
import type { InfoType } from './jma.js';

export interface DocSnapshotLike {
  readonly exists: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface DocRefLike {
  create(data: Record<string, unknown>): Promise<unknown>;
  update(data: Record<string, unknown>): Promise<unknown>;
}

export interface TransactionLike {
  get(ref: DocRefLike): Promise<DocSnapshotLike>;
  set(ref: DocRefLike, data: Record<string, unknown>): unknown;
  update(ref: DocRefLike, data: Record<string, unknown>): unknown;
}

export interface FirestoreLike {
  collection(path: string): { doc(id: string): DocRefLike };
  runTransaction<T>(fn: (tx: TransactionLike) => Promise<T>): Promise<T>;
}

export const SENT_ALERTS = 'sentAlerts';
export const ALERTS = 'alerts';

/** gRPC の ALREADY_EXISTS。create() が同じキーの記録にぶつかったとき。 */
const ALREADY_EXISTS = 6;

export type SendState = 'sending' | 'sent' | 'failed' | 'superseded' | 'skipped';

export type ClaimResult =
  /** この処理が送る権利を得た。 */
  | { status: 'claimed'; attempt: number }
  /** もう送った（または古い続報なので送らない）。 */
  | { status: 'duplicate'; state: SendState }
  /** 別の処理が送っている途中。 */
  | { status: 'in-progress' };

export function sentAlertKey(eventId: string, serial: number, infoType: InfoType): string {
  return `${eventId}_${serial}_${infoType}`;
}

function isAlreadyExists(e: unknown): boolean {
  const code = (e as { code?: unknown } | null)?.code;
  return code === ALREADY_EXISTS || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

/**
 * Firestore に届かないことを示すエラーか（gRPC 14 UNAVAILABLE / 4 DEADLINE_EXCEEDED）。
 * D7 の「記録なしで送る」は、この場合だけにする。PERMISSION_DENIED や ABORTED などは送らずに失敗させる。
 */
export function isFirestoreUnreachable(e: unknown): boolean {
  const code = (e as { code?: unknown } | null)?.code;
  return (
    code === 14 ||
    code === 4 ||
    code === 'unavailable' ||
    code === 'deadline-exceeded' ||
    code === 'UNAVAILABLE' ||
    code === 'DEADLINE_EXCEEDED'
  );
}

export class AlertStore {
  constructor(
    private readonly db: FirestoreLike,
    private readonly opts: { staleSendingMs: number; sentTtlDays: number },
    private readonly now: () => number = Date.now,
  ) {}

  private sentRef(key: string) {
    return this.db.collection(SENT_ALERTS).doc(key);
  }

  private alertRef(eventId: string) {
    return this.db.collection(ALERTS).doc(eventId);
  }

  /**
   * sentAlerts/{key} を create() で作る。作れた処理だけが送る（D6）。
   * すでにあるときは、失敗した記録か sending のまま古くなった記録なら取り直す。
   * Firestore に届かないときの例外はそのまま投げる（呼び出し側で D7 の扱いにする）。
   */
  async claim(
    key: string,
    meta: { eventId: string; serial: number; infoType: InfoType },
  ): Promise<ClaimResult> {
    const now = this.now();
    try {
      await this.sentRef(key).create({
        ...meta,
        key,
        state: 'sending' satisfies SendState,
        attempts: 1,
        createdAt: new Date(now),
        updatedAtMs: now,
        expireAt: new Date(now + this.opts.sentTtlDays * 86_400_000),
      });
      return { status: 'claimed', attempt: 1 };
    } catch (e) {
      if (!isAlreadyExists(e)) throw e;
    }
    return this.reclaim(key);
  }

  private reclaim(key: string): Promise<ClaimResult> {
    const ref = this.sentRef(key);
    return this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data() ?? {};
      const state = data.state as SendState | undefined;
      const updatedAtMs = typeof data.updatedAtMs === 'number' ? data.updatedAtMs : 0;
      const attempts = typeof data.attempts === 'number' ? data.attempts : 1;
      const now = this.now();
      if (state === 'sent' || state === 'superseded' || state === 'skipped') return { status: 'duplicate', state };
      const stale = state === 'sending' && now - updatedAtMs >= this.opts.staleSendingMs;
      if (state === 'failed' || stale || !snap.exists) {
        tx.update(ref, {
          state: 'sending' satisfies SendState,
          attempts: attempts + 1,
          updatedAtMs: now,
        });
        return { status: 'claimed', attempt: attempts + 1 };
      }
      return { status: 'in-progress' };
    });
  }

  async markFailed(key: string, error: string): Promise<void> {
    await this.sentRef(key).update({
      state: 'failed' satisfies SendState,
      error: error.slice(0, 500),
      updatedAtMs: this.now(),
    });
  }

  /** 送らないと決めた記録（古い続報: superseded、対象外: skipped）。 */
  async markNotSent(
    key: string,
    state: Extract<SendState, 'superseded' | 'skipped'>,
    detail: Record<string, unknown> = {},
  ): Promise<void> {
    await this.sentRef(key).update({ ...detail, state, updatedAtMs: this.now() });
  }

  /**
   * alerts/{EventID} を新しい状態で置き換える。
   * build は「通知済みの基準」（notified。送信に成功した最新の状態）を受け取って新しい状態を返す
   * （対象外なら null）。change はこの基準と比べるので、送信に失敗した電文や送信中に止まった電文が
   * 再送されても、自分自身を前の状態として比べることはない。
   *
   * 届く順が入れ替わったときのため、電文の新しさを (Serial, 発表 < 訂正) で比べ、
   * 書かれている状態より古い電文は書かない（stale）。
   * 取消は順序によらず反映し、その EventID の最後の状態として固定する（以後の発表・訂正は stale）。
   * 取消のときも alerts.serial は最大値を保つ。
   */
  async updateAlertState(
    eventId: string,
    serial: number,
    infoType: InfoType,
    build: (notified: PreviousState | null) => AlertState | null,
  ): Promise<
    | { status: 'written'; state: AlertState }
    | { status: 'not-applicable' }
    | { status: 'stale'; latestSerial: number; reason: 'older' | 'cancelled' }
  > {
    const ref = this.alertRef(eventId);
    return this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const prev = snap.exists ? snap.data() : undefined;
      const latest = readOrder(prev);
      if (latest && infoType !== '取消') {
        if (latest.infoType === '取消') {
          return { status: 'stale', latestSerial: latest.serial, reason: 'cancelled' };
        }
        if (compareOrder({ serial, infoType }, latest) < 0) {
          return { status: 'stale', latestSerial: latest.serial, reason: 'older' };
        }
      }
      const notified = readNotified(prev?.notified);
      const state = build(notified);
      if (!state) return { status: 'not-applicable' };
      tx.set(ref, {
        ...state,
        // 取消が古い Serial で届いても、serial は下げない（後から来る古い電文を止めるため）
        serial: latest ? Math.max(latest.serial, state.serial) : state.serial,
        notified: prev?.notified ?? null,
        updatedAt: new Date(this.now()),
      });
      return { status: 'written', state };
    });
  }

  /**
   * FCM への送信に成功したあとの記録を、1 つのトランザクションでまとめて書く。
   * - sentAlerts/{key} を sent にする
   * - alerts/{EventID}.notified（change の基準）を、この状態にする
   *   すでにより新しい電文が通知済みなら変えない。取消は常に反映する
   * 片方だけが書かれて、基準が古いまま残ることを防ぐ。
   */
  async completeSend(key: string, messageId: string, state: AlertState): Promise<void> {
    const sentRef = this.sentRef(key);
    const alertRef = this.alertRef(state.eventId);
    await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(alertRef);
      const current = readNotified(snap.data()?.notified);
      const now = this.now();
      tx.update(sentRef, {
        state: 'sent' satisfies SendState,
        messageId,
        updatedAtMs: now,
        sentAt: new Date(now),
      });
      const newer =
        state.infoType === '取消' || !current || compareOrder(state, current) >= 0;
      if (!newer) return;
      const notified: NotifiedRecord = {
        serial: state.serial,
        infoType: state.infoType,
        kind: state.kind,
        level: state.level,
        maxHeight: state.maxHeight,
      };
      if (snap.exists) tx.update(alertRef, { notified });
      else tx.set(alertRef, { notified });
    });
  }
}

type NotifiedRecord = PreviousState & { infoType: InfoType };

const INFO_TYPE_ORDER: Record<InfoType, number> = { 発表: 0, 訂正: 1, 取消: 2 };

/** 電文の新しさを比べる。Serial が同じなら、訂正は発表より新しい。 */
export function compareOrder(
  a: { serial: number; infoType: InfoType },
  b: { serial: number; infoType: InfoType },
): number {
  if (a.serial !== b.serial) return a.serial - b.serial;
  return INFO_TYPE_ORDER[a.infoType] - INFO_TYPE_ORDER[b.infoType];
}

function isInfoType(v: unknown): v is InfoType {
  return v === '発表' || v === '訂正' || v === '取消';
}

function readOrder(v: Record<string, unknown> | undefined): { serial: number; infoType: InfoType } | null {
  if (!v || typeof v.serial !== 'number') return null;
  return { serial: v.serial, infoType: isInfoType(v.infoType) ? v.infoType : '発表' };
}

function readNotified(v: unknown): NotifiedRecord | null {
  if (typeof v !== 'object' || v === null) return null;
  const n = v as Partial<NotifiedRecord>;
  if (typeof n.serial !== 'number') return null;
  return {
    serial: n.serial,
    infoType: isInfoType(n.infoType) ? n.infoType : '発表',
    kind: n.kind ?? 'cleared',
    level: n.level ?? null,
    maxHeight: n.maxHeight ?? null,
  };
}
