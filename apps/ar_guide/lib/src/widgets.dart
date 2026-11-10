// Overlay widgets matching the mock's S11 / S12 (mocks/evacuate/src/screens/S11.tsx, S12.tsx, nav.css).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fonts.dart';
import 'guide_params.dart';
import 'strings.dart';

class Tk {
  static const bgDark = Color(0xFF18161A);
  static const btnDark = Color(0xFF2A272C);
  static const red = Color(0xFFAE1428);
  static const yellow = Color(0xFFFFD54F);
  static const ink = Color(0xFF17151A);
  static const muted = Color(0xFFD7CFD3);
}

/// Header (variant "sub", red accent rule as on S11). The DEMO badge replaces the mock's globe / phone
/// buttons, which have no function in this single-screen app.
class TkHeader extends StatelessWidget {
  const TkHeader({super.key, required this.title, required this.demoLabel, required this.onBack, this.modeLabel});

  final String title;
  final String demoLabel;
  final String? modeLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tk.bgDark,
        border: Border(bottom: BorderSide(color: Tk.red, width: 5)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Material(
              color: Tk.btnDark,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ),
            if (modeLabel != null) ...[
              Text(modeLabel!, style: const TextStyle(color: Tk.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
            ],
            DemoBadge(label: demoLabel),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

/// Always-visible DEMO marker (the guidance values are demo data, not a real route).
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Tk.red,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}

/// Yellow status pill with the warning icon ("TSUNAMI WARNING", "AR PAUSED").
class TkBadge extends StatelessWidget {
  const TkBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Tk.yellow, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 20, color: Tk.ink),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(color: Tk.ink, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Right   12 m" card.
class TurnCard extends StatelessWidget {
  const TurnCard({super.key, required this.direction, required this.distance});
  final String direction;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
        decoration: BoxDecoration(
          color: const Color(0xF016141A),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(direction, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(width: 28),
            Text(distance, style: const TextStyle(color: Tk.yellow, fontSize: 19, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Small note under the card: compass accuracy low (the arrow stays visible), or "Turn around".
class LowAccuracyChip extends StatelessWidget {
  const LowAccuracyChip({super.key, required this.label, this.icon = Icons.explore_outlined});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD116141A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Tk.yellow),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Bottom "MAP" sheet: title and destination ("Hill Park / 高台公園") when collapsed (the initial state);
/// drag up, or tap the handle, for the schematic route map. Snaps to those two states. Must be placed in
/// a Stack that fills the area below the header.
class MapSheet extends StatefulWidget {
  const MapSheet({super.key, required this.s, required this.params, this.headingDeg, this.sheetHeight});
  final S s;
  final GuideParams params;

  /// Marker rotation on the schematic map (deg, clockwise; 0 = along the route, which is drawn upwards);
  /// null = no direction shown.
  final double? headingDeg;

  /// Receives the sheet's current height in px (the road arrow stays above it).
  final ValueNotifier<double>? sheetHeight;

  /// The expanded sheet covers at most this share of the area below the header, so the turn card at the
  /// top and most of the arrow stay visible.
  static const maxExpandedShare = 0.40;

  @override
  State<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends State<MapSheet> {
  static const _handleArea = 25.0;
  static const _collapsedGap = 12.0;
  static const _mapGap = 10.0;
  static const _legendGap = 8.0;

  final _controller = DraggableScrollableController();

  /// 0 = collapsed, 1 = expanded. Hides the map while collapsed: it would show behind the system bars.
  final _progress = ValueNotifier<double>(0);
  double _availableHeight = 0;
  bool _reportedInitialHeight = false;
  double _min = 0;
  double _max = 1;

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_controller.isAttached) return;
    final expanded = _controller.size > (_min + _max) / 2;
    _controller.animateTo(
      expanded ? _min : _max,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  bool _onSize(DraggableScrollableNotification n) {
    widget.sheetHeight?.value = n.extent * _availableHeight;
    final span = n.maxExtent - n.minExtent;
    _progress.value = span <= 0 ? 0 : ((n.extent - n.minExtent) / span).clamp(0.0, 1.0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final params = widget.params;
    final ja = params.lang == Lang.ja;
    // Japanese UI shows only the Japanese name (same rule as the mock's bilingual()).
    final primary = ja ? (params.destJa ?? params.dest) : params.dest;
    final secondary = ja ? null : params.destJa;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight = math.max(30.0, scaler.scale(30));
    final legendHeight = scaler.scale(22);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final mapWidth = constraints.maxWidth - 36;
        final collapsed = _handleArea + rowHeight + _collapsedGap + bottomInset;
        _availableHeight = height;
        if (!_reportedInitialHeight) {
          // The sheet sends no notification for its initial (collapsed) size.
          _reportedInitialHeight = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.sheetHeight?.value = collapsed;
          });
        }
        final room = height * MapSheet.maxExpandedShare - collapsed - _mapGap - _legendGap - legendHeight;
        final mapHeight = math.max(60.0, math.min(mapWidth / 2.6, room));
        final expanded = collapsed + _mapGap + mapHeight + _legendGap + legendHeight;
        _min = (collapsed / height).clamp(0.05, 1.0);
        _max = (expanded / height).clamp(_min, 1.0);

        return NotificationListener<DraggableScrollableNotification>(
          onNotification: _onSize,
          child: DraggableScrollableSheet(
            controller: _controller,
            initialChildSize: _min,
            minChildSize: _min,
            maxChildSize: _max,
            snap: true,
            builder: (context, scrollController) {
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: Tk.bgDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  // The content fits the expanded sheet exactly; a drag must still reach the sheet.
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  child: SizedBox(
                    height: expanded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          button: true,
                          label: s.map,
                          child: GestureDetector(
                            key: const Key('map-sheet-handle'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggle,
                            child: SizedBox(
                              height: _handleArea,
                              child: Center(
                                child: Container(
                                  width: 56,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6A6370),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                const Icon(Icons.map_outlined, size: 26, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  s.map,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: primary),
                                        if (secondary != null) ...[
                                          const TextSpan(text: '  /  '),
                                          TextSpan(text: secondary, style: TkFonts.japaneseName),
                                        ],
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: _progress,
                          builder: (context, progress, child) => Opacity(opacity: progress, child: child),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, _mapGap, 18, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: mapHeight,
                                    child: CustomPaint(
                                      key: const Key('map-sheet-map'),
                                      painter: MiniMapPainter(turn: params.turn, headingDeg: widget.headingDeg),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: _legendGap),
                                SizedBox(
                                  height: legendHeight,
                                  child: Text(
                                    s.stripedHazard,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Tk.muted, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// "AR paused" panel (the mock's S12): arrows hidden, reason, and what to do.
class PausedSheet extends StatelessWidget {
  const PausedSheet({
    super.key,
    required this.s,
    required this.title,
    required this.message,
    required this.onBack,
    this.actionLabel,
    this.onAction,
    this.showFigure8 = false,
  });

  final S s;
  final String title;
  final String message;
  final VoidCallback onBack;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showFigure8;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      children: [
        Align(alignment: AlignmentDirectional.centerStart, child: TkBadge(label: s.arPaused)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 6),
                  Text(message, style: const TextStyle(color: Tk.muted, fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (showFigure8) const Padding(padding: EdgeInsetsDirectional.only(start: 12), child: Figure8Hint()),
          ],
        ),
        const SizedBox(height: 16),
        if (actionLabel != null && onAction != null) ...[
          _BigButton(label: actionLabel!, primary: true, onPressed: onAction!, icon: Icons.photo_camera),
          const SizedBox(height: 10),
        ],
        _BigButton(label: s.back, primary: false, onPressed: onBack, icon: Icons.arrow_back),
        const SizedBox(height: 10),
        Text(s.routeHidden, style: const TextStyle(color: Tk.muted, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.primary, required this.onPressed, required this.icon});
  final String label;
  final bool primary;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          backgroundColor: primary ? Tk.yellow : Tk.btnDark,
          foregroundColor: primary ? Tk.ink : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tk.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      // No drag handle: this panel does not move (only MapSheet does).
      padding: EdgeInsets.fromLTRB(18, 18, 18, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Phone icon moving along a figure 8 (compass calibration hint).
class Figure8Hint extends StatefulWidget {
  const Figure8Hint({super.key});

  @override
  State<Figure8Hint> createState() => _Figure8HintState();
}

class _Figure8HintState extends State<Figure8Hint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 92,
      height: 64,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = reduceMotion ? 0.125 : _c.value;
          final a = 2 * math.pi * t;
          // Lemniscate of Gerono.
          final x = math.cos(a) * 34;
          final y = math.sin(2 * a) / 2 * 34;
          return CustomPaint(
            painter: _Figure8Painter(),
            child: Center(
              child: Transform.translate(
                offset: Offset(x, y),
                child: const Icon(Icons.smartphone, color: Tk.yellow, size: 26),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Figure8Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path();
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      final p = c + Offset(math.cos(a) * 34, math.sin(2 * a) / 2 * 34);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Tk.muted.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Figure8Painter old) => false;
}

/// Schematic mini map: streets, a striped hazard zone by the sea, the yellow route from the current
/// position (blue dot with heading cone) to the refuge flag, turning the same way as the AR arrow (F38).
class MiniMapPainter extends CustomPainter {
  MiniMapPainter({required this.turn, this.headingDeg});
  final Turn turn;

  /// Marker rotation (deg, clockwise; 0 = up = along the route's next leg). null = plain dot, no direction.
  final double? headingDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A272C));

    // Hazard zone (striped) along the bottom edge.
    final hazard = Rect.fromLTWH(0, h * 0.78, w, h * 0.22);
    canvas.save();
    canvas.clipRect(hazard);
    canvas.drawRect(hazard, Paint()..color = const Color(0xFF3A2A30));
    final stripe = Paint()
      ..color = const Color(0x66AE1428)
      ..strokeWidth = 4;
    for (var x = -h; x < w + h; x += 12) {
      canvas.drawLine(Offset(x, h), Offset(x + h * 0.3, h * 0.7), stripe);
    }
    canvas.restore();

    // Streets.
    final street = Paint()
      ..color = const Color(0xFF4A464E)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final fx in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(w * fx, 0), Offset(w * fx, h), street);
    }
    for (final fy in [0.22, 0.55]) {
      canvas.drawLine(Offset(0, h * fy), Offset(w, h * fy), street);
    }

    // Route.
    // High enough that the heading cone is not clipped when it points south.
    final start = Offset(w * 0.5, h * 0.76);
    final corner = Offset(w * 0.5, h * 0.22);
    final end = switch (turn) {
      Turn.right => Offset(w * 0.8, h * 0.22),
      Turn.left => Offset(w * 0.2, h * 0.22),
      Turn.straight => Offset(w * 0.5, h * 0.04),
    };
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(
      route,
      Paint()
        ..color = Tk.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Refuge flag.
    final pole = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(end, end.translate(0, -16), pole);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy - 16)
        ..lineTo(end.dx + 11, end.dy - 12)
        ..lineTo(end.dx, end.dy - 8)
        ..close(),
      Paint()..color = const Color(0xFF4CAF50),
    );

    // Current position; with a heading, a cone and a pointer turned by it (only the marker rotates).
    final heading = headingDeg;
    if (heading != null) {
      canvas.save();
      canvas.translate(start.dx, start.dy);
      canvas.rotate(heading * math.pi / 180);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-11, -24)
          ..lineTo(11, -24)
          ..close(),
        Paint()..color = const Color(0x994FC3F7),
      );
      canvas.restore();
    }
    canvas.drawCircle(start, heading == null ? 7 : 10, Paint()..color = Colors.white);
    canvas.drawCircle(start, heading == null ? 5 : 8, Paint()..color = const Color(0xFF1E88E5));
    if (heading != null) {
      canvas.save();
      canvas.translate(start.dx, start.dy);
      canvas.rotate(heading * math.pi / 180);
      canvas.drawPath(
        Path()
          ..moveTo(0, -6)
          ..lineTo(4.5, 4.5)
          ..lineTo(0, 2.5)
          ..lineTo(-4.5, 4.5)
          ..close(),
        Paint()..color = Colors.white,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MiniMapPainter old) {
    if (old.turn != turn) return true;
    final a = old.headingDeg;
    final b = headingDeg;
    if (a == null || b == null) return a != b;
    return (a - b).abs() > 0.2;
  }
}
