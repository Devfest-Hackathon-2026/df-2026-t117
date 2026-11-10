// Effects: arrival, turn announcement, re-notification, forced return to evacuation (14.3, 14.4, 14.7-6).
import 'package:ar_guide/app/data/alerts.dart';
import 'package:ar_guide/app/logic/alert_effects.dart';
import 'package:ar_guide/app/logic/app_effects.dart';
import 'package:ar_guide/app/logic/heights.dart';
import 'package:ar_guide/app/logic/nav_effects.dart';
import 'package:ar_guide/app/logic/nav.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/state/derive.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

class FakePlatform implements AppPlatform {
  final spoken = <String>[];
  final vibrations = <List<int>>[];
  final notifications = <String>[];
  int cancels = 0;

  @override
  final ValueListenable<bool> speaking = ValueNotifier(false);

  @override
  bool speak(String text, Lang lang) {
    spoken.add(text);
    return true;
  }

  @override
  void cancelSpeech() => cancels++;

  @override
  void vibrate(List<int> pattern) => vibrations.add(pattern);

  @override
  void notify(String title, String body) => notifications.add(body);
}

({AppStore store, FakePlatform platform, AppEffects effects}) setup(String scenario, {bool Function()? pushCovers}) {
  final platform = FakePlatform();
  final store = AppStore(scenarioId: scenario, lang: Lang.en, platform: platform);
  final effects = AppEffects(store, pushCovers: pushCovers)..start(clock: false);
  addTearDown(effects.dispose);
  return (store: store, platform: platform, effects: effects);
}

List<Alert> major(ExpectedHeight h) => [
      alertEarthquake,
      Alert(id: alertTsunami.id, type: HazardType.tsunami, level: AlertLevel.emergency, area: alertTsunami.area, issuedAt: alertIssuedAt, expectedHeight: h),
    ];

void main() {
  test('rebaseOrigin moves the pin if there is one, else the GPS position', () {
    final s = setup('3').store.state;
    final gps = rebaseOrigin(s, const Point(10.04, 20.06));
    expect(gps.gps?.position, const Point(10, 20.1));
    expect(gps.manualPin, isNull);
    final pinned = rebaseOrigin(s.copyWith(manualPin: const Point(1, 1)), const Point(5, 6));
    expect(pinned.manualPin, const Point(5, 6));
    expect(pinned.gps, isNull);
    expect(pinned.walk?.progressM, 0);
  });

  group('arrival', () {
    test('walking to the end during guidance leads to S06 and stops the walk', () {
      final t = setup('3');
      t.store.patch(const StatePatch(walk: WalkPatch(playing: true)));
      t.store.patch(StatePatch(walk: WalkPatch(progressM: t.store.nav.route.totalM)));
      expect(t.store.state.onHighGround, isTrue);
      expect(t.store.state.walk.playing, isFalse);
      expect(t.store.screen, ScreenId.s06);
    });

    test('not while on the action step', () {
      final t = setup('2');
      t.store.patch(StatePatch(walk: WalkPatch(progressM: t.store.nav.route.totalM)));
      expect(t.store.state.onHighGround, isFalse);
    });
  });

  group('turn announcement', () {
    test('once per turn, within 30 m, with the distance', () {
      final t = setup('3');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 5)));
      expect(t.platform.spoken, isEmpty, reason: '35 m away');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 15)));
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 20)));
      expect(t.platform.spoken, ['Turn right in 25 meters.']);
      expect(t.platform.vibrations, [turnPattern]);
    });

    test('notifies screens', () async {
      final t = setup('3');
      var count = 0;
      final sub = t.store.onTurnAnnounce.listen((_) => count++);
      addTearDown(sub.cancel);
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 15)));
      expect(count, 1);
    });

    test('a rehearsal announces again', () {
      final t = setup('3');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 15)));
      t.store.loadScenario('3');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 15)));
      expect(t.platform.spoken.length, 2);
    });

    test('no announcement while not guiding', () {
      final t = setup('2');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 15)));
      expect(t.platform.spoken, isEmpty);
    });

    test('speech text per language', () {
      expect(turnSpeech(Lang.ja, TurnDirection.right, 30), '30メートル先、右です。');
      expect(turnSpeech(Lang.en, TurnDirection.straight, 12.4), 'Go straight for 12 meters.');
    });
  });

  group('route change', () {
    test('the walk continues from the current position', () {
      final t = setup('3');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 60)));
      final at = t.store.nav.position;
      t.store.patch(const StatePatch(manualPin: Point(140, 331)));
      expect(t.store.state.walk.progressM, 0);
      expect(t.store.state.manualPin!.x, closeTo(at.x, 0.05));
      expect(t.store.state.manualPin!.y, closeTo(at.y, 0.05));
    });

    test('at the start nothing is rebased', () {
      final t = setup('3');
      t.store.patch(const StatePatch(manualPin: Point(140, 331)));
      expect(t.store.state.manualPin, const Point(140, 331));
    });

    test('a route that stays the same is left alone', () {
      final t = setup('3');
      t.store.patch(const StatePatch(walk: WalkPatch(progressM: 60)));
      t.store.patch(const StatePatch(online: false));
      expect(t.store.state.walk.progressM, 60);
    });
  });

  group('re-notification (F88 / F89)', () {
    test('upgrade and raise notify once, downgrade does not', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m5)));
      expect(t.platform.vibrations, [alertChangePattern]);
      expect(t.platform.notifications, ['Tsunami alert upgraded']);
      t.store.tick(1000);
      expect(t.platform.notifications.length, 1);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m10)));
      expect(t.platform.notifications.last, 'Expected tsunami height raised');
      t.store.patch(StatePatch(alerts: [alertEarthquake, alertTsunami]));
      expect(t.platform.notifications.length, 2);
      expect(t.store.state.alertChange?.kind, AlertChangeKind.downgrade);
    });

    test('no notification when a scenario opens', () {
      expect(setup('5').platform.notifications, isEmpty);
    });

    test('pushCoversReNotify: only in the background with push enabled', () {
      expect(pushCoversReNotify(foreground: true, pushEnabled: true), isFalse);
      expect(pushCoversReNotify(foreground: true, pushEnabled: false), isFalse);
      expect(pushCoversReNotify(foreground: false, pushEnabled: true), isTrue);
      expect(pushCoversReNotify(foreground: false, pushEnabled: false), isFalse);
    });

    test('isForegroundLifecycle: matches FCM (inactive is still foreground)', () {
      const table = <AppLifecycleState?, bool>{
        null: true,
        AppLifecycleState.resumed: true,
        AppLifecycleState.inactive: true,
        AppLifecycleState.hidden: false,
        AppLifecycleState.paused: false,
        AppLifecycleState.detached: false,
      };
      expect(table.length, AppLifecycleState.values.length + 1);
      table.forEach((state, foreground) => expect(isForegroundLifecycle(state), foreground, reason: '$state'));
    });

    // [foreground] / [pushEnabled] are read at the moment of the change, as AppShell does.
    ({AppStore store, FakePlatform platform, AppEffects effects}) withPush({required bool foreground, required bool pushEnabled}) =>
        setup('5', pushCovers: () => pushCoversReNotify(foreground: foreground, pushEnabled: pushEnabled));

    test('foreground with push enabled: re-notifies', () {
      final t = withPush(foreground: true, pushEnabled: true);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m5)));
      expect(t.platform.vibrations, [alertChangePattern]);
      expect(t.platform.notifications, ['Tsunami alert upgraded']);
    });

    test('background with push enabled: no re-notification (the FCM notification covers it)', () {
      final t = withPush(foreground: false, pushEnabled: true);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m5)));
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m10)));
      expect(t.platform.vibrations, isEmpty);
      expect(t.platform.notifications, isEmpty);
      expect(t.store.state.alertChange?.kind, AlertChangeKind.raise);
    });

    test('background without push (unavailable / not enabled): still re-notifies', () {
      final t = withPush(foreground: false, pushEnabled: false);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m5)));
      expect(t.platform.vibrations, [alertChangePattern]);
      expect(t.platform.notifications, ['Tsunami alert upgraded']);
    });
  });

  group('forced return to evacuation (F85, 14.7-6)', () {
    test('scenario 5: upgrade with too little margin -> Go higher. NOW', () {
      final t = setup('5');
      expect(t.store.screen, ScreenId.s06);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      final s = t.store.state;
      expect(s.onHighGround, isFalse);
      expect(s.goHigher, GoHigher.now);
      expect(s.guideStep, GuideStep.action);
      expect(t.store.screen, ScreenId.s03);
      expect(t.store.nav.route.refuge.elev, greaterThanOrEqualTo(20));
    });

    test('pressing On high ground again under the same conditions stays on S06', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      t.store.patch(const StatePatch(onHighGround: true));
      expect(t.store.state.onHighGround, isTrue);
      expect(t.store.screen, ScreenId.s06);
      expect(t.store.state.goHigher, isNull);
    });

    test('a further raise checks again', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.m10)));
      t.store.patch(const StatePatch(onHighGround: true));
      expect(t.store.margin.level, isNot(MarginLevel.short));
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      expect(t.store.state.onHighGround, isFalse);
    });

    test('a downgrade does not send the user back down, and does not fire again', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      t.store.patch(const StatePatch(onHighGround: true));
      t.store.patch(StatePatch(alerts: [alertEarthquake, alertTsunami]));
      expect(t.store.state.onHighGround, isTrue);
    });

    test('a rehearsal of the same scenario fires again', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      t.store.loadScenario('5');
      expect(t.store.state.onHighGround, isTrue);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      expect(t.store.state.onHighGround, isFalse);
    });

    test('short only at the lowest point of the error circle: no forced change', () {
      final t = setup('5');
      t.store.patch(const StatePatch(gps: GpsPatch(position: Point(380, 283), accuracyM: 180)));
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      expect(t.store.state.onHighGround, isTrue);
      expect(t.store.screen, ScreenId.s06);
    });

    test('short even at the highest point: forced, then again once the location becomes certain', () {
      final t = setup('5');
      t.store.patch(const StatePatch(gps: GpsPatch(position: Point(100, 400), accuracyM: 110)));
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      expect(t.store.state.onHighGround, isFalse);
      expect(isLocationApproximate(t.store.state), isTrue);

      t.store.patch(const StatePatch(onHighGround: true));
      expect(t.store.state.onHighGround, isTrue, reason: 'same trigger: not again');

      t.store.patch(const StatePatch(gps: GpsPatch(accuracyM: 10)));
      expect(t.store.state.onHighGround, isFalse, reason: 'the location became certain');
    });

    test('at a designated site the instruction stays', () {
      final t = setup('5');
      // Hill Park with the threshold raised so that even its elevation is "not enough".
      t.store.patch(const StatePatch(gps: GpsPatch(position: Point(455, 205)), hugeMinElevM: 40));
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      expect(t.store.margin.mustMove, isTrue);
      expect(t.store.margin.designated?.id, 'hill-park');
      expect(t.store.state.onHighGround, isTrue);
    });

    test('after all clear the one-shot record is gone', () {
      final t = setup('5');
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge)));
      t.store.patch(const StatePatch(alerts: []));
      expect(t.store.screen, ScreenId.h00);
      t.store.patch(StatePatch(alerts: major(ExpectedHeight.huge), onHighGround: true));
      expect(t.store.state.onHighGround, isFalse);
    });
  });

  group('app effects', () {
    test('leaving a screen stops the read-aloud, except while the screen is off', () {
      final t = setup('2');
      t.store.navigate(ScreenId.s09);
      expect(t.platform.cancels, 1);
      t.store.patch(const StatePatch(screenOff: true));
      t.store.back();
      expect(t.platform.cancels, 1);
    });

    test('nav is recomputed only as needed and follows the state', () {
      final t = setup('3');
      final route = t.store.nav.route;
      t.store.tick(1000);
      expect(identical(t.store.nav.route, route), isTrue);
      t.store.patch(const StatePatch(online: false));
      expect(identical(t.store.nav.route, route), isFalse);
      expect(t.store.nav.nextSegmentVerified, isFalse);
    });

    test('computeNavigation works without a memo', () {
      final t = setup('3');
      final n = computeNavigation(t.store.state);
      expect(n.nextTurn?.direction, TurnDirection.right);
      expect(n.remainingM, n.route.totalM);
    });
  });
}
