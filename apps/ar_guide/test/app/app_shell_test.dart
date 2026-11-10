// The shell shows every screen without layout errors, on a small phone and in Arabic.
import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/screens/registry.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:ar_guide/app/town_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SilentPlatform implements AppPlatform {
  @override
  final ValueListenable<bool> speaking = ValueNotifier(false);
  @override
  bool speak(String text, Lang lang) => false;
  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

Future<AppStore> pump(WidgetTester tester, Lang lang, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = AppStore(scenarioId: '4', lang: lang, platform: SilentPlatform());
  await tester.pumpWidget(MaterialApp(theme: tkMaterialTheme(), home: AppShell(store: store, runClock: false)));
  return store;
}

void main() {
  test('every screen id is registered', () {
    expect(screenBuilders.keys.toSet(), ScreenId.values.toSet());
  });

  for (final lang in [Lang.en, Lang.ar, Lang.ja]) {
    testWidgets('all screens render in ${lang.code}', (tester) async {
      final store = await pump(tester, lang, const Size(360, 640));
      for (final id in ScreenId.values) {
        if (id == ScreenId.s11) continue; // the camera screen needs the device
        store.patch(StatePatch(overlay: [id]));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: id.label);
        expect(find.text('DEMO'), findsOneWidget);
      }
    });
  }

  testWidgets('the screen follows the state, with direction by language', (tester) async {
    final store = await pump(tester, Lang.ar, const Size(390, 844));
    expect(store.screen, ScreenId.h00);
    expect(Directionality.of(tester.element(find.byType(TkHeader))), TextDirection.rtl);
    store.loadScenario('2');
    await tester.pump();
    expect(store.screen, ScreenId.s03);
    store.patch(const StatePatch(lang: Lang.en));
    await tester.pump();
    expect(Directionality.of(tester.element(find.byType(TkHeader))), TextDirection.ltr);
  });

  testWidgets('a vertical drag on the S07 map moves the pin, not the screen', (tester) async {
    final store = await pump(tester, Lang.en, const Size(360, 640));
    store.patch(const StatePatch(overlay: [ScreenId.s07]));
    await tester.pump();
    final before = tester.widget<TownMap>(find.byType(TownMap)).pin;
    final gesture = await tester.startGesture(tester.getCenter(find.byType(TownMap)));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    expect(tester.widget<TownMap>(find.byType(TownMap)).pin, isNot(before));
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, 0);
  });

  testWidgets('the header buttons open sub screens and back returns', (tester) async {
    final store = await pump(tester, Lang.en, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.language));
    await tester.pump();
    expect(store.screen, ScreenId.s09);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(store.screen, ScreenId.h00);
  });

  testWidgets('the demo panel opens from the right edge and loads a scenario', (tester) async {
    final store = await pump(tester, Lang.en, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.tap(find.text('5. Upgrade'));
    await tester.pump();
    expect(store.screen, ScreenId.s06);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('5. Upgrade'), findsNothing);
  });

  testWidgets('the listen button shows a toast when speech is unavailable', (tester) async {
    final store = await pump(tester, Lang.en, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          store: store,
          child: const PhoneFrame(child: Center(child: ListenButton(text: 'x', inSheet: true))),
        ),
      ),
    );
    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(store.state.toast, isNotNull);
    expect(find.text(store.state.toast!), findsOneWidget);
  });

  testWidgets('components: text, list labels and widgets', (tester) async {
    final store = await pump(tester, Lang.en, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          store: store,
          child: PhoneFrame(
            child: GuidanceLayout(
              headline: 'Go uphill',
              subline: 'now',
              sublineLarge: true,
              note: 'Route unverified',
              badge: const TkBadge(label: ['a', 'b']),
              pictogram: const SizedBox.expand(),
              actions: const ButtonRow(
                children: [BigButton(label: 'One', compact: true), BigButton(label: 'Two', icon: Icons.flag)],
              ),
              footer: FooterMeta(items: ['JMA', null, '', MetaLink(label: 'Details', onTap: () {})]),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('A  /  B'), findsOneWidget);
    expect(find.text('•'), findsOneWidget);
  });
}
