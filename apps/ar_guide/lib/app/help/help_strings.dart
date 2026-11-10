// Feature F "Ask for help in Japanese": strings of the help card (lib/app/help/help_card.dart).
// Self-contained on purpose: nothing in the shared i18n files refers to it, so the feature can be removed by
// reverting one merge. English is the source; ja is the app's own language; zh-Hans / ko / ar were drafted
// with Gemini (gemini-3.5-flash on Vertex AI) and edited to match the app's terms (high ground = 高地 /
// 고지대 / مكان مرتفع). Like the rest of the app they are demo translations, not checked by native speakers.
import '../i18n/i18n.dart';
import '../state/types.dart';

/// The Japanese shown in large type and played aloud, one sentence per line. tools/voice/help-ja.mjs reads
/// this list (keep it a plain list of single-quoted strings) and makes the clip from it, with the readings
/// of lib/app/platform/readings.dart (高台 -> たかだい).
const List<String> helpJaLines = ['すみません、助けてください。', '津波から逃げています。高台はどこですか？'];

/// The whole Japanese text as it is played (the clip's manifest entry has the same text).
final String helpJaText = helpJaLines.join();

const Dict helpDict = {
  Lang.en: {
    'entry': 'Help in Japanese',
    'title': 'Show this to people nearby, or play it aloud',
    'meaningLabel': 'What this says',
    'meaning1': 'Excuse me, please help me.',
    'meaning2': 'I am escaping from the tsunami. Where is the high ground?',
    'play': 'Play in Japanese',
    'playAria': 'Play the Japanese words aloud',
    'stop': 'Stop',
    'stopAria': 'Stop playing',
  },
  Lang.ja: {
    'entry': '日本語で助けを求める',
    'title': '近くの人に見せるか、音声を流してください',
    'meaningLabel': '意味',
    'meaning1': 'すみません、助けてください。',
    'meaning2': '津波から逃げています。高台はどこですか？',
    'play': '日本語で再生',
    'playAria': '日本語の音声を再生する',
    'stop': '停止',
    'stopAria': '再生を止める',
  },
  Lang.zhHans: {
    'entry': '用日语求助',
    'title': '请出示给附近的人看，或播放语音',
    'meaningLabel': '意思',
    'meaning1': '打扰一下，请帮帮我。',
    'meaning2': '我正在躲避海啸。请问高地在哪里？',
    'play': '播放日语',
    'playAria': '播放日语语音',
    'stop': '停止',
    'stopAria': '停止播放',
  },
  Lang.ko: {
    'entry': '일본어로 도움 요청',
    'title': '주변 사람에게 보여 주거나 음성을 재생하세요',
    'meaningLabel': '뜻',
    'meaning1': '실례합니다, 도와주세요.',
    'meaning2': '쓰나미를 피해 대피 중입니다. 고지대가 어디인가요?',
    'play': '일본어로 재생',
    'playAria': '일본어 음성 재생',
    'stop': '정지',
    'stopAria': '재생 정지',
  },
  Lang.ar: {
    'entry': 'مساعدة باليابانية',
    'title': 'اعرض هذا على من حولك، أو شغّله بصوت عالٍ',
    'meaningLabel': 'معنى هذا الكلام',
    'meaning1': 'عذرًا، ساعدوني من فضلكم.',
    'meaning2': 'أنا أهرب من التسونامي. أين المكان المرتفع؟',
    'play': 'تشغيل باليابانية',
    'playAria': 'تشغيل الكلام الياباني بصوت عالٍ',
    'stop': 'إيقاف',
    'stopAria': 'إيقاف التشغيل',
  },
};
