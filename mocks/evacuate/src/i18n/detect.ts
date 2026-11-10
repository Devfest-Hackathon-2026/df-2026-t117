// Language detection and persistence. Kept separate from index.ts so the store can
// import it without a circular dependency.
import type { Lang } from '../state/types';

export const LANGS: Lang[] = ['en', 'ja', 'zh-Hans', 'ko', 'ar'];
const STORAGE_KEY = 'tasuku.lang';

export function isLang(v: unknown): v is Lang {
  return typeof v === 'string' && (LANGS as string[]).includes(v);
}

/** Map a BCP-47 tag to a supported language, or null. Traditional Chinese falls back to null (-> en). */
export function matchLang(tag: string): Lang | null {
  const t = tag.toLowerCase();
  if (t.startsWith('ja')) return 'ja';
  if (t.startsWith('ko')) return 'ko';
  if (t.startsWith('ar')) return 'ar';
  if (t.startsWith('en')) return 'en';
  if (t.startsWith('zh')) {
    if (/hant|-tw|-hk|-mo/.test(t)) return null;
    return 'zh-Hans';
  }
  return null;
}

/** Detect from navigator.languages / navigator.language. Fallback 'en'. */
export function detectLang(): Lang {
  if (typeof navigator === 'undefined') return 'en';
  const tags = navigator.languages && navigator.languages.length > 0 ? navigator.languages : [navigator.language];
  for (const tag of tags) {
    if (!tag) continue;
    const m = matchLang(tag);
    if (m) return m;
  }
  return 'en';
}

/** Saved language if any, otherwise detected. */
export function loadLang(): Lang {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (isLang(saved)) return saved;
  } catch {
    /* storage unavailable */
  }
  return detectLang();
}

export function saveLang(lang: Lang): void {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    /* storage unavailable */
  }
}

export function isRtl(lang: Lang): boolean {
  return lang === 'ar';
}

/** Sets <html lang> and <html dir> ('rtl' for Arabic). */
export function applyDocumentLang(lang: Lang): void {
  if (typeof document === 'undefined') return;
  document.documentElement.lang = lang;
  document.documentElement.dir = isRtl(lang) ? 'rtl' : 'ltr';
}
