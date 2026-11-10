// Margin check F85 (requirements 14.3) and the approximate-location rules (14.7-6).
import 'package:ar_guide/app/data/alerts.dart';
import 'package:ar_guide/app/data/town.dart';
import 'package:ar_guide/app/logic/margin.dart';
import 'package:ar_guide/app/state/scenarios.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter_test/flutter_test.dart';

const MarginThresholds th = (marginAmpleM: 10, hugeMinElevM: 20);

MarginLevel judge(double elev, ExpectedHeight h) => judgeMargin(elev, h, th).level;

AppState tsunamiState(ExpectedHeight h, Point position, double accuracyM) {
  final alert = alertTsunami.copyWith(level: AlertLevel.emergency, expectedHeight: h);
  final base = createBaseState(Lang.en);
  return base.copyWith(
    alerts: [alert],
    peakExpectedHeight: h,
    gps: base.gps.apply(GpsPatch(position: position, accuracyM: accuracyM)),
  );
}

void main() {
  group('judgeMargin (F85)', () {
    test('elevation - height >= 10 is ample', () {
      expect(judge(13, ExpectedHeight.m3), MarginLevel.ample);
      expect(judgeMargin(13, ExpectedHeight.m3, th).marginM, 10);
    });

    test('0 <= difference < 10 is low', () {
      expect(judge(12.9, ExpectedHeight.m3), MarginLevel.low);
      expect(judge(5, ExpectedHeight.m5), MarginLevel.low);
    });

    test('below the forecast is short', () {
      expect(judge(4.9, ExpectedHeight.m5), MarginLevel.short);
    });

    test('forecast over 10 m below 20 m elevation is short, even with a positive difference', () {
      expect(judge(19.9, ExpectedHeight.over10), MarginLevel.short);
      expect(judge(19.9, ExpectedHeight.huge), MarginLevel.short);
      expect(judge(19.9, ExpectedHeight.m10), MarginLevel.low);
      expect(judge(20, ExpectedHeight.huge), MarginLevel.ample);
    });

    test('high counts as 3 m', () {
      expect(judge(13, ExpectedHeight.high), MarginLevel.ample);
      expect(judge(2.9, ExpectedHeight.high), MarginLevel.short);
    });

    test('thresholds can be changed', () {
      expect(judgeMargin(13, ExpectedHeight.m3, (marginAmpleM: 11, hugeMinElevM: 20)).level, MarginLevel.low);
      expect(judgeMargin(15, ExpectedHeight.huge, (marginAmpleM: 3, hugeMinElevM: 14)).level, MarginLevel.ample);
    });
  });

  group('heights', () {
    test('order and the highest announced', () {
      expect(heightRank(ExpectedHeight.high), heightRank(ExpectedHeight.m3));
      expect(heightRank(ExpectedHeight.huge), heightRank(ExpectedHeight.over10));
      expect(maxHeight(ExpectedHeight.m5, ExpectedHeight.m3), ExpectedHeight.m5);
      expect(maxHeight(null, ExpectedHeight.m3), ExpectedHeight.m3);
    });

    test('raise steps stop over 10 m', () {
      expect(raisedHeight(null), ExpectedHeight.m1);
      expect(raisedHeight(ExpectedHeight.m3), ExpectedHeight.m5);
      expect(raisedHeight(ExpectedHeight.high), ExpectedHeight.m5);
      expect(raisedHeight(ExpectedHeight.over10), isNull);
    });

    test('required refuge elevation', () {
      expect(requiredRefugeElevM(ExpectedHeight.m3, th), 13);
      expect(requiredRefugeElevM(ExpectedHeight.huge, th), 20);
      expect(requiredRefugeElevM(ExpectedHeight.m10, th), 20);
    });
  });

  group('location is approximate (14.7-6)', () {
    test('short at the lowest point only: shown as low, not forced', () {
      const p = Point(380, 283);
      final m = assessMargin(tsunamiState(ExpectedHeight.huge, p, 180), p);
      expect(m.approximate, isTrue);
      expect(m.elevMinM, lessThan(20));
      expect(m.elevMaxM, greaterThanOrEqualTo(20));
      expect(m.level, MarginLevel.low);
      expect(m.mustMove, isFalse);
    });

    test('short even at the highest point: must move', () {
      const p = Point(100, 400);
      final m = assessMargin(tsunamiState(ExpectedHeight.huge, p, 110), p);
      expect(m.approximate, isTrue);
      expect(m.level, MarginLevel.short);
      expect(m.mustMove, isTrue);
    });

    test('exact location: one elevation, not a range', () {
      const p = Point(380, 283);
      final m = assessMargin(tsunamiState(ExpectedHeight.m3, p, 10), p);
      expect(m.approximate, isFalse);
      expect(m.elevMinM, m.elevMaxM);
      expect(m.elevMinM, closeTo(elevationAt(p), 1e-9));
    });

    test('designated site: within half the error radius of the circle center', () {
      final near = Point(hillPark.pos.x + 80, hillPark.pos.y);
      expect(assessMargin(tsunamiState(ExpectedHeight.m3, near, 180), near).designated?.id, 'hill-park');
    });

    test('a refuge merely inside the error circle does not count', () {
      final far = Point(hillPark.pos.x, hillPark.pos.y + 120);
      expect(assessMargin(tsunamiState(ExpectedHeight.m3, far, 180), far).designated, isNull);
    });

    test('arrived within 20 m counts whatever the accuracy', () {
      final at = Point(hillPark.pos.x + 15, hillPark.pos.y);
      expect(assessMargin(tsunamiState(ExpectedHeight.m3, at, 10), at).designated?.id, 'hill-park');
    });

    test('no location: no elevation and no level', () {
      const p = Point(310, 283);
      final s = tsunamiState(ExpectedHeight.m3, p, 10);
      final denied = s.copyWith(gps: s.gps.apply(const GpsPatch(permission: GpsPermission.denied)));
      final m = assessMargin(denied, p);
      expect(m.elevMinM, isNull);
      expect(m.level, isNull);
      expect(m.designated, isNull);
      expect(m.mustMove, isFalse);
    });
  });
}
