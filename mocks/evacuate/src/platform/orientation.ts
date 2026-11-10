// Device tilt -> "device raised" for AR (requirements F36).
// Real devices only, and only after the user opted in with a tap:
//   - iOS 13+: DeviceOrientationEvent.requestPermission() MUST be called from a user gesture
//     -> call requestTiltOptIn() directly from an onClick handler.
//   - Android / others: no prompt; opting in just starts listening.
// beta (front/back tilt) >= 60 deg -> raised, < 45 deg -> lowered (hysteresis). PCs use the demo panel.
import { useEffect, useRef, useSyncExternalStore } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';

export const RAISE_DEG = 60;
export const LOWER_DEG = 45;

export type TiltStatus = 'off' | 'on' | 'denied';

type PermissionFn = () => Promise<'granted' | 'denied' | 'default'>;

let status: TiltStatus = 'off';
const listeners = new Set<() => void>();

function setStatus(s: TiltStatus) {
  status = s;
  listeners.forEach((l) => l());
}

function subscribe(l: () => void) {
  listeners.add(l);
  return () => listeners.delete(l);
}

/**
 * Tilt detection can be offered: DeviceOrientationEvent exists AND the primary pointer is touch
 * (desktop Chrome exposes the event type but never fires it).
 */
export function tiltSupported(): boolean {
  if (typeof window === 'undefined' || typeof DeviceOrientationEvent === 'undefined') return false;
  return !!window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
}

/**
 * Orientation permission shared by tilt detection and the compass in S11 (H5).
 * 'granted' from the start where no prompt exists (Android / desktop).
 */
export type OrientationPermission = 'unknown' | 'granted' | 'denied';

function permissionFn(): PermissionFn | null {
  if (typeof DeviceOrientationEvent === 'undefined') return null;
  const req = (DeviceOrientationEvent as unknown as { requestPermission?: PermissionFn }).requestPermission;
  return typeof req === 'function' ? req : null;
}

let permission: OrientationPermission = permissionFn() ? 'unknown' : 'granted';

/**
 * Call ONLY from a tap handler (iOS 13+). requestPermission() is invoked synchronously, before the
 * first await, so it still runs inside the user gesture. No prompt is shown twice: a granted / denied
 * answer is remembered for the session.
 */
export async function requestOrientationPermission(): Promise<OrientationPermission> {
  const req = permissionFn();
  if (!req || permission !== 'unknown') return permission;
  let next: OrientationPermission;
  try {
    const r = await req.call(DeviceOrientationEvent);
    next = r === 'granted' ? 'granted' : 'denied';
  } catch {
    next = 'denied';
  }
  permission = next;
  listeners.forEach((l) => l());
  return permission;
}

/** Current orientation permission (re-renders on change). */
export function useOrientationPermission(): OrientationPermission {
  return useSyncExternalStore(subscribe, () => permission, () => 'unknown');
}

/** Call ONLY from a tap handler. Resolves to the new status. */
export async function requestTiltOptIn(): Promise<TiltStatus> {
  if (!tiltSupported()) return status;
  const p = await requestOrientationPermission();
  setStatus(p === 'granted' ? 'on' : 'denied');
  return status;
}

export function stopTilt(): void {
  setStatus('off');
}

/** Current opt-in status (re-renders on change). */
export function useTiltStatus(): TiltStatus {
  return useSyncExternalStore(subscribe, () => status, () => 'off');
}

/**
 * While opted in, listen to deviceorientation and patch `deviceRaised` on threshold crossings only
 * (so the demo panel toggle is not overwritten by every event). Mount once (App).
 */
export function useDeviceTilt(): void {
  const s = useTiltStatus();
  const dispatch = useDispatch();
  const raised = useAppState().deviceRaised;
  const raisedRef = useRef(raised);
  useEffect(() => {
    raisedRef.current = raised;
  }, [raised]);

  useEffect(() => {
    if (s !== 'on') return;
    let last: boolean | null = null;
    const onOrient = (e: DeviceOrientationEvent) => {
      const beta = e.beta;
      if (beta === null || Number.isNaN(beta)) return;
      const tilt = Math.abs(beta);
      let next: boolean | null = null;
      if (tilt >= RAISE_DEG) next = true;
      else if (tilt < LOWER_DEG) next = false;
      if (next === null || next === last) return;
      last = next;
      if (next !== raisedRef.current) dispatch(actions.patch({ deviceRaised: next }));
    };
    window.addEventListener('deviceorientation', onOrient);
    return () => window.removeEventListener('deviceorientation', onOrient);
  }, [s, dispatch]);
}
