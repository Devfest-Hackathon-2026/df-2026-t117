import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { computeChange, expectedHeightOf, heightRank } from '../src/alert.js';
import type { TsunamiHeight } from '../src/jma.js';

const m = (meters: number, over = false): TsunamiHeight => ({ meters, label: null, description: null, over });
const q = (label: '巨大' | '高い'): TsunamiHeight => ({ meters: null, label, description: label, over: false });

describe('高さの比較（FB2: 巨大 = 10m 超、高い = 3m）', () => {
  it('比較値', () => {
    assert.equal(heightRank(q('巨大')), 10.5);
    assert.equal(heightRank(q('高い')), 3);
    assert.equal(heightRank(m(10, true)), 10.5);
    assert.equal(heightRank(m(5)), 5);
    assert.equal(heightRank(null), 0);
  });

  it('定性的な発表と数値の発表も、同じ物差しで比べる', () => {
    const prev = (h: TsunamiHeight) => ({ serial: 1, kind: 'major-tsunami-warning' as const, level: 'emergency' as const, maxHeight: h });
    assert.equal(computeChange('major-tsunami-warning', 'emergency', m(10, true), prev(q('巨大'))), 'same');
    assert.equal(computeChange('major-tsunami-warning', 'emergency', m(10), prev(q('巨大'))), 'height-down');
    assert.equal(computeChange('major-tsunami-warning', 'emergency', q('巨大'), prev(m(5))), 'height-up');
    const prevW = { serial: 1, kind: 'tsunami-warning' as const, level: 'warning' as const, maxHeight: q('高い') };
    assert.equal(computeChange('tsunami-warning', 'warning', m(3), prevW), 'same');
  });

  it('expectedHeight はモックの型（1 / 3 / 5 / 10 / over10 / huge / high）', () => {
    assert.equal(expectedHeightOf(q('巨大')), 'huge');
    assert.equal(expectedHeightOf(q('高い')), 'high');
    assert.equal(expectedHeightOf(m(10, true)), 'over10');
    for (const v of [1, 3, 5, 10] as const) assert.equal(expectedHeightOf(m(v)), v);
    assert.equal(expectedHeightOf(m(0.5)), 1);
    assert.equal(expectedHeightOf(m(3.5)), 5);
    assert.equal(expectedHeightOf(m(7)), 10);
    assert.equal(expectedHeightOf(m(12)), 'over10');
    assert.equal(expectedHeightOf({ meters: null, label: null, description: null, over: false }), null);
    assert.equal(expectedHeightOf(null), null);
  });
});
