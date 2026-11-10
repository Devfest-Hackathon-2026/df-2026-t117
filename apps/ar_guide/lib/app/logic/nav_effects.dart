// Navigation side effects. Port of mocks/evacuate/src/logic/useNavEffects.ts. They run on every screen,
// including while the demo "screen off" blackout is shown (F34):
//  1. Arrival: nav.arrived during evacuation guidance -> onHighGround = true, walk paused (F35 -> S06).
//  2. Turn announcement: the next left/right turn comes within turnAnnounceM (30 m) -> speak the
//     instruction in the current language + vibrate, once per turn (requirements 7.5).
//  3. Route change (origin, or a different refuge / node path, e.g. after the online toggle or a raised
//     tsunami forecast) -> the walk continues from where the user is: the position on the old route becomes
//     the new origin and walk.progressM restarts at 0. Progress going backwards (reset, scenario reload)
//     re-arms the turn announcements so a rehearsal announces again.
// The web's device-tilt hook (deviceRaised) is DeviceRaiseEffects (device_raise.dart).
import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/types.dart';
import 'alert_effects.dart';
import 'effect_strings.dart';
import 'nav.dart';

/// Turn-approach pattern: two short pulses.
const List<int> turnPattern = [180, 90, 180];

/// Spoken turn instruction, e.g. "Turn right in 30 meters." (used by the announcement and Listen buttons).
String turnSpeech(Lang lang, TurnDirection direction, double distanceM) => fmt(
      turnSpeechDict[lang]![direction.name]!,
      {'n': distanceM.round() < 0 ? 0 : distanceM.round()},
    );

class NavEffects {
  NavEffects(this.store);

  final AppStore store;

  bool _started = false;
  bool _arrivalFired = false;
  String? _announced;
  double _prevProgress = 0;
  String? _announceDeps;
  late String _routeKey;
  late Point _lastPosition;

  /// Runs once per state change, with the state of that moment.
  void run(AppState state, Navigation nav) {
    final routeKey = '${nav.origin.x},${nav.origin.y}|${nav.route.refuge.id}|${nav.route.nodeIds.join('>')}';
    final progressM = state.walk.progressM;
    if (!_started) {
      _started = true;
      _prevProgress = progressM;
      _routeKey = routeKey;
      _lastPosition = nav.position;
    }

    final mode = deriveMode(state, nav.inHazardZone);
    final guiding = mode == Mode.evacuate && state.guideStep == GuideStep.nav;

    // 1. Arrival -> S06 (once per arrival; re-armed when no longer arrived).
    if (!nav.arrived) {
      _arrivalFired = false;
    } else if (guiding && !_arrivalFired) {
      _arrivalFired = true;
      store.patch(const StatePatch(onHighGround: true, walk: WalkPatch(playing: false)));
    }

    // Progress went backwards (panel reset / scenario reload / new route) -> announce turns again.
    if (progressM < _prevProgress) _announced = null;
    _prevProgress = progressM;

    // 2. Turn announcement (voice + vibration), also while the screen is off. Once per turn.
    final turn = nav.nextTurn;
    final turnKey = turn != null && turn.direction != TurnDirection.straight
        ? '${nav.origin.x},${nav.origin.y}|${turn.point.x.toStringAsFixed(1)},${turn.point.y.toStringAsFixed(1)}'
        : null;
    final within = turn != null && turn.distanceM <= turnAnnounceM;
    final direction = turn?.direction ?? TurnDirection.straight;
    // Same dependencies as the web's effect: re-evaluated only when one of these changes.
    final deps = '$guiding|$turnKey|$within|$direction|${state.lang}';
    if (deps != _announceDeps) {
      _announceDeps = deps;
      if (guiding && turnKey != null && within && _announced != turnKey) {
        _announced = turnKey;
        store.platform.speak(turnSpeech(state.lang, direction, turn.distanceM), state.lang);
        store.platform.vibrate(turnPattern);
        store.announceTurn();
      }
    }

    // 3. Route changed (origin, refuge or node path) -> continue on the new route from the current position.
    if (_routeKey != routeKey) {
      _routeKey = routeKey;
      _announced = null;
      if (progressM != 0) store.patch(rebaseOrigin(state, _lastPosition));
    }
    _lastPosition = nav.position;
  }
}
