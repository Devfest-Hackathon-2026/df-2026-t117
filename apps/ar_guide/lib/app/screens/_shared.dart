// Parts shared by the guidance screens. Port of mocks/evacuate/src/screens/_guideShared.tsx,
// _alertShared.tsx and _navShared.tsx. ListenButton is in components.dart.
import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/guide_strings.dart';
import '../i18n/i18n.dart';
import '../logic/margin.dart';
import '../logic/nav.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../svg_path.dart';
import '../theme.dart';

export '../i18n/guide_strings.dart';
export '../pictograms.dart';
export '../town_map.dart';

// ---------------------------------------------------------------------------
// _guideShared

/// Pause between a screen change and its announcement.
const Duration announceDelay = Duration(milliseconds: 300);

/// The web's useAnnounceOnEnter: reads [text] aloud when the screen appears, and again when the instruction
/// or the language changes. Off when auto read-aloud is unchecked. Also runs while the screen is "off".
/// Put one anywhere in the screen.
class AnnounceOnEnter extends StatefulWidget {
  const AnnounceOnEnter({super.key, required this.text, this.child = const SizedBox.shrink()});

  final String text;
  final Widget child;

  @override
  State<AnnounceOnEnter> createState() => _AnnounceOnEnterState();
}

class _AnnounceOnEnterState extends State<AnnounceOnEnter> {
  Timer? _timer;
  String? _key;

  void _sync() {
    final state = context.appState;
    final key = '${state.autoSpeak}|${widget.text}|${state.lang}';
    if (key == _key) return;
    _key = key;
    _timer?.cancel();
    if (!state.autoSpeak || widget.text.isEmpty) return;
    final store = context.store;
    final text = widget.text;
    final lang = state.lang;
    _timer = Timer(announceDelay, () => store.platform.speak(text, lang));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnnounceOnEnter old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Footer line from freshness() (requirements 7.3).
/// fresh: "JMA • 09:40 JST • Details" (or [freshTail] instead of the Details link, e.g. "Warning active")
/// stale: "Last alert 09:40 JST • Stale"
class GuideFooter extends StatelessWidget {
  const GuideFooter({super.key, this.freshTail});

  final String? freshTail;

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final c = context.common;
    final f = freshness(state);
    final at = formatJstLabel(f.lastAlertAt ?? state.lastFetchAt);
    if (f.stale) return FooterMeta(items: ['${c.lastAlert} $at', c.stale]);
    if (freshTail != null && freshTail!.isNotEmpty) return FooterMeta(items: [c.jma, freshTail]);
    return FooterMeta(
      items: [c.jma, at, MetaLink(label: c.details, onTap: () => context.store.navigate(ScreenId.a02))],
    );
  }
}

// ---------------------------------------------------------------------------
// _alertShared

/// "Go higher." / "Follow the blue evacuation signs" / "Set location": `guideT(context)['goHigher']`.
Tr guideT(BuildContext context) => context.t(guideDict);

/// "3 m" / "over 10 m" / "huge" / "high" (F84: a qualitative first bulletin is shown as is).
String heightLabel(ExpectedHeight h, Lang lang) {
  final meters = commonStrings[lang]!.meters;
  return switch (h) {
    ExpectedHeight.m1 => fmt(meters, {'n': 1}),
    ExpectedHeight.m3 => fmt(meters, {'n': 3}),
    ExpectedHeight.m5 => fmt(meters, {'n': 5}),
    ExpectedHeight.m10 => fmt(meters, {'n': 10}),
    _ => heightDict[lang]![h.name]!,
  };
}

/// Badge-style name of a tsunami level.
String tsunamiLevelLabel(AlertLevel level, Lang lang) {
  final c = commonStrings[lang]!;
  return switch (level) {
    AlertLevel.emergency => c.badgeMajorTsunamiWarning,
    AlertLevel.advisory => c.badgeTsunamiAdvisory,
    AlertLevel.warning => c.badgeTsunamiWarning,
  };
}

/// Band under the header after an upgrade / raised height / downgrade: pass it as `band:` of GuidanceLayout.
/// Stays until the next change, until every alert is lifted, or until closed. Upgrade / raise: yellow.
/// Downgrade: grey, and guidance does not loosen (F8A). Shown on S02 too: while shaking only this changes.
class AlertBand extends StatelessWidget {
  const AlertBand({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final change = state.alertChange;
    if (change == null) return const SizedBox.shrink();
    final lang = state.lang;
    final c = context.common;
    final t = context.t(bandDict);
    final level = tsunamiLevelLabel(change.level, lang);
    final h = change.expectedHeight;
    final height = h != null ? fmt(t['expected'], {'h': heightLabel(h, lang)}) : null;
    final mode = deriveMode(state);
    final downgrade = change.kind == AlertChangeKind.downgrade;
    final raise = change.kind == AlertChangeKind.raise;
    final tail = !downgrade ? null : (mode == Mode.safe ? t['stayAll'] : (mode == Mode.evacuate ? t['keepGoing'] : null));
    final main = raise ? height : level;
    final sub = raise ? null : height;
    final fg = downgrade ? TkColors.textOnDark : TkColors.textOnLight;
    final meta = [sub, '${formatJst(change.at)} ${c.jst}', tail].whereType<String>().join(' • ');
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(TkSizes.gutter, 10, TkSizes.gutter - 8, 10),
      decoration: BoxDecoration(
        color: downgrade ? TkColors.btnDark : TkColors.yellow,
        border: downgrade ? const Border(bottom: BorderSide(color: TkColors.outlineOnDark)) : null,
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(downgrade ? Icons.schedule : Icons.warning_rounded, size: 22, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t[change.kind.name]}: ${main ?? ''}',
                      style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900, height: 1.3)),
                  Text(meta, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.store.patch(const StatePatch(clearAlertChange: true)),
              icon: Icon(Icons.close, size: 20, color: fg),
              tooltip: c.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card strings (also used for the spoken text). The web's useMarginText.
typedef MarginText = ({String? margin, String elevation, String? expected, String staff});

int _jsRound(double n) => (n + 0.5).floor();

MarginText marginText(MarginInfo m, Lang lang) {
  final c = commonStrings[lang]!;
  final t = Tr.of(cardDict, lang);
  final lo = m.elevMinM;
  final hi = m.elevMaxM;
  String? elevValue;
  if (lo != null && hi != null) {
    elevValue = m.approximate && _jsRound(hi) != _jsRound(lo)
        ? fmt(c.meters, {'n': '${_jsRound(lo)}–${_jsRound(hi)}'})
        : fmt(c.meters, {'n': _jsRound(lo)});
  }
  final h = m.heightInUse;
  final diff = m.marginM;
  return (
    margin: diff == null ? null : fmt(diff >= 0 ? t['above'] : t['below'], {'n': _jsRound(diff).abs()}),
    elevation: elevValue != null ? fmt(t['elevation'], {'v': elevValue}) : t['elevUnknown'],
    expected: h != null ? fmt(t['expected'], {'h': heightLabel(h, lang)}) : null,
    staff: t['staff'],
  );
}

/// F83 elevation, F84 expected height, F85 margin (big, colour + icon by the 14.3 table), F87 how long to wait.
/// Never says "safe": only the fact "N m above forecast". Calm colour (not green) when the margin is ample.
/// At a designated evacuation site the instruction stays "Stay here." and the card adds the staff line.
class MarginCard extends StatelessWidget {
  const MarginCard({super.key, required this.margin, required this.staying});

  final MarginInfo margin;
  final bool staying;

  @override
  Widget build(BuildContext context) {
    final m = margin;
    final t = context.t(cardDict);
    final text = marginText(m, context.lang);
    final low = m.level == MarginLevel.low;
    final short = m.level == MarginLevel.short;
    final fg = low ? TkColors.textOnLight : TkColors.textOnDark;
    final highestNotNow = m.heightInUse != null && m.heightNow != null && m.heightInUse != m.heightNow;
    final line = TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800);
    final facts = TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700);
    final bigText = text.margin;
    final expected = text.expected;
    return Semantics(
      label: t['title'],
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: low ? TkColors.yellow : (short ? TkColors.red : const Color(0x47000000)),
          borderRadius: BorderRadius.circular(TkSizes.radiusCard),
          border: low
              ? null
              : Border.all(color: short ? TkColors.white : TkColors.outlineOnDark, width: short ? 3 : 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            if (bigText != null)
              Row(
                children: [
                  Icon(m.level == MarginLevel.ample ? Icons.flag_outlined : Icons.warning_rounded, size: 30, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(bigText, style: TkText.heading.copyWith(color: fg, fontSize: 28, height: 1.15)),
                  ),
                ],
              ),
            Wrap(
              spacing: 16,
              runSpacing: 2,
              children: [
                Text(text.elevation, style: facts),
                if (expected != null)
                  Text.rich(
                    TextSpan(
                      text: expected,
                      children: [
                        if (highestNotNow)
                          TextSpan(
                            text: ' ${t['highest']}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    style: facts,
                  ),
              ],
            ),
            if (m.approximate) Text(t['approx'], style: line),
            if (staying) Text(t['stayUntil'], style: line),
            if (m.designated != null)
              Text(
                text.staff,
                style: low
                    ? line.copyWith(decoration: TextDecoration.underline)
                    : line.copyWith(color: TkColors.yellow),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _navShared

final Path _arrowStem = svgPath('M40 186 V60 H180');
final Path _arrowHead = svgPath('M128 10 L182 60 L128 110');
final Path _straightStem = svgPath('M110 186 V30');
final Path _straightHead = svgPath('M52 86 L110 26 L168 86');

/// Big turn arrow (S04). Directions are geographic, so it is NOT mirrored in Arabic.
class TurnArrow extends StatelessWidget {
  const TurnArrow({super.key, required this.direction, this.color = TkColors.white, this.size});

  final TurnDirection direction;
  final Color color;

  /// Width; null = fill the parent.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(painter: _TurnArrowPainter(direction, color));
    final s = size;
    return ExcludeSemantics(
      child: s != null ? SizedBox(width: s, height: s * 200 / 220, child: paint) : SizedBox.expand(child: paint),
    );
  }
}

class _TurnArrowPainter extends CustomPainter {
  const _TurnArrowPainter(this.direction, this.color);

  final TurnDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 220 < size.height / 200 ? size.width / 220 : size.height / 200;
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate((size.width - 220 * scale) / 2, (size.height - 200 * scale) / 2);
    canvas.scale(scale);
    if (direction == TurnDirection.left) {
      canvas.translate(220, 0);
      canvas.scale(-1, 1);
    }
    final straight = direction == TurnDirection.straight;
    canvas.drawPath(straight ? _straightStem : _arrowStem, p);
    canvas.drawPath(straight ? _straightHead : _arrowHead, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TurnArrowPainter old) => old.direction != direction || old.color != color;
}

/// Localized turn word ("Right" / "Left" / "Straight").
String directionLabel(TurnDirection direction, Lang lang) {
  final c = commonStrings[lang]!;
  return switch (direction) {
    TurnDirection.right => c.right,
    TurnDirection.left => c.left,
    TurnDirection.straight => c.straight,
  };
}

/// "40 m" in the given language.
String metersLabel(double m, Lang lang) {
  final n = _jsRound(m);
  return fmt(commonStrings[lang]!.meters, {'n': n < 0 ? 0 : n});
}

/// Badge text for the current tsunami alert (TSUNAMI WARNING / MAJOR ... / ADVISORY).
String tsunamiBadge(AppState state) {
  final a = mostSevere(state.alerts, HazardType.tsunami);
  return a != null ? alertBadgeLabel(a, state.lang) : commonStrings[state.lang]!.badgeTsunami;
}

/// The web's useAnnounceFlash: [builder] gets true for ~2.4 s after each turn announcement
/// (flashes the speaker / vibration icons).
class AnnounceFlash extends StatefulWidget {
  const AnnounceFlash({super.key, required this.builder});

  final Widget Function(BuildContext context, bool flash) builder;

  @override
  State<AnnounceFlash> createState() => _AnnounceFlashState();
}

class _AnnounceFlashState extends State<AnnounceFlash> {
  StreamSubscription<void>? _sub;
  Timer? _timer;
  bool _flash = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.store.onTurnAnnounce.listen((_) {
      setState(() => _flash = true);
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _flash = false);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _flash);
}

// ---------------------------------------------------------------------------
// Parts of the sub screens (t3.css, nav.css)

const TextStyle t3Body = TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w500, color: TkColors.textOnLight);
const TextStyle t3Heading =
    TextStyle(fontSize: 20, height: 1.25, fontWeight: FontWeight.w800, color: TkColors.textOnLight);
const TextStyle t3Meta = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TkColors.textMutedOnLight);

/// Grey legend line under a map: "Striped = hazard • Flag = refuge".
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Text(
        items.join('  •  '),
        style: const TextStyle(color: TkColors.textMutedOnDark, fontSize: 16, fontWeight: FontWeight.w700),
      );
}

/// Card of the light screens (.t3-card): pink, or grey with [plain].
class LightCard extends StatelessWidget {
  const LightCard({super.key, this.plain = false, required this.children});

  final bool plain;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: plain ? TkColors.lightCard : TkColors.lightCardPink,
          borderRadius: BorderRadius.circular(TkSizes.radiusCard),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: TkColors.textOnLight),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: children),
        ),
      );
}

/// Icon + bold line at the top of a [LightCard].
class CardHead extends StatelessWidget {
  const CardHead({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        spacing: 12,
        children: [
          Icon(icon, size: 26, color: TkColors.textOnLight),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3))),
        ],
      );
}

/// Pill-shaped row of the light screens (.t3-row).
class LightRow extends StatelessWidget {
  const LightRow({
    super.key,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? TkColors.yellow : TkColors.lightCard,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: padding,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      );
}
