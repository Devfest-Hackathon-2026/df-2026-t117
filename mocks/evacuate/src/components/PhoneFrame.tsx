// Phone frame.
// - Wide screens (>= 500px): a 390x844 phone frame with the demo panel slot on its right.
// - Phones (< 500px): full screen; a small floating tab opens the demo panel as a bottom sheet.
// Also renders the StatusBar (clock + DEMO, always visible), the Toast and the "screen off" blackout.
import { useEffect, useState, type ReactNode } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';
import { isRtl, useCommon } from '../i18n';
import { StatusBar, type Theme } from './StatusBar';
import { Toast } from './Toast';
import { Icon } from './Icon';
import './PhoneFrame.css';

const NARROW_QUERY = '(max-width: 499px)';

function useIsNarrow(): boolean {
  const get = () => typeof window !== 'undefined' && !!window.matchMedia && window.matchMedia(NARROW_QUERY).matches;
  const [narrow, setNarrow] = useState(get);
  useEffect(() => {
    if (!window.matchMedia) return;
    const mq = window.matchMedia(NARROW_QUERY);
    const onChange = () => setNarrow(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return narrow;
}

export interface PhoneFrameProps {
  /** Status bar / background theme of the current screen */
  theme?: Theme;
  /** Demo panel content (shown beside the phone, or in a sheet on phones) */
  demoPanel?: ReactNode;
  /** The current screen */
  children: ReactNode;
}

export function PhoneFrame({ theme = 'dark', demoPanel, children }: PhoneFrameProps) {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const narrow = useIsNarrow();
  const [sheetOpen, setSheetOpen] = useState(false);
  const dir = isRtl(state.lang) ? 'rtl' : 'ltr';

  return (
    <div className={`tk-stage ${narrow ? 'tk-stage--narrow' : 'tk-stage--wide'}`} dir="ltr">
      <div className="tk-phone">
        <div className={`tk-phone__screen tk-phone__screen--${theme}`} dir={dir} lang={state.lang}>
          <StatusBar theme={theme} />
          <div className="tk-phone__content">{children}</div>
          <Toast />
          {state.screenOff && (
            <button
              type="button"
              className="tk-phone__off"
              onClick={() => dispatch(actions.patch({ screenOff: false }))}
              aria-label="Screen off (demo). Tap to wake."
            >
              <span>Screen off (demo) · tap to wake</span>
            </button>
          )}
          {!narrow && <div className={`tk-phone__home tk-phone__home--${theme}`} aria-hidden="true" />}
        </div>
      </div>

      {demoPanel && !narrow && (
        <aside className="tk-demo-slot" aria-label="Demo panel">
          {demoPanel}
        </aside>
      )}

      {demoPanel && narrow && (
        <>
          <button
            type="button"
            className="tk-demo-fab"
            aria-label="Open demo panel"
            onClick={() => setSheetOpen(true)}
          >
            <Icon name="sliders" size={18} />
          </button>
          {sheetOpen && (
            <div className="tk-demo-sheet" role="dialog" aria-modal="true" aria-label="Demo panel">
              <div className="tk-demo-sheet__backdrop" onClick={() => setSheetOpen(false)} />
              <div className="tk-demo-sheet__panel">
                <div className="tk-demo-sheet__bar">
                  <span>Demo panel</span>
                  <button type="button" className="tk-demo-sheet__close" onClick={() => setSheetOpen(false)} aria-label={c.close}>
                    <Icon name="close" size={22} />
                  </button>
                </div>
                <div className="tk-demo-sheet__body">{demoPanel}</div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default PhoneFrame;
