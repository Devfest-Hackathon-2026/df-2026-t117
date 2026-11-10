// Derived state: guidance mode, current screen, priority action, freshness, AR availability.
// requirements.md 7.1 / 7.2 / 7.3 / 6.4.1. Port of mocks/evacuate/src/state/derive.ts.
import 'dart:math' as math;

import 'time.dart';
import 'types.dart';

enum Mode { normal, shake, evacuate, safe }

/// Above this location error (m) the location is "approximate": no route arrows, action + signs guide (F92).
const double locateAccuracyThresholdM = 100;

/// AR thresholds (requirements 6.4.1, condition 3).
const double arMaxPositionErrorM = 20;
const double arMaxHeadingErrorDeg = 15;

int levelRank(AlertLevel level) => switch (level) {
      AlertLevel.advisory => 1,
      AlertLevel.warning => 2,
      AlertLevel.emergency => 3,
    };

/// Highest-level alert (optionally of one hazard type), or null.
Alert? mostSevere(List<Alert> alerts, [HazardType? type]) {
  Alert? best;
  for (final a in alerts) {
    if (type != null && a.type != type) continue;
    if (best == null || levelRank(a.level) > levelRank(best.level)) best = a;
  }
  return best;
}

/// Active hazard types in display order (earthquake first), e.g. for "EARTHQUAKE + TSUNAMI".
List<HazardType> activeHazards(AppState state) => [HazardType.earthquake, HazardType.tsunami]
    .where((t) => state.alerts.any((a) => a.type == t))
    .toList();

/// Does this alert require evacuation to high ground?
/// Tsunami warning / major warning: always. Tsunami advisory: only when inside the coastal hazard zone.
bool requiresEvacuation(Alert alert, [bool inHazardZone = true]) {
  if (alert.type != HazardType.tsunami) return false;
  if (alert.level == AlertLevel.advisory) return inHazardZone;
  return true;
}

/// Most severe alert that requires evacuation, or null.
Alert? evacuationAlert(AppState state, [bool inHazardZone = true]) =>
    mostSevere(state.alerts.where((a) => requiresEvacuation(a, inHazardZone)).toList());

/// Hazard-zone flag used for tsunami advisories, latched once evacuation has started:
/// - while guideStep is nav the user keeps evacuating even after walking out of the zone, so an
///   advisory does not flip the mode to normal mid-route (S04 -> H00). Arrival still leads to S06.
/// - on high ground, or after a warning / major warning was announced in this event, a downgrade to an
///   advisory does not loosen guidance either (F8A): only lifting every alert ends it.
bool advisoryZone(AppState state, [bool inHazardZone = true]) {
  final peak = state.peakTsunamiLevel;
  final peakedAboveAdvisory = peak != null && levelRank(peak) >= levelRank(AlertLevel.warning);
  return inHazardZone || state.guideStep == GuideStep.nav || state.onHighGround || peakedAboveAdvisory;
}

/// An evacuation-requiring alert became active, or got more severe, between [prev] and [next].
/// Used by the store to close sub screens so guidance is shown.
bool evacuationEscalated(AppState prev, AppState next) {
  final after = evacuationAlert(next);
  if (after == null) return false;
  final before = evacuationAlert(prev);
  return before == null || levelRank(after.level) > levelRank(before.level);
}

/// GPS too poor (> 100 m) or denied. Ignores manualPin.
bool isLocationUncertain(AppState state) =>
    state.gps.permission == GpsPermission.denied || state.gps.accuracyM > locateAccuracyThresholdM;

/// The location is only approximate (or missing) and no pin was set (FB4, F90 / F92 / F94).
/// Guidance does NOT switch to the pin screen: evacuation shows the action guide (S03 / S05) with
/// "Follow the blue evacuation signs" and a small "Set location" button instead of route arrows.
bool isLocationApproximate(AppState state) => isLocationUncertain(state) && state.manualPin == null;

/// Guidance mode (requirements 7.1).
/// - shake: the current location is shaking (priority 1 in 7.2)
/// - safe: evacuation-requiring alert and on high ground. When the margin check (F85) says "not enough",
///   AlertEffects clears onHighGround (-> evacuate, "Go higher. NOW").
/// - evacuate: evacuation-requiring alert
/// - normal: otherwise (advisory-only alerts are shown on H00)
/// [inHazardZone] only matters for tsunami advisories. It is latched while evacuating (see [advisoryZone]).
Mode deriveMode(AppState state, [bool inHazardZone = true]) {
  if (state.shaking) return Mode.shake;
  final evac = evacuationAlert(state, advisoryZone(state, inHazardZone));
  if (evac == null) return Mode.normal;
  if (state.onHighGround) return Mode.safe;
  return Mode.evacuate;
}

/// AR may be entered at all: online, camera permission, supported device (6.4.1 condition 2).
bool canEnterAr(AppState state) => state.online && state.ar.cameraPermission && state.ar.supported;

/// Tracking quality OK: position error <= 20 m, heading error <= 15 deg, tracking (6.4.1 condition 3).
bool arTrackingOk(AppState state) =>
    state.gps.accuracyM <= arMaxPositionErrorM &&
    state.ar.headingAccuracyDeg <= arMaxHeadingErrorDeg &&
    state.ar.tracking;

/// All AR conditions (requirements 6.4.1): device raised, online + camera + supported,
/// accuracy/heading/tracking OK, next segment passability verified.
/// [nextSegmentVerified] defaults to `state.online`.
bool isArAvailable(AppState state, [bool? nextSegmentVerified]) =>
    state.deviceRaised && canEnterAr(state) && arTrackingOk(state) && (nextSegmentVerified ?? state.online);

/// Screen to show.
/// 1. lockScreen -> S01   2. top of overlay
/// 3. location permission not asked yet when route guidance starts -> A01 (F24)
/// 4. by mode. While the location is approximate (FB4) evacuation stays on the action guide S03 / S05
///    (with the signs hint) even when guideStep is nav, and returns to S04 once the location is good.
ScreenId resolveScreen(AppState state, [bool? nextSegmentVerified, bool inHazardZone = true]) {
  if (state.lockScreen) return ScreenId.s01;
  if (state.overlay.isNotEmpty) return state.overlay.last;
  final mode = deriveMode(state, inHazardZone);
  if (mode == Mode.evacuate && state.guideStep == GuideStep.nav && state.gps.permission == GpsPermission.prompt) {
    return ScreenId.a01;
  }
  switch (mode) {
    case Mode.normal:
      return ScreenId.h00;
    case Mode.shake:
      return ScreenId.s02;
    case Mode.safe:
      return ScreenId.s06;
    case Mode.evacuate:
      final actionGuide = state.guideStep == GuideStep.action || isLocationApproximate(state);
      if (!state.online) return actionGuide ? ScreenId.s05 : ScreenId.s08;
      if (actionGuide) return ScreenId.s03;
      if (isArAvailable(state, nextSegmentVerified)) return ScreenId.s11;
      // Raised but quality (accuracy / heading / tracking / passability) not met -> S12.
      // Offline / no camera / unsupported never enter S11/S12.
      if (state.deviceRaised && canEnterAr(state)) return ScreenId.s12;
      return ScreenId.s04;
  }
}

// ---------------------------------------------------------------------------
// Priority (requirements 7.2)

enum PriorityKind { protect, goUphillNow, goUphill, stayHere, checkInfo, none }

class PriorityAction {
  const PriorityAction(this.rank, this.kind, this.alert);

  /// 1 (most urgent) .. 5; 6 = nothing to do.
  final int rank;
  final PriorityKind kind;

  /// The alert that triggered it (most severe of that rank), if any.
  final Alert? alert;
}

/// The single action to show now (7.2). Ties go to the higher alert level.
/// 1 protect (shaking; the screen picks the pictogram by eqSituation)
/// 2 goUphillNow (tsunami warning / major warning, not on high ground)
/// 3 goUphill (tsunami advisory, inside hazard zone, not on high ground)
/// 4 stayHere (evacuation alert continues, on high ground)
/// 5 checkInfo (any other alert)
PriorityAction topPriorityAction(AppState state, [bool inHazardZone = true]) {
  final zone = advisoryZone(state, inHazardZone);
  if (state.shaking) {
    return PriorityAction(1, PriorityKind.protect, mostSevere(state.alerts, HazardType.earthquake));
  }
  final tsunamiWarnings = state.alerts
      .where((a) => a.type == HazardType.tsunami && (a.level == AlertLevel.warning || a.level == AlertLevel.emergency))
      .toList();
  if (!state.onHighGround && tsunamiWarnings.isNotEmpty) {
    return PriorityAction(2, PriorityKind.goUphillNow, mostSevere(tsunamiWarnings));
  }
  final advisories =
      state.alerts.where((a) => a.type == HazardType.tsunami && a.level == AlertLevel.advisory).toList();
  if (!state.onHighGround && zone && advisories.isNotEmpty) {
    return PriorityAction(3, PriorityKind.goUphill, mostSevere(advisories));
  }
  final evac = evacuationAlert(state, zone);
  if (state.onHighGround && evac != null) {
    return PriorityAction(4, PriorityKind.stayHere, evac);
  }
  if (state.alerts.isNotEmpty) {
    return PriorityAction(5, PriorityKind.checkInfo, mostSevere(state.alerts));
  }
  return const PriorityAction(6, PriorityKind.none, null);
}

// ---------------------------------------------------------------------------
// Freshness (requirements 7.3)

class Freshness {
  const Freshness({
    required this.stale,
    required this.ageMin,
    required this.lastAlertAt,
    required this.routeVerified,
    required this.liveRoadStatus,
    required this.passabilityCheckedAt,
  });

  /// Offline, or more than staleThresholdMin since lastFetchAt -> show "Last alert HH:MM JST • Stale".
  final bool stale;

  /// Minutes since last fetch.
  final double ageMin;

  /// Latest issuedAt among active alerts (null if none): the time shown in "JMA • 09:40 JST".
  final int? lastAlertAt;

  /// false when offline -> "Route unverified".
  final bool routeVerified;

  /// false when offline -> "Live road status unavailable".
  final bool liveRoadStatus;

  /// Time shown in "Passability checked HH:MM JST" (online only).
  final int? passabilityCheckedAt;
}

Freshness freshness(AppState state) {
  final ageMs = math.max(0, state.now - state.lastFetchAt);
  final ageMin = ageMs / minuteMs;
  return Freshness(
    stale: !state.online || ageMin > state.staleThresholdMin,
    ageMin: ageMin,
    lastAlertAt: state.alerts.isEmpty ? null : state.alerts.map((a) => a.issuedAt).reduce(math.max),
    routeVerified: state.online,
    liveRoadStatus: state.online,
    passabilityCheckedAt: state.online ? state.lastFetchAt : null,
  );
}
