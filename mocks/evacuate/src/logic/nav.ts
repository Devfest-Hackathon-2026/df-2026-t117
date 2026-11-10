// Navigation along a route (requirements 7.5): position at a distance, heading, next turn, arrival,
// hazard-zone test, plus the useNavigation() hook shared by S04 / S07 / S08 / S11 / S12.
import { useMemo } from 'react';
import type { Point } from '../state/types';
import { useAppState } from '../state/store';
import { HAZARD_ZONE, type Refuge } from '../data/town';
import { angleDelta, bearing, dist, lerp, pointInPolygon } from './geometry';
import { computeRoute, type Route } from './route';
import { routeMinElevM } from './heights';

/** A direction change of at least this many degrees counts as a turn. */
export const TURN_MIN_DEG = 30;
/** Within this distance of the refuge counts as arrived (-> S06). */
export const ARRIVAL_RADIUS_M = 20;
/** Announce (voice + vibration) when the next turn is this close (used by T5). */
export const TURN_ANNOUNCE_M = 30;

export type TurnDirection = 'left' | 'right' | 'straight';

export interface Turn {
  /** Index of the turn vertex in the polyline */
  index: number;
  point: Point;
  /** Distance from the route start to the turn */
  atM: number;
  direction: Exclude<TurnDirection, 'straight'>;
  /** Signed angle, positive = right (clockwise) */
  angleDeg: number;
}

export interface NextTurn {
  /** 'straight' = no more turns: keep going to the refuge (point = refuge, distanceM = remaining). */
  direction: TurnDirection;
  distanceM: number;
  point: Point;
}

// ---------------------------------------------------------------------------
// Pure functions

function cumulative(points: Point[]): number[] {
  const cum = [0];
  for (let i = 1; i < points.length; i++) cum.push(cum[i - 1] + dist(points[i - 1], points[i]));
  return cum;
}

export function polylineLength(points: Point[]): number {
  const c = cumulative(points);
  return c[c.length - 1] ?? 0;
}

/** Index i of the segment [i, i+1] containing distance d (clamped). */
function segmentIndexAt(points: Point[], cum: number[], d: number): number {
  if (points.length < 2) return 0;
  for (let i = 0; i < points.length - 1; i++) {
    if (d < cum[i + 1]) return i;
  }
  return points.length - 2;
}

/** Point at distance `d` (m) along the polyline, clamped to [0, length]. */
export function pointAtDistance(points: Point[], d: number): Point {
  if (points.length === 0) return { x: 0, y: 0 };
  if (points.length === 1) return { ...points[0] };
  const cum = cumulative(points);
  const total = cum[cum.length - 1];
  const dd = Math.max(0, Math.min(total, d));
  const i = segmentIndexAt(points, cum, dd);
  const segLen = cum[i + 1] - cum[i];
  return segLen === 0 ? { ...points[i] } : lerp(points[i], points[i + 1], (dd - cum[i]) / segLen);
}

/** Heading (compass degrees, 0 = north/up, 90 = east) of the segment at distance `d`. */
export function headingAtDistance(points: Point[], d: number): number {
  if (points.length < 2) return 0;
  const cum = cumulative(points);
  const total = cum[cum.length - 1];
  const i = segmentIndexAt(points, cum, Math.max(0, Math.min(total, d)));
  return bearing(points[i], points[i + 1]);
}

/** The polyline from distance `fromM` to the end (for drawing the remaining route). */
export function slicePolyline(points: Point[], fromM: number): Point[] {
  if (points.length < 2) return points.slice();
  const cum = cumulative(points);
  const total = cum[cum.length - 1];
  const d = Math.max(0, Math.min(total, fromM));
  const i = segmentIndexAt(points, cum, d);
  return [pointAtDistance(points, d), ...points.slice(i + 1)];
}

/** All turns (direction change >= minDeg) along the polyline. */
export function findTurns(points: Point[], minDeg = TURN_MIN_DEG): Turn[] {
  const cum = cumulative(points);
  const turns: Turn[] = [];
  for (let i = 1; i < points.length - 1; i++) {
    if (dist(points[i - 1], points[i]) < 0.01 || dist(points[i], points[i + 1]) < 0.01) continue;
    const delta = angleDelta(bearing(points[i - 1], points[i]), bearing(points[i], points[i + 1]));
    if (Math.abs(delta) >= minDeg) {
      turns.push({ index: i, point: { ...points[i] }, atM: cum[i], direction: delta > 0 ? 'right' : 'left', angleDeg: delta });
    }
  }
  return turns;
}

/**
 * Next turn ahead of distance `d`. If no turn is left, returns 'straight' with the distance to the end.
 * Returns null once arrived (within ARRIVAL_RADIUS_M of the end).
 */
export function nextTurnAt(points: Point[], d: number, minDeg = TURN_MIN_DEG): NextTurn | null {
  if (points.length < 2) return null;
  const total = polylineLength(points);
  const dd = Math.max(0, Math.min(total, d));
  if (total - dd <= ARRIVAL_RADIUS_M) return null;
  const t = findTurns(points, minDeg).find((turn) => turn.atM > dd + 0.5);
  if (t) return { direction: t.direction, distanceM: t.atM - dd, point: t.point };
  return { direction: 'straight', distanceM: total - dd, point: { ...points[points.length - 1] } };
}

export function isArrived(position: Point, refuge: Pick<Refuge, 'pos'>, radiusM = ARRIVAL_RADIUS_M): boolean {
  return dist(position, refuge.pos) <= radiusM;
}

/** Is the point inside the coastal inundation hazard zone (sea counts as inside)? */
export function pointInHazard(p: Point): boolean {
  return pointInPolygon(p, HAZARD_ZONE);
}

export function hasStairs(route: Pick<Route, 'segments'>): boolean {
  return route.segments.some((s) => s.stairs);
}

// ---------------------------------------------------------------------------
// Hook

export interface NavRoute {
  points: Point[];
  totalM: number;
  refuge: Refuge;
  /** false offline -> "Route unverified" */
  verified: boolean;
  hasStairs: boolean;
  /** Full route details (segments, cumM, hazardM, cost, snapped origin ...) */
  detail: Route;
}

export interface Navigation {
  route: NavRoute;
  /** Current (simulated) position = point at walk.progressM along the route */
  position: Point;
  headingDeg: number;
  nextTurn: NextTurn | null;
  arrived: boolean;
  inHazardZone: boolean;
  /** Passability of the segment ahead is verified (online). Feeds the AR condition 4. */
  nextSegmentVerified: boolean;
  /** Route origin = manualPin ?? gps.position */
  origin: Point;
  /** walk.progressM clamped to [0, totalM] */
  progressM: number;
  remainingM: number;
  /** Remaining polyline from the current position (what the map draws) */
  remainingPoints: Point[];
  turns: Turn[];
}

/** Route + position + next turn from the store. Route is memoized on origin + online + required refuge height. */
export function useNavigation(): Navigation {
  const state = useAppState();
  const origin = state.manualPin ?? state.gps.position;
  const { x: ox, y: oy } = origin;
  const online = state.online;
  const minRefugeElevM = routeMinElevM(state);

  const base = useMemo(() => {
    const detail = computeRoute({ x: ox, y: oy }, { online, minRefugeElevM });
    return { detail, turns: findTurns(detail.points) };
  }, [ox, oy, online, minRefugeElevM]);

  const { detail, turns } = base;
  const progressM = Math.max(0, Math.min(detail.totalM, state.walk.progressM));

  return useMemo(() => {
    const position = pointAtDistance(detail.points, progressM);
    const arrived = isArrived(position, detail.refuge);
    return {
      route: {
        points: detail.points,
        totalM: detail.totalM,
        refuge: detail.refuge,
        verified: detail.verified,
        hasStairs: detail.hasStairs,
        detail,
      },
      position,
      headingDeg: headingAtDistance(detail.points, progressM),
      nextTurn: arrived ? null : nextTurnAt(detail.points, progressM),
      arrived,
      inHazardZone: pointInHazard(position),
      // Online: every road was checked at ROAD_STATUS_CHECKED_AT and closed roads are excluded.
      nextSegmentVerified: detail.verified,
      origin: { x: ox, y: oy },
      progressM,
      remainingM: detail.totalM - progressM,
      remainingPoints: slicePolyline(detail.points, progressM),
      turns,
    };
  }, [detail, turns, progressM, ox, oy]);
}
