#!/usr/bin/env node
// ビルド時の訳の点検（architecture.md の D1 / D12）。使い方は README.md。
//
//   node tools/i18n-check/check.mjs              点検して docs/i18n-review.md / .json を書く
//   node tools/i18n-check/check.mjs --dry-run    API を呼ばずに、対象の文と呼び出し回数の見込みを表示
//   node tools/i18n-check/check.mjs --limit 3    先頭 3 件だけ点検して画面に出す（レポートは書かない）
//   --model <名前>        Gemini のモデル（既定は DEFAULT_MODEL）
//   --max-requests <数>   API 呼び出しの上限（既定 300）。超えそうなら止まる
//   --no-judge            Gemini による判定を省く
//
// アプリの文は変えない（点検の報告だけ）。
// 認証はサービスアカウント claude-dev のなりすまし（gcloud）。鍵ファイルは使わない。
// トークンはメモリにだけ置き、表示もファイルへの書き出しもしない。
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, posix, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseDartConsts, parseDartDicts } from './dart-dict.mjs';
import { TARGET_LANGS, TARGETS } from './targets.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const APP = join(ROOT, 'apps/ar_guide/lib/app');
const CACHE_FILE = join(HERE, 'cache.json');
const OUT_MD = join(ROOT, 'docs/i18n-review.md');
const OUT_JSON = join(ROOT, 'docs/i18n-review.json');
const PROJECT = 'devfest2026-oauthmountains';
const SERVICE_ACCOUNT = `claude-dev@${PROJECT}.iam.gserviceaccount.com`;

/** 2026-11-10 に実際の呼び出しで使えることを確かめたモデル（global のエンドポイント）。 */
export const DEFAULT_MODEL = 'gemini-3.5-flash';
const LOCATION = 'global';
/** プロンプトを変えたら上げる（キャッシュが効かなくなる）。 */
const PROMPT_VERSION = 1;

// ---------------------------------------------------------------------------
// 引数

const argv = process.argv.slice(2);
function flag(name) {
  return argv.includes(name);
}
function option(name, fallback) {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback;
}
const DRY = flag('--dry-run');
const JUDGE = !flag('--no-judge');
const LIMIT = Number(option('--limit', 0)) || 0;
const MODEL = option('--model', DEFAULT_MODEL);
const MAX_REQUESTS = Number(option('--max-requests', 300));
if (!Number.isFinite(MAX_REQUESTS) || MAX_REQUESTS < 0) {
  console.error('--max-requests には 0 以上の数を指定してください');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// 対象の文を集める

/** 文に含まれる {n} などのプレースホルダー（並べ替えて比べる）。 */
export function placeholders(s) {
  return (s.match(/\{\w+\}/g) ?? []).sort().join(' ');
}

/** 辞書の表示名: 画面の辞書はファイル名（s01）、push_text は push、それ以外は辞書の名前。 */
function dictLabel(t) {
  if (t.label) return t.label;
  if (t.dict === '_dict') return basename(t.file, '.dart');
  if (t.dict === '_pushText') return 'push';
  return t.dict;
}

export function collectItems(readFile = (f) => readFileSync(join(APP, f), 'utf8')) {
  const parsed = new Map();
  const items = [];
  for (const t of TARGETS) {
    let dict;
    if (t.consts) {
      // const _en = S(...) の形: 言語ごとの定数を集めて 5 言語の辞書にする
      const consts = parseDartConsts(readFile(t.file));
      dict = Object.fromEntries(Object.entries(t.consts).map(([lang, name]) => [lang, consts[name]]));
      if (!dict.en) throw new Error(`${t.file}: 定数 ${t.consts.en} が見つかりません`);
    } else {
      if (!parsed.has(t.file)) parsed.set(t.file, parseDartDicts(readFile(t.file)));
      dict = parsed.get(t.file)[t.dict];
      if (!dict?.en) throw new Error(`${t.file}: 辞書 ${t.dict} が見つかりません`);
    }
    const keys = (t.keys ?? Object.keys(dict.en)).filter((k) => !(t.skip ?? []).includes(k));
    for (const key of keys) {
      const en = dict.en[key];
      if (en === undefined) throw new Error(`${t.file} ${t.dict}: en に ${key} がありません`);
      const current = {};
      for (const lang of Object.keys(TARGET_LANGS)) {
        // 訳がないキーはアプリでは英語に戻る（Tr の挙動）
        current[lang] = dict[lang]?.[key] ?? en;
      }
      items.push({ key: `${dictLabel(t)}.${key}`, file: t.file, where: t.where, en, current });
    }
  }
  return items;
}

// ---------------------------------------------------------------------------
// キャッシュ（同じ入力の呼び出しは繰り返さない）

const cache = existsSync(CACHE_FILE) ? JSON.parse(readFileSync(CACHE_FILE, 'utf8')) : {};
cache.entries ??= {};
function sha(v) {
  return createHash('sha256').update(JSON.stringify(v)).digest('hex').slice(0, 20);
}
/** この実行で使ったキャッシュのキー。全件を点検したときは、使わなかった古い応答を捨てる。 */
const used = new Set();
function saveCache(prune) {
  cache.entries = Object.fromEntries(
    Object.entries(cache.entries)
      .filter(([k]) => !prune || used.has(k))
      .sort(([a], [b]) => a.localeCompare(b)),
  );
  const sorted = cache.entries;
  writeFileSync(CACHE_FILE, `${JSON.stringify({ note: 'tools/i18n-check/check.mjs の応答のキャッシュ。消せば作り直す。', entries: sorted }, null, 1)}\n`);
}

// ---------------------------------------------------------------------------
// API

let token = null;
function accessToken() {
  if (!token) {
    token = execSync(`gcloud auth print-access-token --impersonate-service-account=${SERVICE_ACCOUNT}`, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  }
  return token;
}

const stats = { requests: 0, cached: 0, inputTokens: 0, outputTokens: 0, translatedChars: 0 };

async function post(url, body) {
  for (let attempt = 0; ; attempt++) {
    // 再試行も 1 回と数え、上限を毎回確かめる
    if (stats.requests >= MAX_REQUESTS) throw new Error(`API 呼び出しが上限 ${MAX_REQUESTS} 回に達したので止めます（--max-requests で変更）`);
    stats.requests++;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken()}`,
        'x-goog-user-project': PROJECT,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => ({}));
    if (res.ok) return json;
    if ((res.status === 429 || res.status >= 500) && attempt < 2) {
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      continue;
    }
    const err = new Error(`HTTP ${res.status} ${json.error?.message ?? ''}`.trim());
    err.status = res.status;
    throw err;
  }
}

/** Gemini（Vertex AI）を構造化出力で呼ぶ。応答は JSON をパースしたもの。 */
async function gemini(system, prompt, schema) {
  const key = sha({ kind: 'gemini', v: PROMPT_VERSION, MODEL, system, prompt, schema });
  used.add(key);
  if (cache.entries[key]) {
    stats.cached++;
    return cache.entries[key];
  }
  const host = LOCATION === 'global' ? 'aiplatform.googleapis.com' : `${LOCATION}-aiplatform.googleapis.com`;
  const url = `https://${host}/v1/projects/${PROJECT}/locations/${LOCATION}/publishers/google/models/${MODEL}:generateContent`;
  const res = await post(url, {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: schema,
      thinkingConfig: { thinkingLevel: 'LOW' }, // 短い文の訳と判定なので、考える量を抑えて費用を減らす
    },
  });
  stats.inputTokens += res.usageMetadata?.promptTokenCount ?? 0;
  stats.outputTokens += (res.usageMetadata?.candidatesTokenCount ?? 0) + (res.usageMetadata?.thoughtsTokenCount ?? 0);
  const text = (res.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? '').join('');
  const value = JSON.parse(text);
  cache.entries[key] = value;
  return value;
}

/** Cloud Translation API v3 で英語に訳し戻す。texts は同じ言語の文の配列。戻り値は文 → 英訳。 */
async function backTranslate(texts, sourceLanguageCode) {
  const out = new Map();
  const todo = [];
  for (const t of new Set(texts)) {
    const key = sha({ kind: 'translate', sourceLanguageCode, t });
    used.add(key);
    const hit = cache.entries[key];
    if (hit !== undefined) {
      out.set(t, hit);
      stats.cached++;
    } else todo.push(t);
  }
  for (let i = 0; i < todo.length; i += 100) {
    const chunk = todo.slice(i, i + 100);
    const res = await post(`https://translation.googleapis.com/v3/projects/${PROJECT}/locations/global:translateText`, {
      contents: chunk,
      sourceLanguageCode,
      targetLanguageCode: 'en',
      mimeType: 'text/plain',
    });
    stats.translatedChars += chunk.join('').length;
    res.translations.forEach((tr, j) => {
      out.set(chunk[j], tr.translatedText);
      cache.entries[sha({ kind: 'translate', sourceLanguageCode, t: chunk[j] })] = tr.translatedText;
    });
  }
  return out;
}

/** 並列数を絞って順に処理する。 */
async function pool(list, n, fn) {
  const results = new Array(list.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, list.length) }, async () => {
      while (next < list.length) {
        const i = next++;
        results[i] = await fn(list[i], i);
      }
    }),
  );
  return results;
}

// ---------------------------------------------------------------------------
// プロンプト

const LANG_NAMES = { ja: 'Japanese', 'zh-Hans': 'Simplified Chinese', ko: 'Korean', ar: 'Arabic (Modern Standard)' };
const field = (lang) => lang.replace('-', '_'); // JSON のキー（zh_Hans）

const TRANSLATE_SYSTEM = `You translate emergency evacuation guidance for TASUKU, a smartphone app that guides foreign tourists in Japan to high ground during an earthquake or tsunami.
Rules:
- The reader may be panicking. Use short, imperative, plain words that can be understood at a glance. No polite padding.
- Use the register of official public emergency messages in each language: firm but not rude or slangy (e.g. Korean -세요 / -십시오 forms, not 반말; Japanese short instruction style such as 「高台へ」「頭を守って」).
- Keep the meaning and urgency of the English source exactly. Do not add or drop information.
- Keep placeholders such as {n}, {h} and {v} unchanged.
- Upper-case words in the source (e.g. NOW, TSUNAMI WARNING) are emphasis or labels. Keep the emphasis in a way natural for the target script.
- If the source is a label (not a sentence), translate it as a label.
- Official alert names (Major Tsunami Warning, Tsunami Warning, Tsunami Advisory, Earthquake, Emergency Warning, and the qualitative tsunami heights "huge" / "high") must use the terms of the Japan Meteorological Agency (JMA) multilingual dictionary for each language (Japanese: 大津波警報 / 津波警報 / 津波注意報 / 巨大 / 高い).
Return JSON only.`;

function translatePrompt(item) {
  return `English source: ${JSON.stringify(item.en)}
Where it appears: ${item.where} (key: ${item.key})
Translate into: ${Object.keys(TARGET_LANGS)
    .map((l) => `${field(l)} = ${LANG_NAMES[l]}`)
    .join(', ')}.`;
}

const TRANSLATE_SCHEMA = {
  type: 'OBJECT',
  properties: Object.fromEntries(Object.keys(TARGET_LANGS).map((l) => [field(l), { type: 'STRING' }])),
  required: Object.keys(TARGET_LANGS).map(field),
};

const JUDGE_SYSTEM = `You review translations of emergency evacuation guidance for TASUKU, a smartphone app that guides foreign tourists in Japan to high ground during an earthquake or tsunami.
For each language, judge the CURRENT translation used in the app against the English source:
- Does it keep the meaning and the urgency (an instruction must stay an instruction; NOW must stay urgent)?
- Is it short, imperative and plain enough for a panicking reader?
- Do official alert names follow the Japan Meteorological Agency (JMA) multilingual dictionary terms?
- Are placeholders such as {n} kept?
The back-translations into English were made by a different engine (Google Cloud Translation), use them as evidence when present.
A Gemini translation is given for comparison only; it may also be wrong.
verdict: "ok" = fine; "minor" = understandable but wording/tone/term could be better; "major" = meaning, urgency or the official term is wrong, or it could mislead.
better: which of current / gemini is better for this app ("same" if equivalent).
reason_ja: one short Japanese sentence (max 60 characters) explaining the verdict; for "ok" it may be empty.
Return JSON only.`;

function judgePrompt(item, gem, back) {
  const lines = [`English source: ${JSON.stringify(item.en)}`, `Where it appears: ${item.where} (key: ${item.key})`];
  for (const lang of Object.keys(TARGET_LANGS)) {
    lines.push(`\n[${field(lang)}: ${LANG_NAMES[lang]}]`);
    lines.push(`current: ${JSON.stringify(item.current[lang])}`);
    if (back) lines.push(`back-translation of current: ${JSON.stringify(back[lang]?.current ?? '')}`);
    lines.push(`gemini: ${JSON.stringify(gem[field(lang)])}`);
    if (back) lines.push(`back-translation of gemini: ${JSON.stringify(back[lang]?.gemini ?? '')}`);
  }
  return lines.join('\n');
}

const JUDGE_SCHEMA = {
  type: 'OBJECT',
  properties: Object.fromEntries(
    Object.keys(TARGET_LANGS).map((l) => [
      field(l),
      {
        type: 'OBJECT',
        properties: {
          verdict: { type: 'STRING', enum: ['ok', 'minor', 'major'] },
          better: { type: 'STRING', enum: ['current', 'gemini', 'same'] },
          reason_ja: { type: 'STRING' },
        },
        required: ['verdict', 'better', 'reason_ja'],
      },
    ]),
  ),
  required: Object.keys(TARGET_LANGS).map(field),
};

// ---------------------------------------------------------------------------
// レポート

const SEVERITY = { major: 2, minor: 1, ok: 0 };

function cell(s) {
  return String(s ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

function buildMarkdown(report) {
  const langs = Object.keys(TARGET_LANGS);
  const rows = report.items.flatMap((it) => langs.map((lang) => ({ it, lang, r: it.langs[lang] })));
  const flagged = rows.filter((x) => x.r.flag !== 'ok').sort((a, b) => SEVERITY[b.r.flag] - SEVERITY[a.r.flag]);
  const count = (lang, f) => rows.filter((x) => x.lang === lang && x.r.flag === f).length;
  const L = [];
  L.push(
    report.backTranslation.available
      ? '# 訳の点検レポート（Gemini ＋ Cloud Translation の逆翻訳）'
      : '# 訳の点検レポート（Gemini。Cloud Translation の逆翻訳は未実施）',
  );
  L.push('');
  L.push(`\`tools/i18n-check/check.mjs\` が生成（手で編集しない）。生成日 ${report.generatedAt.slice(0, 10)}。`);
  L.push('');
  L.push(
    'Flutter アプリ（`apps/ar_guide`）の誘導の文と警報の用語を、英語の原文から Gemini で訳し直し、アプリの現在の訳と比べたもの（`mocks/evacuate/docs/architecture.md` の D1 / D12）。**報告だけで、アプリの文と音声ファイルは変えていない。**',
  );
  L.push('');
  L.push('## まとめ');
  L.push('');
  L.push(`- 点検した文: ${report.items.length} 件 × ${langs.length} 言語 = ${rows.length} 件（原文は英語）`);
  L.push(`- 訳し直し・判定のモデル: \`${report.model}\`（Vertex AI、${report.location}）`);
  L.push(
    report.backTranslation.available
      ? '- 逆翻訳: Cloud Translation API v3（Gemini とは別のエンジン）で、現在の訳と Gemini の訳の両方を英語に戻した'
      : `- 逆翻訳: **未実施**（Cloud Translation API が使えなかった: ${report.backTranslation.error}）。判定は Gemini が訳文を直接読んで行った`,
  );
  L.push(`- 判定: ${report.judged ? 'Gemini（構造化出力）。Gemini 自身の訳と比べるので、最終判断は人が行う' : '省略（--no-judge）'}`);
  L.push(
    '- **注意: 警報の公式の用語（気象庁の多言語辞書）についての指摘や案は Gemini の知識によるもので、辞書そのものとは照合していない。** 用語を直す前に、気象庁の多言語辞書で確かめる',
  );
  L.push('');
  L.push('| 言語 | 要修正（major） | 改善の余地（minor） | 問題なし |');
  L.push('|---|---|---|---|');
  for (const lang of langs) L.push(`| ${lang} | ${count(lang, 'major')} | ${count(lang, 'minor')} | ${count(lang, 'ok')} |`);
  L.push('');
  const majors = flagged.filter((x) => x.r.flag === 'major');
  L.push('### 特に重要な指摘（major）');
  L.push('');
  if (majors.length === 0) L.push('なし。');
  for (const x of majors) {
    L.push(`- **${x.it.key}**（${x.lang}）「${x.r.current}」→ 案「${x.r.gemini}」: ${x.r.reason}`);
  }
  L.push('');
  L.push('## 要確認の一覧（major / minor）');
  L.push('');
  L.push('| キー | 言語 | 原文 | 現在の訳 | Gemini の訳 | 逆翻訳（現在） | 逆翻訳（Gemini） | 判定 | 理由 |');
  L.push('|---|---|---|---|---|---|---|---|---|');
  for (const x of flagged) {
    L.push(
      `| ${cell(x.it.key)} | ${x.lang} | ${cell(x.it.en)} | ${cell(x.r.current)} | ${cell(x.r.gemini)} | ${cell(x.r.backCurrent)} | ${cell(x.r.backGemini)} | ${x.r.flag} | ${cell(x.r.reason)} |`,
    );
  }
  L.push('');
  L.push('## 全件');
  L.push('');
  L.push('| キー | 言語 | 原文 | 現在の訳 | Gemini の訳 | 逆翻訳（現在） | 逆翻訳（Gemini） | 判定 |');
  L.push('|---|---|---|---|---|---|---|---|');
  for (const x of rows) {
    L.push(
      `| ${cell(x.it.key)} | ${x.lang} | ${cell(x.it.en)} | ${cell(x.r.current)} | ${cell(x.r.gemini)} | ${cell(x.r.backCurrent)} | ${cell(x.r.backGemini)} | ${x.r.flag} |`,
    );
  }
  L.push('');
  L.push('## 読み方');
  L.push('');
  L.push('- 判定 major: 意味・緊急度・公式の用語が違う、または誤解を招くおそれ。minor: 通じるが言い回しや用語を直せる。ok: 問題なし');
  L.push('- プレースホルダー（`{n}` など）が原文と合わない訳は、Gemini の判定にかかわらず major にしている');
  L.push('- 再実行: `node tools/i18n-check/check.mjs`（キャッシュが効くので、文を変えなければ API は呼ばない）');
  L.push('');
  return L.join('\n');
}

// ---------------------------------------------------------------------------

async function main() {
  let items = collectItems();
  if (LIMIT) items = items.slice(0, LIMIT);
  const langs = Object.keys(TARGET_LANGS);

  if (DRY) {
    for (const it of items) console.log(`${it.key}\t${it.en}\t${langs.map((l) => it.current[l]).join(' / ')}`);
    const uncached = items.filter((it) => !cache.entries[sha({ kind: 'gemini', v: PROMPT_VERSION, MODEL, system: TRANSLATE_SYSTEM, prompt: translatePrompt(it), schema: TRANSLATE_SCHEMA })]).length;
    console.log(`\n対象 ${items.length} 件 × ${langs.length} 言語。モデル ${MODEL}`);
    console.log(`API 呼び出しの見込み: Gemini 訳 ${uncached} 回 ＋ 逆翻訳 最大 ${langs.length} 回 ＋ 判定 最大 ${JUDGE ? items.length : 0} 回（上限 ${MAX_REQUESTS} 回）`);
    return;
  }

  try {
    // 1. Gemini で訳し直す
    const gem = await pool(items, 4, (it) => gemini(TRANSLATE_SYSTEM, translatePrompt(it), TRANSLATE_SCHEMA));
    console.log(`Gemini 訳: ${items.length} 件`);

    // 2. Cloud Translation で現在の訳と Gemini の訳を英語に戻す
    const backTranslation = { available: true, error: null };
    const back = items.map(() => ({}));
    try {
      for (const lang of langs) {
        const texts = items.flatMap((it, i) => [it.current[lang], gem[i][field(lang)]]);
        const map = await backTranslate(texts, TARGET_LANGS[lang]);
        items.forEach((it, i) => {
          back[i][lang] = { current: map.get(it.current[lang]), gemini: map.get(gem[i][field(lang)]) };
        });
      }
      console.log('逆翻訳: 完了');
    } catch (e) {
      if (e.status !== 403 && e.status !== 400) throw e;
      backTranslation.available = false;
      backTranslation.error =
        e.status !== 403
          ? e.message.slice(0, 120)
          : /disabled|has not been used/i.test(e.message)
            ? 'HTTP 403: プロジェクトで translate.googleapis.com が有効になっていない'
            : 'HTTP 403: サービスアカウントに Cloud Translation の権限がない';
      console.warn(`逆翻訳を省きます: ${e.message.slice(0, 300)}`);
    }

    // 3. Gemini で判定する
    const judged = JUDGE
      ? await pool(items, 4, (it, i) => gemini(JUDGE_SYSTEM, judgePrompt(it, gem[i], backTranslation.available ? back[i] : null), JUDGE_SCHEMA))
      : null;

    const report = {
      generatedAt: new Date().toISOString(),
      model: MODEL,
      location: LOCATION,
      backTranslation,
      judged: Boolean(judged),
      items: items.map((it, i) => ({
        key: it.key,
        file: posix.normalize(`apps/ar_guide/lib/app/${it.file}`),
        where: it.where,
        en: it.en,
        langs: Object.fromEntries(
          langs.map((lang) => {
            const j = judged?.[i]?.[field(lang)];
            const mismatch = placeholders(it.en) !== placeholders(it.current[lang]);
            let flag = j?.verdict ?? 'ok';
            let reason = j?.reason_ja ?? '';
            if (mismatch) {
              flag = 'major';
              reason = `プレースホルダーが原文と合わない。${reason}`;
            }
            return [
              lang,
              {
                current: it.current[lang],
                gemini: gem[i][field(lang)],
                backCurrent: back[i][lang]?.current ?? null,
                backGemini: back[i][lang]?.gemini ?? null,
                flag,
                better: j?.better ?? null,
                reason,
              },
            ];
          }),
        ),
      })),
    };

    if (LIMIT) {
      console.log(JSON.stringify(report.items, null, 2));
    } else {
      writeFileSync(OUT_JSON, `${JSON.stringify(report, null, 2)}\n`);
      writeFileSync(OUT_MD, buildMarkdown(report));
      console.log(`書き出し: docs/i18n-review.md, docs/i18n-review.json`);
    }
    saveCache(!LIMIT);
  } finally {
    saveCache(false); // 途中で止まっても、それまでの応答は残す（上の saveCache 済みなら同じ内容）
    console.log(
      `API 呼び出し ${stats.requests} 回、キャッシュ ${stats.cached} 件、Gemini トークン 入力 ${stats.inputTokens} / 出力 ${stats.outputTokens}、逆翻訳 ${stats.translatedChars} 文字`,
    );
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
