// Compass heading for the Web AR view (S11, architecture.md 10.1 H5 / requirements F3B, F3C).
// Real devices only (touch primary pointer); PCs keep the fixed arrow.
//   - Android Chrome: `deviceorientationabsolute` (alpha/beta/gamma relative to magnetic north).
//     A relative-only `deviceorientation` (alpha with an arbitrary origin) is never used.
//   - iOS Safari: `deviceorientation` with webkitCompassHeading / webkitCompassAccuracy, after
//     DeviceOrientationEvent.requestPermission() was granted from a tap (requestCompass()).
// Quality:
//   - no usable compass value within NO_COMPASS_MS -> 'none' (no compass: S11 keeps the fixed arrow, F3C)
//   - a compass exists but the value is unreliable (iOS accuracy < 0 or too large, alpha null, device
//     held almost flat, reading lost) -> 'poor' (AR paused, F3B)
// The heading is smoothed on the circle (0/360 wrap) and ok <-> poor changes only after the raw
// reading has stayed good / poor for QUALITY_HOLD_MS, so the arrow does not flicker.
// Magnetic vs true north (about 7-8 deg in Japan) is NOT corrected: the mock's town map is fictional,
// so there is no real "true north" to align with. A real map would need the declination added.
import { useEffect, useState } from 'react';
import { angleDelta } from '../logic/geometry';
import { AR_MAX_HEADING_ERROR_DEG } from '../state/derive';
import { requestOrientationPermission, tiltSupported, useOrientationPermission } from './orientation';

/** Hysteresis for switching between "arrow" and "AR paused / Calibrate compass" (F3B). */
export const QUALITY_HOLD_MS = 1000;
/** A reading older than this counts as lost. */
const STALE_MS = 1000;
/** No usable compass value at all within this time after entering S11 -> 'none' (no compass). */
export const NO_COMPASS_MS = 3000;
/** |beta| below this = device almost flat: the rear camera points at the floor and the heading is unstable. */
export const FLAT_BETA_DEG = 25;
/** Per-frame smoothing factor of the heading (0..1, higher = faster). */
const SMOOTHING = 0.18;

export type CompassStatus = 'unsupported' | 'prompt' | 'on' | 'denied';

/** unsupported (PC) / prompt (iOS, not asked yet) / on / denied. */
export function useCompassStatus(): CompassStatus {
  const p = useOrientationPermission();
  if (!tiltSupported()) return 'unsupported';
  if (p === 'granted') return 'on';
  return p === 'denied' ? 'denied' : 'prompt';
}

/** Call ONLY from a tap handler (iOS asks for the motion & orientation permission here). */
export function requestCompass(): Promise<unknown> {
  if (!tiltSupported()) return Promise.resolve();
  return requestOrientationPermission();
}

export type CompassQuality = 'waiting' | 'ok' | 'poor' | 'none';

export interface CompassReading {
  /** Smoothed compass heading of the rear camera (deg, 0 = north, clockwise); null until the first reading */
  headingDeg: number | null;
  /** waiting = no decision yet / none = no compass (both keep the fixed arrow), ok = rotate the arrow, poor = AR paused */
  quality: CompassQuality;
}

type CompassEvent = DeviceOrientationEvent & { webkitCompassHeading?: number; webkitCompassAccuracy?: number };

function norm(deg: number): number {
  return ((deg % 360) + 360) % 360;
}

/**
 * Compass heading the rear camera (device -z axis) faces, from absolute alpha/beta/gamma
 * (W3C DeviceOrientation spec, "compassHeading" example). Independent of the screen orientation.
 */
export function rearCameraHeading(alpha: number, beta: number, gamma: number): number {
  const r = Math.PI / 180;
  const cB = Math.cos(beta * r);
  const sB = Math.sin(beta * r);
  const cG = Math.cos(gamma * r);
  const sG = Math.sin(gamma * r);
  const cA = Math.cos(alpha * r);
  const sA = Math.sin(alpha * r);
  const vx = -cA * sG - sA * sB * cG;
  const vy = -sA * sG + cA * sB * cG;
  return norm((Math.atan2(vx, vy) * 180) / Math.PI);
}

/** Smoothed heading + quality with hysteresis. Listens only while `active`. */
export function useCompassHeading(active: boolean): CompassReading {
  const [reading, setReading] = useState<CompassReading>({ headingDeg: null, quality: 'waiting' });

  useEffect(() => {
    if (!active) {
      setReading({ headingDeg: null, quality: 'waiting' });
      return;
    }
    let raw: number | null = null;
    let rawOk = false;
    let rawAt = 0;
    let smoothed: number | null = null;
    let quality: CompassQuality = 'waiting';
    let candidate = false;
    const startedAt = performance.now();
    let candidateSince = startedAt;
    /** A real compass value (iOS heading or absolute alpha) has arrived at least once. */
    let hasCompass = false;
    const flat = (beta: number | null) => beta !== null && Math.abs(beta) < FLAT_BETA_DEG;
    let shown: CompassReading = { headingDeg: null, quality: 'waiting' };
    const hasAbsoluteEvent = 'ondeviceorientationabsolute' in window;

    const onOrient = (ev: Event) => {
      const e = ev as CompassEvent;
      if (typeof e.webkitCompassHeading === 'number' && !Number.isNaN(e.webkitCompassHeading)) {
        // iOS: accuracy < 0 = invalid (needs calibration), large = unreliable.
        const acc = e.webkitCompassAccuracy;
        hasCompass = true;
        raw = norm(e.webkitCompassHeading);
        rawOk = typeof acc === 'number' && acc >= 0 && acc <= AR_MAX_HEADING_ERROR_DEG && !flat(e.beta);
        rawAt = performance.now();
        return;
      }
      // Earth-referenced values only: the absolute event, or (browsers without it) an event that says
      // absolute === true. A relative alpha has an arbitrary origin and is ignored.
      const absolute = e.type === 'deviceorientationabsolute' || (!hasAbsoluteEvent && e.absolute === true);
      if (!absolute) return;
      if (e.alpha === null || e.beta === null || e.gamma === null) return; // no magnetometer: not a value
      hasCompass = true;
      raw = rearCameraHeading(e.alpha, e.beta, e.gamma);
      rawOk = !flat(e.beta);
      rawAt = performance.now();
    };

    let frame = 0;
    const tick = () => {
      const now = performance.now();
      const ok = rawOk && raw !== null && now - rawAt < STALE_MS;
      if (ok !== candidate) {
        candidate = ok;
        candidateSince = now;
      }
      const held = now - candidateSince >= QUALITY_HOLD_MS;
      if (!hasCompass) {
        // Never got a usable value: wait, then give up on the compass (fixed arrow, not AR paused).
        if (now - startedAt >= NO_COMPASS_MS) quality = 'none';
      } else if (quality === 'waiting' || quality === 'none') {
        if (candidate) quality = 'ok';
        else if (held) quality = 'poor';
      } else if (held) {
        quality = candidate ? 'ok' : 'poor';
      }
      if (raw !== null) {
        smoothed = smoothed === null ? raw : norm(smoothed + angleDelta(smoothed, raw) * SMOOTHING);
      }
      const changedHeading =
        smoothed !== null && (shown.headingDeg === null || Math.abs(angleDelta(shown.headingDeg, smoothed)) >= 0.5);
      if (quality !== shown.quality || changedHeading) {
        shown = { headingDeg: smoothed, quality };
        setReading(shown);
      }
      frame = requestAnimationFrame(tick);
    };

    if (hasAbsoluteEvent) window.addEventListener('deviceorientationabsolute', onOrient);
    window.addEventListener('deviceorientation', onOrient);
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      if (hasAbsoluteEvent) window.removeEventListener('deviceorientationabsolute', onOrient);
      window.removeEventListener('deviceorientation', onOrient);
    };
  }, [active]);

  return reading;
}
