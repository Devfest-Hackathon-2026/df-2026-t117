// A03 Disaster-type guide (light): Earthquake (3 situations) / Tsunami.
// Pictograms come from T2 (src/components/pictograms).
import { useState, type ReactNode } from 'react';
import { SubLayout } from '../components/SubLayout';
import { FooterMeta } from '../components/FooterMeta';
import { useCommon, useT } from '../i18n';
import { ProtectHead, GoUphill, StayHere, GetOutOfCar, StayInCar, OutdoorsProtect } from '../components/pictograms';
import './t3.css';

const dict = {
  en: { quake: 'Earthquake', tsunami: 'Tsunami', in: 'Indoors', inD: 'Drop, cover and hold on under a sturdy table. Stay away from windows.', out: 'Outdoors', outD: 'Move away from buildings, walls and glass. Protect your head.', car: 'In car', carD: 'Slow down and pull over to the left. Turn off the engine and stay inside until the shaking stops.', carAfter: 'After the shaking', carAfterD: 'Leave the key in the car, take your valuables and go on foot. Do not drive.',
    t1: 'Go uphill now', t1d: 'Move to high ground or a tall building right away.', t2: 'Do not wait to see the wave', t2d: 'Do not go to look at the sea. Waves can arrive within minutes.', t3: 'Stay until the official all-clear', t3d: 'Tsunami can come many times. Wait for the official announcement.', note: 'Short guide for the demo' },
  ja: { quake: '地震', tsunami: '津波', in: '屋内', inD: '丈夫な机の下で頭を守り、揺れがおさまるまで動かない。窓から離れる。', out: '屋外', outD: '建物・塀・ガラスから離れ、頭を守る。', car: '車内', carD: 'ゆっくり減速して道路の左側に止め、エンジンを切る。揺れがおさまるまで車の中で待つ。', carAfter: '揺れがおさまったら', carAfterD: 'キーは付けたまま、貴重品を持って歩いて避難する。車では逃げない。',
    t1: 'すぐ高台へ', t1d: '高い場所や高い建物にすぐ移動する。', t2: '波を見に行かない', t2d: '海を見に行かない。数分で到達することがあります。', t3: '解除まで戻らない', t3d: '津波は何度も来ます。公式の解除発表を待つ。', note: 'デモ用の短い案内' },
  'zh-Hans': { quake: '地震', tsunami: '海啸', in: '室内', inD: '躲在坚固的桌下，保护头部，远离窗户。', out: '室外', outD: '远离建筑物、围墙和玻璃，保护头部。', car: '车内', carD: '慢慢减速，靠道路左侧停车并熄火。在车内等到摇晃停止。', carAfter: '摇晃停止后', carAfterD: '把钥匙留在车上，带上贵重物品步行避难。不要开车逃离。',
    t1: '立即前往高处', t1d: '马上前往高地或高楼。', t2: '不要等着看海浪', t2d: '不要去看海，海浪几分钟内就可能到达。', t3: '等到官方解除', t3d: '海啸可能多次袭来，请等待官方通知。', note: '演示用简要指南' },
  ko: { quake: '지진', tsunami: '쓰나미', in: '실내', inD: '튼튼한 탁자 아래에서 머리를 보호하고 창문에서 떨어지세요.', out: '실외', outD: '건물, 담, 유리에서 떨어지고 머리를 보호하세요.', car: '차 안', carD: '천천히 속도를 줄여 도로 왼쪽에 세우고 시동을 끄세요. 흔들림이 멈출 때까지 차 안에서 기다리세요.', carAfter: '흔들림이 멈추면', carAfterD: '열쇠는 꽂아 둔 채 귀중품을 챙겨 걸어서 대피하세요. 차로 대피하지 마세요.',
    t1: '바로 고지대로', t1d: '높은 곳이나 높은 건물로 즉시 이동하세요.', t2: '파도를 보러 가지 마세요', t2d: '바다를 보러 가지 마세요. 몇 분 안에 도달할 수 있습니다.', t3: '해제될 때까지 머무르기', t3d: '쓰나미는 여러 번 올 수 있습니다. 공식 발표를 기다리세요.', note: '데모용 짧은 안내' },
  ar: { quake: 'زلزال', tsunami: 'تسونامي', in: 'في الداخل', inD: 'احتمِ تحت طاولة متينة واحمِ رأسك وابتعد عن النوافذ.', out: 'في الخارج', outD: 'ابتعد عن المباني والجدران والزجاج واحمِ رأسك.', car: 'في السيارة', carD: 'خفف السرعة وتوقف على يسار الطريق وأطفئ المحرك. ابقَ داخل السيارة حتى يتوقف الاهتزاز.', carAfter: 'بعد توقف الاهتزاز', carAfterD: 'اترك المفتاح في السيارة وخذ أغراضك الثمينة وتوجه سيرًا على الأقدام. لا تقد السيارة.',
    t1: 'اصعد إلى مكان مرتفع الآن', t1d: 'توجه فورًا إلى مكان مرتفع أو مبنى عالٍ.', t2: 'لا تنتظر رؤية الموجة', t2d: 'لا تذهب لمشاهدة البحر؛ قد تصل الموجات خلال دقائق.', t3: 'ابقَ حتى الإعلان الرسمي', t3d: 'قد تأتي موجات متعددة. انتظر الإعلان الرسمي.', note: 'دليل مختصر للعرض' },
};

function Item({ picto, title, body }: { picto: ReactNode; title: string; body: string }) {
  return (
    <div className="t3-card t3-card--plain t3-item">
      <span className="t3-picto" aria-hidden="true">{picto}</span>
      <div className="t3-item__body">
        <div className="t3-h">{title}</div>
        <div className="t3-p">{body}</div>
      </div>
    </div>
  );
}

let initialTab: 'eq' | 'ts' = 'eq';
/** Set the tab A03 opens on next mount (consumed once; no store change). */
export function setA03InitialTab(tab: 'eq' | 'ts' | 'tsunami' | 'earthquake') {
  initialTab = tab === 'ts' || tab === 'tsunami' ? 'ts' : 'eq';
}

export default function A03() {
  const t = useT(dict);
  const c = useCommon();
  const [tab, setTab] = useState<'eq' | 'ts'>(() => {
    const v = initialTab;
    initialTab = 'eq';
    return v;
  });
  return (
    <SubLayout theme="light" headerTitle={c.titleGuides} title={c.titleGuides} footer={<FooterMeta theme="light" items={[t.note]} />}>
      <div className="t3-seg" role="group">
        <button type="button" aria-pressed={tab === 'eq'} onClick={() => setTab('eq')}>{t.quake}</button>
        <button type="button" aria-pressed={tab === 'ts'} onClick={() => setTab('ts')}>{t.tsunami}</button>
      </div>
      {tab === 'eq' ? (
        <>
          <Item picto={<ProtectHead />} title={t.in} body={t.inD} />
          <Item picto={<OutdoorsProtect />} title={t.out} body={t.outD} />
          <Item picto={<StayInCar />} title={t.car} body={t.carD} />
          <Item picto={<GetOutOfCar />} title={t.carAfter} body={t.carAfterD} />
        </>
      ) : (
        <>
          <Item picto={<GoUphill />} title={t.t1} body={t.t1d} />
          <Item picto={<GoUphill />} title={t.t2} body={t.t2d} />
          <Item picto={<StayHere />} title={t.t3} body={t.t3d} />
        </>
      )}
    </SubLayout>
  );
}
