// Car with a person stepping out (for IN CAR situations; original artwork).
import { PictoSvg, type PictoProps } from './Picto';

export function GetOutOfCar(props: PictoProps) {
  const bg = 'var(--tk-picto-bg)';
  return (
    <PictoSvg viewBox="0 0 420 230" {...props} title={props.title ?? 'Stop the car and get out'}>
      {/* car */}
      <path d="M14 182 V146 Q14 128 34 123 L76 118 L106 76 Q114 66 128 66 H204 Q218 66 226 76 L252 118 L280 124 Q296 130 296 150 V182 Z" />
      <path d="M118 84 H146 V114 H98 Z" fill={bg} />
      <path d="M160 84 H202 L222 114 H160 Z" fill={bg} />
      <circle cx="76" cy="184" r="28" />
      <circle cx="76" cy="184" r="10" fill={bg} />
      <circle cx="238" cy="184" r="28" />
      <circle cx="238" cy="184" r="10" fill={bg} />
      {/* person */}
      <circle cx="356" cy="52" r="17" />
      <g stroke="currentColor" strokeWidth="14" strokeLinecap="round" strokeLinejoin="round" fill="none">
        <path d="M356 78 L350 136" />
        <path d="M350 136 L372 168 L380 212" />
        <path d="M350 136 L330 172 L322 212" />
        <path d="M354 88 L326 108" />
        <path d="M354 88 L384 106" />
      </g>
    </PictoSvg>
  );
}
