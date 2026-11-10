// Derived state: guidance mode, current screen, priority action, freshness, AR availability.
// requirements.md 7.1 / 7.2 / 7.3 / 6.4.1, implementation-plan.md 3.2.
import type { Alert, AlertLevel, AppState, HazardType, ScreenId } from './types';
import { MINUTE_MS } from './time';

export type Mode = 'normal' | 'shake' | 'evacuate' | 'safe';

/** Above this location error (m) the location is "approximate": no route arrows, action + signs guide (F92). */
export const LOCATE_ACCURACY_THRESHOLD_M = 100;
/** AR thresholds (requirements 6.4.1, condition 3). */
export const AR_MAX_POSITION_ERROR_M = 20;
export const AR_MAX_HEADING_ERROR_DEG = 15;

const LEVEL_RANK: Record<AlertLevel, number> = { advisory: 1, warning: 2, emergency: 3 };

export function levelRank(level: AlertLevel): number {
  return LEVEL_RANK[level];
}

/** Highest-level alert (optionally of one hazard type), or null. */
export function mostSevere(alerts: Alert[], type?: HazardType): Alert | null {
  let best: Alert | null = null;
  for (const a of alerts) {
    if (type && a.type !== type) continue;
    if (!best || LEVEL_RANK[a.level] > LEVEL_RANK[best.level]) best = a;
  }
  return best;
}

/** Active hazard types in display order (earthquake first), e.g. for "EARTHQUAKE + TSUNAMI". */
export function activeHazards(state: AppState): HazardType[] {
  const order: HazardType[] = ['earthquake', 'tsunami'];
  return order.filter((t) => state.alerts.some((a) => a.type === t));
}

/**
 * Does this alert require evacuation to high ground?
 * Tsunami warning / major warning: always. Tsunami advisory: only when inside the coastal hazard zone.
 */
export function requiresEvacuation(alert: Alert, inHazardZone = true): boolean {
  if (alert.type !== 'tsunami') return false;
  if (alert.level === 'advisory') return inHazardZone;
  return true;
}

/** Most severe alert that requires evacuation, or null. */
export function evacuationAlert(state: AppState, inHazardZone = true): Alert | null {
  return mostSevere(state.alerts.filter((a) => requiresEvacuation(a, inHazardZone)));
}

/**
 * Hazard-zone flag used for tsunami advisories, latched once evacuation has started:
 * - while guideStep is 'nav' the user keeps evacuating even after walking out of the zone, so an
 *   advisory does not flip the mode to `normal` mid-route (S04 -> H00). Arrival still leads to S06.
 * - on high ground, or after a warning / major warning was announced in this event, a downgrade to an
 *   advisory does not loosen guidance either (F8A): only lifting every alert ends it.
 */
export function advisoryZone(state: AppState, inHazardZone = true): boolean {
  const peakedAboveAdvisory = state.peakTsunamiLevel !== null && LEVEL_RANK[state.peakTsunamiLevel] >= LEVEL_RANK.warning;
  return inHazardZone || state.guideStep === 'nav' || state.onHighGround || peakedAboveAdvisory;
}

/**
 * An evacuation-requiring alert became active, or got more severe, between `prev` and `next`
 * (e.g. added from the demo panel). Used by the store to close sub screens so guidance is shown.
 */
export function evacuationEscalated(prev: AppState, next: AppState): boolean {
  const after = evacuationAlert(next);
  if (!after) return false;
  const before = evacuationAlert(prev);
  return !before || LEVEL_RANK[after.level] > LEVEL_RANK[before.level];
}

/** GPS too poor (> 100 m) or denied. Ignores manualPin. */
export function isLocationUncertain(state: AppState): boolean {
  return state.gps.permission === 'denied' || state.gps.accuracyM > LOCATE_ACCURACY_THRESHOLD_M;
}

/**
 * The location is only approximate (or missing) and no pin was set (FB4, F90 / F92 / F94).
 * Guidance does NOT switch to the pin screen: evacuation shows the action guide (S03 / S05) with
 * "Follow the blue evacuation signs" and a small "Set location" button instead of route arrows.
 */
export function isLocationApproximate(state: AppState): boolean {
  return isLocationUncertain(state) && !state.manualPin;
}

/**
 * Guidance mode (requirements 7.1).
 * - shake: the current location is shaking (priority 1 in 7.2; does not require an earthquake alert so the
 *   demo "shaking" toggle always works)
 * - safe: evacuation-requiring alert and on high ground. When the margin check (F85) says "not enough",
 *   useAlertEffects clears onHighGround (-> evacuate, "Go higher. NOW").
 * - evacuate: evacuation-requiring alert
 * - normal: otherwise (advisory-only alerts are shown on H00)
 * The former `locate` mode (auto S07) was removed by FB4 (F90): see resolveScreen / isLocationApproximate.
 * `inHazardZone` (from T1's town data) only matters for tsunami advisories. Default true.
 * It is latched while evacuating (see advisoryZone).
 */
export function deriveMode(state: AppState, inHazardZone = true): Mode {
  if (state.shaking) return 'shake';
  const evac = evacuationAlert(state, advisoryZone(state, inHazardZone));
  if (!evac) return 'normal';
  if (state.onHighGround) return 'safe';
  return 'evacuate';
}

/** AR may be entered at all: online, camera permission, supported device (6.4.1 condition 2). */
export function canEnterAr(state: AppState): boolean {
  return state.online && state.ar.cameraPermission && state.ar.supported;
}

/** Tracking quality OK: position error <= 20 m, heading error <= 15 deg, tracking (6.4.1 condition 3). */
export function arTrackingOk(state: AppState): boolean {
  return (
    state.gps.accuracyM <= AR_MAX_POSITION_ERROR_M &&
    state.ar.headingAccuracyDeg <= AR_MAX_HEADING_ERROR_DEG &&
    state.ar.tracking
  );
}

/**
 * All AR conditions (requirements 6.4.1): device raised, online + camera + supported,
 * accuracy/heading/tracking OK, next segment passability verified.
 * `nextSegmentVerified` comes from T1's navigation; defaults to `state.online`.
 */
export function isArAvailable(state: AppState, nextSegmentVerified: boolean = state.online): boolean {
  return state.deviceRaised && canEnterAr(state) && arTrackingOk(state) && nextSegmentVerified;
}

/**
 * Screen to show (implementation-plan 3.2).
 * 1. lockScreen -> S01   2. top of overlay
 * 3. location permission not asked yet when route guidance starts -> A01 (F24; "Allow" -> S04,
 *    "Choose on map" -> S07 on the overlay stack)
 * 4. by mode. While the location is approximate (FB4) evacuation stays on the action guide S03 / S05
 *    (with the signs hint) even when guideStep is 'nav', and returns to S04 once the location is good.
 */
export function resolveScreen(
  state: AppState,
  nextSegmentVerified: boolean = state.online,
  inHazardZone = true,
): ScreenId {
  if (state.lockScreen) return 'S01';
  if (state.overlay.length > 0) return state.overlay[state.overlay.length - 1];
  const mode = deriveMode(state, inHazardZone);
  if (mode === 'evacuate' && state.guideStep === 'nav' && state.gps.permission === 'prompt') {
    return 'A01';
  }
  switch (mode) {
    case 'normal':
      return 'H00';
    case 'shake':
      return 'S02';
    case 'safe':
      return 'S06';
    case 'evacuate': {
      const actionGuide = state.guideStep === 'action' || isLocationApproximate(state);
      if (!state.online) return actionGuide ? 'S05' : 'S08';
      if (actionGuide) return 'S03';
      if (isArAvailable(state, nextSegmentVerified)) return 'S11';
      // Raised but quality (accuracy / heading / tracking / passability) not met -> S12.
      // Offline / no camera / unsupported never enter S11/S12.
      if (state.deviceRaised && canEnterAr(state)) return 'S12';
      return 'S04';
    }
  }
}

// ---------------------------------------------------------------------------
// Priority (requirements 7.2)

export type PriorityKind = 'protect' | 'goUphillNow' | 'goUphill' | 'stayHere' | 'checkInfo' | 'none';

export interface PriorityAction {
  /** 1 (most urgent) .. 5; 6 = nothing to do */
  rank: 1 | 2 | 3 | 4 | 5 | 6;
  kind: PriorityKind;
  /** The alert that triggered it (most severe of that rank), if any */
  alert: Alert | null;
}

/**
 * The single action to show now (7.2). Ties go to the higher alert level.
 * 1 protect (shaking; screen picks pictogram by state.eqSituation)
 * 2 goUphillNow (tsunami warning / major warning, not on high ground)
 * 3 goUphill (tsunami advisory, inside hazard zone, not on high ground)
 * 4 stayHere (evacuation alert continues, on high ground)
 * 5 checkInfo (any other alert)
 */
export function topPriorityAction(state: AppState, inHazardZone = true): PriorityAction {
  inHazardZone = advisoryZone(state, inHazardZone);
  if (state.shaking) {
    return { rank: 1, kind: 'protect', alert: mostSevere(state.alerts, 'earthquake') };
  }
  const tsunamiWarnings = state.alerts.filter(
    (a) => a.type === 'tsunami' && (a.level === 'warning' || a.level === 'emergency'),
  );
  if (!state.onHighGround && tsunamiWarnings.length > 0) {
    return { rank: 2, kind: 'goUphillNow', alert: mostSevere(tsunamiWarnings) };
  }
  const advisories = state.alerts.filter((a) => a.type === 'tsunami' && a.level === 'advisory');
  if (!state.onHighGround && inHazardZone && advisories.length > 0) {
    return { rank: 3, kind: 'goUphill', alert: mostSevere(advisories) };
  }
  const evac = evacuationAlert(state, inHazardZone);
  if (state.onHighGround && evac) {
    return { rank: 4, kind: 'stayHere', alert: evac };
  }
  if (state.alerts.length > 0) {
    return { rank: 5, kind: 'checkInfo', alert: mostSevere(state.alerts) };
  }
  return { rank: 6, kind: 'none', alert: null };
}

// ---------------------------------------------------------------------------
// Freshness (requirements 7.3)

export interface Freshness {
  /** Offline, or more than staleThresholdMin since lastFetchAt -> show "Last alert HH:MM JST • Stale" */
  stale: boolean;
  /** Minutes since last fetch */
  ageMin: number;
  /** Latest issuedAt among active alerts (null if none) — the time shown in "JMA • 09:40 JST" */
  lastAlertAt: number | null;
  /** false when offline -> "Route unverified" */
  routeVerified: boolean;
  /** false when offline -> "Live road status unavailable" */
  liveRoadStatus: boolean;
  /** Time shown in "Passability checked HH:MM JST" (online only) */
  passabilityCheckedAt: number | null;
}

export function freshness(state: AppState): Freshness {
  const ageMs = Math.max(0, state.now - state.lastFetchAt);
  const ageMin = ageMs / MINUTE_MS;
  const stale = !state.online || ageMin > state.staleThresholdMin;
  const lastAlertAt = state.alerts.length > 0 ? Math.max(...state.alerts.map((a) => a.issuedAt)) : null;
  return {
    stale,
    ageMin,
    lastAlertAt,
    routeVerified: state.online,
    liveRoadStatus: state.online,
    passabilityCheckedAt: state.online ? state.lastFetchAt : null,
  };
}
