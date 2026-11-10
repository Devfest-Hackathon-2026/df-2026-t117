// Yellow status pill: "(warning) TSUNAMI WARNING", "(clock) OFFLINE / SAVED GUIDE".
// Pass an array label to join parts with " / ". Pass onClick to make it a button (e.g. switch INDOORS/OUTDOORS).
import { Icon } from './Icon';
import './Badge.css';

export interface BadgeProps {
  label: string | string[];
  icon?: 'warning' | 'clock' | 'pin' | 'none';
  /** yellow (default) | red (S01 notification title) */
  tone?: 'yellow' | 'red';
  size?: 'md' | 'sm';
  onClick?: () => void;
  /** aria-label for clickable badges */
  ariaLabel?: string;
  className?: string;
}

export function Badge({ label, icon = 'warning', tone = 'yellow', size = 'md', onClick, ariaLabel, className }: BadgeProps) {
  const parts = Array.isArray(label) ? label : [label];
  const cls = ['tk-badge', `tk-badge--${tone}`, `tk-badge--${size}`, onClick ? 'tk-badge--button' : '', className ?? '']
    .filter(Boolean)
    .join(' ');
  const content = (
    <>
      {icon !== 'none' && <Icon name={icon} size={size === 'sm' ? 16 : 20} />}
      <span className="tk-badge__text">
        {parts.map((p, i) => (
          <span key={i}>
            {i > 0 && <span className="tk-badge__sep">/</span>}
            {p}
          </span>
        ))}
      </span>
    </>
  );
  if (onClick) {
    return (
      <button type="button" className={cls} onClick={onClick} aria-label={ariaLabel}>
        {content}
      </button>
    );
  }
  return <span className={cls}>{content}</span>;
}

export default Badge;
