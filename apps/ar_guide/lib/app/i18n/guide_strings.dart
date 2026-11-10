// Copied from src/screens/_alertShared.tsx of the web mock by a script, so the translations match it exactly.
// zh-Hans / ko / ar are mock drafts, not native-checked (requirements 6.6).
import '../state/types.dart';

/// goHigher / followSigns / setLocation.
const Map<Lang, Map<String, String>> guideDict = {
  Lang.en: {
    'goHigher': 'Go higher.',
    'followSigns': 'Follow the blue evacuation signs',
    'setLocation': 'Set location',
  },
  Lang.ja: {
    'goHigher': 'もっと高い所へ。',
    'followSigns': '青い津波避難の標識に従う',
    'setLocation': '現在地を設定',
  },
  Lang.zhHans: {
    'goHigher': '去更高处。',
    'followSigns': '跟随蓝色海啸避难标志',
    'setLocation': '设置位置',
  },
  Lang.ko: {
    'goHigher': '더 높은 곳으로.',
    'followSigns': '파란색 쓰나미 대피 표지판을 따라가세요',
    'setLocation': '위치 설정',
  },
  Lang.ar: {
    'goHigher': 'اصعد إلى مكان أعلى.',
    'followSigns': 'اتبع لافتات الإخلاء الزرقاء',
    'setLocation': 'حدد الموقع',
  },
};

/// Qualitative tsunami heights.
const Map<Lang, Map<String, String>> heightDict = {
  Lang.en: {
    'over10': 'over 10 m',
    'huge': 'huge',
    'high': 'high',
  },
  Lang.ja: {
    'over10': '10 m 超',
    'huge': '巨大',
    'high': '高い',
  },
  Lang.zhHans: {
    'over10': '超过 10 米',
    'huge': '巨大',
    'high': '高',
  },
  Lang.ko: {
    'over10': '10m 초과',
    'huge': '거대',
    'high': '높음',
  },
  Lang.ar: {
    'over10': 'أكثر من 10 م',
    'huge': 'هائل',
    'high': 'مرتفع',
  },
};

/// The alert-change band (F88 / F89 / F8A).
const Map<Lang, Map<String, String>> bandDict = {
  Lang.en: {
    'upgrade': 'UPGRADED',
    'raise': 'HEIGHT RAISED',
    'downgrade': 'DOWNGRADED',
    'expected': 'Expected {h}',
    'keepGoing': 'Keep going to high ground',
    'stayAll': 'Stay until all alerts are lifted',
  },
  Lang.ja: {
    'upgrade': '格上げ',
    'raise': '高さ引き上げ',
    'downgrade': '格下げ',
    'expected': '予想 {h}',
    'keepGoing': 'このまま高台へ',
    'stayAll': 'すべて解除されるまで待機',
  },
  Lang.zhHans: {
    'upgrade': '已升级',
    'raise': '预计高度上调',
    'downgrade': '已降级',
    'expected': '预计 {h}',
    'keepGoing': '继续前往高处',
    'stayAll': '在全部警报解除前请留在此处',
  },
  Lang.ko: {
    'upgrade': '격상',
    'raise': '예상 높이 상향',
    'downgrade': '격하',
    'expected': '예상 {h}',
    'keepGoing': '계속 높은 곳으로 가세요',
    'stayAll': '모든 경보가 해제될 때까지 머무르세요',
  },
  Lang.ar: {
    'upgrade': 'رُفع المستوى',
    'raise': 'رُفع الارتفاع المتوقع',
    'downgrade': 'خُفض المستوى',
    'expected': 'المتوقع {h}',
    'keepGoing': 'واصل التوجه إلى مكان مرتفع',
    'stayAll': 'ابقَ حتى تُرفع جميع التنبيهات',
  },
};

/// The margin card on S06 (F83-F87).
const Map<Lang, Map<String, String>> cardDict = {
  Lang.en: {
    'title': 'Why here',
    'approx': 'Location approximate',
    'elevation': 'Elevation {v}',
    'elevUnknown': 'Elevation unknown',
    'expected': 'Expected tsunami {h}',
    'highest': '(highest announced)',
    'above': '{n} m above forecast',
    'below': '{n} m below forecast',
    'stayUntil': 'Stay until the warning is lifted',
    'staff': 'Follow staff instructions',
  },
  Lang.ja: {
    'title': 'ここで待つ理由',
    'approx': '現在地はおおまか',
    'elevation': '標高 {v}',
    'elevUnknown': '標高は不明',
    'expected': '予想される津波 {h}',
    'highest': '（これまでの最大）',
    'above': '予想より {n} m 高い',
    'below': '予想より {n} m 低い',
    'stayUntil': '警報が解除されるまで待機',
    'staff': '係員の指示に従う',
  },
  Lang.zhHans: {
    'title': '为什么在这里',
    'approx': '位置为大致位置',
    'elevation': '海拔 {v}',
    'elevUnknown': '海拔未知',
    'expected': '预计海啸 {h}',
    'highest': '（已发布的最高值）',
    'above': '比预计高 {n} 米',
    'below': '比预计低 {n} 米',
    'stayUntil': '请等到警报解除',
    'staff': '请听从工作人员的指示',
  },
  Lang.ko: {
    'title': '여기서 기다리는 이유',
    'approx': '위치가 대략적입니다',
    'elevation': '해발 {v}',
    'elevUnknown': '해발 알 수 없음',
    'expected': '예상 쓰나미 {h}',
    'highest': '(지금까지 최고)',
    'above': '예상보다 {n}m 높음',
    'below': '예상보다 {n}m 낮음',
    'stayUntil': '경보가 해제될 때까지 머무르세요',
    'staff': '직원의 안내에 따르세요',
  },
  Lang.ar: {
    'title': 'لماذا هنا',
    'approx': 'الموقع تقريبي',
    'elevation': 'الارتفاع {v}',
    'elevUnknown': 'الارتفاع غير معروف',
    'expected': 'التسونامي المتوقع {h}',
    'highest': '(الأعلى المُعلن)',
    'above': 'أعلى من المتوقع بـ {n} م',
    'below': 'أدنى من المتوقع بـ {n} م',
    'stayUntil': 'ابقَ حتى يُرفع التحذير',
    'staff': 'اتبع تعليمات الموظفين',
  },
};
