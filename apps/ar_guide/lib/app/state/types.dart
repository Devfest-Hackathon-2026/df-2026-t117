// State and data types shared by the whole app. Port of mocks/evacuate/src/state/types.ts.
// `Lang` is the same enum the AR screen already uses (lib/src/guide_params.dart).
import '../../src/guide_params.dart' show Lang;

export '../../src/guide_params.dart' show Lang;

/// Multilingual text.
class L10n {
  const L10n({required this.en, required this.ja, required this.zhHans, required this.ko, required this.ar});

  final String en;
  final String ja;
  final String zhHans;
  final String ko;
  final String ar;

  String operator [](Lang lang) => switch (lang) {
        Lang.en => en,
        Lang.ja => ja,
        Lang.zhHans => zhHans,
        Lang.ko => ko,
        Lang.ar => ar,
      };
}

enum HazardType { earthquake, tsunami }

/// advisory = 注意報, warning = 警報, emergency = 特別警報 (major tsunami warning).
enum AlertLevel { advisory, warning, emergency }

/// Expected tsunami height (F84). JMA categories: 1 / 3 / 5 / 10 m, [over10] = "10 m 超".
/// The first bulletin may only say [huge] (巨大, major warning) or [high] (高い, warning).
/// For the margin check, [huge] counts as more than 10 m and [high] as 3 m (requirements 14.3).
enum ExpectedHeight { m1, m3, m5, m10, over10, huge, high }

class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.level,
    required this.area,
    required this.issuedAt,
    this.source = 'JMA',
    this.expectedHeight,
    this.arrivalTime,
    this.arrivalCondition,
  });

  final String id;
  final HazardType type;
  final AlertLevel level;
  final L10n area;

  /// epoch ms
  final int issuedAt;
  final String source;

  /// Tsunami only (F84).
  final ExpectedHeight? expectedHeight;

  /// Live alerts only: expected arrival time as announced (ISO 8601 with +09:00), or the condition text instead.
  final String? arrivalTime;
  final String? arrivalCondition;

  /// To drop an optional field, build the [Alert] directly.
  Alert copyWith({
    String? id,
    AlertLevel? level,
    int? issuedAt,
    ExpectedHeight? expectedHeight,
    String? arrivalTime,
    String? arrivalCondition,
  }) =>
      Alert(
        id: id ?? this.id,
        type: type,
        level: level ?? this.level,
        area: area,
        issuedAt: issuedAt ?? this.issuedAt,
        source: source,
        expectedHeight: expectedHeight ?? this.expectedHeight,
        arrivalTime: arrivalTime ?? this.arrivalTime,
        arrivalCondition: arrivalCondition ?? this.arrivalCondition,
      );
}

enum AlertChangeKind { upgrade, raise, downgrade }

/// A tsunami alert was upgraded, its expected height raised, or it was downgraded (F88 / F89 / F8A).
class AlertChange {
  const AlertChange({required this.kind, required this.level, required this.expectedHeight, required this.at});

  final AlertChangeKind kind;

  /// Level and expected height after the change.
  final AlertLevel level;
  final ExpectedHeight? expectedHeight;

  /// epoch ms (virtual clock)
  final int at;
}

enum EqSituation { indoors, outdoors, car }

/// Town coordinates in meters. Origin top-left, x = east, y = south.
class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

enum ScreenId {
  s01,
  s02,
  s03,
  s04,
  s05,
  s06,
  s07,
  s08,
  s09,
  s10,
  s11,
  s12,
  h00,
  a01,
  a02,
  a03,
  a04;

  /// "S01", "H00", ... as in the requirements.
  String get label => name.toUpperCase();
}

enum GpsPermission { granted, denied, prompt }

class GpsState {
  const GpsState({required this.permission, required this.accuracyM, required this.position});

  final GpsPermission permission;
  final double accuracyM;
  final Point position;

  GpsState apply(GpsPatch p) => GpsState(
        permission: p.permission ?? permission,
        accuracyM: p.accuracyM ?? accuracyM,
        position: p.position ?? position,
      );
}

class WalkState {
  const WalkState({required this.playing, required this.speed, required this.progressM});

  final bool playing;

  /// Speed multiplier. 1 = walkBaseMps (1.5 m/s).
  final double speed;

  /// Distance walked along the current route, in meters. Advanced by `tick`.
  final double progressM;

  WalkState apply(WalkPatch p) => WalkState(
        playing: p.playing ?? playing,
        speed: p.speed ?? speed,
        progressM: p.progressM ?? progressM,
      );
}

class ArState {
  const ArState({
    required this.cameraPermission,
    required this.supported,
    required this.headingAccuracyDeg,
    required this.tracking,
    required this.landmarkFound,
    required this.showDetection,
  });

  final bool cameraPermission;
  final bool supported;
  final double headingAccuracyDeg;
  final bool tracking;
  final bool landmarkFound;
  final bool showDetection;

  ArState apply(ArPatch p) => ArState(
        cameraPermission: p.cameraPermission ?? cameraPermission,
        supported: p.supported ?? supported,
        headingAccuracyDeg: p.headingAccuracyDeg ?? headingAccuracyDeg,
        tracking: p.tracking ?? tracking,
        landmarkFound: p.landmarkFound ?? landmarkFound,
        showDetection: p.showDetection ?? showDetection,
      );
}

/// Sent on again from a waiting place (F85 / F88): [now] = the margin is not enough ("Go higher. NOW"),
/// [calm] = the margin is small and the user chose to move ("Go higher.").
enum GoHigher { now, calm }

enum GuideStep { action, nav }

class AppState {
  const AppState({
    required this.lang,
    required this.now,
    required this.online,
    required this.lastFetchAt,
    required this.feedPaused,
    required this.staleThresholdMin,
    required this.alerts,
    required this.shaking,
    required this.eqSituation,
    required this.gps,
    required this.manualPin,
    required this.onHighGround,
    required this.goHigher,
    required this.marginAmpleM,
    required this.hugeMinElevM,
    required this.peakTsunamiLevel,
    required this.peakExpectedHeight,
    required this.alertChange,
    required this.guideStep,
    required this.walk,
    required this.screenOff,
    required this.deviceRaised,
    required this.ar,
    required this.dialerEnabled,
    required this.autoSpeak,
    required this.lockScreen,
    required this.overlay,
    required this.scenarioId,
    required this.scenarioRun,
    required this.toast,
  });

  final Lang lang;

  /// Virtual clock (epoch ms). Starts at 2026-11-08 09:41 JST.
  final int now;
  final bool online;

  /// Last successful fetch of alerts / road status (epoch ms).
  final int lastFetchAt;

  /// Demo: alert / road-status updates are failing. While true, `tick` stops refreshing [lastFetchAt]
  /// even when online, so "Stale" can be shown online (requirements 7.3).
  final bool feedPaused;

  /// Minutes after which info is stale (default 10).
  final double staleThresholdMin;
  final List<Alert> alerts;
  final bool shaking;
  final EqSituation eqSituation;
  final GpsState gps;

  /// Pin confirmed on S07.
  final Point? manualPin;

  /// Pressed "On high ground" or arrived.
  final bool onHighGround;

  /// Cleared on arrival / all clear.
  final GoHigher? goHigher;

  /// Margin check: "ample" when elevation - expected height >= this (m). Default 10 (decision 14.7-2).
  final double marginAmpleM;

  /// Margin check: with a forecast over 10 m, below this elevation is "not enough" (m). Default 20.
  final double hugeMinElevM;

  /// Highest tsunami level / expected height announced since the tsunami alert began. A downgrade does not
  /// loosen guidance (F8A), so the margin check and the destination use these. Reset when all alerts are lifted.
  final AlertLevel? peakTsunamiLevel;
  final ExpectedHeight? peakExpectedHeight;

  /// Last upgrade / raise / downgrade, shown as the band at the top (F88). null = no band.
  final AlertChange? alertChange;

  /// S03 (action) or S04 (nav).
  final GuideStep guideStep;
  final WalkState walk;
  final bool screenOff;
  final bool deviceRaised;
  final ArState ar;
  final bool dialerEnabled;

  /// Read the instruction aloud when a guidance screen appears (S01-S03, S05, S06). Default true.
  final bool autoSpeak;

  /// Showing S01 lock-screen notification.
  final bool lockScreen;

  /// Stack of manually opened sub screens (language, emergency, map, details...).
  final List<ScreenId> overlay;
  final String scenarioId;

  /// Incremented by every scenario load / reset (also a reload of the same scenario). Resets one-shot effects.
  final int scenarioRun;
  final String? toast;

  /// A nullable field is set to null with its `clear...` flag.
  AppState copyWith({
    Lang? lang,
    int? now,
    bool? online,
    int? lastFetchAt,
    bool? feedPaused,
    double? staleThresholdMin,
    List<Alert>? alerts,
    bool? shaking,
    EqSituation? eqSituation,
    GpsState? gps,
    Point? manualPin,
    bool clearManualPin = false,
    bool? onHighGround,
    GoHigher? goHigher,
    bool clearGoHigher = false,
    double? marginAmpleM,
    double? hugeMinElevM,
    AlertLevel? peakTsunamiLevel,
    bool clearPeakTsunamiLevel = false,
    ExpectedHeight? peakExpectedHeight,
    bool clearPeakExpectedHeight = false,
    AlertChange? alertChange,
    bool clearAlertChange = false,
    GuideStep? guideStep,
    WalkState? walk,
    bool? screenOff,
    bool? deviceRaised,
    ArState? ar,
    bool? dialerEnabled,
    bool? autoSpeak,
    bool? lockScreen,
    List<ScreenId>? overlay,
    String? scenarioId,
    int? scenarioRun,
    String? toast,
    bool clearToast = false,
  }) =>
      AppState(
        lang: lang ?? this.lang,
        now: now ?? this.now,
        online: online ?? this.online,
        lastFetchAt: lastFetchAt ?? this.lastFetchAt,
        feedPaused: feedPaused ?? this.feedPaused,
        staleThresholdMin: staleThresholdMin ?? this.staleThresholdMin,
        alerts: alerts ?? this.alerts,
        shaking: shaking ?? this.shaking,
        eqSituation: eqSituation ?? this.eqSituation,
        gps: gps ?? this.gps,
        manualPin: clearManualPin ? null : manualPin ?? this.manualPin,
        onHighGround: onHighGround ?? this.onHighGround,
        goHigher: clearGoHigher ? null : goHigher ?? this.goHigher,
        marginAmpleM: marginAmpleM ?? this.marginAmpleM,
        hugeMinElevM: hugeMinElevM ?? this.hugeMinElevM,
        peakTsunamiLevel: clearPeakTsunamiLevel ? null : peakTsunamiLevel ?? this.peakTsunamiLevel,
        peakExpectedHeight: clearPeakExpectedHeight ? null : peakExpectedHeight ?? this.peakExpectedHeight,
        alertChange: clearAlertChange ? null : alertChange ?? this.alertChange,
        guideStep: guideStep ?? this.guideStep,
        walk: walk ?? this.walk,
        screenOff: screenOff ?? this.screenOff,
        deviceRaised: deviceRaised ?? this.deviceRaised,
        ar: ar ?? this.ar,
        dialerEnabled: dialerEnabled ?? this.dialerEnabled,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        lockScreen: lockScreen ?? this.lockScreen,
        overlay: overlay ?? this.overlay,
        scenarioId: scenarioId ?? this.scenarioId,
        scenarioRun: scenarioRun ?? this.scenarioRun,
        toast: clearToast ? null : toast ?? this.toast,
      );
}

class GpsPatch {
  const GpsPatch({this.permission, this.accuracyM, this.position});
  final GpsPermission? permission;
  final double? accuracyM;
  final Point? position;
}

class WalkPatch {
  const WalkPatch({this.playing, this.speed, this.progressM});
  final bool? playing;
  final double? speed;
  final double? progressM;
}

class ArPatch {
  const ArPatch({
    this.cameraPermission,
    this.supported,
    this.headingAccuracyDeg,
    this.tracking,
    this.landmarkFound,
    this.showDetection,
  });
  final bool? cameraPermission;
  final bool? supported;
  final double? headingAccuracyDeg;
  final bool? tracking;
  final bool? landmarkFound;
  final bool? showDetection;
}

/// Argument of the `patch` action. Fields left out stay as they are; [gps], [walk] and [ar] are merged
/// field by field, so `StatePatch(gps: GpsPatch(accuracyM: 180))` works. A nullable field of the state is
/// set to null with its `clear...` flag.
class StatePatch {
  const StatePatch({
    this.lang,
    this.now,
    this.online,
    this.lastFetchAt,
    this.feedPaused,
    this.staleThresholdMin,
    this.alerts,
    this.shaking,
    this.eqSituation,
    this.gps,
    this.manualPin,
    this.clearManualPin = false,
    this.onHighGround,
    this.goHigher,
    this.clearGoHigher = false,
    this.marginAmpleM,
    this.hugeMinElevM,
    this.alertChange,
    this.clearAlertChange = false,
    this.guideStep,
    this.walk,
    this.screenOff,
    this.deviceRaised,
    this.ar,
    this.dialerEnabled,
    this.autoSpeak,
    this.lockScreen,
    this.overlay,
  });

  final Lang? lang;
  final int? now;
  final bool? online;
  final int? lastFetchAt;
  final bool? feedPaused;
  final double? staleThresholdMin;
  final List<Alert>? alerts;
  final bool? shaking;
  final EqSituation? eqSituation;
  final GpsPatch? gps;
  final Point? manualPin;
  final bool clearManualPin;
  final bool? onHighGround;
  final GoHigher? goHigher;
  final bool clearGoHigher;
  final double? marginAmpleM;
  final double? hugeMinElevM;
  final AlertChange? alertChange;
  final bool clearAlertChange;
  final GuideStep? guideStep;
  final WalkPatch? walk;
  final bool? screenOff;
  final bool? deviceRaised;
  final ArPatch? ar;
  final bool? dialerEnabled;
  final bool? autoSpeak;
  final bool? lockScreen;

  /// When set, the store does not close the overlay stack on its own.
  final List<ScreenId>? overlay;
}
