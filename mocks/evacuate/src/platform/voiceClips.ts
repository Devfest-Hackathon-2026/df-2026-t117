// Pre-generated voice clips (H6: Chirp 3 HD, made by tools/voice/generate.mjs into public/voice/).
// The spoken text of a screen is built from fixed phrases ("Stay here. HIGH GROUND 12 m above forecast").
// splitSpeech() splits such a text into parts: phrases that have a clip in the current language, and the
// rest (numbers such as "12 m above forecast", or a translation changed after the clips were made), which
// the caller reads with the Web Speech API in between.
// Matching is by the phrase text itself (not by key), so a stale clip is never played for an edited text.
import type { Lang } from '../state/types';

type Clip = { file: string; text: string };
type Manifest = { clips?: Partial<Record<Lang, Record<string, Clip>>> };

/** One part of a spoken text: a clip to play, or text for the Web Speech API. `text` is always set. */
export type SpeechPart = { kind: 'clip'; url: string; text: string } | { kind: 'tts'; text: string };

// Characters treated as separators between phrases. Keep in sync with tools/voice/generate.mjs (SEP).
const SEP = /[\s.。,，、،!！?？+]/u;

function trimSep(s: string): string {
  let a = 0;
  let b = s.length;
  while (a < b && SEP.test(s[a])) a++;
  while (b > a && SEP.test(s[b - 1])) b--;
  return s.slice(a, b);
}

/** Per language: phrase (separators trimmed) -> clip URL, longest phrases first. */
let table: Partial<Record<Lang, { phrase: string; url: string }[]>> | null = null;
let pending: Promise<void> | null = null;

const BASE = `${import.meta.env.BASE_URL}voice/`;

/**
 * Fetch the manifest (in the background). Called at start-up, and again by speak() while it has not been
 * loaded (e.g. the first fetch failed). Resolves when this attempt ends, loaded or not; never rejects.
 */
export function loadVoiceManifest(): Promise<void> {
  if (table) return Promise.resolve();
  if (pending) return pending;
  if (typeof fetch === 'undefined') return Promise.resolve();
  pending = fetch(`${BASE}manifest.json`)
    .then((r) => (r.ok ? (r.json() as Promise<Manifest>) : Promise.reject(new Error(String(r.status)))))
    .then((m) => {
      const t: NonNullable<typeof table> = {};
      for (const [lang, clips] of Object.entries(m?.clips ?? {}) as [Lang, Record<string, Clip>][]) {
        t[lang] = Object.values(clips)
          .map((c) => ({ phrase: trimSep(c.text), url: `${BASE}${c.file}` }))
          .filter((c) => c.phrase.length > 0)
          .sort((a, b) => b.phrase.length - a.phrase.length);
      }
      table = t;
    })
    .catch(() => {
      /* not loaded: retried on the next speak(); Web Speech meanwhile */
    })
    .finally(() => {
      pending = null;
    });
  return pending;
}

export function voiceManifestLoaded(): boolean {
  return table !== null;
}

/**
 * Split `text` into clip / Web Speech parts, in order. Returns null when no part has a clip (read the whole
 * text with the Web Speech API as before).
 * At each position the longest phrase that ends at a separator (or the end) becomes a clip; otherwise the
 * text up to the next separator joins the current Web Speech part, which keeps its original spacing.
 */
export function splitSpeech(text: string, lang: Lang): SpeechPart[] | null {
  const list = table?.[lang];
  if (!list || list.length === 0 || !text) return null;
  const parts: SpeechPart[] = [];
  let ttsStart = -1;
  let ttsEnd = -1;
  const flushTts = () => {
    if (ttsStart >= 0) {
      const t = trimSep(text.slice(ttsStart, ttsEnd));
      if (t) parts.push({ kind: 'tts', text: text.slice(ttsStart, ttsEnd).trim() });
    }
    ttsStart = -1;
  };
  let i = 0;
  while (i < text.length) {
    if (SEP.test(text[i])) {
      i++;
      continue;
    }
    const hit = list.find(({ phrase }) => {
      if (!text.startsWith(phrase, i)) return false;
      const end = i + phrase.length;
      return end >= text.length || SEP.test(text[end]);
    });
    if (hit) {
      flushTts();
      parts.push({ kind: 'clip', url: hit.url, text: hit.phrase });
      i += hit.phrase.length;
      continue;
    }
    let j = i;
    while (j < text.length && !SEP.test(text[j])) j++;
    if (ttsStart < 0) ttsStart = i;
    ttsEnd = j;
    i = j;
  }
  flushTts();
  return parts.some((p) => p.kind === 'clip') ? parts : null;
}
