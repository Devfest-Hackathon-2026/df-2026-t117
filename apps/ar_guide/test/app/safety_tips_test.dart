// Safety tips: the two new column articles (5 languages, RTL) and their entry on H00.
// The "stay inside" card was removed (staying inside is advised only while shaking): H00 never shows it.
import 'package:ar_guide/app/data/alerts.dart';
import 'package:ar_guide/app/data/articles.dart';
import 'package:ar_guide/app/logic/nav.dart';
import 'package:ar_guide/app/screens/a04.dart';
import 'package:ar_guide/app/screens/h00.dart';
import 'package:ar_guide/app/state/scenarios.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test.dart' show pump;

Alert tsunamiAlert(AlertLevel level) =>
    Alert(id: alertTsunami.id, type: HazardType.tsunami, level: level, area: alertTsunami.area, issuedAt: alertIssuedAt);

const _stay = ValueKey('h00-stay-inside');

void main() {
  final tips = articles.where((a) => a.isNew).toList();

  test('two new tips, first in the column, with a pictogram', () {
    expect(tips.map((a) => a.id), ['advisory-30cm', 'leave-car']);
    expect(orderedArticles.take(2).map((a) => a.id), ['advisory-30cm', 'leave-car']);
    for (final a in tips) {
      expect(articlePicto[a.id], isNotNull, reason: a.id);
    }
  });

  test('every article and dict has text in all 5 languages, with the same keys', () {
    for (final a in articles) {
      for (final lang in Lang.values) {
        expect(a.title[lang], isNotEmpty);
        expect(a.summary[lang], isNotEmpty);
        for (final p in a.body) {
          expect(p[lang], isNotEmpty);
        }
      }
    }
    for (final dict in [h00Dict, a04Dict]) {
      final keys = dict[Lang.en]!.keys.toSet();
      for (final lang in Lang.values) {
        expect(dict[lang]!.keys.toSet(), keys, reason: lang.code);
      }
    }
  });

  for (final lang in Lang.values) {
    testWidgets('H00 shows the tips and opens each article in ${lang.code}', (tester) async {
      final store = await pump(tester, lang, const Size(360, 640));
      expect(store.screen, ScreenId.h00);
      expect(find.byKey(const ValueKey('h00-tips')), findsOneWidget);
      expect(find.byKey(_stay), findsNothing);
      final dir = lang == Lang.ar ? TextDirection.rtl : TextDirection.ltr;
      for (final a in tips) {
        final entry = find.text(a.title[lang]);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pump();
        expect(store.screen, ScreenId.a04);
        expect(find.text(a.body.first[lang]), findsOneWidget);
        expect(find.text(a.body.last[lang]), findsOneWidget);
        expect(Directionality.of(tester.element(find.text(a.body.first[lang]))), dir);
        expect(tester.takeException(), isNull);
        store.back();
        await tester.pump();
        expect(store.screen, ScreenId.h00);
      }
    });

    testWidgets('A04 lists the tips first with the new tag in ${lang.code}', (tester) async {
      final store = await pump(tester, lang, const Size(360, 640));
      store.navigate(ScreenId.a04);
      await tester.pump();
      expect(find.text(a04Dict[lang]!['new']!), findsNWidgets(2));
      final first = tester.getTopLeft(find.text(tips.first.title[lang])).dy;
      final old = tester.getTopLeft(find.text(articles.firstWhere((a) => !a.isNew).title[lang])).dy;
      expect(first, lessThan(old));
      expect(tester.takeException(), isNull);
    });
  }

  for (final lang in [Lang.en, Lang.ja, Lang.ar]) {
    testWidgets('H00 shows no stay inside card for an advisory outside the zone in ${lang.code}', (tester) async {
      final store = await pump(tester, lang, const Size(360, 640));
      store.patch(StatePatch(
        gps: const GpsPatch(position: scenario5Position),
        alerts: [tsunamiAlert(AlertLevel.advisory)],
      ));
      await tester.pump();
      expect(pointInHazard(scenario5Position), isFalse);
      expect(store.screen, ScreenId.h00);
      expect(find.byKey(_stay), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no stay inside card inside the zone: the advisory or warning evacuates', (tester) async {
    final store = await pump(tester, Lang.en, const Size(390, 844));
    expect(pointInHazard(startPosition), isTrue);
    for (final level in AlertLevel.values) {
      store.patch(StatePatch(alerts: [tsunamiAlert(level)]));
      await tester.pump();
      expect(store.screen, isNot(ScreenId.h00), reason: level.name);
      expect(find.byKey(_stay), findsNothing, reason: level.name);
    }
    // A warning outside the zone also evacuates.
    store.patch(StatePatch(gps: const GpsPatch(position: scenario5Position), alerts: [tsunamiAlert(AlertLevel.warning)]));
    await tester.pump();
    expect(store.screen, isNot(ScreenId.h00));
    expect(find.byKey(_stay), findsNothing);
  });
}
