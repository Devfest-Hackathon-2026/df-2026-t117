// Demo scenarios (requirements.md section 8). T4 refines these later.
import type { AppState, Lang, Point, StatePatch } from './types';
import { MAIN_ALERTS } from '../data/alerts';
import { DEMO_START_MS } from './time';
import { mostSevere } from './derive';

/** Default virtual position: inside the coastal hazard zone (T1 may adjust to match town.ts). */
export const START_POSITION: Point = { x: 140, y: 330 };

/** Scenario 5: waiting on Hill Road outside the hazard zone, elevation about 16 m (not a designated site). */
export const SCENARIO5_POSITION: Point = { x: 310, y: 283 };

export interface Scenario {
  id: string;
  /** Short label for the demo panel */
  label: string;
  /** One-line flow description (Japanese, for the presenter) */
  description: string;
  /** Applied on top of the base state */
  patch: StatePatch;
}

/** Neutral base state (no alerts, everything healthy). */
export function createBaseState(lang: Lang): AppState {
  return {
    lang,
    now: DEMO_START_MS,
    online: true,
    lastFetchAt: DEMO_START_MS,
    feedPaused: false,
    staleThresholdMin: 10,
    alerts: [],
    shaking: false,
    eqSituation: 'indoors',
    gps: { permission: 'granted', accuracyM: 10, position: { ...START_POSITION } },
    manualPin: null,
    onHighGround: false,
    goHigher: null,
    marginAmpleM: 10,
    hugeMinElevM: 20,
    peakTsunamiLevel: null,
    peakExpectedHeight: null,
    alertChange: null,
    guideStep: 'action',
    walk: { playing: false, speed: 1, progressM: 0 },
    screenOff: false,
    deviceRaised: false,
    ar: {
      cameraPermission: true,
      supported: true,
      headingAccuracyDeg: 8,
      tracking: true,
      landmarkFound: true,
      showDetection: false,
    },
    dialerEnabled: false,
    autoSpeak: true,
    lockScreen: false,
    overlay: [],
    scenarioId: '4',
    scenarioRun: 0,
    toast: null,
  };
}

export const SCENARIOS: Scenario[] = [
  {
    id: '1',
    label: '1. Earthquake + Tsunami (main)',
    description: 'S01 通知 → S02 → Shaking stopped → S03 → S04（歩行） → S06',
    patch: {
      alerts: MAIN_ALERTS,
      shaking: true,
      eqSituation: 'indoors',
      lockScreen: true,
      guideStep: 'action',
    },
  },
  {
    id: '2',
    label: '2. Offline',
    description: 'S03 から開始 → パネルで「オフライン」→ S05 → Evacuation map で S08 → 歩行 → S06',
    patch: {
      alerts: MAIN_ALERTS,
      shaking: false,
      guideStep: 'action',
      online: true,
      walk: { playing: false, speed: 1, progressM: 0 },
    },
  },
  {
    id: '3',
    label: '3. GPS uncertain',
    description:
      'S04 から開始 → 歩行を再生 → パネルで精度スライダを ±180 m → S03＋「青い標識に従う」（ピン設定には切り替わらない） → そのまま高台に着く（S06）。Set location でのピン設定は任意',
    patch: {
      alerts: MAIN_ALERTS,
      shaking: false,
      guideStep: 'nav',
      gps: { permission: 'granted', accuracyM: 12 },
      walk: { playing: false, speed: 1, progressM: 0 },
    },
  },
  {
    id: '3b',
    label: '3b. AR',
    description: 'S04 から開始 → 「端末を持ち上げる」→ S11（目印を認識） → 方位精度を 30° に → S12 → Set location → S07',
    patch: {
      alerts: MAIN_ALERTS,
      shaking: false,
      guideStep: 'nav',
      gps: { accuracyM: 8 },
      deviceRaised: false,
      ar: {
        cameraPermission: true,
        supported: true,
        headingAccuracyDeg: 8,
        tracking: true,
        landmarkFound: true,
        showDetection: true,
      },
    },
  },
  {
    id: '5',
    label: '5. Upgrade',
    description:
      'S06（標高 約 16 m で待機・津波警報 3 m）→ パネルで「格上げする」→ 大津波警報（巨大）で余裕が「足りない」→ S03 Go higher. NOW → 避難先へ（S04 → S06）',
    patch: {
      alerts: MAIN_ALERTS,
      shaking: false,
      guideStep: 'action',
      onHighGround: true,
      gps: { permission: 'granted', accuracyM: 10, position: { ...SCENARIO5_POSITION } },
      walk: { playing: false, speed: 1, progressM: 0 },
    },
  },
  {
    id: '4',
    label: '4. Normal (no alerts)',
    description: 'H00 → 災害種別ガイド・コラム・言語・緊急通報',
    patch: {
      alerts: [],
      shaking: false,
    },
  },
];

export const DEFAULT_SCENARIO_ID = '1';

/** Apply a StatePatch to a state (top-level replace, gps/walk/ar shallow-merged). */
export function applyPatch(state: AppState, patch: StatePatch): AppState {
  const { gps, walk, ar, ...rest } = patch;
  return {
    ...state,
    ...rest,
    gps: gps ? { ...state.gps, ...gps } : state.gps,
    walk: walk ? { ...state.walk, ...walk } : state.walk,
    ar: ar ? { ...state.ar, ...ar } : state.ar,
  };
}

/** Full initial state for a scenario. Unknown ids fall back to the default scenario. */
export function buildScenarioState(id: string, lang: Lang): AppState {
  const scenario = SCENARIOS.find((s) => s.id === id) ?? SCENARIOS.find((s) => s.id === DEFAULT_SCENARIO_ID)!;
  const state = applyPatch(createBaseState(lang), scenario.patch);
  // The scenario's tsunami alert is the first announcement: it sets the peaks (F8A) without a band.
  const tsunami = mostSevere(state.alerts, 'tsunami');
  return {
    ...state,
    peakTsunamiLevel: tsunami?.level ?? null,
    peakExpectedHeight: tsunami?.expectedHeight ?? null,
    scenarioId: scenario.id,
  };
}
