// Runs the side effects after every state change. Replaces what the web mounts once in App.tsx:
// the 1 s virtual clock, "leaving a screen stops its read-aloud", NavEffects, AlertEffects, the device tilt
// (DeviceRaiseEffects, F36) and the toast timer.
import 'dart:async';

import '../platform/tilt.dart';
import '../state/store.dart';
import '../state/types.dart';
import 'alert_effects.dart';
import 'device_raise.dart';
import 'nav_effects.dart';

const Duration tickInterval = Duration(seconds: 1);
const Duration toastDuration = Duration(milliseconds: 2500);

class AppEffects {
  /// [pushCovers]: see [AlertEffects]. [tilt]: phone tilt for deviceRaised (null = demo controls only).
  AppEffects(this.store, {bool Function()? pushCovers, TiltSource? tilt})
      : navEffects = NavEffects(store),
        alertEffects = AlertEffects(store, pushCovers: pushCovers),
        raiseEffects = DeviceRaiseEffects(store, tilt);

  final AppStore store;
  final NavEffects navEffects;
  final AlertEffects alertEffects;
  final DeviceRaiseEffects raiseEffects;

  Timer? _clock;
  Timer? _toastTimer;
  String? _toast;
  ScreenId? _screen;
  bool _running = false;
  bool _again = false;

  /// [clock] = false leaves the virtual clock to the caller (tests call `store.tick`).
  void start({bool clock = true}) {
    store.addListener(_onChange);
    _onChange();
    if (clock) _clock = Timer.periodic(tickInterval, (_) => store.tick(tickInterval.inMilliseconds));
  }

  void dispose() {
    _clock?.cancel();
    _toastTimer?.cancel();
    raiseEffects.dispose();
    store.removeListener(_onChange);
  }

  // An effect may change the state. Like React's effects, one pass sees one state, and a change made
  // during a pass starts another pass afterwards instead of running nested.
  void _onChange() {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        _pass();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  void _pass() {
    final state = store.state;
    final nav = store.nav;
    final margin = store.margin;

    // Leaving a screen stops its read-aloud. While the screen is "off" turn announcements must keep playing.
    // Before NavEffects, so a turn announcement fired in the same pass survives it.
    final screen = store.screen;
    if (_screen != null && _screen != screen && !state.screenOff) store.platform.cancelSpeech();
    _screen = screen;

    navEffects.run(state, nav);
    alertEffects.run(state, nav, margin);
    raiseEffects.run(state, screen);

    if (state.toast != _toast) {
      _toast = state.toast;
      _toastTimer?.cancel();
      if (_toast != null) _toastTimer = Timer(toastDuration, () => store.showToast(null));
    }
  }
}
