// Store transitions: upgrade / raise / downgrade / all clear (14.4), screens (7.1, 14.5), freshness (7.3).
import 'package:ar_guide/app/data/alerts.dart';
import 'package:ar_guide/app/i18n/i18n.dart';
import 'package:ar_guide/app/state/derive.dart';
import 'package:ar_guide/app/state/scenarios.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/time.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

List<Alert> tsunami(AlertLevel level, ExpectedHeight? h) => [
      alertEarthquake,
      Alert(id: alertTsunami.id, type: HazardType.tsunami, level: level, area: alertTsunami.area, issuedAt: alertIssuedAt, expectedHeight: h),
    ];

AppState withAlerts(AppState s, AlertLevel level, ExpectedHeight? h) => reducePatch(s, StatePatch(alerts: tsunami(level, h)));

void main() {
  group('alert changes (F88 / F89 / F8A)', () {
    test('a scenario starts with peaks and no band', () {
      final s = buildScenarioState('5', Lang.en);
      expect(s.peakTsunamiLevel, AlertLevel.warning);
      expect(s.peakExpectedHeight, ExpectedHeight.m3);
      expect(s.alertChange, isNull);
    });

    test('upgrade', () {
      final s = withAlerts(buildScenarioState('5', Lang.en), AlertLevel.emergency, ExpectedHeight.huge);
      expect(s.alertChange?.kind, AlertChangeKind.upgrade);
      expect(s.alertChange?.level, AlertLevel.emergency);
      expect(s.peakTsunamiLevel, AlertLevel.emergency);
      expect(s.peakExpectedHeight, ExpectedHeight.huge);
    });

    test('raise at the same level', () {
      final s = withAlerts(buildScenarioState('5', Lang.en), AlertLevel.warning, ExpectedHeight.m5);
      expect(s.alertChange?.kind, AlertChangeKind.raise);
    });

    test('a lowered height at the same level shows no band', () {
      final up = withAlerts(buildScenarioState('5', Lang.en), AlertLevel.warning, ExpectedHeight.m1);
      expect(up.alertChange, isNull);
      expect(up.peakExpectedHeight, ExpectedHeight.m3);
    });

    test('a new alert shows no band', () {
      final s = withAlerts(buildScenarioState('4', Lang.en), AlertLevel.warning, ExpectedHeight.m3);
      expect(s.alertChange, isNull);
      expect(s.peakTsunamiLevel, AlertLevel.warning);
    });

    test('downgrade keeps the peaks and the guidance', () {
      var s = withAlerts(buildScenarioState('5', Lang.en), AlertLevel.emergency, ExpectedHeight.huge);
      s = withAlerts(s, AlertLevel.advisory, ExpectedHeight.m1);
      expect(s.alertChange?.kind, AlertChangeKind.downgrade);
      expect(s.peakTsunamiLevel, AlertLevel.emergency);
      expect(s.peakExpectedHeight, ExpectedHeight.huge);
      // Outside the hazard zone an advisory alone would not evacuate; a past warning keeps it.
      expect(deriveMode(s, false), Mode.safe);
    });

    test('all clear resets everything', () {
      var s = withAlerts(buildScenarioState('5', Lang.en), AlertLevel.emergency, ExpectedHeight.huge);
      s = reducePatch(s, const StatePatch(alerts: []));
      expect(s.peakTsunamiLevel, isNull);
      expect(s.peakExpectedHeight, isNull);
      expect(s.alertChange, isNull);
      expect(s.onHighGround, isFalse);
      expect(s.guideStep, GuideStep.action);
      expect(deriveMode(s), Mode.normal);
    });

    test('while shaking the screen stays on S02 and only the band changes', () {
      var s = reducePatch(buildScenarioState('2', Lang.en), const StatePatch(shaking: true));
      s = withAlerts(s, AlertLevel.emergency, ExpectedHeight.huge);
      expect(resolveScreen(s), ScreenId.s02);
      expect(s.alertChange?.kind, AlertChangeKind.upgrade);
    });

    test('escalation closes the sub screens, a downgrade does not', () {
      final base = reduceNavigate(buildScenarioState('2', Lang.en), ScreenId.s09);
      expect(withAlerts(base, AlertLevel.emergency, ExpectedHeight.huge).overlay, isEmpty);
      expect(withAlerts(base, AlertLevel.warning, ExpectedHeight.m5).overlay, isEmpty, reason: 'raise');
      expect(withAlerts(base, AlertLevel.advisory, ExpectedHeight.m1).overlay, [ScreenId.s09]);
    });

    test('a patch that sets overlay itself keeps it', () {
      final base = reduceNavigate(buildScenarioState('2', Lang.en), ScreenId.s09);
      final s = reducePatch(base, StatePatch(alerts: tsunami(AlertLevel.emergency, ExpectedHeight.huge), overlay: const [ScreenId.a02]));
      expect(s.overlay, [ScreenId.a02]);
    });

    test('arriving on high ground clears goHigher', () {
      final s = reducePatch(
        buildScenarioState('2', Lang.en).copyWith(goHigher: GoHigher.now),
        const StatePatch(onHighGround: true),
      );
      expect(s.goHigher, isNull);
    });
  });

  group('screens (7.1, FB4)', () {
    AppState nav({double accuracy = 10, GpsPermission permission = GpsPermission.granted, bool online = true, Point? pin}) {
      final s = buildScenarioState('3', Lang.en);
      return s.copyWith(
        online: online,
        manualPin: pin,
        gps: s.gps.apply(GpsPatch(accuracyM: accuracy, permission: permission)),
      );
    }

    test('main flow', () {
      expect(resolveScreen(buildScenarioState('1', Lang.en)), ScreenId.s01);
      expect(resolveScreen(buildScenarioState('2', Lang.en)), ScreenId.s03);
      expect(resolveScreen(buildScenarioState('3', Lang.en)), ScreenId.s04);
      expect(resolveScreen(buildScenarioState('4', Lang.en)), ScreenId.h00);
      expect(resolveScreen(buildScenarioState('5', Lang.en)), ScreenId.s06);
    });

    test('approximate location stays on the action guide, without the pin screen', () {
      expect(resolveScreen(nav(accuracy: 180)), ScreenId.s03);
      expect(resolveScreen(nav(accuracy: 100)), ScreenId.s04, reason: '100 m is not over the threshold');
      expect(resolveScreen(nav(accuracy: 180, online: false)), ScreenId.s05);
      expect(resolveScreen(nav(permission: GpsPermission.denied)), ScreenId.s03);
    });

    test('a pin makes the location usable again', () {
      expect(resolveScreen(nav(accuracy: 180, pin: const Point(140, 330))), ScreenId.s04);
    });

    test('permission not asked yet -> A01', () {
      expect(resolveScreen(nav(permission: GpsPermission.prompt)), ScreenId.a01);
    });

    test('offline nav -> S08', () {
      expect(resolveScreen(nav(online: false)), ScreenId.s08);
    });

    test('AR: S11 when all conditions hold, S12 when quality is not met', () {
      final raised = buildScenarioState('3b', Lang.en).copyWith(deviceRaised: true);
      expect(resolveScreen(raised), ScreenId.s11);
      final poor = raised.copyWith(ar: raised.ar.apply(const ArPatch(headingAccuracyDeg: 30)));
      expect(resolveScreen(poor), ScreenId.s12);
      final noCamera = raised.copyWith(ar: raised.ar.apply(const ArPatch(cameraPermission: false)));
      expect(resolveScreen(noCamera), ScreenId.s04);
    });

    test('the overlay comes before the mode, the lock screen before the overlay', () {
      final s = reduceNavigate(buildScenarioState('2', Lang.en), ScreenId.s09);
      expect(resolveScreen(s), ScreenId.s09);
      expect(resolveScreen(s.copyWith(lockScreen: true)), ScreenId.s01);
    });

    test('an advisory outside the zone is normal, unless guidance already started', () {
      final s = reducePatch(
        buildScenarioState('4', Lang.en),
        StatePatch(alerts: [Alert(id: 'a', type: HazardType.tsunami, level: AlertLevel.advisory, area: alertTsunami.area, issuedAt: 0)]),
      );
      expect(deriveMode(s, false), Mode.normal);
      expect(deriveMode(s, true), Mode.evacuate);
      expect(deriveMode(s.copyWith(guideStep: GuideStep.nav), false), Mode.evacuate);
    });
  });

  group('actions', () {
    test('navigate does not duplicate the top; back pops, lowers, then leaves nav', () {
      var s = buildScenarioState('3', Lang.en).copyWith(deviceRaised: true);
      s = reduceNavigate(reduceNavigate(s, ScreenId.s09), ScreenId.s09);
      expect(s.overlay, [ScreenId.s09]);
      s = reduceBack(s);
      expect(s.overlay, isEmpty);
      expect(s.deviceRaised, isTrue);
      s = reduceBack(s);
      expect(s.deviceRaised, isFalse);
      expect(s.guideStep, GuideStep.nav);
      s = reduceBack(s);
      expect(s.guideStep, GuideStep.action);
      expect(canGoBack(s), isFalse);
      expect(identical(reduceBack(s), s), isTrue);
    });

    test('tick walks at 1.5 m/s times speed and holds on S07', () {
      var s = buildScenarioState('3', Lang.en);
      s = s.copyWith(walk: s.walk.apply(const WalkPatch(playing: true, speed: 2)));
      s = reduceTick(s, 1000);
      expect(s.walk.progressM, 3);
      s = reduceTick(reduceNavigate(s, ScreenId.s07), 1000);
      expect(s.walk.progressM, 3);
      expect(s.now, demoStartMs + 2000);
    });

    test('polling refreshes lastFetchAt once a minute unless the feed is paused', () {
      final s = buildScenarioState('4', Lang.en);
      expect(reduceTick(s, 59000).lastFetchAt, demoStartMs);
      expect(reduceTick(s, 60000).lastFetchAt, demoStartMs + 60000);
      expect(reduceTick(s.copyWith(feedPaused: true), 60000).lastFetchAt, demoStartMs);
      expect(reduceTick(s.copyWith(online: false), 60000).lastFetchAt, demoStartMs);
    });

    test('loading a scenario keeps language and settings and counts the run', () {
      final s = buildScenarioState('4', Lang.ja).copyWith(dialerEnabled: true, autoSpeak: false);
      final next = reduceLoadScenario(s, '5');
      expect(next.lang, Lang.ja);
      expect(next.dialerEnabled, isTrue);
      expect(next.autoSpeak, isFalse);
      expect(next.scenarioRun, 1);
    });

    test('gps, walk and ar patches keep the other fields', () {
      final s = reducePatch(buildScenarioState('4', Lang.en), const StatePatch(gps: GpsPatch(accuracyM: 180)));
      expect(s.gps.accuracyM, 180);
      expect(s.gps.position, startPosition);
    });

    test('unknown scenario falls back to the default', () {
      expect(buildScenarioState('nope', Lang.en).scenarioId, defaultScenarioId);
    });
  });

  group('freshness (7.3)', () {
    test('stale after the threshold or offline', () {
      final s = buildScenarioState('2', Lang.en);
      expect(freshness(s).stale, isFalse);
      expect(freshness(s.copyWith(now: s.lastFetchAt + 11 * minuteMs)).stale, isTrue);
      final off = freshness(s.copyWith(online: false));
      expect(off.stale, isTrue);
      expect(off.routeVerified, isFalse);
      expect(off.passabilityCheckedAt, isNull);
      expect(freshness(s).lastAlertAt, alertIssuedAt);
    });
  });

  group('priority (7.2)', () {
    test('order', () {
      final s = buildScenarioState('2', Lang.en);
      expect(topPriorityAction(s.copyWith(shaking: true)).kind, PriorityKind.protect);
      expect(topPriorityAction(s).kind, PriorityKind.goUphillNow);
      expect(topPriorityAction(s.copyWith(onHighGround: true)).kind, PriorityKind.stayHere);
      expect(topPriorityAction(buildScenarioState('4', Lang.en)).kind, PriorityKind.none);
    });
  });

  group('time and language', () {
    test('JST formatting', () {
      expect(formatJst(demoStartMs), '09:41');
      expect(formatJstLabel(jstOnDemoDay(9, 40)), '09:40 JST');
    });

    test('language detection', () {
      expect(matchLang('zh-Hant-TW'), isNull);
      expect(matchLang('zh-CN'), Lang.zhHans);
      expect(matchLang('ja-JP'), Lang.ja);
      expect(matchLang('fr'), isNull);
      expect(detectLang(const [Locale('fr'), Locale('ko', 'KR')]), Lang.ko);
      expect(detectLang(const [Locale('fr')]), Lang.en);
    });

    test('fmt and bilingual', () {
      expect(fmt('{n} m', {'n': 40}), '40 m');
      expect(fmt('{a}', {'n': 1}), '{a}');
      expect(bilingualText(alertTsunami.area, Lang.ja), 'みなと湾（架空）');
      expect(bilingualText(alertTsunami.area, Lang.en), 'Minato Bay (fictional) / みなと湾（架空）');
    });
  });
}
