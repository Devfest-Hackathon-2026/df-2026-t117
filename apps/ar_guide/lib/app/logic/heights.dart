// Expected tsunami heights (F84 / F89) and the margin check table (F85, requirements 14.3).
// Port of mocks/evacuate/src/logic/heights.ts.
import 'dart:math' as math;

import '../state/derive.dart';
import '../state/types.dart';

// ---------------------------------------------------------------------------
// Expected heights

/// Demo steps for "raise the expected height" (JMA categories).
const List<ExpectedHeight> heightSteps = [
  ExpectedHeight.m1,
  ExpectedHeight.m3,
  ExpectedHeight.m5,
  ExpectedHeight.m10,
  ExpectedHeight.over10,
];

/// Ordering of heights: 1 < 3 = high < 5 < 10 < over10 = huge.
int heightRank(ExpectedHeight h) => switch (h) {
      ExpectedHeight.m1 => 1,
      ExpectedHeight.m3 || ExpectedHeight.high => 3,
      ExpectedHeight.m5 => 5,
      ExpectedHeight.m10 => 10,
      ExpectedHeight.over10 || ExpectedHeight.huge => 11,
    };

/// Height used in "elevation - expected height": huge / over10 -> 10 (plus the over-10 rule), high -> 3.
double heightForCheckM(ExpectedHeight h) => switch (h) {
      ExpectedHeight.m1 => 1,
      ExpectedHeight.m3 || ExpectedHeight.high => 3,
      ExpectedHeight.m5 => 5,
      ExpectedHeight.m10 || ExpectedHeight.over10 || ExpectedHeight.huge => 10,
    };

/// "10 m 超" or "巨大".
bool isOver10(ExpectedHeight h) => h == ExpectedHeight.huge || h == ExpectedHeight.over10;

ExpectedHeight? maxHeight(ExpectedHeight? a, ExpectedHeight? b) {
  if (a == null) return b;
  if (b == null) return a;
  return heightRank(b) > heightRank(a) ? b : a;
}

/// Next higher step (demo "raise"), or null when already over 10 m.
ExpectedHeight? raisedHeight(ExpectedHeight? h) {
  final rank = h == null ? 0 : heightRank(h);
  for (final s in heightSteps) {
    if (heightRank(s) > rank) return s;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Margin check (decision table in 14.3)

/// ample = calm colour, "Stay here." / low = yellow, "Go higher." / short = red, back to evacuate ("Go higher. NOW").
enum MarginLevel { ample, low, short }

/// Default 10 m / 20 m. An [AppState] gives these through [marginThresholds].
typedef MarginThresholds = ({double marginAmpleM, double hugeMinElevM});

MarginThresholds marginThresholds(AppState s) => (marginAmpleM: s.marginAmpleM, hugeMinElevM: s.hugeMinElevM);

({MarginLevel level, double marginM}) judgeMargin(double elevM, ExpectedHeight h, MarginThresholds th) {
  final marginM = elevM - heightForCheckM(h);
  if (marginM < 0 || (isOver10(h) && elevM < th.hugeMinElevM)) return (level: MarginLevel.short, marginM: marginM);
  if (marginM < th.marginAmpleM) return (level: MarginLevel.low, marginM: marginM);
  return (level: MarginLevel.ample, marginM: marginM);
}

/// Lowest refuge elevation that is "ample" for this forecast (destination filter, 7.4 / 14.4).
double requiredRefugeElevM(ExpectedHeight h, MarginThresholds th) =>
    math.max(heightForCheckM(h) + th.marginAmpleM, isOver10(h) ? th.hugeMinElevM : 0);

/// Expected height the guidance uses: the highest announced so far (a downgrade does not loosen it, F8A).
ExpectedHeight? heightInUse(AppState state) =>
    maxHeight(state.peakExpectedHeight, mostSevere(state.alerts, HazardType.tsunami)?.expectedHeight);

/// Required refuge elevation for the route (null = no tsunami alert / no forecast: any refuge).
double? routeMinElevM(AppState state) {
  final h = heightInUse(state);
  return h == null ? null : requiredRefugeElevM(h, marginThresholds(state));
}
