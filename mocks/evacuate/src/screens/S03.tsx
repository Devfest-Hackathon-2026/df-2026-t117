// S03 tsunami warning: evacuate now.
// - Sent on again from a waiting place (goHigher, F85 / F88): "Go higher." (+ NOW when the margin is not enough).
// - Location approximate / missing (FB4, F92 / F94): no route; "Follow the blue evacuation signs" and a
//   small "Set location" (opens S07 by hand) replace "Evacuation map".
import { GuidanceLayout } from '../components/GuidanceLayout';
import { Badge } from '../components/Badge';
import { BigButton, ButtonRow } from '../components/BigButton';
import { GoUphill } from '../components/pictograms';
import { actions, useAppState, useDispatch } from '../state/store';
import { isLocationApproximate, mostSevere, topPriorityAction } from '../state/derive';
import { alertBadgeLabel, useCommon, useLang, useT } from '../i18n';
import { GuideFooter, ListenButton, useAnnounceOnEnter } from './_guideShared';
import { AlertBand, useGuideT } from './_alertShared';

export default function S03() {
  const state = useAppState();
  const dispatch = useDispatch();
  const lang = useLang();
  const c = useCommon();
  const g = useGuideT();
  const t = useT({
    en: { headline: 'Go uphill.', now: 'NOW', leaveCar: 'Leave the car. Go on foot.' },
    ja: { headline: '高台へ。', now: '今すぐ', leaveCar: '車を降りて、歩いて避難。' },
    'zh-Hans': { headline: '去高处。', now: '立即', leaveCar: '下车，步行避难。' },
    ko: { headline: '높은 곳으로.', now: '지금 바로', leaveCar: '차에서 내려 걸어서 대피하세요.' },
    ar: { headline: 'اصعد إلى مكان مرتفع.', now: 'الآن', leaveCar: 'اترك السيارة وامشِ.' },
  });
  const action = topPriorityAction(state);
  const alert = action.alert && action.alert.type === 'tsunami' ? action.alert : mostSevere(state.alerts, 'tsunami');
  const badge = alert ? alertBadgeLabel(alert, lang) : c.badgeTsunami;
  const headline = state.goHigher ? g.goHigher : t.headline;
  const showNow = state.goHigher === 'now' || (action.kind === 'goUphillNow' && state.goHigher !== 'calm');
  // Was in a car when the earthquake hit: evacuate on foot, not by car.
  const leaveCar = state.eqSituation === 'car' ? t.leaveCar : undefined;
  const approximate = isLocationApproximate(state);
  const signs = approximate ? g.followSigns : undefined;
  const spoken = [headline, showNow ? t.now : '', leaveCar ?? '', signs ?? ''].filter(Boolean).join(' ');
  useAnnounceOnEnter(spoken);
  const onHighGround = (
    <BigButton variant="outline" icon={approximate ? undefined : 'flag'} onClick={() => dispatch(actions.patch({ onHighGround: true }))}>
      {c.onHighGround}
    </BigButton>
  );

  return (
    <GuidanceLayout
      tone="red"
      band={<AlertBand />}
      badge={<Badge label={badge} />}
      pictogram={<GoUphill />}
      headline={headline}
      subline={showNow ? t.now : undefined}
      sublineSize="large"
      note={
        leaveCar || signs ? (
          <>
            {leaveCar}
            {leaveCar && signs && <br />}
            {signs}
          </>
        ) : undefined
      }
      listen={<ListenButton text={spoken} />}
      footer={<GuideFooter />}
    >
      {approximate ? (
        <ButtonRow>
          <BigButton variant="dark" icon="pin" compact onClick={() => dispatch(actions.navigate('S07'))}>
            {g.setLocation}
          </BigButton>
          {onHighGround}
        </ButtonRow>
      ) : (
        <>
          <BigButton variant="primary" icon="map-download" onClick={() => dispatch(actions.patch({ guideStep: 'nav' }))}>
            {c.evacuationMap}
          </BigButton>
          {onHighGround}
        </>
      )}
    </GuidanceLayout>
  );
}
