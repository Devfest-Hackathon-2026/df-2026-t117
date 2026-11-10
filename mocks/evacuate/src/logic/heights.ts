// Expected tsunami heights (F84 / F89) and the margin check table (F85, requirements 14.3). Pure, no React.
import type { AppState, ExpectedHeight } from '../state/types';
import { mostSevere } from '../state/derive';

// ---------------------------------------------------------------------------
// Expected heights

/** Demo steps for "raise the expected height" (JMA categories). */
export const HEIGHT_STEPS: ExpectedHeight[] = [1, 3, 5, 10, 'over10'];

/** Ordering of heights: 1 < 3 = high < 5 < 10 < over10 = huge. */
export function heightRank(h: ExpectedHeight): number {
  if (h === 'high') return 3;
  if (h === 'huge' || h === 'over10') return 11;
  return h;
}

/** Height used in "elevation - expected height": huge / over10 -> 10 (plus the over-10 rule), high -> 3. */
export function heightForCheckM(h: ExpectedHeight): number {
  if (h === 'high') return 3;
  if (h === 'huge' || h === 'over10') return 10;
  return h;
}

/** "10 m 超" or "巨大" */
export function isOver10(h: ExpectedHeight): boolean {
  return h === 'huge' || h === 'over10';
}

export function maxHeight(a: ExpectedHeight | null, b: ExpectedHeight | null): ExpectedHeight | null {
  if (a === null) return b;
  if (b === null) return a;
  return heightRank(b) > heightRank(a) ? b : a;
}

/** Next higher step (demo "raise"), or null when already over 10 m. */
export function raisedHeight(h: ExpectedHeight | undefined): ExpectedHeight | null {
  const rank = h === undefined ? 0 : heightRank(h);
  return HEIGHT_STEPS.find((s) => heightRank(s) > rank) ?? null;
}

// ---------------------------------------------------------------------------
// Margin check (decision table in 14.3)

/** ample = calm colour, "Stay here." / low = yellow, "Go higher." / short = red, back to evacuate ("Go higher. NOW"). */
export type MarginLevel = 'ample' | 'low' | 'short';

export interface MarginThresholds {
  /** Default 10 m */
  marginAmpleM: number;
  /** Default 20 m */
  hugeMinElevM: number;
}

export function judgeMargin(elevM: number, h: ExpectedHeight, th: MarginThresholds): { level: MarginLevel; marginM: number } {
  const marginM = elevM - heightForCheckM(h);
  if (marginM < 0 || (isOver10(h) && elevM < th.hugeMinElevM)) return { level: 'short', marginM };
  if (marginM < th.marginAmpleM) return { level: 'low', marginM };
  return { level: 'ample', marginM };
}

/** Lowest refuge elevation that is "ample" for this forecast (destination filter, 7.4 / 14.4). */
export function requiredRefugeElevM(h: ExpectedHeight, th: MarginThresholds): number {
  return Math.max(heightForCheckM(h) + th.marginAmpleM, isOver10(h) ? th.hugeMinElevM : 0);
}

/** Expected height the guidance uses: the highest announced so far (a downgrade does not loosen it, F8A). */
export function heightInUse(state: AppState): ExpectedHeight | null {
  const now = mostSevere(state.alerts, 'tsunami')?.expectedHeight ?? null;
  return maxHeight(state.peakExpectedHeight, now);
}

/** Required refuge elevation for the route (null = no tsunami alert / no forecast: any refuge). */
export function routeMinElevM(state: AppState): number | null {
  const h = heightInUse(state);
  return h === null ? null : requiredRefugeElevM(h, state);
}
