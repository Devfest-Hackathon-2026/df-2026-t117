// S07 location uncertain (screen-07): accuracy circle + draggable pin, "Use this pin", "Back to guidance".
// Only opened by hand (FB4 / F90 / F94), pushed on the overlay stack: "Set location" on S03 / S05 (location
// approximate) or S12, and "Choose on map" on A01. It never appears automatically any more.
// While S07 is shown the walk simulation holds (store `tick`): route guidance is paused.
import { useState } from 'react';
import { SubLayout } from '../components/SubLayout';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { FooterMeta } from '../components/FooterMeta';
import { TownMap } from '../components/TownMap';
import type { Point } from '../state/types';
import { actions, useAppState, useDispatch } from '../state/store';
import { fmt, useCommon, useT } from '../i18n';
import { useNavigation } from '../logic/nav';
import './nav.css';

export default function S07() {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const t = useT({
    en: { title: 'Set a pin', accuracy: 'GPS accuracy', denied: 'Location access is off', circle: 'Circle = estimated location', tap: 'Tap or drag the map to move the pin', usePin: 'Use this pin', mapLabel: 'Map: tap to place the pin' },
    ja: { title: 'ピンを置く', accuracy: 'GPS の誤差', denied: '位置情報がオフです', circle: '円 = 推定される現在地', tap: '地図をタップ／ドラッグしてピンを動かす', usePin: 'このピンを使う', mapLabel: '地図：タップしてピンを置く' },
    'zh-Hans': { title: '放置图钉', accuracy: 'GPS 精度', denied: '位置权限已关闭', circle: '圆圈 = 估计位置', tap: '点按或拖动地图来移动图钉', usePin: '使用此图钉', mapLabel: '地图：点按放置图钉' },
    ko: { title: '핀 놓기', accuracy: 'GPS 정확도', denied: '위치 권한이 꺼져 있습니다', circle: '원 = 추정 위치', tap: '지도를 탭하거나 끌어서 핀을 옮기세요', usePin: '이 핀 사용', mapLabel: '지도: 탭하여 핀 놓기' },
    ar: { title: 'ضع دبوسًا', accuracy: 'دقة GPS', denied: 'الوصول إلى الموقع متوقف', circle: 'الدائرة = الموقع التقديري', tap: 'اضغط على الخريطة أو اسحبها لتحريك الدبوس', usePin: 'استخدم هذا الدبوس', mapLabel: 'الخريطة: اضغط لوضع الدبوس' },
  });

  const nav = useNavigation();
  // Start the pin at the current estimate (walk position on the route; = GPS / previous pin when not walking).
  const [pin, setPin] = useState<Point>(() => ({ x: Math.round(nav.position.x), y: Math.round(nav.position.y) }));
  const denied = state.gps.permission === 'denied';

  const confirmPin = () => {
    // Route origin becomes the pin; useNavigation() recomputes the route and the walk restarts at 0.
    dispatch(actions.patch({ manualPin: { ...pin }, walk: { progressM: 0 }, guideStep: 'nav', deviceRaised: false }));
    dispatch(actions.back());
  };
  // Close and lower the device: S04 (location good) or S03 / S05 with the signs hint (still approximate).
  const backToGuidance = () => {
    dispatch(actions.back());
    dispatch(actions.patch({ deviceRaised: false }));
  };

  return (
    <SubLayout
      headerTitle={c.titleLocation}
      badge={<Badge label={c.badgeLocationUncertain} />}
      title={t.title}
      subtitle={
        denied ? (
          t.denied
        ) : (
          <>
            {t.accuracy}
            <span className="tk-nav__acc" dir="ltr">
              {fmt('±' + c.meters, { n: Math.round(state.gps.accuracyM) })}
            </span>
          </>
        )
      }
      actions={
        <>
          <BigButton variant="primary" icon="pin" onClick={confirmPin}>
            {t.usePin}
          </BigButton>
          <BigButton variant="dark" icon="arrow-right" onClick={backToGuidance}>
            {c.backToGuidance}
          </BigButton>
        </>
      }
      footer={<FooterMeta items={[c.routeGuidancePaused]} />}
    >
      <TownMap
        variant="full"
        routeColor="none"
        showAccuracy={!denied}
        showPosition={!denied}
        pinEditable
        pin={pin}
        onPinChange={setPin}
        ariaLabel={`${t.mapLabel}. ${t.tap}`}
        style={{ aspectRatio: '810 / 700' }}
      />
      <p className="tk-nav__legend tk-nav__legend--sub">{denied ? t.tap : t.circle}</p>
    </SubLayout>
  );
}
