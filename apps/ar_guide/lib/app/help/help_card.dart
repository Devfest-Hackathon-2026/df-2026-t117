// Feature F "Ask for help in Japanese": a full-screen card to show to (or play for) Japanese people nearby.
// Large Japanese text, its meaning in the user's language below, and a play / stop button for the Chirp 3 HD
// clip (help_voice.dart). Opened from S04 (route guidance) and S10 (emergency call) by [HelpJaButton].
// Everything of the feature lives in lib/app/help/, so it can be removed by reverting one merge.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../platform/app_platform.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import 'help_card_open.dart';
import 'help_strings.dart';
import 'help_voice.dart';

/// Makes the card's player. Tests replace it to pass a fake output.
HelpVoice Function(AppPlatform guidance) createHelpVoice = (guidance) => HelpVoice(guidance: guidance);

/// Opens the card over the current screen (Android back or the close button returns).
Future<void> openHelpCard(BuildContext context) {
  final store = context.store;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AppScope(store: store, child: const HelpCard()),
    ),
  );
}

/// The entry button. On dark screens (S04) an outline pill, on light screens (S10) a black one.
class HelpJaButton extends StatelessWidget {
  const HelpJaButton({super.key, this.theme = TkTheme.dark, this.padding = EdgeInsets.zero});

  final TkTheme theme;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.t(helpDict);
    return Padding(
      padding: padding,
      child: BigButton(
        key: const ValueKey('help-ja-entry'),
        label: t['entry'],
        variant: theme == TkTheme.dark ? BigButtonVariant.outline : BigButtonVariant.black,
        icon: Icons.record_voice_over_outlined,
        onTap: () => openHelpCard(context),
      ),
    );
  }
}

class HelpCard extends StatefulWidget {
  const HelpCard({super.key});

  @override
  State<HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<HelpCard> {
  late final HelpVoice _voice = createHelpVoice(context.store.platform);

  @override
  void initState() {
    super.initState();
    helpCardsOpen.value++; // no "device raised -> AR" while the card is shown (help_card_open.dart)
    // Plays once on opening: the card is opened to be heard. The button replays or stops it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _voice.play();
    });
  }

  @override
  void dispose() {
    helpCardsOpen.value--;
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final c = context.common;
    final t = context.t(helpDict);
    const ink = TkColors.textOnLight;
    return Directionality(
      textDirection: textDirectionOf(lang),
      child: TkFontScope(
        lang: lang,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: ink,
            fontSize: TkSizes.fsBody,
            locale: localeOf(lang),
            decoration: TextDecoration.none,
          ),
          child: Material(
            color: TkColors.lightBg,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(TkSizes.gutter - 2, 8, TkSizes.gutter, 0),
                    child: Row(
                      spacing: 12,
                      children: [
                        Material(
                          color: TkColors.lightCard,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: const ValueKey('help-ja-close'),
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: SizedBox(
                              width: TkSizes.roundBtn,
                              height: TkSizes.roundBtn,
                              child: Icon(Icons.close, size: 26, color: ink, semanticLabel: c.close),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              color: TkColors.textMutedOnLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 18, TkSizes.gutter, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 18,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                            decoration: BoxDecoration(
                              color: TkColors.white,
                              borderRadius: BorderRadius.circular(TkSizes.radiusCard),
                              border: Border.all(color: TkColors.red, width: 4),
                            ),
                            // The Japanese is always left-to-right with Japanese glyphs, also in Arabic.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 14,
                              children: [
                                for (final line in helpJaLines)
                                  Text(
                                    line,
                                    textDirection: TextDirection.ltr,
                                    style: TkFonts.japaneseName.copyWith(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      height: 1.3,
                                      color: ink,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (lang != Lang.ja)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 6,
                              children: [
                                Text(
                                  t['meaningLabel'],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: TkColors.textMutedOnLight,
                                  ),
                                ),
                                Text(
                                  t['meaning1'],
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
                                ),
                                Text(
                                  t['meaning2'],
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 0, TkSizes.gutter, 0),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _voice.playing,
                      builder: (context, playing, _) => Semantics(
                        button: true,
                        label: playing ? t['stopAria'] : t['playAria'],
                        excludeSemantics: true,
                        child: BigButton(
                          key: const ValueKey('help-ja-play'),
                          label: playing ? t['stop'] : t['play'],
                          variant: playing ? BigButtonVariant.black : BigButtonVariant.primary,
                          icon: playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                          onTap: playing ? _voice.stop : _voice.play,
                        ),
                      ),
                    ),
                  ),
                  FooterMeta(theme: TkTheme.light, items: [c.translationNote]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
