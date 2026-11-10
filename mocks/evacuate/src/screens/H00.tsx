// H00 home (normal mode): calm status card, disaster-guide buttons, preparedness column, translation note.
import { Header } from '../components/Header';
import { Icon } from '../components/Icon';
import { BigButton } from '../components/BigButton';
import { Badge } from '../components/Badge';
import { ProtectHead, GoUphill } from '../components/pictograms';
import { setA03InitialTab } from './A03';
import { actions, useAppState, useDispatch } from '../state/store';
import { formatJstLabel } from '../state/time';
import { mostSevere } from '../state/derive';
import { alertBadgeLabel, useCommon, useLang, useT } from '../i18n';
import { useLiveAlerts } from '../live/LiveAlerts';
import './H00.css';

export default function H00() {
  const state = useAppState();
  const dispatch = useDispatch();
  const lang = useLang();
  const c = useCommon();
  const live = useLiveAlerts();
  const n = useT({
    en: { enable: 'Get alert notifications', working: 'Setting up notifications…', on: 'Alert notifications are on', denied: 'Notifications are blocked in browser settings', error: 'Could not turn on notifications. Try again.', unsupported: 'Notifications are not supported on this device. Alerts still update in the app.' },
    ja: { enable: '警報の通知を受け取る', working: '通知を設定しています…', on: '警報の通知はオンです', denied: 'ブラウザの設定で通知が拒否されています', error: '通知を設定できませんでした。もう一度お試しください。', unsupported: 'この端末は通知に対応していません。警報はアプリ内で更新されます。' },
    'zh-Hans': { enable: '接收警报通知', working: '正在设置通知…', on: '警报通知已开启', denied: '浏览器设置中已阻止通知', error: '无法开启通知，请重试。', unsupported: '此设备不支持通知。警报仍会在应用内更新。' },
    ko: { enable: '경보 알림 받기', working: '알림을 설정하는 중…', on: '경보 알림이 켜져 있습니다', denied: '브라우저 설정에서 알림이 차단되어 있습니다', error: '알림을 설정하지 못했습니다. 다시 시도하세요.', unsupported: '이 기기는 알림을 지원하지 않습니다. 경보는 앱에서 계속 업데이트됩니다.' },
    ar: { enable: 'تلقي إشعارات التنبيه', working: 'جارٍ إعداد الإشعارات…', on: 'إشعارات التنبيه مفعّلة', denied: 'الإشعارات محظورة في إعدادات المتصفح', error: 'تعذّر تفعيل الإشعارات. حاول مرة أخرى.', unsupported: 'هذا الجهاز لا يدعم الإشعارات. ستظل التنبيهات تتحدث داخل التطبيق.' },
  });
  const t = useT({
    en: { none: 'No active alerts', advisory: 'Advisory in effect', warning: 'Warning in effect', emergency: 'Emergency warning in effect', updated: 'Last updated', guides: 'Disaster guides', prep: 'Disaster preparedness in Japan' },
    ja: { none: '警報はありません', advisory: '注意報が出ています', warning: '警報が出ています', emergency: '特別警報が出ています', updated: '最終更新', guides: '災害別ガイド', prep: '日本の防災について' },
    'zh-Hans': { none: '当前无警报', advisory: '注意报生效中', warning: '警报生效中', emergency: '特别警报生效中', updated: '最近更新', guides: '灾害指南', prep: '日本防灾知识' },
    ko: { none: '발령 중인 경보 없음', advisory: '주의보 발령 중', warning: '경보 발령 중', emergency: '특별 경보 발령 중', updated: '마지막 업데이트', guides: '재난별 안내', prep: '일본의 방재 안내' },
    ar: { none: 'لا توجد تنبيهات حالية', advisory: 'إشعار ساري', warning: 'تحذير ساري', emergency: 'تحذير طارئ ساري', updated: 'آخر تحديث', guides: 'أدلة الكوارث', prep: 'الاستعداد للكوارث في اليابان' },
  });
  const hasAlert = state.alerts.length > 0;
  const worst = mostSevere(state.alerts);
  const statusText = worst ? (worst.level === 'advisory' ? t.advisory : worst.level === 'emergency' ? t.emergency : t.warning) : t.none;
  const go = (id: 'A03' | 'A04' | 'A02' | 'S08') => () => dispatch(actions.navigate(id));

  return (
    <div className="tk-screen tk-screen--dark">
      <Header variant="brand" accent="yellow" />
      <div className="tk-h00__body">
        <section className="tk-h00__status" aria-live="polite">
          <div className="tk-h00__statusrow">
            <span className={`tk-h00__check ${hasAlert ? 'tk-h00__check--alert' : ''}`}>
              <Icon name={hasAlert ? 'warning' : 'check'} size={24} />
            </span>
            <h2 className="tk-h00__status-title tk-heading">{statusText}</h2>
          </div>
          {hasAlert && (
            <div style={{ paddingInlineStart: 52, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {state.alerts.map((a) => (
                <Badge key={a.id} size="sm" label={alertBadgeLabel(a, lang)} />
              ))}
            </div>
          )}
          <p className="tk-h00__updated">
            {t.updated} {formatJstLabel(state.lastFetchAt)}
          </p>
        </section>

        <h3 className="tk-h00__heading">{t.guides}</h3>
        <div className="tk-h00__grid">
          <button type="button" className="tk-h00__tile" onClick={go('A03')}>
            <span className="tk-h00__tile-picto">
              <ProtectHead />
            </span>
            <span className="tk-h00__tile-label">{c.badgeEarthquake}</span>
          </button>
          <button type="button" className="tk-h00__tile" onClick={() => {
            setA03InitialTab('tsunami');
            dispatch(actions.navigate('A03'));
          }}>
            <span className="tk-h00__tile-picto">
              <GoUphill />
            </span>
            <span className="tk-h00__tile-label">{c.badgeTsunami}</span>
          </button>
        </div>

        <div className="tk-h00__spacer" />
        {hasAlert && (
          <BigButton variant="outline" icon="clock" onClick={go('A02')}>
            {c.officialUpdates}
          </BigButton>
        )}
        {live.pushSupport === 'supported' && (live.pushState === 'idle' || live.pushState === 'error') ? (
          <>
            <BigButton variant="outline" icon="bell" onClick={live.enablePush}>
              {n.enable}
            </BigButton>
            {live.pushState === 'error' && <p className="tk-h00__note">{n.error}</p>}
          </>
        ) : live.pushSupport !== 'checking' ? (
          <p className="tk-h00__note" aria-live="polite">
            {live.pushSupport !== 'supported'
              ? n.unsupported
              : live.pushState === 'working'
                ? n.working
                : live.pushState === 'denied'
                  ? n.denied
                  : n.on}
          </p>
        ) : null}
        <BigButton variant="outline" icon="map-download" onClick={go('S08')}>
          {c.savedMap}
        </BigButton>
        <BigButton variant="primary" icon="shield" onClick={go('A04')}>
          {t.prep}
        </BigButton>
        <p className="tk-h00__note">{c.translationNote}</p>
      </div>
    </div>
  );
}
