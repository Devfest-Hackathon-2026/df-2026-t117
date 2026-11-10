import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  JmaParseError,
  kindFromCode,
  levelOf,
  parseTsunamiReport,
  UnsupportedReportError,
} from '../src/jma.js';
import { fixture } from './fakes.js';

describe('parseTsunamiReport', () => {
  it('津波警報の発表を読み取る', () => {
    const r = parseTsunamiReport(fixture('01-warning-issued.xml'));
    assert.equal(r.eventId, '20261108094000');
    assert.equal(r.serial, 1);
    assert.equal(r.infoType, '発表');
    assert.equal(r.status, '訓練');
    assert.equal(r.reportDateTime, '2026-11-08T09:42:00+09:00');
    assert.equal(r.headline, '東北地方太平洋沿岸に津波警報を発表しました。');
    assert.equal(r.items.length, 2);
    const [miyagi, fukushima] = r.items;
    assert.deepEqual(miyagi, {
      areaCode: '220',
      areaName: '宮城県',
      kindCode: '51',
      kindName: '津波警報',
      kind: 'tsunami-warning',
      lastKindCode: null,
      lastKindName: null,
      firstWave: { arrivalTime: '2026-11-08T10:10:00+09:00', condition: null },
      maxHeight: { meters: 3, label: null, description: '３ｍ', over: false },
    });
    assert.equal(fukushima?.kind, 'tsunami-advisory');
    assert.equal(fukushima?.maxHeight?.meters, 1);
  });

  it('大津波警報への格上げ（コード 53）と前の種別を読み取る', () => {
    const r = parseTsunamiReport(fixture('02-major-upgrade.xml'));
    const miyagi = r.items[0];
    assert.equal(miyagi?.kindCode, '53');
    assert.equal(miyagi?.kind, 'major-tsunami-warning');
    assert.equal(miyagi?.lastKindName, '津波警報');
    assert.equal(miyagi?.maxHeight?.meters, 5);
  });

  it('「10m 超」と「ただちに津波来襲と予測」を読み取る', () => {
    const r = parseTsunamiReport(fixture('03-height-raised.xml'));
    const miyagi = r.items[0];
    assert.deepEqual(miyagi?.maxHeight, { meters: 10, label: null, description: '１０ｍ超', over: true });
    assert.deepEqual(miyagi?.firstWave, { arrivalTime: null, condition: 'ただちに津波来襲と予測' });
  });

  it('本文に数値がなく description（全角）にだけあるときは、そこから読む', () => {
    const xml = fixture('03-height-raised.xml').replace(
      '<jmx_eb:TsunamiHeight type="津波の高さ" unit="m" condition="超" description="１０ｍ超">10</jmx_eb:TsunamiHeight>',
      '<jmx_eb:TsunamiHeight type="津波の高さ" unit="m" description="１０ｍ超" xsi:nil="true"/>',
    );
    assert.notEqual(xml, fixture('03-height-raised.xml'));
    const r = parseTsunamiReport(xml);
    assert.deepEqual(r.items[0]?.maxHeight, { meters: 10, label: null, description: '１０ｍ超', over: true });
    const r2 = parseTsunamiReport(
      fixture('01-warning-issued.xml').replace('description="３ｍ">3<', 'description="３．５ｍ"><'),
    );
    assert.equal(r2.items[0]?.maxHeight?.meters, 3.5);
  });

  it('定性的な高さ（巨大・高い）を読み取る', () => {
    const r = parseTsunamiReport(fixture('21-tall-qualitative.xml'));
    assert.deepEqual(r.items[0]?.maxHeight, { meters: null, label: '巨大', description: '巨大', over: false });
    assert.deepEqual(r.items[1]?.maxHeight, { meters: null, label: '高い', description: '高い', over: false });
  });

  it('解除の電文は、すべての項目が cleared になる', () => {
    const r = parseTsunamiReport(fixture('05-cleared.xml'));
    assert.deepEqual(
      r.items.map((i) => [i.kindName, i.kind]),
      [
        ['津波注意報解除', 'cleared'],
        ['津波予報（若干の海面変動）', 'cleared'],
      ],
    );
    assert.equal(r.items[0]?.maxHeight, null);
  });

  it('訂正・取消の InfoType を読み取る。取消は本文に予報がなくてよい', () => {
    assert.equal(parseTsunamiReport(fixture('12-advisory-corrected.xml')).infoType, '訂正');
    const cancel = parseTsunamiReport(fixture('13-advisory-cancelled.xml'));
    assert.equal(cancel.infoType, '取消');
    assert.equal(cancel.items.length, 0);
  });

  it('津波警報・注意報・予報以外の電文は対象外', () => {
    assert.throws(() => parseTsunamiReport(fixture('91-tsunami-info.xml')), UnsupportedReportError);
  });

  it('壊れた電文・必須の要素がない電文は JmaParseError', () => {
    assert.throws(() => parseTsunamiReport('not xml'), JmaParseError);
    assert.throws(() => parseTsunamiReport('<Report><Control><Title>津'), JmaParseError);
    const noEvent = fixture('01-warning-issued.xml').replace(/<EventID>.*<\/EventID>/, '');
    assert.throws(() => parseTsunamiReport(noEvent), /EventID/);
    const badSerial = fixture('01-warning-issued.xml').replace('<Serial>1</Serial>', '<Serial>x</Serial>');
    assert.throws(() => parseTsunamiReport(badSerial), /Serial/);
    const badEvent = fixture('01-warning-issued.xml').replace(
      '<EventID>20261108094000</EventID>',
      '<EventID>../../x</EventID>',
    );
    assert.throws(() => parseTsunamiReport(badEvent), /EventID/);
    const noItems = fixture('01-warning-issued.xml').replace(/<Tsunami>[\s\S]*<\/Tsunami>/, '');
    assert.throws(() => parseTsunamiReport(noItems), /Item/);
  });

  it('DOCTYPE（実体の定義）を含む XML は受け付けない', () => {
    const xml = `<?xml version="1.0"?><!DOCTYPE r [<!ENTITY a "aaaa">]>${fixture('01-warning-issued.xml').replace(/^<\?xml[^>]*>/, '')}`;
    assert.throws(() => parseTsunamiReport(xml), /DOCTYPE/);
  });
});

describe('kindFromCode / levelOf', () => {
  it('コード表どおりに種別とレベルを決める', () => {
    const table: [string, string, string, string | null][] = [
      ['52', '大津波警報', 'major-tsunami-warning', 'emergency'],
      ['53', '大津波警報：発表', 'major-tsunami-warning', 'emergency'],
      ['51', '津波警報', 'tsunami-warning', 'warning'],
      ['62', '津波注意報', 'tsunami-advisory', 'advisory'],
      ['50', '警報解除', 'cleared', null],
      ['60', '津波注意報解除', 'cleared', null],
      ['71', '津波予報（若干の海面変動）', 'cleared', null],
      ['00', '津波なし', 'cleared', null],
      ['99', '津波警報', 'tsunami-warning', 'warning'], // 未知のコードは名前で判断
    ];
    for (const [code, name, kind, level] of table) {
      const k = kindFromCode(code, name);
      assert.equal(k, kind, `${code} ${name}`);
      assert.equal(levelOf(k), level, `${code} ${name}`);
    }
  });
});
