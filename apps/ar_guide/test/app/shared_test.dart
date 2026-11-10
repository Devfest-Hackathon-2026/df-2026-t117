// Shared parts: band, margin card, footer, announcements, pictograms, map, S11 back.
import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/data/alerts.dart';
import 'package:ar_guide/app/logic/margin.dart';
import 'package:ar_guide/app/logic/nav.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/screens/_shared.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/svg_path.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:ar_guide/src/guide_params.dart' show GuideParams;
import 'package:ar_guide/src/guide_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

AppStore makeStore(String scenario, [Lang lang = Lang.en]) =>
    AppStore(scenarioId: scenario, lang: lang, platform: RecordingPlatform());

Future<void> show(WidgetTester tester, AppStore store, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: AppScope(store: store, child: PhoneFrame(child: child))),
  );
}

List<Alert> tsunami(AlertLevel level, ExpectedHeight h) => [
      Alert(id: 't', type: HazardType.tsunami, level: level, area: alertTsunami.area, issuedAt: alertIssuedAt, expectedHeight: h),
    ];

MarginInfo info({
  double? lo = 16.4,
  double? hi = 16.4,
  double? diff = 13.4,
  bool approximate = false,
  MarginLevel? level = MarginLevel.ample,
  ExpectedHeight? inUse = ExpectedHeight.m3,
  ExpectedHeight? now = ExpectedHeight.m3,
}) =>
    MarginInfo(
      heightInUse: inUse,
      heightNow: now,
      elevMinM: lo,
      elevMaxM: hi,
      approximate: approximate,
      level: level,
      marginM: diff,
      mustMove: false,
      designated: null,
    );

void main() {
  group('svgPath', () {
    test('reads the commands used by the artwork', () {
      final b = svgPath('M0 0 L10 0 V10 H0 Z').getBounds();
      expect(b, const Rect.fromLTRB(0, 0, 10, 10));
      expect(svgPath('M0 0 Q5 10 10 0 C10 5 5 5 0 0 A11 11 0 1 1 11 -20.5').getBounds().isEmpty, isFalse);
      expect(svgPolygon('0,0 10,0 10,10').getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('rejects what it cannot read', () {
      expect(() => svgPath('M0 0 Z T1 1'), throwsA(isFormatException));
    });
  });

  group('labels', () {
    test('heightLabel', () {
      expect(heightLabel(ExpectedHeight.m3, Lang.en), '3 m');
      expect(heightLabel(ExpectedHeight.over10, Lang.ja), '10 m 超');
      expect(heightLabel(ExpectedHeight.huge, Lang.ja), '巨大');
      expect(heightLabel(ExpectedHeight.high, Lang.en), 'high');
    });

    test('marginText', () {
      final t = marginText(info(), Lang.en);
      expect(t.margin, '13 m above forecast');
      expect(t.elevation, 'Elevation 16 m');
      expect(t.expected, 'Expected tsunami 3 m');
    });

    test('marginText: below, range, unknown, and JS rounding of negatives', () {
      expect(marginText(info(diff: -2.5), Lang.en).margin, '2 m below forecast');
      expect(marginText(info(lo: 18, hi: 30, approximate: true), Lang.en).elevation, 'Elevation 18–30 m');
      final none = marginText(info(lo: null, hi: null, diff: null, inUse: null), Lang.en);
      expect(none.elevation, 'Elevation unknown');
      expect(none.margin, isNull);
      expect(none.expected, isNull);
    });

    test('directions, meters and badge', () {
      expect(directionLabel(TurnDirection.left, Lang.ja), '左');
      expect(metersLabel(39.6, Lang.en), '40 m');
      expect(metersLabel(-3, Lang.en), '0 m');
      final s = makeStore('2').state;
      expect(tsunamiBadge(s), 'TSUNAMI WARNING');
      expect(tsunamiBadge(makeStore('4').state), 'TSUNAMI');
    });

    test('fitBox keeps the aspect and visibleRect covers the box', () {
      final b = fitBox(const [Point(0, 0), Point(100, 100)], 2, 0, 0);
      expect(b.width / b.height, 2);
      final v = visibleRect(const Rect.fromLTWH(0, 0, 200, 100), const Size(100, 100));
      expect(v.rect, const Rect.fromLTWH(50, 0, 100, 100));
      expect(v.mPerPx, 1);
    });
  });

  group('AlertBand', () {
    testWidgets('nothing without a change; upgrade; closing it', (tester) async {
      final store = makeStore('5');
      await show(tester, store, const AlertBand());
      expect(find.textContaining('UPGRADED'), findsNothing);
      store.patch(StatePatch(alerts: tsunami(AlertLevel.emergency, ExpectedHeight.huge)));
      await tester.pump();
      expect(find.text('UPGRADED: ${tsunamiLevelLabel(AlertLevel.emergency, Lang.en)}'), findsOneWidget);
      expect(find.textContaining('Expected huge'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(store.state.alertChange, isNull);
    });

    testWidgets('raise shows the height; downgrade says to stay', (tester) async {
      final store = makeStore('5');
      await show(tester, store, const AlertBand());
      store.patch(StatePatch(alerts: tsunami(AlertLevel.warning, ExpectedHeight.m5)));
      await tester.pump();
      expect(find.text('HEIGHT RAISED: Expected 5 m'), findsOneWidget);
      store.patch(StatePatch(alerts: tsunami(AlertLevel.advisory, ExpectedHeight.m1)));
      await tester.pump();
      expect(find.textContaining('Stay until all alerts are lifted'), findsOneWidget);
    });
  });

  testWidgets('MarginCard lines', (tester) async {
    final store = makeStore('5');
    await show(tester, store, MarginCard(margin: info(approximate: true, inUse: ExpectedHeight.huge), staying: true));
    expect(find.text('13 m above forecast'), findsOneWidget);
    expect(find.text('Location approximate'), findsOneWidget);
    expect(find.text('Stay until the warning is lifted'), findsOneWidget);
    expect(find.textContaining('(highest announced)', findRichText: true), findsOneWidget);
    expect(find.text('Follow staff instructions'), findsNothing);
  });

  group('GuideFooter', () {
    testWidgets('fresh, link, tail, stale', (tester) async {
      final store = makeStore('2');
      await show(tester, store, const GuideFooter());
      expect(find.text('09:40 JST'), findsOneWidget);
      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(store.state.overlay, [ScreenId.a02]);
      await show(tester, store, const GuideFooter(freshTail: 'Warning active'));
      expect(find.text('Warning active'), findsOneWidget);
      store.patch(const StatePatch(online: false));
      await tester.pump();
      expect(find.text('Last alert 09:40 JST'), findsOneWidget);
      expect(find.text('Stale'), findsOneWidget);
    });
  });

  group('AnnounceOnEnter', () {
    testWidgets('speaks after the delay, again on a new text, not when off', (tester) async {
      final store = makeStore('2');
      final spoken = (store.platform as RecordingPlatform).spoken;
      await show(tester, store, const AnnounceOnEnter(text: 'one'));
      expect(spoken, isEmpty);
      await tester.pump(announceDelay);
      expect(spoken, ['one']);
      store.tick(1000);
      await tester.pump(announceDelay);
      expect(spoken, ['one'], reason: 'a clock tick is not a new instruction');
      await show(tester, store, const AnnounceOnEnter(text: 'two'));
      await tester.pump(announceDelay);
      expect(spoken, ['one', 'two']);
      store.patch(const StatePatch(autoSpeak: false));
      await show(tester, store, const AnnounceOnEnter(text: 'three'));
      await tester.pump(announceDelay);
      expect(spoken, ['one', 'two']);
    });
  });

  testWidgets('AnnounceFlash follows the turn announcement', (tester) async {
    final store = makeStore('3');
    await show(tester, store, AnnounceFlash(builder: (_, flash) => Text(flash ? 'on' : 'off')));
    expect(find.text('off'), findsOneWidget);
    store.announceTurn();
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('off'), findsOneWidget);
  });

  for (final lang in [Lang.en, Lang.ar]) {
    testWidgets('pictograms and arrows draw in ${lang.code}', (tester) async {
      final store = makeStore('4', lang);
      await show(
        tester,
        store,
        Column(
          children: [
            for (final k in PictogramKind.values) Pictogram(k, size: 90),
            Row(children: [for (final d in TurnDirection.values) TurnArrow(direction: d, size: 40)]),
            const SizedBox(width: 100, height: 40, child: Pictogram(PictogramKind.stayHere)),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('TownMap', () {
    testWidgets('every option draws, also inside a scrolling layout', (tester) async {
      final store = makeStore('3');
      store.patch(const StatePatch(gps: GpsPatch(accuracyM: 180), walk: WalkPatch(progressM: 30)));
      await show(
        tester,
        store,
        const SingleChildScrollView(
          child: Column(
            children: [
              TownMap(),
              TownMap(variant: TownMapVariant.full, routeColor: RouteColor.none, showAccuracy: true),
              TownMap(routeColor: RouteColor.yellow, showHeading: true, headingDeg: 80),
              TownMap(showAllRefuges: true, showClosures: true, focus: Point(300, 300)),
              TownMap(showPosition: false, viewBox: Rect.fromLTWH(0, 0, 300, 200)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await show(tester, store, const GuidanceLayout(headline: 'x', topExtra: TownMap()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap sets the pin, inside the visible map', (tester) async {
      final store = makeStore('3');
      Point? got;
      await show(
        tester,
        store,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: TownMap(variant: TownMapVariant.full, pinEditable: true, onPinChange: (p) => got = p),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TownMap));
      await tester.tapAt(box.center);
      expect(got, isNotNull);
      expect(got!.x, inInclusiveRange(200, 400));
      await tester.tapAt(box.topLeft + const Offset(1, 1));
      await tester.pump();
      expect(got!.y, greaterThan(-20), reason: 'kept away from the top edge (about -82 without the clamp)');
    });
  });

  group('S11 back', () {
    void mockAr(WidgetTester tester) {
      final m = tester.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(const MethodChannel('tasuku_ar/ar'), (call) async => {'camera': 'denied', 'arcore': false});
      addTearDown(() => m.setMockMethodCallHandler(const MethodChannel('tasuku_ar/ar'), null));
    }

    testWidgets('GuideScreen calls onBack instead of leaving the app', (tester) async {
      mockAr(tester);
      var backs = 0;
      var popped = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') popped = true;
        return null;
      });
      await tester.pumpWidget(MaterialApp(home: GuideScreen(params: GuideParams.demo, onBack: () => backs++)));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      expect(backs, 1);
      expect(popped, isFalse);
    });

    testWidgets('in the app the back button returns to S04', (tester) async {
      mockAr(tester);
      final store = makeStore('3b');
      store.patch(const StatePatch(deviceRaised: true));
      expect(store.screen, ScreenId.s11);
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store, runClock: false)));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pump();
      expect(store.state.deviceRaised, isFalse);
      expect(store.screen, ScreenId.s04);
    });
  });
}
