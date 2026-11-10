// Demo-only URL query to open a given state directly (used for screenshots / rehearsals).
// Harmless: once on load it applies the same patches the demo panel can apply. Unknown keys are ignored.
//   ?scenario=3b         load a scenario (1, 2, 3, 3b, 4, 5)
//   &lang=ar             en | ja | zh-Hans | ko | ar
//   &raised=1            deviceRaised
//   &online=0            online
//   &acc=180             gps.accuracyM
//   &heading=30          ar.headingAccuracyDeg
//   &tracking=0          ar.tracking
//   &found=0             ar.landmarkFound
//   &detect=1            ar.showDetection
//   &progress=120        walk.progressM
//   &step=nav|action     guideStep
//   &open=S07            push a sub screen on the overlay stack
import { useEffect } from 'react';
import type { ScreenId, StatePatch } from '../state/types';
import { actions, useDispatch } from '../state/store';
import { isLang } from '../i18n';
import { SCREEN_IDS } from '../screens/meta';

export function useDevQuery(): void {
  const dispatch = useDispatch();
  useEffect(() => {
    if (typeof window === 'undefined' || !window.location.search) return;
    const q = new URLSearchParams(window.location.search);
    const num = (k: string): number | undefined => {
      const v = q.get(k);
      if (v === null || v.trim() === '') return undefined;
      const n = Number(v);
      return Number.isFinite(n) ? n : undefined;
    };
    const bool = (k: string): boolean | undefined => (q.has(k) ? q.get(k) === '1' || q.get(k) === 'true' : undefined);

    const scenario = q.get('scenario');
    if (scenario) dispatch(actions.loadScenario(scenario));

    const p: StatePatch = {};
    const lang = q.get('lang');
    if (lang && isLang(lang)) p.lang = lang;
    const raised = bool('raised');
    if (raised !== undefined) p.deviceRaised = raised;
    const online = bool('online');
    if (online !== undefined) p.online = online;
    const step = q.get('step');
    if (step === 'nav' || step === 'action') p.guideStep = step;
    const acc = num('acc');
    if (acc !== undefined) p.gps = { accuracyM: acc };
    const progress = num('progress');
    if (progress !== undefined) p.walk = { progressM: Math.max(0, progress) };
    const ar: NonNullable<StatePatch['ar']> = {};
    const heading = num('heading');
    if (heading !== undefined) ar.headingAccuracyDeg = heading;
    const tracking = bool('tracking');
    if (tracking !== undefined) ar.tracking = tracking;
    const found = bool('found');
    if (found !== undefined) ar.landmarkFound = found;
    const detect = bool('detect');
    if (detect !== undefined) ar.showDetection = detect;
    if (Object.keys(ar).length > 0) p.ar = ar;
    if (Object.keys(p).length > 0) dispatch(actions.patch(p));

    const open = q.get('open');
    if (open && (SCREEN_IDS as string[]).includes(open)) dispatch(actions.navigate(open as ScreenId));
  }, [dispatch]);
}
