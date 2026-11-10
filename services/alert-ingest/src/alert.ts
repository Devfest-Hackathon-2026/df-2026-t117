// 電文から「みなと湾」の警報の状態を作る。
import type { Config } from './config.js';
import {
  levelOf,
  type AlertKind,
  type AlertLevel,
  type ForecastItem,
  type InfoType,
  type TsunamiHeight,
  type TsunamiReport,
} from './jma.js';

export type StateKind = AlertKind | 'cancelled';

/** 前の状態からの変化。 */
export type AlertChange =
  | 'new' // はじめての警報（または解除・取消のあとの再発表）
  | 'upgrade' // 格上げ（例: 津波警報 → 大津波警報）
  | 'downgrade' // 格下げ（例: 津波警報 → 津波注意報）
  | 'height-up' // 種別は同じで、予想される高さの引き上げ
  | 'height-down' // 種別は同じで、予想される高さの引き下げ
  | 'same' // 変化なし（続報・訂正）
  | 'cleared' // 解除
  | 'cancelled'; // 取消

/** alerts/{EventID} に書く、モックが購読する最新の状態。 */
export interface AlertState {
  alertId: string;
  eventId: string;
  serial: number;
  infoType: InfoType;
  jmaStatus: string;
  kind: StateKind;
  level: AlertLevel | null;
  change: AlertChange;
  previousKind: StateKind | null;
  previousLevel: AlertLevel | null;
  maxHeight: TsunamiHeight | null;
  /**
   * 予想される高さ（モックの `expectedHeight` と同じ形。requirements.md F84）。
   * 気象庁の区分 1 / 3 / 5 / 10（m）、`over10`（10m 超）、`huge`（巨大）、`high`（高い）。
   * 区分外の値は、それ以上の最小の区分に切り上げる（元の値は maxHeight）。高さの発表がなければ null。
   */
  expectedHeight: ExpectedHeight | null;
  arrivalTime: string | null;
  arrivalCondition: string | null;
  issuedAt: string;
  areaId: string;
  areaName: string;
  /** 判断の元にした電文の津波予報区。 */
  sourceAreas: { code: string; name: string; kindName: string }[];
  headline: string | null;
}

/** mocks/evacuate/src/state/types.ts の ExpectedHeight と同じ。 */
export type ExpectedHeight = 1 | 3 | 5 | 10 | 'over10' | 'huge' | 'high';

const HEIGHT_BUCKETS = [1, 3, 5, 10] as const;

export function expectedHeightOf(h: TsunamiHeight | null): ExpectedHeight | null {
  if (!h) return null;
  if (h.label === '巨大') return 'huge';
  if (h.label === '高い') return 'high';
  if (h.meters === null) return null;
  if (h.over && h.meters >= 10) return 'over10';
  // 区分外の値（例: 3.5）は、それ以上の最小の区分に切り上げる。10 を超えれば over10。
  return HEIGHT_BUCKETS.find((b) => h.meters! <= b) ?? 'over10';
}

/** 状態の一部（前の状態として読むもの）。 */
export type PreviousState = Pick<AlertState, 'serial' | 'kind' | 'level' | 'maxHeight'>;

const LEVEL_RANK: Record<AlertLevel, number> = { advisory: 1, warning: 2, emergency: 3 };

function rank(level: AlertLevel | null): number {
  return level === null ? 0 : LEVEL_RANK[level];
}

/**
 * 高さの比較用の値（m）。FB2（requirements.md F84）の決定に合わせ、
 * 「巨大」は 10 m 超、「高い」は 3 m として扱う。「10m 超」は 10.5。
 */
export function heightRank(h: TsunamiHeight | null): number {
  if (!h) return 0;
  if (h.label === '巨大') return 10.5;
  if (h.label === '高い') return 3;
  if (h.meters === null) return 0;
  return h.meters + (h.over ? 0.5 : 0);
}

/** 対象の予報区の項目を選ぶ。 */
export function relevantItems(report: TsunamiReport, config: Config): ForecastItem[] {
  if (config.demoAreaOverride) return report.items;
  const codes = new Set(config.targetAreaCodes);
  return report.items.filter((i) => codes.has(i.areaCode));
}

/** 項目のうち、最も重いもの（レベル → 高さの順）。 */
function strongest(items: ForecastItem[]): ForecastItem | null {
  let best: ForecastItem | null = null;
  for (const item of items) {
    if (!best) {
      best = item;
      continue;
    }
    const d = rank(levelOf(item.kind)) - rank(levelOf(best.kind));
    if (d > 0 || (d === 0 && heightRank(item.maxHeight) > heightRank(best.maxHeight))) best = item;
  }
  return best;
}

export function computeChange(
  kind: StateKind,
  level: AlertLevel | null,
  height: TsunamiHeight | null,
  previous: PreviousState | null,
): AlertChange {
  if (kind === 'cancelled') return 'cancelled';
  if (kind === 'cleared') return 'cleared';
  if (!previous || previous.level === null) return 'new';
  const d = rank(level) - rank(previous.level);
  if (d > 0) return 'upgrade';
  if (d < 0) return 'downgrade';
  const h = heightRank(height) - heightRank(previous.maxHeight);
  if (h > 0) return 'height-up';
  if (h < 0) return 'height-down';
  return 'same';
}

/**
 * 電文と前の状態から、新しい状態を作る。
 * previous は「通知済みの基準」（FCM への送信に成功した最新の状態）。change はこれと比べる。
 * 対象の予報区が電文に含まれないときは null（配信しない）。
 */
export function buildAlertState(
  report: TsunamiReport,
  config: Config,
  previous: PreviousState | null,
): AlertState | null {
  const base = {
    alertId: report.eventId,
    eventId: report.eventId,
    serial: report.serial,
    infoType: report.infoType,
    jmaStatus: report.status,
    previousKind: previous?.kind ?? null,
    previousLevel: previous?.level ?? null,
    issuedAt: report.reportDateTime,
    areaId: config.areaId,
    areaName: config.areaName,
    headline: report.headline,
  };

  if (report.infoType === '取消') {
    return {
      ...base,
      kind: 'cancelled',
      level: null,
      change: 'cancelled',
      maxHeight: null,
      expectedHeight: null,
      arrivalTime: null,
      arrivalCondition: null,
      sourceAreas: [],
    };
  }

  const items = relevantItems(report, config);
  const top = strongest(items);
  if (!top) return null;

  const kind = top.kind;
  const level = levelOf(kind);
  // 町の状態は、最も重い項目の種別・高さ・到達予想時刻で表す。解除のときは高さ・到達時刻を持たない。
  const active = level === null ? [] : items.filter((i) => levelOf(i.kind) !== null);
  const maxHeight = level === null ? null : top.maxHeight;

  return {
    ...base,
    kind,
    level,
    change: computeChange(kind, level, maxHeight, previous),
    maxHeight,
    expectedHeight: expectedHeightOf(maxHeight),
    arrivalTime: level === null ? null : top.firstWave.arrivalTime,
    arrivalCondition: level === null ? null : top.firstWave.condition,
    sourceAreas: (level === null ? items : active).map((i) => ({
      code: i.areaCode,
      name: i.areaName,
      kindName: i.kindName,
    })),
  };
}
