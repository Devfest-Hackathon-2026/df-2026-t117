// Read-aloud (requirements 3). No network call to a speech service, no permission prompt.
// H6: the text is split into parts (platform/voiceClips.ts). Parts with a pre-generated Chirp 3 HD clip
// (public/voice/) are played with one <audio> element; the other parts (numbers such as "12 m above
// forecast", missing clips) are read with the Web Speech API (speechSynthesis), one after another in order.
// If a clip cannot be played, that part and everything after it are read with the Web Speech API.
// Note: browsers only allow sound after the user has interacted with the page once (sticky activation);
// both paths simply stay silent before that.
import { useEffect, useState } from 'react';
import type { Lang } from '../state/types';
import { LANG_SPEECH_TAGS } from '../i18n';
import { applyReadings } from './readings';
import { loadVoiceManifest,splitSpeech, voiceManifestLoaded, type SpeechPart } from './voiceClips';

if (typeof window !== 'undefined') void loadVoiceManifest();

/** speak() waits at most this long for the manifest (so the first automatic announcement, F18, uses clips). */
const MANIFEST_WAIT_MS = 300;

export function speechSupported(): boolean {
  return typeof window !== 'undefined' && 'speechSynthesis' in window && typeof SpeechSynthesisUtterance !== 'undefined';
}

function audioSupported(): boolean {
  return typeof Audio !== 'undefined';
}

// ---------------------------------------------------------------------------
// Speaking state (F82: the fixed Listen button shows "Stop" while something is being read aloud).
// True from speak() until the last part ends (or cancelSpeech()).

type SpeakingListener = (speaking: boolean) => void;
const speakingListeners = new Set<SpeakingListener>();
let speakingNow = false;

function setSpeaking(v: boolean): void {
  if (v === speakingNow) return;
  speakingNow = v;
  speakingListeners.forEach((l) => l(v));
}

/** Is something being read aloud right now? */
export function isSpeaking(): boolean {
  return speakingNow;
}

/** true while read-aloud is playing (re-renders on start / end). */
export function useSpeaking(): boolean {
  const [v, setV] = useState(speakingNow);
  useEffect(() => {
    speakingListeners.add(setV);
    setV(speakingNow);
    return () => {
      speakingListeners.delete(setV);
    };
  }, []);
  return v;
}

// ---------------------------------------------------------------------------
// Playback of a sequence of parts

let audio: HTMLAudioElement | null = null;
/** Second element that only loads the next clip while the current one plays (shorter gaps). */
let preloader: HTMLAudioElement | null = null;
/** Bumped on every speak / cancel, so callbacks of an interrupted sequence do nothing. */
let generation = 0;
let pollTimer: number | undefined;

function stopPoll(): void {
  if (pollTimer !== undefined) {
    window.clearInterval(pollTimer);
    pollTimer = undefined;
  }
}

function stopAudio(): void {
  if (!audio) return;
  audio.onended = null;
  audio.onerror = null;
  try {
    audio.pause();
  } catch {
    /* ignore */
  }
}

/** When speechSynthesis.cancel() was last called (performance.now()); see CANCEL_GAP_MS. */
let cancelledAt = -Infinity;

/** Cancel Web Speech only when something is speaking or queued (a needless cancel() can make Chrome drop the next speak()). */
function stopTts(): void {
  stopPoll();
  if (!speechSupported()) return;
  try {
    const ss = window.speechSynthesis;
    if (ss.speaking || ss.pending) {
      ss.cancel();
      cancelledAt = performance.now();
    }
  } catch {
    /* ignore */
  }
}

function preload(url: string): void {
  if (!audioSupported()) return;
  if (!preloader) {
    preloader = new Audio();
    preloader.preload = 'auto';
    preloader.muted = true;
  }
  if (preloader.src.endsWith(url.replace(/^\.\//, ''))) return;
  preloader.src = url;
  try {
    preloader.load();
  } catch {
    /* ignore */
  }
}

/** Delay between speechSynthesis.cancel() and the next speak() (Chrome drops a speak() right after cancel). */
const CANCEL_GAP_MS = 50;

/**
 * Upper bound for one Web Speech part (ms): 1.5 s + 0.12 s per character (0.2 s for ja / zh / ko, where
 * one character is about one syllable). After it the part counts as finished even without an `end` event.
 */
function ttsLimitMs(text: string, lang: Lang): number {
  const perChar = lang === 'ja' || lang === 'zh-Hans' || lang === 'ko' ? 200 : 120;
  return 1500 + perChar * text.length;
}

/** Read `text` with the Web Speech API, then call `done` (once). Calls `done` at once when unavailable. */
function speakTtsPart(text: string, lang: Lang, gen: number, done: () => void): void {
  let finished = false;
  const finish = () => {
    if (finished || gen !== generation) return;
    finished = true;
    stopPoll();
    done();
  };
  if (!speechSupported() || !text) {
    finish();
    return;
  }
  const spoken = applyReadings(text, lang);
  const say = () => {
    if (finished || gen !== generation) return;
    try {
      const u = new SpeechSynthesisUtterance(spoken);
      u.lang = LANG_SPEECH_TAGS[lang];
      u.rate = 1;
      u.onend = finish;
      u.onerror = finish;
      window.speechSynthesis.speak(u);
      // Some browsers drop `end` events: also finish once the synthesizer is idle.
      // speechSynthesis.speaking is also true while an utterance is queued (pending).
      stopPoll();
      pollTimer = window.setInterval(() => {
        if (!window.speechSynthesis.speaking && !window.speechSynthesis.pending) finish();
      }, 300);
      // iOS Safari may never send `end` and keep `speaking` true: give up after an upper bound from the length.
      window.setTimeout(finish, ttsLimitMs(spoken, lang));
    } catch {
      finish();
    }
  };
  try {
    // Chrome may ignore a speak() right after cancel(): cancel only when something is queued, and then
    // speak in the next task.
    stopTts();
    const since = performance.now() - cancelledAt;
    if (since < CANCEL_GAP_MS) window.setTimeout(say, CANCEL_GAP_MS - since);
    else say();
  } catch {
    finish();
  }
}

/** Play `parts` in order. A clip that fails turns itself and every later part into one Web Speech part. */
function playParts(parts: SpeechPart[], lang: Lang, gen: number): void {
  let i = 0;
  const next = () => {
    if (gen !== generation) return;
    if (i >= parts.length) {
      stopAudio();
      setSpeaking(false);
      return;
    }
    const index = i++;
    const part = parts[index];
    if (part.kind === 'tts') {
      speakTtsPart(part.text, lang, gen, next);
      return;
    }
    let failed = false;
    // Both `error` and the play() rejection may report the same failure: handle it once.
    const failFrom = () => {
      if (failed || gen !== generation) return;
      failed = true;
      stopAudio();
      const rest = parts
        .slice(index)
        .map((p) => p.text)
        .join(' ');
      i = parts.length;
      speakTtsPart(rest, lang, gen, next);
    };
    if (!audioSupported()) {
      failFrom();
      return;
    }
    if (!audio) {
      audio = new Audio();
      audio.preload = 'auto';
    }
    const el = audio;
    el.onended = () => {
      if (gen === generation) next();
    };
    el.onerror = failFrom;
    el.src = part.url;
    el.play().catch(failFrom);
    const upcoming = parts.slice(index + 1).find((p) => p.kind === 'clip');
    if (upcoming && upcoming.kind === 'clip') preload(upcoming.url);
  };
  next();
}

function start(text: string, lang: Lang, gen: number): void {
  if (gen !== generation) return;
  const parts = splitSpeech(text, lang) ?? [{ kind: 'tts', text }];
  playParts(parts, lang, gen);
}

/**
 * Speak `text` in `lang` (interrupts anything currently being spoken): Chirp 3 HD clips for the phrases
 * that have one, the Web Speech API for the rest. Returns false when read-aloud is unavailable on this device.
 * When the manifest has not been loaded yet, it is (re)fetched and waited for at most MANIFEST_WAIT_MS.
 */
export function speak(text: string, lang: Lang): boolean {
  if (!text) return false;
  if (!speechSupported()) {
    // Only clips can sound: unavailable when there is no <audio>, or the manifest is known and has no clip.
    if (!audioSupported()) return false;
    if (voiceManifestLoaded() && !splitSpeech(text, lang)) return false;
  }
  const gen = ++generation;
  stopAudio();
  stopTts();
  setSpeaking(true);
  if (voiceManifestLoaded()) {
    start(text, lang, gen);
  } else {
    let started = false;
    const go = () => {
      if (started) return;
      started = true;
      start(text, lang, gen);
    };
    void loadVoiceManifest().then(go);
    window.setTimeout(go, MANIFEST_WAIT_MS);
  }
  return true;
}

/** Stop any ongoing speech (clips and Web Speech). */
export function cancelSpeech(): void {
  generation++;
  stopAudio();
  stopTts();
  setSpeaking(false);
}
