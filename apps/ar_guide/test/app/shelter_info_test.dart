// Feature G: the shelter info block on S06, in every language, without moving S06's own parts.
import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/screens/_shared.dart';
import 'package:ar_guide/app/shelter/shelter_info.dart';
import 'package:ar_guide/app/shelter/shelter_strings.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingPlatform implements AppPlatform {
  final spoken = <String>[];
  @override
  final ValueListenable<bool> speaking = ValueNotifier(false);
  @override
  bool speak(String text, Lang lang) {
    spoken.add(text);
    return true;
  }

  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

/// Scenario 5 starts on S06 (on high ground, ample margin).
Future<(AppStore, RecordingPlatform)> pumpS06(WidgetTester tester, Lang lang, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final platform = RecordingPlatform();
  final store = AppStore(scenarioId: '5', lang: lang, platform: platform);
  await tester.pumpWidget(MaterialApp(theme: tkMaterialTheme(), home: AppShell(store: store, runClock: false)));
  await tester.pump(const Duration(milliseconds: 400)); // past the announcement delay
  return (store, platform);
}

void main() {
  test('every language has every string', () {
    final keys = shelterDict[Lang.en]!.keys.toSet();
    for (final lang in Lang.values) {
      expect(shelterDict[lang]?.keys.toSet(), keys, reason: lang.code);
      expect(shelterDict[lang]!.values.every((v) => v.trim().isNotEmpty), isTrue, reason: lang.code);
    }
  });

  for (final lang in Lang.values) {
    testWidgets('S06 shows the shelter info in ${lang.code}, below its own parts', (tester) async {
      final (store, platform) = await pumpS06(tester, lang, const Size(360, 734));
      expect(store.screen, ScreenId.s06);
      expect(tester.takeException(), isNull);

      final strings = shelterDict[lang]!;
      expect(find.byType(ShelterInfo), findsOneWidget);
      for (final key in ['title', 'free', 'passport', 'tellStaff']) {
        expect(find.text(strings[key]!), findsOneWidget, reason: key);
      }
      // The Japanese word is shown beside the title in the other languages.
      expect(find.text(shelterJapanese), lang == Lang.ja ? findsNothing : findsOneWidget);

      final direction = Directionality.of(tester.element(find.byType(ShelterInfo)));
      expect(direction, lang == Lang.ar ? TextDirection.rtl : TextDirection.ltr);

      // S06's own parts are still there, and the block comes after them.
      expect(find.byType(Pictogram), findsOneWidget);
      expect(find.byType(MarginCard), findsOneWidget);
      expect(find.byType(BigButton), findsWidgets);
      expect(find.byType(ListenButton), findsOneWidget);
      expect(find.byType(FooterMeta), findsOneWidget);
      final infoTop = tester.getTopLeft(find.byType(ShelterInfo)).dy;
      expect(infoTop, greaterThanOrEqualTo(tester.getBottomLeft(find.byType(ListenButton)).dy));
      expect(tester.getTopLeft(find.byType(FooterMeta)).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.byType(ShelterInfo)).dy));

      // Not part of the S06 announcement.
      expect(platform.spoken, isNotEmpty);
      for (final text in platform.spoken) {
        for (final s in strings.values) {
          expect(text.contains(s), isFalse, reason: s);
        }
      }
    });
  }
}
