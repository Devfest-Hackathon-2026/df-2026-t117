// A01 Location permission explanation (light). Allow -> granted; Choose on map -> denied + S07 opened by hand.
// If S07 is closed without a pin, guidance continues with the action guide + signs (FB4 / F94).
// Shown by resolveScreen when route guidance starts while gps.permission is 'prompt' (or pushed on the overlay).
import { SubLayout } from '../components/SubLayout';
import { BigButton } from '../components/BigButton';
import { Icon } from '../components/Icon';
import { FooterMeta } from '../components/FooterMeta';
import { actions, useAppState, useDispatch } from '../state/store';
import { useCommon, useT } from '../i18n';
import './t3.css';

const dict = {
  en: { title: 'Use your location?', why1: 'Find the safest route to high ground', why2: 'Show your address to rescuers', stay: 'Your location stays on this device.', allow: 'Allow location', map: 'Choose on map', foot: 'You can change this later' },
  ja: { title: '位置情報を使いますか？', why1: '高台までの安全な道を探します', why2: '救助する人にあなたの場所を伝えます', stay: '位置情報は端末の外に送信されません。', allow: '位置情報を許可', map: '地図で選ぶ', foot: '後から変更できます' },
  'zh-Hans': { title: '使用您的位置？', why1: '查找通往高处的最安全路线', why2: '向救援人员显示您的地址', stay: '您的位置仅保存在此设备上。', allow: '允许定位', map: '在地图上选择', foot: '稍后可以更改' },
  ko: { title: '위치를 사용할까요?', why1: '고지대로 가는 가장 안전한 경로를 찾습니다', why2: '구조대에 내 주소를 보여줍니다', stay: '위치 정보는 이 기기에만 저장됩니다.', allow: '위치 허용', map: '지도에서 선택', foot: '나중에 변경할 수 있습니다' },
  ar: { title: 'استخدام موقعك؟', why1: 'العثور على أأمن مسار إلى مكان مرتفع', why2: 'إظهار عنوانك لفرق الإنقاذ', stay: 'يبقى موقعك على هذا الجهاز.', allow: 'السماح بالموقع', map: 'اختر على الخريطة', foot: 'يمكنك تغيير ذلك لاحقًا' },
};

export default function A01() {
  const t = useT(dict);
  const c = useCommon();
  const dispatch = useDispatch();
  const fromOverlay = useAppState().overlay.at(-1) === 'A01';
  const choose = (permission: 'granted' | 'denied') => {
    dispatch(actions.patch({ gps: { permission } }));
    // Resolved automatically (not on the overlay): the permission change alone moves on to S04.
    if (fromOverlay) dispatch(actions.back());
    if (permission === 'denied') dispatch(actions.navigate('S07'));
  };
  return (
    <SubLayout
      theme="light"
      headerTitle={c.titlePermission}
      title={t.title}
      actions={
        <>
          <BigButton variant="black" icon="pin" onClick={() => choose('granted')}>
            {t.allow}
          </BigButton>
          <BigButton variant="white" icon="map-download" onClick={() => choose('denied')}>
            {t.map}
          </BigButton>
        </>
      }
      footer={<FooterMeta theme="light" items={[t.foot]} />}
    >
      <div className="t3-list">
        <div className="t3-card t3-card--plain">
          <div className="t3-card__head"><Icon name="flag" size={26} />{t.why1}</div>
        </div>
        <div className="t3-card t3-card--plain">
          <div className="t3-card__head"><Icon name="pin" size={26} />{t.why2}</div>
        </div>
        <div className="t3-card">
          <div className="t3-card__head"><Icon name="shield" size={26} />{t.stay}</div>
        </div>
      </div>
    </SubLayout>
  );
}
