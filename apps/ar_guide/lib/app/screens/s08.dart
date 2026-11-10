// S08 saved map: bundled map without live closures (offline, F41 / F42).
// Shown for guideStep nav while offline (resolveScreen), or pushed on the overlay stack.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'mapLabel': 'Saved map of the town'},
  Lang.ja: {'mapLabel': '保存済みの町の地図'},
  Lang.zhHans: {'mapLabel': '已保存的城镇地图'},
  Lang.ko: {'mapLabel': '저장된 마을 지도'},
  Lang.ar: {'mapLabel': 'الخريطة المحفوظة للبلدة'},
};

class S08Screen extends StatelessWidget {
  const S08Screen({super.key});

  void _back(BuildContext context) {
    final store = context.store;
    final overlay = store.state.overlay;
    if (overlay.isNotEmpty && overlay.last == ScreenId.s08) {
      store.back();
    } else {
      store.patch(const StatePatch(guideStep: GuideStep.action)); // -> S05 (offline) / S03 (online)
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final c = context.common;
    final t = context.t(_dict);
    final f = freshness(state);
    final checkedAt = f.passabilityCheckedAt;
    final footer = !f.liveRoadStatus
        ? c.liveRoadUnavailable
        : (checkedAt != null ? '${c.passabilityChecked} ${formatJstLabel(checkedAt)}' : null);
    return SubLayout(
      headerTitle: c.titleSavedMap,
      badge: state.online ? null : TkBadge(label: c.badgeOffline, icon: Icons.schedule),
      title: c.savedMap,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // Offline: no live closures, no (unverified) route line; the position dot keeps moving while walking.
          TownMap(
            variant: TownMapVariant.full,
            routeColor: RouteColor.none,
            showClosures: state.online,
            semanticLabel: t['mapLabel'],
          ),
          MapLegend(items: [c.stripedHazard, c.flagRefuge]),
        ],
      ),
      actions: BigButton(
        label: c.backToGuidance,
        variant: BigButtonVariant.white,
        icon: Icons.arrow_back,
        onTap: () => _back(context),
      ),
      footer: FooterMeta(items: [footer]),
    );
  }
}
