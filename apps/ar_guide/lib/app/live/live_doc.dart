// Live alerts: turn `alerts/{EventID}` documents written by services/alert-ingest into the same store patches
// as the demo panel's alert controls. Port of mocks/evacuate/src/live/liveDoc.ts. Pure functions (no Firebase).
import '../data/alerts.dart';
import '../state/types.dart';

/// The fields of `alerts/{EventID}` the app uses (services/alert-ingest/README.md).
class LiveAlertDoc {
  const LiveAlertDoc({
    required this.eventId,
    required this.serial,
    required this.infoType,
    required this.kind,
    required this.level,
    required this.change,
    required this.expectedHeight,
    required this.arrivalTime,
    required this.arrivalCondition,
    required this.issuedAt,
    required this.areaId,
    required this.jmaStatus,
    required this.updatedAtMs,
  });

  final String eventId;
  final num serial;
  final String infoType;

  /// major-tsunami-warning / tsunami-warning / tsunami-advisory / cleared / cancelled
  final String kind;

  /// null when cleared / cancelled.
  final AlertLevel? level;
  final String change;
  final ExpectedHeight? expectedHeight;
  final String? arrivalTime;
  final String? arrivalCondition;
  final String? issuedAt;
  final String areaId;
  final String? jmaStatus;

  /// updatedAt (server write time) in epoch ms, 0 if unknown.
  final int updatedAtMs;
}

const Set<String> _kinds = {'major-tsunami-warning', 'tsunami-warning', 'tsunami-advisory', 'cleared', 'cancelled'};
const Set<String> _infoTypes = {'発表', '訂正', '取消'};

/// Live tsunami alerts get this id, so a cancellation can be matched to the alert it retracts.
String liveAlertId(String eventId) => 'jma-$eventId';

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

AlertLevel? _level(Object? v) => AlertLevel.values.where((l) => l.name == v).firstOrNull;

ExpectedHeight? _height(Object? v) {
  if (v is num) {
    return switch (v) { 1 => ExpectedHeight.m1, 3 => ExpectedHeight.m3, 5 => ExpectedHeight.m5, 10 => ExpectedHeight.m10, _ => null };
  }
  return switch (v) { 'over10' => ExpectedHeight.over10, 'huge' => ExpectedHeight.huge, 'high' => ExpectedHeight.high, _ => null };
}

int _millis(Object? v) => v is num ? v.toInt() : (v is DateTime ? v.millisecondsSinceEpoch : 0);

/// Validate a Firestore document (`updatedAt` as epoch ms or a DateTime). Returns null for anything unusable.
LiveAlertDoc? parseAlertDoc(String id, Map<String, dynamic> data) {
  final kind = data['kind'];
  final serial = data['serial'];
  if (kind is! String || !_kinds.contains(kind) || serial is! num) return null;
  final level = _level(data['level']);
  // A warning / advisory must carry a level; cleared / cancelled never do.
  if ((kind == 'cleared' || kind == 'cancelled') != (level == null)) return null;
  final info = data['infoType'];
  return LiveAlertDoc(
    eventId: _str(data['eventId']) ?? id,
    serial: serial,
    infoType: info is String && _infoTypes.contains(info) ? info : '発表',
    kind: kind,
    level: level,
    change: _str(data['change']) ?? 'new',
    expectedHeight: _height(data['expectedHeight']),
    arrivalTime: _str(data['arrivalTime']),
    arrivalCondition: _str(data['arrivalCondition']),
    issuedAt: _str(data['issuedAt']),
    areaId: _str(data['areaId']) ?? '',
    jmaStatus: _str(data['jmaStatus']),
    updatedAtMs: _millis(data['updatedAt']),
  );
}

/// One bulletin = EventID + Serial + InfoType. Each is applied to the store once.
String liveKey(LiveAlertDoc d) => '${d.eventId}|${d.serial}|${d.infoType}';

/// When the subscription starts, only an active alert this recent is applied (older ones are just marked seen).
const int startFreshMs = 60 * 60 * 1000;

bool applyOnStart(LiveAlertDoc d, int realNowMs) =>
    d.level != null && d.updatedAtMs > 0 && realNowMs - d.updatedAtMs <= startFreshMs;

/// The store patch for a live bulletin, in the same shape as the demo panel's controls, so the store detects
/// upgrade / raise / downgrade itself. The alert's issuedAt is the virtual clock, as the demo panel does.
StatePatch? liveAlertPatch(AppState state, LiveAlertDoc d) {
  final tsunami = state.alerts.where((a) => a.type == HazardType.tsunami).firstOrNull;
  final rest = state.alerts.where((a) => a.type != HazardType.tsunami).toList();
  if (d.kind == 'cleared') return StatePatch(alerts: const [], lastFetchAt: state.now);
  if (d.kind == 'cancelled') {
    if (tsunami?.id != liveAlertId(d.eventId)) return null;
    return StatePatch(alerts: rest, lastFetchAt: state.now);
  }
  final level = d.level;
  if (level == null) return null;
  final base = tsunami ?? alertTsunami;
  // Built directly: arrivalTime / arrivalCondition of the previous bulletin must not carry over.
  final next = Alert(
    id: liveAlertId(d.eventId),
    type: base.type,
    level: level,
    area: base.area,
    issuedAt: state.now,
    source: base.source,
    expectedHeight: d.expectedHeight ?? defaultHeight[level],
    arrivalTime: d.arrivalTime,
    arrivalCondition: d.arrivalCondition,
  );
  return StatePatch(alerts: [...rest, next], lastFetchAt: state.now);
}

/// "HH:MM" of an ISO time as announced (JST offset kept), e.g. "2026-11-08T10:05:00+09:00" -> "10:05".
String? hhmm(String? iso) {
  final m = iso == null ? null : RegExp(r'T(\d{2}):(\d{2})').firstMatch(iso);
  return m == null ? null : '${m[1]}:${m[2]}';
}
