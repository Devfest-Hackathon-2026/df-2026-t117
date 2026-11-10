// Fictional town "Minato Bay / みなと湾（架空）". NOT a real place. Port of mocks/evacuate/src/data/town.ts.
// Coordinates are meters: origin top-left, x = east, y = south. Core area ~600 m x 450 m.
// Sea on the west (slanted coastline), coastal inundation hazard band, street grid rising to the east.
import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../state/scenarios.dart';
import '../state/time.dart';
import '../state/types.dart';
import 'names.dart';

export 'names.dart';

class TownNode {
  const TownNode({required this.id, required this.x, required this.y, required this.elev});

  final String id;
  final double x;
  final double y;

  /// Elevation above sea level (m). Rises to the east.
  final double elev;
}

class RoadClosure {
  const RoadClosure({required this.reason, required this.checkedAt});

  final L10n reason;

  /// When passability was last checked (epoch ms). 09:41 JST on the demo day.
  final int checkedAt;
}

class Street {
  const Street({
    required this.id,
    required this.name,
    required this.nodeIds,
    this.stairs = false,
    this.extendStart = false,
    this.extendEnd = false,
  });

  final String id;
  final L10n name;

  /// Node ids along the street, in order.
  final List<String> nodeIds;

  /// Whole street is stairs.
  final bool stairs;

  /// Draw a decorative continuation past the first / last node (outside the core area).
  final bool extendStart;
  final bool extendEnd;
}

class TownEdge {
  const TownEdge({
    required this.id,
    required this.a,
    required this.b,
    required this.streetId,
    required this.stairs,
    required this.closure,
  });

  final String id;
  final String a;
  final String b;
  final String streetId;
  final bool stairs;
  final RoadClosure? closure;
}

class Refuge {
  const Refuge({
    required this.id,
    required this.name,
    required this.address,
    required this.nodeId,
    required this.pos,
    required this.elev,
  });

  final String id;
  final L10n name;
  final L10n address;

  /// Graph node the refuge sits on.
  final String nodeId;
  final Point pos;
  final double elev;
}

/// Build "ROAD, Minato Bay" in 5 languages (Japanese: "みなと湾 ROAD（架空）").
L10n townAddress(L10n road) => L10n(
      en: '${road.en}, Minato Bay',
      ja: 'みなと湾 ${road.ja}（架空）',
      zhHans: '港湾 ${road.zhHans}（虚构）',
      ko: '미나토만 ${road.ko}(가상)',
      ar: '${road.ar}، خليج ميناتو (خيالي)',
    );

// ---------------------------------------------------------------------------
// Terrain

const Rect townBounds = Rect.fromLTWH(0, 0, 600, 450);

/// Coastline from north to south (land is east of it). Extends past the core area for drawing.
const List<Point> coastline = [
  Point(92, -300),
  Point(90, 0),
  Point(82, 110),
  Point(96, 220),
  Point(74, 340),
  Point(52, 450),
  Point(36, 750),
];

/// East edge of the inundation hazard zone, north to south.
const List<Point> hazardEastEdge = [
  Point(212, -300),
  Point(214, 0),
  Point(222, 140),
  Point(230, 250),
  Point(214, 350),
  Point(182, 450),
  Point(150, 750),
];

const double _farWest = -600;

/// Sea polygon (west of the coastline).
final List<Point> seaPolygon = [
  Point(_farWest, coastline.first.y),
  ...coastline,
  Point(_farWest, coastline.last.y),
];

/// Hazard (inundation) zone polygon: everything west of [hazardEastEdge] (sea included, so a pin dropped
/// in the sea counts as hazard). The map draws the sea on top, so only the land band appears striped.
final List<Point> hazardZone = [
  Point(_farWest, hazardEastEdge.first.y),
  ...hazardEastEdge,
  Point(_farWest, hazardEastEdge.last.y),
];

/// High ground: roughly east of x = 380 (elevation >= ~20 m). Used for the "HIGH GROUND" label.
const double highGroundMinX = 380;

const Point _hillTop = Point(470, 190);

/// Elevation model (m): rises ~4.5 m per 100 m eastwards plus a hill around Hill Park.
double elevationAt(Point p) {
  final dx = p.x - _hillTop.x;
  final dy = p.y - _hillTop.y;
  final bump = 8 * math.exp(-(dx * dx + dy * dy) / (2 * 90 * 90));
  return math.max(0, 1.5 + 0.045 * p.x + bump);
}

// ---------------------------------------------------------------------------
// Road graph

const Map<String, (double, double)> _rawNodes = {
  // Row A (Shrine Road), y ~ 45 -> 28
  'AW': (94, 46), 'A0': (128, 45), 'A1': (252, 40), 'A2': (372, 36), 'A3': (485, 32), 'A4': (585, 28),
  // Row B (Market Road), y ~ 164 -> 145
  'BW': (96, 164), 'B0': (132, 163), 'B1': (255, 158), 'B2': (369, 153), 'B3': (481, 149), 'B4': (583, 145),
  // Row C (Hill Road), y ~ 291 -> 272
  'CW': (90, 291), 'C0': (140, 290), 'C1': (258, 285), 'C2': (366, 280), 'C3': (476, 276), 'C4': (580, 272),
  // Row D (Station Road), y ~ 402 -> 385
  'DW': (68, 402), 'D0': (140, 400), 'D1': (262, 396), 'D2': (362, 392), 'D3': (470, 388), 'D4': (578, 385),
  // Hill Park (on top of the hill)
  'HP': (455, 205),
};

final Map<String, TownNode> nodes = {
  for (final MapEntry(key: id, value: (x, y)) in _rawNodes.entries)
    id: TownNode(id: id, x: x, y: y, elev: (elevationAt(Point(x, y)) * 10).round() / 10),
};

const List<Street> streets = [
  Street(id: 'rowA', name: roadShrine, nodeIds: ['AW', 'A0', 'A1', 'A2', 'A3', 'A4'], extendEnd: true),
  Street(id: 'rowB', name: roadMarket, nodeIds: ['BW', 'B0', 'B1', 'B2', 'B3', 'B4'], extendEnd: true),
  Street(id: 'rowC', name: roadHill, nodeIds: ['CW', 'C0', 'C1', 'C2', 'C3', 'C4'], extendEnd: true),
  Street(id: 'rowD', name: roadStation, nodeIds: ['DW', 'D0', 'D1', 'D2', 'D3', 'D4'], extendEnd: true),
  Street(id: 'col0', name: roadShore, nodeIds: ['A0', 'B0', 'C0', 'D0'], extendStart: true, extendEnd: true),
  Street(id: 'col1', name: roadPine, nodeIds: ['A1', 'B1', 'C1', 'D1'], extendStart: true, extendEnd: true),
  Street(id: 'col2', name: roadCherry, nodeIds: ['A2', 'B2', 'C2', 'D2'], extendStart: true, extendEnd: true),
  Street(id: 'col3', name: roadPark, nodeIds: ['A3', 'B3', 'C3', 'D3'], extendStart: true, extendEnd: true),
  Street(id: 'col4', name: roadEast, nodeIds: ['A4', 'B4', 'C4', 'D4'], extendStart: true, extendEnd: true),
  Street(id: 'parkLane', name: roadParkLane, nodeIds: ['C3', 'HP']),
  Street(id: 'steps', name: roadSteps, nodeIds: ['C2', 'HP'], stairs: true),
];

/// Passability was checked at 09:41 JST (shown as "Passability checked 09:41 JST" while online).
final int roadStatusCheckedAt = jstOnDemoDay(9, 41);

/// Closed road segments, keyed by "a-b" node pair (either order). Mock data, like roads.json.
final Map<String, RoadClosure> closures = {
  'D1-D2': RoadClosure(reason: closureD1D2Reason, checkedAt: roadStatusCheckedAt),
  'A2-B2': RoadClosure(reason: closureA2B2Reason, checkedAt: roadStatusCheckedAt),
};

RoadClosure? _closureFor(String a, String b) => closures['$a-$b'] ?? closures['$b-$a'];

final List<TownEdge> edges = [
  for (final s in streets)
    for (var i = 1; i < s.nodeIds.length; i++)
      TownEdge(
        id: '${s.nodeIds[i - 1]}-${s.nodeIds[i]}',
        a: s.nodeIds[i - 1],
        b: s.nodeIds[i],
        streetId: s.id,
        stairs: s.stairs,
        closure: _closureFor(s.nodeIds[i - 1], s.nodeIds[i]),
      ),
];

Street? streetById(String id) {
  for (final s in streets) {
    if (s.id == id) return s;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Refuges (flags)

Refuge _refuge(String id, L10n name, L10n road, String nodeId) {
  final n = nodes[nodeId]!;
  return Refuge(id: id, name: name, address: townAddress(road), nodeId: nodeId, pos: Point(n.x, n.y), elev: n.elev);
}

final List<Refuge> refuges = [
  _refuge('hill-park', refugeNameHillPark, roadHill, 'HP'),
  _refuge('minato-shrine', refugeNameMinatoShrine, roadShrine, 'A3'),
  _refuge('east-school', refugeNameEastSchool, roadStation, 'D4'),
];

final Refuge hillPark = refuges[0];

// ---------------------------------------------------------------------------
// Start position

/// Scenario start: on Shore Street, 40 m south of Hill Road, inside the hazard zone.
const Point townStart = startPosition;

/// Address of the start road (Shore Street).
final L10n startAddress = townAddress(roadShore);

/// "Hill Road, Minato Bay / みなと湾 高台通り（架空）"
final L10n hillRoadAddress = townAddress(roadHill);

// ---------------------------------------------------------------------------
// Address lookup (S10 "Show this location")

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

double _distToSegment(Point p, TownNode a, TownNode b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return _hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

/// Multilingual address of the nearest named street (or refuge, if within 25 m).
L10n addressAt(Point p) {
  for (final r in refuges) {
    if (_hypot(p.x - r.pos.x, p.y - r.pos.y) <= 25) {
      final a = r.address;
      return L10n(
        en: '${r.name.en}, ${a.en}',
        ja: '${a.ja} ${r.name.ja}',
        zhHans: '${a.zhHans} ${r.name.zhHans}',
        ko: '${a.ko} ${r.name.ko}',
        ar: '${r.name.ar}، ${a.ar}',
      );
    }
  }
  var bestD = double.infinity;
  Street? best;
  for (final e in edges) {
    final d = _distToSegment(p, nodes[e.a]!, nodes[e.b]!);
    if (d < bestD) {
      bestD = d;
      best = streetById(e.streetId);
    }
  }
  return townAddress(best?.name ?? roadShore);
}
