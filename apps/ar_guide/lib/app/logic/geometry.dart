// Small 2D geometry helpers (town meters, x = east, y = south). Port of mocks/evacuate/src/logic/geometry.ts.
import 'dart:math' as math;

import '../state/types.dart';

double dist(Point a, Point b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy);
}

Point lerp(Point a, Point b, double t) => Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

/// Closest point on segment ab to p, with t in [0, 1].
({Point point, double t, double d}) projectOnSegment(Point p, Point a, Point b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  final point = Point(a.x + dx * t, a.y + dy * t);
  return (point: point, t: t, d: dist(p, point));
}

/// Ray-casting point-in-polygon.
bool pointInPolygon(Point p, List<Point> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i];
    final b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}

/// Compass bearing from a to b in degrees: 0 = north (up), 90 = east, clockwise.
double bearing(Point a, Point b) {
  final deg = (math.atan2(b.x - a.x, -(b.y - a.y)) * 180) / math.pi;
  return (deg + 360).remainder(360);
}

/// Signed smallest angle from bearing [from] to bearing [to], in (-180, 180]. Positive = clockwise (right).
double angleDelta(double from, double to) {
  var d = (to - from).remainder(360);
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Length of segment ab that lies inside [poly], estimated by sampling.
double lengthInside(Point a, Point b, List<Point> poly, [int samples = 24]) {
  final len = dist(a, b);
  if (len == 0) return 0;
  var inside = 0;
  for (var i = 0; i < samples; i++) {
    if (pointInPolygon(lerp(a, b, (i + 0.5) / samples), poly)) inside++;
  }
  return (len * inside) / samples;
}
