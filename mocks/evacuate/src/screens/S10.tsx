// S10 Emergency "Call for help" (light). The demo never dials unless dialerEnabled (decision #5).
import { SubLayout } from '../components/SubLayout';
import { Icon, type IconName } from '../components/Icon';
import { FooterMeta } from '../components/FooterMeta';
import { actions, useAppState, useDispatch } from '../state/store';
import { useNavigation } from '../logic/nav';
import { addressAt } from '../data/town';
import { bilingual, fmt, useCommon, useT } from '../i18n';
import './t3.css';

const dict = {
  en: { title: 'Call for help', ambulance: 'Ambulance', fire: 'Fire', police: 'Police', show: 'Show this location', footer: 'Opens the system dialer', demoCall: 'Demo: would call {n}', confirm: 'Call {n}?' },
  ja: { title: '助けを呼ぶ', ambulance: '救急', fire: '消防', police: '警察', show: 'この場所を伝える', footer: '電話アプリが開きます', demoCall: 'デモ：{n} に発信します', confirm: '{n} に発信しますか？' },
  'zh-Hans': { title: '呼叫救援', ambulance: '急救', fire: '消防', police: '警察', show: '出示此位置', footer: '将打开系统拨号器', demoCall: '演示：将拨打 {n}', confirm: '拨打 {n}？' },
  ko: { title: '도움 요청', ambulance: '구급', fire: '소방', police: '경찰', show: '이 위치 보여주기', footer: '시스템 전화 앱이 열립니다', demoCall: '데모: {n}에 전화합니다', confirm: '{n}에 전화할까요?' },
  ar: { title: 'اطلب المساعدة', ambulance: 'إسعاف', fire: 'إطفاء', police: 'شرطة', show: 'أظهر هذا الموقع', footer: 'يفتح تطبيق الاتصال بالنظام', demoCall: 'تجريبي: سيتم الاتصال بـ {n}', confirm: 'الاتصال بـ {n}؟' },
};

export default function S10() {
  const t = useT(dict);
  const c = useCommon();
  const { lang, dialerEnabled } = useAppState();
  const dispatch = useDispatch();
  const place = bilingual(addressAt(useNavigation().position), lang);

  const call = (n: string) => {
    if (!dialerEnabled) {
      dispatch(actions.showToast(fmt(t.demoCall, { n })));
      return;
    }
    if (window.confirm(fmt(t.confirm, { n }))) window.location.href = `tel:${n}`;
  };

  const rows: { icon: IconName; label: string; n: string }[] = [
    { icon: 'heart-pulse', label: t.ambulance, n: '119' },
    { icon: 'fire', label: t.fire, n: '119' },
    { icon: 'shield', label: t.police, n: '110' },
  ];

  return (
    <SubLayout
      theme="light"
      headerTitle={c.titleEmergency}
      title={t.title}
      actions={
        <>
          <div className="t3-card">
            <div className="t3-card__head">
              <Icon name="pin" size={26} />
              {t.show}
            </div>
            <div className="t3-card__big">{place.primary}</div>
            {place.ja && (
              <div className="t3-card__sub" lang="ja" dir="ltr">
                {place.ja}
              </div>
            )}
          </div>
        </>
      }
      footer={<FooterMeta theme="light" items={[t.footer]} />}
    >
      <div className="t3-list">
        {rows.map((r) => (
          <button key={r.label} type="button" className="t3-row t3-row--call" onClick={() => call(r.n)}>
            <span className="t3-row__icon">
              <Icon name={r.icon} size={26} />
            </span>
            <span className="t3-row__label">{r.label}</span>
            <span className="t3-row__num" dir="ltr">
              {r.n}
            </span>
          </button>
        ))}
      </div>
    </SubLayout>
  );
}
