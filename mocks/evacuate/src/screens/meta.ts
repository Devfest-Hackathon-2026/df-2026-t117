// Screen metadata: display name (for dev / demo panel) and theme (status bar + background).
import type { ScreenId } from '../state/types';
import type { Theme } from '../components/StatusBar';

export interface ScreenMeta {
  name: string;
  theme: Theme;
  /** Guidance screens use the brand header; sub screens use back + title */
  kind: 'guidance' | 'sub' | 'lock';
}

export const SCREEN_META: Record<ScreenId, ScreenMeta> = {
  S01: { name: 'Lock-screen alert', theme: 'dark', kind: 'lock' },
  S02: { name: 'Earthquake: shaking', theme: 'dark', kind: 'guidance' },
  S03: { name: 'Tsunami: go uphill now', theme: 'dark', kind: 'guidance' },
  S04: { name: 'Route navigation', theme: 'dark', kind: 'guidance' },
  S05: { name: 'Offline saved guide', theme: 'dark', kind: 'guidance' },
  S06: { name: 'High ground: stay here', theme: 'dark', kind: 'guidance' },
  S07: { name: 'Location uncertain: set a pin', theme: 'dark', kind: 'sub' },
  S08: { name: 'Saved map (offline)', theme: 'dark', kind: 'sub' },
  S09: { name: 'Language', theme: 'light', kind: 'sub' },
  S10: { name: 'Emergency call', theme: 'light', kind: 'sub' },
  S11: { name: 'AR guidance', theme: 'dark', kind: 'sub' },
  S12: { name: 'AR paused: map guidance', theme: 'dark', kind: 'sub' },
  H00: { name: 'Home (no alerts)', theme: 'dark', kind: 'guidance' },
  A01: { name: 'Location permission', theme: 'light', kind: 'sub' },
  A02: { name: 'Alert details', theme: 'light', kind: 'sub' },
  A03: { name: 'Disaster guides', theme: 'light', kind: 'sub' },
  A04: { name: 'Safety articles', theme: 'light', kind: 'sub' },
};

export const SCREEN_IDS = Object.keys(SCREEN_META) as ScreenId[];
