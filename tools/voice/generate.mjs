#!/usr/bin/env node
// 誘導画面の固定の指示文を Chirp 3 HD の声で MP3 にする（H6）。使い方は README.md。
//
//   node tools/voice/generate.mjs            差分だけ生成（manifest のハッシュと同じ文は呼ばない）
//   node tools/voice/generate.mjs --dry-run  API を呼ばずに、生成する文と文字数だけ表示
//   node tools/voice/generate.mjs --force    全部作り直す
//
// 認証はサービスアカウント claude-dev のなりすまし（gcloud）。鍵ファイルは使わない。
// トークンはメモリにだけ置き、表示もファイルへの書き出しもしない。
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AUDIO_CONFIG, LANGS, PHRASES, PREFERRED_VOICE } from './phrases.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const MOCK = resolve(HERE, '../../mocks/evacuate');
const OUT = join(MOCK, 'public/voice');
const MANIFEST = join(OUT, 'manifest.json');
const PROJECT = 'devfest2026-oauthmountains';
const SERVICE_ACCOUNT = `claude-dev@${PROJECT}.iam.gserviceaccount.com`;
const API = 'https://texttospeech.googleapis.com/v1';

const args = new Set(process.argv.slice(2));
const DRY = args.has('--dry-run');
const FORCE = args.has('--force');

// 文の区切りとみなす文字。モック側（src/platform/voiceClips.ts）と同じにする。
const SEP = /[\s.。,，、،!！?？+]/u;
function trimSep(s) {
  let a = 0;
  let b = s.length;
  while (a < b && SEP.test(s[a])) a++;
  while (b > a && SEP.test(s[b - 1])) b--;
  return s.slice(a, b);
}

// ---------------------------------------------------------------------------
// モックのソースから辞書を取り出す（TypeScript の構文木を読む。モックの node_modules の typescript を使う）

const require = createRequire(join(MOCK, 'package.json'));
let ts;
try {
  ts = require('typescript');
} catch {
  console.error('mocks/evacuate の依存が入っていません。先に `npm ci --prefix mocks/evacuate` を実行してください。');
  process.exit(1);
}

// 読みの辞書はモックと同じファイルを使う（TypeScript を JS にして読み込む）
const readingsJs = ts.transpileModule(readFileSync(join(MOCK, 'src/platform/readings.ts'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
}).outputText;
const { applyReadings } = await import(`data:text/javascript;base64,${Buffer.from(readingsJs).toString('base64')}`);

const sourceCache = new Map();
function source(file) {
  if (!sourceCache.has(file)) {
    const text = readFileSync(join(MOCK, file), 'utf8');
    sourceCache.set(file, ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, file.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS));
  }
  return sourceCache.get(file);
}

function findDict(file, dict) {
  let found = null;
  const visit = (node) => {
    if (found) return;
    if (dict === 'useT' && ts.isCallExpression(node) && node.expression.getText() === 'useT' && node.arguments[0] && ts.isObjectLiteralExpression(node.arguments[0])) {
      found = node.arguments[0];
      return;
    }
    if (dict !== 'useT' && ts.isVariableDeclaration(node) && node.name.getText() === dict && node.initializer && ts.isObjectLiteralExpression(node.initializer)) {
      found = node.initializer;
      return;
    }
    ts.forEachChild(node, visit);
  };
  visit(source(file));
  if (!found) throw new Error(`${file}: 辞書 ${dict} が見つかりません`);
  return found;
}

function propName(p) {
  if (ts.isIdentifier(p.name) || ts.isStringLiteral(p.name)) return p.name.text;
  return p.name.getText();
}

function readString(obj, name, where) {
  const p = obj.properties.find((x) => ts.isPropertyAssignment(x) && propName(x) === name);
  if (!p) throw new Error(`${where}: ${name} がありません`);
  const v = p.initializer;
  if (!ts.isStringLiteral(v) && !ts.isNoSubstitutionTemplateLiteral(v)) throw new Error(`${where}.${name}: 文字列ではありません`);
  return v.text;
}

function phraseText(ph, lang) {
  const dict = findDict(ph.file, ph.dict);
  const where = `${ph.file} ${ph.dict}`;
  const langProp = dict.properties.find((x) => ts.isPropertyAssignment(x) && propName(x) === lang);
  if (!langProp || !ts.isObjectLiteralExpression(langProp.initializer)) throw new Error(`${where}: ${lang} がありません`);
  return readString(langProp.initializer, ph.prop, `${where}.${lang}`);
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

let requests = 0;
async function api(path, body) {
  requests++;
  const res = await fetch(`${API}/${path}`, {
    method: body ? 'POST' : 'GET',
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      'x-goog-user-project': PROJECT,
      ...(body ? { 'Content-Type': 'application/json; charset=utf-8' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${path}: HTTP ${res.status} ${json.error?.message ?? ''}`);
  return json;
}

async function pickVoice(languageCode, previous) {
  const { voices = [] } = await api(`voices?languageCode=${encodeURIComponent(languageCode)}`);
  const chirp = voices.filter((v) => v.name.includes('Chirp3-HD') && v.languageCodes.includes(languageCode)).map((v) => v.name);
  if (chirp.length === 0) return null;
  if (previous && chirp.includes(previous)) return previous;
  return chirp.find((n) => n.endsWith(`-${PREFERRED_VOICE}`)) ?? chirp[0];
}

// ---------------------------------------------------------------------------

/**
 * 読ませる文。画面の大文字の語（EARTHQUAKE, NOW など）は 1 文字ずつ読まれないよう、先頭だけ大文字にして渡す。
 * manifest の text は画面の文のまま（モックはこの text で照合する）。
 */
function sayText(text, lang) {
  return applyReadings(text.replace(/\b[A-Z]{2,}\b/g, (w) => w[0] + w.slice(1).toLowerCase()), lang);
}

function clipHash(say, voice, languageCode) {
  return sha(JSON.stringify({ text: say, voice, languageCode, audio: AUDIO_CONFIG }));
}

function sha(s) {
  return createHash('sha256').update(s).digest('hex').slice(0, 16);
}

async function main() {
  const old = existsSync(MANIFEST) ? JSON.parse(readFileSync(MANIFEST, 'utf8')) : { langs: {}, clips: {} };

  // 文を集める（言語ごとに、区切りを除いた文が同じものは 1 つにまとめる）
  const plan = {};
  for (const lang of Object.keys(LANGS)) {
    const seen = new Map();
    plan[lang] = [];
    for (const ph of PHRASES) {
      const text = phraseText(ph, lang);
      if (/[0-9０-９٠-٩{}]/u.test(text)) throw new Error(`${ph.key} (${lang}): 数値を含む文は載せない: ${text}`);
      const norm = trimSep(text);
      if (seen.has(norm)) {
        seen.get(norm).alsoFrom.push(ph.key);
        continue;
      }
      const item = { key: ph.key, text, alsoFrom: [] };
      seen.set(norm, item);
      plan[lang].push(item);
    }
  }

  if (DRY) {
    let chars = 0;
    for (const [lang, items] of Object.entries(plan)) {
      for (const it of items) {
        const prev = old.clips?.[lang]?.[it.key];
        const say = sayText(it.text, lang);
        const state = prev && prev.hash === clipHash(say, prev.voice, LANGS[lang]) && !FORCE ? 'キャッシュ' : '生成';
        if (state === '生成') chars += say.length;
        console.log(`${lang}\t${it.key}\t${state}\t${say}`);
      }
    }
    console.log(`生成する文字数（目安）: ${chars}`);
    return;
  }

  const manifest = {
    version: 1,
    note: 'tools/voice/generate.mjs が生成。手で編集しない。',
    audio: AUDIO_CONFIG,
    langs: {},
    clips: {},
  };
  let generated = 0;
  let cached = 0;
  let chars = 0;

  for (const [lang, languageCode] of Object.entries(LANGS)) {
    const voice = await pickVoice(languageCode, old.langs?.[lang]?.voice);
    if (!voice) {
      console.log(`${lang} (${languageCode}): Chirp 3 HD の声がないため生成しません（Web Speech API で読みます）`);
      rmSync(join(OUT, lang), { recursive: true, force: true });
      continue;
    }
    manifest.langs[lang] = { languageCode, voice };
    manifest.clips[lang] = {};
    mkdirSync(join(OUT, lang), { recursive: true });
    for (const it of plan[lang]) {
      const say = sayText(it.text, lang);
      const hash = clipHash(say, voice, languageCode);
      const file = `${lang}/${it.key}.mp3`;
      const path = join(OUT, file);
      const prev = old.clips?.[lang]?.[it.key];
      if (!FORCE && prev && prev.hash === hash && existsSync(path)) {
        cached++;
      } else {
        const res = await api('text:synthesize', {
          input: { text: say },
          voice: { languageCode, name: voice },
          audioConfig: AUDIO_CONFIG,
        });
        writeFileSync(path, Buffer.from(res.audioContent, 'base64'));
        generated++;
        chars += say.length;
        console.log(`生成: ${file}  ${it.text}`);
      }
      manifest.clips[lang][it.key] = {
        file,
        text: it.text,
        reading: say,
        voice,
        hash,
        ...(it.alsoFrom.length ? { alsoFrom: it.alsoFrom } : {}),
      };
    }
  }

  // 使われなくなったファイルを消す
  for (const [lang, clips] of Object.entries(old.clips ?? {})) {
    for (const [key, c] of Object.entries(clips)) {
      if (!manifest.clips[lang]?.[key]) {
        rmSync(join(OUT, c.file), { force: true });
        console.log(`削除: ${c.file}`);
      }
    }
  }

  writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`生成 ${generated} 件（${chars} 文字）、キャッシュ ${cached} 件、API 呼び出し ${requests} 回`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
