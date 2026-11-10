// A01 location permission explanation (light). Allow -> granted; Choose on map -> denied + S07 opened by hand.
// If S07 is closed without a pin, guidance continues with the action guide + signs (FB4 / F94).
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'title': 'Use your location?', 'why1': 'Find the safest route to high ground', 'why2': 'Show your address to rescuers', 'stay': 'Your location stays on this device.', 'allow': 'Allow location', 'map': 'Choose on map', 'foot': 'You can change this later'},
  Lang.ja: {'title': '位置情報を使いますか？', 'why1': '高台までの安全な道を探します', 'why2': '救助する人にあなたの場所を伝えます', 'stay': '位置情報は端末の外に送信されません。', 'allow': '位置情報を許可', 'map': '地図で選ぶ', 'foot': '後から変更できます'},
  Lang.zhHans: {'title': '使用您的位置？', 'why1': '查找通往高处的最安全路线', 'why2': '向救援人员显示您的地址', 'stay': '您的位置仅保存在此设备上。', 'allow': '允许定位', 'map': '在地图上选择', 'foot': '稍后可以更改'},
  Lang.ko: {'title': '위치를 사용할까요?', 'why1': '고지대로 가는 가장 안전한 경로를 찾습니다', 'why2': '구조대에 내 주소를 보여줍니다', 'stay': '위치 정보는 이 기기에만 저장됩니다.', 'allow': '위치 허용', 'map': '지도에서 선택', 'foot': '나중에 변경할 수 있습니다'},
  Lang.ar: {'title': 'استخدام موقعك؟', 'why1': 'العثور على أأمن مسار إلى مكان مرتفع', 'why2': 'إظهار عنوانك لفرق الإنقاذ', 'stay': 'يبقى موقعك على هذا الجهاز.', 'allow': 'السماح بالموقع', 'map': 'اختر على الخريطة', 'foot': 'يمكنك تغيير ذلك لاحقًا'},
};

class A01Screen extends StatelessWidget {
  const A01Screen({super.key});

  void _choose(BuildContext context, GpsPermission permission) {
    final store = context.store;
    final overlay = store.state.overlay;
    final fromOverlay = overlay.isNotEmpty && overlay.last == ScreenId.a01;
    store.patch(StatePatch(gps: GpsPatch(permission: permission)));
    // Resolved automatically (not on the overlay): the permission change alone moves on to S04.
    if (fromOverlay) store.back();
    if (permission == GpsPermission.denied) store.navigate(ScreenId.s07);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final t = context.t(_dict);
    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titlePermission,
      title: t['title'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          LightCard(plain: true, children: [CardHead(icon: Icons.flag_outlined, text: t['why1'])]),
          LightCard(plain: true, children: [CardHead(icon: Icons.place, text: t['why2'])]),
          LightCard(children: [CardHead(icon: Icons.shield_outlined, text: t['stay'])]),
        ],
      ),
      actions: ButtonStack(
        children: [
          BigButton(
            label: t['allow'],
            variant: BigButtonVariant.black,
            icon: Icons.place,
            onTap: () => _choose(context, GpsPermission.granted),
          ),
          BigButton(
            label: t['map'],
            variant: BigButtonVariant.white,
            icon: Icons.map_outlined,
            onTap: () => _choose(context, GpsPermission.denied),
          ),
        ],
      ),
      footer: FooterMeta(theme: TkTheme.light, items: [t['foot']]),
    );
  }
}
