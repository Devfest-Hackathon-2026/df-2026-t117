// Copied from src/logic/useAlertEffects.ts and useNavEffects.ts of the web mock by a script, so the translations match it exactly.
// zh-Hans / ko / ar are mock drafts, not native-checked (requirements 6.6).
import '../state/types.dart';

/// Re-notification body: upgrade / raise.
const Map<Lang, Map<String, String>> notifyBodyDict = {
  Lang.en: {
    'upgrade': 'Tsunami alert upgraded',
    'raise': 'Expected tsunami height raised',
  },
  Lang.ja: {
    'upgrade': '津波の警報が格上げされました',
    'raise': '予想される津波の高さが引き上げられました',
  },
  Lang.zhHans: {
    'upgrade': '海啸警报已升级',
    'raise': '预计海啸高度已上调',
  },
  Lang.ko: {
    'upgrade': '쓰나미 경보가 격상되었습니다',
    'raise': '예상 쓰나미 높이가 상향되었습니다',
  },
  Lang.ar: {
    'upgrade': 'تم رفع مستوى تنبيه التسونامي',
    'raise': 'تم رفع الارتفاع المتوقع للتسونامي',
  },
};

/// Spoken turn instruction: right / left / straight.
const Map<Lang, Map<String, String>> turnSpeechDict = {
  Lang.en: {
    'right': 'Turn right in {n} meters.',
    'left': 'Turn left in {n} meters.',
    'straight': 'Go straight for {n} meters.',
  },
  Lang.ja: {
    'right': '{n}メートル先、右です。',
    'left': '{n}メートル先、左です。',
    'straight': 'このまま{n}メートル直進です。',
  },
  Lang.zhHans: {
    'right': '前方{n}米右转。',
    'left': '前方{n}米左转。',
    'straight': '直行{n}米。',
  },
  Lang.ko: {
    'right': '{n}미터 앞에서 오른쪽입니다.',
    'left': '{n}미터 앞에서 왼쪽입니다.',
    'straight': '{n}미터 직진하세요.',
  },
  Lang.ar: {
    'right': 'انعطف يمينًا بعد {n} متر.',
    'left': 'انعطف يسارًا بعد {n} متر.',
    'straight': 'تابع إلى الأمام لمسافة {n} متر.',
  },
};
