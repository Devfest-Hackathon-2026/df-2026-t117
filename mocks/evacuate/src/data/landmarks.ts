// Registered AR landmarks (requirements F39, like landmarks.json). Fictional town data, NOT real places.
// In production a vision model extracts landmark candidates from the camera frame and they are matched
// against this list; in the mock the "recognition result" is the demo flag `ar.landmarkFound`.
import type { L10n, Point } from '../state/types';

export type LandmarkKind = 'tsunami-evacuation-sign' | 'evacuation-route-sign' | 'traffic-mirror';

export interface Landmark {
  id: string;
  kind: LandmarkKind;
  name: L10n;
  /** Town meters (x = east, y = south) */
  pos: Point;
}

const KIND_NAMES: Record<LandmarkKind, L10n> = {
  'tsunami-evacuation-sign': {
    en: 'Tsunami evacuation sign',
    ja: '津波避難誘導標識',
    'zh-Hans': '海啸避难指示牌',
    ko: '쓰나미 대피 안내 표지',
    ar: 'لافتة إخلاء التسونامي',
  },
  'evacuation-route-sign': {
    en: 'Evacuation route sign',
    ja: '避難路の標識',
    'zh-Hans': '避难路线标志',
    ko: '대피로 표지',
    ar: 'لافتة طريق الإخلاء',
  },
  'traffic-mirror': {
    en: 'Traffic mirror',
    ja: 'カーブミラー',
    'zh-Hans': '道路反光镜',
    ko: '도로 반사경',
    ar: 'مرآة مرور',
  },
};

export const LANDMARKS: Landmark[] = [
  // Corner of Shore Street x Hill Road: first turn (Right) of the main scenario route.
  { id: 'lm-shore-hill-sign', kind: 'tsunami-evacuation-sign', name: KIND_NAMES['tsunami-evacuation-sign'], pos: { x: 148, y: 284 } },
  { id: 'lm-shore-hill-mirror', kind: 'traffic-mirror', name: KIND_NAMES['traffic-mirror'], pos: { x: 132, y: 296 } },
  // Pine Street x Hill Road
  { id: 'lm-pine-hill-sign', kind: 'tsunami-evacuation-sign', name: KIND_NAMES['tsunami-evacuation-sign'], pos: { x: 264, y: 279 } },
  // Foot of Hill Steps (Cherry Street x Hill Road): second turn (Left)
  { id: 'lm-steps-sign', kind: 'evacuation-route-sign', name: KIND_NAMES['evacuation-route-sign'], pos: { x: 372, y: 274 } },
  // Park Street x Hill Road
  { id: 'lm-park-hill-sign', kind: 'tsunami-evacuation-sign', name: KIND_NAMES['tsunami-evacuation-sign'], pos: { x: 482, y: 270 } },
  // Shore Street x Market Road / Station Road
  { id: 'lm-shore-market-sign', kind: 'tsunami-evacuation-sign', name: KIND_NAMES['tsunami-evacuation-sign'], pos: { x: 138, y: 157 } },
  { id: 'lm-shore-station-sign', kind: 'tsunami-evacuation-sign', name: KIND_NAMES['tsunami-evacuation-sign'], pos: { x: 146, y: 394 } },
];

/** Max distance (m) between a landmark and the next turn for it to be used for alignment. */
export const LANDMARK_MATCH_RADIUS_M = 40;

/** Registered sign closest to `p` within `radiusM` (signs preferred over mirrors), or null. */
export function landmarkNear(p: Point, radiusM = LANDMARK_MATCH_RADIUS_M): Landmark | null {
  let best: { lm: Landmark; score: number } | null = null;
  for (const lm of LANDMARKS) {
    const d = Math.hypot(lm.pos.x - p.x, lm.pos.y - p.y);
    if (d > radiusM) continue;
    const score = d + (lm.kind === 'traffic-mirror' ? 1000 : 0);
    if (!best || score < best.score) best = { lm, score };
  }
  return best?.lm ?? null;
}
