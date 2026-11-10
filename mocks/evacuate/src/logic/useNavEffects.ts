// Navigation side effects (T5). Mounted once from App so they run on every screen, including while the
// demo "screen off" blackout is shown (F34):
//  1. Arrival: nav.arrived during evacuation guidance -> onHighGround = true, walk paused (F35 -> S06).
//  2. Turn announcement: the next left/right turn comes within TURN_ANNOUNCE_M (30 m) -> speak the
//     instruction in the current language + vibrate, once per turn (requirements 7.5).
//  3. Route change (origin = manual pin / GPS position, or a different refuge / node path, e.g. after the
//     online toggle or a raised tsunami forecast) -> the walk continues from where the user is: the
//     position on the old route becomes the new origin and walk.progressM restarts at 0. Progress going
//     backwards (reset, scenario reload) re-arms the turn announcements so a rehearsal announces again.
//  4. Device tilt (opt-in, real devices only) -> deviceRaised.
import { useEffect, useRef } from 'react';
import type { Lang } from '../state/types';
import { actions, useAppState, useDispatch } from '../state/store';
import { deriveMode } from '../state/derive';
import { fmt } from '../i18n';
import { speak } from '../platform/speech';
import { vibrate, TURN_PATTERN } from '../platform/vibrate';
import { useDeviceTilt } from '../platform/orientation';
import { TURN_ANNOUNCE_M, useNavigation, type TurnDirection } from './nav';
import { rebaseOrigin } from './useAlertEffects';

const SPEECH: Record<Lang, Record<TurnDirection, string>> = {
  en: { right: 'Turn right in {n} meters.', left: 'Turn left in {n} meters.', straight: 'Go straight for {n} meters.' },
  ja: { right: '{n}メートル先、右です。', left: '{n}メートル先、左です。', straight: 'このまま{n}メートル直進です。' },
  'zh-Hans': { right: '前方{n}米右转。', left: '前方{n}米左转。', straight: '直行{n}米。' },
  ko: { right: '{n}미터 앞에서 오른쪽입니다.', left: '{n}미터 앞에서 왼쪽입니다.', straight: '{n}미터 직진하세요.' },
  ar: { right: 'انعطف يمينًا بعد {n} متر.', left: 'انعطف يسارًا بعد {n} متر.', straight: 'تابع إلى الأمام لمسافة {n} متر.' },
};

/** Spoken turn instruction, e.g. "Turn right in 30 meters." (used by the announcement and Listen buttons). */
export function turnSpeech(lang: Lang, direction: TurnDirection, distanceM: number): string {
  return fmt((SPEECH[lang] ?? SPEECH.en)[direction], { n: Math.max(0, Math.round(distanceM)) });
}

// Tiny event bus so screens can flash the speaker / vibration icons when an announcement fires.
type AnnounceListener = () => void;
const announceListeners = new Set<AnnounceListener>();

/** Subscribe to turn announcements. Returns an unsubscribe function. */
export function onTurnAnnounce(l: AnnounceListener): () => void {
  announceListeners.add(l);
  return () => {
    announceListeners.delete(l);
  };
}

export function useNavEffects(): void {
  const state = useAppState();
  const dispatch = useDispatch();
  const nav = useNavigation();
  useDeviceTilt();

  const mode = deriveMode(state, nav.inHazardZone);
  const guiding = mode === 'evacuate' && state.guideStep === 'nav';

  // 1. Arrival -> S06 (once per arrival; re-armed when no longer arrived).
  const arrivalFiredRef = useRef(false);
  useEffect(() => {
    if (!nav.arrived) {
      arrivalFiredRef.current = false;
      return;
    }
    if (guiding && !arrivalFiredRef.current) {
      arrivalFiredRef.current = true;
      dispatch(actions.patch({ onHighGround: true, walk: { playing: false } }));
    }
  }, [nav.arrived, guiding, dispatch]);

  // Progress went backwards (panel reset / scenario reload / new route) -> announce turns again.
  const announcedRef = useRef<string | null>(null);
  const progressM = state.walk.progressM;
  const prevProgressRef = useRef(progressM);
  useEffect(() => {
    if (progressM < prevProgressRef.current) announcedRef.current = null;
    prevProgressRef.current = progressM;
  }, [progressM]);

  // 2. Turn announcement (voice + vibration), also while the screen is off. Once per turn.
  const turn = nav.nextTurn;
  const turnKey =
    turn && turn.direction !== 'straight'
      ? `${nav.origin.x},${nav.origin.y}|${turn.point.x.toFixed(1)},${turn.point.y.toFixed(1)}`
      : null;
  const within = !!turn && turn.distanceM <= TURN_ANNOUNCE_M;
  const direction = turn?.direction ?? 'straight';
  const distanceRef = useRef(0);
  useEffect(() => {
    distanceRef.current = turn?.distanceM ?? 0;
  });
  const lang = state.lang;
  useEffect(() => {
    if (!guiding || !turnKey || !within) return;
    if (announcedRef.current === turnKey) return;
    announcedRef.current = turnKey;
    speak(turnSpeech(lang, direction, distanceRef.current), lang);
    vibrate(TURN_PATTERN);
    announceListeners.forEach((l) => l());
  }, [guiding, turnKey, within, direction, lang]);

  // 3. Route changed (origin, refuge or node path) -> continue on the new route from the current position.
  const routeKey = `${nav.origin.x},${nav.origin.y}|${nav.route.refuge.id}|${nav.route.detail.nodeIds.join('>')}`;
  const routeRef = useRef(routeKey);
  // Position on the route of the previous render (updated by the effect below, after this one).
  const lastPositionRef = useRef(nav.position);
  useEffect(() => {
    if (routeRef.current === routeKey) return;
    routeRef.current = routeKey;
    announcedRef.current = null;
    if (progressM !== 0) dispatch(actions.patch(rebaseOrigin(state, lastPositionRef.current)));
    // progressM / state are read only at the moment the route changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeKey, dispatch]);
  useEffect(() => {
    lastPositionRef.current = nav.position;
  });
}
