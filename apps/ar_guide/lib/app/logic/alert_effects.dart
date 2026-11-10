// Alert-change side effects (FB3: F88 / F89, FB2: F85). Port of mocks/evacuate/src/logic/useAlertEffects.ts.
//  1. Upgrade / raised expected height -> notify again: vibration + notification.
//     The band at the top of every guidance screen is the in-app part of the notification.
//     While shaking, only the band is updated (the screen stays on S02, 7.2 rank 1).
//  2. Margin "not enough" for certain while waiting on high ground (not at a designated evacuation site)
//     -> back to evacuation: onHighGround off, "Go higher. NOW" (goHigher now), route from here.
//     Once per trigger only (rule c): it fires when the condition newly holds, and is checked again only
//     after an upgrade / raised height (the peaks change) or when the location becomes certain.
//     Pressing "On high ground" again under the same conditions therefore stays on S06.
//  While the app is not in the foreground and FCM push is enabled, the push notification already covers the
//  change, so the re-notification is skipped (no duplicate). Without push it still fires.
import 'dart:ui' show AppLifecycleState;

import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';
import 'effect_strings.dart';
import 'margin.dart';
import 'nav.dart';

/// Long-short-long pattern for a re-notification.
const List<int> alertChangePattern = [400, 120, 400, 120, 400];

double _round1(double v) => (v * 10 + 0.5).floor() / 10;

/// Patch that makes [p] the new route origin (manual pin if one is set, else the simulated GPS position).
StatePatch rebaseOrigin(AppState state, Point p) {
  final at = Point(_round1(p.x), _round1(p.y));
  return state.manualPin != null
      ? StatePatch(manualPin: at, walk: const WalkPatch(progressM: 0))
      : StatePatch(gps: GpsPatch(position: at), walk: const WalkPatch(progressM: 0));
}

/// Re-check trigger for the forced return to evacuation: changes only with an upgrade / raised height
/// (the peaks; a downgrade or closing the band does not change them), when the location becomes certain,
/// or with a scenario load / reset (scenarioRun, so a rehearsal of the same scenario fires again).
String forceTriggerKey(AppState state, int certainCount) =>
    '${state.scenarioRun}|${state.peakTsunamiLevel?.name ?? '-'}|${state.peakExpectedHeight?.name ?? '-'}|$certainCount';

/// The last fired key, reset when it can no longer apply: every tsunami alert lifted (peaks back to null).
String? nextLastFiredKey(String? lastFiredKey, AppState state) => state.peakTsunamiLevel == null ? null : lastFiredKey;

/// Whether FCM treats the app as in the foreground (onMessage, not shown). firebase_messaging counts the process
/// as foreground while it is visible, so inactive (notification shade, split screen, system dialog) is foreground
/// too; only paused / hidden / detached are background. No lifecycle state yet counts as the foreground.
bool isForegroundLifecycle(AppLifecycleState? s) =>
    s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

/// Whether the push notification already covers a re-notification: only when the app is not in the
/// foreground and FCM push is enabled (foreground messages are not shown, see live_backend.dart).
bool pushCoversReNotify({required bool foreground, required bool pushEnabled}) => !foreground && pushEnabled;

/// Force evacuate now? Only when the condition holds and this trigger has not fired yet (rule c).
bool shouldForceEvacuate(bool condition, String key, String? lastFiredKey) => condition && key != lastFiredKey;

class AlertEffects {
  /// [pushCovers] answers [pushCoversReNotify] for the moment of the change (default: never covered).
  AlertEffects(this.store, {bool Function()? pushCovers}) : _pushCovers = pushCovers ?? _never;

  final AppStore store;
  final bool Function() _pushCovers;

  static bool _never() => false;

  bool _started = false;
  AlertChange? _firedChange;
  bool _prevApprox = false;
  int _certainCount = 0;
  String? _lastFired;

  /// Runs once per state change, with the state of that moment.
  void run(AppState state, Navigation nav, MarginInfo margin) {
    final approximate = isLocationApproximate(state);
    if (!_started) {
      _started = true;
      _firedChange = state.alertChange;
      _prevApprox = approximate;
    }

    // 1. Re-notify on upgrade / raise (once per change).
    final change = state.alertChange;
    if (!identical(_firedChange, change)) {
      _firedChange = change;
      if (change != null && change.kind != AlertChangeKind.downgrade && !_pushCovers()) {
        store.platform.vibrate(alertChangePattern);
        store.platform.notify('TASUKU', notifyBodyDict[state.lang]![change.kind.name]!);
      }
    }

    // Count "location became certain" (approximate -> not approximate): one of the re-check triggers.
    if (_prevApprox && !approximate) _certainCount += 1;
    _prevApprox = approximate;

    // 2. Not enough margin for certain on high ground -> evacuate again ("Go higher. NOW"), once per trigger.
    final mode = deriveMode(state, nav.inHazardZone);
    final condition = mode == Mode.safe && margin.mustMove && margin.designated == null;
    final key = forceTriggerKey(state, _certainCount);
    _lastFired = nextLastFiredKey(_lastFired, state);
    if (!shouldForceEvacuate(condition, key, _lastFired)) return;
    _lastFired = key;
    final origin = rebaseOrigin(state, nav.position);
    store.patch(StatePatch(
      manualPin: origin.manualPin,
      gps: origin.gps,
      onHighGround: false,
      goHigher: GoHigher.now,
      guideStep: GuideStep.action,
      walk: const WalkPatch(progressM: 0, playing: false),
    ));
  }
}
