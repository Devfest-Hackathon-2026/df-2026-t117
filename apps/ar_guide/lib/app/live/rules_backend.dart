// Loads the action rules from Firebase Remote Config (architecture.md D1: "行動ルール Remote Config のキャッシュ").
// Activated values are kept on the device, so the last fetched rules still apply offline. Without Firebase
// (no google-services.json, tests) or with a bad value, the built-in defaults (= the values before
// Remote Config) are used.
import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../state/action_rules.dart';
import 'firebase_app.dart';

abstract class RulesBackend {
  /// Throws when Remote Config cannot be used (no google-services.json, for example).
  Future<void> init();

  /// Fetches and activates the server values. Throws on failure (offline, for example).
  Future<void> fetchAndActivate();

  /// The activated values that came from the server (kept on the device between starts).
  Map<String, String> activeValues();
}

/// For tests and runs without Firebase: always the defaults.
class NoRulesBackend implements RulesBackend {
  const NoRulesBackend();

  @override
  Future<void> init() async => throw StateError('no backend');

  @override
  Future<void> fetchAndActivate() async => throw StateError('no backend');

  @override
  Map<String, String> activeValues() => const {};
}

class FirebaseRulesBackend implements RulesBackend {
  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  @override
  Future<void> init() async {
    await ensureFirebase();
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: const Duration(minutes: 30),
    ));
    await _rc.ensureInitialized();
  }

  @override
  Future<void> fetchAndActivate() async {
    await _rc.fetchAndActivate();
    if (_rc.lastFetchStatus != RemoteConfigFetchStatus.success) {
      throw StateError('fetch ${_rc.lastFetchStatus.name}');
    }
  }

  @override
  Map<String, String> activeValues() => {
        for (final e in _rc.getAll().entries)
          if (e.value.source == ValueSource.valueRemote) e.key: e.value.asString(),
      };
}

/// Startup: init + fetch (each with [timeout]). Never throws; falls back to the cached values, then the defaults.
Future<ActionRules> loadActionRules(RulesBackend backend, {Duration timeout = const Duration(seconds: 6)}) async {
  try {
    await backend.init().timeout(timeout);
  } catch (_) {
    return ActionRules.defaults;
  }
  var fresh = true;
  try {
    await backend.fetchAndActivate().timeout(timeout);
  } catch (_) {
    fresh = false;
  }
  try {
    return parseRules(backend.activeValues(), fresh: fresh);
  } catch (_) {
    return ActionRules.defaults;
  }
}
