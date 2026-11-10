// Road graph + Dijkstra for the fictional town (requirements 7.4). Port of mocks/evacuate/src/logic/route.ts.
//
// Edge cost (directed, a -> b):
//   length * (1 + max(0, uphillGrade) * uphillK) + (stairs ? stairsPenaltyM : 0) + hazardLength * hazardWeight
// - Hazard-zone edges are allowed (the start is inside the zone) but heavily penalised, so the route leaves fast.
// - Online: closed roads are excluded. Offline: nothing is excluded and the route is marked unverified.
// - Destination: the refuge with the lowest total cost among those high enough for the expected tsunami
//   (elevation >= minRefugeElevM, i.e. "ample" in the margin check, 14.4). If none qualifies, the highest
//   reachable refuge, so guidance never stops for lack of a candidate.
import 'dart:math' as math;

import '../data/town.dart';
import '../state/types.dart';
import 'geometry.dart';

class RouteWeights {
  const RouteWeights({this.uphillK = 8, this.stairsPenaltyM = 40, this.hazardWeight = 6});

  /// Multiplier for the uphill grade (rise / run). 8 => a 5 % climb costs +40 %.
  final double uphillK;

  /// Fixed penalty for using a stairs edge (meters-equivalent).
  final double stairsPenaltyM;

  /// Each meter inside the hazard zone costs this many extra meters.
  final double hazardWeight;
}

class RouteSegment {
  const RouteSegment({
    required this.from,
    required this.to,
    required this.lengthM,
    required this.edgeId,
    required this.streetId,
    required this.stairs,
    required this.closed,
    required this.hazardM,
  });

  final Point from;
  final Point to;
  final double lengthM;

  /// Graph edge this segment runs on (null for the connector from an off-road origin to the road).
  final String? edgeId;
  final String? streetId;
  final bool stairs;

  /// Known closed in the saved road data (only possible on offline routes).
  final bool closed;
  final double hazardM;
}

/// The web's `Route` (renamed: Flutter has its own `Route`).
class EvacRoute {
  const EvacRoute({
    required this.points,
    required this.cumM,
    required this.totalM,
    required this.segments,
    required this.refuge,
    required this.verified,
    required this.hasStairs,
    required this.closedOnRoute,
    required this.hazardM,
    required this.cost,
    required this.origin,
    required this.snapped,
    required this.nodeIds,
  });

  /// Polyline from origin to refuge (town meters).
  final List<Point> points;

  /// Cumulative distance at each point (cumM[0] = 0, cumM[last] = totalM).
  final List<double> cumM;
  final double totalM;

  /// segments[i] joins points[i] -> points[i + 1].
  final List<RouteSegment> segments;
  final Refuge refuge;

  /// false when computed offline (closures not applied -> "Route unverified").
  final bool verified;

  /// Route uses stairs -> "Steps on route".
  final bool hasStairs;

  /// Offline route passes a road that is closed in the saved data.
  final bool closedOnRoute;

  /// Meters of the route inside the hazard zone.
  final double hazardM;

  /// Total Dijkstra cost.
  final double cost;

  /// Raw origin (GPS / manual pin) and the point it snapped to on the road.
  final Point origin;
  final Point snapped;

  /// Graph node ids visited (excluding the virtual origin).
  final List<String> nodeIds;
}

class SnapResult {
  const SnapResult({required this.point, required this.edge, required this.t, required this.distM});

  final Point point;
  final TownEdge edge;

  /// 0 at edge.a, 1 at edge.b.
  final double t;

  /// Distance from the input point to the road.
  final double distM;
}

Point _nodePoint(String id) {
  final n = nodes[id]!;
  return Point(n.x, n.y);
}

/// Snap an arbitrary point (GPS or manual pin) to the nearest road.
SnapResult snapToRoad(Point p) {
  SnapResult? best;
  for (final e in edges) {
    final pr = projectOnSegment(p, _nodePoint(e.a), _nodePoint(e.b));
    if (best == null || pr.d < best.distM) best = SnapResult(point: pr.point, edge: e, t: pr.t, distM: pr.d);
  }
  return best!;
}

/// Directed cost of walking from [from] to [to].
double segmentCost(
  Point from,
  Point to,
  double elevFrom,
  double elevTo,
  bool stairs, [
  RouteWeights w = const RouteWeights(),
]) {
  final len = dist(from, to);
  if (len == 0) return 0;
  final grade = math.max(0.0, (elevTo - elevFrom) / len);
  final hazard = lengthInside(from, to, hazardZone);
  return len * (1 + grade * w.uphillK) + (stairs ? w.stairsPenaltyM : 0) + hazard * w.hazardWeight;
}

class _Arc {
  const _Arc(this.to, this.cost, this.edge);
  final String to;
  final double cost;
  final TownEdge? edge;
}

class _Prev {
  const _Prev(this.from, this.edge);
  final String from;
  final TownEdge? edge;
}

const String _originId = '__origin';
const double _offRoadConnectorM = 2;

/// Shortest (least effort, hazard-avoiding) route from [origin] to the best refuge.
/// Always returns a route: if the graph were disconnected it falls back to a straight line to Hill Park.
/// [minRefugeElevM]: only refuges at least this high are candidates (null = any). See routeMinElevM().
EvacRoute computeRoute(
  Point origin, {
  required bool online,
  RouteWeights weights = const RouteWeights(),
  double? minRefugeElevM,
}) {
  final snap = snapToRoad(origin);
  final snapped = snap.point;

  Point pos(String id) => id == _originId ? snapped : _nodePoint(id);
  double elev(String id) => id == _originId ? elevationAt(snapped) : nodes[id]!.elev;

  // Adjacency (directed arcs)
  final adj = <String, List<_Arc>>{};
  void addArc(String a, String b, TownEdge? edge) {
    final cost = segmentCost(pos(a), pos(b), elev(a), elev(b), edge?.stairs ?? false, weights);
    adj.putIfAbsent(a, () => []).add(_Arc(b, cost, edge));
  }

  for (final e in edges) {
    if (online && e.closure != null) continue;
    addArc(e.a, e.b, e);
    addArc(e.b, e.a, e);
  }
  // Virtual origin on the snapped edge. You are already on that road, so these arcs are never excluded.
  addArc(_originId, snap.edge.a, snap.edge);
  addArc(_originId, snap.edge.b, snap.edge);

  // Dijkstra (graph is tiny: O(V^2) is fine)
  final distTo = <String, double>{_originId: 0};
  final prev = <String, _Prev>{};
  final done = <String>{};
  for (;;) {
    String? u;
    var best = double.infinity;
    distTo.forEach((id, d) {
      if (!done.contains(id) && d < best) {
        best = d;
        u = id;
      }
    });
    final current = u;
    if (current == null) break;
    done.add(current);
    for (final arc in adj[current] ?? const <_Arc>[]) {
      final nd = best + arc.cost;
      if (nd < (distTo[arc.to] ?? double.infinity)) {
        distTo[arc.to] = nd;
        prev[arc.to] = _Prev(current, arc.edge);
      }
    }
  }

  // Best refuge: cheapest among the high-enough ones; otherwise the highest reachable one.
  final reachable = refuges.where((r) => (distTo[r.nodeId] ?? double.infinity) < double.infinity).toList();
  final minElev = minRefugeElevM ?? double.negativeInfinity;
  var candidates = reachable.where((r) => r.elev >= minElev).toList();
  if (candidates.isEmpty && reachable.isNotEmpty) {
    final top = reachable.map((r) => r.elev).reduce(math.max);
    candidates = reachable.where((r) => r.elev == top).toList();
  }
  var refuge = refuges[0];
  var refugeCost = double.infinity;
  for (final r in candidates) {
    final c = distTo[r.nodeId] ?? double.infinity;
    if (c < refugeCost) {
      refugeCost = c;
      refuge = r;
    }
  }

  // Reconstruct node path
  final path = <({String id, TownEdge? edge})>[];
  if (refugeCost < double.infinity) {
    var cur = refuge.nodeId;
    while (cur != _originId) {
      final p = prev[cur]!;
      path.insert(0, (id: cur, edge: p.edge));
      cur = p.from;
    }
  }

  // Build polyline + segments
  final points = <Point>[];
  final segments = <RouteSegment>[];
  void push(Point to, TownEdge? edge) {
    final from = points.isEmpty ? null : points.last;
    points.add(to);
    if (from == null) return;
    segments.add(RouteSegment(
      from: from,
      to: to,
      lengthM: dist(from, to),
      edgeId: edge?.id,
      streetId: edge?.streetId,
      stairs: edge?.stairs ?? false,
      closed: edge?.closure != null,
      hazardM: lengthInside(from, to, hazardZone),
    ));
  }

  if (snap.distM > _offRoadConnectorM) points.add(origin);
  push(snapped, null);
  if (path.isEmpty) push(refuge.pos, null);
  for (final step in path) {
    final p = _nodePoint(step.id);
    // Skip zero-length steps (origin exactly on a node)
    if (dist(points.last, p) < 0.01) continue;
    push(p, step.edge);
  }

  final cumM = <double>[0];
  for (final s in segments) {
    cumM.add(cumM.last + s.lengthM);
  }

  return EvacRoute(
    points: points,
    cumM: cumM,
    totalM: cumM.last,
    segments: segments,
    refuge: refuge,
    verified: online,
    hasStairs: segments.any((s) => s.stairs),
    closedOnRoute: segments.any((s) => s.closed),
    hazardM: segments.fold(0.0, (a, s) => a + s.hazardM),
    cost: refugeCost,
    origin: origin,
    snapped: snapped,
    nodeIds: path.map((p) => p.id).toList(),
  );
}
