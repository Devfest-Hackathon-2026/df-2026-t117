// S07 location uncertain: accuracy circle + draggable pin, "Use this pin", "Back to guidance".
// Only opened by hand (FB4 / F90 / F94), pushed on the overlay stack. Route guidance is paused while shown.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'title': 'Set a pin', 'accuracy': 'GPS accuracy', 'denied': 'Location access is off', 'circle': 'Circle = estimated location', 'tap': 'Tap or drag the map to move the pin', 'usePin': 'Use this pin', 'mapLabel': 'Map: tap to place the pin'},
  Lang.ja: {'title': 'ピンを置く', 'accuracy': 'GPS の誤差', 'denied': '位置情報がオフです', 'circle': '円 = 推定される現在地', 'tap': '地図をタップ／ドラッグしてピンを動かす', 'usePin': 'このピンを使う', 'mapLabel': '地図：タップしてピンを置く'},
  Lang.zhHans: {'title': '放置图钉', 'accuracy': 'GPS 精度', 'denied': '位置权限已关闭', 'circle': '圆圈 = 估计位置', 'tap': '点按或拖动地图来移动图钉', 'usePin': '使用此图钉', 'mapLabel': '地图：点按放置图钉'},
  Lang.ko: {'title': '핀 놓기', 'accuracy': 'GPS 정확도', 'denied': '위치 권한이 꺼져 있습니다', 'circle': '원 = 추정 위치', 'tap': '지도를 탭하거나 끌어서 핀을 옮기세요', 'usePin': '이 핀 사용', 'mapLabel': '지도: 탭하여 핀 놓기'},
  Lang.ar: {'title': 'ضع دبوسًا', 'accuracy': 'دقة GPS', 'denied': 'الوصول إلى الموقع متوقف', 'circle': 'الدائرة = الموقع التقديري', 'tap': 'اضغط على الخريطة أو اسحبها لتحريك الدبوس', 'usePin': 'استخدم هذا الدبوس', 'mapLabel': 'الخريطة: اضغط لوضع الدبوس'},
};

class S07Screen extends StatefulWidget {
  const S07Screen({super.key});

  @override
  State<S07Screen> createState() => _S07ScreenState();
}

class _S07ScreenState extends State<S07Screen> {
  Point? _pin;

  /// True while a finger is on the map, so a vertical drag moves the pin instead of scrolling the screen.
  bool _scrollLocked = false;

  void _lockScroll(bool locked) {
    if (_scrollLocked != locked) setState(() => _scrollLocked = locked);
  }

  void _confirmPin(Point pin) {
    final store = context.store;
    store.patch(StatePatch(
      manualPin: pin,
      walk: const WalkPatch(progressM: 0),
      guideStep: GuideStep.nav,
      deviceRaised: false,
    ));
    store.back();
  }

  void _backToGuidance() {
    final store = context.store;
    store.back();
    store.patch(const StatePatch(deviceRaised: false));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final c = context.common;
    final t = context.t(_dict);
    // Start the pin at the current estimate (walk position on the route; = GPS / previous pin when not walking).
    final start = context.nav.position;
    final pin = _pin ??= Point(start.x.roundToDouble(), start.y.roundToDouble());
    final denied = state.gps.permission == GpsPermission.denied;
    final accuracy = fmt('±${c.meters}', {'n': state.gps.accuracyM.round()});
    final isolated = '${String.fromCharCode(0x2066)}$accuracy${String.fromCharCode(0x2069)}';
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        physics: _scrollLocked ? const NeverScrollableScrollPhysics() : null,
      ),
      child: SubLayout(
        headerTitle: c.titleLocation,
        badge: TkBadge(label: c.badgeLocationUncertain),
        title: t['title'],
        // The isolate marks keep "±180 m" left-to-right inside an Arabic line.
        subtitle: denied ? t['denied'] : '${t['accuracy']}  $isolated',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Listener(
              onPointerDown: (_) => _lockScroll(true),
              onPointerUp: (_) => _lockScroll(false),
              onPointerCancel: (_) => _lockScroll(false),
              child: AspectRatio(
                aspectRatio: 810 / 700,
                child: TownMap(
                  variant: TownMapVariant.full,
                  routeColor: RouteColor.none,
                  showAccuracy: !denied,
                  showPosition: !denied,
                  pinEditable: true,
                  controlledPin: true,
                  pin: pin,
                  onPinChange: (p) => setState(() => _pin = p),
                  semanticLabel: '${t['mapLabel']}. ${t['tap']}',
                  fill: true,
                ),
              ),
            ),
            MapLegend(items: [denied ? t['tap'] : t['circle']]),
          ],
        ),
        actions: ButtonStack(
          children: [
            BigButton(label: t['usePin'], icon: Icons.place, onTap: () => _confirmPin(pin)),
            BigButton(
              label: c.backToGuidance,
              variant: BigButtonVariant.dark,
              icon: Icons.arrow_forward,
              onTap: _backToGuidance,
            ),
          ],
        ),
        footer: FooterMeta(items: [c.routeGuidancePaused]),
      ),
    );
  }
}
