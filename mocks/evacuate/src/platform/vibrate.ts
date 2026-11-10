// Vibration API wrapper (requirements 3). iOS Safari has no navigator.vibrate, so screens also show a
// vibration icon. Browsers ignore vibrate() until the user has interacted with the page once.

/** Turn-approach pattern: two short pulses. */
export const TURN_PATTERN: number[] = [180, 90, 180];

export function vibrationSupported(): boolean {
  return typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function';
}

/** Vibrate with `pattern` (ms or [on, off, on, ...]). Returns whether the API is supported and accepted it. */
export function vibrate(pattern: number | number[] = TURN_PATTERN): boolean {
  if (!vibrationSupported()) return false;
  try {
    return navigator.vibrate(pattern);
  } catch {
    return false;
  }
}
