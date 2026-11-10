// Virtual clock helpers. All times are shown in JST regardless of the browser's timezone.

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 2026-11-08 09:41:00 JST (= 00:41:00 UTC). Initial virtual clock. */
export const DEMO_START_MS = Date.UTC(2026, 10, 8, 0, 41, 0);

/** Build an epoch ms for a JST wall-clock time on the demo day (2026-11-08). */
export function jstOnDemoDay(hh: number, mm: number, ss = 0): number {
  return Date.UTC(2026, 10, 8, hh, mm, ss) - JST_OFFSET_MS;
}

/** "HH:MM" in JST, e.g. "09:41". */
export function formatJst(ms: number): string {
  const d = new Date(ms + JST_OFFSET_MS);
  const hh = String(d.getUTCHours()).padStart(2, '0');
  const mm = String(d.getUTCMinutes()).padStart(2, '0');
  return `${hh}:${mm}`;
}

/** "HH:MM JST", e.g. "09:40 JST". */
export function formatJstLabel(ms: number): string {
  return `${formatJst(ms)} JST`;
}

export const MINUTE_MS = 60 * 1000;
