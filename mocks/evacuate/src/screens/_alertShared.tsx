// FB2 / FB3 / FB4 parts shared by the guidance screens:
//  - AlertBand: "UPGRADED: Major Tsunami Warning • 09:43" band under the header (F88 / F89 / F8A)
//  - MarginCard: elevation / expected tsunami / margin card on S06 (F83-F85, F87)
//  - useGuideT: strings for "Go higher.", the signs hint and "Set location" (F85 / F92 / F94)
import type { ExpectedHeight, Lang } from '../state/types';
import { actions, useAppState, useDispatch } from '../state/store';
import { deriveMode } from '../state/derive';
import { formatJst } from '../state/time';
import { common, fmt, useCommon, useLang, useT } from '../i18n';
import { Icon } from '../components/Icon';
import type { MarginInfo } from '../logic/margin';
import './alert.css';

const guideDict = {
  en: { goHigher: 'Go higher.', followSigns: 'Follow the blue evacuation signs', setLocation: 'Set location' },
  ja: { goHigher: 'もっと高い所へ。', followSigns: '青い津波避難の標識に従う', setLocation: '現在地を設定' },
  'zh-Hans': { goHigher: '去更高处。', followSigns: '跟随蓝色海啸避难标志', setLocation: '设置位置' },
  ko: { goHigher: '더 높은 곳으로.', followSigns: '파란색 쓰나미 대피 표지판을 따라가세요', setLocation: '위치 설정' },
  ar: { goHigher: 'اصعد إلى مكان أعلى.', followSigns: 'اتبع لافتات الإخلاء الزرقاء', setLocation: 'حدد الموقع' },
};

/** "Go higher." / "Follow the blue evacuation signs" / "Set location" in the current language. */
export function useGuideT() {
  return useT(guideDict);
}

const heightDict: Record<Lang, { over10: string; huge: string; high: string }> = {
  en: { over10: 'over 10 m', huge: 'huge', high: 'high' },
  ja: { over10: '10 m 超', huge: '巨大', high: '高い' },
  'zh-Hans': { over10: '超过 10 米', huge: '巨大', high: '高' },
  ko: { over10: '10m 초과', huge: '거대', high: '높음' },
  ar: { over10: 'أكثر من 10 م', huge: 'هائل', high: 'مرتفع' },
};

/** "3 m" / "over 10 m" / "huge" / "high" (F84: a qualitative first bulletin is shown as is). */
export function heightLabel(h: ExpectedHeight, lang: Lang): string {
  if (typeof h === 'number') return fmt(common[lang].meters, { n: h });
  return heightDict[lang][h];
}

/** Badge-style name of a tsunami level (TSUNAMI ADVISORY / TSUNAMI WARNING / MAJOR TSUNAMI WARNING). */
function tsunamiLevelLabel(level: 'advisory' | 'warning' | 'emergency', lang: Lang): string {
  const c = common[lang];
  return level === 'emergency' ? c.badgeMajorTsunamiWarning : level === 'advisory' ? c.badgeTsunamiAdvisory : c.badgeTsunamiWarning;
}

// ---------------------------------------------------------------------------
// Alert-change band (F88 / F89 / F8A)

const bandDict = {
  en: { upgrade: 'UPGRADED', raise: 'HEIGHT RAISED', downgrade: 'DOWNGRADED', expected: 'Expected {h}', keepGoing: 'Keep going to high ground', stayAll: 'Stay until all alerts are lifted' },
  ja: { upgrade: '格上げ', raise: '高さ引き上げ', downgrade: '格下げ', expected: '予想 {h}', keepGoing: 'このまま高台へ', stayAll: 'すべて解除されるまで待機' },
  'zh-Hans': { upgrade: '已升级', raise: '预计高度上调', downgrade: '已降级', expected: '预计 {h}', keepGoing: '继续前往高处', stayAll: '在全部警报解除前请留在此处' },
  ko: { upgrade: '격상', raise: '예상 높이 상향', downgrade: '격하', expected: '예상 {h}', keepGoing: '계속 높은 곳으로 가세요', stayAll: '모든 경보가 해제될 때까지 머무르세요' },
  ar: { upgrade: 'رُفع المستوى', raise: 'رُفع الارتفاع المتوقع', downgrade: 'خُفض المستوى', expected: 'المتوقع {h}', keepGoing: 'واصل التوجه إلى مكان مرتفع', stayAll: 'ابقَ حتى تُرفع جميع التنبيهات' },
};

/**
 * Band under the header after an upgrade / raised height / downgrade. Stays until the next change, until
 * every alert is lifted, or until closed. Upgrade / raise: yellow, role=alert (part of the re-notification).
 * Downgrade: grey, and guidance does not loosen (F8A): "Keep going" / "Stay until all alerts are lifted".
 * Shown on S02 too: while shaking only this band changes (14.4).
 */
export function AlertBand() {
  const state = useAppState();
  const dispatch = useDispatch();
  const lang = useLang();
  const c = useCommon();
  const t = useT(bandDict);
  const change = state.alertChange;
  if (!change) return null;
  const level = tsunamiLevelLabel(change.level, lang);
  const height = change.expectedHeight !== null ? fmt(t.expected, { h: heightLabel(change.expectedHeight, lang) }) : null;
  const mode = deriveMode(state);
  const tail = change.kind !== 'downgrade' ? null : mode === 'safe' ? t.stayAll : mode === 'evacuate' ? t.keepGoing : null;
  const main = change.kind === 'raise' ? height : level;
  const sub = change.kind === 'raise' ? null : height;
  return (
    <div className={`tk-band tk-band--${change.kind}`} role={change.kind === 'downgrade' ? 'status' : 'alert'}>
      <Icon name={change.kind === 'downgrade' ? 'clock' : 'warning'} size={22} />
      <p className="tk-band__text">
        <b>
          {t[change.kind]}: {main}
        </b>
        <span className="tk-band__meta">{[sub, `${formatJst(change.at)} ${c.jst}`, tail].filter(Boolean).join(' • ')}</span>
      </p>
      <button type="button" className="tk-band__close" aria-label={c.close} onClick={() => dispatch(actions.patch({ alertChange: null }))}>
        <Icon name="close" size={20} />
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Margin card (S06)

const cardDict = {
  en: { title: 'Why here', approx: 'Location approximate', elevation: 'Elevation {v}', elevUnknown: 'Elevation unknown', expected: 'Expected tsunami {h}', highest: '(highest announced)', above: '{n} m above forecast', below: '{n} m below forecast', stayUntil: 'Stay until the warning is lifted', staff: 'Follow staff instructions' },
  ja: { title: 'ここで待つ理由', approx: '現在地はおおまか', elevation: '標高 {v}', elevUnknown: '標高は不明', expected: '予想される津波 {h}', highest: '（これまでの最大）', above: '予想より {n} m 高い', below: '予想より {n} m 低い', stayUntil: '警報が解除されるまで待機', staff: '係員の指示に従う' },
  'zh-Hans': { title: '为什么在这里', approx: '位置为大致位置', elevation: '海拔 {v}', elevUnknown: '海拔未知', expected: '预计海啸 {h}', highest: '（已发布的最高值）', above: '比预计高 {n} 米', below: '比预计低 {n} 米', stayUntil: '请等到警报解除', staff: '请听从工作人员的指示' },
  ko: { title: '여기서 기다리는 이유', approx: '위치가 대략적입니다', elevation: '해발 {v}', elevUnknown: '해발 알 수 없음', expected: '예상 쓰나미 {h}', highest: '(지금까지 최고)', above: '예상보다 {n}m 높음', below: '예상보다 {n}m 낮음', stayUntil: '경보가 해제될 때까지 머무르세요', staff: '직원의 안내에 따르세요' },
  ar: { title: 'لماذا هنا', approx: 'الموقع تقريبي', elevation: 'الارتفاع {v}', elevUnknown: 'الارتفاع غير معروف', expected: 'التسونامي المتوقع {h}', highest: '(الأعلى المُعلن)', above: 'أعلى من المتوقع بـ {n} م', below: 'أدنى من المتوقع بـ {n} م', stayUntil: 'ابقَ حتى يُرفع التحذير', staff: 'اتبع تعليمات الموظفين' },
};

/** Card strings (also used for the spoken text). */
export function useMarginText(m: MarginInfo): { margin: string | null; elevation: string; expected: string | null; staff: string } {
  const lang = useLang();
  const c = useCommon();
  const t = useT(cardDict);
  const r = (n: number) => Math.round(n);
  const elevValue =
    m.elevMinM === null || m.elevMaxM === null
      ? null
      : m.approximate && r(m.elevMaxM) !== r(m.elevMinM)
        ? fmt(c.meters, { n: `${r(m.elevMinM)}–${r(m.elevMaxM)}` })
        : fmt(c.meters, { n: r(m.elevMinM) });
  const elevation = elevValue ? fmt(t.elevation, { v: elevValue }) : t.elevUnknown;
  const expected = m.heightInUse !== null ? fmt(t.expected, { h: heightLabel(m.heightInUse, lang) }) : null;
  const margin = m.marginM === null ? null : fmt(m.marginM >= 0 ? t.above : t.below, { n: Math.abs(r(m.marginM)) });
  return { margin, elevation, expected, staff: t.staff };
}

/**
 * F83 elevation, F84 expected height, F85 margin (big, colour + icon by the 14.3 table), F87 how long to wait.
 * Never says "safe": only the fact "N m above forecast". Calm colour (not green) when the margin is ample.
 * At a designated evacuation site the instruction stays "Stay here." and the card adds "Follow staff instructions".
 */
export function MarginCard({ margin: m, staying }: { margin: MarginInfo; staying: boolean }) {
  const t = useT(cardDict);
  const text = useMarginText(m);
  const level = m.level ?? 'none';
  const highestNotNow = m.heightInUse !== null && m.heightNow !== null && m.heightInUse !== m.heightNow;
  return (
    <section className={`tk-margin tk-margin--${level}`} aria-label={t.title}>
      {text.margin && (
        <p className="tk-margin__big">
          <Icon name={level === 'ample' ? 'flag' : 'warning'} size={30} />
          <span className="tk-heading">{text.margin}</span>
        </p>
      )}
      <p className="tk-margin__facts">
        <span>{text.elevation}</span>
        {text.expected && (
          <span>
            {text.expected}
            {highestNotNow && <span className="tk-margin__note"> {t.highest}</span>}
          </span>
        )}
      </p>
      {m.approximate && <p className="tk-margin__approx">{t.approx}</p>}
      {staying && <p className="tk-margin__until">{t.stayUntil}</p>}
      {m.designated && <p className="tk-margin__staff">{t.staff}</p>}
    </section>
  );
}
