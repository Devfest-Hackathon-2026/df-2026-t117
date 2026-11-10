// Shared components. Port of mocks/evacuate/src/components: PhoneFrame, StatusBar, Header, BigButton,
// Badge, FooterMeta, GuidanceLayout, SubLayout, Toast, and the fixed ListenButton (F80-F82).
// Directional paddings are used throughout, so everything mirrors in Arabic.
import 'package:flutter/material.dart';

import 'demo/demo_panel.dart';
import 'i18n/i18n.dart';
import 'state/store.dart';
import 'state/time.dart';
import 'state/types.dart';
import 'theme.dart';

/// A String becomes a [Text]; a Widget is used as it is.
Widget _content(Object value, {TextStyle? style, TextAlign? textAlign}) =>
    value is Widget ? value : Text('$value', style: style, textAlign: textAlign);

// ---------------------------------------------------------------------------
// Frame

/// The frame of every screen: status bar (virtual clock + DEMO), content, toast, "screen off" blackout
/// and the tab that opens the demo panel. With [fullBleed] the screen draws everything itself (S11).
class PhoneFrame extends StatefulWidget {
  const PhoneFrame({super.key, this.theme = TkTheme.dark, this.fullBleed = false, required this.child});

  final TkTheme theme;
  final bool fullBleed;
  final Widget child;

  @override
  State<PhoneFrame> createState() => _PhoneFrameState();
}

class _PhoneFrameState extends State<PhoneFrame> {
  bool _panelOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final theme = widget.theme;
    final screen = Directionality(
      textDirection: textDirectionOf(state.lang),
      child: DefaultTextStyle(
        style: TextStyle(
          color: TkColors.text(theme),
          fontSize: TkSizes.fsBody,
          locale: localeOf(state.lang),
          decoration: TextDecoration.none,
        ).merge(TkFonts.style(state.lang)),
        child: widget.fullBleed
            ? widget.child
            : SafeArea(
                child: Column(
                  children: [
                    TkStatusBar(theme: theme),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
      ),
    );
    // The font scope also covers the toast and the Material theme of S11's Scaffold.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TkFontScope(
        lang: state.lang,
        child: Material(
          color: TkColors.background(theme),
          child: Stack(
            children: [
              Positioned.fill(child: screen),
              if (state.toast != null) _Toast(message: state.toast!),
              if (state.screenOff) const _ScreenOff(),
              Align(
                alignment: Alignment.centerRight,
                child: _DemoTab(onTap: () => setState(() => _panelOpen = true)),
              ),
              if (_panelOpen) _DemoSheet(onClose: () => setState(() => _panelOpen = false)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Virtual clock (JST) on the left, DEMO badge on the right (always shown, never mirrored).
class TkStatusBar extends StatelessWidget {
  const TkStatusBar({super.key, this.theme = TkTheme.dark});

  final TkTheme theme;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: TkSizes.statusH,
        color: TkColors.background(theme),
        padding: const EdgeInsets.symmetric(horizontal: TkSizes.gutter),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatJst(context.appState.now), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Text('DEMO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: TkSizes.gutter,
      right: TkSizes.gutter,
      bottom: 96,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: TkColors.black, borderRadius: BorderRadius.circular(TkSizes.radiusBadge)),
          child: Text(
            message,
            textAlign: TextAlign.center,
            textDirection: textDirectionOf(context.lang),
            style: const TextStyle(color: TkColors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Screen-off blackout (F34). Walk simulation, voice and vibration keep running underneath.
class _ScreenOff extends StatelessWidget {
  const _ScreenOff();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.store.patch(const StatePatch(screenOff: false)),
        child: const ColoredBox(
          color: Color(0xFF000000),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Text(
                'Screen off (demo) · tap to wake',
                style: TextStyle(color: Color(0xFF3D3A40), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoTab extends StatelessWidget {
  const _DemoTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open demo panel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 26,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xD1FFFFFF),
            borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 2))],
          ),
          child: const Icon(Icons.tune, size: 18, color: TkColors.textOnLight),
        ),
      ),
    );
  }
}

class _DemoSheet extends StatelessWidget {
  const _DemoSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(onTap: onClose, child: const ColoredBox(color: Color(0x80000000))),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.8,
              child: Material(
                color: const Color(0xFFF6F3F1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: DefaultTextStyle(
                  style: const TextStyle(color: TkColors.textOnLight, fontSize: 14),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Demo panel', style: TextStyle(fontWeight: FontWeight.w800)),
                              IconButton(
                                onPressed: onClose,
                                icon: const Icon(Icons.close, color: TkColors.textOnLight),
                                tooltip: context.common.close,
                              ),
                            ],
                          ),
                        ),
                        const Expanded(child: DemoPanel()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header

enum HeaderVariant { brand, sub }

enum HeaderAccent { yellow, red, none }

/// `brand` = TASUKU logo (guidance screens). `sub` = back arrow + title (sub screens).
/// Globe (-> S09) and phone (-> S10) buttons are always present (requirements 4, common).
class TkHeader extends StatelessWidget {
  const TkHeader({
    super.key,
    this.variant = HeaderVariant.brand,
    this.title,
    this.theme = TkTheme.dark,
    this.onBack,
    this.accent = HeaderAccent.none,
  });

  final HeaderVariant variant;

  /// Title for [HeaderVariant.sub].
  final String? title;
  final TkTheme theme;

  /// Overrides the back behavior (default: store.back).
  final VoidCallback? onBack;

  /// Colored rule under the header: yellow on guidance screens (S02-S06), red on S11.
  final HeaderAccent accent;

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final color = TkColors.text(theme);
    final rule = switch (accent) {
      HeaderAccent.yellow => TkColors.yellow,
      HeaderAccent.red => TkColors.red,
      HeaderAccent.none => null,
    };
    Widget round(IconData icon, String label, VoidCallback onTap) => _RoundButton(
          icon: icon,
          label: label,
          theme: theme,
          onTap: onTap,
        );
    return Container(
      decoration: BoxDecoration(
        color: TkColors.background(theme),
        border: rule == null ? null : Border(bottom: BorderSide(color: rule, width: 5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TkSizes.gutter - 2),
      height: TkSizes.headerH + (rule == null ? 0 : 5),
      child: Row(
        children: [
          if (variant == HeaderVariant.sub) ...[
            round(Icons.arrow_back, c.back, onBack ?? () => context.store.back()),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: variant == HeaderVariant.brand
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'TASUKU',
                      textDirection: TextDirection.ltr,
                      style: TkText.heading.copyWith(fontSize: 25, color: color),
                    ),
                  )
                : Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TkText.heading.copyWith(fontSize: 21, color: color),
                  ),
          ),
          round(Icons.language, c.changeLanguage, () => context.store.navigate(ScreenId.s09)),
          const SizedBox(width: 6),
          round(Icons.phone, c.emergencyCall, () => context.store.navigate(ScreenId.s10)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.theme, required this.onTap});

  final IconData icon;
  final String label;
  final TkTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme == TkTheme.dark ? TkColors.btnDark : TkColors.lightCard,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: TkSizes.roundBtn,
          height: TkSizes.roundBtn,
          child: Icon(icon, size: 26, color: TkColors.text(theme), semanticLabel: label),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons

enum BigButtonVariant { primary, white, dark, outline, black }

/// Large pill button (min height 58). The icon sits at the inline-start edge, the label is centered.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.variant = BigButtonVariant.primary,
    this.icon,
    this.onTap,
    this.compact = false,
  });

  final String label;

  /// primary = yellow, white, dark = #2A272C, outline = transparent w/ light border, black = on light screens.
  final BigButtonVariant variant;
  final IconData? icon;

  /// null = disabled.
  final VoidCallback? onTap;

  /// Narrower share in a [ButtonRow] (e.g. next to "On high ground").
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      BigButtonVariant.primary => (TkColors.yellow, TkColors.textOnLight),
      BigButtonVariant.white => (TkColors.white, TkColors.textOnLight),
      BigButtonVariant.dark => (TkColors.btnDark, TkColors.textOnDark),
      BigButtonVariant.outline => (Colors.transparent, TkColors.textOnDark),
      BigButtonVariant.black => (TkColors.black, TkColors.white),
    };
    final side = variant == BigButtonVariant.outline
        ? const BorderSide(color: TkColors.outlineOnDark, width: 2)
        : BorderSide.none;
    final shape = StadiumBorder(side: side);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TkSizes.btnH),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (icon != null)
                  PositionedDirectional(start: 16, child: Icon(icon, size: 28, color: fg)),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(icon != null ? 56 : 18, 10, 18, 10),
                  child: Text(label, textAlign: TextAlign.center, style: TkText.button.copyWith(color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of buttons (e.g. a compact one next to "On high ground").
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children});

  final List<BigButton> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(flex: children[i].compact ? 2 : 3, child: children[i]),
        ],
      ],
    );
  }
}

/// Vertical stack of buttons with the standard gap.
class ButtonStack extends StatelessWidget {
  const ButtonStack({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badge, source line

enum BadgeTone { yellow, red }

/// Status pill: "(warning) TSUNAMI WARNING". [label] is a String, or a `List<String>` joined with " / ".
class TkBadge extends StatelessWidget {
  const TkBadge({
    super.key,
    required this.label,
    this.icon = Icons.warning_rounded,
    this.tone = BadgeTone.yellow,
    this.small = false,
    this.onTap,
  });

  final Object label;

  /// null = no icon.
  final IconData? icon;
  final BadgeTone tone;
  final bool small;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = tone == BadgeTone.yellow ? TkColors.textOnLight : TkColors.white;
    final text = (label is List ? (label as List).join('  /  ') : '$label').toUpperCase();
    final child = Container(
      constraints: BoxConstraints(minHeight: small ? 24 : 32),
      padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 3 : 6),
      decoration: BoxDecoration(
        color: tone == BadgeTone.yellow ? TkColors.yellow : TkColors.red,
        borderRadius: BorderRadius.circular(TkSizes.radiusBadge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 16 : 20, color: fg),
            SizedBox(width: small ? 6 : 10),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: small ? 12 : TkSizes.fsBadge,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}

/// Small grey centered source line: "JMA • 09:40 JST • Details". Items are joined with " • ".
/// An item is a String or a Widget; null and '' are skipped.
class FooterMeta extends StatelessWidget {
  const FooterMeta({super.key, required this.items, this.theme = TkTheme.dark});

  final List<Object?> items;
  final TkTheme theme;

  @override
  Widget build(BuildContext context) {
    final style = TkText.meta.copyWith(color: TkColors.muted(theme));
    final visible = items.where((i) => i != null && i != '').cast<Object>().toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 14, TkSizes.gutter, 18),
      child: DefaultTextStyle.merge(
        style: style,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•')),
                _content(visible[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Link-like button inside [FooterMeta] (e.g. "Details" -> A02).
class MetaLink extends StatelessWidget {
  const MetaLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), child: Text(label)),
    );
  }
}

// ---------------------------------------------------------------------------
// The fixed Listen button (F80-F82)

/// Exactly one on every guidance screen, in the same place: right above the source line at the
/// inline-start edge (left; right in Arabic). Pass it as `listen:` of [GuidanceLayout].
/// S11 puts it at the start of the bottom MAP sheet's top row ([inSheet]).
/// Tap: reads [text]. While anything is being read aloud it turns into "Stop".
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.text, this.inSheet = false});

  final String text;
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final t = context.t(listenDict);
    final lang = context.lang;
    final platform = context.store.platform;
    final button = ValueListenableBuilder<bool>(
      valueListenable: platform.speaking,
      builder: (context, speaking, _) {
        final fg = speaking ? TkColors.textOnLight : TkColors.textOnDark;
        final shape = StadiumBorder(
          side: speaking ? BorderSide.none : const BorderSide(color: TkColors.outlineOnDark, width: 2),
        );
        return Semantics(
          button: true,
          label: speaking ? t['stopAria'] : t['listenAria'],
          child: Material(
            color: speaking ? TkColors.yellow : TkColors.btnDark,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: () {
                if (speaking) {
                  platform.cancelSpeech();
                } else if (!platform.speak(text, lang)) {
                  context.store.showToast(t['unavailable']);
                }
              },
              child: Container(
                constraints: const BoxConstraints(minWidth: 132, minHeight: TkSizes.btnH),
                padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 22, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded, size: 26, color: fg),
                    const SizedBox(width: 10),
                    Text(speaking ? t['stop'] : c.listen, style: TkText.button.copyWith(color: fg)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (inSheet) return button;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(TkSizes.gutter, 14, TkSizes.gutter, 0),
      child: Align(alignment: AlignmentDirectional.centerStart, child: button),
    );
  }
}

// ---------------------------------------------------------------------------
// Layouts

/// Fills the available height and scrolls when the content is taller.
class ScrollFill extends StatelessWidget {
  const ScrollFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

enum GuidanceTone { red, maroon, grey }

enum PictogramBg { pink, cream, none }

/// Common guidance structure (S02, S03, S05, S06; requirements 4):
///   Header (TASUKU, yellow rule)
///   Top panel (red / maroon / grey): badge -> pictogram card -> headline -> sub-line -> note
///   Dark bottom area: buttons -> fixed Listen button -> source line
class GuidanceLayout extends StatelessWidget {
  const GuidanceLayout({
    super.key,
    this.tone = GuidanceTone.red,
    this.header,
    this.band,
    this.badge,
    this.pictogram,
    this.pictogramBg = PictogramBg.pink,
    required this.headline,
    this.subline,
    this.sublineLarge = false,
    this.note,
    this.topExtra,
    this.actions,
    this.listen,
    this.footer,
  });

  /// red = alert (S02/S03/S04), maroon = waiting (S06), grey = offline (S05).
  final GuidanceTone tone;

  /// Replaces the default header.
  final Widget? header;

  /// Right under the header, e.g. the alert-change band (F88).
  final Widget? band;
  final Widget? badge;
  final Widget? pictogram;
  final PictogramBg pictogramBg;

  /// Main instruction: String or Widget.
  final Object headline;

  /// Yellow line under the headline: "NOW" (large) / "TSUNAMI GUIDE", "HIGH GROUND" (small). String or Widget.
  final Object? subline;
  final bool sublineLarge;

  /// White secondary line, e.g. "Route unverified". String or Widget.
  final Object? note;

  /// Anything else at the end of the top panel (e.g. S04 mini map).
  final Widget? topExtra;

  /// Bottom area content: BigButton / ButtonRow / ButtonStack.
  final Widget? actions;

  /// The fixed [ListenButton].
  final Widget? listen;

  /// Usually a [FooterMeta].
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final panel = switch (tone) {
      GuidanceTone.red => TkColors.red,
      GuidanceTone.maroon => TkColors.maroon,
      GuidanceTone.grey => TkColors.panelGrey,
    };
    final sub = subline;
    final subStyle = TkText.heading.copyWith(
      color: TkColors.yellow,
      fontSize: sublineLarge ? TkText.headline(lang).fontSize : 22,
      height: sublineLarge ? 1 : null,
      fontWeight: sublineLarge ? FontWeight.w900 : FontWeight.w800,
    );
    final picto = pictogram;
    final noteValue = note;
    return ScrollFill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header ?? const TkHeader(accent: HeaderAccent.yellow),
          ?band,
          Expanded(
            child: Container(
              color: panel,
              padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 14, TkSizes.gutter, 28),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: TkColors.textOnDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (badge != null) ...[
                      Align(alignment: AlignmentDirectional.centerStart, child: badge),
                      const SizedBox(height: 18),
                    ],
                    if (picto != null) ...[
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 140, maxHeight: 260),
                          child: _PictogramCard(bg: pictogramBg, child: picto),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _content(headline, style: TkText.headline(lang).copyWith(color: TkColors.textOnDark)),
                    if (sub != null) ...[
                      const SizedBox(height: 8),
                      _content(sub is String ? sub.toUpperCase() : sub, style: subStyle),
                    ],
                    if (noteValue != null) ...[
                      const SizedBox(height: 14),
                      _content(noteValue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                    if (topExtra != null) ...[
                      const SizedBox(height: 18),
                      topExtra!,
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: TkColors.bgDark,
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actions != null)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: TkSizes.gutter), child: actions),
                ?listen,
                ?footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PictogramCard extends StatelessWidget {
  const _PictogramCard({required this.bg, required this.child});

  final PictogramBg bg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = switch (bg) {
      PictogramBg.pink => TkColors.pictoBg,
      PictogramBg.cream => TkColors.pictoBgCream,
      PictogramBg.none => Colors.transparent,
    };
    return Container(
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      padding: bg == PictogramBg.none ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(TkSizes.radiusCard)),
      child: child,
    );
  }
}

/// Sub-screen structure (S07-S10, S12, A01-A04): Header sub (back + title) -> optional badge ->
/// big page title -> content -> actions pushed toward the bottom -> source line.
class SubLayout extends StatelessWidget {
  const SubLayout({
    super.key,
    required this.headerTitle,
    this.theme = TkTheme.dark,
    this.onBack,
    this.header,
    this.badge,
    this.title,
    this.subtitle,
    this.content,
    this.actions,
    this.footer,
  });

  final String headerTitle;
  final TkTheme theme;
  final VoidCallback? onBack;

  /// Replaces the default header entirely.
  final Widget? header;
  final Widget? badge;

  /// Large page title (String or Widget), e.g. "Set a pin", "Language", "Call for help".
  final Object? title;

  /// Line under the title (String or Widget), e.g. "GPS accuracy ±180 m".
  final Object? subtitle;
  final Widget? content;

  /// Buttons, placed after content and pushed to the lower half.
  final Widget? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final titleValue = title;
    final subtitleValue = subtitle;
    return ScrollFill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header ?? TkHeader(variant: HeaderVariant.sub, title: headerTitle, theme: theme, onBack: onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 18, TkSizes.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (badge != null) ...[
                    Align(alignment: AlignmentDirectional.centerStart, child: badge),
                    const SizedBox(height: 18),
                  ],
                  if (titleValue != null) ...[
                    _content(titleValue, style: TkText.title.copyWith(color: TkColors.text(theme))),
                    const SizedBox(height: 12),
                  ],
                  if (subtitleValue != null) ...[
                    _content(
                      subtitleValue,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TkColors.muted(theme)),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ?content,
                  const Spacer(),
                  if (actions != null) ...[
                    const SizedBox(height: 18),
                    actions!,
                  ],
                ],
              ),
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}
