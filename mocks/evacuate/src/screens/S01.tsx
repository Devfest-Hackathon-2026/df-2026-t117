// S01 lock-screen notification: clock, SIMULATED ALERT, card with hazard names + rank-1 instruction.
import { Icon } from '../components/Icon';
import { BigButton } from '../components/BigButton';
import { ProtectHead, OutdoorsProtect, StayInCar, GoUphill, StayHere } from '../components/pictograms';
import { useAnnounceOnEnter } from './_guideShared';
import { actions, useAppState, useDispatch } from '../state/store';
import { activeHazards, topPriorityAction } from '../state/derive';
import { formatJst } from '../state/time';
import { useCommon, useLang, useT } from '../i18n';
import './S01.css';

export default function S01() {
  const state = useAppState();
  const dispatch = useDispatch();
  const c = useCommon();
  const lang = useLang();
  const t = useT({
    en: { protect: 'Protect your head', car: 'Pull over. Stay inside.', outdoors: 'Protect your head', goNow: 'Go uphill NOW', go: 'Go uphill', stay: 'Stay here', check: 'Check updates' },
    ja: { protect: '頭を守れ', car: '停車。車内で待つ。', outdoors: '頭を守れ', goNow: '今すぐ高台へ', go: '高台へ', stay: 'ここで待機', check: '情報を確認' },
    'zh-Hans': { protect: '保护头部', car: '靠边停车，留在车内', outdoors: '保护头部', goNow: '立即去高处', go: '去高处', stay: '留在这里', check: '查看最新信息' },
    ko: { protect: '머리를 보호하세요', car: '정차하고 차 안에 머무르세요', outdoors: '머리를 보호하세요', goNow: '지금 바로 높은 곳으로', go: '높은 곳으로', stay: '여기에 머무르세요', check: '정보를 확인하세요' },
    ar: { protect: 'احمِ رأسك', car: 'توقف وابقَ في السيارة', outdoors: 'احمِ رأسك', goNow: 'اصعد إلى مكان مرتفع الآن', go: 'اصعد إلى مكان مرتفع', stay: 'ابقَ هنا', check: 'تحقق من التحديثات' },
  });

  const names = activeHazards(state).map((h) => (h === 'earthquake' ? c.badgeEarthquake : c.badgeTsunami));
  const title = names.length > 0 ? names.join(' + ') : c.simulatedAlert;
  const action = topPriorityAction(state);

  let picto = <ProtectHead />;
  let text = t.check;
  switch (action.kind) {
    case 'protect':
      if (state.eqSituation === 'car') {
        picto = <StayInCar />;
        text = t.car;
      } else if (state.eqSituation === 'outdoors') {
        picto = <OutdoorsProtect />;
        text = t.outdoors;
      } else {
        text = t.protect;
      }
      break;
    case 'goUphillNow':
      picto = <GoUphill />;
      text = t.goNow;
      break;
    case 'goUphill':
      picto = <GoUphill />;
      text = t.go;
      break;
    case 'stayHere':
      picto = <StayHere />;
      text = t.stay;
      break;
    default:
      break;
  }

  // Read the notification aloud when it appears (e.g. "Earthquake + Tsunami. Go uphill NOW").
  useAnnounceOnEnter(`${title}. ${text}`);

  return (
    <div className="tk-screen tk-screen--dark tk-s01">
      <div className="tk-s01__clock tk-heading" dir="ltr">
        {formatJst(state.now)}
      </div>
      <p className="tk-s01__sim">
        SIMULATED ALERT
        {c.simulatedAlert !== 'SIMULATED ALERT' && (
          <span lang={lang} style={{ display: 'block', marginTop: 2, textTransform: 'none' }}>
            {c.simulatedAlert}
          </span>
        )}
      </p>
      <section className="tk-s01__card" aria-label={title}>
        <div className="tk-s01__title">
          <Icon name="warning" size={30} />
          <span>{title}</span>
        </div>
        <div className="tk-s01__picto">{picto}</div>
        <p className="tk-s01__instruction tk-heading">{text}</p>
        <div className="tk-s01__open">
          <BigButton variant="black" onClick={() => dispatch(actions.patch({ lockScreen: false, overlay: [] }))}>
            {c.openGuide}
          </BigButton>
        </div>
      </section>
    </div>
  );
}
