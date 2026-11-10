// Demo scenarios (requirements.md section 8). Port of mocks/evacuate/src/state/scenarios.ts.
import '../data/alerts.dart';
import 'action_rules.dart';
import 'derive.dart';
import 'time.dart';
import 'types.dart';

/// Default virtual position: inside the coastal hazard zone.
const Point startPosition = Point(140, 330);

/// Scenario 5: waiting on Hill Road outside the hazard zone, elevation about 16 m (not a designated site).
const Point scenario5Position = Point(310, 283);

class Scenario {
  const Scenario({required this.id, required this.label, required this.description, required this.patch});

  final String id;

  /// Short label for the demo panel.
  final String label;

  /// One-line flow description (Japanese, for the presenter).
  final String description;

  /// Applied on top of the base state.
  final StatePatch patch;
}

/// Neutral base state (no alerts, everything healthy). The thresholds come from [rules] (Remote Config).
AppState createBaseState(Lang lang, [ActionRules rules = ActionRules.defaults]) => AppState(
      lang: lang,
      now: demoStartMs,
      online: true,
      lastFetchAt: demoStartMs,
      feedPaused: false,
      staleThresholdMin: rules.staleThresholdMin,
      alerts: const [],
      shaking: false,
      eqSituation: EqSituation.indoors,
      gps: const GpsState(permission: GpsPermission.granted, accuracyM: 10, position: startPosition),
      manualPin: null,
      onHighGround: false,
      goHigher: null,
      marginAmpleM: rules.marginAmpleM,
      hugeMinElevM: rules.hugeMinElevM,
      peakTsunamiLevel: null,
      peakExpectedHeight: null,
      alertChange: null,
      guideStep: GuideStep.action,
      walk: const WalkState(playing: false, speed: 1, progressM: 0),
      screenOff: false,
      deviceRaised: false,
      ar: const ArState(
        cameraPermission: true,
        supported: true,
        headingAccuracyDeg: 8,
        tracking: true,
        landmarkFound: true,
        showDetection: false,
      ),
      dialerEnabled: false,
      autoSpeak: true,
      lockScreen: false,
      overlay: const [],
      scenarioId: '4',
      scenarioRun: 0,
      toast: null,
    );

const _walkReset = WalkPatch(playing: false, speed: 1, progressM: 0);

final List<Scenario> scenarios = [
  Scenario(
    id: '1',
    label: '1. Earthquake + Tsunami (main)',
    description: 'S01 通知 → S02 → Shaking stopped → S03 → S04（歩行） → S06',
    patch: StatePatch(
      alerts: mainAlerts,
      shaking: true,
      eqSituation: EqSituation.indoors,
      lockScreen: true,
      guideStep: GuideStep.action,
    ),
  ),
  Scenario(
    id: '2',
    label: '2. Offline',
    description: 'S03 から開始 → パネルで「オフライン」→ S05 → Evacuation map で S08 → 歩行 → S06',
    patch: StatePatch(
      alerts: mainAlerts,
      shaking: false,
      guideStep: GuideStep.action,
      online: true,
      walk: _walkReset,
    ),
  ),
  Scenario(
    id: '3',
    label: '3. GPS uncertain',
    description:
        'S04 から開始 → 歩行を再生 → パネルで精度スライダを ±180 m → S03＋「青い標識に従う」（ピン設定には切り替わらない） → そのまま高台に着く（S06）。Set location でのピン設定は任意',
    patch: StatePatch(
      alerts: mainAlerts,
      shaking: false,
      guideStep: GuideStep.nav,
      gps: const GpsPatch(permission: GpsPermission.granted, accuracyM: 12),
      walk: _walkReset,
    ),
  ),
  Scenario(
    id: '3b',
    label: '3b. AR',
    description: 'S04 から開始 → 「端末を持ち上げる」→ S11（目印を認識） → 方位精度を 30° に → S12 → Set location → S07',
    patch: StatePatch(
      alerts: mainAlerts,
      shaking: false,
      guideStep: GuideStep.nav,
      gps: const GpsPatch(accuracyM: 8),
      deviceRaised: false,
      ar: const ArPatch(
        cameraPermission: true,
        supported: true,
        headingAccuracyDeg: 8,
        tracking: true,
        landmarkFound: true,
        showDetection: true,
      ),
    ),
  ),
  Scenario(
    id: '5',
    label: '5. Upgrade',
    description:
        'S06（標高 約 16 m で待機・津波警報 3 m）→ パネルで「格上げする」→ 大津波警報（巨大）で余裕が「足りない」→ S03 Go higher. NOW → 避難先へ（S04 → S06）',
    patch: StatePatch(
      alerts: mainAlerts,
      shaking: false,
      guideStep: GuideStep.action,
      onHighGround: true,
      gps: const GpsPatch(permission: GpsPermission.granted, accuracyM: 10, position: scenario5Position),
      walk: _walkReset,
    ),
  ),
  const Scenario(
    id: '4',
    label: '4. Normal (no alerts)',
    description: 'H00 → 災害種別ガイド・コラム・言語・緊急通報',
    patch: StatePatch(alerts: [], shaking: false),
  ),
];

const String defaultScenarioId = '1';

/// Apply a [StatePatch] to a state (top-level replace, gps/walk/ar merged field by field).
AppState applyPatch(AppState state, StatePatch p) {
  final gps = p.gps;
  final walk = p.walk;
  final ar = p.ar;
  return state.copyWith(
    lang: p.lang,
    now: p.now,
    online: p.online,
    lastFetchAt: p.lastFetchAt,
    feedPaused: p.feedPaused,
    staleThresholdMin: p.staleThresholdMin,
    alerts: p.alerts,
    shaking: p.shaking,
    eqSituation: p.eqSituation,
    gps: gps == null ? null : state.gps.apply(gps),
    manualPin: p.manualPin,
    clearManualPin: p.clearManualPin,
    onHighGround: p.onHighGround,
    goHigher: p.goHigher,
    clearGoHigher: p.clearGoHigher,
    marginAmpleM: p.marginAmpleM,
    hugeMinElevM: p.hugeMinElevM,
    alertChange: p.alertChange,
    clearAlertChange: p.clearAlertChange,
    guideStep: p.guideStep,
    walk: walk == null ? null : state.walk.apply(walk),
    screenOff: p.screenOff,
    deviceRaised: p.deviceRaised,
    ar: ar == null ? null : state.ar.apply(ar),
    dialerEnabled: p.dialerEnabled,
    autoSpeak: p.autoSpeak,
    lockScreen: p.lockScreen,
    overlay: p.overlay,
  );
}

/// Full initial state for a scenario. Unknown ids fall back to the default scenario.
AppState buildScenarioState(String id, Lang lang, [ActionRules rules = ActionRules.defaults]) {
  final scenario = scenarios.firstWhere(
    (s) => s.id == id,
    orElse: () => scenarios.firstWhere((s) => s.id == defaultScenarioId),
  );
  final state = applyPatch(createBaseState(lang, rules), scenario.patch);
  // The scenario's tsunami alert is the first announcement: it sets the peaks (F8A) without a band.
  final tsunami = mostSevere(state.alerts, HazardType.tsunami);
  return state.copyWith(
    peakTsunamiLevel: tsunami?.level,
    peakExpectedHeight: tsunami?.expectedHeight,
    scenarioId: scenario.id,
  );
}
