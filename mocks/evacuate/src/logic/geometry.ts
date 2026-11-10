// Small 2D geometry helpers (town meters, x = east, y = south). Pure, no React.
import type { Point } from '../state/types';

export function dist(a: Point, b: Point): number {
  return Math.hypot(b.x - a.x, b.y - a.y);
}

export function lerp(a: Point, b: Point, t: number): Point {
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
}

/** Closest point on segment ab to p, with t in [0, 1]. */
export function projectOnSegment(p: Point, a: Point, b: Point): { point: Point; t: number; d: number } {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2));
  const point = { x: a.x + dx * t, y: a.y + dy * t };
  return { point, t, d: dist(p, point) };
}

/** Ray-casting point-in-polygon. */
export function pointInPolygon(p: Point, poly: Point[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i];
    const b = poly[j];
    if (a.y > p.y !== b.y > p.y && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}

/** Compass bearing from a to b in degrees: 0 = north (up), 90 = east, clockwise. */
export function bearing(a: Point, b: Point): number {
  const deg = (Math.atan2(b.x - a.x, -(b.y - a.y)) * 180) / Math.PI;
  return (deg + 360) % 360;
}

/** Signed smallest angle from bearing `from` to bearing `to`, in (-180, 180]. Positive = clockwise (right). */
export function angleDelta(from: number, to: number): number {
  let d = (to - from) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/** Length of segment ab that lies inside `poly`, estimated by sampling. */
export function lengthInside(a: Point, b: Point, poly: Point[], samples = 24): number {
  const len = dist(a, b);
  if (len === 0) return 0;
  let inside = 0;
  for (let i = 0; i < samples; i++) {
    if (pointInPolygon(lerp(a, b, (i + 0.5) / samples), poly)) inside++;
  }
  return (len * inside) / samples;
}
