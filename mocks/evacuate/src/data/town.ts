// Fictional town "Minato Bay / みなと湾（架空）" (T1). NOT a real place.
// Coordinates are meters: origin top-left, x = east, y = south. Core area ~600 m x 450 m.
// Sea on the west (slanted coastline), coastal inundation hazard band, street grid rising to the east (HIGH GROUND).
import type { L10n, Point } from '../state/types';
import { START_POSITION } from '../state/scenarios';
import { jstOnDemoDay } from '../state/time';

// ---------------------------------------------------------------------------
// Types

export interface TownNode {
  id: string;
  x: number;
  y: number;
  /** Elevation above sea level (m). Rises to the east. */
  elev: number;
}

export interface RoadClosure {
  reason: L10n;
  /** When passability was last checked (epoch ms). 09:41 JST on the demo day. */
  checkedAt: number;
}

export interface Street {
  id: string;
  name: L10n;
  /** Node ids along the street, in order */
  nodes: string[];
  /** Whole street is stairs */
  stairs?: boolean;
  /** Draw a decorative continuation past the first / last node (outside the core area) */
  extendStart?: boolean;
  extendEnd?: boolean;
}

export interface TownEdge {
  id: string;
  a: string;
  b: string;
  streetId: string;
  stairs: boolean;
  closure: RoadClosure | null;
}

export interface Refuge {
  id: string;
  name: L10n;
  address: L10n;
  /** Graph node the refuge sits on */
  nodeId: string;
  pos: Point;
  elev: number;
}

// ---------------------------------------------------------------------------
// Names

export const TOWN_NAME: L10n = {
  en: 'Minato Bay (fictional)',
  ja: 'みなと湾（架空）',
  'zh-Hans': '港湾（虚构）',
  ko: '미나토만(가상)',
  ar: 'خليج ميناتو (خيالي)',
};

/** Map labels */
export const MAP_LABELS: { sea: L10n; highGround: L10n } = {
  sea: { en: 'SEA', ja: '海', 'zh-Hans': '海', ko: '바다', ar: 'البحر' },
  highGround: { en: 'HIGH GROUND', ja: '高台', 'zh-Hans': '高地', ko: '고지대', ar: 'أرض مرتفعة' },
};

/** Build "<road>, Minato Bay" in 5 languages (Japanese: "みなと湾 <road>（架空）"). */
export function townAddress(road: L10n): L10n {
  return {
    en: `${road.en}, Minato Bay`,
    ja: `みなと湾 ${road.ja}（架空）`,
    'zh-Hans': `港湾 ${road['zh-Hans']}（虚构）`,
    ko: `미나토만 ${road.ko}(가상)`,
    ar: `${road.ar}، خليج ميناتو (خيالي)`,
  };
}

const ROAD_NAMES = {
  shore: { en: 'Shore Street', ja: '浜通り', 'zh-Hans': '滨海街', ko: '해변길', ar: 'شارع الشاطئ' },
  pine: { en: 'Pine Street', ja: '松通り', 'zh-Hans': '松树街', ko: '소나무길', ar: 'شارع الصنوبر' },
  cherry: { en: 'Cherry Street', ja: '桜通り', 'zh-Hans': '樱花街', ko: '벚꽃길', ar: 'شارع الكرز' },
  park: { en: 'Park Street', ja: '公園通り', 'zh-Hans': '公园街', ko: '공원길', ar: 'شارع الحديقة' },
  east: { en: 'East Street', ja: '東通り', 'zh-Hans': '东街', ko: '동쪽길', ar: 'الشارع الشرقي' },
  shrine: { en: 'Shrine Road', ja: '神社通り', 'zh-Hans': '神社路', ko: '신사길', ar: 'طريق الضريح' },
  market: { en: 'Market Road', ja: '市場通り', 'zh-Hans': '市场路', ko: '시장길', ar: 'طريق السوق' },
  hill: { en: 'Hill Road', ja: '高台通り', 'zh-Hans': '高台路', ko: '고지대길', ar: 'طريق التل' },
  station: { en: 'Station Road', ja: '駅前通り', 'zh-Hans': '站前路', ko: '역앞길', ar: 'طريق المحطة' },
  parkLane: { en: 'Hill Park Lane', ja: '高台公園前', 'zh-Hans': '高台公园路', ko: '고지대 공원길', ar: 'ممر حديقة التل' },
  steps: { en: 'Hill Steps', ja: '高台の階段', 'zh-Hans': '高台台阶', ko: '고지대 계단', ar: 'درج التل' },
} satisfies Record<string, L10n>;

export const ROAD_NAME = ROAD_NAMES;

// ---------------------------------------------------------------------------
// Terrain

export const TOWN_BOUNDS = { x: 0, y: 0, w: 600, h: 450 } as const;

/** Coastline from north to south (land is east of it). Extends past the core area for drawing. */
export const COASTLINE: Point[] = [
  { x: 92, y: -300 },
  { x: 90, y: 0 },
  { x: 82, y: 110 },
  { x: 96, y: 220 },
  { x: 74, y: 340 },
  { x: 52, y: 450 },
  { x: 36, y: 750 },
];

/** East edge of the inundation hazard zone, north to south. */
export const HAZARD_EAST_EDGE: Point[] = [
  { x: 212, y: -300 },
  { x: 214, y: 0 },
  { x: 222, y: 140 },
  { x: 230, y: 250 },
  { x: 214, y: 350 },
  { x: 182, y: 450 },
  { x: 150, y: 750 },
];

const FAR_WEST = -600;

/** Sea polygon (west of the coastline). */
export const SEA_POLYGON: Point[] = [
  { x: FAR_WEST, y: COASTLINE[0].y },
  ...COASTLINE,
  { x: FAR_WEST, y: COASTLINE[COASTLINE.length - 1].y },
];

/**
 * Hazard (inundation) zone polygon: everything west of HAZARD_EAST_EDGE (sea included, so a pin dropped
 * in the sea counts as hazard). The map draws the sea on top, so only the land band appears striped.
 */
export const HAZARD_ZONE: Point[] = [
  { x: FAR_WEST, y: HAZARD_EAST_EDGE[0].y },
  ...HAZARD_EAST_EDGE,
  { x: FAR_WEST, y: HAZARD_EAST_EDGE[HAZARD_EAST_EDGE.length - 1].y },
];

/** High ground: roughly east of x = 380 (elevation >= ~20 m). Used for the "HIGH GROUND" label. */
export const HIGH_GROUND_MIN_X = 380;

const HILL_TOP: Point = { x: 470, y: 190 };

/** Elevation model (m): rises ~4.5 m per 100 m eastwards plus a hill around Hill Park. */
export function elevationAt(p: Point): number {
  const dx = p.x - HILL_TOP.x;
  const dy = p.y - HILL_TOP.y;
  const bump = 8 * Math.exp(-(dx * dx + dy * dy) / (2 * 90 * 90));
  return Math.max(0, 1.5 + 0.045 * p.x + bump);
}

// ---------------------------------------------------------------------------
// Road graph

const RAW_NODES: Record<string, [number, number]> = {
  // Row A (Shrine Road), y ~ 45 -> 28
  AW: [94, 46], A0: [128, 45], A1: [252, 40], A2: [372, 36], A3: [485, 32], A4: [585, 28],
  // Row B (Market Road), y ~ 164 -> 145
  BW: [96, 164], B0: [132, 163], B1: [255, 158], B2: [369, 153], B3: [481, 149], B4: [583, 145],
  // Row C (Hill Road), y ~ 291 -> 272
  CW: [90, 291], C0: [140, 290], C1: [258, 285], C2: [366, 280], C3: [476, 276], C4: [580, 272],
  // Row D (Station Road), y ~ 402 -> 385
  DW: [68, 402], D0: [140, 400], D1: [262, 396], D2: [362, 392], D3: [470, 388], D4: [578, 385],
  // Hill Park (on top of the hill)
  HP: [455, 205],
};

export const NODES: Record<string, TownNode> = Object.fromEntries(
  Object.entries(RAW_NODES).map(([id, [x, y]]) => [
    id,
    { id, x, y, elev: Math.round(elevationAt({ x, y }) * 10) / 10 },
  ]),
);

export const STREETS: Street[] = [
  { id: 'rowA', name: ROAD_NAMES.shrine, nodes: ['AW', 'A0', 'A1', 'A2', 'A3', 'A4'], extendEnd: true },
  { id: 'rowB', name: ROAD_NAMES.market, nodes: ['BW', 'B0', 'B1', 'B2', 'B3', 'B4'], extendEnd: true },
  { id: 'rowC', name: ROAD_NAMES.hill, nodes: ['CW', 'C0', 'C1', 'C2', 'C3', 'C4'], extendEnd: true },
  { id: 'rowD', name: ROAD_NAMES.station, nodes: ['DW', 'D0', 'D1', 'D2', 'D3', 'D4'], extendEnd: true },
  { id: 'col0', name: ROAD_NAMES.shore, nodes: ['A0', 'B0', 'C0', 'D0'], extendStart: true, extendEnd: true },
  { id: 'col1', name: ROAD_NAMES.pine, nodes: ['A1', 'B1', 'C1', 'D1'], extendStart: true, extendEnd: true },
  { id: 'col2', name: ROAD_NAMES.cherry, nodes: ['A2', 'B2', 'C2', 'D2'], extendStart: true, extendEnd: true },
  { id: 'col3', name: ROAD_NAMES.park, nodes: ['A3', 'B3', 'C3', 'D3'], extendStart: true, extendEnd: true },
  { id: 'col4', name: ROAD_NAMES.east, nodes: ['A4', 'B4', 'C4', 'D4'], extendStart: true, extendEnd: true },
  { id: 'parkLane', name: ROAD_NAMES.parkLane, nodes: ['C3', 'HP'] },
  { id: 'steps', name: ROAD_NAMES.steps, nodes: ['C2', 'HP'], stairs: true },
];

/** Passability was checked at 09:41 JST (shown as "Passability checked 09:41 JST" while online). */
export const ROAD_STATUS_CHECKED_AT = jstOnDemoDay(9, 41);

/** Closed road segments, keyed by "a-b" node pair (either order). Mock data, like roads.json. */
export const CLOSURES: Record<string, RoadClosure> = {
  'D1-D2': {
    reason: {
      en: 'Collapsed wall',
      ja: 'ブロック塀の倒壊',
      'zh-Hans': '围墙倒塌',
      ko: '담장 붕괴',
      ar: 'انهيار جدار',
    },
    checkedAt: ROAD_STATUS_CHECKED_AT,
  },
  'A2-B2': {
    reason: {
      en: 'Fallen debris',
      ja: '落下物',
      'zh-Hans': '坠落物',
      ko: '낙하물',
      ar: 'حطام متساقط',
    },
    checkedAt: ROAD_STATUS_CHECKED_AT,
  },
};

function closureFor(a: string, b: string): RoadClosure | null {
  return CLOSURES[`${a}-${b}`] ?? CLOSURES[`${b}-${a}`] ?? null;
}

export const EDGES: TownEdge[] = STREETS.flatMap((s) =>
  s.nodes.slice(1).map((b, i) => {
    const a = s.nodes[i];
    return { id: `${a}-${b}`, a, b, streetId: s.id, stairs: !!s.stairs, closure: closureFor(a, b) };
  }),
);

export function streetById(id: string): Street | undefined {
  return STREETS.find((s) => s.id === id);
}

// ---------------------------------------------------------------------------
// Refuges (flags)

function node(id: string): TownNode {
  return NODES[id];
}

export const REFUGES: Refuge[] = [
  {
    id: 'hill-park',
    name: { en: 'Hill Park', ja: '高台公園', 'zh-Hans': '高台公园', ko: '고지대 공원', ar: 'حديقة التل' },
    address: townAddress(ROAD_NAMES.hill),
    nodeId: 'HP',
    pos: { x: node('HP').x, y: node('HP').y },
    elev: node('HP').elev,
  },
  {
    id: 'minato-shrine',
    name: { en: 'Minato Shrine', ja: 'みなと神社', 'zh-Hans': '港神社', ko: '미나토 신사', ar: 'ضريح ميناتو' },
    address: townAddress(ROAD_NAMES.shrine),
    nodeId: 'A3',
    pos: { x: node('A3').x, y: node('A3').y },
    elev: node('A3').elev,
  },
  {
    id: 'east-school',
    name: {
      en: 'East Junior High School',
      ja: '東中学校',
      'zh-Hans': '东中学',
      ko: '동중학교',
      ar: 'المدرسة الإعدادية الشرقية',
    },
    address: townAddress(ROAD_NAMES.station),
    nodeId: 'D4',
    pos: { x: node('D4').x, y: node('D4').y },
    elev: node('D4').elev,
  },
];

export const HILL_PARK = REFUGES[0];

// ---------------------------------------------------------------------------
// Start position

/** Scenario start: on Shore Street, 40 m south of Hill Road, inside the hazard zone. Equals START_POSITION. */
export const TOWN_START: Point = { ...START_POSITION };

/** Address of the start road (Shore Street). */
export const START_ADDRESS: L10n = townAddress(ROAD_NAMES.shore);

/** "Hill Road, Minato Bay / みなと湾 高台通り（架空）" */
export const HILL_ROAD_ADDRESS: L10n = townAddress(ROAD_NAMES.hill);

// ---------------------------------------------------------------------------
// Address lookup (S10 "Show this location")

function distToSegment(p: Point, a: Point, b: Point): number {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2));
  return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

/** Multilingual address of the nearest named street (or refuge, if within 25 m). */
export function addressAt(p: Point): L10n {
  for (const r of REFUGES) {
    if (Math.hypot(p.x - r.pos.x, p.y - r.pos.y) <= 25) {
      const a = r.address;
      return {
        en: `${r.name.en}, ${a.en}`,
        ja: `${a.ja} ${r.name.ja}`,
        'zh-Hans': `${a['zh-Hans']} ${r.name['zh-Hans']}`,
        ko: `${a.ko} ${r.name.ko}`,
        ar: `${r.name.ar}، ${a.ar}`,
      };
    }
  }
  let best: { d: number; street: Street } | null = null;
  for (const e of EDGES) {
    const d = distToSegment(p, node(e.a), node(e.b));
    if (!best || d < best.d) best = { d, street: streetById(e.streetId)! };
  }
  return townAddress(best ? best.street.name : ROAD_NAMES.shore);
}
