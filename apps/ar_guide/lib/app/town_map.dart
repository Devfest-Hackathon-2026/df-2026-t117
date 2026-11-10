// Map of the fictional town "Minato Bay" (requirements 6.3 / 6.4). Port of
// mocks/evacuate/src/components/TownMap.tsx. Route / position / heading come from the store, so every screen
// shows the same values. The map is geography: it is never mirrored in Arabic.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/town.dart';
import 'i18n/i18n.dart';
import 'logic/nav.dart';
import 'state/store.dart';
import 'state/types.dart';
import 'svg_path.dart';
import 'theme.dart';

/// mini = card in S04/S11 (810:435), full = S07/S08/S12 (810:780).
enum TownMapVariant { mini, full }

/// blue (S04), yellow with dark outline (S11), none (S07/S08/S12). Draws the remaining route.
enum RouteColor { blue, yellow, none }

const double _extensionM = 400;
const Color _ink = Color(0xFF17151A);
const Color _steps = Color(0xFFA8A095);
const Color _closed = Color(0xFFAE1428);

Offset _o(Point p) => Offset(p.x, p.y);

Path _polyline(List<Point> points, {bool close = false}) => Path()..addPolygon([for (final p in points) _o(p)], close);

Point _extend(Point from, Point toward, double len) {
  final dx = from.x - toward.x;
  final dy = from.y - toward.y;
  final h = math.sqrt(dx * dx + dy * dy);
  final l = h == 0 ? 1.0 : h;
  return Point(from.x + (dx / l) * len, from.y + (dy / l) * len);
}

final List<({bool stairs, Path path})> _streetPaths = [
  for (final s in streets)
    () {
      final pts = [for (final id in s.nodeIds) Point(nodes[id]!.x, nodes[id]!.y)];
      if (s.extendStart && pts.length > 1) pts.insert(0, _extend(pts[0], pts[1], _extensionM));
      if (s.extendEnd && pts.length > 1) pts.add(_extend(pts.last, pts[pts.length - 2], _extensionM));
      return (stairs: s.stairs, path: _polyline(pts));
    }(),
];

final Path _seaPath = _polyline(seaPolygon, close: true);
final Path _hazardPath = _polyline(hazardZone, close: true);

final List<({Point mid, double angle})> _closedEdges = [
  for (final e in edges)
    if (e.closure != null)
      (
        mid: Point((nodes[e.a]!.x + nodes[e.b]!.x) / 2, (nodes[e.a]!.y + nodes[e.b]!.y) / 2),
        angle: math.atan2(nodes[e.b]!.y - nodes[e.a]!.y, nodes[e.b]!.x - nodes[e.a]!.x),
      ),
];

final Path _flagPole = svgPath('M-5.5 8 V-8');
final Path _flagCloth = svgPath('M-5.5 -8 H1 V-5.5 H6.5 V2.5 H0.5 V0 H-5.5');
final Path _headingArrow = svgPath('M0 -6.8 L5.4 5.6 L0 3 L-5.4 5.6 Z');
final Path _mapPin = svgPath('M0 0 C-2.5 -6 -11 -12.5 -11 -20.5 A11 11 0 1 1 11 -20.5 C11 -12.5 2.5 -6 0 0 Z');

/// x of the coastline at a given y (linear interpolation).
double coastXAt(double y) {
  for (var i = 0; i < coastline.length - 1; i++) {
    final a = coastline[i];
    final b = coastline[i + 1];
    if (y >= a.y && y <= b.y) {
      final dy = b.y - a.y;
      return a.x + ((b.x - a.x) * (y - a.y)) / (dy == 0 ? 1 : dy);
    }
  }
  return coastline.last.x;
}

Rect fitBox(List<Point> points, double aspect, double minW, double pad) {
  var x0 = double.infinity, y0 = double.infinity, x1 = double.negativeInfinity, y1 = double.negativeInfinity;
  for (final p in points) {
    x0 = math.min(x0, p.x);
    y0 = math.min(y0, p.y);
    x1 = math.max(x1, p.x);
    y1 = math.max(y1, p.y);
  }
  x0 -= pad;
  y0 -= pad;
  x1 += pad;
  y1 += pad;
  var w = math.max(minW, x1 - x0);
  var h = y1 - y0;
  if (w / h < aspect) {
    w = h * aspect;
  } else {
    h = w / aspect;
  }
  return Rect.fromCenter(center: Offset((x0 + x1) / 2, (y0 + y1) / 2), width: w, height: h);
}

/// Area actually visible inside [box] with "slice" (cover) scaling, and meters per pixel.
({Rect rect, double mPerPx}) visibleRect(Rect vb, Size box) {
  final scale = math.max(box.width / vb.width, box.height / vb.height);
  final w = box.width / scale;
  final h = box.height / scale;
  return (rect: Rect.fromLTWH(vb.left + (vb.width - w) / 2, vb.top + (vb.height - h) / 2, w, h), mPerPx: 1 / scale);
}

class TownMap extends StatefulWidget {
  const TownMap({
    super.key,
    this.variant = TownMapVariant.mini,
    this.routeColor = RouteColor.blue,
    this.showAccuracy = false,
    this.pinEditable = false,
    this.pin,
    this.controlledPin = false,
    this.onPinChange,
    this.showHeading = false,
    this.headingDeg,
    this.showPosition = true,
    this.showClosures,
    this.showAllRefuges,
    this.viewBox,
    this.focus,
    this.semanticLabel,
    this.fill = false,
  });

  final TownMapVariant variant;
  final RouteColor routeColor;

  /// GPS accuracy circle (S07). The blue dot is then drawn at gps.position instead of the walk position.
  final bool showAccuracy;

  /// Pin can be tapped / dragged (S07). Uncontrolled unless [controlledPin].
  final bool pinEditable;

  /// Used with [controlledPin] (null = no pin).
  final Point? pin;

  /// true = [pin] gives the position (the web's `pin !== undefined`).
  final bool controlledPin;

  /// Called on tap and while dragging (town meters, clamped to the visible map).
  final ValueChanged<Point>? onPinChange;

  /// Current position as a blue circle with a white navigation arrow (S11). Otherwise a blue dot.
  final bool showHeading;

  /// Live compass heading for that marker (deg). null = the walking direction along the route.
  final double? headingDeg;

  /// Show the current-position marker at all.
  final bool showPosition;

  /// Closed-road markers. null = only while online (offline the live status is unknown).
  final bool? showClosures;

  /// Every refuge flag. null = full: all refuges, mini: only the route's refuge.
  final bool? showAllRefuges;

  /// Explicit view box in town meters (cropped to fill the card).
  final Rect? viewBox;

  /// Center the default view on this point.
  final Point? focus;

  /// Accessible label. Defaults to the town name.
  final String? semanticLabel;

  /// true = fill the parent instead of the variant's aspect ratio (the web's `style` override).
  final bool fill;

  @override
  State<TownMap> createState() => _TownMapState();
}

class _TownMapState extends State<TownMap> {
  Point? _localPin;

  double get _defaultAspect => widget.variant == TownMapVariant.mini ? 810 / 435 : 810 / 780;

  Point? _pinPos(AppState state) {
    if (widget.controlledPin) return widget.pin;
    if (!widget.pinEditable) return null;
    return _localPin ?? state.manualPin ?? state.gps.position;
  }

  Rect _viewBox(AppState state, Navigation nav, Size size) {
    final explicit = widget.viewBox;
    if (explicit != null) return explicit;
    final aspect = size.width / size.height;
    Rect box;
    if (widget.variant == TownMapVariant.mini) {
      final pts = [...nav.route.points, nav.origin, nav.route.refuge.pos];
      final cy = pts.fold(0.0, (a, p) => a + p.y) / pts.length;
      pts.add(Point(coastXAt(cy) - 40, cy)); // keep a strip of sea on the left (+ pad)
      box = fitBox(pts, aspect, 560, 50);
    } else {
      final gps = state.gps.position;
      box = fitBox(
        [
          Point(-30, townBounds.top),
          Point(townBounds.right + 12, townBounds.bottom),
          // keep the whole accuracy circle in frame
          if (widget.showAccuracy) ...[
            Point(gps.x - state.gps.accuracyM - 8, gps.y),
            Point(gps.x, gps.y - state.gps.accuracyM - 8),
          ],
        ],
        aspect,
        0,
        0,
      );
    }
    final focus = widget.focus;
    if (focus != null) box = Rect.fromCenter(center: _o(focus), width: box.width, height: box.height);
    return box;
  }

  void _pinAt(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final store = context.store;
    final (:rect, :mPerPx) = visibleRect(_viewBox(store.state, store.nav, size), size);
    final inset = 12 * mPerPx;
    double r(double v) => (v + 0.5).floorToDouble();
    final p = Point(
      r((rect.left + local.dx * mPerPx).clamp(rect.left + inset, rect.right - inset)),
      r((rect.top + local.dy * mPerPx).clamp(rect.top + inset * 3, rect.bottom - inset)),
    );
    if (!widget.controlledPin) setState(() => _localPin = p);
    widget.onPinChange?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final state = store.state;
    final nav = store.nav;
    final Widget map = CustomPaint(
      painter: _TownPainter(
        map: widget,
        state: state,
        nav: nav,
        pin: _pinPos(state),
        viewBoxFor: (size) => _viewBox(state, nav, size),
      ),
      child: const SizedBox.expand(),
    );
    final interactive = widget.pinEditable
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _pinAt(d.localPosition),
            onPanUpdate: (d) => _pinAt(d.localPosition),
            child: map,
          )
        : map;
    final clipped = Semantics(
      image: true,
      label: widget.semanticLabel ?? townName[state.lang],
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: interactive),
    );
    return widget.fill ? clipped : AspectRatio(aspectRatio: _defaultAspect, child: clipped);
  }
}

class _TownPainter extends CustomPainter {
  const _TownPainter({
    required this.map,
    required this.state,
    required this.nav,
    required this.pin,
    required this.viewBoxFor,
  });

  final TownMap map;
  final AppState state;
  final Navigation nav;
  final Point? pin;
  final Rect Function(Size) viewBoxFor;

  static Paint _fill(Color c) => Paint()
    ..isAntiAlias = true
    ..color = c;

  static Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..color = c
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final mini = map.variant == TownMapVariant.mini;
    final (rect: vis, mPerPx: u) = visibleRect(viewBoxFor(size), size);
    final roadW = (mini ? 6 : 8.5) * u;

    void toTown() {
      canvas.save();
      canvas.scale(1 / u);
      canvas.translate(-vis.left, -vis.top);
    }

    canvas.clipRect(Offset.zero & size);
    toTown();

    // land, hazard band, sea
    canvas.drawRect(vis, _fill(TkColors.mapLand));
    _drawHazard(canvas, vis, u);
    canvas.drawPath(_seaPath, _fill(TkColors.mapSea));

    // roads
    for (final s in _streetPaths.where((s) => !s.stairs)) {
      canvas.drawPath(s.path, _stroke(TkColors.mapRoad, roadW));
    }
    // stairs: narrower road with step ticks
    for (final s in _streetPaths.where((s) => s.stairs)) {
      canvas.drawPath(s.path, _stroke(TkColors.mapRoad, roadW * 0.85));
      _drawDashes(canvas, s.path, 1.3 * u, 2.6 * u, _stroke(_steps, roadW * 0.85, cap: StrokeCap.butt));
    }

    if (map.showClosures ?? state.online) {
      for (final c in _closedEdges) {
        _closure(canvas, c.mid, c.angle, u);
      }
    }

    // route
    if (map.routeColor != RouteColor.none && nav.remainingPoints.length > 1) {
      final route = _polyline(nav.remainingPoints);
      if (map.routeColor == RouteColor.yellow) {
        canvas.drawPath(route, _stroke(_ink, 9.5 * u));
        canvas.drawPath(route, _stroke(TkColors.mapRouteAr, 5.5 * u));
      } else {
        canvas.drawPath(route, _stroke(TkColors.mapRoute, 6 * u));
      }
    }

    // refuges
    final all = map.showAllRefuges ?? !mini;
    for (final r in all ? refuges : [nav.route.refuge]) {
      _flag(canvas, r.pos, u, mini ? 13.5 : 14.5);
    }
    canvas.restore();

    // labels, in screen pixels
    _labels(canvas, size, vis, u);

    toTown();

    // GPS accuracy
    final gps = state.gps;
    if (map.showAccuracy) {
      final c = _o(gps.position);
      final r = math.max(4 * u, gps.accuracyM);
      canvas.drawCircle(c, r, _fill(TkColors.mapAccuracyFill.withValues(alpha: 0.9)));
      canvas.drawCircle(c, r, _stroke(TkColors.mapRoute, 2 * u));
    }

    // current position
    if (map.showPosition) {
      final at = map.showAccuracy ? gps.position : nav.position;
      if (map.showHeading) {
        _heading(canvas, at, u, map.headingDeg ?? nav.headingDeg);
      } else {
        canvas.drawCircle(_o(at), 9.5 * u, _fill(TkColors.white));
        canvas.drawCircle(_o(at), 6.5 * u, _fill(TkColors.mapRoute));
      }
    }

    final p = pin;
    if (p != null) _pin(canvas, p, u);
    canvas.restore();
  }

  void _drawHazard(Canvas canvas, Rect vis, double u) {
    final stripe = 8.5 * u;
    canvas.save();
    canvas.clipPath(_hazardPath);
    canvas.drawRect(vis, _fill(TkColors.mapHazard));
    // Stripes in a pattern rotated by 45 degrees: find the range that covers the visible area.
    const c = math.sqrt1_2;
    final corners = [vis.topLeft, vis.topRight, vis.bottomLeft, vis.bottomRight];
    final xs = corners.map((p) => p.dx * c + p.dy * c);
    final ys = corners.map((p) => -p.dx * c + p.dy * c);
    final x0 = (xs.reduce(math.min) / stripe).floor();
    final x1 = (xs.reduce(math.max) / stripe).ceil();
    final y0 = ys.reduce(math.min);
    final y1 = ys.reduce(math.max);
    canvas.rotate(math.pi / 4);
    final paint = _stroke(TkColors.mapHazardStripe, 0.75 * u, cap: StrokeCap.butt);
    for (var k = x0; k <= x1; k++) {
      canvas.drawLine(Offset(k * stripe, y0), Offset(k * stripe, y1), paint);
    }
    canvas.restore();
  }

  void _drawDashes(Canvas canvas, Path path, double on, double off, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += on + off) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
      }
    }
  }

  void _closure(Canvas canvas, Point at, double angle, double u) {
    canvas.save();
    canvas.translate(at.x, at.y);
    canvas.rotate(angle);
    canvas.scale(u);
    canvas.drawCircle(Offset.zero, 6.5, _fill(_closed));
    canvas.drawCircle(Offset.zero, 6.5, _stroke(TkColors.white, 1.5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-1.2, -3.8, 2.4, 7.6), const Radius.circular(1)),
      _fill(TkColors.white),
    );
    canvas.restore();
  }

  void _flag(Canvas canvas, Point at, double u, double r) {
    final s = r * u;
    canvas.save();
    canvas.translate(at.x, at.y);
    canvas.drawCircle(Offset.zero, s + 2.5 * u, _fill(TkColors.mapRoad));
    canvas.drawCircle(Offset.zero, s, _fill(_ink));
    canvas.scale(s / 14);
    final paint = _stroke(TkColors.white, 1.6 * u);
    canvas.drawPath(_flagPole, paint);
    canvas.drawPath(_flagCloth, paint);
    canvas.restore();
  }

  void _heading(Canvas canvas, Point at, double u, double deg) {
    canvas.save();
    canvas.translate(at.x, at.y);
    canvas.drawCircle(Offset.zero, 13 * u, _fill(TkColors.white));
    canvas.drawCircle(Offset.zero, 10.5 * u, _fill(TkColors.mapRoute));
    canvas.rotate(deg * math.pi / 180);
    canvas.scale(u);
    canvas.drawPath(_headingArrow, _fill(TkColors.white));
    canvas.drawPath(_headingArrow, _stroke(TkColors.white, 1));
    canvas.restore();
  }

  void _pin(Canvas canvas, Point at, double u) {
    canvas.save();
    canvas.translate(at.x, at.y);
    canvas.scale(u);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 3.2), _fill(const Color(0x40000000)));
    canvas.drawPath(_mapPin, _fill(_ink));
    canvas.drawPath(_mapPin, _stroke(TkColors.white, 1.2));
    canvas.drawCircle(const Offset(0, -20.5), 4.2, _fill(TkColors.white));
    canvas.restore();
  }

  void _labels(Canvas canvas, Size size, Rect vis, double u) {
    final seaBaselineM = vis.bottom - 12 * u;
    if (coastXAt(seaBaselineM) - vis.left > 36 * u) {
      _label(canvas, mapLabelSea[state.lang], 10, size.height - 12, TkColors.mapLabelSea, TkColors.mapSea);
    }
    if (vis.right > highGroundMinX + 60) {
      _label(canvas, mapLabelHighGround[state.lang], null, 22, _ink, TkColors.mapLand, rightPx: size.width - 12);
    }
  }

  /// [baseline] is in pixels. With [rightPx] the text ends there; otherwise it starts at [x].
  void _label(Canvas canvas, String text, double? x, double baseline, Color color, Color halo, {double? rightPx}) {
    TextPainter build(TextStyle extra) => TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              locale: localeOf(state.lang),
            ).merge(extra),
          ),
        )..layout();
    final under = build(TextStyle(foreground: _stroke(halo, 3)));
    final over = build(TextStyle(color: color));
    final left = rightPx != null ? rightPx - over.width : x!;
    final top = baseline - over.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    under.paint(canvas, Offset(left, top));
    over.paint(canvas, Offset(left, top));
    under.dispose();
    over.dispose();
  }

  @override
  bool shouldRepaint(_TownPainter old) => true;
}
