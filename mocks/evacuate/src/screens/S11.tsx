// S11 AR guidance (screen-11 / demo-guide-04 left phone): camera view of the street with the turn arrow,
// "Right 12 m" card, landmark alignment status, and a bottom MAP sheet. S11 and S04 share the same route,
// walk position and next turn (useNavigation), so the camera and the map point at the same corner (F38).
// H5 (architecture.md 10.1): on real devices the background is the rear camera and the arrow is rotated by
// the compass; PCs (demo panel), a denied camera or a missing compass keep the still image / fixed arrow
// (F3C). An unreliable compass hides the arrow and shows "AR paused / Calibrate compass" (F3B).
// Android also gets a button that opens the Flutter AR app (H4) with the same turn / distance / bearing.
import { useRef } from 'react';
import { Header } from '../components/Header';
import { Badge } from '../components/Badge';
import { Icon } from '../components/Icon';
import { TownMap } from '../components/TownMap';
import { useAppState } from '../state/store';
import { bilingual, isRtl, useCommon, useLang, useT } from '../i18n';
import { useNavigation } from '../logic/nav';
import { turnSpeech } from '../logic/useNavEffects';
import { landmarkNear } from '../data/landmarks';
import { ListenButton } from './_guideShared';
import { AlertBand } from './_alertShared';
import { useDirectionLabel, useMeters, useTsunamiBadge } from './_navShared';
import { ArScene } from './_arScene';
import { angleDelta, bearing, dist } from '../logic/geometry';
import type { Lang } from '../i18n';
import type { TurnDirection } from '../logic/nav';
import { tiltSupported } from '../platform/orientation';
import { useBackCamera } from '../platform/camera';
import { requestCompass, useCompassHeading, useCompassStatus } from '../platform/compass';

/** The arrow is drawn on the road ahead, so it is turned at most this far to either side. */
const MAX_ARROW_ROTATE_DEG = 90;
/** Package of the Flutter AR guide (apps/ar_guide, applicationId). */
const AR_APP_PACKAGE = 'jp.tasuku.ar_guide';
/** The next turn counts as "behind" above this angle, and stops counting below TURN_AROUND_EXIT_DEG. */
const TURN_AROUND_ENTER_DEG = 120;
const TURN_AROUND_EXIT_DEG = 110;

function isAndroid(): boolean {
  return typeof navigator !== 'undefined' && /Android/i.test(navigator.userAgent);
}

/**
 * intent:// link to the AR app (tasuku-ar://guide?..., see apps/ar_guide guide_params.dart).
 * No S.browser_fallback_url: a fallback page load would reset the mock (its state is not saved).
 * Without it, a missing app just opens the Play Store and the tab keeps the demo state.
 */
function arAppIntent(p: { turn: TurnDirection; distM: number; dest: string; destJa: string | null; lang: Lang; bearingDeg: number }): string {
  const q: [string, string][] = [
    ['turn', p.turn],
    ['dist', String(Math.round(p.distM))],
    ['dest', p.dest],
    ['lang', p.lang],
    ['bearing', String(Math.round(p.bearingDeg) % 360)],
  ];
  if (p.destJa) q.push(['dest_ja', p.destJa]);
  const query = q.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
  return `intent://guide?${query}#Intent;scheme=tasuku-ar;package=${AR_APP_PACKAGE};end`;
}

export default function S11() {
  const state = useAppState();
  const lang = useLang();
  const c = useCommon();
  const nav = useNavigation();
  const t = useT({
    en: {
      matched: 'Landmark matched', matching: 'Matching landmark…', camera: 'Camera view (demo still image) with the route arrow', mapLabel: 'Route map',
      cameraLive: 'Live camera view with the route arrow', useCompass: 'Point arrow with compass',
      calibrate: 'Calibrate compass', calibrateSub: 'Move your phone in a figure 8. Follow the map below meanwhile.',
      openApp: 'Open AR app', openAppAria: 'Open the AR guide app (Android)',
      noCompass: 'Compass unavailable', turnAround: 'Turn around',
    },
    ja: {
      matched: '目印と一致', matching: '目印を照合中…', camera: 'カメラ映像（デモ用の静止画）と経路の矢印', mapLabel: 'ルートの地図',
      cameraLive: 'カメラ映像と経路の矢印', useCompass: 'コンパスで矢印を合わせる',
      calibrate: 'コンパスを補正してください', calibrateSub: '端末を 8 の字に動かしてください。その間は下の地図に従ってください。',
      openApp: 'AR アプリで開く', openAppAria: 'AR 案内アプリを開く（Android）',
      noCompass: 'コンパスを使えません', turnAround: '後ろを向いてください',
    },
    'zh-Hans': {
      matched: '地标已匹配', matching: '正在匹配地标…', camera: '相机画面（演示静态图）与路线箭头', mapLabel: '路线地图',
      cameraLive: '实时相机画面与路线箭头', useCompass: '用指南针对准箭头',
      calibrate: '请校准指南针', calibrateSub: '请将手机按 8 字形移动。期间请按下方地图前进。',
      openApp: '在 AR 应用中打开', openAppAria: '打开 AR 导航应用（Android）',
      noCompass: '指南针不可用', turnAround: '请向后转',
    },
    ko: {
      matched: '랜드마크 일치', matching: '랜드마크 확인 중…', camera: '카메라 화면(데모 정지 이미지)과 경로 화살표', mapLabel: '경로 지도',
      cameraLive: '실시간 카메라 화면과 경로 화살표', useCompass: '나침반으로 화살표 맞추기',
      calibrate: '나침반을 보정하세요', calibrateSub: '휴대폰을 8자 모양으로 움직이세요. 그동안은 아래 지도를 따라가세요.',
      openApp: 'AR 앱에서 열기', openAppAria: 'AR 안내 앱 열기(Android)',
      noCompass: '나침반을 사용할 수 없음', turnAround: '뒤로 도세요',
    },
    ar: {
      matched: 'تمت مطابقة المعلم', matching: 'جارٍ مطابقة المعلم…', camera: 'عرض الكاميرا (صورة ثابتة تجريبية) مع سهم المسار', mapLabel: 'خريطة المسار',
      cameraLive: 'عرض الكاميرا المباشر مع سهم المسار', useCompass: 'وجّه السهم بالبوصلة',
      calibrate: 'قم بمعايرة البوصلة', calibrateSub: 'حرّك هاتفك على شكل الرقم 8. اتبع الخريطة أدناه في هذه الأثناء.',
      openApp: 'افتح تطبيق الواقع المعزز', openAppAria: 'افتح تطبيق إرشاد الواقع المعزز (Android)',
      noCompass: 'البوصلة غير متاحة', turnAround: 'استدر للخلف',
    },
  });

  const direction = nav.nextTurn?.direction ?? 'straight';
  const distanceM = nav.nextTurn?.distanceM ?? 0;
  const dirLabel = useDirectionLabel(direction);
  const distLabel = useMeters(distanceM);
  const badge = useTsunamiBadge();

  // Landmark alignment (F39): a registered sign near the next turn + the mock recognition result.
  // Recognition is supplementary: the arrow depends only on tracking + passability, not on the match.
  const landmark = nav.nextTurn ? landmarkNear(nav.nextTurn.point) : null;
  const matched = state.ar.landmarkFound && landmark !== null;
  const showBox = matched && state.ar.showDetection;
  const showArrow = nav.nextSegmentVerified && nav.nextTurn !== null;

  const dest = bilingual(nav.route.refuge.name, lang);

  // H5: rear camera + compass on real devices only. PCs (pointer: fine) keep the still street.
  const realDevice = tiltSupported();
  const camera = useBackCamera(realDevice);
  const compassStatus = useCompassStatus();
  const compass = useCompassHeading(compassStatus === 'on');
  // Way to walk now: towards the next turn (or the route end); along the segment when at the corner.
  const turnPoint = nav.nextTurn?.point ?? null;
  const targetBearing = turnPoint && dist(nav.position, turnPoint) > 1 ? bearing(nav.position, turnPoint) : nav.headingDeg;
  const compassPaused = showArrow && compassStatus === 'on' && compass.quality === 'poor';
  // No compass on this device (no usable value within 3 s): fixed arrow + a small note (F3C).
  const noCompass = compassStatus === 'on' && compass.quality === 'none';
  const delta =
    compassStatus === 'on' && compass.quality === 'ok' && compass.headingDeg !== null
      ? angleDelta(compass.headingDeg, targetBearing)
      : null;
  // Turn behind the user: show "Turn around" instead of a +-90 arrow, with a small hysteresis so the
  // arrow does not swing between left and right around +-180.
  const turnAroundRef = useRef(false);
  if (delta === null) turnAroundRef.current = false;
  else if (Math.abs(delta) > TURN_AROUND_ENTER_DEG) turnAroundRef.current = true;
  else if (Math.abs(delta) < TURN_AROUND_EXIT_DEG) turnAroundRef.current = false;
  const turnAround = turnAroundRef.current;
  const arrowRotateDeg =
    delta === null || turnAround ? null : Math.max(-MAX_ARROW_ROTATE_DEG, Math.min(MAX_ARROW_ROTATE_DEG, delta));
  const offerArApp = realDevice && isAndroid() && nav.nextTurn !== null;
  // Keep the overlay cards on the side opposite the turn (physical left for Right/Straight, right for Left),
  // whatever the text direction, so they never cover the arrow head.
  const physicalLeft = direction !== 'left';
  const overlayAlign = physicalLeft !== isRtl(lang) ? 'flex-start' : 'flex-end';

  return (
    <div className="tk-screen tk-screen--dark tk-ar">
      <Header variant="sub" title={c.titleArGuidance} accent="red" />
      <AlertBand />
      <div className="tk-ar__camera">
        <ArScene
          direction={direction}
          showArrow={showArrow && !compassPaused}
          showDetection={showBox}
          ariaLabel={camera.stream ? t.cameraLive : t.camera}
          cameraStream={camera.stream}
          arrowRotateDeg={arrowRotateDeg}
          turnAround={turnAround}
        />
        {compassPaused && (
          <div className="tk-ar__paused" role="status">
            <Badge label={c.badgeArPaused} size="sm" />
            <span className="tk-ar__paused-title tk-heading">{t.calibrate}</span>
            <span className="tk-ar__paused-sub">{t.calibrateSub}</span>
          </div>
        )}
        <div className="tk-ar__overlay" style={{ alignItems: overlayAlign }}>
          <Badge label={badge} />
          <div className="tk-ar__card" aria-live="polite">
            <span className="tk-ar__card-dir tk-heading">{dirLabel}</span>
            <span className="tk-ar__card-dist">{distLabel}</span>
          </div>
          {showBox && landmark && (
            <span className="tk-ar__chip tk-ar__chip--ok">
              <Icon name="check" size={16} />
              <span>
                {t.matched}
                <span className="tk-ar__chip-sub">{landmark.name[lang]}</span>
              </span>
            </span>
          )}
          {!matched && (
            <span className="tk-ar__chip tk-ar__chip--pending">
              <span className="tk-ar__spinner" aria-hidden="true" />
              <span>{t.matching}</span>
            </span>
          )}
          {showArrow && turnAround && !compassPaused && (
            <span className="tk-ar__chip tk-ar__chip--ok" role="status">
              <span>{t.turnAround}</span>
            </span>
          )}
          {showArrow && noCompass && (
            <span className="tk-ar__chip tk-ar__chip--note">
              <span>{t.noCompass}</span>
            </span>
          )}
          {compassStatus === 'prompt' && (
            // iOS: the orientation permission can only be requested from a tap (F3C: denied -> fixed arrow).
            <button type="button" className="tk-ar__chip tk-ar__chipbtn" onClick={() => void requestCompass()}>
              <Icon name="pin" size={16} />
              <span>{t.useCompass}</span>
            </button>
          )}
          {offerArApp && (
            <a
              className="tk-ar__chip tk-ar__chipbtn"
              href={arAppIntent({
                turn: direction,
                distM: distanceM,
                dest: dest.primary,
                destJa: dest.ja,
                lang,
                bearingDeg: targetBearing,
              })}
              aria-label={t.openAppAria}
            >
              <Icon name="arrow-right" size={16} />
              <span>{t.openApp}</span>
            </a>
          )}
        </div>
      </div>
      <section className="tk-ar__sheet">
        <div className="tk-ar__sheetrow">
          {/* F80: the fixed Listen button sits at the start of the sheet's top row (decision 14.7-1). */}
          {/* H6: while "Turn around" is shown, the button reads that (a Chirp 3 HD clip) instead of the turn. */}
          <ListenButton
            text={showArrow && turnAround && !compassPaused ? t.turnAround : turnSpeech(lang, direction, distanceM)}
            placement="sheet"
          />
          <span className="tk-ar__maptitle">
            <Icon name="map-download" size={26} />
            <span className="tk-heading">{c.map}</span>
          </span>
          <span className="tk-ar__dest">
            {dest.primary}
            {dest.ja && (
              <>
                <span className="tk-ar__sep">/</span>
                <span lang="ja">{dest.ja}</span>
              </>
            )}
          </span>
        </div>
        <TownMap
          variant="mini"
          routeColor="yellow"
          showHeading
          headingDeg={compassStatus === 'on' && compass.quality === 'ok' ? compass.headingDeg : null}
          ariaLabel={t.mapLabel}
        />
        <div className="tk-ar__sheetfoot">
          <span>{c.stripedHazard}</span>
        </div>
      </section>
    </div>
  );
}
