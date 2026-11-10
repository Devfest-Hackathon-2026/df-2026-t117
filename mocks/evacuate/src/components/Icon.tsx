// Inline SVG icons (24x24, currentColor). Arrows flip automatically in RTL.
import type { CSSProperties, ReactElement } from 'react';
import './Icon.css';

export type IconName =
  | 'warning'
  | 'globe'
  | 'phone'
  | 'speaker'
  | 'stop'
  | 'arrow-left'
  | 'arrow-right'
  | 'map-download'
  | 'flag'
  | 'pin'
  | 'clock'
  | 'check'
  | 'vibrate'
  | 'heart-pulse'
  | 'fire'
  | 'shield'
  | 'close'
  | 'sliders'
  | 'bell';

const S = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' } as const;

const PATHS: Record<IconName, ReactElement> = {
  warning: (
    <g {...S}>
      <path d="M12 3.5 2.8 19.5h18.4L12 3.5Z" />
      <path d="M12 9.5v5" />
      <circle cx="12" cy="17" r="0.6" fill="currentColor" />
    </g>
  ),
  globe: (
    <g {...S}>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c2.6 2.5 3.8 5.5 3.8 9s-1.2 6.5-3.8 9c-2.6-2.5-3.8-5.5-3.8-9S9.4 5.5 12 3Z" />
      <path d="M4.5 7.5h15M4.5 16.5h15" />
    </g>
  ),
  phone: (
    <g {...S}>
      <path d="M5.2 3.5h3.1l1.6 4.2-2.1 1.5a11.6 11.6 0 0 0 7 7l1.5-2.1 4.2 1.6v3.1a2 2 0 0 1-2.2 2C10.7 20.3 3.7 13.3 3.2 5.7a2 2 0 0 1 2-2.2Z" />
    </g>
  ),
  speaker: (
    <g {...S}>
      <path d="M3.5 9.5h3.5L11.5 5.5v13L7 14.5H3.5v-5Z" />
      <path d="M14.5 9.2a4 4 0 0 1 0 5.6M17 7a7 7 0 0 1 0 10M19.5 4.8a10 10 0 0 1 0 14.4" />
    </g>
  ),
  stop: (
    <g {...S}>
      <rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor" />
    </g>
  ),
  'arrow-left': (
    <g {...S}>
      <path d="M20 12H4.5M10.5 5.5 4 12l6.5 6.5" />
    </g>
  ),
  'arrow-right': (
    <g {...S}>
      <path d="M4 12h15.5M13.5 5.5 20 12l-6.5 6.5" />
    </g>
  ),
  'map-download': (
    <g {...S}>
      <path d="M3 5.5 8 4l5 1.5L18 4v7M3 5.5v13L8 17l5 1.5M8 4v13M13 5.5v6" />
      <path d="M18 14v6.5M15.5 18l2.5 2.5 2.5-2.5M15 22h6" />
    </g>
  ),
  flag: (
    <g {...S}>
      <path d="M5.5 21V3.5M5.5 4h12v7.5h-12" />
    </g>
  ),
  pin: (
    <g>
      <path
        fill="currentColor"
        fillRule="evenodd"
        d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7Zm0 4.2a2.8 2.8 0 1 0 0 5.6 2.8 2.8 0 0 0 0-5.6Z"
      />
    </g>
  ),
  clock: (
    <g {...S}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5.5h4" />
    </g>
  ),
  check: (
    <g {...S}>
      <path d="m4.5 12.5 5 5 10-11" />
    </g>
  ),
  vibrate: (
    <g {...S}>
      <rect x="8" y="3.5" width="8" height="17" rx="1.6" />
      <path d="M11 17.5h2M5 8l-1.5 2L5 12l-1.5 2L5 16M19 8l1.5 2L19 12l1.5 2L19 16" />
    </g>
  ),
  'heart-pulse': (
    <g {...S}>
      <path d="M12 20s-8-4.8-8-10.5A4.5 4.5 0 0 1 12 7a4.5 4.5 0 0 1 8 2.5C20 15.2 12 20 12 20Z" />
      <path d="M4.5 12h4l1.5-2.5 2.5 5 1.5-2.5h5.5" />
    </g>
  ),
  fire: (
    <g>
      <path
        fill="currentColor"
        d="M12 2.5c.6 3-1 4.6-2.5 6.3C8 10.5 6.5 12.3 6.5 15a5.5 5.5 0 0 0 11 0c0-2.5-1.2-4.2-2.2-5.3-.2 1.5-.9 2.6-1.8 3 .5-3.7-.6-7.6-1.5-10.2Z"
      />
    </g>
  ),
  shield: (
    <g>
      <path fill="currentColor" d="M12 2.5 4 5.5v6c0 5 3.4 9 8 10.5 4.6-1.5 8-5.5 8-10.5v-6l-8-3Z" />
      <path d="M12 3v18.5M4.3 11.3h15.4" stroke="#fff" strokeWidth="1.4" />
    </g>
  ),
  close: (
    <g {...S}>
      <path d="M6 6l12 12M18 6 6 18" />
    </g>
  ),
  sliders: (
    <g {...S}>
      <path d="M4 7h9M17 7h3M4 17h3M11 17h9" />
      <circle cx="15" cy="7" r="2" />
      <circle cx="9" cy="17" r="2" />
    </g>
  ),
  bell: (
    <g {...S}>
      <path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15l1.5-2Z" />
      <path d="M10 20.5a2 2 0 0 0 4 0" />
    </g>
  ),
};

const FLIP_IN_RTL: ReadonlySet<IconName> = new Set<IconName>(['arrow-left', 'arrow-right']);

export interface IconProps {
  name: IconName;
  /** px, default 24 */
  size?: number;
  className?: string;
  style?: CSSProperties;
  /** Accessible label. Without it the icon is aria-hidden (decorative). */
  title?: string;
  /** Override automatic RTL mirroring (arrows mirror by default). */
  flipRtl?: boolean;
}

export function Icon({ name, size = 24, className, style, title, flipRtl }: IconProps) {
  const flip = flipRtl ?? FLIP_IN_RTL.has(name);
  const cls = ['tk-icon', flip ? 'tk-flip-rtl' : '', className ?? ''].filter(Boolean).join(' ');
  return (
    <svg
      className={cls}
      style={style}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {PATHS[name]}
    </svg>
  );
}

export default Icon;
