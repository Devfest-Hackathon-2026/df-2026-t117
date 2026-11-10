// Firestore と FCM の代わり（テスト用）。使う操作だけを、本物と同じ意味で再現する。
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { BatchResponse, Message, MulticastMessage } from 'firebase-admin/messaging';
import { loadConfig, type Config } from '../src/config.js';
import type { IngestDeps } from '../src/ingest.js';
import { setLogSilent } from '../src/log.js';
import type { MessagingLike } from '../src/notify.js';
import {
  AlertStore,
  type DocRefLike,
  type DocSnapshotLike,
  type FirestoreLike,
  type TransactionLike,
} from '../src/store.js';
import type { TokenDoc, TokenStore } from '../src/tokens.js';

setLogSilent(true);

const FIXTURES = join(dirname(fileURLToPath(import.meta.url)), 'fixtures');

export function fixture(name: string): string {
  return readFileSync(join(FIXTURES, name), 'utf8');
}

type Data = Record<string, unknown>;

class FakeDocRef implements DocRefLike {
  constructor(
    private readonly db: FakeFirestore,
    readonly path: string,
  ) {}

  async create(data: Data): Promise<void> {
    await this.db.tick();
    this.db.maybeFail();
    if (this.db.docs.has(this.path)) {
      // 本物の create() は同じ ID の記録があると ALREADY_EXISTS（gRPC 6）で失敗する。
      throw Object.assign(new Error('6 ALREADY_EXISTS: Document already exists'), { code: 6 });
    }
    this.db.docs.set(this.path, structuredClone(data));
  }

  async update(data: Data): Promise<void> {
    await this.db.tick();
    this.db.maybeFail();
    const cur = this.db.docs.get(this.path);
    if (!cur) throw Object.assign(new Error('5 NOT_FOUND'), { code: 5 });
    this.db.docs.set(this.path, { ...cur, ...structuredClone(data) });
  }
}

export class FakeFirestore implements FirestoreLike {
  readonly docs = new Map<string, Data>();
  /** 設定すると、すべての操作がこの gRPC コードで失敗する（14 UNAVAILABLE、7 PERMISSION_DENIED など）。 */
  failCode: number | null = null;
  /**
   * トランザクションの書き込みのパスを受け取り、true を返すとそのトランザクションを失敗させる
   * （書き込みは 1 つも反映しない）。
   */
  failCommitWhen: ((paths: string[]) => boolean) | null = null;
  private queue: Promise<unknown> = Promise.resolve();

  collection(path: string) {
    return { doc: (id: string) => new FakeDocRef(this, `${path}/${id}`) };
  }

  get(path: string): Data | undefined {
    return this.docs.get(path);
  }

  /** 非同期の境目を作り、並行する処理が入れ替わるようにする。 */
  async tick(): Promise<void> {
    await new Promise((r) => setImmediate(r));
  }

  maybeFail(): void {
    if (this.failCode !== null) {
      throw Object.assign(new Error(`${this.failCode} injected failure`), { code: this.failCode });
    }
  }

  /** トランザクションは 1 つずつ順に実行する（本物の直列化と同じ結果になる）。 */
  runTransaction<T>(fn: (tx: TransactionLike) => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => {
      await this.tick();
      this.maybeFail();
      const writes: { path: string; apply: () => void }[] = [];
      const tx: TransactionLike = {
        get: async (ref) => {
          const path = (ref as FakeDocRef).path;
          const d = this.docs.get(path);
          const snap: DocSnapshotLike = {
            exists: d !== undefined,
            data: () => (d === undefined ? undefined : structuredClone(d)),
          };
          return snap;
        },
        set: (ref, data) => {
          const path = (ref as FakeDocRef).path;
          writes.push({ path, apply: () => this.docs.set(path, structuredClone(data)) });
        },
        update: (ref, data) => {
          const path = (ref as FakeDocRef).path;
          writes.push({
            path,
            apply: () => {
              // 本物と同じく、ない記録の update は失敗する（ここでは確認だけ先に行う）
              this.docs.set(path, { ...this.docs.get(path), ...structuredClone(data) });
            },
          });
          if (!this.docs.has(path)) throw Object.assign(new Error('5 NOT_FOUND'), { code: 5 });
        },
      };
      const result = await fn(tx);
      if (this.failCommitWhen?.(writes.map((w) => w.path))) {
        throw Object.assign(new Error('10 ABORTED: injected commit failure'), { code: 10 });
      }
      for (const w of writes) w.apply();
      return result;
    };
    const p = this.queue.then(run, run);
    this.queue = p.catch(() => undefined);
    return p;
  }
}

export class FakeMessaging implements MessagingLike {
  readonly sent: Message[] = [];
  /** 次の n 回の送信を失敗させる。 */
  failNext = 0;

  async send(message: Message): Promise<string> {
    await new Promise((r) => setImmediate(r));
    if (this.failNext > 0) {
      this.failNext--;
      throw new Error('messaging/internal-error');
    }
    this.sent.push(message);
    return `projects/test/messages/${this.sent.length}`;
  }

  readonly multicast: MulticastMessage[] = [];
  /** トークンごとの送信エラーのコード（ないトークンは成功）。 */
  tokenErrors = new Map<string, string>();
  /** 次の n 回の multicast を、呼び出しごと失敗させる。 */
  failNextMulticast = 0;

  async sendEachForMulticast(message: MulticastMessage): Promise<BatchResponse> {
    await new Promise((r) => setImmediate(r));
    if (this.failNextMulticast > 0) {
      this.failNextMulticast--;
      throw new Error('messaging/internal-error');
    }
    this.multicast.push(message);
    const responses = message.tokens.map((t, i) => {
      const code = this.tokenErrors.get(t);
      return code
        ? { success: false, error: { code, message: code, toJSON: () => ({}) } }
        : { success: true, messageId: `projects/test/messages/m${this.multicast.length}-${i}` };
    });
    const successCount = responses.filter((r) => r.success).length;
    return { responses, successCount, failureCount: responses.length - successCount } as BatchResponse;
  }

  /** 送ったメッセージの data。 */
  data(i: number): Record<string, string> {
    const m = this.sent[i];
    if (!m) throw new Error(`message ${i} がありません`);
    return m.data ?? {};
  }
}

export class FakeTokenStore implements TokenStore {
  /** expireAt の新しい順に並べておく */
  docs: { id: string; token: string; expireAt: number }[] = [];
  failList = false;
  /** list が返るまでの時間（タイムアウトの確認用）。null なら返らない */
  listDelayMs: number | null = 0;
  readonly removed: string[] = [];
  lastListNow: Date | null = null;

  /** expireAt が今から 1 日後のトークンを、新しい順に並べる。 */
  setTokens(tokens: string[], expireAt = Date.parse('2026-11-09T00:00:00Z')): void {
    this.docs = tokens.map((token, i) => ({ id: `doc-${token}-${i}`, token, expireAt }));
  }

  get tokens(): string[] {
    return this.docs.map((d) => d.token);
  }

  async list(max: number, now: Date): Promise<TokenDoc[]> {
    this.lastListNow = now;
    if (this.listDelayMs === null) return new Promise(() => undefined);
    if (this.listDelayMs > 0) await new Promise((r) => setTimeout(r, this.listDelayMs!));
    if (this.failList) throw Object.assign(new Error('14 UNAVAILABLE'), { code: 14 });
    return this.docs
      .filter((d) => d.expireAt > now.getTime())
      .slice(0, max)
      .map(({ id, token }) => ({ id, token }));
  }

  async remove(ids: string[]): Promise<void> {
    this.removed.push(...ids);
    this.docs = this.docs.filter((d) => !ids.includes(d.id));
  }
}

export interface Harness extends IngestDeps {
  db: FakeFirestore;
  fcm: FakeMessaging;
  tokens: FakeTokenStore;
  clock: { now: number };
}

export function harness(env: Record<string, string> = {}): Harness {
  const config: Config = loadConfig({ DEMO_AREA_OVERRIDE: 'true', ...env });
  const db = new FakeFirestore();
  const fcm = new FakeMessaging();
  const clock = { now: Date.parse('2026-11-08T00:42:05Z') };
  const store = new AlertStore(db, config, () => clock.now);
  const tokens = new FakeTokenStore();
  return { config, store, messaging: fcm, db, fcm, tokens, clock, now: () => clock.now };
}
