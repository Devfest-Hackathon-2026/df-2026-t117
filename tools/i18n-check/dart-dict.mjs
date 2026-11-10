// Flutter アプリの辞書（Dart の const リテラル）を読む小さなパーサ。
//
// 対象は次の 3 つの形だけ（apps/ar_guide の辞書はすべてこのどれか）:
//
//   const Dict _dict = { Lang.en: {'key': 'text', ...}, Lang.ja: {...}, ... };          parseDartDicts
//   const Map<Lang, CommonStrings> commonStrings = { Lang.en: CommonStrings(key: 'text', ...), ... };
//   const _en = S(key: 'text', ...);   （lib/src/strings.dart。1 言語ずつ別の定数）     parseDartConsts
//
// Dart の構文全体は扱わない。字句（文字列・識別子・記号・コメント）に分けてから、上の並びだけを読む。
// 値が文字列リテラルでない項目（式など）があれば、推測せずにエラーで止まる。

/** Dart の Lang 列挙子 → このツールの言語コード（モック・tools/voice と同じ）。 */
export const DART_LANGS = { en: 'en', ja: 'ja', zhHans: 'zh-Hans', ko: 'ko', ar: 'ar' };

const ESCAPES = { n: '\n', t: '\t', r: '\r', b: '\b', f: '\f', v: '\v', 0: '\0' };

/** Dart のソースを字句に分ける。文字列は中身（エスケープ解除後）を value に入れる。 */
export function tokenize(src) {
  const out = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (/\s/.test(c)) {
      i++;
    } else if (src.startsWith('//', i)) {
      const e = src.indexOf('\n', i);
      i = e < 0 ? src.length : e + 1;
    } else if (src.startsWith('/*', i)) {
      const e = src.indexOf('*/', i + 2);
      if (e < 0) throw new Error('閉じていないコメント');
      i = e + 2;
    } else if (c === "'" || c === '"' || ((c === 'r' || c === 'R') && (src[i + 1] === "'" || src[i + 1] === '"'))) {
      const raw = c === 'r' || c === 'R';
      if (raw) i++;
      const q = src[i];
      if (src.startsWith(q.repeat(3), i)) throw new Error(`三重引用符の文字列は未対応 (位置 ${i})`);
      i++;
      let value = '';
      let interpolated = false;
      for (;;) {
        if (i >= src.length || src[i] === '\n') throw new Error(`閉じていない文字列 (位置 ${i})`);
        const ch = src[i];
        if (ch === q) {
          i++;
          break;
        }
        if (ch === '\\' && !raw) {
          const n = src[i + 1];
          if (n === 'u') {
            let hex;
            if (src[i + 2] === '{') {
              const e = src.indexOf('}', i + 3);
              hex = src.slice(i + 3, e);
              i = e + 1;
            } else {
              hex = src.slice(i + 2, i + 6);
              i += 6;
            }
            value += String.fromCodePoint(parseInt(hex, 16));
          } else {
            value += ESCAPES[n] ?? n;
            i += 2;
          }
          continue;
        }
        if (ch === '$' && !raw) interpolated = true;
        value += ch;
        i++;
      }
      // 隣り合う文字列リテラルは Dart では連結される
      const prev = out[out.length - 1];
      if (prev?.type === 'string') {
        prev.value += value;
        prev.interpolated ||= interpolated;
      } else {
        out.push({ type: 'string', value, interpolated });
      }
    } else if (/[A-Za-z_$]/.test(c)) {
      const m = /^[A-Za-z_$][\w$]*/.exec(src.slice(i, i + 200));
      out.push({ type: 'ident', value: m[0] });
      i += m[0].length;
    } else {
      out.push({ type: 'punct', value: c });
      i++;
    }
  }
  return out;
}

const CLOSE = { '{': '}', '(': ')' };

const is = (t, type, value) => t && t.type === type && (value === undefined || t.value === value);

/**
 * `{'key': 'text', ...}`（open = '{'）または `CommonStrings(key: 'text', ...)`（open = '('）の中身を読む。
 * 戻り値: [項目, 閉じ括弧の次の位置]
 */
function readEntries(tokens, i, open) {
  const close = CLOSE[open];
  const entries = {};
  i++; // 開き括弧
  while (!is(tokens[i], 'punct', close)) {
    const k = tokens[i];
    if (!(is(k, 'string') || is(k, 'ident')) || !is(tokens[i + 1], 'punct', ':')) {
      throw new Error(`項目の形が想定外: ${JSON.stringify(k)}`);
    }
    const v = tokens[i + 2];
    if (!(is(v, 'string') && (is(tokens[i + 3], 'punct', ',') || is(tokens[i + 3], 'punct', close)))) {
      // 値が文字列リテラルでない（式など）ものは推測せずに止める
      throw new Error(`${k.value}: 値が文字列リテラルではありません`);
    }
    entries[k.value] = v.value;
    i += 3;
    if (is(tokens[i], 'punct', ',')) i++;
  }
  return [entries, i + 1];
}

/**
 * 1 言語ずつ別の定数にした形（AR 案内の apps/ar_guide/lib/src/strings.dart）を読む:
 *
 *   const _en = S(title: 'AR guidance', ...);
 *
 * 戻り値: { 定数の名前: { キー: 文 } }
 */
export function parseDartConsts(src) {
  const tokens = tokenize(src);
  const consts = {};
  for (let i = 0; i + 4 < tokens.length; i++) {
    // const <名前> = <クラス名> (
    if (!(is(tokens[i], 'ident', 'const') && is(tokens[i + 1], 'ident') && is(tokens[i + 2], 'punct', '='))) continue;
    if (!(is(tokens[i + 3], 'ident') && is(tokens[i + 4], 'punct', '('))) continue;
    const [entries, next] = readEntries(tokens, i + 4, '(');
    consts[tokens[i + 1].value] = entries;
    i = next - 1;
  }
  return consts;
}

/**
 * Dart のソースから 5 言語の辞書をすべて取り出す。
 * 戻り値: { 辞書の名前: { 言語コード: { キー: 文 } } }
 */
export function parseDartDicts(src) {
  const tokens = tokenize(src);
  const dicts = {};
  for (let i = 0; i + 2 < tokens.length; i++) {
    // <名前> = { Lang . <列挙子> :
    if (!(is(tokens[i], 'ident') && is(tokens[i + 1], 'punct', '=') && is(tokens[i + 2], 'punct', '{'))) continue;
    if (!(is(tokens[i + 3], 'ident', 'Lang') && is(tokens[i + 4], 'punct', '.'))) continue;
    const name = tokens[i].value;
    const dict = {};
    let j = i + 3;
    while (is(tokens[j], 'ident', 'Lang')) {
      const lang = DART_LANGS[tokens[j + 2]?.value];
      if (!lang || !is(tokens[j + 3], 'punct', ':')) throw new Error(`${name}: 言語の書き方が想定外`);
      j += 4;
      if (is(tokens[j], 'ident', 'const')) j++;
      if (is(tokens[j], 'ident') && is(tokens[j + 1], 'punct', '(')) j++; // CommonStrings(
      const open = tokens[j]?.value;
      if (open !== '{' && open !== '(') throw new Error(`${name}.${lang}: 辞書の形が想定外`);
      const [entries, next] = readEntries(tokens, j, open);
      dict[lang] = entries;
      j = next;
      if (is(tokens[j], 'punct', ',')) j++;
    }
    dicts[name] = dict;
    i = j;
  }
  return dicts;
}
