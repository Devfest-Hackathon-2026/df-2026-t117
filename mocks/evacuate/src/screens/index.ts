// Screen registry: ScreenId -> component + meta. App renders SCREENS[resolveScreen(state)].
// Each screen file default-exports its component; replace the file content, keep the default export.
import type { ComponentType } from 'react';
import type { ScreenId } from '../state/types';
import { SCREEN_META, type ScreenMeta } from './meta';
import S01 from './S01';
import S02 from './S02';
import S03 from './S03';
import S04 from './S04';
import S05 from './S05';
import S06 from './S06';
import S07 from './S07';
import S08 from './S08';
import S09 from './S09';
import S10 from './S10';
import S11 from './S11';
import S12 from './S12';
import H00 from './H00';
import A01 from './A01';
import A02 from './A02';
import A03 from './A03';
import A04 from './A04';

export { SCREEN_META, SCREEN_IDS } from './meta';
export type { ScreenMeta } from './meta';

export const SCREEN_COMPONENTS: Record<ScreenId, ComponentType> = {
  S01,
  S02,
  S03,
  S04,
  S05,
  S06,
  S07,
  S08,
  S09,
  S10,
  S11,
  S12,
  H00,
  A01,
  A02,
  A03,
  A04,
};

export interface ScreenEntry extends ScreenMeta {
  id: ScreenId;
  component: ComponentType;
}

export function getScreen(id: ScreenId): ScreenEntry {
  return { id, component: SCREEN_COMPONENTS[id], ...SCREEN_META[id] };
}
