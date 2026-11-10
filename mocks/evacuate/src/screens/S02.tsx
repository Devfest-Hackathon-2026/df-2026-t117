// S02 earthquake, shaking now. Tap the badge to cycle INDOORS -> OUTDOORS -> IN CAR (decision 12-4).
import { GuidanceLayout } from '../components/GuidanceLayout';
import { Badge } from '../components/Badge';
import { BigButton } from '../components/BigButton';
import { ProtectHead, OutdoorsProtect, StayInCar } from '../components/pictograms';
import { actions, useAppState, useDispatch } from '../state/store';
import { eqSituationLabel, useCommon, useLang, useT } from '../i18n';
import type { EqSituation } from '../state/types';
import { GuideFooter, ListenButton, useAnnounceOnEnter } from './_guideShared';
import { AlertBand } from './_alertShared';

const NEXT: Record<EqSituation, EqSituation> = { indoors: 'outdoors', outdoors: 'car', car: 'indoors' };

export default function S02() {
  const { eqSituation } = useAppState();
  const dispatch = useDispatch();
  const lang = useLang();
  const c = useCommon();
  const t = useT({
    en: { indoors: 'Protect your head', outdoors: 'Protect your head', outdoorsSub: 'Stay away from buildings', car: 'Pull over. Stay inside.', carSub: 'Wait until the shaking stops', switchSituation: 'Change situation' },
    ja: { indoors: '頭を守れ', outdoors: '頭を守れ', outdoorsSub: '建物から離れる', car: '停車。車内で待つ。', carSub: '揺れがおさまるまで', switchSituation: '状況を切り替え' },
    'zh-Hans': { indoors: '保护头部', outdoors: '保护头部', outdoorsSub: '远离建筑物', car: '靠边停车，留在车内。', carSub: '等到摇晃停止', switchSituation: '切换场景' },
    ko: { indoors: '머리를 보호하세요', outdoors: '머리를 보호하세요', outdoorsSub: '건물에서 떨어지세요', car: '정차하고 차 안에 머무르세요.', carSub: '흔들림이 멈출 때까지', switchSituation: '상황 전환' },
    ar: { indoors: 'احمِ رأسك', outdoors: 'احمِ رأسك', outdoorsSub: 'ابتعد عن المباني', car: 'توقف وابقَ في السيارة.', carSub: 'حتى يتوقف الاهتزاز', switchSituation: 'تغيير الحالة' },
  });
  const headline = eqSituation === 'car' ? t.car : t[eqSituation];
  const subline = eqSituation === 'outdoors' ? t.outdoorsSub : eqSituation === 'car' ? t.carSub : undefined;
  const spoken = subline ? `${headline} ${subline}` : headline;
  useAnnounceOnEnter(spoken);
  const picto = eqSituation === 'indoors' ? <ProtectHead /> : eqSituation === 'outdoors' ? <OutdoorsProtect /> : <StayInCar />;

  return (
    <GuidanceLayout
      tone="red"
      band={<AlertBand />}
      badge={
        <Badge
          label={[c.badgeEarthquake, eqSituationLabel(eqSituation, lang)]}
          onClick={() => dispatch(actions.patch({ eqSituation: NEXT[eqSituation] }))}
          ariaLabel={`${c.badgeEarthquake} / ${eqSituationLabel(eqSituation, lang)} - ${t.switchSituation}`}
        />
      }
      pictogram={picto}
      headline={headline}
      subline={subline}
      listen={<ListenButton text={spoken} />}
      footer={<GuideFooter />}
    >
      <BigButton variant="white" icon="arrow-right" onClick={() => dispatch(actions.patch({ shaking: false }))}>
        {c.shakingStopped}
      </BigButton>
    </GuidanceLayout>
  );
}
