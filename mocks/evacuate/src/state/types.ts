// State and data types shared by all tasks (implementation-plan.md 3.1).
// Field list matches the plan, plus `feedPaused` (added in the review fixes, R1).

export type Lang = 'en' | 'ja' | 'zh-Hans' | 'ko' | 'ar';
/** Multilingual text */
export type L10n = Record<Lang, string>;
export type HazardType = 'earthquake' | 'tsunami';
/** advisory = 注意報, warning = 警報, emergency = 特別警報 (major tsunami warning) */
export type AlertLevel = 'advisory' | 'warning' | 'emergency';

/**
 * Expected tsunami height (F84). JMA categories: 1 / 3 / 5 / 10 m, `over10` = "10 m 超" (more than 10 m).
 * The first bulletin may only say `huge` (巨大, major warning) or `high` (高い, warning).
 * For the margin check, `huge` counts as more than 10 m and `high` as 3 m (requirements 14.3).
 */
export type ExpectedHeight = 1 | 3 | 5 | 10 | 'over10' | 'huge' | 'high';

export interface Alert {
  id: string;
  type: HazardType;
  level: AlertLevel;
  area: L10n;
  /** epoch ms */
  issuedAt: number;
  source: 'JMA';
  /** Tsunami only (F84) */
  expectedHeight?: ExpectedHeight;
  /** Live alerts only (H2): expected arrival time as announced (ISO 8601 with +09:00), or the condition text instead. */
  arrivalTime?: string;
  arrivalCondition?: string;
}

/** A tsunami alert was upgraded, its expected height raised, or it was downgraded (F88 / F89 / F8A). */
export interface AlertChange {
  kind: 'upgrade' | 'raise' | 'downgrade';
  /** Level and expected height after the change */
  level: AlertLevel;
  expectedHeight: ExpectedHeight | null;
  /** epoch ms (virtual clock) */
  at: number;
}

export type EqSituation = 'indoors' | 'outdoors' | 'car';

/** Town coordinates in meters. Origin top-left, x = east, y = south. */
export interface Point {
  x: number;
  y: number;
}

export type ScreenId =
  | 'S01' | 'S02' | 'S03' | 'S04' | 'S05' | 'S06' | 'S07' | 'S08' | 'S09' | 'S10' | 'S11' | 'S12'
  | 'H00' | 'A01' | 'A02' | 'A03' | 'A04';

export interface GpsState {
  permission: 'granted' | 'denied' | 'prompt';
  accuracyM: number;
  position: Point;
}

export interface WalkState {
  playing: boolean;
  /** Speed multiplier. 1 = WALK_BASE_MPS (1.5 m/s). */
  speed: number;
  /** Distance walked along the current route, in meters. Advanced by `tick`. */
  progressM: number;
}

export interface ArState {
  cameraPermission: boolean;
  supported: boolean;
  headingAccuracyDeg: number;
  tracking: boolean;
  landmarkFound: boolean;
  showDetection: boolean;
}

export interface AppState {
  lang: Lang;
  /** Virtual clock (epoch ms). Starts at 2026-11-08 09:41 JST. */
  now: number;
  online: boolean;
  /** Last successful fetch of alerts / road status (epoch ms). */
  lastFetchAt: number;
  /**
   * Demo: alert / road-status updates are failing (paused). While true, `tick` stops refreshing
   * lastFetchAt even when online, so "Stale" can be shown online (requirements 7.3).
   */
  feedPaused: boolean;
  /** Minutes after which info is stale (default 10). */
  staleThresholdMin: number;
  alerts: Alert[];
  shaking: boolean;
  eqSituation: EqSituation;
  gps: GpsState;
  /** Pin confirmed on S07 */
  manualPin: Point | null;
  /** Pressed "On high ground" or arrived */
  onHighGround: boolean;
  /**
   * Sent on again from a waiting place (F85 / F88): 'now' = the margin is not enough ("Go higher. NOW"),
   * 'calm' = the margin is small and the user chose to move ("Go higher."). Cleared on arrival / all clear.
   */
  goHigher: 'now' | 'calm' | null;
  /** Margin check: "ample" when elevation - expected height >= this (m). Default 10 (decision 14.7-2). */
  marginAmpleM: number;
  /** Margin check: with a forecast over 10 m, below this elevation is "not enough" (m). Default 20. */
  hugeMinElevM: number;
  /**
   * Highest tsunami level / expected height announced since the tsunami alert began. A downgrade does not
   * loosen guidance (F8A), so the margin check and the destination use these. Reset when all alerts are lifted.
   */
  peakTsunamiLevel: AlertLevel | null;
  peakExpectedHeight: ExpectedHeight | null;
  /** Last upgrade / raise / downgrade, shown as the band at the top (F88). null = no band. */
  alertChange: AlertChange | null;
  /** S03 (action) or S04 (nav) */
  guideStep: 'action' | 'nav';
  walk: WalkState;
  screenOff: boolean;
  deviceRaised: boolean;
  ar: ArState;
  dialerEnabled: boolean;
  /** Read the instruction aloud when a guidance screen appears (S01-S03, S05, S06). Default true. */
  autoSpeak: boolean;
  /** Showing S01 lock-screen notification */
  lockScreen: boolean;
  /** Stack of manually opened sub screens (language, emergency, map, details...) */
  overlay: ScreenId[];
  scenarioId: string;
  /** Incremented by every scenario load / reset (also a reload of the same scenario). Resets one-shot effects. */
  scenarioRun: number;
  toast: string | null;
}

/**
 * Patch shape for the `patch` action. Top-level keys replace; the nested objects
 * `gps`, `walk` and `ar` are shallow-merged (so `{ gps: { accuracyM: 180 } }` works).
 */
export type StatePatch = Partial<Omit<AppState, 'gps' | 'walk' | 'ar'>> & {
  gps?: Partial<GpsState>;
  walk?: Partial<WalkState>;
  ar?: Partial<ArState>;
};
