// Margin check on high ground (FB2: F83-F85, requirements 14.3). Port of mocks/evacuate/src/logic/margin.ts.
// The pure table lives in heights.dart; this file adds the position-dependent parts.
// The web's useMargin() is `context.margin` / `store.margin`.
import 'dart:math' as math;

import '../data/town.dart';
import '../state/derive.dart';
import '../state/types.dart';
import 'geometry.dart';
import 'heights.dart';
import 'nav.dart';

export 'heights.dart';

/// Lowest / highest elevation within [radiusM] of [p] (center, 8 points at r/2 and 8 at r).
({double min, double max}) elevationRange(Point p, double radiusM) {
  var min = elevationAt(p);
  var max = min;
  for (final f in const [0.5, 1.0]) {
    for (var i = 0; i < 8; i++) {
      final a = (i * math.pi) / 4;
      final e = elevationAt(Point(p.x + math.cos(a) * radiusM * f, p.y + math.sin(a) * radiusM * f));
      min = math.min(min, e);
      max = math.max(max, e);
    }
  }
  return (min: min, max: max);
}

class MarginInfo {
  const MarginInfo({
    required this.heightInUse,
    required this.heightNow,
    required this.elevMinM,
    required this.elevMaxM,
    required this.approximate,
    required this.level,
    required this.marginM,
    required this.mustMove,
    required this.designated,
  });

  /// Height used for the check (highest announced) and the current forecast.
  final ExpectedHeight? heightInUse;
  final ExpectedHeight? heightNow;

  /// Elevation of the current position (a range when the location is approximate). null = no location.
  final double? elevMinM;
  final double? elevMaxM;
  final bool approximate;

  /// Level shown (colour of the card, headline on S06). null when there is no forecast or no location.
  /// Uses the lowest elevation in the circle, except that "short" from the lowest point alone is shown as
  /// "low" (yellow "Go higher." + "Location approximate") when the highest point is not short (rule b).
  final MarginLevel? level;

  /// elevation (lowest in the circle) - expected height
  final double? marginM;

  /// "Not enough" for certain: with an approximate location, even the highest elevation in the circle is
  /// short. Only this may force S06 back to evacuate (AlertEffects; rule b). Display-only checks never do.
  final bool mustMove;

  /// At a designated tsunami evacuation site (refuge flag): instruction stays "Stay here." + staff line.
  /// (i) Arrived: the walk position is within arrivalRadiusM of the refuge, whatever the GPS accuracy.
  /// (ii) Approximate location: the circle's center is within half the error radius of the refuge.
  /// A refuge that is merely somewhere inside the error circle does not count (rule a). No location: null.
  final Refuge? designated;
}

/// Pure margin assessment at [position] (the walk position on the route).
MarginInfo assessMargin(AppState state, Point position) {
  final approximate = isLocationApproximate(state);
  final noLocation = state.gps.permission == GpsPermission.denied && state.manualPin == null;
  final heightNow = mostSevere(state.alerts, HazardType.tsunami)?.expectedHeight;
  final height = heightInUse(state);
  final radius = approximate && !noLocation ? state.gps.accuracyM : 0.0;
  final elev = elevationAt(position);
  final range = noLocation ? null : (radius > 0 ? elevationRange(position, radius) : (min: elev, max: elev));
  final th = marginThresholds(state);
  final low = range != null && height != null ? judgeMargin(range.min, height, th) : null;
  final high = range != null && height != null ? judgeMargin(range.max, height, th) : null;
  final mustMove = high?.level == MarginLevel.short;
  final level = low == null ? null : (low.level == MarginLevel.short && !mustMove ? MarginLevel.low : low.level);
  Refuge? designated;
  if (!noLocation) {
    final within = math.max(arrivalRadiusM, radius / 2);
    var best = double.infinity;
    for (final r in refuges) {
      final d = dist(position, r.pos);
      if (d <= within && d < best) {
        best = d;
        designated = r;
      }
    }
  }
  return MarginInfo(
    heightInUse: height,
    heightNow: heightNow,
    elevMinM: range?.min,
    elevMaxM: range?.max,
    approximate: approximate,
    level: level,
    marginM: low?.marginM,
    mustMove: mustMove,
    designated: designated,
  );
}
