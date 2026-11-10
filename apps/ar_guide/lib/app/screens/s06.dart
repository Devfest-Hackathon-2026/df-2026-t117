// S06 on high ground (maroon tone). FB2: the instruction comes with its grounds (MarginCard, F83-F85 / F87).
// Instruction by the margin check (14.3):
//  - ample, no forecast / location, or at a designated evacuation site -> "Stay here." / HIGH GROUND
//  - low (0-10 m)                                                        -> "Go higher." + "Evacuation map"
//  - short (< 0 m, or over 10 m forecast below 20 m)                    -> AlertEffects sends the user on again.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../logic/alert_effects.dart';
import '../logic/margin.dart';
import '../shelter/shelter_info.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'headline': 'Stay here.', 'active': 'ACTIVE'},
  Lang.ja: {'headline': 'ここで待機。', 'active': '発表中'},
  Lang.zhHans: {'headline': '留在这里。', 'active': '生效中'},
  Lang.ko: {'headline': '여기에 머무르세요.', 'active': '발령 중'},
  Lang.ar: {'headline': 'ابقَ هنا.', 'active': 'ساري'},
};

class S06Screen extends StatelessWidget {
  const S06Screen({super.key});

  void _goHigherCalmly(BuildContext context) {
    final store = context.store;
    final origin = rebaseOrigin(store.state, store.nav.position);
    store.patch(StatePatch(
      manualPin: origin.manualPin,
      gps: origin.gps,
      walk: origin.walk,
      onHighGround: false,
      goHigher: GoHigher.calm,
      guideStep: GuideStep.nav,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final lang = state.lang;
    final c = context.common;
    final g = guideT(context);
    final margin = context.margin;
    final text = marginText(margin, lang);
    final t = context.t(_dict);
    final alert = evacuationAlert(state) ?? mostSevere(state.alerts, HazardType.tsunami);
    final badge = alert != null ? '${alertBadgeLabel(alert, lang)} ${t['active']}' : c.badgeTsunamiWarningActive;
    final staying = margin.designated != null || margin.level == null || margin.level == MarginLevel.ample;
    final headline = staying ? t['headline'] : g['goHigher'];
    final subline = staying ? c.highGround : null;
    final spoken = [headline, ?subline, ?text.margin, if (margin.designated != null) text.staff].join(' ');
    return AnnounceOnEnter(
      text: spoken,
      child: GuidanceLayout(
        tone: GuidanceTone.maroon,
        band: const AlertBand(),
        badge: TkBadge(label: badge),
        pictogram: const Pictogram(PictogramKind.stayHere),
        pictogramBg: PictogramBg.cream,
        headline: headline,
        subline: subline,
        topExtra: MarginCard(margin: margin, staying: staying),
        actions: ButtonStack(
          children: [
            if (!staying)
              BigButton(
                label: c.evacuationMap,
                icon: Icons.map_outlined,
                onTap: () => _goHigherCalmly(context),
              ),
            BigButton(
              label: c.officialUpdates,
              variant: BigButtonVariant.outline,
              icon: Icons.schedule,
              onTap: () => context.store.navigate(ScreenId.a02),
            ),
          ],
        ),
        listen: ListenButton(text: spoken),
        footer: Column(children: [const ShelterInfo(), GuideFooter(freshTail: c.warningActive)]),
      ),
    );
  }
}
