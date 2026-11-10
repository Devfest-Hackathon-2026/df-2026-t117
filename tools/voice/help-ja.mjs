#!/usr/bin/env node
// 機能 F「日本語で助けを求める」の日本語の音声（Chirp 3 HD）を作る。使い方は README.md の「help-ja.mjs」。
//
//   node tools/voice/help-ja.mjs            文・声・形式が変わったときだけ生成
//   node tools/voice/help-ja.mjs --dry-run  API を呼ばずに、合成する文と文字数だけ表示
//   node tools/voice/help-ja.mjs --force    作り直す
//
// generate.mjs と違い、文はモックではなく Flutter アプリ（apps/ar_guide/lib/app/help/help_strings.dart の
// helpJaLines）から取り、出力も apps/ar_guide/assets/voice/help/ に直接書く（モックにはこの機能がない）。
// 読みの辞書は apps/ar_guide/lib/app/platform/readings.dart の日本語（高台 → たかだい）を使う。
// 認証はサービスアカウント claude-dev のなりすまし（gcloud）。鍵ファイルは使わない。トークンは表示も保存もしない。
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AUDIO_CONFIG, PREFERRED_VOICE } from './phrases.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const APP = resolve(HERE, '../../apps/ar_guide');
const STRINGS = join(APP, 'lib/app/help/help_strings.dart');
const READINGS = join(APP, 'lib/app/platform/readings.dart');
const OUT = join(APP, 'assets/voice/help');
const MANIFEST = join(OUT, 'manifest.json');
const FILE = 'help/ja.mp3'; // assets/voice/ からの相対パス（アプリの VoiceClips と同じ形）
const LANGUAGE_CODE = 'ja-JP';
const PROJECT = 'devfest2026-oauthmountains';
const SERVICE_ACCOUNT = `claude-dev@${PROJECT}.iam.gserviceaccount.com`;
const API = 'https://texttospeech.googleapis.com/v1';

const args = new Set(process.argv.slice(2));
const DRY = args.has('--dry-run');
const FORCE = args.has('--force');

/** Dart の単一引用符の文字列リテラルを取り出す（エスケープは \' と \\ だけ扱う）。 */
function dartStrings(src) {
  return [...src.matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1].replace(/\\(['\\])/g, '$1'));
}

/** help_strings.dart の helpJaLines。 */
function helpText() {
  const src = readFileSync(STRINGS, 'utf8');
  const m = src.match(/const List<String> helpJaLines = \[([\s\S]*?)\];/);
  if (!m) throw new Error(`${STRINGS}: helpJaLines が見つかりません`);
  const lines = dartStrings(m[1]);
  if (lines.length === 0) throw new Error('helpJaLines が空です');
  return lines.join('');
}

/** readings.dart の Lang.ja の辞書。 */
function jaReadings() {
  const src = readFileSync(READINGS, 'utf8');
  const m = src.match(/Lang\.ja:\s*\{([^}]*)\}/);
  if (!m) throw new Error(`${READINGS}: Lang.ja の辞書が見つかりません`);
  const s = dartStrings(m[1]);
  const dict = {};
  for (let i = 0; i + 1 < s.length; i += 2) dict[s[i]] = s[i + 1];
  return dict;
}

/** アプリの applyReadings と同じ: 長い語から 1 回で置き換える。 */
function applyReadings(text, dict) {
  const words = Object.keys(dict).sort((a, b) => b.length - a.length);
  if (words.length === 0) return text;
  return text.replace(new RegExp(words.join('|'), 'gu'), (w) => dict[w]);
}

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

async function pickVoice(previous) {
  const { voices = [] } = await api(`voices?languageCode=${LANGUAGE_CODE}`);
  const chirp = voices.filter((v) => v.name.includes('Chirp3-HD') && v.languageCodes.includes(LANGUAGE_CODE)).map((v) => v.name);
  if (chirp.length === 0) throw new Error(`${LANGUAGE_CODE} に Chirp 3 HD の声がありません`);
  if (previous && chirp.includes(previous)) return previous;
  return chirp.find((n) => n.endsWith(`-${PREFERRED_VOICE}`)) ?? chirp[0];
}

function clipHash(say, voice) {
  return createHash('sha256')
    .update(JSON.stringify({ text: say, voice, languageCode: LANGUAGE_CODE, audio: AUDIO_CONFIG }))
    .digest('hex')
    .slice(0, 16);
}

async function main() {
  const text = helpText();
  const say = applyReadings(text, jaReadings());
  const old = existsSync(MANIFEST) ? JSON.parse(readFileSync(MANIFEST, 'utf8')) : null;
  const prev = old?.clips?.ja?.help;

  if (DRY) {
    const state = !FORCE && prev && prev.hash === clipHash(say, prev.voice) && existsSync(join(OUT, 'ja.mp3')) ? 'キャッシュ' : '生成';
    console.log(`表示: ${text}\n合成: ${say}\n${state}（${say.length} 文字）`);
    return;
  }

  const voice = await pickVoice(old?.langs?.ja?.voice);
  const hash = clipHash(say, voice);
  const path = join(OUT, 'ja.mp3');
  if (!FORCE && prev && prev.hash === hash && existsSync(path)) {
    console.log(`変更なし（API 呼び出し ${requests} 回）`);
    return;
  }
  const res = await api('text:synthesize', {
    input: { text: say },
    voice: { languageCode: LANGUAGE_CODE, name: voice },
    audioConfig: AUDIO_CONFIG,
  });
  mkdirSync(OUT, { recursive: true });
  writeFileSync(path, Buffer.from(res.audioContent, 'base64'));
  const manifest = {
    version: 1,
    note: 'tools/voice/help-ja.mjs が生成。手で編集しない。',
    audio: AUDIO_CONFIG,
    langs: { ja: { languageCode: LANGUAGE_CODE, voice } },
    clips: { ja: { help: { file: FILE, text, reading: say, voice, hash } } },
  };
  writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`生成: assets/voice/${FILE}（${say.length} 文字、API 呼び出し ${requests} 回）\n合成: ${say}`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
