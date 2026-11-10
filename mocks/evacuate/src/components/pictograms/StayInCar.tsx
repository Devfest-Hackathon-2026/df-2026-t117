// Stopped car with the driver still inside and hazard lights on (IN CAR while shaking: wait inside until the
// shaking stops; original artwork).
import { PictoSvg, type PictoProps } from './Picto';

export function StayInCar(props: PictoProps) {
  const bg = 'var(--tk-picto-bg)';
  return (
    <PictoSvg viewBox="0 0 420 230" {...props} title={props.title ?? 'Pull over and stay in the car'}>
      {/* car */}
      <path d="M64 182 V146 Q64 128 84 123 L126 118 L156 76 Q164 66 178 66 H254 Q268 66 276 76 L302 118 L330 124 Q346 130 346 150 V182 Z" />
      <path d="M168 84 H196 V114 H148 Z" fill={bg} />
      <path d="M210 84 H252 L272 114 H210 Z" fill={bg} />
      {/* driver seated inside (head + shoulders in the front window) */}
      <circle cx="236" cy="96" r="10" />
      <path d="M220 114 Q222 104 236 104 Q250 104 252 114 Z" />
      <circle cx="126" cy="184" r="28" />
      <circle cx="126" cy="184" r="10" fill={bg} />
      <circle cx="288" cy="184" r="28" />
      <circle cx="288" cy="184" r="10" fill={bg} />
      {/* hazard lights flashing at both ends */}
      <g stroke="currentColor" strokeWidth="10" strokeLinecap="round" fill="none">
        <path d="M44 128 L18 116" />
        <path d="M44 146 L14 146" />
        <path d="M44 164 L18 176" />
        <path d="M366 128 L392 116" />
        <path d="M366 146 L396 146" />
        <path d="M366 164 L392 176" />
      </g>
    </PictoSvg>
  );
}
