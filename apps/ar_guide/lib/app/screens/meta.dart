// Screen metadata: display name (for dev / demo panel) and theme. Port of mocks/evacuate/src/screens/meta.ts.
import '../state/types.dart';
import '../theme.dart';

enum ScreenKind { guidance, sub, lock }

class ScreenMeta {
  const ScreenMeta(this.name, this.theme, this.kind, {this.fullBleed = false});

  final String name;
  final TkTheme theme;

  /// Guidance screens use the brand header; sub screens use back + title.
  final ScreenKind kind;

  /// The screen draws everything itself, without the frame's status bar (S11: the existing AR screen).
  final bool fullBleed;
}

const Map<ScreenId, ScreenMeta> screenMeta = {
  ScreenId.s01: ScreenMeta('Lock-screen alert', TkTheme.dark, ScreenKind.lock),
  ScreenId.s02: ScreenMeta('Earthquake: shaking', TkTheme.dark, ScreenKind.guidance),
  ScreenId.s03: ScreenMeta('Tsunami: go uphill now', TkTheme.dark, ScreenKind.guidance),
  ScreenId.s04: ScreenMeta('Route navigation', TkTheme.dark, ScreenKind.guidance),
  ScreenId.s05: ScreenMeta('Offline saved guide', TkTheme.dark, ScreenKind.guidance),
  ScreenId.s06: ScreenMeta('High ground: stay here', TkTheme.dark, ScreenKind.guidance),
  ScreenId.s07: ScreenMeta('Location uncertain: set a pin', TkTheme.dark, ScreenKind.sub),
  ScreenId.s08: ScreenMeta('Saved map (offline)', TkTheme.dark, ScreenKind.sub),
  ScreenId.s09: ScreenMeta('Language', TkTheme.light, ScreenKind.sub),
  ScreenId.s10: ScreenMeta('Emergency call', TkTheme.light, ScreenKind.sub),
  ScreenId.s11: ScreenMeta('AR guidance', TkTheme.dark, ScreenKind.sub, fullBleed: true),
  ScreenId.s12: ScreenMeta('AR paused: map guidance', TkTheme.dark, ScreenKind.sub),
  ScreenId.h00: ScreenMeta('Home (no alerts)', TkTheme.dark, ScreenKind.guidance),
  ScreenId.a01: ScreenMeta('Location permission', TkTheme.light, ScreenKind.sub),
  ScreenId.a02: ScreenMeta('Alert details', TkTheme.light, ScreenKind.sub),
  ScreenId.a03: ScreenMeta('Disaster guides', TkTheme.light, ScreenKind.sub),
  ScreenId.a04: ScreenMeta('Safety articles', TkTheme.light, ScreenKind.sub),
};
