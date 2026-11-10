// S03 tsunami warning: evacuate now.
// - Sent on again from a waiting place (goHigher, F85 / F88): "Go higher." (+ NOW when the margin is not enough).
// - Location approximate / missing (FB4, F92 / F94): no route; "Follow the blue evacuation signs" and a
//   small "Set location" (opens S07 by hand) replace "Evacuation map".
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'headline': 'Go uphill.', 'now': 'NOW', 'leaveCar': 'Leave the car. Go on foot.'},
  Lang.ja: {'headline': '高台へ。', 'now': '今すぐ', 'leaveCar': '車を降りて、歩いて避難。'},
  Lang.zhHans: {'headline': '去高处。', 'now': '立即', 'leaveCar': '下车，步行避难。'},
  Lang.ko: {'headline': '높은 곳으로.', 'now': '지금 바로', 'leaveCar': '차에서 내려 걸어서 대피하세요.'},
  Lang.ar: {'headline': 'اصعد إلى مكان مرتفع.', 'now': 'الآن', 'leaveCar': 'اترك السيارة وامشِ.'},
};

class S03Screen extends StatelessWidget {
  const S03Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final lang = state.lang;
    final c = context.common;
    final g = guideT(context);
    final t = context.t(_dict);
    final action = topPriorityAction(state);
    final actionAlert = action.alert;
    final alert = actionAlert != null && actionAlert.type == HazardType.tsunami
        ? actionAlert
        : mostSevere(state.alerts, HazardType.tsunami);
    final badge = alert != null ? alertBadgeLabel(alert, lang) : c.badgeTsunami;
    final headline = state.goHigher != null ? g['goHigher'] : t['headline'];
    final showNow =
        state.goHigher == GoHigher.now || (action.kind == PriorityKind.goUphillNow && state.goHigher != GoHigher.calm);
    // Was in a car when the earthquake hit: evacuate on foot, not by car.
    final leaveCar = state.eqSituation == EqSituation.car ? t['leaveCar'] : null;
    final approximate = isLocationApproximate(state);
    final signs = approximate ? g['followSigns'] : null;
    final spoken = [headline, if (showNow) t['now'], ?leaveCar, ?signs].join(' ');
    final note = [?leaveCar, ?signs].join('\n');
    final onHighGround = BigButton(
      label: c.onHighGround,
      variant: BigButtonVariant.outline,
      icon: approximate ? null : Icons.flag_outlined,
      onTap: () => context.store.patch(const StatePatch(onHighGround: true)),
    );
    return AnnounceOnEnter(
      text: spoken,
      child: GuidanceLayout(
        band: const AlertBand(),
        badge: TkBadge(label: badge),
        pictogram: const Pictogram(PictogramKind.goUphill),
        headline: headline,
        subline: showNow ? t['now'] : null,
        sublineLarge: true,
        note: note.isEmpty ? null : note,
        actions: approximate
            ? ButtonRow(
                children: [
                  BigButton(
                    label: g['setLocation'],
                    variant: BigButtonVariant.dark,
                    icon: Icons.place,
                    compact: true,
                    onTap: () => context.store.navigate(ScreenId.s07),
                  ),
                  onHighGround,
                ],
              )
            : ButtonStack(
                children: [
                  BigButton(
                    label: c.evacuationMap,
                    icon: Icons.map_outlined,
                    onTap: () => context.store.patch(const StatePatch(guideStep: GuideStep.nav)),
                  ),
                  onHighGround,
                ],
              ),
        listen: ListenButton(text: spoken),
        footer: const GuideFooter(),
      ),
    );
  }
}
