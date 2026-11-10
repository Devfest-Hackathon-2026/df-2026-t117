// Road graph + Dijkstra for the fictional town (requirements 7.4). Pure, no React.
//
// Edge cost (directed, a -> b):
//   length * (1 + max(0, uphillGrade) * uphillK) + (stairs ? stairsPenaltyM : 0) + hazardLength * hazardWeight
// - Hazard-zone edges are allowed (the start is inside the zone) but heavily penalised, so the route leaves fast.
// - Online: closed roads are excluded. Offline: nothing is excluded and the route is marked unverified.
// - Destination: the refuge with the lowest total cost among those high enough for the expected tsunami
//   (elevation >= minRefugeElevM, i.e. "ample" in the margin check, 14.4). If none qualifies, the highest
//   reachable refuge, so guidance never stops for lack of a candidate.
import type { Point } from '../state/types';
import { EDGES, HAZARD_ZONE, NODES, REFUGES, elevationAt, type Refuge, type TownEdge } from '../data/town';
import { dist, lengthInside, projectOnSegment } from './geometry';

export interface RouteWeights {
  /** Multiplier for the uphill grade (rise / run). 8 => a 5 % climb costs +40 %. */
  uphillK: number;
  /** Fixed penalty for using a stairs edge (meters-equivalent). */
  stairsPenaltyM: number;
  /** Each meter inside the hazard zone costs this many extra meters. */
  hazardWeight: number;
}

export const DEFAULT_WEIGHTS: RouteWeights = { uphillK: 8, stairsPenaltyM: 40, hazardWeight: 6 };

export interface RouteOptions {
  online: boolean;
  weights?: Partial<RouteWeights>;
  /** Only refuges at least this high are candidates (null / undefined = any). See routeMinElevM(). */
  minRefugeElevM?: number | null;
}

export interface RouteSegment {
  from: Point;
  to: Point;
  lengthM: number;
  /** Graph edge this segment runs on (null for the connector from an off-road origin to the road). */
  edgeId: string | null;
  streetId: string | null;
  stairs: boolean;
  /** Known closed in the saved road data (only possible on offline routes). */
  closed: boolean;
  hazardM: number;
}

export interface Route {
  /** Polyline from origin to refuge (town meters) */
  points: Point[];
  /** Cumulative distance at each point (cumM[0] = 0, cumM[last] = totalM) */
  cumM: number[];
  totalM: number;
  /** segments[i] joins points[i] -> points[i + 1] */
  segments: RouteSegment[];
  refuge: Refuge;
  /** false when computed offline (closures not applied -> "Route unverified") */
  verified: boolean;
  /** Route uses stairs -> "Steps on route" */
  hasStairs: boolean;
  /** Offline route passes a road that is closed in the saved data */
  closedOnRoute: boolean;
  /** Meters of the route inside the hazard zone */
  hazardM: number;
  /** Total Dijkstra cost */
  cost: number;
  /** Raw origin (GPS / manual pin) and the point it snapped to on the road */
  origin: Point;
  snapped: Point;
  /** Graph node ids visited (excluding the virtual origin) */
  nodeIds: string[];
}

export interface SnapResult {
  point: Point;
  edge: TownEdge;
  /** 0 at edge.a, 1 at edge.b */
  t: number;
  /** Distance from the input point to the road */
  distM: number;
}

function nodePoint(id: string): Point {
  const n = NODES[id];
  return { x: n.x, y: n.y };
}

/** Snap an arbitrary point (GPS or manual pin) to the nearest road. */
export function snapToRoad(p: Point): SnapResult {
  let best: SnapResult | null = null;
  for (const e of EDGES) {
    const pr = projectOnSegment(p, nodePoint(e.a), nodePoint(e.b));
    if (!best || pr.d < best.distM) best = { point: pr.point, edge: e, t: pr.t, distM: pr.d };
  }
  return best!;
}

/** Directed cost of walking from `from` to `to`. */
export function segmentCost(
  from: Point,
  to: Point,
  elevFrom: number,
  elevTo: number,
  stairs: boolean,
  w: RouteWeights = DEFAULT_WEIGHTS,
): number {
  const len = dist(from, to);
  if (len === 0) return 0;
  const grade = Math.max(0, (elevTo - elevFrom) / len);
  const hazard = lengthInside(from, to, HAZARD_ZONE);
  return len * (1 + grade * w.uphillK) + (stairs ? w.stairsPenaltyM : 0) + hazard * w.hazardWeight;
}

interface Arc {
  to: string;
  cost: number;
  edge: TownEdge | null;
}

const ORIGIN_ID = '__origin';

/**
 * Shortest (least effort, hazard-avoiding) route from `origin` to the best refuge.
 * Always returns a route: if the graph were disconnected it falls back to a straight line to Hill Park.
 */
export function computeRoute(origin: Point, opts: RouteOptions): Route {
  const w: RouteWeights = { ...DEFAULT_WEIGHTS, ...opts.weights };
  const snap = snapToRoad(origin);
  const snapped = snap.point;

  const pos = (id: string): Point => (id === ORIGIN_ID ? snapped : nodePoint(id));
  const elev = (id: string): number => (id === ORIGIN_ID ? elevationAt(snapped) : NODES[id].elev);

  // Adjacency (directed arcs)
  const adj = new Map<string, Arc[]>();
  const addArc = (a: string, b: string, edge: TownEdge | null) => {
    const stairs = edge?.stairs ?? false;
    const cost = segmentCost(pos(a), pos(b), elev(a), elev(b), stairs, w);
    if (!adj.has(a)) adj.set(a, []);
    adj.get(a)!.push({ to: b, cost, edge });
  };
  for (const e of EDGES) {
    if (opts.online && e.closure) continue;
    addArc(e.a, e.b, e);
    addArc(e.b, e.a, e);
  }
  // Virtual origin on the snapped edge. You are already on that road, so these arcs are never excluded.
  addArc(ORIGIN_ID, snap.edge.a, snap.edge);
  addArc(ORIGIN_ID, snap.edge.b, snap.edge);

  // Dijkstra (graph is tiny: O(V^2) is fine)
  const distTo = new Map<string, number>([[ORIGIN_ID, 0]]);
  const prev = new Map<string, { from: string; edge: TownEdge | null }>();
  const done = new Set<string>();
  for (;;) {
    let u: string | null = null;
    let best = Infinity;
    for (const [id, d] of distTo) {
      if (!done.has(id) && d < best) {
        best = d;
        u = id;
      }
    }
    if (u === null) break;
    done.add(u);
    for (const arc of adj.get(u) ?? []) {
      const nd = best + arc.cost;
      if (nd < (distTo.get(arc.to) ?? Infinity)) {
        distTo.set(arc.to, nd);
        prev.set(arc.to, { from: u, edge: arc.edge });
      }
    }
  }

  // Best refuge: cheapest among the high-enough ones; otherwise the highest reachable one.
  const reachable = REFUGES.filter((r) => (distTo.get(r.nodeId) ?? Infinity) < Infinity);
  const minElev = opts.minRefugeElevM ?? -Infinity;
  const highEnough = reachable.filter((r) => r.elev >= minElev);
  let candidates = highEnough;
  if (candidates.length === 0 && reachable.length > 0) {
    const top = Math.max(...reachable.map((r) => r.elev));
    candidates = reachable.filter((r) => r.elev === top);
  }
  let refuge: Refuge = REFUGES[0];
  let refugeCost = Infinity;
  for (const r of candidates) {
    const c = distTo.get(r.nodeId) ?? Infinity;
    if (c < refugeCost) {
      refugeCost = c;
      refuge = r;
    }
  }

  // Reconstruct node path
  const path: { id: string; edge: TownEdge | null }[] = [];
  if (refugeCost < Infinity) {
    let cur = refuge.nodeId;
    while (cur !== ORIGIN_ID) {
      const p = prev.get(cur)!;
      path.unshift({ id: cur, edge: p.edge });
      cur = p.from;
    }
  }

  // Build polyline + segments
  const points: Point[] = [];
  const segments: RouteSegment[] = [];
  const push = (to: Point, edge: TownEdge | null) => {
    const from = points[points.length - 1];
    points.push(to);
    if (!from) return;
    const lengthM = dist(from, to);
    segments.push({
      from,
      to,
      lengthM,
      edgeId: edge?.id ?? null,
      streetId: edge?.streetId ?? null,
      stairs: edge?.stairs ?? false,
      closed: !!edge?.closure,
      hazardM: lengthInside(from, to, HAZARD_ZONE),
    });
  };
  const OFF_ROAD_CONNECTOR_M = 2;
  if (snap.distM > OFF_ROAD_CONNECTOR_M) points.push({ ...origin });
  push({ ...snapped }, null);
  if (path.length === 0) {
    push({ ...refuge.pos }, null);
  }
  for (const step of path) {
    const p = nodePoint(step.id);
    // Skip zero-length steps (origin exactly on a node)
    if (dist(points[points.length - 1], p) < 0.01) continue;
    push(p, step.edge);
  }

  const cumM = [0];
  for (const s of segments) cumM.push(cumM[cumM.length - 1] + s.lengthM);
  const totalM = cumM[cumM.length - 1];

  return {
    points,
    cumM,
    totalM,
    segments,
    refuge,
    verified: opts.online,
    hasStairs: segments.some((s) => s.stairs),
    closedOnRoute: segments.some((s) => s.closed),
    hazardM: segments.reduce((a, s) => a + s.hazardM, 0),
    cost: refugeCost,
    origin: { ...origin },
    snapped: { ...snapped },
    nodeIds: path.map((p) => p.id),
  };
}
