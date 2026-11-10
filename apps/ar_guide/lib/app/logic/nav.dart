// Navigation along a route (requirements 7.5): position at a distance, heading, next turn, arrival,
// hazard-zone test. Port of mocks/evacuate/src/logic/nav.ts. The web's useNavigation() is
// `context.nav` / `store.nav`.
import 'dart:math' as math;

import '../data/town.dart';
import '../state/types.dart';
import 'geometry.dart';
import 'heights.dart';
import 'route.dart';

/// A direction change of at least this many degrees counts as a turn.
const double turnMinDeg = 30;

/// Within this distance of the refuge counts as arrived (-> S06).
const double arrivalRadiusM = 20;

/// Announce (voice + vibration) when the next turn is this close.
const double turnAnnounceM = 30;

enum TurnDirection { left, right, straight }

class Turn {
  const Turn({
    required this.index,
    required this.point,
    required this.atM,
    required this.direction,
    required this.angleDeg,
  });

  /// Index of the turn vertex in the polyline.
  final int index;
  final Point point;

  /// Distance from the route start to the turn.
  final double atM;

  /// left or right (never straight).
  final TurnDirection direction;

  /// Signed angle, positive = right (clockwise).
  final double angleDeg;
}

class NextTurn {
  const NextTurn({required this.direction, required this.distanceM, required this.point});

  /// straight = no more turns: keep going to the refuge (point = refuge, distanceM = remaining).
  final TurnDirection direction;
  final double distanceM;
  final Point point;
}

// ---------------------------------------------------------------------------
// Pure functions

List<double> _cumulative(List<Point> points) {
  final cum = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cum.add(cum[i - 1] + dist(points[i - 1], points[i]));
  }
  return cum;
}

double polylineLength(List<Point> points) => _cumulative(points).last;

/// Index i of the segment [i, i+1] containing distance d (clamped).
int _segmentIndexAt(List<Point> points, List<double> cum, double d) {
  if (points.length < 2) return 0;
  for (var i = 0; i < points.length - 1; i++) {
    if (d < cum[i + 1]) return i;
  }
  return points.length - 2;
}

/// Point at distance [d] (m) along the polyline, clamped to [0, length].
Point pointAtDistance(List<Point> points, double d) {
  if (points.isEmpty) return const Point(0, 0);
  if (points.length == 1) return points[0];
  final cum = _cumulative(points);
  final dd = d.clamp(0.0, cum.last);
  final i = _segmentIndexAt(points, cum, dd);
  final segLen = cum[i + 1] - cum[i];
  return segLen == 0 ? points[i] : lerp(points[i], points[i + 1], (dd - cum[i]) / segLen);
}

/// Heading (compass degrees, 0 = north/up, 90 = east) of the segment at distance [d].
double headingAtDistance(List<Point> points, double d) {
  if (points.length < 2) return 0;
  final cum = _cumulative(points);
  final i = _segmentIndexAt(points, cum, d.clamp(0.0, cum.last));
  return bearing(points[i], points[i + 1]);
}

/// The polyline from distance [fromM] to the end (for drawing the remaining route).
List<Point> slicePolyline(List<Point> points, double fromM) {
  if (points.length < 2) return List.of(points);
  final cum = _cumulative(points);
  final d = fromM.clamp(0.0, cum.last);
  final i = _segmentIndexAt(points, cum, d);
  return [pointAtDistance(points, d), ...points.sublist(i + 1)];
}

/// All turns (direction change >= [minDeg]) along the polyline.
List<Turn> findTurns(List<Point> points, [double minDeg = turnMinDeg]) {
  final cum = _cumulative(points);
  final turns = <Turn>[];
  for (var i = 1; i < points.length - 1; i++) {
    if (dist(points[i - 1], points[i]) < 0.01 || dist(points[i], points[i + 1]) < 0.01) continue;
    final delta = angleDelta(bearing(points[i - 1], points[i]), bearing(points[i], points[i + 1]));
    if (delta.abs() >= minDeg) {
      turns.add(Turn(
        index: i,
        point: points[i],
        atM: cum[i],
        direction: delta > 0 ? TurnDirection.right : TurnDirection.left,
        angleDeg: delta,
      ));
    }
  }
  return turns;
}

/// Next turn ahead of distance [d]. If no turn is left, returns straight with the distance to the end.
/// Returns null once arrived (within [arrivalRadiusM] of the end).
NextTurn? nextTurnAt(List<Point> points, double d, [double minDeg = turnMinDeg]) {
  if (points.length < 2) return null;
  final total = polylineLength(points);
  final dd = d.clamp(0.0, total);
  if (total - dd <= arrivalRadiusM) return null;
  for (final t in findTurns(points, minDeg)) {
    if (t.atM > dd + 0.5) return NextTurn(direction: t.direction, distanceM: t.atM - dd, point: t.point);
  }
  return NextTurn(direction: TurnDirection.straight, distanceM: total - dd, point: points.last);
}

bool isArrived(Point position, Refuge refuge, [double radiusM = arrivalRadiusM]) =>
    dist(position, refuge.pos) <= radiusM;

/// Is the point inside the coastal inundation hazard zone (sea counts as inside)?
bool pointInHazard(Point p) => pointInPolygon(p, hazardZone);

bool hasStairs(EvacRoute route) => route.segments.any((s) => s.stairs);

// ---------------------------------------------------------------------------
// From the state

class Navigation {
  const Navigation({
    required this.route,
    required this.position,
    required this.headingDeg,
    required this.nextTurn,
    required this.arrived,
    required this.inHazardZone,
    required this.nextSegmentVerified,
    required this.origin,
    required this.progressM,
    required this.remainingM,
    required this.remainingPoints,
    required this.turns,
  });

  /// Full route details. The web's `nav.route.detail` is this object too.
  final EvacRoute route;

  /// Current (simulated) position = point at walk.progressM along the route.
  final Point position;
  final double headingDeg;
  final NextTurn? nextTurn;
  final bool arrived;
  final bool inHazardZone;

  /// Passability of the segment ahead is verified (online). Feeds the AR condition 4.
  final bool nextSegmentVerified;

  /// Route origin = manualPin ?? gps.position.
  final Point origin;

  /// walk.progressM clamped to [0, totalM].
  final double progressM;
  final double remainingM;

  /// Remaining polyline from the current position (what the map draws).
  final List<Point> remainingPoints;
  final List<Turn> turns;
}

/// Keeps the last route, so it is computed again only when origin, online or the required height change.
class RouteMemo {
  Point? _origin;
  bool? _online;
  double? _minElev;
  EvacRoute? _route;
  List<Turn> _turns = const [];

  (EvacRoute, List<Turn>) get(Point origin, bool online, double? minElev) {
    final cached = _route;
    if (cached != null && _origin == origin && _online == online && _minElev == minElev) return (cached, _turns);
    final route = computeRoute(origin, online: online, minRefugeElevM: minElev);
    _origin = origin;
    _online = online;
    _minElev = minElev;
    _route = route;
    _turns = findTurns(route.points);
    return (route, _turns);
  }
}

/// Route + position + next turn from the state.
Navigation computeNavigation(AppState state, [RouteMemo? memo]) {
  final origin = state.manualPin ?? state.gps.position;
  final (route, turns) = (memo ?? RouteMemo()).get(origin, state.online, routeMinElevM(state));
  final progressM = math.max(0.0, math.min(route.totalM, state.walk.progressM));
  final position = pointAtDistance(route.points, progressM);
  final arrived = isArrived(position, route.refuge);
  return Navigation(
    route: route,
    position: position,
    headingDeg: headingAtDistance(route.points, progressM),
    nextTurn: arrived ? null : nextTurnAt(route.points, progressM),
    arrived: arrived,
    inHazardZone: pointInHazard(position),
    // Online: every road was checked at roadStatusCheckedAt and closed roads are excluded.
    nextSegmentVerified: route.verified,
    origin: origin,
    progressM: progressM,
    remainingM: route.totalM - progressM,
    remainingPoints: slicePolyline(route.points, progressM),
    turns: turns,
  );
}
