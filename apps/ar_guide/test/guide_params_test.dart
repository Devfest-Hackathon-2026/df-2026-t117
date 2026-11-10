import 'package:ar_guide/src/floor_arrow.dart';
import 'package:ar_guide/src/guide_params.dart';
import 'package:ar_guide/src/platform.dart';
import 'package:ar_guide/src/strings.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuideParams.fromUri', () {
    test('no link -> demo default', () {
      final p = GuideParams.fromUri(null);
      expect(p.turn, Turn.right);
      expect(p.distanceM, 12);
      expect(p.dest, 'Hill Park');
      expect(p.destJa, '高台公園');
      expect(p.lang, Lang.en);
      expect(p.bearingDeg, isNull);
      expect(p.fromLink, isFalse);
    });

    test('full link', () {
      final p = GuideParams.fromUri(
          Uri.parse('tasuku-ar://guide?turn=left&dist=30&dest=Hill%20Park&lang=ja&bearing=-90&mode=compass'));
      expect(p.turn, Turn.left);
      expect(p.distanceM, 30);
      expect(p.destJa, '高台公園');
      expect(p.lang, Lang.ja);
      expect(p.bearingDeg, 270);
      expect(p.mode, ArMode.compass);
      expect(p.fromLink, isTrue);
    });

    test('invalid values fall back or are clamped', () {
      final p = GuideParams.fromUri(Uri.parse(
          'tasuku-ar://guide?turn=up&dist=-5&lang=xx&bearing=abc&dest=%E2%80%AE${'a' * 80}'));
      expect(p.turn, Turn.right);
      expect(p.distanceM, 0);
      expect(p.lang, Lang.en);
      expect(p.bearingDeg, isNull);
      expect(p.dest.length, GuideParams.maxNameLength);
      expect(p.dest.contains(String.fromCharCode(0x202e)), isFalse);
      expect(p.destJa, isNull);
    });

    test('other scheme or host is ignored', () {
      expect(GuideParams.fromUri(Uri.parse('https://guide?turn=left')).turn, Turn.right);
      expect(GuideParams.fromUri(Uri.parse('tasuku-ar://other?turn=left')).turn, Turn.right);
    });

    test('broken %-encoding -> demo default, no exception', () {
      final uri = Uri.parse('tasuku-ar://guide?turn=left&dest=%E0%A4');
      expect(() => uri.queryParameters, throwsFormatException);
      final p = GuideParams.fromUri(uri);
      expect(p.turn, Turn.right);
      expect(p.dest, 'Hill Park');
      expect(p.fromLink, isFalse);
    });

    test('zh alias', () {
      expect(GuideParams.fromUri(Uri.parse('tasuku-ar://guide?lang=zh')).lang, Lang.zhHans);
    });
  });

  test('angleDiff wraps', () {
    expect(angleDiff(10, 350), 20);
    expect(angleDiff(350, 10), -20);
    expect(angleDiff(180, 0), 180);
  });

  test('map marker and camera arrow always agree', () {
    for (var bearing = 0.0; bearing < 360; bearing += 37) {
      for (var heading = 0.0; heading < 360; heading += 23) {
        final arrow = arrowAngle(bearing: bearing, heading: heading);
        final marker = mapMarkerAngle(bearing: bearing, heading: heading);
        expect((arrow + marker) % 360, closeTo(0, 1e-9));
      }
    }
    // Arrow straight ahead -> marker along the route (up on the schematic map).
    expect(arrowAngle(bearing: 80, heading: 80), 0);
    expect(mapMarkerAngle(bearing: 80, heading: 80), 0);
    // Facing 30 degrees left of the route: the arrow turns right, the marker leans left of the route.
    expect(arrowAngle(bearing: 80, heading: 50), 30);
    expect(mapMarkerAngle(bearing: 80, heading: 50), -30);
    // No `bearing` in the link: the first heading becomes the bearing, so both start at 0.
    const firstHeading = 212.0;
    expect(arrowAngle(bearing: firstHeading, heading: firstHeading), 0);
    expect(mapMarkerAngle(bearing: firstHeading, heading: firstHeading), 0);
  });

  test('turn around: on above 120, off below 110, kept in between', () {
    final latch = TurnAroundLatch();
    expect(latch.update(119), isFalse);
    expect(latch.update(121), isTrue);
    expect(latch.update(115), isTrue);
    expect(latch.update(109), isFalse);
    expect(latch.update(-121), isTrue);
    expect(latch.update(-115), isTrue);
    expect(latch.update(null), isFalse);
    expect(latch.update(180), isTrue);
  });

  test('turn around is translated in every language', () {
    for (final lang in Lang.values) {
      expect(S.of(lang).turnAround, isNotEmpty);
    }
  });

  group('road band', () {
    const size = Size(390, 844);
    List<Offset> band({Turn turn = Turn.straight, double delta = 0, double pitch = 30, double sheet = 96}) =>
        FloorArrowPainter.screenPolygon(size,
            turn: turn, deltaDeg: delta, pitchDeg: pitch, bottomObstruction: sheet);
    double halfWidth(List<Offset> p, int i) => (p[p.length - 1 - i].dx - p[i].dx).abs() / 2;

    test('wide near the bottom centre, narrowing with distance', () {
      final p = band();
      expect((p.first + p.last).dx / 2, closeTo(195, 0.5));
      expect(p.first.dy, greaterThan(size.height - 96));
      for (var i = 1; i <= 8; i++) {
        expect(halfWidth(p, i), lessThan(halfWidth(p, i - 1)));
      }
    });

    for (final pitch in [4.0, 15.0, 30.0, 60.0, 90.0]) {
      for (final turn in Turn.values) {
        test('stays on the road below the cards: $turn, pitch $pitch', () {
          final horizon = FloorArrowPainter.horizonY(size, pitch);
          for (final o in band(turn: turn, pitch: pitch)) {
            expect(o.dy, greaterThan(horizon));
            expect(o.dy, greaterThan(size.height * 0.3));
          }
        });
      }
    }

    test('the horizon rises as the phone tilts down', () {
      expect(FloorArrowPainter.horizonY(size, 40), lessThan(FloorArrowPainter.horizonY(size, 10)));
    });

    test('the far end swings to the side of the bearing, around a fixed root', () {
      final centre = band();
      final right = band(delta: 30);
      final left = band(delta: -30);
      final mid = centre.length ~/ 2;
      expect(right[mid].dx, greaterThan(centre[mid].dx));
      expect(left[mid].dx, lessThan(centre[mid].dx));
      // The midpoint of the two root corners drifts a little: after the swing one corner is nearer.
      expect((right.first + right.last).dx / 2, closeTo(195, 8));
      // Behind the user: clamped, never folded back.
      expect(band(delta: 170)[mid].dx, band(delta: 60)[mid].dx);
    });

    for (final delta in [-180.0, -121.0, -119.0, -80.0, -60.0, 0.0, 60.0, 80.0, 119.0, 121.0, 180.0]) {
      test('stays finite and near the screen: delta $delta', () {
        for (final turn in Turn.values) {
          for (final pitch in [-10.0, 4.0, 15.0, 30.0, 60.0, 78.0, 90.0]) {
            for (final sheet in [96.0, 292.0]) {
              for (final o in band(turn: turn, delta: delta, pitch: pitch, sheet: sheet)) {
                expect(o.isFinite, isTrue, reason: '$turn pitch $pitch sheet $sheet');
                // At a 60 degree swing the far end heads for x/z = tan 60, about 2.6 screen widths from the centre.
                expect(o.dx, inInclusiveRange(-size.width * 3, size.width * 4), reason: '$turn pitch $pitch sheet $sheet');
                expect(o.dy, inInclusiveRange(-size.height, size.height * 2), reason: '$turn pitch $pitch sheet $sheet');
              }
            }
          }
        }
      });
    }

    test('the head bends to the turn side', () {
      final right = band(turn: Turn.right);
      final left = band(turn: Turn.left);
      final tip = (right.length ~/ 2);
      expect(right[tip].dx, greaterThan(195));
      expect(left[tip].dx, lessThan(195));
    });

    test('the root stays visible above an expanded sheet', () {
      const expanded = 292.0;
      final p = band(sheet: expanded);
      expect(p.first.dy, lessThanOrEqualTo(size.height - expanded + 15));
      expect(p.first.dy, greaterThan(size.height - expanded - 1));
    });
  });

  test('right arrow bends to +x, left to -x', () {
    expect(FloorArrowPainter.centreLine(Turn.right).last.dx, greaterThan(0));
    expect(FloorArrowPainter.centreLine(Turn.left).last.dx, lessThan(0));
    expect(FloorArrowPainter.centreLine(Turn.straight).last.dx, 0);
  });
}
