// Large pill button (min height 56px). Icon sits at the inline-start edge, label centered.
import type { ReactNode } from 'react';
import { Icon, type IconName } from './Icon';
import './BigButton.css';

export type BigButtonVariant = 'primary' | 'white' | 'dark' | 'outline' | 'black';

export interface BigButtonProps {
  /** primary = yellow, white, dark = #2A272C, outline = transparent w/ light border, black = on light screens */
  variant?: BigButtonVariant;
  /** Icon name or any node, shown at the inline-start edge */
  icon?: IconName | ReactNode;
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  /** Shrink to content (e.g. "Listen" next to "On high ground" in a ButtonRow) */
  compact?: boolean;
  type?: 'button' | 'submit';
  ariaLabel?: string;
  className?: string;
}

export function BigButton({
  variant = 'primary',
  icon,
  children,
  onClick,
  disabled,
  compact,
  type = 'button',
  ariaLabel,
  className,
}: BigButtonProps) {
  const cls = [
    'tk-bigbtn',
    `tk-bigbtn--${variant}`,
    compact ? 'tk-bigbtn--compact' : '',
    icon ? 'tk-bigbtn--has-icon' : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ');
  return (
    <button type={type} className={cls} onClick={onClick} disabled={disabled} aria-label={ariaLabel}>
      {icon ? (
        <span className="tk-bigbtn__icon">
          {typeof icon === 'string' ? <Icon name={icon as IconName} size={28} /> : icon}
        </span>
      ) : null}
      <span className="tk-bigbtn__label">{children}</span>
    </button>
  );
}

/** Horizontal row of buttons (e.g. [Listen compact] [On high ground]). */
export function ButtonRow({ children }: { children: ReactNode }) {
  return <div className="tk-btnrow">{children}</div>;
}

/** Vertical stack of buttons with standard gap. */
export function ButtonStack({ children }: { children: ReactNode }) {
  return <div className="tk-btnstack">{children}</div>;
}

export default BigButton;
