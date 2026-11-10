// App store: React Context + useReducer (implementation-plan.md 3.1).
import { createContext, useContext, useReducer, type Dispatch, type ReactNode } from 'react';
import type { AlertChange, AppState, ScreenId, StatePatch } from './types';
import { applyPatch, buildScenarioState, DEFAULT_SCENARIO_ID } from './scenarios';
import { loadLang } from '../i18n/detect';
import { evacuationEscalated, levelRank, mostSevere, resolveScreen } from './derive';
import { heightRank, maxHeight } from '../logic/heights';

/** Base walking speed (m/s) for walk.speed = 1 (requirements 7.5). */
export const WALK_BASE_MPS = 1.5;
/** While online (and the feed is not paused), `tick` refreshes lastFetchAt once per virtual minute (simulated polling). */
export const FETCH_INTERVAL_MS = 60 * 1000;

export type Action =
  /** Partial update. gps / walk / ar are shallow-merged.
   *  Shaking turning on, or an evacuation alert becoming active / more severe / its expected height raised,
   *  closes the overlay stack (unless the patch sets `overlay` itself) so the guidance screen is shown.
   *  Changes of the tsunami alert are tracked by trackAlertChanges (F88 / F89 / F8A). */
  | { type: 'patch'; patch: StatePatch }
  /** Reset to a scenario's initial state (keeps current language, dialerEnabled and autoSpeak). */
  | { type: 'loadScenario'; id: string }
  /** Push a sub screen on the overlay stack (no duplicate if it is already on top). */
  | { type: 'navigate'; screen: ScreenId }
  /** Pop the overlay stack. If it is empty: lower the device if raised, else nav -> action. */
  | { type: 'back' }
  /** Advance virtual clock by dtMs and the walk by WALK_BASE_MPS * speed while playing
   *  (the walk holds while S07 / A01 is shown: route guidance is paused there).
   *  While online and !feedPaused, also refreshes lastFetchAt every FETCH_INTERVAL_MS. */
  | { type: 'tick'; dtMs: number }
  /** Show a toast (null hides it). Toast auto-hides after ~2.5 s. */
  | { type: 'showToast'; message: string | null };

/** Action creators (optional sugar): dispatch(actions.navigate('S09')) */
export const actions = {
  patch: (patch: StatePatch): Action => ({ type: 'patch', patch }),
  loadScenario: (id: string): Action => ({ type: 'loadScenario', id }),
  navigate: (screen: ScreenId): Action => ({ type: 'navigate', screen }),
  back: (): Action => ({ type: 'back' }),
  tick: (dtMs: number): Action => ({ type: 'tick', dtMs }),
  showToast: (message: string | null): Action => ({ type: 'showToast', message }),
};

/**
 * Compare the tsunami alert before / after a patch (FB3):
 * - upgrade (level up) / raise (expected height up) / downgrade (level down) -> `alertChange` (the band, F88).
 *   A new alert (none before) or a lowered height at the same level shows no band.
 * - keeps the highest level / height announced so far (a downgrade never loosens guidance, F8A)
 * - every tsunami alert lifted -> peaks, band and the evacuation progress (high ground, nav step) reset.
 * - arriving on high ground clears `goHigher`.
 */
export function trackAlertChanges(prev: AppState, next: AppState): AppState {
  let out = next;
  if (next.onHighGround && !prev.onHighGround && next.goHigher) out = { ...out, goHigher: null };
  if (prev.alerts === next.alerts) return out;
  const before = mostSevere(prev.alerts, 'tsunami');
  const after = mostSevere(next.alerts, 'tsunami');
  if (!after) {
    if (!before) return out;
    return { ...out, peakTsunamiLevel: null, peakExpectedHeight: null, alertChange: null, goHigher: null, onHighGround: false, guideStep: 'action' };
  }
  const hAfter = after.expectedHeight ?? null;
  let change: AlertChange['kind'] | null = null;
  if (before) {
    const dl = levelRank(after.level) - levelRank(before.level);
    if (dl > 0) change = 'upgrade';
    else if (dl < 0) change = 'downgrade';
    else if (hAfter !== null && (before.expectedHeight === undefined || heightRank(hAfter) > heightRank(before.expectedHeight))) change = 'raise';
  }
  const peakLevel = prev.peakTsunamiLevel && levelRank(prev.peakTsunamiLevel) > levelRank(after.level) ? prev.peakTsunamiLevel : after.level;
  return {
    ...out,
    peakTsunamiLevel: peakLevel,
    peakExpectedHeight: maxHeight(prev.peakExpectedHeight, hAfter),
    alertChange: change ? { kind: change, level: after.level, expectedHeight: hAfter, at: next.now } : out.alertChange,
  };
}

export function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'patch': {
      const next = trackAlertChanges(state, applyPatch(state, action.patch));
      if (next.overlay.length > 0 && !('overlay' in action.patch)) {
        const raised = next.alertChange !== state.alertChange && next.alertChange?.kind === 'raise';
        if ((next.shaking && !state.shaking) || evacuationEscalated(state, next) || raised) return { ...next, overlay: [] };
      }
      return next;
    }
    case 'loadScenario': {
      const next = buildScenarioState(action.id, state.lang);
      return { ...next, dialerEnabled: state.dialerEnabled, autoSpeak: state.autoSpeak, scenarioRun: state.scenarioRun + 1 };
    }
    case 'navigate': {
      if (state.overlay[state.overlay.length - 1] === action.screen) return state;
      return { ...state, overlay: [...state.overlay, action.screen] };
    }
    case 'back': {
      if (state.overlay.length > 0) return { ...state, overlay: state.overlay.slice(0, -1) };
      if (state.deviceRaised) return { ...state, deviceRaised: false };
      if (state.guideStep === 'nav') return { ...state, guideStep: 'action' };
      return state;
    }
    case 'tick': {
      const now = state.now + action.dtMs;
      // While online the app "polls" once per virtual minute, so lastFetchAt stays fresh —
      // unless updates are failing (demo: feedPaused), which lets "Stale" show while online.
      const polling = state.online && !state.feedPaused;
      const lastFetchAt = polling && now - state.lastFetchAt >= FETCH_INTERVAL_MS ? now : state.lastFetchAt;
      // Route guidance is paused while the pin screen S07 (opened by hand) or A01 (permission prompt) is shown.
      // resolveScreen's defaults are exact for these two screens (they don't depend on nav inputs).
      const screen = resolveScreen(state);
      if (!state.walk.playing || screen === 'S07' || screen === 'A01') return { ...state, now, lastFetchAt };
      const progressM = state.walk.progressM + WALK_BASE_MPS * state.walk.speed * (action.dtMs / 1000);
      return { ...state, now, lastFetchAt, walk: { ...state.walk, progressM } };
    }
    case 'showToast':
      return { ...state, toast: action.message };
    default:
      return state;
  }
}

const StateContext = createContext<AppState | null>(null);
const DispatchContext = createContext<Dispatch<Action> | null>(null);

function init(scenarioId: string): AppState {
  return buildScenarioState(scenarioId, loadLang());
}

export function AppProvider({ children, scenarioId = DEFAULT_SCENARIO_ID }: { children: ReactNode; scenarioId?: string }) {
  const [state, dispatch] = useReducer(reducer, scenarioId, init);
  return (
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={dispatch}>{children}</DispatchContext.Provider>
    </StateContext.Provider>
  );
}

export function useAppState(): AppState {
  const s = useContext(StateContext);
  if (!s) throw new Error('useAppState must be used inside <AppProvider>');
  return s;
}

export function useDispatch(): Dispatch<Action> {
  const d = useContext(DispatchContext);
  if (!d) throw new Error('useDispatch must be used inside <AppProvider>');
  return d;
}
