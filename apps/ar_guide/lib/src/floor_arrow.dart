// Compass mode (no ARCore): a tapered guide band painted on the road, as on the mock's S11 (F37).
//
// A simple pinhole camera held [cameraHeightM] above a flat ground looks [pitchDeg] below the horizon.
// The band starts at the lower centre of the visible camera area (wide), runs away from the user
// (narrowing with perspective) and bends towards the turn at its far end, with the arrow head there.
// The whole band swings around its root by (route bearing - phone heading). The phone tilt moves the
// horizon and changes the perspective. There is no road detection: the ground is assumed.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'guide_params.dart';

/// "Turn around" U-turn arrow (the mock's ARROW_UTURN, 390-wide coordinates): fixed, so it never swings.
class UTurnArrowPainter extends CustomPainter {
  UTurnArrowPainter({required this.sheetHeight}) : super(repaint: sheetHeight);

  /// Height of the MAP sheet (px): the arrow stays above it.
  final ValueListenable<double> sheetHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 390;
    canvas.save();
    canvas.translate(0, size.height - sheetHeight.value - 24 - 452 * k);
    canvas.scale(k);
    final body = Path()
      ..moveTo(240, 452)
      ..lineTo(240, 300)
      ..cubicTo(240, 230, 150, 230, 150, 300)
      ..lineTo(150, 352);
    final head = Path()
      ..moveTo(150, 392)
      ..lineTo(126, 348)
      ..lineTo(174, 348)
      ..close();
    void draw(Color color, double bodyWidth, double headStroke) {
      canvas.drawPath(
        body,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = bodyWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(head, Paint()..color = color);
      canvas.drawPath(
        head,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = headStroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw(FloorArrowPainter._ink, 30, 12);
    draw(FloorArrowPainter._yellow, 19, 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(UTurnArrowPainter old) => old.sheetHeight != sheetHeight;
}

class FloorArrowPainter extends CustomPainter {
  FloorArrowPainter({
    required this.turn,
    required this.deltaDeg,
    required this.pitchDeg,
    required this.sheetHeight,
  }) : super(repaint: sheetHeight);

  final Turn turn;

  /// Clockwise angle from where the phone points to the route bearing (deg).
  final double deltaDeg;

  /// Camera angle below the horizon (deg).
  final double pitchDeg;

  /// Height of the MAP sheet (px): the root of the band stays just above it, even when it is expanded.
  final ValueListenable<double> sheetHeight;

  static const cameraHeightM = 1.4;

  /// Horizontal field of view of the screen width (portrait), approximate for phone main cameras.
  static const hFovDeg = 52.0;

  /// The band always runs away from the user, so it swings at most this far to either side.
  /// Beyond it the far end would come towards the camera; past 120 deg the screen shows "Turn around".
  static const maxSwingDeg = 60.0;

  /// How far the root of the band tucks under the sheet (px).
  static const _rootTuck = 14.0;

  static const _yellow = Color(0xFFFFD54F);
  static const _ink = Color(0xFF16141A);

  /// Centre line on the ground: x = right, y = forward, origin at the root of the band.
  static List<Offset> centreLine(Turn turn, {double length = 3, double radius = 0.6, double exit = 0.4}) {
    if (turn == Turn.straight) {
      return [for (var i = 0; i <= 8; i++) Offset(0, length * i / 8)];
    }
    final s = turn == Turn.left ? -1.0 : 1.0;
    final turnAt = length - radius;
    return [
      for (var i = 0; i < 8; i++) Offset(0, turnAt * i / 8),
      for (var i = 0; i <= 12; i++)
        Offset(
          s * (radius - radius * math.cos(math.pi / 2 * i / 12)),
          turnAt + radius * math.sin(math.pi / 2 * i / 12),
        ),
      for (var i = 1; i <= 3; i++) Offset(s * (radius + exit * i / 3), length),
    ];
  }

  /// Horizon on the screen (px from the top; may be off-screen when the phone points at the floor).
  static double horizonY(Size size, double pitchDeg) =>
      size.height / 2 - _focal(size) * math.tan(_theta(pitchDeg));

  static double _focal(Size size) => size.width / 2 / math.tan(hFovDeg / 2 * math.pi / 180);
  static double _theta(double pitchDeg) => pitchDeg.clamp(4.0, 78.0) * math.pi / 180;

  /// Outline of the band on the screen. Order: one side from the root, the head, the other side back.
  static List<Offset> screenPolygon(
    Size size, {
    required Turn turn,
    required double deltaDeg,
    required double pitchDeg,
    required double bottomObstruction,
  }) {
    final w = size.width;
    final h = size.height;
    final theta = _theta(pitchDeg);
    final sinT = math.sin(theta);
    final cosT = math.cos(theta);
    final f = _focal(size);
    final cy = h / 2;
    final horizon = horizonY(size, pitchDeg);

    // Root and corner are chosen on the screen, then converted to the ground.
    final rootY = math.max(
      math.min(h, h - bottomObstruction + _rootTuck),
      math.max(horizon, 0) + h * 0.2,
    );
    final cornerY = math.max(
      math.min(math.max(horizon + h * 0.12, h * 0.46), rootY - h * 0.14),
      horizon + h * 0.02,
    );
    double groundZ(double y) {
      final v = (cy - y) / f;
      return cameraHeightM * (cosT + v * sinT) / (sinT - v * cosT);
    }

    double zc(double z) => cameraHeightM * sinT + z * cosT;
    double world(double z, double px) => px * zc(z) / f;

    final zRoot = groundZ(rootY);
    final zCorner = math.min(groundZ(cornerY), zRoot + 25);
    final length = zCorner - zRoot;

    final halfRoot = world(zRoot, w * 0.17);
    final halfCorner = world(zCorner, w * 0.055);
    final lateral = world(zCorner, w * 0.38);
    final straight = turn == Turn.straight;
    final radius = math.min(lateral * 0.35, length * 0.45);
    final exit = lateral * 0.2;
    final headLen = straight ? math.min(lateral * 0.45, length * 0.35) : lateral * 0.45;
    // A band running sideways is foreshortened in depth, so it needs more width on the ground.
    final halfExit = straight ? halfCorner : math.max(halfCorner, length * 0.07);
    final headHalf = straight ? halfCorner * 2.4 : math.max(halfCorner * 2.4, length * 0.18);

    final line = centreLine(turn, length: length, radius: radius, exit: exit);
    double halfAt(int i) {
      final p = line[i];
      if (straight || p.dy <= length - radius && p.dx == 0) {
        return halfRoot + (halfCorner - halfRoot) * (p.dy / length).clamp(0.0, 1.0);
      }
      return halfCorner + (halfExit - halfCorner) * (p.dx.abs() / radius).clamp(0.0, 1.0);
    }

    final sideA = <Offset>[];
    final sideB = <Offset>[];
    for (var i = 0; i < line.length; i++) {
      final t = _unit(line[math.min(i + 1, line.length - 1)] - line[math.max(i - 1, 0)]);
      final n = Offset(t.dy, -t.dx);
      final half = halfAt(i);
      sideA.add(line[i] - n * half);
      sideB.add(line[i] + n * half);
    }
    final end = line.last;
    final t = _unit(end - line[line.length - 2]);
    final n = Offset(t.dy, -t.dx);
    final outline = [
      ...sideA,
      end - n * headHalf,
      end + t * headLen,
      end + n * headHalf,
      ...sideB.reversed,
    ];

    final delta = deltaDeg.clamp(-maxSwingDeg, maxSwingDeg) * math.pi / 180;
    final cosD = math.cos(delta);
    final sinD = math.sin(delta);
    return [
      for (final p in outline)
        () {
          // Swing clockwise (seen from above) around the root, then project.
          final x = p.dx * cosD + p.dy * sinD;
          final z = zRoot - p.dx * sinD + p.dy * cosD;
          // Never nearer than a fraction of the root's depth, which keeps every point finite and near the screen.
          final depth = math.max(zc(zRoot) * 0.4, zc(z));
          final yc = -cameraHeightM * cosT + z * sinT;
          return Offset(w / 2 + f * x / depth, cy - f * yc / depth);
        }(),
    ];
  }

  static Offset _unit(Offset v) {
    final d = v.distance;
    return d < 1e-9 ? const Offset(0, 1) : v / d;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addPolygon(
        screenPolygon(
          size,
          turn: turn,
          deltaDeg: deltaDeg,
          pitchDeg: pitchDeg,
          bottomObstruction: sheetHeight.value,
        ),
        true,
      );
    canvas.drawPath(path, Paint()..color = _yellow.withValues(alpha: 0.72));
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(FloorArrowPainter old) =>
      old.turn != turn ||
      old.sheetHeight != sheetHeight ||
      (old.deltaDeg - deltaDeg).abs() > 0.2 ||
      (old.pitchDeg - pitchDeg).abs() > 0.2;
}
