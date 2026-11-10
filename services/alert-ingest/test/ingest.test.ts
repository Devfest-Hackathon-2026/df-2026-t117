import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildAlertState } from '../src/alert.js';
import { ingest } from '../src/ingest.js';
import { parseTsunamiReport } from '../src/jma.js';
import { fixture, harness } from './fakes.js';

const E1 = '20261108094000';
const E2 = '20261108120000';

describe('ingest: 一連の続報', () => {
  it('発表 → 格上げ → 高さの引き上げ → 格下げ → 解除 を順に配信する', async () => {
    const h = harness();
    const steps = [
      ['01-warning-issued.xml', 'tsunami-warning', 'warning', 'new'],
      ['02-major-upgrade.xml', 'major-tsunami-warning', 'emergency', 'upgrade'],
      ['03-height-raised.xml', 'major-tsunami-warning', 'emergency', 'height-up'],
      ['04-downgrade-advisory.xml', 'tsunami-advisory', 'advisory', 'downgrade'],
      ['05-cleared.xml', 'cleared', 'none', 'cleared'],
    ] as const;

    for (const [i, [file, kind, level, change]] of steps.entries()) {
      const r = await ingest(fixture(file), h);
      assert.equal(r.result, 'sent', file);
      const data = h.fcm.data(i);
      assert.equal(data.kind, kind, file);
      assert.equal(data.level, level, file);
      assert.equal(data.change, change, file);
      assert.equal(data.serial, String(i + 1), file);
      assert.equal(data.alertId, E1);
      assert.equal(data.areaId, 'minato-bay');
      assert.equal(data.jmaStatus, '訓練');

      const alert = h.db.get(`alerts/${E1}`);
      assert.equal(alert?.kind, kind, file);
      assert.equal(alert?.change, change, file);
      assert.equal(alert?.serial, i + 1, file);
      const sent = h.db.get(`sentAlerts/${E1}_${i + 1}_発表`);
      assert.equal(sent?.state, 'sent', file);
    }
    assert.equal(h.fcm.sent.length, 5);

    // 各段階の高さ・到達時刻
    assert.equal(h.fcm.data(0).heightMeters, '3');
    assert.equal(h.fcm.data(0).arrivalTime, '2026-11-08T10:10:00+09:00');
    assert.equal(h.fcm.data(1).heightMeters, '5');
    assert.equal(h.fcm.data(2).heightMeters, '10');
    assert.equal(h.fcm.data(2).heightOver, 'true');
    assert.equal(h.fcm.data(2).arrivalCondition, 'ただちに津波来襲と予測');
    assert.equal(h.fcm.data(3).arrivalCondition, '第１波の到達を確認');
    assert.equal(h.fcm.data(4).heightMeters, undefined);

    const last = h.db.get(`alerts/${E1}`);
    assert.equal(last?.level, null);
    assert.equal(last?.previousKind, 'tsunami-advisory');
    assert.equal(last?.issuedAt, '2026-11-08T17:00:00+09:00');
  });

  it('FCM のメッセージは、トピック・優先度高・警報 ID の collapse key で、データだけを送る', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    const m = h.fcm.sent[0] as Record<string, any>;
    assert.equal(m.topic, 'demo-minato-bay');
    assert.equal(m.notification, undefined, '文言はクライアントで選ぶので notification は入れない');
    assert.equal(m.android.priority, 'high');
    assert.equal(m.android.collapseKey, E1);
    assert.equal(m.webpush.headers.Urgency, 'high');
    assert.equal(m.apns.headers['apns-collapse-id'], E1);
    for (const v of Object.values(m.data as Record<string, unknown>)) assert.equal(typeof v, 'string');
    assert.equal(m.data.issuedAt, '2026-11-08T09:42:00+09:00');
  });

  it('区分外の高さは切り上げて expectedHeight に入れ、元の値は maxHeight に残す', async () => {
    const h = harness();
    const xml = fixture('01-warning-issued.xml').replace('description="３ｍ">3<', 'description="３．５ｍ">3.5<');
    await ingest(xml, h);
    assert.equal(h.fcm.data(0).expectedHeight, '5');
    assert.equal(h.fcm.data(0).heightMeters, '3.5');
    assert.equal(h.db.get(`alerts/${E1}`)?.expectedHeight, 5);
    assert.equal((h.db.get(`alerts/${E1}`)?.maxHeight as { meters: number }).meters, 3.5);
  });

  it('定性的な高さ（巨大）は heightLabel と expectedHeight=huge で送る', async () => {
    const h = harness();
    await ingest(fixture('21-tall-qualitative.xml'), h);
    const d = h.fcm.data(0);
    assert.equal(d.kind, 'major-tsunami-warning');
    assert.equal(d.heightLabel, '巨大');
    assert.equal(d.expectedHeight, 'huge');
    assert.equal(d.heightMeters, undefined);
    assert.equal(h.db.get('alerts/20261108150000')?.expectedHeight, 'huge');
  });

  it('数値の高さは expectedHeight に区分の値（data では文字列）で入れる', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(h.fcm.data(0).expectedHeight, '3');
    assert.equal(h.db.get(`alerts/${E1}`)?.expectedHeight, 3);
    await ingest(fixture('03-height-raised.xml'), h); // 10m 超
    assert.equal(h.fcm.data(1).expectedHeight, 'over10');
    assert.equal(h.db.get(`alerts/${E1}`)?.expectedHeight, 'over10');
    assert.equal((h.db.get(`alerts/${E1}`)?.maxHeight as { meters: number }).meters, 10);
    await ingest(fixture('05-cleared.xml'), h);
    assert.equal(h.fcm.data(2).expectedHeight, undefined);
    assert.equal(h.db.get(`alerts/${E1}`)?.expectedHeight, null);
  });

  it('訂正・取消は別の警報として配信する', async () => {
    const h = harness();
    const r1 = await ingest(fixture('11-advisory-issued.xml'), h);
    const r2 = await ingest(fixture('12-advisory-corrected.xml'), h);
    const r3 = await ingest(fixture('13-advisory-cancelled.xml'), h);
    assert.deepEqual(
      [r1.result, r2.result, r3.result],
      ['sent', 'sent', 'sent'],
    );
    assert.equal(h.fcm.data(1).infoType, '訂正');
    assert.equal(h.fcm.data(1).change, 'same');
    assert.equal(h.fcm.data(1).arrivalTime, '2026-11-08T12:20:00+09:00');
    assert.equal(h.fcm.data(2).infoType, '取消');
    assert.equal(h.fcm.data(2).kind, 'cancelled');
    assert.equal(h.fcm.data(2).level, 'none');
    assert.ok(h.db.get(`sentAlerts/${E2}_1_発表`));
    assert.ok(h.db.get(`sentAlerts/${E2}_1_訂正`));
    assert.ok(h.db.get(`sentAlerts/${E2}_1_取消`));
    assert.equal(h.db.get(`alerts/${E2}`)?.kind, 'cancelled');
  });
});

describe('ingest: 二重送信の防止（D6）', () => {
  it('同じ電文を 2 回受け取っても、送るのは 1 回だけ', async () => {
    const h = harness();
    const xml = fixture('01-warning-issued.xml');
    assert.equal((await ingest(xml, h)).result, 'sent');
    assert.equal((await ingest(xml, h)).result, 'duplicate');
    assert.equal(h.fcm.sent.length, 1);
  });

  it('同じ電文を同時に受け取っても、送るのは 1 回だけ', async () => {
    const h = harness();
    const xml = fixture('02-major-upgrade.xml');
    const results = await Promise.all(Array.from({ length: 5 }, () => ingest(xml, h)));
    assert.equal(results.filter((r) => r.result === 'sent').length, 1);
    assert.ok(results.every((r) => ['sent', 'duplicate', 'in-progress'].includes(r.result)));
    assert.equal(h.fcm.sent.length, 1);
  });

  it('古い続報が後から届いたら送らない', async () => {
    const h = harness();
    await ingest(fixture('03-height-raised.xml'), h);
    const r = await ingest(fixture('02-major-upgrade.xml'), h);
    assert.equal(r.result, 'superseded');
    assert.equal(h.fcm.sent.length, 1);
    assert.equal(h.db.get(`alerts/${E1}`)?.serial, 3);
    assert.equal(h.db.get(`sentAlerts/${E1}_2_発表`)?.state, 'superseded');
  });

  it('FCM への送信に失敗したら failed にし、再送で送り直す', async () => {
    const h = harness();
    const xml = fixture('01-warning-issued.xml');
    h.fcm.failNext = 1;
    assert.equal((await ingest(xml, h)).result, 'failed');
    assert.equal(h.db.get(`sentAlerts/${E1}_1_発表`)?.state, 'failed');
    assert.equal((await ingest(xml, h)).result, 'sent');
    const rec = h.db.get(`sentAlerts/${E1}_1_発表`);
    assert.equal(rec?.state, 'sent');
    assert.equal(rec?.attempts, 2);
    assert.equal(h.fcm.sent.length, 1);
  });

  it('sending のまま一定時間たった記録は送り直す（途中で落ちた処理の救済）', async () => {
    const h = harness();
    // 前の処理が create() の直後に落ちた状態を作る
    await h.store.claim(`${E1}_1_発表`, { eventId: E1, serial: 1, infoType: '発表' });
    const xml = fixture('01-warning-issued.xml');
    assert.equal((await ingest(xml, h)).result, 'in-progress');
    assert.equal(h.fcm.sent.length, 0);
    h.clock.now += h.config.staleSendingMs;
    assert.equal((await ingest(xml, h)).result, 'sent');
    assert.equal(h.fcm.sent.length, 1);
  });

  it('Firestore に届かないときは、記録なしで送る（D7）', async () => {
    const h = harness();
    h.db.failCode = 14; // UNAVAILABLE
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent-unrecorded');
    assert.equal(h.fcm.sent.length, 1);
    assert.equal(h.fcm.data(0).change, 'new');
  });

  it('Firestore の応答が遅すぎるとき（DEADLINE_EXCEEDED）も、記録なしで送る（D7）', async () => {
    const h = harness();
    h.db.failCode = 4;
    assert.equal((await ingest(fixture('01-warning-issued.xml'), h)).result, 'sent-unrecorded');
  });

  it('権限の不足など、届かない以外の Firestore のエラーでは送らずに失敗させる', async () => {
    for (const code of [7 /* PERMISSION_DENIED */, 10 /* ABORTED */]) {
      const h = harness();
      h.db.failCode = code;
      await assert.rejects(ingest(fixture('01-warning-issued.xml'), h), new RegExp(`^Error: ${code} `));
      assert.equal(h.fcm.sent.length, 0, `code ${code}`);
    }
  });

  it('格上げの送信に失敗して再送されても、change は upgrade のまま（自分自身と比べない）', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    h.fcm.failNext = 1;
    assert.equal((await ingest(fixture('02-major-upgrade.xml'), h)).result, 'failed');
    assert.equal((await ingest(fixture('02-major-upgrade.xml'), h)).result, 'sent');
    assert.equal(h.fcm.data(1).change, 'upgrade');
    assert.equal(h.fcm.data(1).serial, '2');
    assert.equal(h.db.get(`alerts/${E1}`)?.change, 'upgrade');
  });

  it('格上げの送信に失敗した間に次の続報が来たら、次の続報を格上げとして送る', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h); // 津波警報（通知済み）
    h.fcm.failNext = 1;
    assert.equal((await ingest(fixture('02-major-upgrade.xml'), h)).result, 'failed'); // 大津波警報（未通知）
    const r3 = await ingest(fixture('03-height-raised.xml'), h); // 大津波警報（同じ種別）
    assert.equal(r3.result, 'sent');
    assert.equal(h.fcm.data(1).serial, '3');
    assert.equal(h.fcm.data(1).change, 'upgrade', '基準は通知済みの Serial 1（津波警報）');
    assert.equal((await ingest(fixture('02-major-upgrade.xml'), h)).result, 'superseded');
    assert.equal(h.fcm.sent.length, 2);
    const notified = h.db.get(`alerts/${E1}`)?.notified as Record<string, unknown>;
    assert.equal(notified.serial, 3);
    assert.equal(notified.level, 'emergency');
  });

  it('送信中に止まった電文が送り直されたときも、通知済みの基準と比べる', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    // Serial 2 の処理が alerts を書いた後、FCM に送る前に落ちた状態を作る
    const report2 = fixture('02-major-upgrade.xml');
    const r = parseTsunamiReport(report2);
    await h.store.claim(`${E1}_2_発表`, { eventId: E1, serial: 2, infoType: '発表' });
    await h.store.updateAlertState(E1, 2, '発表', (n) => buildAlertState(r, h.config, n));
    h.clock.now += h.config.staleSendingMs;
    assert.equal((await ingest(report2, h)).result, 'sent');
    assert.equal(h.fcm.data(1).change, 'upgrade');
  });

  it('取消は、より新しい Serial があっても反映し、serial は最大値を保って取消で固定する', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    await ingest(fixture('02-major-upgrade.xml'), h);
    const cancel1 = fixture('13-advisory-cancelled.xml').replace(
      '<EventID>20261108120000</EventID>',
      `<EventID>${E1}</EventID>`,
    );
    const r = await ingest(cancel1, h);
    assert.equal(r.result, 'sent');
    assert.equal(h.fcm.data(2).kind, 'cancelled');
    assert.equal(h.db.get(`alerts/${E1}`)?.kind, 'cancelled');
    assert.equal(h.db.get(`alerts/${E1}`)?.serial, 2, 'Serial 1 の取消でも serial は下げない');
    // 取消のあとに届いた発表（古いものも新しいものも）は反映しない
    assert.equal((await ingest(fixture('03-height-raised.xml'), h)).result, 'superseded');
    assert.equal(h.db.get(`alerts/${E1}`)?.kind, 'cancelled');
    assert.equal(h.db.get(`alerts/${E1}`)?.serial, 2);
    assert.equal(h.fcm.sent.length, 3);
  });

  it('同じ Serial では訂正を発表より新しいとみなし、あとから来た発表は反映しない', async () => {
    const h = harness();
    h.fcm.failNext = 1;
    assert.equal((await ingest(fixture('11-advisory-issued.xml'), h)).result, 'failed'); // Serial 1 発表
    assert.equal((await ingest(fixture('12-advisory-corrected.xml'), h)).result, 'sent'); // Serial 1 訂正
    assert.equal((await ingest(fixture('11-advisory-issued.xml'), h)).result, 'superseded'); // 発表の再送
    assert.equal(h.fcm.sent.length, 1);
    const alert = h.db.get(`alerts/${E2}`);
    assert.equal(alert?.infoType, '訂正');
    assert.equal(alert?.arrivalTime, '2026-11-08T12:20:00+09:00');
    assert.equal(h.db.get(`sentAlerts/${E2}_1_発表`)?.state, 'superseded');
  });

  it('送信後の記録（sent と notified）は 1 つのトランザクションで書く', async () => {
    const h = harness();
    const serial3Downgrade = fixture('04-downgrade-advisory.xml').replace('<Serial>4</Serial>', '<Serial>3</Serial>');
    const serial4Major = fixture('03-height-raised.xml').replace('<Serial>3</Serial>', '<Serial>4</Serial>');
    await ingest(fixture('02-major-upgrade.xml'), h); // Serial 2 大津波警報

    // Serial 3（格下げ）の送信後の書き込みを失敗させると、sent も notified も書かれない
    h.db.failCommitWhen = (paths) => paths.includes(`sentAlerts/${E1}_3_発表`);
    assert.equal((await ingest(serial3Downgrade, h)).result, 'sent-unconfirmed');
    assert.equal(h.db.get(`sentAlerts/${E1}_3_発表`)?.state, 'sending');
    assert.equal((h.db.get(`alerts/${E1}`)?.notified as { serial: number }).serial, 2);
    h.db.failCommitWhen = null;

    // 書き込みが通れば両方そろって更新される
    h.clock.now += h.config.staleSendingMs;
    assert.equal((await ingest(serial3Downgrade, h)).result, 'sent');
    assert.equal(h.db.get(`sentAlerts/${E1}_3_発表`)?.state, 'sent');
    assert.equal((h.db.get(`alerts/${E1}`)?.notified as { serial: number }).serial, 3);

    // Serial 4 で大津波警報に戻すと、格上げとして送る
    assert.equal((await ingest(serial4Major, h)).result, 'sent');
    assert.equal(h.fcm.data(h.fcm.sent.length - 1).change, 'upgrade');
  });

  it('sentAlerts には TTL 用の expireAt を入れる', async () => {
    const h = harness();
    await ingest(fixture('01-warning-issued.xml'), h);
    const rec = h.db.get(`sentAlerts/${E1}_1_発表`);
    assert.ok(rec?.expireAt instanceof Date);
    assert.equal((rec.expireAt as Date).getTime() - h.clock.now, 7 * 86_400_000);
  });
});

describe('ingest: 対象の判定', () => {
  it('DEMO_AREA_OVERRIDE が無効なら、TARGET_AREA_CODES の予報区だけを見る', async () => {
    const h = harness({ DEMO_AREA_OVERRIDE: 'false', TARGET_AREA_CODES: '250' });
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'sent');
    assert.equal(h.fcm.data(0).kind, 'tsunami-advisory'); // 福島県（250）は注意報
    assert.equal(h.fcm.data(0).arrivalTime, '2026-11-08T10:20:00+09:00');
  });

  it('対象の予報区がない電文は、記録も配信もしない', async () => {
    const h = harness({ DEMO_AREA_OVERRIDE: 'false', TARGET_AREA_CODES: '100' });
    const r = await ingest(fixture('01-warning-issued.xml'), h);
    assert.equal(r.result, 'ignored');
    assert.equal(h.db.docs.size, 0);
    assert.equal(h.fcm.sent.length, 0);
  });

  it('既定では、試験の電文は配信しない', async () => {
    const h = harness();
    const xml = fixture('01-warning-issued.xml').replace('<Status>訓練</Status>', '<Status>試験</Status>');
    assert.equal((await ingest(xml, h)).result, 'ignored');
    assert.equal(h.fcm.sent.length, 0);
  });

  it('津波警報・注意報・予報以外の電文は配信しない', async () => {
    const h = harness();
    assert.equal((await ingest(fixture('91-tsunami-info.xml'), h)).result, 'ignored');
  });

  it('読めない電文は invalid', async () => {
    const h = harness();
    assert.equal((await ingest('<oops', h)).result, 'invalid');
    assert.equal(h.db.docs.size, 0);
  });
});
