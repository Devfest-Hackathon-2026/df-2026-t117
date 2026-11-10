// "Device raised -> AR" (requirements F36). Port of the web's useDeviceTilt (mocks/evacuate/src/platform/orientation.ts):
//  - front/back tilt (the web's |beta|) >= 60 deg -> raised, < 30 deg -> lowered, kept in between (hysteresis);
//    (the web uses < 45 deg; lowered to 30 after device testing so tilting the phone to look at the floor arrow stays in AR);
//  - deviceRaised is patched only when the detected value changes (a crossing), so the demo panel toggle
//    「端末を持ち上げる」 and the S04 "View in AR" shortcut are not overwritten by every sample;
//  - added here: a crossing must hold for [RaiseDetector.hold] (300 ms) before it counts, so a shaky hand
//    near a threshold does not flip between S04 and S11.
// The web needs a tap to opt in (iOS permission prompt). Android has no permission for these sensors, so the
// app listens without a tap, but only while S04 / S11 / S12 are shown and AR can be entered (battery).
// Also not while the help card (help/help_card.dart) is open: it is shown by raising the phone. When the card
// closes, the first sample is taken as the current posture without switching, so the user lowers and raises
// the phone again to enter AR.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../help/help_card_open.dart';
import '../platform/tilt.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';

/// Front/back tilt in the web's DeviceOrientation `beta` terms: 0 = phone flat, 90 = upright.
/// [pitchDeg] = camera angle below the horizon (0 = upright, 90 = flat).
double frontBackTiltDeg(double pitchDeg) => (90 - pitchDeg).abs();

/// Pure decision logic: pitch samples with their time -> committed raised / lowered changes.
class RaiseDetector {
  RaiseDetector({this.hold = const Duration(milliseconds: 300), this.maxGap = const Duration(seconds: 1)});

  static const raiseDeg = 60.0;
  static const lowerDeg = 30.0;

  final Duration hold;

  /// Samples further apart than this (e.g. after the app was in the background) restart a running hold.
  final Duration maxGap;

  bool? _committed;
  bool? _pending;
  Duration _pendingSince = Duration.zero;
  Duration? _lastAt;

  /// Last committed value (null until the first one).
  bool? get raised => _committed;

  /// The sensor was stopped and starts again: drop a running hold but keep the committed value, as the
  /// web keeps `last` while the app stays open. Otherwise, with the phone lying flat, returning to S11 after
  /// a manual "View in AR" would re-commit "lowered" and kick the user back to S04.
  void restart() {
    _pending = null;
    _lastAt = null;
  }

  static bool? _candidate(double pitchDeg) {
    final tilt = frontBackTiltDeg(pitchDeg);
    return tilt >= raiseDeg ? true : (tilt < lowerDeg ? false : null);
  }

  /// Takes the posture of this sample as the committed value without reporting a change (no hold).
  /// Between the thresholds the committed value is kept.
  void seed(double pitchDeg, Duration at) {
    _pending = null;
    _lastAt = at;
    _committed = _candidate(pitchDeg) ?? _committed;
  }

  /// Feeds one sample. Returns the new value when it commits (a change), otherwise null.
  bool? add(double pitchDeg, Duration at) {
    final last = _lastAt;
    _lastAt = at;
    if (last != null && at - last > maxGap) _pending = null;
    final candidate = _candidate(pitchDeg);
    // Between the thresholds: no new evidence either way; a running hold continues.
    if (candidate == null) return null;
    if (candidate == _committed) {
      _pending = null;
      return null;
    }
    if (_pending != candidate) {
      _pending = candidate;
      _pendingSince = at;
    }
    if (at - _pendingSince < hold) return null;
    _committed = candidate;
    _pending = null;
    return candidate;
  }
}

/// Screens where raising / lowering the phone matters.
const Set<ScreenId> tiltScreens = {ScreenId.s04, ScreenId.s11, ScreenId.s12};

/// Listens to [source] only while needed and patches deviceRaised on committed changes.
class DeviceRaiseEffects {
  /// [helpCards]: open help cards (default [helpCardsOpen]); the sensor is off while it is above 0.
  DeviceRaiseEffects(
    this.store,
    this.source, {
    Duration Function()? now,
    RaiseDetector? detector,
    ValueListenable<int>? helpCards,
  })  : _now = now ?? _stopwatchNow(),
        detector = detector ?? RaiseDetector(),
        _helpCards = helpCards ?? helpCardsOpen {
    _helpCards.addListener(_onHelpCards);
  }

  final AppStore store;
  final TiltSource? source;
  final RaiseDetector detector;
  final Duration Function() _now;
  StreamSubscription<double>? _sub;
  final ValueListenable<int> _helpCards;

  /// The sensor was stopped for a help card: the first sample after it seeds the detector.
  bool _seedNext = false;

  /// The stream reported an error (e.g. no `tasuku_ar/tilt` handler on this platform). The effect stops
  /// listening and does not subscribe again for the rest of this AppEffects' life; the demo controls still work.
  bool _failed = false;

  static Duration Function() _stopwatchNow() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  /// The sensor is listened to now.
  bool get listening => _sub != null;

  void run(AppState state, ScreenId screen) {
    final helpOpen = _helpCards.value > 0;
    final want = source != null &&
        !_failed &&
        tiltScreens.contains(screen) &&
        canEnterAr(state) &&
        !state.screenOff &&
        !helpOpen;
    if (want && _sub == null) {
      detector.restart();
      _sub = source!.pitch().listen(_onPitch, onError: (Object _) {
        _failed = true;
        stop();
      });
    } else if (!want && _sub != null) {
      stop();
      if (helpOpen) _seedNext = true;
    }
  }

  void _onHelpCards() => run(store.state, store.screen);

  void _onPitch(double pitchDeg) {
    if (_seedNext) {
      _seedNext = false;
      detector.seed(pitchDeg, _now());
      return;
    }
    final change = detector.add(pitchDeg, _now());
    if (change != null && change != store.state.deviceRaised) store.patch(StatePatch(deviceRaised: change));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Stops and stops following the help cards.
  void dispose() {
    stop();
    _helpCards.removeListener(_onHelpCards);
  }
}
