// App store: ChangeNotifier + InheritedNotifier. Port of mocks/evacuate/src/state/store.tsx.
// The reducer cases are pure functions (`reduce...`), and AppStore has one method per web action.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../i18n/i18n.dart';
import '../logic/margin.dart';
import '../logic/nav.dart';
import '../platform/app_platform.dart';
import 'action_rules.dart';
import 'derive.dart';
import 'scenarios.dart';
import 'types.dart';

/// Base walking speed (m/s) for walk.speed = 1 (requirements 7.5).
const double walkBaseMps = 1.5;

/// While online (and the feed is not paused), `tick` refreshes lastFetchAt once per virtual minute.
const int fetchIntervalMs = 60 * 1000;

/// Compare the tsunami alert before / after a patch (FB3):
/// - upgrade (level up) / raise (expected height up) / downgrade (level down) -> alertChange (the band, F88).
///   A new alert (none before) or a lowered height at the same level shows no band.
/// - keeps the highest level / height announced so far (a downgrade never loosens guidance, F8A)
/// - every tsunami alert lifted -> peaks, band and the evacuation progress (high ground, nav step) reset.
/// - arriving on high ground clears goHigher.
AppState trackAlertChanges(AppState prev, AppState next) {
  var out = next;
  if (next.onHighGround && !prev.onHighGround && next.goHigher != null) {
    out = out.copyWith(clearGoHigher: true);
  }
  if (identical(prev.alerts, next.alerts)) return out;
  final before = mostSevere(prev.alerts, HazardType.tsunami);
  final after = mostSevere(next.alerts, HazardType.tsunami);
  if (after == null) {
    if (before == null) return out;
    return out.copyWith(
      clearPeakTsunamiLevel: true,
      clearPeakExpectedHeight: true,
      clearAlertChange: true,
      clearGoHigher: true,
      onHighGround: false,
      guideStep: GuideStep.action,
    );
  }
  final hAfter = after.expectedHeight;
  AlertChangeKind? change;
  if (before != null) {
    final dl = levelRank(after.level) - levelRank(before.level);
    final hBefore = before.expectedHeight;
    if (dl > 0) {
      change = AlertChangeKind.upgrade;
    } else if (dl < 0) {
      change = AlertChangeKind.downgrade;
    } else if (hAfter != null && (hBefore == null || heightRank(hAfter) > heightRank(hBefore))) {
      change = AlertChangeKind.raise;
    }
  }
  final peak = prev.peakTsunamiLevel;
  final peakLevel = peak != null && levelRank(peak) > levelRank(after.level) ? peak : after.level;
  final peakHeight = maxHeight(prev.peakExpectedHeight, hAfter);
  return out.copyWith(
    peakTsunamiLevel: peakLevel,
    peakExpectedHeight: peakHeight,
    clearPeakExpectedHeight: peakHeight == null,
    alertChange: change == null ? null : AlertChange(kind: change, level: after.level, expectedHeight: hAfter, at: next.now),
  );
}

/// Partial update. Shaking turning on, or an evacuation alert becoming active / more severe / its expected
/// height raised, closes the overlay stack (unless the patch sets `overlay` itself) so guidance is shown.
AppState reducePatch(AppState state, StatePatch patch) {
  final next = trackAlertChanges(state, applyPatch(state, patch));
  if (next.overlay.isNotEmpty && patch.overlay == null) {
    final raised = !identical(next.alertChange, state.alertChange) && next.alertChange?.kind == AlertChangeKind.raise;
    if ((next.shaking && !state.shaking) || evacuationEscalated(state, next) || raised) {
      return next.copyWith(overlay: const []);
    }
  }
  return next;
}

/// Reset to a scenario's initial state (keeps current language, dialerEnabled and autoSpeak).
/// The thresholds start from [rules] (Remote Config), not from the demo panel sliders.
AppState reduceLoadScenario(AppState state, String id, [ActionRules rules = ActionRules.defaults]) =>
    buildScenarioState(id, state.lang, rules).copyWith(
      dialerEnabled: state.dialerEnabled,
      autoSpeak: state.autoSpeak,
      scenarioRun: state.scenarioRun + 1,
    );

/// Push a sub screen on the overlay stack (no duplicate if it is already on top).
AppState reduceNavigate(AppState state, ScreenId screen) {
  if (state.overlay.isNotEmpty && state.overlay.last == screen) return state;
  return state.copyWith(overlay: [...state.overlay, screen]);
}

/// Can [reduceBack] change anything?
bool canGoBack(AppState state) => state.overlay.isNotEmpty || state.deviceRaised || state.guideStep == GuideStep.nav;

/// Pop the overlay stack. If it is empty: lower the device if raised, else nav -> action.
AppState reduceBack(AppState state) {
  if (state.overlay.isNotEmpty) return state.copyWith(overlay: state.overlay.sublist(0, state.overlay.length - 1));
  if (state.deviceRaised) return state.copyWith(deviceRaised: false);
  if (state.guideStep == GuideStep.nav) return state.copyWith(guideStep: GuideStep.action);
  return state;
}

/// Advance the virtual clock by [dtMs] and the walk by walkBaseMps * speed while playing
/// (the walk holds while S07 / A01 is shown: route guidance is paused there).
/// While online and !feedPaused, also refreshes lastFetchAt every fetchIntervalMs.
AppState reduceTick(AppState state, int dtMs) {
  final now = state.now + dtMs;
  final polling = state.online && !state.feedPaused;
  final lastFetchAt = polling && now - state.lastFetchAt >= fetchIntervalMs ? now : state.lastFetchAt;
  // resolveScreen's defaults are exact for these two screens (they don't depend on nav inputs).
  final screen = resolveScreen(state);
  if (!state.walk.playing || screen == ScreenId.s07 || screen == ScreenId.a01) {
    return state.copyWith(now: now, lastFetchAt: lastFetchAt);
  }
  final progressM = state.walk.progressM + walkBaseMps * state.walk.speed * (dtMs / 1000);
  return state.copyWith(
    now: now,
    lastFetchAt: lastFetchAt,
    walk: state.walk.apply(WalkPatch(progressM: progressM)),
  );
}

/// Show a toast (null hides it). The toast auto-hides after ~2.5 s (AppEffects).
AppState reduceShowToast(AppState state, String? message) =>
    state.copyWith(toast: message, clearToast: message == null);

class AppStore extends ChangeNotifier {
  AppStore({String scenarioId = defaultScenarioId, Lang? lang, AppPlatform? platform})
      : _state = buildScenarioState(scenarioId, lang ?? loadLang()),
        platform = platform ?? DeviceAppPlatform();

  /// Speech, vibration and notifications (replaced by a fake in tests).
  final AppPlatform platform;

  AppState _state;
  AppState get state => _state;

  ActionRules _rules = ActionRules.defaults;

  /// The action rules in use (Remote Config, cached, or the built-in defaults). Scenarios start from them.
  ActionRules get rules => _rules;

  /// Applies rules loaded at startup; loadScenario / reset use them from now on. In the current state a
  /// threshold is only replaced while it still has the old rules' value (a demo panel slider change is kept).
  void applyRules(ActionRules rules) {
    final old = _rules;
    final s = _state;
    _rules = rules;
    _state = s.copyWith(
      marginAmpleM: s.marginAmpleM == old.marginAmpleM ? rules.marginAmpleM : null,
      hugeMinElevM: s.hugeMinElevM == old.hugeMinElevM ? rules.hugeMinElevM : null,
      staleThresholdMin: s.staleThresholdMin == old.staleThresholdMin ? rules.staleThresholdMin : null,
    );
    notifyListeners();
  }

  final _routeMemo = RouteMemo();
  AppState? _navFor;
  late Navigation _nav;

  /// Route + position + next turn for the current state (the web's `useNavigation()`).
  Navigation get nav {
    if (!identical(_navFor, _state)) {
      _nav = computeNavigation(_state, _routeMemo);
      _navFor = _state;
    }
    return _nav;
  }

  /// Margin check for the current position (the web's `useMargin()`).
  MarginInfo get margin => assessMargin(_state, nav.position);

  /// The screen to show now.
  ScreenId get screen => resolveScreen(_state, nav.nextSegmentVerified, nav.inHazardZone);

  final _turnAnnounce = StreamController<void>.broadcast(sync: true);

  /// Fires on every turn announcement, so screens can flash the speaker / vibration icons.
  Stream<void> get onTurnAnnounce => _turnAnnounce.stream;

  /// Called by NavEffects.
  void announceTurn() => _turnAnnounce.add(null);

  @override
  void dispose() {
    _turnAnnounce.close();
    super.dispose();
  }

  void _set(AppState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  void patch(StatePatch patch) => _set(reducePatch(_state, patch));
  void loadScenario(String id) => _set(reduceLoadScenario(_state, id, _rules));
  void navigate(ScreenId screen) => _set(reduceNavigate(_state, screen));
  void back() => _set(reduceBack(_state));
  void tick(int dtMs) => _set(reduceTick(_state, dtMs));
  void showToast(String? message) => _set(reduceShowToast(_state, message));
}

/// Makes the store available to the screens.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  /// The store; the calling widget rebuilds on every state change.
  static AppStore watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// The store, without rebuilding (for button callbacks).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Short forms for the screens. All getters except [store] rebuild the widget on state changes,
/// so call them in `build`; in callbacks use `context.store`.
extension AppContext on BuildContext {
  AppStore get store => AppScope.read(this);
  AppState get appState => AppScope.watch(this).state;
  Navigation get nav => AppScope.watch(this).nav;
  MarginInfo get margin => AppScope.watch(this).margin;
  Lang get lang => appState.lang;
  CommonStrings get common => commonStrings[lang]!;

  /// The current language's strings of a screen dictionary (the web's `useT`).
  Tr t(Dict dict) => Tr.of(dict, lang);
}
