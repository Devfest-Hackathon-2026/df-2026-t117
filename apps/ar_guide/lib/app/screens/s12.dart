// S12 AR paused: device raised but position / heading / tracking not good enough (F3B).
// Route arrows are hidden; the user can set the location (S07) or go to the action guide.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../logic/nav.dart';
import '../logic/nav_effects.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'title': 'Check location', 'sub': 'Camera position uncertain', 'setLocation': 'Set location', 'actionGuide': 'Action guide', 'hidden': 'Route arrows hidden', 'mapLabel': 'Town map (route hidden)'},
  Lang.ja: {'title': '現在地を確認', 'sub': 'カメラの位置が不確かです', 'setLocation': '現在地を設定', 'actionGuide': '行動の案内', 'hidden': '経路の矢印を非表示中', 'mapLabel': '町の地図（経路は非表示）'},
  Lang.zhHans: {'title': '确认位置', 'sub': '相机位置不确定', 'setLocation': '设置位置', 'actionGuide': '行动指引', 'hidden': '已隐藏路线箭头', 'mapLabel': '城镇地图（已隐藏路线）'},
  Lang.ko: {'title': '위치 확인', 'sub': '카메라 위치가 불확실합니다', 'setLocation': '위치 설정', 'actionGuide': '행동 안내', 'hidden': '경로 화살표 숨김', 'mapLabel': '마을 지도(경로 숨김)'},
  Lang.ar: {'title': 'تحقق من الموقع', 'sub': 'موضع الكاميرا غير مؤكد', 'setLocation': 'حدد الموقع', 'actionGuide': 'دليل التصرف', 'hidden': 'أسهم المسار مخفية', 'mapLabel': 'خريطة البلدة (المسار مخفي)'},
};

class S12Screen extends StatelessWidget {
  const S12Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final lang = context.lang;
    final nav = context.nav;
    final t = context.t(_dict);
    return SubLayout(
      headerTitle: c.titleMapGuidance,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TkHeader(variant: HeaderVariant.sub, title: c.titleMapGuidance),
          const AlertBand(),
        ],
      ),
      badge: TkBadge(label: c.badgeArPaused),
      title: t['title'],
      subtitle: t['sub'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // Position is uncertain: no route line and no position marker (F3B).
          AspectRatio(
            aspectRatio: 810 / 700,
            child: TownMap(
              variant: TownMapVariant.full,
              routeColor: RouteColor.none,
              showPosition: false,
              semanticLabel: t['mapLabel'],
              fill: true,
            ),
          ),
          MapLegend(items: [c.stripedHazard, c.flagRefuge]),
        ],
      ),
      actions: ButtonStack(
        children: [
          BigButton(
            label: t['setLocation'],
            icon: Icons.place,
            onTap: () => context.store.navigate(ScreenId.s07),
          ),
          BigButton(
            label: t['actionGuide'],
            variant: BigButtonVariant.dark,
            icon: Icons.arrow_back,
            onTap: () => context.store.patch(const StatePatch(guideStep: GuideStep.action, deviceRaised: false)),
          ),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // F80 / F81: fixed Listen button; reads the next turn of the same route as S04 / S11.
          ListenButton(
            text: turnSpeech(lang, nav.nextTurn?.direction ?? TurnDirection.straight, nav.nextTurn?.distanceM ?? 0),
          ),
          FooterMeta(items: [t['hidden']]),
        ],
      ),
    );
  }
}
