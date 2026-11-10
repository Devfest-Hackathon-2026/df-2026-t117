import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { after, before, describe, it } from 'node:test';
import { createApp } from '../src/server.js';
import { fixture, harness } from './fakes.js';

describe('HTTP', () => {
  const h = harness({ MAX_BODY_BYTES: '200000' });
  const server = createApp(h);
  let base = '';

  before(async () => {
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });
  after(() => new Promise<void>((resolve) => server.close(() => resolve())));

  const post = (body: string) =>
    fetch(`${base}/ingest`, {
      method: 'POST',
      headers: { 'content-type': 'application/xml' },
      body,
    });

  it('POST /ingest で電文を受け取り、配信の結果を返す', async () => {
    const res = await post(fixture('01-warning-issued.xml'));
    assert.equal(res.status, 200);
    const body = (await res.json()) as Record<string, unknown>;
    assert.equal(body.result, 'sent');
    assert.equal(body.kind, 'tsunami-warning');
    assert.equal(body.change, 'new');
  });

  it('同じ電文の再送は 200 duplicate', async () => {
    const res = await post(fixture('01-warning-issued.xml'));
    assert.equal(res.status, 200);
    assert.equal(((await res.json()) as Record<string, unknown>).result, 'duplicate');
    assert.equal(h.fcm.sent.length, 1);
  });

  it('別の処理が送っている途中なら 503 と Retry-After を返す（送信元に再送させる）', async () => {
    // 別の処理が sentAlerts を作った直後に落ちた状態
    await h.store.claim('20261108094000_2_発表', { eventId: '20261108094000', serial: 2, infoType: '発表' });
    const res = await post(fixture('02-major-upgrade.xml'));
    assert.equal(res.status, 503);
    assert.equal(res.headers.get('retry-after'), String(h.config.staleSendingMs / 1000));
    assert.equal(((await res.json()) as Record<string, unknown>).result, 'in-progress');
    assert.equal(h.fcm.sent.length, 1);
    // Retry-After のあとに再送すれば送れる
    h.clock.now += h.config.staleSendingMs;
    assert.equal((await post(fixture('02-major-upgrade.xml'))).status, 200);
    assert.equal(h.fcm.sent.length, 2);
  });

  it('送信後の記録を書けなかったら 503 と Retry-After を返し、再送で記録と基準をそろえる', async () => {
    const xml = fixture('03-height-raised.xml'); // Serial 3
    const key = '20261108094000_3_発表';
    h.db.failCommitWhen = (paths) => paths.includes(`sentAlerts/${key}`);
    const res = await post(xml);
    assert.equal(res.status, 503);
    assert.equal(res.headers.get('retry-after'), String(h.config.staleSendingMs / 1000));
    assert.equal(((await res.json()) as Record<string, unknown>).result, 'sent-unconfirmed');
    assert.equal(h.db.get(`sentAlerts/${key}`)?.state, 'sending');
    assert.notEqual((h.db.get('alerts/20261108094000')?.notified as { serial: number }).serial, 3);
    h.db.failCommitWhen = null;

    // Retry-After のあとの再送で送り直し、記録と基準の両方が書かれる
    h.clock.now += h.config.staleSendingMs;
    const again = await post(xml);
    assert.equal(again.status, 200);
    assert.equal(h.db.get(`sentAlerts/${key}`)?.state, 'sent');
    assert.equal((h.db.get('alerts/20261108094000')?.notified as { serial: number }).serial, 3);
  });

  it('読めない電文は 400', async () => {
    const res = await post('<oops');
    assert.equal(res.status, 400);
  });

  it('大きすぎる本文は 413', async () => {
    const res = await post('x'.repeat(300_000));
    assert.equal(res.status, 413);
  });

  it('GET /ingest は 405、その他のパスは 404、/healthz は 200', async () => {
    assert.equal((await fetch(`${base}/ingest`)).status, 405);
    assert.equal((await fetch(`${base}/nope`)).status, 404);
    assert.equal((await fetch(`${base}/healthz`)).status, 200);
  });
});
