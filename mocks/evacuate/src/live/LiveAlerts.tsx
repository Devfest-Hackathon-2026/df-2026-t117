// Live alerts provider (H2). Mounted inside AppProvider.
//  - Subscribes to the demo town's `alerts/{EventID}` in Firestore and applies each new bulletin once
//    (EventID + Serial + InfoType) with the same store patch as the demo panel. The app state follows Firestore.
//  - While the subscription is off, failing, or the demo is "offline", the demo panel alone controls alerts
//    as before. A bulletin received while the demo is offline is applied when it goes back online.
//  - A scenario load / reset clears what was received (the current bulletin is kept as seen, not re-applied).
//  - Web Push (FCM) opt-in for the lock-screen notification (S01). Foreground messages are not shown.
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';
import { applyOnStart, liveAlertPatch, liveKey, type LiveAlertDoc } from './liveDoc';
import { detectPushSupport, enablePush as requestPush, notificationPermission, type PushState, type PushSupport } from '../platform/push';

export type LiveStatus = 'off' | 'connecting' | 'live' | 'cache' | 'error';

export interface LiveAlertsApi {
  enabled: boolean;
  setEnabled: (on: boolean) => void;
  status: LiveStatus;
  error: string | null;
  /** Real time (epoch ms) the latest new bulletin was received. Cleared by a scenario reset. */
  receivedAt: number | null;
  /** The latest received bulletin (cleared by a scenario reset) */
  latest: LiveAlertDoc | null;
  /** Whether `latest` has been applied to the store (false while waiting for the demo to be online) */
  latestApplied: boolean;
  pushSupport: PushSupport;
  pushState: PushState;
  pushError: string | null;
  /** Real time of the last FCM message received in the foreground (not shown; for the demo panel readout) */
  lastPushAt: number | null;
  /** Ask for notification permission and register (call from a user action). */
  enablePush: () => void;
}

const LiveContext = createContext<LiveAlertsApi | null>(null);

function message(e: unknown): string {
  if (e && typeof e === 'object' && 'code' in e && typeof (e as { code: unknown }).code === 'string') {
    return `${(e as { code: string }).code}: ${e instanceof Error ? e.message : ''}`;
  }
  return e instanceof Error ? e.message : String(e);
}

export function LiveAlertsProvider({ children }: { children: ReactNode }) {
  const state = useAppState();
  const dispatch = useDispatch();

  const [enabled, setEnabled] = useState(true);
  const [status, setStatus] = useState<LiveStatus>('connecting');
  const [error, setError] = useState<string | null>(null);
  const [latest, setLatest] = useState<LiveAlertDoc | null>(null);
  const [receivedAt, setReceivedAt] = useState<number | null>(null);
  const [appliedTick, setAppliedTick] = useState(0);
  /** Bulletins already applied (or marked seen). Survives toggling and resets. */
  const appliedRef = useRef(new Set<string>());
  /** The bulletin last received (applied or waiting for the demo to be online). */
  const receivedKeyRef = useRef<string | null>(null);

  // 1. Subscription (Firebase loaded on demand; any failure only shows as an error in the demo panel).
  useEffect(() => {
    if (!enabled) {
      setStatus('off');
      return;
    }
    let cancelled = false;
    let unsubscribe: (() => void) | null = null;
    let started = false; // the first snapshot from the server has been seen
    setStatus('connecting');
    setError(null);
    import('./firestoreAlerts')
      .then(({ subscribeDemoAlerts }) => {
        if (cancelled) return;
        unsubscribe = subscribeDemoAlerts({
          next(doc, { fromCache }) {
            if (cancelled) return;
            setStatus(fromCache ? 'cache' : 'live');
            setError(null);
            if (fromCache && !started) return; // wait for the server's view before deciding what is "current"
            const initial = !started;
            started = true;
            if (!doc) return;
            const key = liveKey(doc);
            // The same bulletin is written twice by the server (state, then `notified`): count it once.
            if (appliedRef.current.has(key) || receivedKeyRef.current === key) return;
            // At start, an old or lifted alert is only marked seen, so it does not override the scenario.
            if (initial && !applyOnStart(doc, Date.now())) {
              appliedRef.current.add(key);
              return;
            }
            receivedKeyRef.current = key;
            setLatest(doc);
            setReceivedAt(Date.now());
          },
          error(e) {
            if (cancelled) return;
            setStatus('error');
            setError(message(e));
          },
        });
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setStatus('error');
        setError(message(e));
      });
    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  }, [enabled]);

  // 2. Apply the latest bulletin once, when subscribed and the demo is online.
  const online = state.online;
  useEffect(() => {
    if (!latest || !enabled || !online) return;
    const key = liveKey(latest);
    if (appliedRef.current.has(key)) return;
    appliedRef.current.add(key);
    setAppliedTick((n) => n + 1);
    const patch = liveAlertPatch(state, latest);
    if (patch) dispatch(actions.patch(patch));
    // Runs when a new bulletin arrives or the demo comes back online; the store state is read at that moment.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latest, enabled, online, dispatch]);

  // 3. Scenario load / reset: forget what was received (keep it marked seen so it is not applied again).
  const run = state.scenarioRun;
  const runRef = useRef(run);
  useEffect(() => {
    if (runRef.current === run) return;
    runRef.current = run;
    setLatest((prev) => {
      if (prev) appliedRef.current.add(liveKey(prev));
      return null;
    });
    setReceivedAt(null);
  }, [run]);

  // 4. Web Push.
  const [pushSupport, setPushSupport] = useState<PushSupport>('checking');
  const [pushState, setPushState] = useState<PushState>('idle');
  const [pushError, setPushError] = useState<string | null>(null);
  const [lastPushAt, setLastPushAt] = useState<number | null>(null);
  const onForeground = useCallback(() => setLastPushAt(Date.now()), []);

  const enablePush = useCallback(() => {
    if (pushSupport !== 'supported') return;
    setPushState('working');
    setPushError(null);
    requestPush(onForeground)
      .then((r) => setPushState(r))
      .catch((e: unknown) => {
        setPushState('error');
        setPushError(message(e));
      });
  }, [pushSupport, onForeground]);

  useEffect(() => {
    let cancelled = false;
    void detectPushSupport().then((s) => {
      if (cancelled) return;
      setPushSupport(s);
      const permission = notificationPermission();
      if (s !== 'supported') return;
      if (permission === 'denied') setPushState('denied');
      // Already allowed earlier: register again quietly on every open (no prompt). Registrations expire within
      // 2 days, so this keeps the token valid, and it refreshes a rotated token and hooks foreground messages.
      if (permission === 'granted') {
        setPushState('working');
        requestPush(onForeground)
          .then((r) => !cancelled && setPushState(r))
          .catch((e: unknown) => {
            if (cancelled) return;
            setPushState('error');
            setPushError(message(e));
          });
      }
    });
    return () => {
      cancelled = true;
    };
  }, [onForeground]);

  const latestApplied = latest ? appliedRef.current.has(liveKey(latest)) : false;
  const api = useMemo<LiveAlertsApi>(
    () => ({
      enabled,
      setEnabled,
      status,
      error,
      receivedAt,
      latest,
      latestApplied,
      pushSupport,
      pushState,
      pushError,
      lastPushAt,
      enablePush,
    }),
    // appliedTick re-evaluates latestApplied after an apply
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [enabled, status, error, receivedAt, latest, latestApplied, appliedTick, pushSupport, pushState, pushError, lastPushAt, enablePush],
  );

  return <LiveContext.Provider value={api}>{children}</LiveContext.Provider>;
}

export function useLiveAlerts(): LiveAlertsApi {
  const v = useContext(LiveContext);
  if (!v) throw new Error('useLiveAlerts must be used inside <LiveAlertsProvider>');
  return v;
}
