// S10 emergency "Call for help" (light). The demo never dials: the app has no dialer connection.
import 'package:flutter/material.dart';

import '../data/town.dart';
import '../help/help_card.dart';
import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'title': 'Call for help', 'ambulance': 'Ambulance', 'fire': 'Fire', 'police': 'Police', 'show': 'Show this location', 'footer': 'Opens the system dialer', 'demoCall': 'Demo: would call {n}', 'confirm': 'Call {n}?'},
  Lang.ja: {'title': '助けを呼ぶ', 'ambulance': '救急', 'fire': '消防', 'police': '警察', 'show': 'この場所を伝える', 'footer': '電話アプリが開きます', 'demoCall': 'デモ：{n} に発信します', 'confirm': '{n} に発信しますか？'},
  Lang.zhHans: {'title': '呼叫救援', 'ambulance': '急救', 'fire': '消防', 'police': '警察', 'show': '出示此位置', 'footer': '将打开系统拨号器', 'demoCall': '演示：将拨打 {n}', 'confirm': '拨打 {n}？'},
  Lang.ko: {'title': '도움 요청', 'ambulance': '구급', 'fire': '소방', 'police': '경찰', 'show': '이 위치 보여주기', 'footer': '시스템 전화 앱이 열립니다', 'demoCall': '데모: {n}에 전화합니다', 'confirm': '{n}에 전화할까요?'},
  Lang.ar: {'title': 'اطلب المساعدة', 'ambulance': 'إسعاف', 'fire': 'إطفاء', 'police': 'شرطة', 'show': 'أظهر هذا الموقع', 'footer': 'يفتح تطبيق الاتصال بالنظام', 'demoCall': 'تجريبي: سيتم الاتصال بـ {n}', 'confirm': 'الاتصال بـ {n}؟'},
};

class S10Screen extends StatelessWidget {
  const S10Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final t = context.t(_dict);
    final place = bilingual(addressAt(context.nav.position), context.lang);
    final placeJa = place.ja;
    final rows = [
      (icon: Icons.monitor_heart_outlined, label: t['ambulance'], n: '119'),
      (icon: Icons.local_fire_department_outlined, label: t['fire'], n: '119'),
      (icon: Icons.shield_outlined, label: t['police'], n: '110'),
    ];
    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titleEmergency,
      title: t['title'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          for (final r in rows)
            LightRow(
              onTap: () => context.store.showToast(fmt(t['demoCall'], {'n': r.n})),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 20, 14),
              child: Row(
                spacing: 14,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: TkColors.white, shape: BoxShape.circle),
                    child: Icon(r.icon, size: 26, color: TkColors.textOnLight),
                  ),
                  Expanded(
                    child: Text(
                      r.label,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: TkColors.textOnLight),
                    ),
                  ),
                  Text(
                    r.n,
                    textDirection: TextDirection.ltr,
                    style: TkText.heading.copyWith(fontSize: 32, color: TkColors.textOnLight),
                  ),
                ],
              ),
            ),
          const HelpJaButton(theme: TkTheme.light),
        ],
      ),
      actions: LightCard(
        children: [
          CardHead(icon: Icons.place, text: t['show']),
          Text(place.primary, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (placeJa != null)
            Text(
              placeJa,
              textDirection: TextDirection.ltr,
              style: TkFonts.japaneseName.copyWith(fontSize: 20, color: TkColors.textMutedOnLight),
            ),
        ],
      ),
      footer: FooterMeta(theme: TkTheme.light, items: [t['footer']]),
    );
  }
}
