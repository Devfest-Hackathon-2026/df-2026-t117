// Common guidance structure (screens S02, S03, S05, S06; requirements 4 "全画面共通"):
//   Header (TASUKU, yellow rule)
//   Top panel (red / maroon / grey): badge -> pictogram card -> headline -> sub-line -> note
//   Dark bottom area: buttons (children) -> fixed Listen button (listen, F80) -> FooterMeta (footer)
import type { ReactNode } from 'react';
import { Header } from './Header';
import './GuidanceLayout.css';

export type GuidanceTone = 'red' | 'maroon' | 'grey';

export interface GuidanceLayoutProps {
  /** Top panel color: red = alert (S02/S03/S04), maroon = waiting (S06), grey = offline (S05). Default red. */
  tone?: GuidanceTone;
  /** Replace the default header (<Header variant="brand" accent="yellow" />) */
  header?: ReactNode;
  /** Usually a <Badge /> */
  badge?: ReactNode;
  /** Pictogram SVG, rendered inside the rounded card */
  pictogram?: ReactNode;
  /** Card background: pink (#FCE8E4, default), cream (#FDF6F1, S06), none (no card; e.g. S04 turn arrow) */
  pictogramBg?: 'pink' | 'cream' | 'none';
  /** Main instruction (>= 40px heavy) */
  headline: ReactNode;
  /** Yellow line under the headline: "NOW" (large) / "TSUNAMI GUIDE", "HIGH GROUND" (small) */
  subline?: ReactNode;
  sublineSize?: 'large' | 'small';
  /** White secondary line, e.g. "Route unverified" */
  note?: ReactNode;
  /** Anything else at the end of the top panel (e.g. S04 mini map) */
  topExtra?: ReactNode;
  /** Bottom area content: BigButton / ButtonRow / ButtonStack */
  children?: ReactNode;
  /** The fixed Listen button (<ListenButton />), always right above the footer at the inline-start edge (F80) */
  listen?: ReactNode;
  /** Shown right under the header, e.g. the alert-change band (F88) */
  band?: ReactNode;
  /** Usually a <FooterMeta /> */
  footer?: ReactNode;
  className?: string;
}

export function GuidanceLayout({
  tone = 'red',
  header,
  badge,
  pictogram,
  pictogramBg = 'pink',
  headline,
  subline,
  sublineSize = 'small',
  note,
  topExtra,
  children,
  listen,
  band,
  footer,
  className,
}: GuidanceLayoutProps) {
  return (
    <div className={['tk-screen', 'tk-screen--dark', 'tk-guidance', className ?? ''].filter(Boolean).join(' ')}>
      {header ?? <Header variant="brand" accent="yellow" />}
      {band}
      <section className={`tk-guidance__top tk-guidance__top--${tone}`}>
        {badge && <div className="tk-guidance__badge">{badge}</div>}
        {pictogram && <div className={`tk-guidance__picto tk-guidance__picto--${pictogramBg}`}>{pictogram}</div>}
        <div className="tk-guidance__text">
          <h2 className="tk-guidance__headline tk-heading">{headline}</h2>
          {subline && (
            <p className={`tk-guidance__subline tk-guidance__subline--${sublineSize} ${sublineSize === 'large' ? 'tk-heading' : ''}`}>
              {subline}
            </p>
          )}
          {note && <p className="tk-guidance__note">{note}</p>}
        </div>
        {topExtra}
      </section>
      <section className="tk-guidance__bottom">
        {children && <div className="tk-guidance__actions">{children}</div>}
        {listen}
        {footer}
      </section>
    </div>
  );
}

export default GuidanceLayout;
