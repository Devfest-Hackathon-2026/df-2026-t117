// Pictograms (original artwork). Same drawing data as mocks/evacuate/src/components/pictograms.
import 'package:flutter/widgets.dart';

import 'svg_path.dart';
import 'theme.dart';

enum PictogramKind { protectHead, goUphill, stayHere, getOutOfCar, stayInCar, outdoorsProtect }

enum _Ink { line, bg, black, yellow }

class _Shape {
  const _Shape(this.path, {this.ink = _Ink.line, this.strokeWidth, this.outline});

  final Path Function() path;
  final _Ink ink;

  /// Set = stroked with round caps and joins, not filled.
  final double? strokeWidth;

  /// Set = filled with [ink], then outlined with black at this width.
  final double? outline;
}

_Shape _d(String d, [_Ink ink = _Ink.line]) => _Shape(() => svgPath(d), ink: ink);

_Shape _poly(String points, [_Ink ink = _Ink.line]) => _Shape(() => svgPolygon(points), ink: ink);

_Shape _circle(double cx, double cy, double r, {_Ink ink = _Ink.line, double? outline}) => _Shape(
      () => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      ink: ink,
      outline: outline,
    );

_Shape _ellipse(double cx, double cy, double rx, double ry) => _Shape(
      () => Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2)),
    );

_Shape _rect(double x, double y, double w, double h, {double r = 0, _Ink ink = _Ink.line}) => _Shape(
      () => Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r))),
      ink: ink,
    );

List<_Shape> _strokes(double width, List<String> ds) => [
      for (final d in ds) _Shape(() => svgPath(d), strokeWidth: width),
    ];

class _Art {
  const _Art(this.viewBox, this.title, this.shapes, {this.flipRtl = false});

  final Rect viewBox;

  /// Accessible label (English, as on the web).
  final String title;
  final List<_Shape> shapes;
  final bool flipRtl;
}

final Map<PictogramKind, _Art> _art = {
  PictogramKind.protectHead: _Art(const Rect.fromLTWH(0, 0, 360, 230), 'Protect your head under a table', [
    _rect(14, 8, 332, 36, r: 14),
    _rect(34, 40, 26, 184, r: 5),
    _rect(300, 40, 26, 184, r: 5),
    _rect(82, 40, 17, 116, r: 4),
    _rect(261, 40, 17, 116, r: 4),
    // person
    _circle(222, 112, 27),
    _d('M118 212 C106 192 118 164 150 142 C172 124 192 108 218 84 Q240 74 258 86 L254 96 Q238 92 226 100 C208 116 198 128 190 140 L208 152 Q192 170 176 178 L214 192 C232 198 238 210 226 218 L130 218 Q112 218 118 212 Z'),
  ]),
  PictogramKind.goUphill: _Art(
    const Rect.fromLTWH(0, 0, 360, 240),
    'Go uphill, away from the sea',
    flipRtl: true,
    [
      // slope
      _poly('125,222 345,122 345,222'),
      // waves
      _d('M8 222 Q28 176 58 160 Q96 144 108 174 Q104 190 88 190 Q76 182 82 174 Q60 180 72 200 Q88 212 112 200 Q128 190 142 196 L148 222 Z'),
      _d('M96 205 Q110 190 130 188 Q146 188 150 200 L158 222 L110 222 Z'),
      // arrow
      ..._strokes(13, ['M262 104 L304 76']),
      _poly('296,48 330,44 316,80'),
      // walker
      _circle(196, 58, 15),
      ..._strokes(14, [
        'M200 82 L188 126',
        'M190 126 L214 142 L212 176',
        'M188 126 L166 172 L178 180',
        'M196 88 L172 98 L164 118',
        'M206 90 L234 96 L244 100',
      ]),
    ],
  ),
  PictogramKind.stayHere: _Art(const Rect.fromLTWH(0, -6, 360, 226), 'Stay here on high ground', [
    _poly('20,212 20,148 108,76 178,76 226,42 340,42 340,212', _Ink.black),
    _circle(222, 30, 34, ink: _Ink.yellow, outline: 6),
    _rect(205, 12, 12, 36, r: 3, ink: _Ink.black),
    _rect(227, 12, 12, 36, r: 3, ink: _Ink.black),
  ]),
  PictogramKind.getOutOfCar: _Art(const Rect.fromLTWH(0, 0, 420, 230), 'Stop the car and get out', [
    // car
    _d('M14 182 V146 Q14 128 34 123 L76 118 L106 76 Q114 66 128 66 H204 Q218 66 226 76 L252 118 L280 124 Q296 130 296 150 V182 Z'),
    _d('M118 84 H146 V114 H98 Z', _Ink.bg),
    _d('M160 84 H202 L222 114 H160 Z', _Ink.bg),
    _circle(76, 184, 28),
    _circle(76, 184, 10, ink: _Ink.bg),
    _circle(238, 184, 28),
    _circle(238, 184, 10, ink: _Ink.bg),
    // person
    _circle(356, 52, 17),
    ..._strokes(14, [
      'M356 78 L350 136',
      'M350 136 L372 168 L380 212',
      'M350 136 L330 172 L322 212',
      'M354 88 L326 108',
      'M354 88 L384 106',
    ]),
  ]),
  PictogramKind.stayInCar: _Art(const Rect.fromLTWH(0, 0, 420, 230), 'Pull over and stay in the car', [
    // car
    _d('M64 182 V146 Q64 128 84 123 L126 118 L156 76 Q164 66 178 66 H254 Q268 66 276 76 L302 118 L330 124 Q346 130 346 150 V182 Z'),
    _d('M168 84 H196 V114 H148 Z', _Ink.bg),
    _d('M210 84 H252 L272 114 H210 Z', _Ink.bg),
    // driver seated inside (head + shoulders in the front window)
    _circle(236, 96, 10),
    _d('M220 114 Q222 104 236 104 Q250 104 252 114 Z'),
    _circle(126, 184, 28),
    _circle(126, 184, 10, ink: _Ink.bg),
    _circle(288, 184, 28),
    _circle(288, 184, 10, ink: _Ink.bg),
    // hazard lights flashing at both ends
    ..._strokes(10, [
      'M44 128 L18 116',
      'M44 146 L14 146',
      'M44 164 L18 176',
      'M366 128 L392 116',
      'M366 146 L396 146',
      'M366 164 L392 176',
    ]),
  ]),
  PictogramKind.outdoorsProtect: _Art(
    const Rect.fromLTWH(0, 0, 360, 230),
    'Crouch and protect your head, away from buildings',
    [
      // buildings
      _rect(8, 30, 70, 190, r: 4),
      _rect(282, 80, 70, 140, r: 4),
      for (final (x, y) in const [
        (22.0, 48.0), (48.0, 48.0), (22.0, 80.0), (48.0, 80.0), (22.0, 112.0), (48.0, 112.0),
        (296.0, 98.0), (322.0, 98.0), (296.0, 130.0), (322.0, 130.0),
      ])
        _rect(x, y, 16, 16, ink: _Ink.bg),
      // falling debris
      _poly('150,20 168,26 160,42 144,36'),
      _poly('200,6 216,14 206,30 192,22'),
      _poly('232,44 246,48 242,62 228,58'),
      // person
      _ellipse(170, 176, 46, 32),
      _circle(216, 168, 19),
      ..._strokes(13, ['M188 146 L232 148 L240 164', 'M128 200 L196 212']),
      _d('M118 214 Q124 196 148 206 L206 214 Z'),
    ],
  ),
};

/// Fills the parent keeping its proportions, or is [size] wide. GoUphill mirrors in Arabic.
class Pictogram extends StatelessWidget {
  const Pictogram(this.kind, {super.key, this.size, this.color = TkColors.pictoLine, this.title});

  final PictogramKind kind;
  final double? size;
  final Color color;

  /// Accessible label (default is English).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final art = _art[kind]!;
    Widget paint = CustomPaint(painter: _PictogramPainter(art, color));
    if (art.flipRtl && Directionality.of(context) == TextDirection.rtl) {
      paint = Transform.flip(flipX: true, child: paint);
    }
    final s = size;
    return Semantics(
      image: true,
      label: title ?? art.title,
      child: s != null
          ? SizedBox(width: s, height: s * art.viewBox.height / art.viewBox.width, child: paint)
          : SizedBox.expand(child: paint),
    );
  }
}

class _PictogramPainter extends CustomPainter {
  const _PictogramPainter(this.art, this.line);

  final _Art art;
  final Color line;

  Color _color(_Ink ink) => switch (ink) {
        _Ink.line => line,
        _Ink.bg => TkColors.pictoBg,
        _Ink.black => TkColors.black,
        _Ink.yellow => TkColors.yellow,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final vb = art.viewBox;
    final scale = size.shortestSide == 0
        ? 0.0
        : (size.width / vb.width < size.height / vb.height ? size.width / vb.width : size.height / vb.height);
    canvas.save();
    canvas.translate((size.width - vb.width * scale) / 2, (size.height - vb.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-vb.left, -vb.top);
    for (final s in art.shapes) {
      final path = s.path();
      final p = Paint()
        ..isAntiAlias = true
        ..color = _color(s.ink);
      final w = s.strokeWidth;
      if (w != null) {
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      }
      canvas.drawPath(path, p);
      final o = s.outline;
      if (o != null) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = o
            ..color = TkColors.black,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PictogramPainter old) => old.art != art || old.line != line;
}
