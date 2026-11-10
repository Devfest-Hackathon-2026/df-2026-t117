// S08 saved map (screen-08): bundled SVG map without live closures (offline, F41 / F42).
// Shown for guideStep 'nav' while offline (resolveScreen), or pushed on the overlay stack.
import { SubLayout } from '../components/SubLayout';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { FooterMeta } from '../components/FooterMeta';
import { TownMap } from '../components/TownMap';
import { actions, useAppState, useDispatch } from '../state/store';
import { freshness } from '../state/derive';
import { formatJstLabel } from '../state/time';
import { useCommon, useT } from '../i18n';
import './nav.css';

export default function S08() {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const t = useT({
    en: { mapLabel: 'Saved map of the town' },
    ja: { mapLabel: '保存済みの町の地図' },
    'zh-Hans': { mapLabel: '已保存的城镇地图' },
    ko: { mapLabel: '저장된 마을 지도' },
    ar: { mapLabel: 'الخريطة المحفوظة للبلدة' },
  });
  const f = freshness(state);
  const fromOverlay = state.overlay[state.overlay.length - 1] === 'S08';

  const back = () => {
    if (fromOverlay) dispatch(actions.back());
    else dispatch(actions.patch({ guideStep: 'action' })); // -> S05 (offline) / S03 (online)
  };

  const footer = f.liveRoadStatus
    ? f.passabilityCheckedAt !== null
      ? `${c.passabilityChecked} ${formatJstLabel(f.passabilityCheckedAt)}`
      : null
    : c.liveRoadUnavailable;

  return (
    <SubLayout
      headerTitle={c.titleSavedMap}
      badge={!state.online ? <Badge label={c.badgeOffline} icon="clock" /> : undefined}
      title={c.savedMap}
      actions={
        <BigButton variant="white" icon="arrow-left" onClick={back}>
          {c.backToGuidance}
        </BigButton>
      }
      footer={<FooterMeta items={[footer]} />}
    >
      {/* Offline: no live closures, no (unverified) route line; the position dot keeps moving while walking. */}
      <TownMap variant="full" routeColor="none" showClosures={state.online} ariaLabel={t.mapLabel} />
      <p className="tk-nav__legend tk-nav__legend--sub">
        <span>{c.stripedHazard}</span>
        <span className="tk-nav__dot" aria-hidden="true">•</span>
        <span>{c.flagRefuge}</span>
      </p>
    </SubLayout>
  );
}
