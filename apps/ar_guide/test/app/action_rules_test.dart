// Action rules from Remote Config (architecture.md D1): defaults without Firebase, cached values offline,
// invalid values ignored, and the store / scenarios start from the loaded rules.
import 'dart:async';

import 'package:ar_guide/app/live/rules_backend.dart';
import 'package:ar_guide/app/state/action_rules.dart';
import 'package:ar_guide/app/state/scenarios.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shared_test.dart' show RecordingPlatform;

class FakeRulesBackend implements RulesBackend {
  FakeRulesBackend(this.values, {this.initFails = false, this.fetchFails = false, this.fetchHangs = false});

  final Map<String, String> values;
  final bool initFails;
  final bool fetchFails;
  final bool fetchHangs;

  @override
  Future<void> init() async {
    if (initFails) throw StateError('no google-services.json');
  }

  @override
  Future<void> fetchAndActivate() {
    if (fetchHangs) return Completer<void>().future;
    if (fetchFails) return Future.error(StateError('offline'));
    return Future.value();
  }

  @override
  Map<String, String> activeValues() => values;
}

const Map<String, String> published = {
  rulesVersionKey: '2026-11-10.1',
  marginAmpleKey: '12',
  hugeMinElevKey: '25.5',
  staleThresholdKey: '5',
};

void main() {
  const d = ActionRules.defaults;

  test('the defaults are the values before Remote Config', () {
    final base = createBaseState(Lang.en);
    expect(d.source, RulesSource.defaults);
    expect(base.marginAmpleM, 10);
    expect(base.hugeMinElevM, 20);
    expect(base.staleThresholdMin, 10);
    expect((d.marginAmpleM, d.hugeMinElevM, d.staleThresholdMin), (10.0, 20.0, 10.0));
  });

  group('loadActionRules', () {
    test('no Firebase -> defaults', () async {
      expect(await loadActionRules(const NoRulesBackend()), same(d));
      expect(await loadActionRules(FakeRulesBackend(published, initFails: true)), same(d));
    });

    test('fetched values are applied', () async {
      final r = await loadActionRules(FakeRulesBackend(published));
      expect(r.source, RulesSource.remote);
      expect(r.rulesVersion, '2026-11-10.1');
      expect(r.marginAmpleM, 12);
      expect(r.hugeMinElevM, 25.5);
      expect(r.staleThresholdMin, 5);
    });

    test('fetch failure or timeout -> the values activated earlier (cache)', () async {
      final failed = await loadActionRules(FakeRulesBackend(published, fetchFails: true));
      expect(failed.source, RulesSource.cached);
      expect(failed.marginAmpleM, 12);
      final hung = await loadActionRules(FakeRulesBackend(published, fetchHangs: true), timeout: const Duration(milliseconds: 10));
      expect(hung.source, RulesSource.cached);
      expect(hung.rulesVersion, '2026-11-10.1');
    });

    test('nothing published or cached -> defaults', () async {
      expect(await loadActionRules(FakeRulesBackend(const {})), same(d));
      expect(await loadActionRules(FakeRulesBackend(const {}, fetchFails: true)), same(d));
      expect(await loadActionRules(FakeRulesBackend(const {'other_param': '1'})), same(d));
    });
  });

  group('parseRules rejects invalid values one by one', () {
    ActionRules parse(Map<String, String> v) => parseRules({...published, ...v});

    test('negative, NaN, infinite, not a number', () {
      expect(parse({marginAmpleKey: '-1'}).marginAmpleM, d.marginAmpleM);
      expect(parse({hugeMinElevKey: 'NaN'}).hugeMinElevM, d.hugeMinElevM);
      expect(parse({hugeMinElevKey: 'Infinity'}).hugeMinElevM, d.hugeMinElevM);
      expect(parse({staleThresholdKey: 'ten'}).staleThresholdMin, d.staleThresholdMin);
      expect(parse({staleThresholdKey: ''}).staleThresholdMin, d.staleThresholdMin);
    });

    test('out of range (the demo panel slider ranges)', () {
      expect(parse({marginAmpleKey: '31'}).marginAmpleM, d.marginAmpleM);
      expect(parse({hugeMinElevKey: '41'}).hugeMinElevM, d.hugeMinElevM);
      expect(parse({staleThresholdKey: '0'}).staleThresholdMin, d.staleThresholdMin);
      expect(parse({staleThresholdKey: '31'}).staleThresholdMin, d.staleThresholdMin);
      // The edges are accepted.
      expect(parse({marginAmpleKey: '0'}).marginAmpleM, 0);
      expect(parse({hugeMinElevKey: '40'}).hugeMinElevM, 40);
      expect(parse({staleThresholdKey: ' 1 '}).staleThresholdMin, 1);
    });

    test('the valid values are kept', () {
      final r = parse({marginAmpleKey: '-5'});
      expect(r.marginAmpleM, d.marginAmpleM);
      expect(r.hugeMinElevM, 25.5);
      expect(r.staleThresholdMin, 5);
    });

    test('empty or too long version -> default version', () {
      expect(parse({rulesVersionKey: '  '}).rulesVersion, d.rulesVersion);
      expect(parse({rulesVersionKey: 'x' * 65}).rulesVersion, d.rulesVersion);
    });
  });

  group('store', () {
    const rules = ActionRules(rulesVersion: 'r1', marginAmpleM: 12, hugeMinElevM: 25, staleThresholdMin: 5, source: RulesSource.remote);

    test('applyRules sets the thresholds, and reset / loadScenario start from them', () {
      final store = AppStore(lang: Lang.en, platform: RecordingPlatform());
      store.applyRules(rules);
      expect(store.rules, same(rules));
      expect((store.state.marginAmpleM, store.state.hugeMinElevM, store.state.staleThresholdMin), (12.0, 25.0, 5.0));
      store.patch(const StatePatch(marginAmpleM: 3));
      store.loadScenario('5');
      expect((store.state.marginAmpleM, store.state.hugeMinElevM, store.state.staleThresholdMin), (12.0, 25.0, 5.0));
    });

    test('a slider changed before the rules arrive is kept', () {
      final store = AppStore(lang: Lang.en, platform: RecordingPlatform());
      store.patch(const StatePatch(hugeMinElevM: 40));
      store.applyRules(rules);
      expect(store.state.hugeMinElevM, 40);
      expect(store.state.marginAmpleM, 12);
    });
  });
}
