// node --test tools/i18n-check/ で実行する（API は呼ばない）。
import assert from 'node:assert/strict';
import test from 'node:test';
import { parseDartConsts, parseDartDicts, tokenize } from './dart-dict.mjs';
import { collectItems, placeholders } from './check.mjs';

test('Dict の形（Lang.xx: {...}）を読む', () => {
  const src = `
// comment with 'quote'
const Dict _dict = {
  Lang.en: {'go': 'Go uphill', 'n': 'Turn in {n} m',},
  Lang.ja: {'go': '高台へ', /* c */ 'n': '{n} m 先'},
  Lang.zhHans: {'go': '去高处'},
};`;
  const d = parseDartDicts(src)._dict;
  assert.deepEqual(d.en, { go: 'Go uphill', n: 'Turn in {n} m' });
  assert.deepEqual(d.ja, { go: '高台へ', n: '{n} m 先' });
  assert.deepEqual(d['zh-Hans'], { go: '去高处' });
});

test('値が文字列リテラルでない項目はエラーで止まる', () => {
  assert.throws(() => parseDartDicts(`const Dict d = { Lang.en: {'a': foo('x')} };`), /文字列リテラルではありません/);
});

test('1 言語ずつの定数（const _en = S(...)）を読む', () => {
  const src = `class S { const S({required this.a}); final String a; }
const _en = S(a: 'Turn around', b: 'x');
const _ja = S(a: '後ろを向いてください', b: 'y');`;
  const c = parseDartConsts(src);
  assert.deepEqual(c._en, { a: 'Turn around', b: 'x' });
  assert.equal(c._ja.a, '後ろを向いてください');
  assert.equal(Object.keys(c).length, 2);
});

test('CommonStrings(...) の形を読む', () => {
  const src = `const Map<Lang, CommonStrings> commonStrings = {
    Lang.en: CommonStrings(appName: 'TASUKU', note: "It's"),
    Lang.ar: const CommonStrings(appName: 'تاسوكو', note: 'a' 'b'),
  };`;
  const d = parseDartDicts(src).commonStrings;
  assert.equal(d.en.note, "It's");
  assert.equal(d.ar.appName, 'تاسوكو');
  assert.equal(d.ar.note, 'ab'); // 隣り合う文字列は連結
});

test('エスケープと raw 文字列', () => {
  const [a, , b] = tokenize(String.raw`'it\'s é \$x', r'\n'`).map((t) => t.value);
  assert.equal(a, "it's é $x");
  assert.equal(b, String.raw`\n`);
});

test('プレースホルダーの比較', () => {
  assert.equal(placeholders('Elevation {v}, {n} m'), '{n} {v}');
  assert.equal(placeholders('高さ'), '');
});

test('アプリの辞書から対象の文を集められる', () => {
  const items = collectItems();
  const go = items.find((x) => x.key === 's01.goNow');
  assert.equal(go.en, 'Go uphill NOW');
  assert.equal(go.current.ja, '今すぐ高台へ');
  const badge = items.find((x) => x.key === 'commonStrings.badgeMajorTsunamiWarning');
  assert.equal(badge.current.ja, '大津波警報');
  const turn = items.find((x) => x.key === 's11.turnAround'); // lib/src/strings.dart の const _en = S(...)
  assert.equal(turn.en, 'Turn around');
  assert.equal(turn.current.ja, '後ろを向いてください');
  assert.ok(items.every((x) => x.en && Object.values(x.current).every(Boolean)));
});
