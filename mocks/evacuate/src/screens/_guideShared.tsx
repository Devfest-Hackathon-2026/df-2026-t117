// Helpers shared by the guidance screens S01-S06, S11, S12 (T2; fixed Listen button: FB1).
import { useCallback, useEffect } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';
import { freshness } from '../state/derive';
import { formatJstLabel } from '../state/time';
import { useCommon, useLang, useT } from '../i18n';
import { cancelSpeech, speak, useSpeaking } from '../platform/speech';
import { FooterMeta, MetaLink } from '../components/FooterMeta';
import { Icon } from '../components/Icon';
import './listen.css';

const listenDict = {
  en: { unavailable: 'Read-aloud is not available on this device', stop: 'Stop', stopAria: 'Stop reading aloud', listenAria: 'Read the instruction aloud' },
  ja: { unavailable: 'この端末では読み上げを使えません', stop: '停止', stopAria: '読み上げを止める', listenAria: '指示を読み上げる' },
  'zh-Hans': { unavailable: '此设备不支持朗读', stop: '停止', stopAria: '停止朗读', listenAria: '朗读指示' },
  ko: { unavailable: '이 기기에서는 듣기를 사용할 수 없습니다', stop: '정지', stopAria: '읽기 중지', listenAria: '안내를 읽어 줍니다' },
  ar: { unavailable: 'القراءة الصوتية غير متاحة على هذا الجهاز', stop: 'إيقاف', stopAria: 'إيقاف القراءة الصوتية', listenAria: 'اقرأ التعليمات بصوت عالٍ' },
};

/** Returns a handler that reads `text` aloud in the current language (toast if unsupported). */
export function useListen(text: string): () => void {
  const lang = useLang();
  const dispatch = useDispatch();
  const t = useT(listenDict);
  return useCallback(() => {
    // T5: delegates to platform/speech.ts (same behavior: cancel current speech, speak in current language).
    if (!speak(text, lang)) dispatch(actions.showToast(t.unavailable));
  }, [dispatch, lang, t, text]);
}

/**
 * The fixed Listen button (F80-F82). Every guidance screen (S02-S06, S11, S12) renders exactly one, in the
 * same place: the bottom row right above the source line, at the inline-start edge (left; right in RTL).
 * S11 puts it at the start of the bottom MAP sheet's top row (`placement="sheet"`).
 * - Tap: reads `text` (the screen's instruction; the next turn on S04 / S11 / S12) in the current language.
 * - While anything is being read aloud (including the automatic announcement, F18) it turns into "Stop";
 *   tapping it then stops the speech.
 */
export function ListenButton({ text, placement = 'bar' }: { text: string; placement?: 'bar' | 'sheet' }) {
  const c = useCommon();
  const t = useT(listenDict);
  const listen = useListen(text);
  const speaking = useSpeaking();
  const button = (
    <button
      type="button"
      className={`tk-listen${speaking ? ' tk-listen--speaking' : ''}`}
      onClick={speaking ? cancelSpeech : listen}
      aria-label={speaking ? t.stopAria : t.listenAria}
      aria-pressed={speaking}
    >
      <Icon name={speaking ? 'stop' : 'speaker'} size={26} />
      <span className="tk-listen__label">{speaking ? t.stop : c.listen}</span>
    </button>
  );
  if (placement === 'sheet') return button;
  return <div className="tk-listenbar">{button}</div>;
}

/** Pause between a screen change and its announcement (ms). */
export const ANNOUNCE_DELAY_MS = 300;

/**
 * Reads `text` aloud when the screen appears, and again when the instruction changes (e.g. the situation
 * badge on S02, or the language). Off when the demo panel's auto read-aloud is unchecked.
 * - Delayed by ANNOUNCE_DELAY_MS: App cancels speech when the screen changes, and that effect runs after
 *   this (child) effect in the same commit, so speaking immediately would be cut off at once.
 * - Also runs while the screen is "off" (e.g. arrival -> S06), like the turn announcements (F34).
 * - Browsers only allow speech after the first user interaction; before that it fails silently.
 */
export function useAnnounceOnEnter(text: string): void {
  const lang = useLang();
  const { autoSpeak } = useAppState();
  useEffect(() => {
    if (!autoSpeak || !text) return;
    const id = window.setTimeout(() => speak(text, lang), ANNOUNCE_DELAY_MS);
    return () => window.clearTimeout(id);
  }, [autoSpeak, text, lang]);
}

/**
 * Footer line from freshness() (requirements 7.3).
 * fresh: "JMA • 09:40 JST • Details" (or `freshTail` instead of the Details link, e.g. "Warning active")
 * stale: "Last alert 09:40 JST • Stale"
 */
export function GuideFooter({ freshTail }: { freshTail?: string }) {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const f = freshness(state);
  const at = formatJstLabel(f.lastAlertAt ?? state.lastFetchAt);
  if (f.stale) {
    return <FooterMeta items={[`${c.lastAlert} ${at}`, c.stale]} />;
  }
  if (freshTail) return <FooterMeta items={[c.jma, freshTail]} />;
  return (
    <FooterMeta
      items={[c.jma, at, <MetaLink key="d" onClick={() => dispatch(actions.navigate('A02'))}>{c.details}</MetaLink>]}
    />
  );
}
