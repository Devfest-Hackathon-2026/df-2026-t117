// Small grey centered meta line: "JMA • 09:40 JST • Details". Items are joined with " • ".
import type { ReactNode } from 'react';
import type { Theme } from './StatusBar';
import './FooterMeta.css';

export interface FooterMetaProps {
  /** Falsy items (null / undefined / false / '') are skipped */
  items: ReactNode[];
  theme?: Theme;
  className?: string;
}

export function FooterMeta({ items, theme = 'dark', className }: FooterMetaProps) {
  const visible = items.filter((i) => i !== null && i !== undefined && i !== false && i !== '');
  return (
    <p className={['tk-footermeta', `tk-footermeta--${theme}`, className ?? ''].filter(Boolean).join(' ')}>
      {visible.map((item, i) => (
        <span key={i} className="tk-footermeta__item">
          {i > 0 && (
            <span className="tk-footermeta__dot" aria-hidden="true">
              •
            </span>
          )}
          {item}
        </span>
      ))}
    </p>
  );
}

/** Link-like button for use inside FooterMeta (e.g. "Details" -> A02). */
export function MetaLink({ children, onClick }: { children: ReactNode; onClick: () => void }) {
  return (
    <button type="button" className="tk-footermeta__link" onClick={onClick}>
      {children}
    </button>
  );
}

export default FooterMeta;
