// 気象庁防災情報 XML（津波警報・注意報・予報 VTSE41）の解析。
// 参考: 気象庁「防災情報 XML フォーマット」地震火山関連の解説資料。
// 電文全体ではなく、配信の判断に必要な要素だけを読む。
import { XMLParser } from 'fast-xml-parser';

/** 電文のタイトル（Control/Title）。VTSE41 は末尾に a が付く版もある。 */
const TSUNAMI_WARNING_TITLE = /^津波警報・注意報・予報/;

export type InfoType = '発表' | '訂正' | '取消';

/** サービス内での警報の種別。 */
export type AlertKind =
  | 'major-tsunami-warning' // 大津波警報
  | 'tsunami-warning' // 津波警報
  | 'tsunami-advisory' // 津波注意報
  | 'cleared'; // 解除・津波予報・津波なし

/** モック（mocks/evacuate/src/state/types.ts の AlertLevel）と同じ段階。解除は null。 */
export type AlertLevel = 'advisory' | 'warning' | 'emergency';

export interface TsunamiHeight {
  /** 数値で発表された高さ（m）。「巨大」「高い」など定性的な発表では null。 */
  meters: number | null;
  /** 定性的な発表（「巨大」「高い」）。数値の発表では null。 */
  label: '巨大' | '高い' | null;
  /** 電文の description 属性そのまま（例: 「１０ｍ超」「巨大」）。 */
  description: string | null;
  /** 「10m 超」のように、値より高いことを示すとき true。 */
  over: boolean;
}

export interface FirstWave {
  /** 到達予想時刻（ISO 8601、電文の時差表記のまま）。 */
  arrivalTime: string | null;
  /** 「ただちに津波来襲と予測」「第１波の到達を確認」など。 */
  condition: string | null;
}

export interface ForecastItem {
  areaCode: string;
  areaName: string;
  kindCode: string;
  kindName: string;
  kind: AlertKind;
  lastKindCode: string | null;
  lastKindName: string | null;
  firstWave: FirstWave;
  maxHeight: TsunamiHeight | null;
}

export interface TsunamiReport {
  controlTitle: string;
  /** 運用種別（通常 / 訓練 / 試験）。 */
  status: string;
  /** Control/DateTime（電文の作成時刻、UTC）。 */
  createdAt: string;
  /** Head/ReportDateTime（発表時刻）。 */
  reportDateTime: string;
  eventId: string;
  serial: number;
  infoType: InfoType;
  headline: string | null;
  items: ForecastItem[];
}

export class JmaParseError extends Error {
  override name = 'JmaParseError';
}

/** 津波警報・注意報・予報ではない電文（受け取るが配信しない）。 */
export class UnsupportedReportError extends Error {
  override name = 'UnsupportedReportError';
  constructor(public readonly title: string) {
    super(`対象外の電文です: ${title}`);
  }
}

const ARRAY_TAGS = new Set(['Item', 'Area', 'Information']);

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  removeNSPrefix: true,
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  isArray: (name) => ARRAY_TAGS.has(name),
});

type Node = Record<string, unknown>;

function isNode(v: unknown): v is Node {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 要素の文字列。属性付きの要素は #text を読む。 */
function text(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  if (isNode(v)) {
    const t = v['#text'];
    return t === undefined || t === null ? null : String(t);
  }
  return null;
}

function attr(v: unknown, name: string): string | null {
  if (!isNode(v)) return null;
  const a = v[`@_${name}`];
  return a === undefined || a === null ? null : String(a);
}

function child(v: unknown, name: string): unknown {
  return isNode(v) ? v[name] : undefined;
}

function children(v: unknown, name: string): unknown[] {
  const c = child(v, name);
  if (c === undefined || c === null) return [];
  return Array.isArray(c) ? c : [c];
}

function required(v: unknown, path: string): string {
  const t = text(v);
  if (t === null || t === '') throw new JmaParseError(`${path} がありません`);
  return t;
}

/**
 * 警報等情報要素の「津波警報・注意報・予報」のコード表。
 * 52/53 大津波警報、51 津波警報、62 津波注意報、50 警報解除、60 津波注意報解除、
 * 71〜73 津波予報、00 津波なし。
 */
export function kindFromCode(code: string, name: string): AlertKind {
  switch (code) {
    case '52':
    case '53':
      return 'major-tsunami-warning';
    case '51':
      return 'tsunami-warning';
    case '62':
      return 'tsunami-advisory';
    case '00':
    case '50':
    case '60':
    case '71':
    case '72':
    case '73':
      return 'cleared';
  }
  // 未知のコードは名前で判断する。
  if (name.includes('解除')) return 'cleared';
  if (name.includes('大津波警報')) return 'major-tsunami-warning';
  if (name.includes('津波警報')) return 'tsunami-warning';
  if (name.includes('津波注意報')) return 'tsunami-advisory';
  return 'cleared';
}

export function levelOf(kind: AlertKind): AlertLevel | null {
  switch (kind) {
    case 'major-tsunami-warning':
      return 'emergency';
    case 'tsunami-warning':
      return 'warning';
    case 'tsunami-advisory':
      return 'advisory';
    case 'cleared':
      return null;
  }
}

/** 全角の英数字・記号を半角に直す（「１０ｍ超」→「10m超」）。 */
export function toHalfWidth(s: string): string {
  return s.replace(/[\uFF01-\uFF5E]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0));
}

function metersFromDescription(description: string | null): number | null {
  if (!description) return null;
  const m = /(\d+(?:\.\d+)?)\s*m/i.exec(toHalfWidth(description));
  return m ? Number(m[1]) : null;
}

function parseHeight(maxHeight: unknown): TsunamiHeight | null {
  const h = child(maxHeight, 'TsunamiHeight');
  if (h === undefined || h === null) return null;
  const description = attr(h, 'description');
  const condition = attr(h, 'condition');
  const raw = text(h);
  const n = raw === null || raw === '' ? NaN : Number(raw);
  // 本文に数値がなく、description（例: 「１０ｍ超」）にだけ数字があるときは、そこから読む。
  const meters = Number.isFinite(n) ? n : metersFromDescription(description);
  let label: TsunamiHeight['label'] = null;
  if (meters === null && description) {
    if (description.includes('巨大')) label = '巨大';
    else if (description.includes('高い')) label = '高い';
  }
  const over = condition === '超' || (description?.endsWith('超') ?? false);
  return { meters, label, description, over };
}

function parseItem(item: unknown): ForecastItem {
  const area = child(item, 'Area');
  const areaNode = Array.isArray(area) ? area[0] : area;
  const category = child(item, 'Category');
  const kind = child(category, 'Kind');
  const lastKind = child(category, 'LastKind');
  const kindCode = required(child(kind, 'Code'), 'Item/Category/Kind/Code');
  const kindName = text(child(kind, 'Name')) ?? '';
  const first = child(item, 'FirstHeight');
  return {
    areaCode: required(child(areaNode, 'Code'), 'Item/Area/Code'),
    areaName: text(child(areaNode, 'Name')) ?? '',
    kindCode,
    kindName,
    kind: kindFromCode(kindCode, kindName),
    lastKindCode: text(child(lastKind, 'Code')),
    lastKindName: text(child(lastKind, 'Name')),
    firstWave: {
      arrivalTime: text(child(first, 'ArrivalTime')),
      condition: text(child(first, 'Condition')),
    },
    maxHeight: parseHeight(child(item, 'MaxHeight')),
  };
}

/**
 * 電文を解析する。
 * - XML として読めない・必須の要素がないときは JmaParseError
 * - 津波警報・注意報・予報でない電文は UnsupportedReportError
 */
export function parseTsunamiReport(xml: string): TsunamiReport {
  // DTD（外部実体・実体展開）は気象庁の電文に含まれないので、受け付けない。
  if (/<!DOCTYPE|<!ENTITY/i.test(xml)) {
    throw new JmaParseError('DOCTYPE を含む XML は受け付けません');
  }
  let doc: unknown;
  try {
    doc = parser.parse(xml, true);
  } catch (e) {
    throw new JmaParseError(`XML を解析できません: ${(e as Error).message}`);
  }
  const report = child(doc, 'Report');
  if (!isNode(report)) throw new JmaParseError('Report 要素がありません');

  const control = child(report, 'Control');
  const head = child(report, 'Head');
  const body = child(report, 'Body');

  const controlTitle = required(child(control, 'Title'), 'Control/Title');
  if (!TSUNAMI_WARNING_TITLE.test(controlTitle)) {
    throw new UnsupportedReportError(controlTitle);
  }

  const infoType = required(child(head, 'InfoType'), 'Head/InfoType');
  if (infoType !== '発表' && infoType !== '訂正' && infoType !== '取消') {
    throw new JmaParseError(`InfoType が不正です: ${infoType}`);
  }
  const serialText = required(child(head, 'Serial'), 'Head/Serial');
  const serial = Number(serialText);
  if (!Number.isInteger(serial) || serial < 0) {
    throw new JmaParseError(`Serial が不正です: ${serialText}`);
  }
  const eventId = required(child(head, 'EventID'), 'Head/EventID');
  if (!/^[0-9A-Za-z_-]{1,64}$/.test(eventId)) {
    // Firestore のドキュメント ID・FCM の collapse key に使うので、安全な文字だけにする。
    throw new JmaParseError(`EventID が不正です: ${eventId}`);
  }

  const forecast = child(child(body, 'Tsunami'), 'Forecast');
  const items = children(forecast, 'Item').map(parseItem);

  if (infoType !== '取消' && items.length === 0) {
    throw new JmaParseError('Body/Tsunami/Forecast/Item がありません');
  }

  return {
    controlTitle,
    status: required(child(control, 'Status'), 'Control/Status'),
    createdAt: required(child(control, 'DateTime'), 'Control/DateTime'),
    reportDateTime: required(child(head, 'ReportDateTime'), 'Head/ReportDateTime'),
    eventId,
    serial,
    infoType,
    headline: text(child(child(head, 'Headline'), 'Text')),
    items,
  };
}
