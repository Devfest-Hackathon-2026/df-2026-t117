import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { ingest } from '../src/ingest.js';
import {
  FirestoreTokenStore,
  isInvalidTokenError,
  MULTICAST_MAX,
  sendToWebTokens,
  type TokenFirestoreLike,
} from '../src/tokens.js';
import { buildAlertState } from '../src/alert.js';
import { parseTsunamiReport } from '../src/jma.js';
import { FakeMessaging, FakeTokenStore, fixture, harness } from './fakes.js';

const E1 = '20261108094000';

describe('Web のクライアント（fcmTokens）への送信', () => {
  it('トピックに加えて、fcmTokens の有効なトークンへ同じ data を送る', async () => {
    const h = harness();
    h.tokens.setTokens(['tok-a', 'tok-b']);
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent');
    assert.equal(h.fcm.sent.length, 1, 'トピック送信は 1 回');
    assert.equal(h.fcm.multicast.length, 1);
    const m = h.fcm.multicast[0]!;
    assert.deepEqual(m.tokens, ['tok-a', 'tok-b']);
    assert.deepEqual(m.data, h.fcm.data(0), 'トピックと同じ data');
    assert.equal((m as { topic?: string }).topic, undefined);
    assert.equal(m.webpush?.headers?.Urgency, 'high');
    assert.equal(m.webpush?.headers?.Topic, E1);
    if (r.result === 'sent') assert.deepEqual(r.webPush, { tokens: 2, success: 2, failure: 0, removed: 0 });
    assert.equal(h.tokens.lastListNow?.getTime(), h.clock.now, '有効期限は現在時刻で判定する');
  });

  it('有効期限（expireAt）の切れたトークンには送らない', async () => {
    const h = harness();
    h.tokens.docs = [
      { id: 'd1', token: 'fresh', expireAt: h.clock.now + 60_000 },
      { id: 'd2', token: 'expired', expireAt: h.clock.now - 1 },
    ];
    await ingest(fixture('01-warning-issued.xml'), h);
    assert.deepEqual(h.fcm.multicast[0]?.tokens, ['fresh']);
  });

  it('同じトークンの登録が複数あっても 1 回だけ送り、無効なら全部消す', async () => {
    const h = harness();
    h.tokens.docs = [
      { id: 'd1', token: 'same', expireAt: h.clock.now + 2_000 },
      { id: 'd2', token: 'same', expireAt: h.clock.now + 1_000 },
      { id: 'd3', token: 'other', expireAt: h.clock.now + 1_000 },
    ];
    h.fcm.tokenErrors.set('same', 'messaging/registration-token-not-registered');
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.deepEqual(h.fcm.multicast[0]?.tokens, ['same', 'other']);
    assert.deepEqual(h.tokens.removed.sort(), ['d1', 'd2']);
    if (r.result === 'sent') assert.deepEqual(r.webPush, { tokens: 2, success: 1, failure: 1, removed: 2 });
  });

  it('トークンがなければ multicast は呼ばない', async () => {
    const h = harness();
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent');
    assert.equal(h.fcm.multicast.length, 0);
  });

  it('形式の誤り（偽のトークン）と登録の切れたトークンは削除し、一時的なエラーのトークンは残す', async () => {
    const h = harness();
    h.tokens.setTokens(['ok', 'gone', 'bad', 'fake', 'busy', 'oops', 'quota']);
    h.fcm.tokenErrors.set('gone', 'messaging/registration-token-not-registered');
    h.fcm.tokenErrors.set('bad', 'messaging/invalid-registration-token');
    h.fcm.tokenErrors.set('fake', 'messaging/invalid-argument');
    h.fcm.tokenErrors.set('busy', 'messaging/server-unavailable');
    h.fcm.tokenErrors.set('oops', 'messaging/internal-error');
    h.fcm.tokenErrors.set('quota', 'messaging/quota-exceeded');
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent');
    assert.deepEqual(h.tokens.tokens, ['ok', 'busy', 'oops', 'quota']);
    if (r.result === 'sent') assert.deepEqual(r.webPush, { tokens: 7, success: 1, failure: 6, removed: 3 });
  });

  it('削除するエラーの判定', () => {
    for (const c of ['registration-token-not-registered', 'invalid-registration-token', 'invalid-argument']) {
      assert.equal(isInvalidTokenError(`messaging/${c}`), true, c);
    }
    for (const c of ['server-unavailable', 'internal-error', 'quota-exceeded', 'unavailable', 'third-party-auth-error']) {
      assert.equal(isInvalidTokenError(`messaging/${c}`), false, c);
    }
    assert.equal(isInvalidTokenError(undefined), false);
  });

  it('500 件ごとに分けて送る', async () => {
    const h = harness({ MAX_WEB_TOKENS: String(MULTICAST_MAX + 3) });
    h.tokens.setTokens(Array.from({ length: MULTICAST_MAX + 3 }, (_, i) => `t${i}`));
    await ingest(fixture('01-warning-issued.xml'), h);
    assert.deepEqual(
      h.fcm.multicast.map((m) => m.tokens.length),
      [MULTICAST_MAX, 3],
    );
  });

  it('読むのは新しい順に MAX_WEB_TOKENS 件（既定 200）。0 なら Web へは送らない', async () => {
    const def = harness();
    assert.equal(def.config.maxWebTokens, 200);
    def.tokens.setTokens(Array.from({ length: 250 }, (_, i) => `t${i}`));
    await ingest(fixture('01-warning-issued.xml'), def);
    assert.equal(def.fcm.multicast[0]?.tokens.length, 200);
    assert.equal(def.fcm.multicast[0]?.tokens[0], 't0');

    const h = harness({ MAX_WEB_TOKENS: '2' });
    h.tokens.setTokens(['t1', 't2', 't3']);
    await ingest(fixture('01-warning-issued.xml'), h);
    assert.deepEqual(h.fcm.multicast[0]?.tokens, ['t1', 't2']);

    const off = harness({ MAX_WEB_TOKENS: '0' });
    off.tokens.setTokens(['t1']);
    const r = await ingest(fixture('01-warning-issued.xml'), off);
    assert.equal(r.result, 'sent');
    assert.equal(off.fcm.multicast.length, 0);
  });

  it('トークンの読み出しや multicast が失敗しても、トピックに送れていれば sent のまま（再送させない）', async () => {
    const h = harness();
    h.tokens.failList = true;
    const r1 = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r1.result, 'sent');
    if (r1.result === 'sent') assert.match(r1.webPush.error ?? '', /UNAVAILABLE/);
    assert.equal(h.db.get(`sentAlerts/${E1}_1_発表`)?.state, 'sent');

    h.tokens.failList = false;
    h.tokens.setTokens(['t1']);
    h.fcm.failNextMulticast = 1;
    const r2 = await ingest(fixture('02-major-upgrade.xml'), h);
    assert.equal(r2.result, 'sent');
    if (r2.result === 'sent') {
      assert.equal(r2.webPush.failure, 1);
      assert.equal(r2.webPush.removed, 0);
    }
    assert.deepEqual(h.tokens.tokens, ['t1'], '呼び出しごとの失敗ではトークンを消さない');
  });

  it('fcmTokens の読み出しが時間内に終わらなければ、Web への送信だけ諦める', async () => {
    const state = buildAlertState(parseTsunamiReport(fixture('01-warning-issued.xml')), harness().config, null)!;
    const tokens = new FakeTokenStore();
    tokens.setTokens(['t1']);
    tokens.listDelayMs = null; // 返らない
    const messaging = new FakeMessaging();
    const started = Date.now();
    const r = await sendToWebTokens(state, { tokens, messaging, maxTokens: 10, readTimeoutMs: 50 });
    assert.ok(Date.now() - started < 1_000);
    assert.match(r.error ?? '', /50 ms/);
    assert.equal(messaging.multicast.length, 0);
  });

  it('トピック送信に失敗したら、Web へも送らない', async () => {
    const h = harness();
    h.tokens.setTokens(['t1']);
    h.fcm.failNext = 1;
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'failed');
    assert.equal(h.fcm.multicast.length, 0);
  });

  it('同じ電文の再送（duplicate）では Web へも送らない', async () => {
    const h = harness();
    h.tokens.setTokens(['t1']);
    await ingest(fixture('01-warning-issued.xml'), h);
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'duplicate');
    assert.equal(h.fcm.multicast.length, 1);
  });

  it('Firestore に届かず記録なしで送るときは、fcmTokens を読まずトピックだけに送る', async () => {
    const h = harness();
    h.tokens.setTokens(['t1']);
    h.db.failCode = 14;
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent-unrecorded');
    assert.equal(h.fcm.sent.length, 1);
    assert.equal(h.fcm.multicast.length, 0);
    assert.equal(h.tokens.lastListNow, null, 'fcmTokens を読まない');
    if (r.result === 'sent-unrecorded') assert.equal(r.webPush.skipped, 'firestore-unreachable');
  });
});

describe('FirestoreTokenStore', () => {
  it('expireAt > now を expireAt の新しい順に最大 max 件読み、remove でドキュメントを消す', async () => {
    const calls: string[] = [];
    const db: TokenFirestoreLike = {
      collection: (path) => ({
        where: (field, op, value) => ({
          orderBy: (f2, dir) => ({
            limit: (n) => ({
              get: async () => {
                calls.push(`list ${path} ${field}${op}${value.toISOString()} ${f2} ${dir} ${n}`);
                return {
                  docs: [
                    { id: 'a', data: () => ({ token: 'tok-a' }) },
                    { id: 'b', data: () => ({ token: 42 }) },
                  ],
                };
              },
            }),
          }),
        }),
        doc: (id) => ({
          delete: async () => {
            calls.push(`delete ${path}/${id}`);
          },
        }),
      }),
    };
    const store = new FirestoreTokenStore(db);
    const now = new Date('2026-11-08T00:00:00Z');
    assert.deepEqual(await store.list(10, now), [{ id: 'a', token: 'tok-a' }], 'token が文字列でないものは除く');
    assert.deepEqual(await store.list(0, now), []);
    await store.remove(['a']);
    assert.deepEqual(calls, [
      'list fcmTokens expireAt>2026-11-08T00:00:00.000Z expireAt desc 10',
      'delete fcmTokens/a',
    ]);
  });
});
