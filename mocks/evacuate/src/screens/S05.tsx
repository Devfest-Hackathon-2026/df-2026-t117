// S05 offline saved guide (grey tone). Same FB4 handling as S03 when the location is approximate.
import { GuidanceLayout } from '../components/GuidanceLayout';
import { Badge } from '../components/Badge';
import { BigButton, ButtonRow } from '../components/BigButton';
import { GoUphill } from '../components/pictograms';
import { actions, useAppState, useDispatch } from '../state/store';
import { isLocationApproximate } from '../state/derive';
import { useCommon, useT } from '../i18n';
import { GuideFooter, ListenButton, useAnnounceOnEnter } from './_guideShared';
import { AlertBand, useGuideT } from './_alertShared';

export default function S05() {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const g = useGuideT();
  const t = useT({
    en: { headline: 'Go uphill.', guide: 'TSUNAMI GUIDE', leaveCar: 'Leave the car. Go on foot.' },
    ja: { headline: '高台へ。', guide: '津波ガイド', leaveCar: '車を降りて、歩いて避難。' },
    'zh-Hans': { headline: '去高处。', guide: '海啸指南', leaveCar: '下车，步行避难。' },
    ko: { headline: '높은 곳으로.', guide: '쓰나미 안내', leaveCar: '차에서 내려 걸어서 대피하세요.' },
    ar: { headline: 'اصعد إلى مكان مرتفع.', guide: 'دليل التسونامي', leaveCar: 'اترك السيارة وامشِ.' },
  });
  const headline = state.goHigher ? g.goHigher : t.headline;
  const leaveCar = state.eqSituation === 'car' ? t.leaveCar : undefined;
  const approximate = isLocationApproximate(state);
  const signs = approximate ? g.followSigns : undefined;
  const spoken = [headline, leaveCar ?? '', signs ?? ''].filter(Boolean).join(' ');
  useAnnounceOnEnter(spoken);
  const onHighGround = (
    <BigButton variant="outline" icon={approximate ? undefined : 'flag'} onClick={() => dispatch(actions.patch({ onHighGround: true }))}>
      {c.onHighGround}
    </BigButton>
  );
  return (
    <GuidanceLayout
      tone="grey"
      band={<AlertBand />}
      badge={<Badge label={[c.badgeOffline, c.badgeSavedGuide]} icon="clock" />}
      pictogram={<GoUphill />}
      headline={headline}
      subline={t.guide}
      note={
        <>
          {leaveCar && (
            <>
              {leaveCar}
              <br />
            </>
          )}
          {signs && (
            <>
              {signs}
              <br />
            </>
          )}
          {c.routeUnverified}
        </>
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
            {c.savedMap}
          </BigButton>
          {onHighGround}
        </>
      )}
    </GuidanceLayout>
  );
}
