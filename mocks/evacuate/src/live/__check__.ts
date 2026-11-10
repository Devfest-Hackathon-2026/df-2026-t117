// Self-check for live alerts (H2): Firestore document -> store patch -> band (FB3). Not imported by the app.
// Run (from mocks/evacuate), e.g. with tsx:  npx tsx src/live/__check__.ts
import { reducer } from '../state/store';
import { buildScenarioState } from '../state/scenarios';
import type { AppState } from '../state/types';
import { applyOnStart, liveAlertId, liveAlertPatch, liveKey, parseAlertDoc, START_FRESH_MS } from './liveDoc';

const results: string[] = [];
let failed = 0;
function check(name: string, ok: boolean, info = ''): void {
  if (!ok) failed++;
  results.push(`${ok ? 'PASS' : 'FAIL'}  ${name}${info ? `  (${info})` : ''}`);
}

const E = '20261108094000';
function doc(fields: Record<string, unknown>) {
  const d = parseAlertDoc(E, {
    alertId: E,
    eventId: E,
    serial: 1,
    infoType: '発表',
    jmaStatus: '訓練',
    areaId: 'minato-bay',
    issuedAt: '2026-11-08T09:42:00+09:00',
    updatedAt: { toMillis: () => 1_000 },
    ...fields,
  });
  if (!d) throw new Error(`invalid doc ${JSON.stringify(fields)}`);
  return d;
}
function apply(s: AppState, fields: Record<string, unknown>): AppState {
  const p = liveAlertPatch(s, doc(fields));
  return p ? reducer(s, { type: 'patch', patch: p }) : s;
}

// Parsing
check('rejects unknown kind', parseAlertDoc(E, { kind: 'tsunami-info', serial: 1 }) === null);
check('rejects warning without level', parseAlertDoc(E, { kind: 'tsunami-warning', serial: 1, level: null }) === null);
check('rejects cleared with level', parseAlertDoc(E, { kind: 'cleared', serial: 1, level: 'warning' }) === null);
check('reads updatedAt Timestamp', doc({ kind: 'tsunami-warning', level: 'warning' }).updatedAtMs === 1_000);
check('unknown expectedHeight -> null', doc({ kind: 'tsunami-warning', level: 'warning', expectedHeight: 4 }).expectedHeight === null);
check('key = EventID|Serial|InfoType', liveKey(doc({ kind: 'cleared', level: null, serial: 5 })) === `${E}|5|発表`);

// Start-up filter
const active = doc({ kind: 'tsunami-warning', level: 'warning', updatedAt: { toMillis: () => 10_000_000 } });
check('fresh active alert applies at start', applyOnStart(active, 10_000_000 + 60_000));
check('old active alert does not apply at start', !applyOnStart(active, 10_000_000 + START_FRESH_MS + 1));
check('cleared does not apply at start', !applyOnStart(doc({ kind: 'cleared', level: null }), 1_000));

// Normal mode (no alerts) -> warning -> upgrade -> raise -> downgrade -> cleared
let s = buildScenarioState('1', 'en');
s = { ...s, alerts: [] };
s = apply(s, { kind: 'tsunami-warning', level: 'warning', expectedHeight: 3, arrivalTime: '2026-11-08T10:10:00+09:00' });
const t1 = s.alerts.find((a) => a.type === 'tsunami');
check('warning creates the tsunami alert', t1?.level === 'warning' && t1.expectedHeight === 3 && t1.id === liveAlertId(E));
check('arrival time kept', t1?.arrivalTime === '2026-11-08T10:10:00+09:00');
check('new alert shows no band', s.alertChange === null);
check('lastFetchAt refreshed', s.lastFetchAt === s.now);

s = apply(s, { kind: 'major-tsunami-warning', level: 'emergency', expectedHeight: 5, serial: 2 });
check('upgrade -> band upgrade', s.alertChange?.kind === 'upgrade' && s.alertChange.level === 'emergency');
s = apply(s, { kind: 'major-tsunami-warning', level: 'emergency', expectedHeight: 'over10', serial: 3 });
check('height raised -> band raise', s.alertChange?.kind === 'raise' && s.alertChange.expectedHeight === 'over10');
s = apply(s, { kind: 'tsunami-advisory', level: 'advisory', expectedHeight: 1, serial: 4 });
check('downgrade -> band downgrade', s.alertChange?.kind === 'downgrade');
check('peak level kept after downgrade (F8A)', s.peakTsunamiLevel === 'emergency' && s.peakExpectedHeight === 'over10');
s = apply(s, { kind: 'cleared', level: null, serial: 5 });
check('cleared lifts every alert', s.alerts.length === 0 && s.peakTsunamiLevel === null && s.alertChange === null);

// Missing expected height -> demo default for the level
let d = buildScenarioState('1', 'en');
d = apply({ ...d, alerts: [] }, { kind: 'major-tsunami-warning', level: 'emergency' });
check('no expectedHeight -> default for level', d.alerts[0]?.expectedHeight === 'huge');

// Scenario 1 (earthquake + tsunami warning 3 m): a live major warning replaces the scenario's tsunami alert
let m = buildScenarioState('1', 'en');
check('scenario 1 has an earthquake alert', m.alerts.some((a) => a.type === 'earthquake'));
const eqBefore = m.alerts.some((a) => a.type === 'earthquake');
m = apply(m, { kind: 'major-tsunami-warning', level: 'emergency', expectedHeight: 5 });
check('replaces the scenario tsunami alert (one tsunami alert)', m.alerts.filter((a) => a.type === 'tsunami').length === 1);
check('keeps the earthquake alert', m.alerts.some((a) => a.type === 'earthquake') === eqBefore);
check('scenario warning -> live major = upgrade band', m.alertChange?.kind === 'upgrade');

// Cancellation only removes the alert of the same EventID
const other = liveAlertPatch(m, { ...doc({ kind: 'cancelled', level: null, infoType: '取消' }), eventId: 'other' });
check('cancel of another event does nothing', other === null);
m = apply(m, { kind: 'cancelled', level: null, infoType: '取消' });
check('cancel removes that tsunami alert only', !m.alerts.some((a) => a.type === 'tsunami') && m.alerts.some((a) => a.type === 'earthquake') === eqBefore);

for (const r of results) console.log(r);
console.log(failed === 0 ? `\nAll ${results.length} checks passed.` : `\n${failed} of ${results.length} checks FAILED.`);
if (failed > 0) throw new Error('live alerts self-check failed');
