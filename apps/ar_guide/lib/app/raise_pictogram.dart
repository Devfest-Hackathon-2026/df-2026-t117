// "Raise the phone" pictogram for the S04 AR button: a hand holding a phone upright, with an up arrow.
// Same drawing style as pictograms.dart (flat ink on the button colour). The hand and phone bob up and
// down a few times to suggest raising, then rests (one bob every 10 s); static with reduced motion.
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'svg_path.dart';
import 'theme.dart';

const Rect _viewBox = Rect.fromLTWH(0, 0, 120, 110);

/// How far the hand and phone rise, in view box units (about 4-5 px at the button's size).
const double _liftUnits = 20;

final Path _arrowShaft = svgPath('M102 66 L102 32');
final Path _arrowHead = svgPolygon('89,38 102,16 115,38');
final Path _phone = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 22, 38, 58), const Radius.circular(7)));
final Path _screen = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(33, 29, 28, 40), const Radius.circular(2)));
// Cupped hand: thumb on the start side, fingers on the end side, palm under the phone. Runs past the
// bottom of the view box (clipped), so the wrist comes in from below as it rises.
final Path _hand = svgPath('M10 140 L12 72 Q13 62 22 63 L22 88 L72 88 L72 63 Q81 62 82 72 L80 140 Z');

/// [width] wide, decorative (the button carries the label). Mirrors in RTL with the button's layout.
class RaisePhonePictogram extends StatefulWidget {
  const RaisePhonePictogram({super.key, this.width = 26, this.color = TkColors.bgDark, this.background = TkColors.yellow});

  final double width;
  final Color color;

  /// Colour of the phone screen (the button behind the pictogram).
  final Color background;

  /// Widget tests settle with pumpAndSettle, which waits out every animation; flutter_test_config.dart
  /// turns the motion off for the whole suite.
  @visibleForTesting
  static bool debugDisableMotion = false;

  /// Bobs when the pictogram appears, then one bob every [restInterval].
  static const int introBobs = 3;
  static const Duration bobDuration = Duration(milliseconds: 1400);
  static const Duration restInterval = Duration(seconds: 10);

  /// False with large text (system font size 160 % and up): the label then needs the whole button.
  /// Uses the text scale rather than the width, because S04 sizes its column by intrinsics, which a
  /// LayoutBuilder cannot report.
  static bool fitsBesideLabel(BuildContext context) => MediaQuery.textScalerOf(context).scale(14) / 14 < 1.6;

  @override
  State<RaisePhonePictogram> createState() => _RaisePhonePictogramState();
}

class _RaisePhonePictogramState extends State<RaisePhonePictogram> with SingleTickerProviderStateMixin {
  // Value counts bobs: 0 -> n runs n bobs and rests at a whole number (the lowered pose).
  late final AnimationController _c = AnimationController.unbounded(vsync: this);
  Timer? _rest;

  bool _still(BuildContext context) =>
      RaisePhonePictogram.debugDisableMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  void _bob(int times) {
    _c.value = 0;
    _c.animateTo(times.toDouble(), duration: RaisePhonePictogram.bobDuration * times, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _rest?.cancel();
      _rest = null;
      _c
        ..stop()
        ..value = 0;
    } else if (_rest == null) {
      _bob(RaisePhonePictogram.introBobs);
      _rest = Timer.periodic(RaisePhonePictogram.restInterval, (_) {
        if (!_c.isAnimating) _bob(1);
      });
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    Widget paint = CustomPaint(painter: _RaisePainter(_c, widget.color, widget.background));
    if (Directionality.of(context) == TextDirection.rtl) {
      paint = Transform.flip(flipX: true, child: paint);
    }
    // SizedBox, not CustomPaint.size: the S04 column sizes itself by intrinsics, which a childless
    // CustomPaint reports as zero.
    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: w * _viewBox.height / _viewBox.width,
        child: RepaintBoundary(child: paint),
      ),
    );
  }
}

/// Repaints from [bobs] directly (no rebuilds while it moves).
class _RaisePainter extends CustomPainter {
  _RaisePainter(this.bobs, this.ink, this.background) : super(repaint: bobs);

  final Animation<double> bobs;

  /// 0 (lowered) -> 1 (raised) -> 0 over each bob, eased at both ends.
  double get _lift {
    final t = bobs.value - bobs.value.floorToDouble();
    return Curves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
  }

  final Color ink;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.width / _viewBox.width < size.height / _viewBox.height
        ? size.width / _viewBox.width
        : size.height / _viewBox.height;
    final fill = Paint()
      ..isAntiAlias = true
      ..color = ink;
    canvas.save();
    canvas.translate((size.width - _viewBox.width * scale) / 2, (size.height - _viewBox.height * scale) / 2);
    canvas.scale(scale);
    canvas.clipRect(_viewBox);
    canvas.drawPath(
      _arrowShaft,
      Paint()
        ..isAntiAlias = true
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(_arrowHead, fill);
    canvas.translate(0, -_liftUnits * _lift);
    canvas.drawPath(_hand, fill);
    canvas.drawPath(_phone, fill);
    canvas.drawPath(
      _screen,
      Paint()
        ..isAntiAlias = true
        ..color = background,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaisePainter old) => old.bobs != bobs || old.ink != ink || old.background != background;
}

/// Passes [maxWidth] on to its child's intrinsic heights. S04 sizes its column by intrinsics, and a
/// ConstrainedBox(maxWidth) does not narrow the width it asks about, so a label that wraps to more lines
/// beside the pictogram would otherwise overflow instead of making room.
class IntrinsicMaxWidth extends SingleChildRenderObjectWidget {
  const IntrinsicMaxWidth({super.key, required this.maxWidth, super.child});

  final double maxWidth;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderIntrinsicMaxWidth(maxWidth);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderIntrinsicMaxWidth).maxWidth = maxWidth;
  }
}

class _RenderIntrinsicMaxWidth extends RenderProxyBox {
  _RenderIntrinsicMaxWidth(this._maxWidth);

  double _maxWidth;
  set maxWidth(double value) {
    if (value == _maxWidth) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  double _clamp(double width) => width < _maxWidth ? width : _maxWidth;

  @override
  double computeMinIntrinsicHeight(double width) => super.computeMinIntrinsicHeight(_clamp(width));

  @override
  double computeMaxIntrinsicHeight(double width) => super.computeMaxIntrinsicHeight(_clamp(width));
}
