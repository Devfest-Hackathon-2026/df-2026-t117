// A02 alert details / official updates (light). Fictional data, clearly marked SIMULATED.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'title': 'Official updates', 'issued': 'Issued', 'area': 'Area', 'source': 'Source', 'timeline': 'Timeline', 'none': 'No active alerts', 'sim': 'SIMULATED: fictional data, not a real JMA alert.', 't1': 'Earthquake information issued', 't2': 'Tsunami warning issued for the coast', 't3': 'Stay on high ground until the official all-clear'},
  Lang.ja: {'title': '公式の続報', 'issued': '発表', 'area': '地域', 'source': '情報源', 'timeline': '時系列', 'none': '発表中の警報はありません', 'sim': '模擬データ：架空の情報であり、実際の気象庁の警報ではありません。', 't1': '地震情報を発表', 't2': '沿岸に津波警報を発表', 't3': '解除の発表があるまで高台にとどまってください'},
  Lang.zhHans: {'title': '官方更新', 'issued': '发布', 'area': '区域', 'source': '来源', 'timeline': '时间线', 'none': '当前没有警报', 'sim': '模拟：虚构数据，并非真实的气象厅警报。', 't1': '发布地震信息', 't2': '对沿岸发布海啸警报', 't3': '在官方解除前请留在高处'},
  Lang.ko: {'title': '공식 업데이트', 'issued': '발표', 'area': '지역', 'source': '출처', 'timeline': '시간순 경과', 'none': '발령 중인 경보 없음', 'sim': '모의: 가상 데이터이며 실제 기상청 경보가 아닙니다.', 't1': '지진 정보 발표', 't2': '해안에 쓰나미 경보 발표', 't3': '공식 해제 시까지 고지대에 머무르세요'},
  Lang.ar: {'title': 'التحديثات الرسمية', 'issued': 'صدر', 'area': 'المنطقة', 'source': 'المصدر', 'timeline': 'التسلسل الزمني', 'none': 'لا توجد تنبيهات سارية', 'sim': 'تجريبي: بيانات خيالية وليست تنبيهًا حقيقيًا.', 't1': 'صدرت معلومات الزلزال', 't2': 'صدر تحذير تسونامي للساحل', 't3': 'ابقَ في مكان مرتفع حتى الإعلان الرسمي عن زوال الخطر'},
};

const int _minuteMs = 60 * 1000;

class A02Screen extends StatelessWidget {
  const A02Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final lang = state.lang;
    final c = context.common;
    final t = context.t(_dict);
    final sorted = [...state.alerts]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    String levelLabel(AlertLevel l) => switch (l) {
          AlertLevel.advisory => c.levelAdvisory,
          AlertLevel.warning => c.levelWarning,
          AlertLevel.emergency => c.levelEmergency,
        };
    final base = sorted.isEmpty ? null : sorted.first.issuedAt;
    final steps = base == null
        ? const <(int, String)>[]
        : [(base, t['t1']), (base + _minuteMs, t['t2']), (base + 2 * _minuteMs, t['t3'])];

    Widget card(Alert a) {
      final area = bilingual(a.area, lang);
      final areaJa = area.ja;
      return LightCard(
        plain: true,
        children: [
          TkBadge(label: alertBadgeLabel(a, lang), small: true),
          Text(levelLabel(a.level), style: t3Heading),
          Text('${t['area']}: ${area.primary}', style: t3Body),
          if (areaJa != null)
            Text(areaJa, style: TkFonts.japaneseName.copyWith(fontSize: 20, color: TkColors.textMutedOnLight)),
          Text('${t['issued']} ${formatJstLabel(a.issuedAt)} • ${t['source']}: ${c.jma}', style: t3Meta),
        ],
      );
    }

    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titleAlertDetails,
      title: t['title'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          if (sorted.isEmpty) Text(t['none'], style: t3Body),
          for (final a in sorted) card(a),
          if (steps.isNotEmpty) ...[
            Text(t['timeline'], style: t3Heading),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 14),
              decoration: const BoxDecoration(
                border: BorderDirectional(start: BorderSide(color: TkColors.yellow, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (final s in steps)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatJstLabel(s.$1), style: t3Meta),
                        Text(s.$2, style: t3Body),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      footer: FooterMeta(theme: TkTheme.light, items: [c.jma, t['sim']]),
    );
  }
}
