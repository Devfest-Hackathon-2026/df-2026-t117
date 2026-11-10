// Dark hill / ground with a yellow pause badge on top (as the S06 design; original artwork).
import { PictoSvg, type PictoProps } from './Picto';

export function StayHere(props: PictoProps) {
  return (
    <PictoSvg viewBox="0 -6 360 226" {...props} title={props.title ?? 'Stay here on high ground'}>
      <polygon points="20,212 20,148 108,76 178,76 226,42 340,42 340,212" fill="var(--tk-black)" />
      <circle cx="222" cy="30" r="34" fill="var(--tk-yellow)" stroke="var(--tk-black)" strokeWidth="6" />
      <rect x="205" y="12" width="12" height="36" rx="3" fill="var(--tk-black)" />
      <rect x="227" y="12" width="12" height="36" rx="3" fill="var(--tk-black)" />
    </PictoSvg>
  );
}
