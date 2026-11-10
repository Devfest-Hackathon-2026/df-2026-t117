// Fictional mock alerts. NOT real JMA data. Area name is fictional ("（架空）").
import type { Alert, AlertLevel, ExpectedHeight, L10n } from '../state/types';
import { jstOnDemoDay } from '../state/time';

export const MINATO_BAY_AREA: L10n = {
  en: 'Minato Bay (fictional)',
  ja: 'みなと湾（架空）',
  'zh-Hans': '港湾（虚构）',
  ko: '미나토만(가상)',
  ar: 'خليج ميناتو (خيالي)',
};

/** Issued 09:40 JST on the demo day. */
export const ALERT_ISSUED_AT = jstOnDemoDay(9, 40);

export const ALERT_EARTHQUAKE: Alert = {
  id: 'eq-20261108-0940',
  type: 'earthquake',
  level: 'warning',
  area: MINATO_BAY_AREA,
  issuedAt: ALERT_ISSUED_AT,
  source: 'JMA',
};

export const ALERT_TSUNAMI: Alert = {
  id: 'tsunami-20261108-0940',
  type: 'tsunami',
  level: 'warning',
  area: MINATO_BAY_AREA,
  issuedAt: ALERT_ISSUED_AT,
  source: 'JMA',
  expectedHeight: 3,
};

/** Main scenario alerts: earthquake + tsunami warning. */
export const MAIN_ALERTS: Alert[] = [ALERT_EARTHQUAKE, ALERT_TSUNAMI];

/** Typical expected height for a tsunami level, used when the demo panel changes the level. */
export const DEFAULT_HEIGHT: Record<AlertLevel, ExpectedHeight> = { advisory: 1, warning: 3, emergency: 'huge' };

/** Copy of an alert with a different level (for the demo panel's level switch). */
export function withLevel(alert: Alert, level: AlertLevel): Alert {
  return alert.type === 'tsunami' ? { ...alert, level, expectedHeight: DEFAULT_HEIGHT[level] } : { ...alert, level };
}
