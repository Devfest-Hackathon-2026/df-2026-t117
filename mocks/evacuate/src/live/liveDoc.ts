// Live alerts (H2): turn `alerts/{EventID}` documents written by services/alert-ingest into the same store
// actions as the demo panel's alert controls (level / expected height / upgrade / downgrade / lift).
// Pure functions only (no Firebase import), so they can be checked without the SDK.
import type { Alert, AlertLevel, AppState, ExpectedHeight, StatePatch } from '../state/types';
import { ALERT_TSUNAMI, DEFAULT_HEIGHT } from '../data/alerts';

export type LiveKind = 'major-tsunami-warning' | 'tsunami-warning' | 'tsunami-advisory' | 'cleared' | 'cancelled';
export type InfoType = '発表' | '訂正' | '取消';

/** The fields of `alerts/{EventID}` the mock uses (services/alert-ingest/README.md). */
export interface LiveAlertDoc {
  eventId: string;
  serial: number;
  infoType: InfoType;
  kind: LiveKind;
  /** null when cleared / cancelled */
  level: AlertLevel | null;
  change: string;
  expectedHeight: ExpectedHeight | null;
  arrivalTime: string | null;
  arrivalCondition: string | null;
  issuedAt: string | null;
  areaId: string;
  jmaStatus: string | null;
  /** updatedAt (server write time) in epoch ms, 0 if unknown */
  updatedAtMs: number;
}

const KINDS: readonly LiveKind[] = ['major-tsunami-warning', 'tsunami-warning', 'tsunami-advisory', 'cleared', 'cancelled'];
const LEVELS: readonly AlertLevel[] = ['advisory', 'warning', 'emergency'];
const HEIGHTS: readonly ExpectedHeight[] = [1, 3, 5, 10, 'over10', 'huge', 'high'];
const INFO_TYPES: readonly InfoType[] = ['発表', '訂正', '取消'];

/** Live tsunami alerts get this id, so a cancellation can be matched to the alert it retracts. */
export function liveAlertId(eventId: string): string {
  return `jma-${eventId}`;
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v !== '' ? v : null;
}

function millis(v: unknown): number {
  if (typeof v === 'number') return v;
  if (v && typeof v === 'object' && typeof (v as { toMillis?: unknown }).toMillis === 'function') {
    return (v as { toMillis: () => number }).toMillis();
  }
  if (v instanceof Date) return v.getTime();
  return 0;
}

/** Validate a Firestore document. Returns null for anything the mock cannot use. */
export function parseAlertDoc(id: string, data: Record<string, unknown>): LiveAlertDoc | null {
  const eventId = str(data.eventId) ?? id;
  const kind = data.kind as LiveKind;
  if (!KINDS.includes(kind) || typeof data.serial !== 'number') return null;
  const level = LEVELS.includes(data.level as AlertLevel) ? (data.level as AlertLevel) : null;
  // A warning / advisory must carry a level; cleared / cancelled never do.
  if ((kind === 'cleared' || kind === 'cancelled') !== (level === null)) return null;
  return {
    eventId,
    serial: data.serial,
    infoType: INFO_TYPES.includes(data.infoType as InfoType) ? (data.infoType as InfoType) : '発表',
    kind,
    level,
    change: str(data.change) ?? 'new',
    expectedHeight: HEIGHTS.includes(data.expectedHeight as ExpectedHeight) ? (data.expectedHeight as ExpectedHeight) : null,
    arrivalTime: str(data.arrivalTime),
    arrivalCondition: str(data.arrivalCondition),
    issuedAt: str(data.issuedAt),
    areaId: str(data.areaId) ?? '',
    jmaStatus: str(data.jmaStatus),
    updatedAtMs: millis(data.updatedAt),
  };
}

/** One bulletin = EventID + Serial + InfoType. Each is applied to the store once. */
export function liveKey(d: Pick<LiveAlertDoc, 'eventId' | 'serial' | 'infoType'>): string {
  return `${d.eventId}|${d.serial}|${d.infoType}`;
}

/** When the subscription starts, only an active alert this recent is applied (older ones are just marked seen). */
export const START_FRESH_MS = 60 * 60 * 1000;

/** Apply the document found when the subscription starts? Only an active alert written within START_FRESH_MS. */
export function applyOnStart(d: LiveAlertDoc, realNowMs: number): boolean {
  return d.level !== null && d.updatedAtMs > 0 && realNowMs - d.updatedAtMs <= START_FRESH_MS;
}

/**
 * The store patch for a live bulletin, using the same shape as the demo panel's controls, so the store
 * detects upgrade / raise / downgrade itself (trackAlertChanges, FB3) and shows the band:
 * - warning / advisory: replace the tsunami alert (level, expected height, arrival) like "格上げする" etc.
 *   Without an expected height the demo default for the level is used.
 * - cleared: lift every alert, like "解除する".
 * - cancelled: remove the tsunami alert only if it came from the same EventID; otherwise nothing (null).
 * The alert's issuedAt is the virtual clock (as the demo panel does), so the demo timeline stays consistent.
 * A received bulletin is also a successful fetch (lastFetchAt).
 */
export function liveAlertPatch(state: Pick<AppState, 'alerts' | 'now'>, d: LiveAlertDoc): StatePatch | null {
  const tsunami = state.alerts.find((a) => a.type === 'tsunami');
  const rest = state.alerts.filter((a) => a.type !== 'tsunami');
  if (d.kind === 'cleared') return { alerts: [], lastFetchAt: state.now };
  if (d.kind === 'cancelled') {
    if (tsunami?.id !== liveAlertId(d.eventId)) return null;
    return { alerts: rest, lastFetchAt: state.now };
  }
  if (d.level === null) return null;
  const next: Alert = {
    ...(tsunami ?? ALERT_TSUNAMI),
    id: liveAlertId(d.eventId),
    level: d.level,
    expectedHeight: d.expectedHeight ?? DEFAULT_HEIGHT[d.level],
    issuedAt: state.now,
    arrivalTime: d.arrivalTime ?? undefined,
    arrivalCondition: d.arrivalCondition ?? undefined,
  };
  return { alerts: [...rest, next], lastFetchAt: state.now };
}

/** "HH:MM" of an ISO time as announced (JST offset kept), e.g. "2026-11-08T10:05:00+09:00" -> "10:05". */
export function hhmm(iso: string | null | undefined): string | null {
  const m = iso ? /T(\d{2}):(\d{2})/.exec(iso) : null;
  return m ? `${m[1]}:${m[2]}` : null;
}
