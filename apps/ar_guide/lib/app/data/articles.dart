// Copied from src/data/articles.ts of the web mock by a script, so the translations match it exactly.
// zh-Hans / ko / ar are mock drafts, not native-checked (requirements 6.6).
// The two [isNew] safety tips at the top are app-only (not in the web mock). Facts follow the Japan
// Meteorological Agency's public tsunami guidance, in our own words.
import '../state/types.dart';

class Article {
  const Article({required this.id, required this.title, required this.summary, required this.body, this.isNew = false});
  final String id;

  /// Highlighted on H00 and marked "new" in the A04 list.
  final bool isNew;
  final L10n title;
  final L10n summary;
  final List<L10n> body;
}

const List<Article> articles = [
  Article(
    id: 'advisory-30cm',
    isNew: true,
    title: L10n(en: 'Even a tsunami advisory can sweep you away', ja: '津波注意報でも人は流されます', zhHans: '即使是海啸注意报，人也会被冲走', ko: '쓰나미 주의보라도 사람이 휩쓸립니다', ar: 'حتى إشعار التسونامي قد يجرفك'),
    summary: L10n(en: 'About 30 cm of moving water can knock an adult off their feet.', ja: '30cmほどの津波でも、大人は立っていられません。', zhHans: '约30厘米的海啸就能让成年人站不稳。', ko: '30cm 정도의 쓰나미에도 어른이 서 있을 수 없습니다.', ar: 'نحو 30 سم من الماء المندفع قد يُسقط شخصًا بالغًا.'),
    body: [
      L10n(en: 'A tsunami is not an ordinary wave: the whole sea pushes in with great force. Even water about 30 cm deep can knock an adult off their feet and carry them away.', ja: '津波はふつうの波とちがい、海全体が強い力で押し寄せます。深さ30cmほどの水でも、大人が立っていられずに流されることがあります。', zhHans: '海啸不同于普通的海浪，整片海水会以强大的力量涌来。即使水深只有约30厘米，成年人也可能站不稳并被冲走。', ko: '쓰나미는 보통 파도와 달리 바다 전체가 강한 힘으로 밀려옵니다. 깊이 30cm 정도의 물에도 어른이 서 있지 못하고 휩쓸릴 수 있습니다.', ar: 'التسونامي ليس موجة عادية؛ فالبحر كله يندفع بقوة كبيرة. حتى الماء بعمق 30 سم تقريبًا قد يُسقط شخصًا بالغًا ويجرفه.'),
      L10n(en: 'A tsunami advisory (chuuihou) is issued when waves of up to about 1 m are expected. That is still dangerous in the sea and on the shore.', ja: '津波注意報は、高さ1mまでの津波が予想されるときに出ます。海の中や海岸では、それでも十分に危険です。', zhHans: '预计海啸高度在1米左右以下时会发布海啸注意报。在海中和海岸边，这仍然很危险。', ko: '쓰나미 주의보는 높이 1m까지의 쓰나미가 예상될 때 발표됩니다. 바다 안이나 해안에서는 그래도 충분히 위험합니다.', ar: 'يصدر إشعار التسونامي عندما يُتوقع موج يصل ارتفاعه إلى نحو متر واحد. وهذا خطير في البحر وعلى الشاطئ.'),
      L10n(en: 'Under an advisory, get out of the water right away and move away from beaches, ports and river mouths. Do not go to look at the sea.', ja: '注意報が出たら、すぐに海から上がり、海岸・港・河口から離れます。海を見に行かないでください。', zhHans: '发布注意报后，请立即离开水中，远离海滩、港口和河口。不要去看海。', ko: '주의보가 나오면 바로 물에서 나와 해변, 항구, 하구에서 떨어지세요. 바다를 보러 가지 마세요.', ar: 'عند صدور الإشعار، اخرج من الماء فورًا وابتعد عن الشواطئ والموانئ ومصبات الأنهار. لا تذهب لمشاهدة البحر.'),
      L10n(en: 'Stay away from the coast until the advisory is lifted. Waves can come again and again. If this app or local officials tell you to go to high ground, follow them.', ja: '注意報が解除されるまで海岸に近づきません。津波は何度もくり返し来ます。このアプリや自治体が高台への避難を呼びかけたら、それに従ってください。', zhHans: '在注意报解除前不要靠近海岸，海啸可能多次袭来。如果本应用或当地政府要求前往高处，请照做。', ko: '주의보가 해제될 때까지 해안에 가까이 가지 마세요. 쓰나미는 여러 번 반복해서 옵니다. 이 앱이나 지자체가 고지대로 대피하라고 하면 따르세요.', ar: 'لا تقترب من الساحل حتى يُرفع الإشعار، فقد تتكرر الموجات. وإذا طلب منك هذا التطبيق أو السلطات المحلية التوجه إلى مكان مرتفع فاتبع ذلك.'),
    ],
  ),
  Article(
    id: 'leave-car',
    isNew: true,
    title: L10n(en: 'Leave the car and evacuate on foot', ja: '車を降りて、歩いて避難', zhHans: '下车步行避难', ko: '차에서 내려 걸어서 대피', ar: 'اترك السيارة وأخلِ المكان سيرًا'),
    summary: L10n(en: 'Cars get stuck in traffic and can be carried away by a tsunami.', ja: '車は渋滞で動けなくなり、津波に流されることがあります。', zhHans: '汽车会堵在路上，还可能被海啸冲走。', ko: '차는 정체로 움직이지 못하고 쓰나미에 떠내려갈 수 있습니다.', ar: 'تعلق السيارات في الزحام وقد يجرفها التسونامي.'),
    body: [
      L10n(en: 'Escaping a tsunami by car is dangerous. Roads jam quickly, and even shallow water can carry a car away.', ja: '車で津波から逃げるのは危険です。道路はすぐに渋滞し、浅い水でも車は流されることがあります。', zhHans: '开车躲避海啸很危险。道路很快就会堵塞，即使是浅水也可能把汽车冲走。', ko: '차로 쓰나미를 피하는 것은 위험합니다. 도로는 금방 막히고, 얕은 물에도 차가 떠내려갈 수 있습니다.', ar: 'الهروب من التسونامي بالسيارة خطير. تزدحم الطرق بسرعة، وقد يجرف الماء الضحل السيارة.'),
      L10n(en: 'In a tsunami evacuation, go on foot as a rule. Some areas allow cars in limited cases, such as for people who need help. Follow local rules.', ja: '津波からの避難は、原則として徒歩です。手助けが必要な人など、地域によって車の利用が認められる場合があります。地域のルールに従ってください。', zhHans: '海啸避难原则上步行。部分地区在有限情况下允许用车，例如需要帮助的人。请遵守当地规定。', ko: '쓰나미 대피는 원칙적으로 걸어서 합니다. 도움이 필요한 사람 등 지역에 따라 차 이용이 허용되는 경우가 있습니다. 지역 규칙을 따르세요.', ar: 'الإخلاء من التسونامي يكون سيرًا على الأقدام كقاعدة. تسمح بعض المناطق بالسيارة في حالات محدودة، مثل من يحتاجون إلى مساعدة. اتبع القواعد المحلية.'),
      L10n(en: 'If the ground shakes while you drive, slow down, pull over to the left and wait in the car until the shaking stops, as the app shows.', ja: '運転中に揺れたら、アプリの案内どおり、ゆっくり道路の左側に止め、揺れがおさまるまで車内で待ちます。', zhHans: '开车时遇到摇晃，请按应用的指引慢慢减速，靠道路左侧停车，在车内等到摇晃停止。', ko: '운전 중에 흔들리면 앱 안내대로 천천히 도로 왼쪽에 세우고, 흔들림이 멈출 때까지 차 안에서 기다리세요.', ar: 'إذا اهتزت الأرض أثناء القيادة، فخفف السرعة وتوقف على يسار الطريق وانتظر داخل السيارة حتى يتوقف الاهتزاز، كما يوضح التطبيق.'),
      L10n(en: 'Then leave the car: park on the left, turn off the engine, leave the key in and the doors unlocked, take your valuables and walk to high ground.', ja: 'そのあと車を降ります。道路の左側に止めてエンジンを切り、キーは付けたまま、ドアはロックせず、貴重品を持って歩いて高台へ向かいます。', zhHans: '然后下车：靠左停好并熄火，把钥匙留在车上、不要锁门，带上贵重物品步行前往高处。', ko: '그런 다음 차에서 내리세요. 도로 왼쪽에 세우고 시동을 끄고, 열쇠는 꽂아 두고 문은 잠그지 말고, 귀중품을 챙겨 걸어서 고지대로 가세요.', ar: 'ثم اترك السيارة: توقف على اليسار وأطفئ المحرك، واترك المفتاح فيها والأبواب غير مقفلة، وخذ أغراضك الثمينة وامشِ إلى مكان مرتفع.'),
      L10n(en: 'Leaving the key lets others move the car so that rescue vehicles can get through.', ja: 'キーを残すのは、救助の車が通れるように、ほかの人が車を動かせるようにするためです。', zhHans: '留下钥匙是为了让他人能移动车辆，方便救援车辆通行。', ko: '열쇠를 남기는 것은 구조 차량이 지나갈 수 있도록 다른 사람이 차를 옮길 수 있게 하기 위해서입니다.', ar: 'ترك المفتاح يتيح للآخرين تحريك السيارة كي تمر مركبات الإنقاذ.'),
    ],
  ),
  Article(
    id: 'alert-levels',
    title: L10n(en: 'Japan’s alert levels', ja: '日本の警戒レベル', zhHans: '日本的警报级别', ko: '일본의 경보 단계', ar: 'مستويات التنبيه في اليابان'),
    summary: L10n(en: 'Advisory, warning and emergency warning explained.', ja: '注意報・警報・特別警報のちがい。', zhHans: '注意报、警报与特别警报的区别。', ko: '주의보, 경보, 특별경보의 차이.', ar: 'الفرق بين الإشعار والتحذير والتحذير الطارئ.'),
    body: [
      L10n(en: 'Advisory (chuuihou): be careful and prepare. Know where high ground is.', ja: '注意報：注意が必要です。避難の準備をし、高台の場所を確認します。', zhHans: '注意报：需要留意并做好准备，确认高处在哪里。', ko: '주의보: 주의하고 준비하세요. 고지대의 위치를 확인하세요.', ar: 'إشعار: كن حذرًا واستعد، وتعرّف على مكان المرتفعات.'),
      L10n(en: 'Warning (keihou): danger is expected. Evacuate to high ground now.', ja: '警報：重大な危険が予想されます。今すぐ高台へ避難します。', zhHans: '警报：预计有重大危险，请立即前往高处避难。', ko: '경보: 큰 위험이 예상됩니다. 지금 바로 고지대로 대피하세요.', ar: 'تحذير: يُتوقع خطر كبير. توجّه إلى مكان مرتفع الآن.'),
      L10n(en: 'Emergency warning (tokubetsu keihou, e.g. major tsunami warning): extraordinary danger. Act immediately to save your life.', ja: '特別警報（大津波警報など）：命にかかわる異常な危険。直ちに命を守る行動を。', zhHans: '特别警报（如大海啸警报）：生命面临异常危险，请立即采取行动保命。', ko: '특별경보(대형 쓰나미 경보 등): 생명이 위험한 비상 상황입니다. 즉시 행동하세요.', ar: 'تحذير طارئ (مثل تحذير التسونامي الكبير): خطر استثنائي. تصرّف فورًا لإنقاذ حياتك.'),
    ],
  ),
  Article(
    id: 'shelters-signs',
    title: L10n(en: 'Shelters and evacuation signs', ja: '避難所と避難標識', zhHans: '避难所与避难标志', ko: '대피소와 대피 표지', ar: 'مراكز الإيواء ولافتات الإخلاء'),
    summary: L10n(en: 'How to read the blue tsunami evacuation sign.', ja: '津波避難場所の青い標識の見かた。', zhHans: '如何看懂蓝色的海啸避难标志。', ko: '파란 쓰나미 대피 표지 읽는 법.', ar: 'كيف تقرأ لافتة إخلاء التسونامي الزرقاء.'),
    body: [
      L10n(en: 'Blue signs with a running figure and a wave point to tsunami evacuation sites or buildings. Follow the arrow.', ja: '走る人と波が描かれた青い標識は、津波避難場所・津波避難ビルを示します。矢印の方向へ進みます。', zhHans: '带有奔跑人形和海浪的蓝色标志指向海啸避难场所或避难楼，请沿箭头方向前进。', ko: '달리는 사람과 파도가 그려진 파란 표지는 쓰나미 대피 장소나 건물을 가리킵니다. 화살표를 따라가세요.', ar: 'اللافتات الزرقاء التي تحمل شكلًا يركض وموجة تشير إلى أماكن أو مبانٍ للإخلاء. اتبع السهم.'),
      L10n(en: 'Shelters are different from tsunami evacuation sites. Check the sign to see which hazards a place is safe for.', ja: '避難所と津波避難場所は別のものです。標識で、どの災害に対応する場所か確認します。', zhHans: '避难所与海啸避难场所不同，请查看标志确认适用于哪种灾害。', ko: '대피소와 쓰나미 대피 장소는 다릅니다. 표지에서 어떤 재난에 대응하는지 확인하세요.', ar: 'مراكز الإيواء تختلف عن أماكن إخلاء التسونامي. تحقق من اللافتة لمعرفة نوع الخطر.'),
    ],
  ),
  Article(
    id: 'emergency-numbers',
    title: L10n(en: 'Emergency numbers and your location', ja: '緊急番号と場所の伝え方', zhHans: '紧急电话与说明位置', ko: '긴급 번호와 위치 설명', ar: 'أرقام الطوارئ وكيفية شرح موقعك'),
    summary: L10n(en: '119 for ambulance and fire, 110 for police.', ja: '救急・消防は119、警察は110。', zhHans: '急救和消防拨119，警察拨110。', ko: '구급·소방은 119, 경찰은 110.', ar: '119 للإسعاف والإطفاء و110 للشرطة.'),
    body: [
      L10n(en: 'Dial 119 for an ambulance or fire, and 110 for police. Calls are free.', ja: '救急・消防は119、警察は110。通話は無料です。', zhHans: '急救和消防拨119，警察拨110，通话免费。', ko: '구급·소방은 119, 경찰은 110입니다. 통화는 무료입니다.', ar: 'اتصل بـ 119 للإسعاف أو الإطفاء وبـ 110 للشرطة. المكالمة مجانية.'),
      L10n(en: 'Say your location slowly: the nearest landmark, building or intersection. Use the Emergency screen to show your place in Japanese.', ja: '近くの目印・建物・交差点をゆっくり伝えます。緊急画面で日本語の場所表示を見せることもできます。', zhHans: '慢慢说出附近的地标、建筑或路口。可在紧急画面向对方出示日语位置。', ko: '근처의 랜드마크, 건물, 교차로를 천천히 말하세요. 긴급 화면에서 일본어 위치를 보여줄 수 있습니다.', ar: 'اذكر موقعك ببطء: أقرب معلم أو مبنى أو تقاطع. استخدم شاشة الطوارئ لعرض موقعك بالياباني.'),
    ],
  ),
];
