// Live alerts. Port of mocks/evacuate/src/live/LiveAlerts.tsx.
//  - Subscribes to the demo town's `alerts` in Firestore and applies each new bulletin once, with the same
//    store patch as the demo panel. While off, failing, or the demo is "offline", the demo panel alone controls
//    alerts. A bulletin received while the demo is offline is applied when it goes back online.
//  - A scenario load / reset clears what was received (the bulletin stays marked as seen).
//  - FCM: the notification permission and the topic. Foreground messages are not shown.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import 'live_backend.dart';
import 'live_doc.dart';

enum LiveStatus { off, connecting, live, cache, error }

/// [unavailable] = Firebase could not start (no google-services.json).
enum PushSupport { checking, supported, unavailable }

enum PushState { idle, working, enabled, denied, error }

class LiveAlerts extends ChangeNotifier {
  LiveAlerts(this.store, this.backend, {int Function()? realNow}) : _realNow = realNow ?? _systemNow;

  final AppStore store;
  final LiveBackend backend;
  final int Function() _realNow;

  static int _systemNow() => DateTime.now().millisecondsSinceEpoch;

  bool enabled = true;
  LiveStatus status = LiveStatus.connecting;
  String? error;

  /// The latest received bulletin and its real receive time (cleared by a scenario reset).
  LiveAlertDoc? latest;
  int? receivedAt;

  PushSupport pushSupport = PushSupport.checking;
  PushState pushState = PushState.idle;
  String? pushError;

  /// Real time of the last FCM message received in the foreground (not shown; for the demo panel).
  int? lastPushAt;

  /// Bulletins already applied (or marked seen). Survives toggling and resets.
  final Set<String> _applied = {};
  String? _receivedKey;
  StreamSubscription<LiveSnapshot>? _sub;
  bool _started = false; // the first snapshot from the server has been seen
  bool _booted = false;
  bool _ready = false;
  String? _initError;
  bool _disposed = false;

  late bool _online;
  late int _run;
  late Lang _lang;

  /// Whether [latest] has been applied to the store (false while waiting for the demo to be online).
  bool get latestApplied => latest != null && _applied.contains(liveKey(latest!));

  void start() {
    final s = store.state;
    _online = s.online;
    _run = s.scenarioRun;
    _lang = s.lang;
    saveNotificationLang(_lang);
    store.addListener(_onStore);
    unawaited(_boot());
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_onStore);
    _sub?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _boot() async {
    try {
      await backend.init();
      _ready = true;
    } catch (e) {
      _initError = _message(e);
    }
    if (_disposed) return;
    _booted = true;
    pushSupport = _ready ? PushSupport.supported : PushSupport.unavailable;
    _subscribe();
    await enablePush();
  }

  void setEnabled(bool on) {
    enabled = on;
    _subscribe();
    _applyLatest();
    _changed();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = null;
    if (!enabled) {
      status = LiveStatus.off;
      _changed();
      return;
    }
    if (!_booted) return;
    _started = false;
    if (!_ready) {
      status = LiveStatus.error;
      error = _initError;
      _changed();
      return;
    }
    status = LiveStatus.connecting;
    error = null;
    _changed();
    _sub = backend.alerts().listen(_onSnapshot, onError: (Object e) {
      status = LiveStatus.error;
      error = _message(e);
      _changed();
    });
  }

  void _onSnapshot(LiveSnapshot snap) {
    status = snap.fromCache ? LiveStatus.cache : LiveStatus.live;
    error = null;
    _receive(snap);
    _changed();
  }

  void _receive(LiveSnapshot snap) {
    if (snap.fromCache && !_started) return; // wait for the server's view before deciding what is "current"
    final initial = !_started;
    _started = true;
    final doc = snap.doc;
    if (doc == null) return;
    final key = liveKey(doc);
    // The same bulletin is written twice by the server (state, then `notified`): count it once.
    if (_applied.contains(key) || _receivedKey == key) return;
    // At start, an old or lifted alert is only marked seen, so it does not override the scenario.
    if (initial && !applyOnStart(doc, _realNow())) {
      _applied.add(key);
      return;
    }
    _receivedKey = key;
    latest = doc;
    receivedAt = _realNow();
    _applyLatest();
  }

  /// Apply the latest bulletin once, when subscribed and the demo is online.
  void _applyLatest() {
    final doc = latest;
    if (doc == null || !enabled || !store.state.online) return;
    if (!_applied.add(liveKey(doc))) return;
    final patch = liveAlertPatch(store.state, doc);
    if (patch != null) store.patch(patch);
  }

  void _onStore() {
    final s = store.state;
    if (s.lang != _lang) {
      _lang = s.lang;
      saveNotificationLang(_lang);
    }
    if (s.scenarioRun != _run) {
      _run = s.scenarioRun;
      final doc = latest;
      if (doc != null) _applied.add(liveKey(doc));
      latest = null;
      receivedAt = null;
      _changed();
    }
    if (s.online != _online) {
      _online = s.online;
      _applyLatest();
      _changed();
    }
  }

  /// Asks for the notification permission and subscribes to the topic. Runs at start-up too: Android does not
  /// tell "never asked" from "denied" and shows no dialog once refused for good, so asking is always safe.
  Future<void> enablePush() async {
    if (pushState == PushState.working) return;
    pushState = PushState.working;
    pushError = null;
    _changed();
    try {
      if (!await backend.requestNotifications()) {
        pushState = PushState.denied;
      } else if (_ready) {
        await backend.registerPush(_onForeground);
        pushState = PushState.enabled;
      } else {
        pushState = PushState.idle;
      }
    } catch (e) {
      pushState = PushState.error;
      pushError = _message(e);
    }
    _changed();
  }

  void _onForeground() {
    lastPushAt = _realNow();
    _changed();
  }

  static String _message(Object e) => e.toString();
}

/// Makes [LiveAlerts] available to the demo panel and H00.
class LiveScope extends InheritedNotifier<LiveAlerts> {
  const LiveScope({super.key, required LiveAlerts live, required super.child}) : super(notifier: live);

  static LiveAlerts of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LiveScope>()!.notifier!;
}

extension LiveContext on BuildContext {
  /// The web's `useLiveAlerts()`. Rebuilds the widget when it changes.
  LiveAlerts get live => LiveScope.of(this);
}
