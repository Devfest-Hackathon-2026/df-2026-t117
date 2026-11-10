// App header. 'brand' = TASUKU logo (guidance screens). 'sub' = back arrow + title (sub screens).
// Globe (-> S09) and phone (-> S10) buttons are always present (requirements 4, common).
import { actions, useDispatch } from '../state/store';
import { useCommon } from '../i18n';
import { Icon } from './Icon';
import type { Theme } from './StatusBar';
import './Header.css';

export interface HeaderProps {
  variant: 'brand' | 'sub';
  /** Title for variant 'sub' */
  title?: string;
  theme?: Theme;
  /** Override back behavior (default: dispatch back) */
  onBack?: () => void;
  /** Colored rule under the header: yellow on guidance screens (S02-S06), red on S11. Default none. */
  accent?: 'yellow' | 'red' | 'none';
}

export function Header({ variant, title, theme = 'dark', onBack, accent = 'none' }: HeaderProps) {
  const dispatch = useDispatch();
  const c = useCommon();
  return (
    <header className={`tk-header tk-header--${theme} tk-header--accent-${accent}`}>
      <div className="tk-header__row">
        {variant === 'sub' && (
          <button
            type="button"
            className="tk-header__round"
            aria-label={c.back}
            onClick={onBack ?? (() => dispatch(actions.back()))}
          >
            <Icon name="arrow-left" size={26} />
          </button>
        )}
        {variant === 'brand' ? (
          <span className="tk-header__logo tk-heading" dir="ltr">
            TASUKU
          </span>
        ) : (
          <h1 className="tk-header__title tk-heading">{title}</h1>
        )}
        <div className="tk-header__actions">
          <button
            type="button"
            className="tk-header__round"
            aria-label={c.changeLanguage}
            onClick={() => dispatch(actions.navigate('S09'))}
          >
            <Icon name="globe" size={26} />
          </button>
          <button
            type="button"
            className="tk-header__round"
            aria-label={c.emergencyCall}
            onClick={() => dispatch(actions.navigate('S10'))}
          >
            <Icon name="phone" size={26} />
          </button>
        </div>
      </div>
    </header>
  );
}

export default Header;
