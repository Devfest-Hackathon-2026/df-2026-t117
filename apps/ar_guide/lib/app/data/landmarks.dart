// Registered AR landmarks (requirements F39, like landmarks.json). Fictional town data, NOT real places.
// Port of mocks/evacuate/src/data/landmarks.ts. In the mock the "recognition result" is the demo flag
// `ar.landmarkFound`.
import 'dart:math' as math;

import '../state/types.dart';
import 'names.dart';

enum LandmarkKind { tsunamiEvacuationSign, evacuationRouteSign, trafficMirror }

class Landmark {
  const Landmark({required this.id, required this.kind, required this.name, required this.pos});

  final String id;
  final LandmarkKind kind;
  final L10n name;

  /// Town meters (x = east, y = south).
  final Point pos;
}

const List<Landmark> landmarks = [
  // Corner of Shore Street x Hill Road: first turn (Right) of the main scenario route.
  Landmark(id: 'lm-shore-hill-sign', kind: LandmarkKind.tsunamiEvacuationSign, name: kindNameTsunamiEvacuationSign, pos: Point(148, 284)),
  Landmark(id: 'lm-shore-hill-mirror', kind: LandmarkKind.trafficMirror, name: kindNameTrafficMirror, pos: Point(132, 296)),
  // Pine Street x Hill Road
  Landmark(id: 'lm-pine-hill-sign', kind: LandmarkKind.tsunamiEvacuationSign, name: kindNameTsunamiEvacuationSign, pos: Point(264, 279)),
  // Foot of Hill Steps (Cherry Street x Hill Road): second turn (Left)
  Landmark(id: 'lm-steps-sign', kind: LandmarkKind.evacuationRouteSign, name: kindNameEvacuationRouteSign, pos: Point(372, 274)),
  // Park Street x Hill Road
  Landmark(id: 'lm-park-hill-sign', kind: LandmarkKind.tsunamiEvacuationSign, name: kindNameTsunamiEvacuationSign, pos: Point(482, 270)),
  // Shore Street x Market Road / Station Road
  Landmark(id: 'lm-shore-market-sign', kind: LandmarkKind.tsunamiEvacuationSign, name: kindNameTsunamiEvacuationSign, pos: Point(138, 157)),
  Landmark(id: 'lm-shore-station-sign', kind: LandmarkKind.tsunamiEvacuationSign, name: kindNameTsunamiEvacuationSign, pos: Point(146, 394)),
];

/// Max distance (m) between a landmark and the next turn for it to be used for alignment.
const double landmarkMatchRadiusM = 40;

/// Registered sign closest to [p] within [radiusM] (signs preferred over mirrors), or null.
Landmark? landmarkNear(Point p, [double radiusM = landmarkMatchRadiusM]) {
  Landmark? best;
  var bestScore = double.infinity;
  for (final lm in landmarks) {
    final dx = lm.pos.x - p.x;
    final dy = lm.pos.y - p.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > radiusM) continue;
    final score = d + (lm.kind == LandmarkKind.trafficMirror ? 1000 : 0);
    if (score < bestScore) {
      best = lm;
      bestScore = score;
    }
  }
  return best;
}
