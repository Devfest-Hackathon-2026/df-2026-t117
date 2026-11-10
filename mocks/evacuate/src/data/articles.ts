// Short preparedness articles (A04). Fictional-mock content, general guidance only. Drafts for zh-Hans / ko / ar are not native-checked.
import type { L10n } from '../state/types';

export interface Article {
  id: string;
  title: L10n;
  summary: L10n;
  body: L10n[];
}

export const ARTICLES: Article[] = [
  {
    id: 'alert-levels',
    title: {
      en: 'Japan’s alert levels',
      ja: '日本の警戒レベル',
      'zh-Hans': '日本的警报级别',
      ko: '일본의 경보 단계',
      ar: 'مستويات التنبيه في اليابان',
    },
    summary: {
      en: 'Advisory, warning and emergency warning explained.',
      ja: '注意報・警報・特別警報のちがい。',
      'zh-Hans': '注意报、警报与特别警报的区别。',
      ko: '주의보, 경보, 특별경보의 차이.',
      ar: 'الفرق بين الإشعار والتحذير والتحذير الطارئ.',
    },
    body: [
      {
        en: 'Advisory (chuuihou): be careful and prepare. Know where high ground is.',
        ja: '注意報：注意が必要です。避難の準備をし、高台の場所を確認します。',
        'zh-Hans': '注意报：需要留意并做好准备，确认高处在哪里。',
        ko: '주의보: 주의하고 준비하세요. 고지대의 위치를 확인하세요.',
        ar: 'إشعار: كن حذرًا واستعد، وتعرّف على مكان المرتفعات.',
      },
      {
        en: 'Warning (keihou): danger is expected. Evacuate to high ground now.',
        ja: '警報：重大な危険が予想されます。今すぐ高台へ避難します。',
        'zh-Hans': '警报：预计有重大危险，请立即前往高处避难。',
        ko: '경보: 큰 위험이 예상됩니다. 지금 바로 고지대로 대피하세요.',
        ar: 'تحذير: يُتوقع خطر كبير. توجّه إلى مكان مرتفع الآن.',
      },
      {
        en: 'Emergency warning (tokubetsu keihou, e.g. major tsunami warning): extraordinary danger. Act immediately to save your life.',
        ja: '特別警報（大津波警報など）：命にかかわる異常な危険。直ちに命を守る行動を。',
        'zh-Hans': '特别警报（如大海啸警报）：生命面临异常危险，请立即采取行动保命。',
        ko: '특별경보(대형 쓰나미 경보 등): 생명이 위험한 비상 상황입니다. 즉시 행동하세요.',
        ar: 'تحذير طارئ (مثل تحذير التسونامي الكبير): خطر استثنائي. تصرّف فورًا لإنقاذ حياتك.',
      },
    ],
  },
  {
    id: 'shelters-signs',
    title: {
      en: 'Shelters and evacuation signs',
      ja: '避難所と避難標識',
      'zh-Hans': '避难所与避难标志',
      ko: '대피소와 대피 표지',
      ar: 'مراكز الإيواء ولافتات الإخلاء',
    },
    summary: {
      en: 'How to read the blue tsunami evacuation sign.',
      ja: '津波避難場所の青い標識の見かた。',
      'zh-Hans': '如何看懂蓝色的海啸避难标志。',
      ko: '파란 쓰나미 대피 표지 읽는 법.',
      ar: 'كيف تقرأ لافتة إخلاء التسونامي الزرقاء.',
    },
    body: [
      {
        en: 'Blue signs with a running figure and a wave point to tsunami evacuation sites or buildings. Follow the arrow.',
        ja: '走る人と波が描かれた青い標識は、津波避難場所・津波避難ビルを示します。矢印の方向へ進みます。',
        'zh-Hans': '带有奔跑人形和海浪的蓝色标志指向海啸避难场所或避难楼，请沿箭头方向前进。',
        ko: '달리는 사람과 파도가 그려진 파란 표지는 쓰나미 대피 장소나 건물을 가리킵니다. 화살표를 따라가세요.',
        ar: 'اللافتات الزرقاء التي تحمل شكلًا يركض وموجة تشير إلى أماكن أو مبانٍ للإخلاء. اتبع السهم.',
      },
      {
        en: 'Shelters are different from tsunami evacuation sites. Check the sign to see which hazards a place is safe for.',
        ja: '避難所と津波避難場所は別のものです。標識で、どの災害に対応する場所か確認します。',
        'zh-Hans': '避难所与海啸避难场所不同，请查看标志确认适用于哪种灾害。',
        ko: '대피소와 쓰나미 대피 장소는 다릅니다. 표지에서 어떤 재난에 대응하는지 확인하세요.',
        ar: 'مراكز الإيواء تختلف عن أماكن إخلاء التسونامي. تحقق من اللافتة لمعرفة نوع الخطر.',
      },
    ],
  },
  {
    id: 'emergency-numbers',
    title: {
      en: 'Emergency numbers and your location',
      ja: '緊急番号と場所の伝え方',
      'zh-Hans': '紧急电话与说明位置',
      ko: '긴급 번호와 위치 설명',
      ar: 'أرقام الطوارئ وكيفية شرح موقعك',
    },
    summary: {
      en: '119 for ambulance and fire, 110 for police.',
      ja: '救急・消防は119、警察は110。',
      'zh-Hans': '急救和消防拨119，警察拨110。',
      ko: '구급·소방은 119, 경찰은 110.',
      ar: '119 للإسعاف والإطفاء و110 للشرطة.',
    },
    body: [
      {
        en: 'Dial 119 for an ambulance or fire, and 110 for police. Calls are free.',
        ja: '救急・消防は119、警察は110。通話は無料です。',
        'zh-Hans': '急救和消防拨119，警察拨110，通话免费。',
        ko: '구급·소방은 119, 경찰은 110입니다. 통화는 무료입니다.',
        ar: 'اتصل بـ 119 للإسعاف أو الإطفاء وبـ 110 للشرطة. المكالمة مجانية.',
      },
      {
        en: 'Say your location slowly: the nearest landmark, building or intersection. Use the Emergency screen to show your place in Japanese.',
        ja: '近くの目印・建物・交差点をゆっくり伝えます。緊急画面で日本語の場所表示を見せることもできます。',
        'zh-Hans': '慢慢说出附近的地标、建筑或路口。可在紧急画面向对方出示日语位置。',
        ko: '근처의 랜드마크, 건물, 교차로를 천천히 말하세요. 긴급 화면에서 일본어 위치를 보여줄 수 있습니다.',
        ar: 'اذكر موقعك ببطء: أقرب معلم أو مبنى أو تقاطع. استخدم شاشة الطوارئ لعرض موقعك بالياباني.',
      },
    ],
  },
];
