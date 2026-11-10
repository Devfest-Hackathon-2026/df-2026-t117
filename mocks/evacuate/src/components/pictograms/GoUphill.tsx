// Person walking up a slope, waves at bottom-left, arrow up-right (original artwork). Mirrors in RTL.
import { PictoSvg, type PictoProps } from './Picto';

export function GoUphill(props: PictoProps) {
  return (
    <PictoSvg viewBox="0 0 360 240" {...props} flipRtl title={props.title ?? 'Go uphill, away from the sea'}>
      {/* slope */}
      <polygon points="125,222 345,122 345,222" />
      {/* waves */}
      <path d="M8 222 Q28 176 58 160 Q96 144 108 174 Q104 190 88 190 Q76 182 82 174 Q60 180 72 200 Q88 212 112 200 Q128 190 142 196 L148 222 Z" />
      <path d="M96 205 Q110 190 130 188 Q146 188 150 200 L158 222 L110 222 Z" />
      {/* arrow */}
      <g stroke="currentColor" strokeWidth="13" strokeLinecap="round" fill="none">
        <path d="M262 104 L304 76" />
      </g>
      <polygon points="296,48 330,44 316,80" />
      {/* walker */}
      <circle cx="196" cy="58" r="15" />
      <g stroke="currentColor" strokeWidth="14" strokeLinecap="round" strokeLinejoin="round" fill="none">
        <path d="M200 82 L188 126" />
        <path d="M190 126 L214 142 L212 176" />
        <path d="M188 126 L166 172 L178 180" />
        <path d="M196 88 L172 98 L164 118" />
        <path d="M206 90 L234 96 L244 100" />
      </g>
    </PictoSvg>
  );
}
