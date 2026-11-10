// Person crouching with arms over the head, away from buildings and falling objects (original artwork).
import { PictoSvg, type PictoProps } from './Picto';

export function OutdoorsProtect(props: PictoProps) {
  const bg = 'var(--tk-picto-bg)';
  return (
    <PictoSvg viewBox="0 0 360 230" {...props} title={props.title ?? 'Crouch and protect your head, away from buildings'}>
      {/* buildings */}
      <rect x="8" y="30" width="70" height="190" rx="4" />
      <rect x="282" y="80" width="70" height="140" rx="4" />
      <g fill={bg}>
        <rect x="22" y="48" width="16" height="16" />
        <rect x="48" y="48" width="16" height="16" />
        <rect x="22" y="80" width="16" height="16" />
        <rect x="48" y="80" width="16" height="16" />
        <rect x="22" y="112" width="16" height="16" />
        <rect x="48" y="112" width="16" height="16" />
        <rect x="296" y="98" width="16" height="16" />
        <rect x="322" y="98" width="16" height="16" />
        <rect x="296" y="130" width="16" height="16" />
        <rect x="322" y="130" width="16" height="16" />
      </g>
      {/* falling debris */}
      <polygon points="150,20 168,26 160,42 144,36" />
      <polygon points="200,6 216,14 206,30 192,22" />
      <polygon points="232,44 246,48 242,62 228,58" />
      {/* person */}
      <ellipse cx="170" cy="176" rx="46" ry="32" />
      <circle cx="216" cy="168" r="19" />
      <g stroke="currentColor" strokeWidth="13" strokeLinecap="round" strokeLinejoin="round" fill="none">
        <path d="M188 146 L232 148 L240 164" />
        <path d="M128 200 L196 212" />
      </g>
      <path d="M118 214 Q124 196 148 206 L206 214 Z" />
    </PictoSvg>
  );
}
