// Margin check on high ground (FB2: F83-F85, requirements 14.3) and expected tsunami heights (F84 / F89).
// The pure table lives in heights.ts; this file adds the position-dependent parts and the useMargin() hook
// used by S06, the demo panel and the alert-change effects.
import { useMemo } from 'react';
import type { AppState, ExpectedHeight, Point } from '../state/types';
import { heightInUse, judgeMargin, type MarginLevel } from './heights';
import { useAppState } from '../state/store';
import { isLocationApproximate, mostSevere } from '../state/derive';
import { elevationAt, REFUGES, type Refuge } from '../data/town';
import { dist } from './geometry';
import { ARRIVAL_RADIUS_M, useNavigation } from './nav';

export * from './heights';

/** Lowest / highest elevation within `radiusM` of `p` (center, 8 points at r/2 and 8 at r). */
export function elevationRange(p: Point, radiusM: number): { min: number; max: number } {
  let min = elevationAt(p);
  let max = min;
  for (const f of [0.5, 1]) {
    for (let i = 0; i < 8; i++) {
      const a = (i * Math.PI) / 4;
      const e = elevationAt({ x: p.x + Math.cos(a) * radiusM * f, y: p.y + Math.sin(a) * radiusM * f });
      min = Math.min(min, e);
      max = Math.max(max, e);
    }
  }
  return { min, max };
}

// ---------------------------------------------------------------------------
// Hook

export interface MarginInfo {
  /** Height used for the check (highest announced) and the current forecast */
  heightInUse: ExpectedHeight | null;
  heightNow: ExpectedHeight | null;
  /** Elevation of the current position (a range when the location is approximate). null = no location. */
  elevMinM: number | null;
  elevMaxM: number | null;
  approximate: boolean;
  /**
   * Level shown (colour of the card, headline on S06). null when there is no forecast or no location.
   * Uses the lowest elevation in the circle, except that "short" from the lowest point alone is shown as
   * "low" (yellow "Go higher." + "Location approximate") when the highest point is not short (review rule b).
   */
  level: MarginLevel | null;
  /** elevation (lowest in the circle) - expected height */
  marginM: number | null;
  /**
   * "Not enough" for certain: with an approximate location, even the highest elevation in the circle is short.
   * Only this may force S06 back to evacuate (useAlertEffects; review rule b). Display-only checks never do.
   */
  mustMove: boolean;
  /**
   * At a designated tsunami evacuation site (refuge flag): instruction stays "Stay here." + staff line.
   * (i) Arrived: the walk position is within ARRIVAL_RADIUS_M of the refuge (the route's arrival check), whatever
   * the GPS accuracy. (ii) Approximate location: the circle's center is within half the error radius of the
   * refuge. A refuge that is merely somewhere inside the error circle does not count (re-review).
   * (review rule a). No location: null.
   */
  designated: Refuge | null;
}

/** Pure margin assessment at `position` (the walk position on the route). */
export function assessMargin(state: AppState, position: Point): MarginInfo {
  const approximate = isLocationApproximate(state);
  const noLocation = state.gps.permission === 'denied' && !state.manualPin;
  const heightNow = mostSevere(state.alerts, 'tsunami')?.expectedHeight ?? null;
  const height = heightInUse(state);
  const radius = approximate && !noLocation ? state.gps.accuracyM : 0;
  const elev = elevationAt(position);
  const range = noLocation ? null : radius > 0 ? elevationRange(position, radius) : { min: elev, max: elev };
  const th = { marginAmpleM: state.marginAmpleM, hugeMinElevM: state.hugeMinElevM };
  const low = range && height !== null ? judgeMargin(range.min, height, th) : null;
  const high = range && height !== null ? judgeMargin(range.max, height, th) : null;
  const mustMove = high?.level === 'short';
  const level = low ? (low.level === 'short' && !mustMove ? 'low' : low.level) : null;
  let designated: Refuge | null = null;
  if (!noLocation) {
    const within = Math.max(ARRIVAL_RADIUS_M, radius / 2);
    let best = Infinity;
    for (const r of REFUGES) {
      const d = dist(position, r.pos);
      if (d <= within && d < best) {
        best = d;
        designated = r;
      }
    }
  }
  return {
    heightInUse: height,
    heightNow,
    elevMinM: range?.min ?? null,
    elevMaxM: range?.max ?? null,
    approximate,
    level,
    marginM: low?.marginM ?? null,
    mustMove,
    designated,
  };
}

export function useMargin(): MarginInfo {
  const state = useAppState();
  const nav = useNavigation();
  const { x, y } = nav.position;
  // assessMargin only reads these fields of the state.
  const { alerts, peakExpectedHeight, marginAmpleM, hugeMinElevM, gps, manualPin } = state;
  return useMemo(
    () => assessMargin(state, { x, y }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [x, y, alerts, peakExpectedHeight, marginAmpleM, hugeMinElevM, gps, manualPin],
  );
}
