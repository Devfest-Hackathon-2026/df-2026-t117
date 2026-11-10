// H00 home (normal mode): calm status card, disaster-guide buttons, preparedness column, translation note.
// The web's push-notification row is left out: push is not ported to the app yet.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';
import 'a03.dart';

const Dict _dict = {
  Lang.en: {'none': 'No active alerts', 'advisory': 'Advisory in effect', 'warning': 'Warning in effect', 'emergency': 'Emergency warning in effect', 'updated': 'Last updated', 'guides': 'Disaster guides', 'prep': 'Disaster preparedness in Japan'},
  Lang.ja: {'none': '警報はありません', 'advisory': '注意報が出ています', 'warning': '警報が出ています', 'emergency': '特別警報が出ています', 'updated': '最終更新', 'guides': '災害別ガイド', 'prep': '日本の防災について'},
  Lang.zhHans: {'none': '当前无警报', 'advisory': '注意报生效中', 'warning': '警报生效中', 'emergency': '特别警报生效中', 'updated': '最近更新', 'guides': '灾害指南', 'prep': '日本防灾知识'},
  Lang.ko: {'none': '발령 중인 경보 없음', 'advisory': '주의보 발령 중', 'warning': '경보 발령 중', 'emergency': '특별 경보 발령 중', 'updated': '마지막 업데이트', 'guides': '재난별 안내', 'prep': '일본의 방재 안내'},
  Lang.ar: {'none': 'لا توجد تنبيهات حالية', 'advisory': 'إشعار ساري', 'warning': 'تحذير ساري', 'emergency': 'تحذير طارئ ساري', 'updated': 'آخر تحديث', 'guides': 'أدلة الكوارث', 'prep': 'الاستعداد للكوارث في اليابان'},
};

class H00Screen extends StatelessWidget {
  const H00Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final lang = state.lang;
    final c = context.common;
    final t = context.t(_dict);
    final hasAlert = state.alerts.isNotEmpty;
    final statusText = switch (mostSevere(state.alerts)?.level) {
      null => t['none'],
      AlertLevel.advisory => t['advisory'],
      AlertLevel.emergency => t['emergency'],
      AlertLevel.warning => t['warning'],
    };
    const note = TextStyle(color: TkColors.textMutedOnDark, fontSize: TkSizes.fsMeta, fontWeight: FontWeight.w700);
    return ScrollFill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TkHeader(accent: HeaderAccent.yellow),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 20, TkSizes.gutter, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: TkColors.btnDark,
                        borderRadius: BorderRadius.circular(TkSizes.radiusCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Row(
                            spacing: 12,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasAlert ? TkColors.red : TkColors.yellow,
                                ),
                                child: Icon(
                                  hasAlert ? Icons.warning_rounded : Icons.check,
                                  size: 24,
                                  color: hasAlert ? TkColors.white : TkColors.textOnLight,
                                ),
                              ),
                              Expanded(
                                child: Text(statusText, style: TkText.heading.copyWith(fontSize: 30, height: 1.1)),
                              ),
                            ],
                          ),
                          if (hasAlert)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 52),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final a in state.alerts) TkBadge(label: alertBadgeLabel(a, lang), small: true),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 52),
                            child: Text('${t['updated']} ${formatJstLabel(state.lastFetchAt)}', style: note),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    t['guides'].toUpperCase(),
                    style: const TextStyle(
                      color: TkColors.textMutedOnDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        Expanded(
                          child: _Tile(
                            picto: PictogramKind.protectHead,
                            label: c.badgeEarthquake,
                            onTap: () => context.store.navigate(ScreenId.a03),
                          ),
                        ),
                        Expanded(
                          child: _Tile(
                            picto: PictogramKind.goUphill,
                            label: c.badgeTsunami,
                            onTap: () {
                              setA03InitialTab(A03Tab.tsunami);
                              context.store.navigate(ScreenId.a03);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (hasAlert)
                    BigButton(
                      label: c.officialUpdates,
                      variant: BigButtonVariant.outline,
                      icon: Icons.schedule,
                      onTap: () => context.store.navigate(ScreenId.a02),
                    ),
                  BigButton(
                    label: c.savedMap,
                    variant: BigButtonVariant.outline,
                    icon: Icons.map_outlined,
                    onTap: () => context.store.navigate(ScreenId.s08),
                  ),
                  BigButton(
                    label: t['prep'],
                    icon: Icons.shield_outlined,
                    onTap: () => context.store.navigate(ScreenId.a04),
                  ),
                  Text(c.translationNote, textAlign: TextAlign.center, style: note),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.picto, required this.label, required this.onTap});

  final PictogramKind picto;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TkSizes.radiusCard);
    return Material(
      color: TkColors.pictoBg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              SizedBox(height: 80, width: double.infinity, child: Pictogram(picto)),
              Text(label, style: TkText.heading.copyWith(fontSize: 22, color: TkColors.textOnLight)),
            ],
          ),
        ),
      ),
    );
  }
}
