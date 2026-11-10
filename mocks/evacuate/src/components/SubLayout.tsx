// Sub-screen structure (S07-S10, S12, A01-A04): Header 'sub' (back + title) -> optional badge ->
// big page title -> content -> actions pinned toward the bottom -> FooterMeta.
import type { ReactNode } from 'react';
import { Header } from './Header';
import type { Theme } from './StatusBar';
import './SubLayout.css';

export interface SubLayoutProps {
  /** Header title (small, next to the back arrow) */
  headerTitle: string;
  theme?: Theme;
  onBack?: () => void;
  /** Replace the default header entirely */
  header?: ReactNode;
  badge?: ReactNode;
  /** Large page title, e.g. "Set a pin", "Language", "Call for help" */
  title?: ReactNode;
  /** Line under the title, e.g. "GPS accuracy ±180 m" */
  subtitle?: ReactNode;
  /** Main content */
  children?: ReactNode;
  /** Buttons, placed after content and pushed to the lower half */
  actions?: ReactNode;
  footer?: ReactNode;
  className?: string;
}

export function SubLayout({
  headerTitle,
  theme = 'dark',
  onBack,
  header,
  badge,
  title,
  subtitle,
  children,
  actions,
  footer,
  className,
}: SubLayoutProps) {
  return (
    <div className={['tk-screen', `tk-screen--${theme}`, 'tk-sub', className ?? ''].filter(Boolean).join(' ')}>
      {header ?? <Header variant="sub" title={headerTitle} theme={theme} onBack={onBack} />}
      <div className="tk-sub__body">
        {badge && <div className="tk-sub__badge">{badge}</div>}
        {title && <h2 className="tk-sub__title tk-heading">{title}</h2>}
        {subtitle && <p className="tk-sub__subtitle">{subtitle}</p>}
        {children && <div className="tk-sub__content">{children}</div>}
        <div className="tk-sub__spacer" />
        {actions && <div className="tk-sub__actions">{actions}</div>}
      </div>
      {footer}
    </div>
  );
}

export default SubLayout;
