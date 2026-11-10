// Action rules (thresholds) distributed by Firebase Remote Config (architecture.md D1). Pure: no Firebase here,
// see live/rules_backend.dart. Server template: tools/remote-config/template.json.

/// Remote Config parameter names.
const String rulesVersionKey = 'rules_version';
const String marginAmpleKey = 'margin_ample_m';
const String hugeMinElevKey = 'huge_min_elev_m';
const String staleThresholdKey = 'stale_threshold_min';

enum RulesSource {
  /// Built-in defaults (no Remote Config, or nothing published).
  defaults,

  /// Fetched from Remote Config at this start.
  remote,

  /// Fetched at an earlier start (this fetch failed or timed out, e.g. offline).
  cached,
}

class ActionRules {
  const ActionRules({
    required this.rulesVersion,
    required this.marginAmpleM,
    required this.hugeMinElevM,
    required this.staleThresholdMin,
    this.source = RulesSource.defaults,
  });

  final String rulesVersion;

  /// Margin (m) above the expected height that counts as ample (AppState.marginAmpleM).
  final double marginAmpleM;

  /// Elevation (m) needed when the expected height is over 10 m (AppState.hugeMinElevM).
  final double hugeMinElevM;

  /// Minutes since the last fetch after which the alert is stale (AppState.staleThresholdMin).
  final double staleThresholdMin;

  final RulesSource source;

  /// The values before Remote Config (createBaseState).
  static const ActionRules defaults = ActionRules(
    rulesVersion: 'builtin',
    marginAmpleM: 10,
    hugeMinElevM: 20,
    staleThresholdMin: 10,
  );
}

/// Accepted ranges (same as the demo panel sliders). Values outside are ignored.
const ({double min, double max}) marginAmpleRange = (min: 0, max: 30);
const ({double min, double max}) hugeMinElevRange = (min: 0, max: 40);
const ({double min, double max}) staleThresholdRange = (min: 1, max: 30);

double _number(String? raw, ({double min, double max}) range, double fallback) {
  final v = raw == null ? null : double.tryParse(raw.trim());
  if (v == null || !v.isFinite || v < range.min || v > range.max) return fallback;
  return v;
}

String _version(String? raw) {
  final v = raw?.trim() ?? '';
  return v.isEmpty || v.length > 64 ? ActionRules.defaults.rulesVersion : v;
}

/// Rules from the Remote Config values (only the ones that came from the server). Missing or invalid
/// values fall back to the default one by one; no values at all means [RulesSource.defaults].
ActionRules parseRules(Map<String, String> values, {bool fresh = true}) {
  const d = ActionRules.defaults;
  final known = [rulesVersionKey, marginAmpleKey, hugeMinElevKey, staleThresholdKey];
  if (!known.any(values.containsKey)) return d;
  return ActionRules(
    rulesVersion: _version(values[rulesVersionKey]),
    marginAmpleM: _number(values[marginAmpleKey], marginAmpleRange, d.marginAmpleM),
    hugeMinElevM: _number(values[hugeMinElevKey], hugeMinElevRange, d.hugeMinElevM),
    staleThresholdMin: _number(values[staleThresholdKey], staleThresholdRange, d.staleThresholdMin),
    source: fresh ? RulesSource.remote : RulesSource.cached,
  );
}
