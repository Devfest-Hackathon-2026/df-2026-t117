// Shared wrapper for the pictograms: consistent props, role="img" and aria-label.
import type { ReactNode } from 'react';
import './pictograms.css';

export interface PictoProps {
  /** Fixed pixel size (width; height follows the aspect ratio). Omit to fill the parent. */
  size?: number;
  className?: string;
  /** Ink color. Default: currentColor (the panel sets --tk-picto-line). */
  color?: string;
  /** Accessible label (default is English). */
  title?: string;
}

export function PictoSvg({
  viewBox,
  size,
  className,
  color,
  title,
  flipRtl,
  children,
}: PictoProps & { viewBox: string; title: string; flipRtl?: boolean; children: ReactNode }) {
  const [, , w, h] = viewBox.split(' ').map(Number);
  const cls = ['tk-picto', flipRtl ? 'tk-picto--flip-rtl' : '', className ?? ''].filter(Boolean).join(' ');
  return (
    <svg
      className={cls}
      viewBox={viewBox}
      width={size}
      height={size ? (size * h) / w : undefined}
      role="img"
      aria-label={title}
      focusable="false"
      style={color ? { color } : undefined}
      fill="currentColor"
    >
      {children}
    </svg>
  );
}
