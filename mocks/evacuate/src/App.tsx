import { useEffect, useRef } from 'react';
import { actions, useAppState, useDispatch } from './state/store';
import { resolveScreen } from './state/derive';
import { applyDocumentLang } from './i18n';
import { cancelSpeech } from './platform/speech';
import { PhoneFrame } from './components/PhoneFrame';
import { getScreen } from './screens';
import { DemoPanel } from './demo/DemoPanel';
import { useNavigation } from './logic/nav';
import { useNavEffects } from './logic/useNavEffects';
import { useDevQuery } from './logic/devQuery';
import { useAlertEffects } from './logic/useAlertEffects';

const TICK_MS = 1000;

export default function App() {
  const state = useAppState();
  const dispatch = useDispatch();
  const nav = useNavigation();

  // Virtual clock + walk simulation (keeps running while the screen is "off").
  useEffect(() => {
    const id = window.setInterval(() => dispatch(actions.tick(TICK_MS)), TICK_MS);
    return () => window.clearInterval(id);
  }, [dispatch]);

  // Set <html lang/dir> (rtl for Arabic). The language is persisted only when the user applies it on S09.
  useEffect(() => {
    applyDocumentLang(state.lang);
  }, [state.lang]);

  const screen = getScreen(resolveScreen(state, nav.nextSegmentVerified, nav.inHazardZone));
  const Screen = screen.component;

  // Leaving a screen stops its read-aloud. While the screen is "off" (blackout), screen changes are not
  // visible and turn announcements must keep playing, so nothing is cancelled then.
  const prevScreenRef = useRef(screen.id);
  const screenOff = state.screenOff;
  useEffect(() => {
    if (prevScreenRef.current === screen.id) return;
    prevScreenRef.current = screen.id;
    if (!screenOff) cancelSpeech();
  }, [screen.id, screenOff]);

  // Declared after the cancel effect above so a turn announcement fired in the same commit survives it.
  useNavEffects(); // T5: arrival -> S06, turn voice + vibration (also while screen off), tilt
  useDevQuery(); // T5: demo-only ?scenario=..&raised=.. URL query (see logic/devQuery.ts)
  useAlertEffects(); // FB3 / FB2: re-notify on upgrade / raise, back to evacuation when the margin is not enough

  return (
    <PhoneFrame theme={screen.theme} demoPanel={<DemoPanel />}>
      <Screen key={screen.id} />
    </PhoneFrame>
  );
}
