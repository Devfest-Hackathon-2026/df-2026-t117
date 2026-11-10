// Strings of the shelter info block on S06 (feature G). Kept apart from the shared i18n files so the
// feature can be removed as one unit. zh-Hans / ko / ar are demo translations (not native-checked).
// Terms follow the app's existing ones: 避难所 / 工作人员, 대피소 / 직원, مراكز الإيواء / الموظفين, 係員.
import '../i18n/i18n.dart';
import '../state/types.dart';

/// Japanese word for the shelter, shown beside the title in the other languages so it can be matched
/// with signs and with what people say on site.
const String shelterJapanese = '避難所';

const Dict shelterDict = {
  Lang.en: {
    'title': 'Evacuation shelters',
    'free': 'Shelters are free. Anyone can use them, including visitors from abroad.',
    'passport': 'If you have your passport, show it to the staff.',
    'tellStaff': 'Tell the staff you are a visitor and which language you speak.',
  },
  Lang.ja: {
    'title': '避難所について',
    'free': '避難所は無料です。外国からの旅行者も含め、だれでも利用できます。',
    'passport': 'パスポートを持っていれば、係員に見せてください。',
    'tellStaff': '係員に、旅行者であることと話せる言語を伝えてください。',
  },
  Lang.zhHans: {
    'title': '避难所',
    'free': '避难所免费，任何人都可以使用，包括外国游客。',
    'passport': '如果您带着护照，请出示给工作人员。',
    'tellStaff': '请告诉工作人员您是游客，以及您使用的语言。',
  },
  Lang.ko: {
    'title': '대피소',
    'free': '대피소는 무료입니다. 외국인 관광객을 포함해 누구나 이용할 수 있습니다.',
    'passport': '여권이 있으면 직원에게 보여 주세요.',
    'tellStaff': '직원에게 여행자라는 것과 사용하는 언어를 알려 주세요.',
  },
  Lang.ar: {
    'title': 'مراكز الإيواء',
    'free': 'مراكز الإيواء مجانية، ويمكن لأي شخص استخدامها، بما في ذلك الزوار من الخارج.',
    'passport': 'إذا كان معك جواز سفرك، فأظهره للموظفين.',
    'tellStaff': 'أخبر الموظفين أنك زائر وباللغة التي تتحدثها.',
  },
};
