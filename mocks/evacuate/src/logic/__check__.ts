// Self-check for the route engine (T1). Not imported by the app.
// Run (from mocks/evacuate):
//   npx tsc src/logic/__check__.ts --outDir <tmp> --module commonjs --target es2022 --jsx react-jsx \
//       --esModuleInterop --skipLibCheck --types vite/client
//   NODE_PATH=./node_modules node <tmp>/logic/__check__.js
import { CLOSURES, EDGES, HILL_PARK, TOWN_START } from '../data/town';
import { START_POSITION } from '../state/scenarios';
import { computeRoute, snapToRoad } from './route';
import { findTurns, nextTurnAt, pointAtDistance, pointInHazard, isArrived } from './nav';

const results: string[] = [];
let failed = 0;
function check(name: string, ok: boolean, info = ''): void {
  if (!ok) failed++;
  results.push(`${ok ? 'PASS' : 'FAIL'}  ${name}${info ? `  (${info})` : ''}`);
}
const r1 = (n: number) => Math.round(n * 10) / 10;

check('TOWN_START equals START_POSITION', TOWN_START.x === START_POSITION.x && TOWN_START.y === START_POSITION.y);
check('start lies on a road', snapToRoad(TOWN_START).distM < 0.5, `snap ${r1(snapToRoad(TOWN_START).distM)} m`);
check('start is inside the hazard zone', pointInHazard(TOWN_START));

const online = computeRoute(TOWN_START, { online: true });
check('online route reaches Hill Park', online.refuge.id === HILL_PARK.id, online.refuge.name.en);
check('online route is verified', online.verified);
check('online route avoids closed roads', online.segments.every((s) => !s.closed));
check('route uses stairs (Steps on route)', online.hasStairs);

// Distance at which the route leaves the hazard zone
let exitM = -1;
for (let d = 0; d <= online.totalM; d += 1) {
  if (!pointInHazard(pointAtDistance(online.points, d))) {
    exitM = d;
    break;
  }
}
check('leaves hazard zone within 150 m', exitM >= 0 && exitM <= 150, `exit at ${exitM} m of ${r1(online.totalM)} m`);

const turns = findTurns(online.points);
check('route has a right turn', turns.some((t) => t.direction === 'right'), turns.map((t) => `${t.direction}@${r1(t.atM)}m(${r1(t.angleDeg)}deg)`).join(', '));
const first = nextTurnAt(online.points, 0);
check('first instruction is Right ~40 m', first?.direction === 'right' && Math.abs((first?.distanceM ?? 0) - 40) < 1, `${first?.direction} ${r1(first?.distanceM ?? 0)} m`);
const end = pointAtDistance(online.points, online.totalM);
check('arrival at end of route', isArrived(end, online.refuge) && nextTurnAt(online.points, online.totalM) === null);
check('not arrived at start', !isArrived(pointAtDistance(online.points, 0), online.refuge));

const offline = computeRoute(TOWN_START, { online: false });
check('offline route is flagged unverified', offline.verified === false);
check('offline route reaches a refuge', offline.points.length > 1, offline.refuge.name.en);

// Closures matter online from other origins
const origins = [
  { x: 300, y: 394 },
  { x: 370, y: 100 },
  { x: 200, y: 160 },
  { x: 100, y: 420 },
  { x: 560, y: 300 },
  { x: 30, y: 200 },
];
for (const o of origins) {
  const on = computeRoute(o, { online: true });
  const off = computeRoute(o, { online: false });
  const closedIds = new Set(Object.keys(CLOSURES));
  const usesClosedOnline = on.segments.some((s) => s.edgeId && s.closed && closedIds.size > 0 && s.lengthM > 0 && s.edgeId !== snapToRoad(o).edge.id);
  check(`origin (${o.x},${o.y}) online avoids closures`, !usesClosedOnline, `${on.refuge.name.en} ${r1(on.totalM)} m / offline ${off.refuge.name.en} ${r1(off.totalM)} m${off.closedOnRoute ? ' (offline passes closure)' : ''}`);
}
check('graph has edges', EDGES.length > 20, `${EDGES.length} edges`);

results.push('', `route: ${online.points.map((p) => `(${r1(p.x)},${r1(p.y)})`).join(' -> ')}`);
results.push(`total ${r1(online.totalM)} m, hazard ${r1(online.hazardM)} m, cost ${r1(online.cost)}`);
results.push(failed === 0 ? 'ALL CHECKS PASSED' : `${failed} CHECK(S) FAILED`);
console.log(results.join('\n'));
if (failed > 0) throw new Error(`${failed} check(s) failed`);
