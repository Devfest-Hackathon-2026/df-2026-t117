// Person crouching under a table, protecting the head (original artwork).
import { PictoSvg, type PictoProps } from './Picto';

export function ProtectHead(props: PictoProps) {
  return (
    <PictoSvg viewBox="0 0 360 230" {...props} title={props.title ?? 'Protect your head under a table'}>
      <rect x="14" y="8" width="332" height="36" rx="14" />
      <rect x="34" y="40" width="26" height="184" rx="5" />
      <rect x="300" y="40" width="26" height="184" rx="5" />
      <rect x="82" y="40" width="17" height="116" rx="4" />
      <rect x="261" y="40" width="17" height="116" rx="4" />
      {/* person */}
      <circle cx="222" cy="112" r="27" />
      <path d="M118 212 C106 192 118 164 150 142 C172 124 192 108 218 84 Q240 74 258 86 L254 96 Q238 92 226 100 C208 116 198 128 190 140 L208 152 Q192 170 176 178 L214 192 C232 198 238 210 226 218 L130 218 Q112 218 118 212 Z" />
    </PictoSvg>
  );
}
