// Phone status bar: virtual clock (JST) on the left, DEMO badge on the right (always shown).
import { useAppState } from '../state/store';
import { formatJst } from '../state/time';
import './StatusBar.css';

export type Theme = 'dark' | 'light';

export function StatusBar({ theme = 'dark' }: { theme?: Theme }) {
  const { now } = useAppState();
  return (
    <div className={`tk-statusbar tk-statusbar--${theme}`} dir="ltr">
      <span className="tk-statusbar__time">{formatJst(now)}</span>
      <span className="tk-statusbar__demo" title="Demo build: simulated data only">
        DEMO
      </span>
    </div>
  );
}

export default StatusBar;
