// Device raised -> AR (F36): thresholds, hysteresis, debounce, and the effect that patches deviceRaised.
import 'dart:async';

import 'package:ar_guide/app/logic/app_effects.dart';
import 'package:ar_guide/app/logic/device_raise.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/platform/tilt.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/foundation.dart';
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

class _FakeTilt implements TiltSource {
  StreamController<double>? controller;
  int listens = 0;

  bool get active => controller != null;

  @override
  Stream<double> pitch() {
    listens++;
    controller = StreamController<double>(onCancel: () => controller = null);
    return controller!.stream;
  }

  void send(double pitch) => controller?.add(pitch);
}

/// Pitch (camera below the horizon) for a front/back tilt in the web's beta terms.
double pitchFor(double tiltDeg) => 90 - tiltDeg;

Duration ms(int v) => Duration(milliseconds: v);

/// Feeds (ms, tilt deg) samples; returns the committed changes as "ms:value".
List<String> run(List<(int, double)> samples) {
  final d = RaiseDetector();
  final out = <String>[];
  for (final (t, tilt) in samples) {
    final c = d.add(pitchFor(tilt), ms(t));
    if (c != null) out.add('$t:$c');
  }
  return out;
}

void main() {
  group('frontBackTiltDeg', () {
    test('flat = 0, upright = 90, tilted back past upright stays > 90', () {
      expect(frontBackTiltDeg(90), 0);
      expect(frontBackTiltDeg(0), 90);
      expect(frontBackTiltDeg(30), 60);
      expect(frontBackTiltDeg(-20), 110);
    });
  });

  group('RaiseDetector', () {
    final cases = <String, (List<(int, double)>, List<String>)>{
      'held at 60 deg for 300 ms -> raised': ([(0, 60), (100, 61), (200, 62), (300, 65)], ['300:true']),
      'shorter than 300 ms -> nothing': ([(0, 70), (100, 70), (200, 70)], []),
      'just below 60 deg never raises': ([(0, 59.9), (500, 59.9), (1000, 59.9)], []),
      'flat at first -> lowered once, then nothing': ([(0, 10), (300, 10), (600, 10), (900, 10)], ['300:false']),
      'between 30 and 60 keeps the state (hysteresis)': (
        [(0, 70), (300, 70), (400, 50), (800, 31), (1500, 30)],
        ['300:true'],
      ),
      'below 30 for 300 ms -> lowered': ([(0, 70), (300, 70), (400, 29), (600, 20), (700, 10)], ['300:true', '700:false']),
      'a dip below 30 shorter than 300 ms is ignored (debounce)': (
        [(0, 70), (300, 70), (400, 20), (500, 20), (600, 70), (1000, 20), (1200, 70)],
        ['300:true'],
      ),
      'shaking across 60 deg: the hold restarts after a lowered sample': (
        [(0, 20), (300, 20), (400, 61), (500, 20), (600, 61), (800, 61), (900, 61)],
        ['300:false', '900:true'],
      ),
      'samples inside the band do not restart a running hold': ([(0, 20), (300, 20), (400, 61), (500, 55), (700, 61)], ['300:false', '700:true']),
    };
    cases.forEach((name, c) {
      test(name, () => expect(run(c.$1), c.$2));
    });

    test('restart keeps the committed value and drops a running hold', () {
      final d = RaiseDetector();
      d.add(pitchFor(70), ms(0));
      expect(d.add(pitchFor(70), ms(300)), isTrue);
      d.add(pitchFor(10), ms(400)); // a lowering hold starts
      d.restart();
      expect(d.raised, isTrue);
      expect(d.add(pitchFor(70), ms(2000)), isNull); // same as committed: no change
      d.add(pitchFor(10), ms(2100));
      expect(d.add(pitchFor(10), ms(2300)), isNull); // hold restarted at 2100
      expect(d.add(pitchFor(10), ms(2400)), isFalse);
    });

    test('a gap over 1 s between samples restarts the hold', () {
      final d = RaiseDetector();
      d.add(pitchFor(10), ms(0));
      expect(d.add(pitchFor(10), ms(300)), isFalse);
      d.add(pitchFor(70), ms(400));
      expect(d.add(pitchFor(70), ms(2000)), isNull); // 1.6 s gap: hold starts again here
      expect(d.add(pitchFor(70), ms(2200)), isNull);
      expect(d.add(pitchFor(70), ms(2300)), isTrue);
    });
  });

  test('seed takes the posture without reporting; between the thresholds it keeps the value', () {
    final d = RaiseDetector();
    d.add(pitchFor(10), ms(0));
    expect(d.add(pitchFor(10), ms(300)), isFalse);
    d.seed(pitchFor(75), ms(400));
    expect(d.raised, isTrue);
    expect(d.add(pitchFor(75), ms(800)), isNull);
    d.seed(pitchFor(50), ms(900));
    expect(d.raised, isTrue);
    d.add(pitchFor(10), ms(1000));
    expect(d.add(pitchFor(10), ms(1300)), isFalse);
  });

  group('DeviceRaiseEffects', () {
    late AppStore store;
    late _FakeTilt tilt;
    late Duration now;

    // Same wiring as AppEffects, with a controllable clock.
    void start(String scenario, {ValueListenable<int>? helpCards}) {
      store = AppStore(scenarioId: scenario, lang: Lang.en, platform: _Silent());
      tilt = _FakeTilt();
      now = Duration.zero;
      final raise = DeviceRaiseEffects(store, tilt, now: () => now, helpCards: helpCards);
      store.addListener(() => raise.run(store.state, store.screen));
      raise.run(store.state, store.screen);
      addTearDown(raise.dispose);
    }

    Future<void> hold(double tiltDeg) async {
      for (var i = 0; i < 4; i++) {
        tilt.send(pitchFor(tiltDeg));
        await Future<void>.delayed(Duration.zero);
        now += ms(100);
      }
    }

    test('raising on S04 opens S11, lowering returns to S04', () async {
      start('3b');
      expect(store.screen, ScreenId.s04);
      expect(tilt.active, isTrue);
      await hold(10);
      expect(store.screen, ScreenId.s04);
      await hold(75);
      expect(store.state.deviceRaised, isTrue);
      expect(store.screen, ScreenId.s11);
      expect(tilt.active, isTrue);
      await hold(50); // in the band: stays
      expect(store.screen, ScreenId.s11);
      await hold(20);
      expect(store.state.deviceRaised, isFalse);
      expect(store.screen, ScreenId.s04);
    });

    test('raising the phone to show the help card stays on S04; after closing, a new raise opens AR', () async {
      final cards = ValueNotifier<int>(0);
      start('3b', helpCards: cards);
      await hold(10); // lying flat: lowered committed
      cards.value = 1; // help card opened on S04
      expect(tilt.active, isFalse);
      await hold(75); // raised to show the card: nothing is listened to
      expect(store.state.deviceRaised, isFalse);
      expect(store.screen, ScreenId.s04);
      cards.value = 0; // closed while still raised
      expect(tilt.active, isTrue);
      await hold(75);
      await hold(75);
      expect(store.screen, ScreenId.s04); // the raised posture at closing is not a raise
      await hold(20); // lowered
      expect(store.screen, ScreenId.s04);
      await hold(75); // raised again
      expect(store.state.deviceRaised, isTrue);
      expect(store.screen, ScreenId.s11);
    });

    test('closing the help card with the phone flat: raising works as before', () async {
      final cards = ValueNotifier<int>(0);
      start('3b', helpCards: cards);
      await hold(10);
      cards.value = 1;
      cards.value = 0;
      await hold(10);
      expect(store.screen, ScreenId.s04);
      await hold(75);
      expect(store.screen, ScreenId.s11);
    });

    test('the demo shortcut / panel toggle is not overwritten while the tilt does not cross', () async {
      start('3b');
      await hold(10); // lying flat: lowered committed
      store.patch(const StatePatch(deviceRaised: true)); // S04 "View in AR"
      expect(store.screen, ScreenId.s11);
      await hold(10);
      await hold(30);
      expect(store.state.deviceRaised, isTrue);
      expect(store.screen, ScreenId.s11);
    });

    test('leaving and returning keeps a manual AR entry while the phone stays flat', () async {
      start('3b');
      await hold(10); // lying flat: lowered committed
      store.patch(const StatePatch(deviceRaised: true)); // demo panel / S04 "View in AR"
      expect(store.screen, ScreenId.s11);
      store.patch(const StatePatch(online: false)); // leaves S04/S11/S12: sensor stops
      expect(tilt.active, isFalse);
      store.patch(const StatePatch(online: true));
      expect(tilt.active, isTrue);
      expect(store.screen, ScreenId.s11);
      await hold(10);
      await hold(10);
      expect(store.state.deviceRaised, isTrue);
      expect(store.screen, ScreenId.s11);
    });

    test('the sensor is off on other screens and when AR cannot be entered', () async {
      start('3b');
      expect(tilt.active, isTrue);
      store.patch(const StatePatch(guideStep: GuideStep.action));
      expect(store.screen, isNot(anyOf(ScreenId.s04, ScreenId.s11, ScreenId.s12)));
      expect(tilt.active, isFalse);
      store.patch(const StatePatch(guideStep: GuideStep.nav));
      expect(tilt.active, isTrue);
      store.patch(const StatePatch(online: false));
      expect(tilt.active, isFalse);
    });

    test('AppEffects without a tilt source never listens', () {
      final s = AppStore(scenarioId: '3b', lang: Lang.en, platform: _Silent());
      final effects = AppEffects(s)..start(clock: false);
      addTearDown(effects.dispose);
      expect(effects.raiseEffects.listening, isFalse);
    });

    test('AppEffects with a tilt source listens on S04 and stops on dispose', () {
      final s = AppStore(scenarioId: '3b', lang: Lang.en, platform: _Silent());
      final t = _FakeTilt();
      final effects = AppEffects(s, tilt: t)..start(clock: false);
      expect(effects.raiseEffects.listening, isTrue);
      expect(t.active, isTrue);
      effects.dispose();
      expect(t.active, isFalse);
    });
  });
}
