// S04 route navigation (screen-04): big turn arrow, "Right / 40 m", voice + vibration status, mini map,
// legend, "On high ground", passability line. All route values come from useNavigation() (T1).
import { Header } from '../components/Header';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { FooterMeta } from '../components/FooterMeta';
import { Icon } from '../components/Icon';
import { TownMap } from '../components/TownMap';
import { actions, useAppState, useDispatch } from '../state/store';
import { canEnterAr, freshness } from '../state/derive';
import { formatJstLabel } from '../state/time';
import { useCommon, useLang, useT } from '../i18n';
import { useNavigation } from '../logic/nav';
import { turnSpeech } from '../logic/useNavEffects';
import { requestTiltOptIn, tiltSupported, useTiltStatus } from '../platform/orientation';
import { requestCompass } from '../platform/compass';
import { vibrationSupported } from '../platform/vibrate';
import { ListenButton } from './_guideShared';
import { AlertBand } from './_alertShared';
import { TurnArrow, useAnnounceFlash, useDirectionLabel, useMeters, useTsunamiBadge } from './_navShared';

export default function S04() {
  const state = useAppState();
  const dispatch = useDispatch();
  const lang = useLang();
  const c = useCommon();
  const nav = useNavigation();
  const t = useT({
    en: { demo: 'Demo', voiceOn: 'Voice guidance on', vibrationOn: 'Vibration on', vibrationVisual: 'Vibration (not supported on this device)', tilt: 'Raise for AR', tiltOn: 'Tilt on', mapLabel: 'Route map', arView: 'View in AR', arAria: 'View in AR (demo: simulates raising the phone)' },
    ja: { demo: 'デモ', voiceOn: '音声案内オン', vibrationOn: '振動オン', vibrationVisual: '振動（この端末は非対応）', tilt: '持ち上げて AR', tiltOn: '傾き検知オン', mapLabel: 'ルートの地図', arView: 'AR で見る', arAria: 'AR で見る（デモ：端末を持ち上げた状態を再現）' },
    'zh-Hans': { demo: '演示', voiceOn: '语音导航已开启', vibrationOn: '振动已开启', vibrationVisual: '振动（此设备不支持）', tilt: '举起手机用 AR', tiltOn: '倾斜检测已开启', mapLabel: '路线地图', arView: '用 AR 查看', arAria: '用 AR 查看（演示：模拟举起手机）' },
    ko: { demo: '데모', voiceOn: '음성 안내 켜짐', vibrationOn: '진동 켜짐', vibrationVisual: '진동(이 기기는 미지원)', tilt: '들어 올려 AR', tiltOn: '기울기 감지 켜짐', mapLabel: '경로 지도', arView: 'AR로 보기', arAria: 'AR로 보기(데모: 휴대폰을 들어 올린 상태를 재현)' },
    ar: { demo: 'تجريبي', voiceOn: 'الإرشاد الصوتي مفعّل', vibrationOn: 'الاهتزاز مفعّل', vibrationVisual: 'الاهتزاز (غير مدعوم على هذا الجهاز)', tilt: 'ارفع الهاتف للواقع المعزز', tiltOn: 'كشف الإمالة مفعّل', mapLabel: 'خريطة المسار', arView: 'عرض بالواقع المعزز', arAria: 'عرض بالواقع المعزز (تجريبي: يحاكي رفع الهاتف)' },
  });

  const direction = nav.nextTurn?.direction ?? 'straight';
  const distanceM = nav.nextTurn?.distanceM ?? 0;
  const dirLabel = useDirectionLabel(direction);
  const distLabel = useMeters(distanceM);
  const badge = useTsunamiBadge();
  const flash = useAnnounceFlash();
  const f = freshness(state);

  const tilt = useTiltStatus();
  const offerTilt = tiltSupported() && canEnterAr(state) && tilt === 'off';
  const canVibrate = vibrationSupported();

  const legend = [c.stripedHazard, nav.route.hasStairs ? c.stepsOnRoute : null].filter(Boolean) as string[];
  const footer =
    f.routeVerified && f.passabilityCheckedAt !== null
      ? [`${c.passabilityChecked} ${formatJstLabel(f.passabilityCheckedAt)}`, t.demo]
      : [c.routeUnverified, t.demo];

  return (
    <div className="tk-screen tk-screen--dark tk-nav">
      <Header variant="brand" accent="yellow" />
      <AlertBand />
      <section className="tk-nav__top">
        <div className="tk-nav__badge">
          <Badge label={badge} />
        </div>
        <div className="tk-nav__arrow">
          <TurnArrow direction={direction} />
        </div>
        <h2 className="tk-nav__dir tk-heading">{dirLabel}</h2>
        <div className="tk-nav__distrow">
          <div className={`tk-nav__status${flash ? ' tk-nav__status--flash' : ''}`}>
            <span className="tk-nav__statusicon" role="img" aria-label={t.voiceOn} title={t.voiceOn}>
              <Icon name="speaker" size={30} />
            </span>
            <span className="tk-nav__statusicon" role="img" aria-label={canVibrate ? t.vibrationOn : t.vibrationVisual} title={canVibrate ? t.vibrationOn : t.vibrationVisual}>
              <Icon name="vibrate" size={30} />
            </span>
          </div>
          <p className="tk-nav__dist tk-heading" aria-live="polite">
            {distLabel}
          </p>
          <div className="tk-nav__aside">
            {canEnterAr(state) && (
              <button
                type="button"
                className="tk-nav__arbtn"
                aria-label={t.arAria}
                title={t.arAria}
                onClick={() => {
                  // H5: on real devices this tap also asks for the compass (iOS allows the prompt only
                  // from a user gesture). Denied -> S11 keeps the fixed arrow (F3C). No-op on PCs.
                  void requestCompass();
                  dispatch(actions.patch({ deviceRaised: true }));
                }}
              >
                {t.arView}
              </button>
            )}
            {offerTilt && (
              <button
                type="button"
                className="tk-nav__tilt"
                // iOS: the orientation permission prompt may only be requested from this tap.
                onClick={() => void requestTiltOptIn()}
              >
                {t.tilt}
              </button>
            )}
          </div>
        </div>
      </section>
      <div className="tk-nav__mapband">
        <TownMap variant="mini" routeColor="blue" ariaLabel={t.mapLabel} />
      </div>
      <section className="tk-nav__bottom">
        <p className="tk-nav__legend">
          {legend.map((l, i) => (
            <span key={l}>
              {i > 0 && <span className="tk-nav__dot" aria-hidden="true">•</span>}
              {l}
            </span>
          ))}
        </p>
        <div className="tk-nav__actions">
          <BigButton variant="white" icon="flag" onClick={() => dispatch(actions.patch({ onHighGround: true, walk: { playing: false } }))}>
            {c.onHighGround}
          </BigButton>
        </div>
        <ListenButton text={turnSpeech(lang, direction, distanceM)} />
        <FooterMeta items={footer} />
      </section>
    </div>
  );
}
