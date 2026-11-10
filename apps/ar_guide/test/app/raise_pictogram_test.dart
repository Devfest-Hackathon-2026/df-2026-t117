// S04 "View in AR" button: the raise-the-phone pictogram, its motion and reduced motion.
import 'dart:io';

import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/raise_pictogram.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Silent implements AppPlatform {
  @override
  final ValueListenable<bool> speaking = ValueNotifier(false);
  @override
  bool speak(String text, Lang lang) => true;
  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

Future<AppStore> _openS04(WidgetTester tester, {Lang lang = Lang.en, Size size = const Size(360, 734)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final m = tester.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(const MethodChannel('tasuku_ar/ar'), (call) async => {'camera': 'denied', 'arcore': false});
  addTearDown(() => m.setMockMethodCallHandler(const MethodChannel('tasuku_ar/ar'), null));
  final store = AppStore(scenarioId: '3b', lang: lang, platform: _Silent());
  addTearDown(store.dispose);
  expect(store.screen, ScreenId.s04);
  await tester.pumpWidget(MaterialApp(home: AppShell(store: store, runClock: false)));
  await tester.pump();
  return store;
}

Finder _arButton(String label) => find.ancestor(of: find.text(label), matching: find.byType(InkWell));

void main() {
  // The bundled Noto fonts, so widths match the device (the default test font draws every glyph 1 em wide).
  setUpAll(() async {
    final families = <String, String>{};
    String? family;
    for (final line in File('pubspec.yaml').readAsLinesSync()) {
      final f = RegExp(r'^\s+- family:\s*(\S+)').firstMatch(line);
      if (f != null) family = f.group(1);
      final a = RegExp(r'^\s+- asset:\s*(\S+)').firstMatch(line);
      if (a != null && family != null) families[family] = a.group(1)!;
    }
    for (final MapEntry(key: name, value: asset) in families.entries) {
      final bytes = File(asset).readAsBytesSync();
      await (FontLoader(name)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  tearDown(() => RaisePhonePictogram.debugDisableMotion = true);

  testWidgets('the AR button shows the pictogram next to its label', (tester) async {
    await _openS04(tester);
    final button = _arButton('View in AR');
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.byType(RaisePhonePictogram)), findsOneWidget);
    final buttonBox = tester.getRect(button);
    expect(buttonBox.width, lessThanOrEqualTo(104));
    expect(buttonBox.height, greaterThanOrEqualTo(44));
    expect(tester.getRect(find.byType(RaisePhonePictogram)).left, lessThan(tester.getRect(find.text('View in AR')).left));
    expect(find.bySemanticsLabel('View in AR (demo: simulates raising the phone)'), findsOneWidget);
  });

  testWidgets('in Arabic the pictogram sits on the right of the label', (tester) async {
    await _openS04(tester, lang: Lang.ar);
    const label = 'عرض بالواقع المعزز';
    expect(find.descendant(of: _arButton(label), matching: find.byType(RaisePhonePictogram)), findsOneWidget);
    expect(tester.getRect(find.byType(RaisePhonePictogram)).left, greaterThan(tester.getRect(find.text(label)).left));
    expect(tester.getRect(_arButton(label)).width, lessThanOrEqualTo(104));
  });

  testWidgets('the pictogram bobs a few times, rests, then bobs once every 10 s', (tester) async {
    RaisePhonePictogram.debugDisableMotion = false;
    await _openS04(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // 3 bobs x 1.4 s, then nothing until the timer.
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 5800)); // 10.2 s after S04 appeared
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    // Leaving S04 cancels the timer (a pending timer would fail the test).
    await tester.pumpWidget(const SizedBox());
  });

  for (final (lang, label) in const [(Lang.en, 'View in AR'), (Lang.ar, 'عرض بالواقع المعزز')]) {
    testWidgets('320x640 with 200 % text in $lang: no pictogram, no overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _openS04(tester, lang: lang, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(_arButton(label), findsOneWidget);
      expect(find.byType(RaisePhonePictogram), findsNothing);
      await tester.ensureVisible(_arButton(label));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Not pumped further: S11 at 200 % text is outside this change.
      await tester.tap(_arButton(label));
      expect(store.state.deviceRaised, isTrue);
    });
  }

  testWidgets('320x640 at normal text size keeps the pictogram without overflow', (tester) async {
    await _openS04(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.byType(RaisePhonePictogram), findsOneWidget);
  });

  testWidgets('the pictogram is still when the system disables animations', (tester) async {
    RaisePhonePictogram.debugDisableMotion = false;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _openS04(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpAndSettle(); // returns: nothing loops
    expect(find.byType(RaisePhonePictogram), findsOneWidget);
  });

  testWidgets('the pictogram is still with accessible navigation (screen reader)', (tester) async {
    RaisePhonePictogram.debugDisableMotion = false;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _openS04(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('tapping the button (on the pictogram) still sets deviceRaised', (tester) async {
    final store = await _openS04(tester);
    await tester.tap(find.byType(RaisePhonePictogram));
    await tester.pump();
    expect(store.state.deviceRaised, isTrue);
    expect(store.screen, ScreenId.s11);
  });
}
