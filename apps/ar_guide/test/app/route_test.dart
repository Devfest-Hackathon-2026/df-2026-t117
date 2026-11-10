// Port of mocks/evacuate/src/logic/__check__.ts.
import 'package:ar_guide/app/data/town.dart';
import 'package:ar_guide/app/logic/nav.dart';
import 'package:ar_guide/app/logic/route.dart';
import 'package:ar_guide/app/state/scenarios.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final online = computeRoute(townStart, online: true);

  test('start matches the scenario, lies on a road, inside the hazard zone', () {
    expect(townStart, startPosition);
    expect(snapToRoad(townStart).distM, lessThan(0.5));
    expect(pointInHazard(townStart), isTrue);
  });

  test('online route: Hill Park, verified, avoids closures, uses stairs', () {
    expect(online.refuge.id, hillPark.id);
    expect(online.verified, isTrue);
    expect(online.segments.every((s) => !s.closed), isTrue);
    expect(online.hasStairs, isTrue);
  });

  test('leaves the hazard zone within 150 m', () {
    var exitM = -1;
    for (var d = 0; d <= online.totalM; d++) {
      if (!pointInHazard(pointAtDistance(online.points, d.toDouble()))) {
        exitM = d;
        break;
      }
    }
    expect(exitM, inInclusiveRange(0, 150));
  });

  test('first instruction is Right about 40 m', () {
    expect(findTurns(online.points).any((t) => t.direction == TurnDirection.right), isTrue);
    final first = nextTurnAt(online.points, 0)!;
    expect(first.direction, TurnDirection.right);
    expect(first.distanceM, closeTo(40, 1));
  });

  test('arrival at the end of the route only', () {
    expect(isArrived(pointAtDistance(online.points, online.totalM), online.refuge), isTrue);
    expect(nextTurnAt(online.points, online.totalM), isNull);
    expect(isArrived(pointAtDistance(online.points, 0), online.refuge), isFalse);
  });

  test('offline route is unverified and still reaches a refuge', () {
    final offline = computeRoute(townStart, online: false);
    expect(offline.verified, isFalse);
    expect(offline.points.length, greaterThan(1));
  });

  test('online routes from other origins never use a closed road beyond the snapped one', () {
    const origins = [Point(300, 394), Point(370, 100), Point(200, 160), Point(100, 420), Point(560, 300), Point(30, 200)];
    for (final o in origins) {
      final snapId = snapToRoad(o).edge.id;
      final r = computeRoute(o, online: true);
      expect(r.segments.where((s) => s.closed && s.lengthM > 0 && s.edgeId != snapId), isEmpty, reason: '$o');
    }
  });

  test('graph has the same size as the web', () {
    expect(edges.length, greaterThan(20));
    expect(closures.keys, containsAll(['D1-D2', 'A2-B2']));
  });

  group('destination filter (14.4)', () {
    const nearEastSchool = Point(570, 385);

    test('no limit: the cheapest refuge', () {
      expect(computeRoute(nearEastSchool, online: true).refuge.id, 'east-school');
    });

    test('a refuge lower than required is skipped', () {
      final school = refuges.firstWhere((r) => r.id == 'east-school');
      expect(computeRoute(nearEastSchool, online: true, minRefugeElevM: school.elev + 0.1).refuge.id, isNot('east-school'));
    });

    test('nothing high enough: the highest reachable refuge', () {
      expect(computeRoute(nearEastSchool, online: true, minRefugeElevM: 110).refuge.id, 'hill-park');
    });
  });
}
