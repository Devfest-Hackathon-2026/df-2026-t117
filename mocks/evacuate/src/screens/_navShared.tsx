// Helpers shared by the navigation / AR screens S04 S07 S08 S11 S12 (T5).
import { useEffect, useState } from 'react';
import type { TurnDirection } from '../logic/nav';
import { onTurnAnnounce } from '../logic/useNavEffects';
import { useAppState } from '../state/store';
import { mostSevere } from '../state/derive';
import { alertBadgeLabel, useCommon, useLang } from '../i18n';
import './nav.css';

/**
 * Big white turn arrow (S04). Directions are geographic, so the arrow is NOT mirrored in RTL:
 * "left" is the mirrored "right" graphic in every language.
 */
export function TurnArrow({ direction, className }: { direction: TurnDirection; className?: string }) {
  const common = {
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 28,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };
  return (
    <svg className={className} viewBox="0 0 220 200" aria-hidden="true" focusable="false">
      {direction === 'straight' ? (
        <g {...common}>
          <path d="M110 186 V30" />
          <path d="M52 86 L110 26 L168 86" />
        </g>
      ) : (
        <g {...common} transform={direction === 'left' ? 'translate(220 0) scale(-1 1)' : undefined}>
          <path d="M40 186 V60 H180" />
          <path d="M128 10 L182 60 L128 110" />
        </g>
      )}
    </svg>
  );
}

/** Localized turn word ("Right" / "Left" / "Straight"). */
export function useDirectionLabel(direction: TurnDirection): string {
  const c = useCommon();
  return direction === 'right' ? c.right : direction === 'left' ? c.left : c.straight;
}

/** "40 m" in the current language. */
export function useMeters(m: number): string {
  const c = useCommon();
  return c.meters.replace('{n}', String(Math.max(0, Math.round(m))));
}

/** Badge text for the current tsunami alert (TSUNAMI WARNING / MAJOR ... / ADVISORY). */
export function useTsunamiBadge(): string {
  const state = useAppState();
  const lang = useLang();
  const c = useCommon();
  const a = mostSevere(state.alerts, 'tsunami');
  return a ? alertBadgeLabel(a, lang) : c.badgeTsunami;
}

/** true for ~2.4 s after each turn announcement (flashes the speaker / vibration icons). */
export function useAnnounceFlash(): boolean {
  const [flash, setFlash] = useState(false);
  useEffect(() => {
    let timer: number | undefined;
    const off = onTurnAnnounce(() => {
      setFlash(true);
      window.clearTimeout(timer);
      timer = window.setTimeout(() => setFlash(false), 2400);
    });
    return () => {
      off();
      window.clearTimeout(timer);
    };
  }, []);
  return flash;
}
