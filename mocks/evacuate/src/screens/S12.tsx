// S12 AR paused (demo-guide-04, right phone): device raised but position / heading / tracking not good
// enough (F3B). Route arrows are hidden; the user can set the location (S07) or go to the action guide.
import { SubLayout } from '../components/SubLayout';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { FooterMeta } from '../components/FooterMeta';
import { TownMap } from '../components/TownMap';
import { actions, useDispatch } from '../state/store';
import { useCommon, useLang, useT } from '../i18n';
import { useNavigation } from '../logic/nav';
import { turnSpeech } from '../logic/useNavEffects';
import { ListenButton } from './_guideShared';
import { AlertBand } from './_alertShared';
import { Header } from '../components/Header';
import './nav.css';

export default function S12() {
  const dispatch = useDispatch();
  const c = useCommon();
  const lang = useLang();
  const nav = useNavigation();
  const t = useT({
    en: { title: 'Check location', sub: 'Camera position uncertain', setLocation: 'Set location', actionGuide: 'Action guide', hidden: 'Route arrows hidden', mapLabel: 'Town map (route hidden)' },
    ja: { title: '現在地を確認', sub: 'カメラの位置が不確かです', setLocation: '現在地を設定', actionGuide: '行動の案内', hidden: '経路の矢印を非表示中', mapLabel: '町の地図（経路は非表示）' },
    'zh-Hans': { title: '确认位置', sub: '相机位置不确定', setLocation: '设置位置', actionGuide: '行动指引', hidden: '已隐藏路线箭头', mapLabel: '城镇地图（已隐藏路线）' },
    ko: { title: '위치 확인', sub: '카메라 위치가 불확실합니다', setLocation: '위치 설정', actionGuide: '행동 안내', hidden: '경로 화살표 숨김', mapLabel: '마을 지도(경로 숨김)' },
    ar: { title: 'تحقق من الموقع', sub: 'موضع الكاميرا غير مؤكد', setLocation: 'حدد الموقع', actionGuide: 'دليل التصرف', hidden: 'أسهم المسار مخفية', mapLabel: 'خريطة البلدة (المسار مخفي)' },
  });

  return (
    <SubLayout
      headerTitle={c.titleMapGuidance}
      header={
        <>
          <Header variant="sub" title={c.titleMapGuidance} theme="dark" />
          <AlertBand />
        </>
      }
      badge={<Badge label={c.badgeArPaused} />}
      title={t.title}
      subtitle={t.sub}
      actions={
        <>
          {/* Opens S07 on the overlay stack (S07 is only ever opened by hand, FB4 / F90). */}
          <BigButton variant="primary" icon="pin" onClick={() => dispatch(actions.navigate('S07'))}>
            {t.setLocation}
          </BigButton>
          <BigButton variant="dark" icon="arrow-left" onClick={() => dispatch(actions.patch({ guideStep: 'action', deviceRaised: false }))}>
            {t.actionGuide}
          </BigButton>
        </>
      }
      footer={
        <>
          {/* F80 / F81: fixed Listen button; reads the next turn of the same route as S04 / S11. */}
          <ListenButton text={turnSpeech(lang, nav.nextTurn?.direction ?? 'straight', nav.nextTurn?.distanceM ?? 0)} />
          <FooterMeta items={[t.hidden]} />
        </>
      }
    >
      {/* Position is uncertain: no route line and no position marker (F3B). */}
      <TownMap variant="full" routeColor="none" showPosition={false} ariaLabel={t.mapLabel} style={{ aspectRatio: '810 / 700' }} />
      <p className="tk-nav__legend tk-nav__legend--sub">
        <span>{c.stripedHazard}</span>
        <span className="tk-nav__dot" aria-hidden="true">•</span>
        <span>{c.flagRefuge}</span>
      </p>
    </SubLayout>
  );
}
