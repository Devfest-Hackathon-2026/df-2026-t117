// S02 earthquake, shaking now. Tap the badge to cycle INDOORS -> OUTDOORS -> IN CAR (decision 12-4).
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'indoors': 'Protect your head', 'outdoors': 'Protect your head', 'outdoorsSub': 'Stay away from buildings', 'car': 'Pull over. Stay inside.', 'carSub': 'Wait until the shaking stops', 'switchSituation': 'Change situation'},
  Lang.ja: {'indoors': '頭を守れ', 'outdoors': '頭を守れ', 'outdoorsSub': '建物から離れる', 'car': '停車。車内で待つ。', 'carSub': '揺れがおさまるまで', 'switchSituation': '状況を切り替え'},
  Lang.zhHans: {'indoors': '保护头部', 'outdoors': '保护头部', 'outdoorsSub': '远离建筑物', 'car': '靠边停车，留在车内。', 'carSub': '等到摇晃停止', 'switchSituation': '切换场景'},
  Lang.ko: {'indoors': '머리를 보호하세요', 'outdoors': '머리를 보호하세요', 'outdoorsSub': '건물에서 떨어지세요', 'car': '정차하고 차 안에 머무르세요.', 'carSub': '흔들림이 멈출 때까지', 'switchSituation': '상황 전환'},
  Lang.ar: {'indoors': 'احمِ رأسك', 'outdoors': 'احمِ رأسك', 'outdoorsSub': 'ابتعد عن المباني', 'car': 'توقف وابقَ في السيارة.', 'carSub': 'حتى يتوقف الاهتزاز', 'switchSituation': 'تغيير الحالة'},
};

const Map<EqSituation, EqSituation> _next = {
  EqSituation.indoors: EqSituation.outdoors,
  EqSituation.outdoors: EqSituation.car,
  EqSituation.car: EqSituation.indoors,
};

class S02Screen extends StatelessWidget {
  const S02Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final eq = context.appState.eqSituation;
    final lang = context.lang;
    final c = context.common;
    final t = context.t(_dict);
    final headline = t[eq.name];
    final subline = switch (eq) {
      EqSituation.outdoors => t['outdoorsSub'],
      EqSituation.car => t['carSub'],
      EqSituation.indoors => null,
    };
    final spoken = subline != null ? '$headline $subline' : headline;
    final picto = switch (eq) {
      EqSituation.indoors => PictogramKind.protectHead,
      EqSituation.outdoors => PictogramKind.outdoorsProtect,
      EqSituation.car => PictogramKind.stayInCar,
    };
    return AnnounceOnEnter(
      text: spoken,
      child: GuidanceLayout(
        band: const AlertBand(),
        badge: Semantics(
          button: true,
          label: '${c.badgeEarthquake} / ${eqSituationLabel(eq, lang)} - ${t['switchSituation']}',
          child: TkBadge(
            label: [c.badgeEarthquake, eqSituationLabel(eq, lang)],
            onTap: () => context.store.patch(StatePatch(eqSituation: _next[eq])),
          ),
        ),
        pictogram: Pictogram(picto),
        headline: headline,
        subline: subline,
        actions: BigButton(
          label: c.shakingStopped,
          variant: BigButtonVariant.white,
          icon: Icons.arrow_forward,
          onTap: () => context.store.patch(const StatePatch(shaking: false)),
        ),
        listen: ListenButton(text: spoken),
        footer: const GuideFooter(),
      ),
    );
  }
}
