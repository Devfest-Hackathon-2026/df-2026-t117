// Alert-change side effects (FB3: F88 / F89, FB2: F85). Mounted once from App.
//  1. Upgrade / raised expected height -> notify again: vibration + browser notification (if allowed).
//     The band at the top of every guidance screen (AlertBand) is the in-app part of the notification.
//     While shaking, only the band is updated (the screen stays on S02, 7.2 rank 1).
//  2. Margin "not enough" for certain while waiting on high ground (not at a designated evacuation site)
//     -> back to evacuation: onHighGround off, "Go higher. NOW" (goHigher 'now'), route from here.
//     Once per trigger only (review rule c): it fires when the condition newly holds, and is checked again
//     only after an upgrade / raised height (the peaks change) or when the location becomes certain.
//     Pressing "On high ground" again under the same conditions therefore stays on S06.
import { useEffect, useRef } from 'react';
import type { AppState, Lang, Point, StatePatch } from '../state/types';
import { actions, useAppState, useDispatch } from '../state/store';
import { deriveMode, isLocationApproximate } from '../state/derive';
import { vibrate } from '../platform/vibrate';
import { useNavigation } from './nav';
import { useMargin } from './margin';

/** Long-short-long pattern for a re-notification. */
export const ALERT_CHANGE_PATTERN: number[] = [400, 120, 400, 120, 400];

const NOTIFY_BODY: Record<Lang, { upgrade: string; raise: string }> = {
  en: { upgrade: 'Tsunami alert upgraded', raise: 'Expected tsunami height raised' },
  ja: { upgrade: '津波の警報が格上げされました', raise: '予想される津波の高さが引き上げられました' },
  'zh-Hans': { upgrade: '海啸警报已升级', raise: '预计海啸高度已上调' },
  ko: { upgrade: '쓰나미 경보가 격상되었습니다', raise: '예상 쓰나미 높이가 상향되었습니다' },
  ar: { upgrade: 'تم رفع مستوى تنبيه التسونامي', raise: 'تم رفع الارتفاع المتوقع للتسونامي' },
};

/** Patch that makes `p` the new route origin (manual pin if one is set, else the simulated GPS position). */
export function rebaseOrigin(state: AppState, p: Point): StatePatch {
  const at = { x: Math.round(p.x * 10) / 10, y: Math.round(p.y * 10) / 10 };
  return state.manualPin ? { manualPin: at, walk: { progressM: 0 } } : { gps: { position: at }, walk: { progressM: 0 } };
}

/**
 * Re-check trigger for the forced return to evacuation: changes only with an upgrade / raised height
 * (the peaks; a downgrade or closing the band does not change them), when the location becomes certain,
 * or with a scenario load / reset (scenarioRun, so a rehearsal of the same scenario fires again).
 */
export function forceTriggerKey(
  state: Pick<AppState, 'peakTsunamiLevel' | 'peakExpectedHeight' | 'scenarioRun'>,
  certainCount: number,
): string {
  return `${state.scenarioRun}|${state.peakTsunamiLevel ?? '-'}|${state.peakExpectedHeight ?? '-'}|${certainCount}`;
}

/**
 * The last fired key, reset when it can no longer apply: every tsunami alert lifted (peaks back to null).
 * A scenario load / reset changes `scenarioRun`, so the key differs and the effect can fire again.
 */
export function nextLastFiredKey(lastFiredKey: string | null, state: Pick<AppState, 'peakTsunamiLevel'>): string | null {
  return state.peakTsunamiLevel === null ? null : lastFiredKey;
}

/** Force evacuate now? Only when the condition holds and this trigger has not fired yet (rule c). */
export function shouldForceEvacuate(condition: boolean, key: string, lastFiredKey: string | null): boolean {
  return condition && key !== lastFiredKey;
}

export function useAlertEffects(): void {
  const state = useAppState();
  const dispatch = useDispatch();
  const nav = useNavigation();
  const margin = useMargin();

  // 1. Re-notify on upgrade / raise (once per change).
  const change = state.alertChange;
  const firedRef = useRef(change);
  const lang = state.lang;
  useEffect(() => {
    if (firedRef.current === change) return;
    firedRef.current = change;
    if (!change || change.kind === 'downgrade') return;
    vibrate(ALERT_CHANGE_PATTERN);
    try {
      if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
        new Notification('TASUKU', { body: NOTIFY_BODY[lang][change.kind] });
      }
    } catch {
      /* ignore */
    }
  }, [change, lang]);

  // Count "location became certain" (approximate -> not approximate): one of the re-check triggers.
  // Counted during render so the key below already reflects it (idempotent on a repeated render).
  const approximate = isLocationApproximate(state);
  const prevApproxRef = useRef(approximate);
  const certainCountRef = useRef(0);
  if (prevApproxRef.current && !approximate) certainCountRef.current += 1;
  prevApproxRef.current = approximate;

  // 2. Not enough margin for certain on high ground -> evacuate again ("Go higher. NOW"), once per trigger.
  const mode = deriveMode(state, nav.inHazardZone);
  const condition = mode === 'safe' && margin.mustMove && !margin.designated;
  const key = forceTriggerKey(state, certainCountRef.current);
  const lastFiredRef = useRef<string | null>(null);
  lastFiredRef.current = nextLastFiredKey(lastFiredRef.current, state);
  useEffect(() => {
    if (!shouldForceEvacuate(condition, key, lastFiredRef.current)) return;
    lastFiredRef.current = key;
    dispatch(
      actions.patch({
        ...rebaseOrigin(state, nav.position),
        onHighGround: false,
        goHigher: 'now',
        guideStep: 'action',
        walk: { progressM: 0, playing: false },
      }),
    );
    // Runs when the condition or the trigger changes; state / position are read at that moment only.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [condition, key, dispatch]);
}
