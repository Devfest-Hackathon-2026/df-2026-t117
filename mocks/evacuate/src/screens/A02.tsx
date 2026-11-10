// A02 Alert details / official updates (light). Fictional data, clearly marked SIMULATED.
import { SubLayout } from '../components/SubLayout';
import { Badge } from '../components/Badge';
import { FooterMeta } from '../components/FooterMeta';
import { useAppState } from '../state/store';
import { alertBadgeLabel, bilingual, useCommon, useT } from '../i18n';
import { formatJstLabel, MINUTE_MS } from '../state/time';
import type { AlertLevel } from '../state/types';
import './t3.css';

const dict = {
  en: { title: 'Official updates', issued: 'Issued', area: 'Area', source: 'Source', timeline: 'Timeline', none: 'No active alerts', sim: 'SIMULATED: fictional data, not a real JMA alert.',
    t1: 'Earthquake information issued', t2: 'Tsunami warning issued for the coast', t3: 'Stay on high ground until the official all-clear' },
  ja: { title: '公式の続報', issued: '発表', area: '地域', source: '情報源', timeline: '時系列', none: '発表中の警報はありません', sim: '模擬データ：架空の情報であり、実際の気象庁の警報ではありません。',
    t1: '地震情報を発表', t2: '沿岸に津波警報を発表', t3: '解除の発表があるまで高台にとどまってください' },
  'zh-Hans': { title: '官方更新', issued: '发布', area: '区域', source: '来源', timeline: '时间线', none: '当前没有警报', sim: '模拟：虚构数据，并非真实的气象厅警报。',
    t1: '发布地震信息', t2: '对沿岸发布海啸警报', t3: '在官方解除前请留在高处' },
  ko: { title: '공식 업데이트', issued: '발표', area: '지역', source: '출처', timeline: '시간순 경과', none: '발령 중인 경보 없음', sim: '모의: 가상 데이터이며 실제 기상청 경보가 아닙니다.',
    t1: '지진 정보 발표', t2: '해안에 쓰나미 경보 발표', t3: '공식 해제 시까지 고지대에 머무르세요' },
  ar: { title: 'التحديثات الرسمية', issued: 'صدر', area: 'المنطقة', source: 'المصدر', timeline: 'التسلسل الزمني', none: 'لا توجد تنبيهات سارية', sim: 'تجريبي: بيانات خيالية وليست تنبيهًا حقيقيًا.',
    t1: 'صدرت معلومات الزلزال', t2: 'صدر تحذير تسونامي للساحل', t3: 'ابقَ في مكان مرتفع حتى الإعلان الرسمي عن زوال الخطر' },
};

export default function A02() {
  const t = useT(dict);
  const c = useCommon();
  const { alerts, lang } = useAppState();
  const sorted = [...alerts].sort((a, b) => b.issuedAt - a.issuedAt);
  const levelLabel = (l: AlertLevel) => (l === 'advisory' ? c.levelAdvisory : l === 'warning' ? c.levelWarning : c.levelEmergency);
  const base = sorted[0]?.issuedAt;
  const steps = base === undefined ? [] : [
    { at: base, text: t.t1 },
    { at: base + MINUTE_MS, text: t.t2 },
    { at: base + 2 * MINUTE_MS, text: t.t3 },
  ];

  return (
    <SubLayout
      theme="light"
      headerTitle={c.titleAlertDetails}
      title={t.title}
      footer={<FooterMeta theme="light" items={[c.jma, t.sim]} />}
    >
      {sorted.length === 0 && <p className="t3-p">{t.none}</p>}
      {sorted.map((a) => {
        const area = bilingual(a.area, lang);
        return (
          <div key={a.id} className="t3-card t3-card--plain">
            <div><Badge label={alertBadgeLabel(a, lang)} size="sm" /></div>
            <div className="t3-h">{levelLabel(a.level)}</div>
            <div className="t3-p">{t.area}: {area.primary}</div>
            {area.ja && <div className="t3-card__sub" lang="ja">{area.ja}</div>}
            <div className="t3-meta">
              {t.issued} {formatJstLabel(a.issuedAt)} • {t.source}: {c.jma}
            </div>
          </div>
        );
      })}
      {steps.length > 0 && (
        <>
          <h3 className="t3-h">{t.timeline}</h3>
          <ul className="t3-timeline">
            {steps.map((s, i) => (
              <li key={i}>
                <div className="t3-meta">{formatJstLabel(s.at)}</div>
                <div className="t3-p">{s.text}</div>
              </li>
            ))}
          </ul>
        </>
      )}
    </SubLayout>
  );
}
