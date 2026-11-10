// The demo scenarios, driven from the demo panel in the real app shell. Steps that belong to a screen's own
// button are done with the same patch that button sends.
import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Silent implements AppPlatform {
  final _speaking = ValueNotifier<bool>(false);
  @override
  ValueListenable<bool> get speaking => _speaking;
  @override
  bool speak(String text, Lang lang) => true;
  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

class _Panel {
  _Panel(this.tester, this.store);

  final WidgetTester tester;
  final AppStore store;

  Future<void> section(String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> tap(String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Finder _row(String label) => find.ancestor(of: find.text(label), matching: find.byType(Row)).first;

  Future<void> toggle(String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: _row(label), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
  }

  Future<void> slide(String labelStart, double value) async {
    final slider = find.descendant(
      of: find.ancestor(of: find.textContaining(labelStart), matching: find.byType(Column)).first,
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(slider).onChanged!(value);
    await tester.pumpAndSettle();
  }

  /// Runs the virtual clock until [until] holds (at most 15 virtual minutes).
  Future<void> walk(bool Function() until) async {
    for (var i = 0; i < 900 && !until(); i++) {
      store.tick(1000);
    }
    await tester.pumpAndSettle();
  }
}

Future<_Panel> _open(WidgetTester tester, String scenario) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = AppStore(scenarioId: scenario, lang: Lang.en, platform: _Silent());
  addTearDown(store.dispose);
  await tester.pumpWidget(MaterialApp(theme: tkMaterialTheme(), home: AppShell(store: store, runClock: false)));
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
  return _Panel(tester, store);
}

Alert _tsunami(AppStore s) => s.state.alerts.firstWhere((a) => a.type == HazardType.tsunami);

void main() {
  testWidgets('scenario 1: shaking stops, then the walk reaches S06', (tester) async {
    final p = await _open(tester, '1');
    final store = p.store;
    expect(store.screen, ScreenId.s01);
    store.patch(const StatePatch(lockScreen: false));
    await tester.pumpAndSettle();
    expect(store.screen, ScreenId.s02);
    await p.section('災害');
    await p.toggle('揺れ');
    expect(store.state.shaking, isFalse);
    expect(store.screen, ScreenId.s03);
    store.patch(const StatePatch(guideStep: GuideStep.nav));
    await tester.pumpAndSettle();
    expect(store.screen, ScreenId.s04);
    await p.section('歩行');
    await p.tap('再生');
    expect(store.state.walk.playing, isTrue);
    await p.tap('×4');
    expect(store.state.walk.speed, 4);
    await p.walk(() => store.screen == ScreenId.s06);
    expect(store.screen, ScreenId.s06);
    expect(store.state.onHighGround, isTrue);
    expect(store.state.walk.playing, isFalse);
  });

  testWidgets('scenario 2: offline, the evacuation map, then the walk reaches S06', (tester) async {
    final p = await _open(tester, '2');
    final store = p.store;
    expect(store.screen, ScreenId.s03);
    await p.section('通信');
    await p.toggle('オンライン');
    expect(store.state.online, isFalse);
    expect(store.screen, ScreenId.s05);
    store.patch(const StatePatch(guideStep: GuideStep.nav)); // S05's Evacuation map button
    await tester.pumpAndSettle();
    expect(store.screen, ScreenId.s08);
    await p.section('歩行');
    await p.tap('再生');
    await p.tap('×4');
    await p.walk(() => store.state.onHighGround);
    expect(store.state.onHighGround, isTrue);
    await p.toggle('オンライン');
    expect(store.state.online, isTrue);
  });

  testWidgets('scenario 3: the accuracy slider drops S04 to S03, the walk continues', (tester) async {
    final p = await _open(tester, '3');
    final store = p.store;
    expect(store.screen, ScreenId.s04);
    await p.section('歩行');
    await p.tap('再生');
    await p.section('位置');
    await p.slide('GPS 精度', 180);
    expect(store.state.gps.accuracyM, 180);
    expect(store.screen, ScreenId.s03);
    expect(store.state.walk.playing, isTrue);
    await p.slide('GPS 精度', 10);
    expect(store.screen, ScreenId.s04);
    await p.tap('×4');
    await p.walk(() => store.screen == ScreenId.s06);
    expect(store.screen, ScreenId.s06);
  });

  testWidgets('scenario 5: upgrade sends S06 back to S03, then the alert controls', (tester) async {
    final p = await _open(tester, '5');
    final store = p.store;
    expect(store.screen, ScreenId.s06);
    await p.section('災害');
    await p.tap('格上げする');
    expect(_tsunami(store).level, AlertLevel.emergency);
    expect(store.state.goHigher, GoHigher.now);
    expect(store.screen, ScreenId.s03);
    await p.tap('格下げする');
    expect(_tsunami(store).level, AlertLevel.warning);
    expect(store.state.peakTsunamiLevel, AlertLevel.emergency);
    await p.tap('高さを引き上げる');
    expect(_tsunami(store).expectedHeight, isNot(ExpectedHeight.m3));
    await p.tap('解除する');
    expect(store.state.alerts, isEmpty);
    expect(store.state.onHighGround, isFalse);
  });
}
