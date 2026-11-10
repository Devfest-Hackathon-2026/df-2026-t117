// Pronunciation dictionary: what the speech engine is given instead of the displayed text.
// The one place for readings. Used by platform/speech.ts (Web Speech API) and tools/voice/generate.mjs
// (Chirp 3 HD clips). The generator loads this file on its own, so keep it free of runtime imports.
import type { Lang } from '../state/types';

const READINGS: Partial<Record<Lang, Record<string, string>>> = {
  ja: {
    高台公園: 'たかだいこうえん',
    高台: 'たかだい',
  },
};

/** `text` as it should be read aloud. Replaced in one pass, longest word first; the displayed text is untouched. */
export function applyReadings(text: string, lang: Lang): string {
  const dict = READINGS[lang];
  if (!dict) return text;
  const pattern = Object.keys(dict)
    .sort((a, b) => b.length - a.length)
    .join('|');
  return text.replace(new RegExp(pattern, 'gu'), (word) => dict[word]);
}
