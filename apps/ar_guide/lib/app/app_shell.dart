// The app: shows the screen that the state resolves to (the web's App.tsx + screens/index.ts).
import 'package:flutter/material.dart';

import 'live/live_alerts.dart';
import 'live/live_backend.dart';
import 'live/rules_backend.dart';
import 'logic/alert_effects.dart';
import 'logic/app_effects.dart';
import 'platform/tilt.dart';
import 'screens/meta.dart';
import 'screens/registry.dart';
import 'state/store.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.store, this.runClock = true, this.liveBackend, this.rulesBackend, this.tilt});

  /// Tests pass their own store.
  final AppStore? store;

  /// false leaves the virtual clock to the caller (tests).
  final bool runClock;

  /// Firestore + FCM. Tests that pass a [store] get none unless they pass their own.
  final LiveBackend? liveBackend;

  /// Remote Config (action rules). Tests that pass a [store] get none unless they pass their own.
  final RulesBackend? rulesBackend;

  /// Phone tilt -> deviceRaised (F36). Tests that pass a [store] get none unless they pass their own.
  final TiltSource? tilt;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppStore _store = widget.store ?? AppStore();
  late final AppEffects _effects = AppEffects(
    _store,
    pushCovers: _pushCovers,
    tilt: widget.tilt ?? (widget.store == null ? const NativeTiltSource() : null),
  );
  late final LiveAlerts _live =
      LiveAlerts(_store, widget.liveBackend ?? (widget.store == null ? FirebaseLiveBackend() : const NoLiveBackend()));

  /// In the background the FCM notification already tells the user (no duplicate re-notification).
  bool _pushCovers() {
    return pushCoversReNotify(
      foreground: isForegroundLifecycle(WidgetsBinding.instance.lifecycleState),
      pushEnabled: _live.pushState == PushState.enabled,
    );
  }

  @override
  void initState() {
    super.initState();
    _effects.start(clock: widget.runClock);
    _live.start();
    final rules = widget.rulesBackend ?? (widget.store == null ? FirebaseRulesBackend() : const NoRulesBackend());
    loadActionRules(rules).then((r) {
      if (mounted) _store.applyRules(r);
    });
  }

  @override
  void dispose() {
    _effects.dispose();
    _live.dispose();
    _store.platform.cancelSpeech();
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        store: _store,
        child: LiveScope(live: _live, child: const _CurrentScreen()),
      );
}

class _CurrentScreen extends StatelessWidget {
  const _CurrentScreen();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final id = store.screen;
    final meta = screenMeta[id]!;
    return PopScope(
      // The Android back button follows the same rule as the on-screen back arrow; with nothing to go
      // back to, it leaves the app.
      canPop: !canGoBack(store.state),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) store.back();
      },
      child: PhoneFrame(
        theme: meta.theme,
        fullBleed: meta.fullBleed,
        child: KeyedSubtree(key: ValueKey(id), child: Builder(builder: screenBuilders[id]!)),
      ),
    );
  }
}
