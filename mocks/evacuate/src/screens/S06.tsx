// S06 on high ground (maroon tone). FB2: the instruction comes with its grounds (MarginCard, F83-F85 / F87).
// Instruction by the margin check (14.3):
//  - ample, no forecast / location, or at a designated evacuation site -> "Stay here." / HIGH GROUND
//  - low (0-10 m)                                                        -> "Go higher." + "Evacuation map"
//  - short (< 0 m, or over 10 m forecast below 20 m)                    -> useAlertEffects sends the user on
//    again (evacuate, "Go higher. NOW"); this screen is only visible for that instant.
import { GuidanceLayout } from '../components/GuidanceLayout';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { StayHere } from '../components/pictograms';
import { actions, useAppState, useDispatch } from '../state/store';
import { evacuationAlert, mostSevere } from '../state/derive';
import { alertBadgeLabel, useCommon, useLang, useT } from '../i18n';
import { useMargin } from '../logic/margin';
import { useNavigation } from '../logic/nav';
import { rebaseOrigin } from '../logic/useAlertEffects';
import { GuideFooter, ListenButton, useAnnounceOnEnter } from './_guideShared';
import { AlertBand, MarginCard, useGuideT, useMarginText } from './_alertShared';

export default function S06() {
  const state = useAppState();
  const lang = useLang();
  const dispatch = useDispatch();
  const c = useCommon();
  const g = useGuideT();
  const nav = useNavigation();
  const margin = useMargin();
  const marginText = useMarginText(margin);
  const t = useT({
    en: { headline: 'Stay here.', active: 'ACTIVE' },
    ja: { headline: 'ここで待機。', active: '発表中' },
    'zh-Hans': { headline: '留在这里。', active: '生效中' },
    ko: { headline: '여기에 머무르세요.', active: '발령 중' },
    ar: { headline: 'ابقَ هنا.', active: 'ساري' },
  });
  const alert = evacuationAlert(state) ?? mostSevere(state.alerts, 'tsunami');
  const badge = alert ? `${alertBadgeLabel(alert, lang)} ${t.active}` : c.badgeTsunamiWarningActive;
  const staying = margin.designated !== null || margin.level === null || margin.level === 'ample';
  const headline = staying ? t.headline : g.goHigher;
  const subline = staying ? c.highGround : undefined;
  const spoken = [headline, subline ?? '', marginText.margin ?? '', margin.designated ? marginText.staff : ''].filter(Boolean).join(' ');
  useAnnounceOnEnter(spoken);
  const goHigherCalmly = () =>
    dispatch(
      actions.patch({
        ...rebaseOrigin(state, nav.position),
        onHighGround: false,
        goHigher: 'calm',
        guideStep: 'nav',
      }),
    );
  return (
    <GuidanceLayout
      tone="maroon"
      band={<AlertBand />}
      badge={<Badge label={badge} />}
      pictogram={<StayHere />}
      pictogramBg="cream"
      headline={headline}
      subline={subline}
      topExtra={<MarginCard margin={margin} staying={staying} />}
      listen={<ListenButton text={spoken} />}
      footer={<GuideFooter freshTail={c.warningActive} />}
    >
      {!staying && (
        <BigButton variant="primary" icon="map-download" onClick={goHigherCalmly}>
          {c.evacuationMap}
        </BigButton>
      )}
      <BigButton variant="outline" icon="clock" onClick={() => dispatch(actions.navigate('A02'))}>
        {c.officialUpdates}
      </BigButton>
    </GuidanceLayout>
  );
}
