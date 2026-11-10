// S05 offline saved guide (grey tone). Same FB4 handling as S03 when the location is approximate.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'headline': 'Go uphill.', 'guide': 'TSUNAMI GUIDE', 'leaveCar': 'Leave the car. Go on foot.'},
  Lang.ja: {'headline': '高台へ。', 'guide': '津波ガイド', 'leaveCar': '車を降りて、歩いて避難。'},
  Lang.zhHans: {'headline': '去高处。', 'guide': '海啸指南', 'leaveCar': '下车，步行避难。'},
  Lang.ko: {'headline': '높은 곳으로.', 'guide': '쓰나미 안내', 'leaveCar': '차에서 내려 걸어서 대피하세요.'},
  Lang.ar: {'headline': 'اصعد إلى مكان مرتفع.', 'guide': 'دليل التسونامي', 'leaveCar': 'اترك السيارة وامشِ.'},
};

class S05Screen extends StatelessWidget {
  const S05Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final c = context.common;
    final g = guideT(context);
    final t = context.t(_dict);
    final headline = state.goHigher != null ? g['goHigher'] : t['headline'];
    final leaveCar = state.eqSituation == EqSituation.car ? t['leaveCar'] : null;
    final approximate = isLocationApproximate(state);
    final signs = approximate ? g['followSigns'] : null;
    final spoken = [headline, ?leaveCar, ?signs].join(' ');
    final onHighGround = BigButton(
      label: c.onHighGround,
      variant: BigButtonVariant.outline,
      icon: approximate ? null : Icons.flag_outlined,
      onTap: () => context.store.patch(const StatePatch(onHighGround: true)),
    );
    return AnnounceOnEnter(
      text: spoken,
      child: GuidanceLayout(
        tone: GuidanceTone.grey,
        band: const AlertBand(),
        badge: TkBadge(label: [c.badgeOffline, c.badgeSavedGuide], icon: Icons.schedule),
        pictogram: const Pictogram(PictogramKind.goUphill),
        headline: headline,
        subline: t['guide'],
        note: [?leaveCar, ?signs, c.routeUnverified].join('\n'),
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
                    label: c.savedMap,
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
