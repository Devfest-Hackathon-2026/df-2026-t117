// i18n foundation. Port of mocks/evacuate/src/i18n (detect.ts and index.ts).
// Common strings: common_strings.dart. Screen strings: a `Dict` in each screen file (see README).
import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

import 'package:shared_preferences/shared_preferences.dart';

import '../state/types.dart';
import 'common_strings.dart';

export 'common_strings.dart';

const List<Lang> langs = Lang.values;

/// Map a BCP-47 tag to a supported language, or null. Traditional Chinese falls back to null (-> en).
Lang? matchLang(String tag) {
  final t = tag.toLowerCase();
  if (t.startsWith('ja')) return Lang.ja;
  if (t.startsWith('ko')) return Lang.ko;
  if (t.startsWith('ar')) return Lang.ar;
  if (t.startsWith('en')) return Lang.en;
  if (t.startsWith('zh')) {
    if (RegExp(r'hant|-tw|-hk|-mo').hasMatch(t)) return null;
    return Lang.zhHans;
  }
  return null;
}

/// Detect from the device's language list. Fallback en.
Lang detectLang([List<Locale>? locales]) {
  for (final l in locales ?? PlatformDispatcher.instance.locales) {
    final m = matchLang(l.toLanguageTag());
    if (m != null) return m;
  }
  return Lang.en;
}

Lang? _savedLang;

const String _langKey = 'tasuku.lang';

Lang? _langNamed(String? name) => Lang.values.where((l) => l.name == name).firstOrNull;

/// Reads the saved language into memory. Call once before the app starts; a failure means "none saved".
Future<void> loadSavedLang() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
    _savedLang = _langNamed(prefs.getString(_langKey));
  } catch (_) {}
}

/// Saved language if any, otherwise detected.
Lang loadLang() => _savedLang ?? detectLang();

/// Called by S09 when the language is applied.
void saveLang(Lang lang) {
  _savedLang = lang;
  unawaited(_writeString(_langKey, lang.name));
}

Future<void> _writeString(String key, String value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  } catch (_) {}
}

const String _notificationLangKey = 'tasuku.notification_lang';

/// The app's current language, for notifications shown while it is closed.
void saveNotificationLang(Lang lang) => unawaited(_writeString(_notificationLangKey, lang.name));

/// Language of a notification shown from the background isolate.
Future<Lang> loadNotificationLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final saved = _langNamed(prefs.getString(_notificationLangKey));
    if (saved != null) return saved;
  } catch (_) {}
  return detectLang();
}

bool isRtl(Lang lang) => lang == Lang.ar;

TextDirection textDirectionOf(Lang lang) => isRtl(lang) ? TextDirection.rtl : TextDirection.ltr;

/// Locale for text, so Han characters use the right regional glyphs.
Locale localeOf(Lang lang) => switch (lang) {
      Lang.en => const Locale('en'),
      Lang.ja => const Locale('ja'),
      Lang.zhHans => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Lang.ko => const Locale('ko'),
      Lang.ar => const Locale('ar'),
    };

/// Native names for the language picker.
const Map<Lang, String> langNativeNames = {
  Lang.en: 'English',
  Lang.ja: '日本語',
  Lang.zhHans: '简体中文',
  Lang.ko: '한국어',
  Lang.ar: 'العربية',
};

/// BCP-47 tags for text-to-speech.
const Map<Lang, String> langSpeechTags = {
  Lang.en: 'en-US',
  Lang.ja: 'ja-JP',
  Lang.zhHans: 'zh-CN',
  Lang.ko: 'ko-KR',
  Lang.ar: 'ar-SA',
};

/// A 5-language dictionary: language -> key -> text. Screens declare one as a `const`.
typedef Dict = Map<Lang, Map<String, String>>;

/// The strings of one language. A missing key falls back to English, then to the key itself,
/// so a typo shows up on the screen instead of crashing it.
class Tr {
  const Tr(this._strings, this._english);

  factory Tr.of(Dict dict, Lang lang) {
    final en = dict[Lang.en] ?? const <String, String>{};
    return Tr(dict[lang] ?? en, en);
  }

  final Map<String, String> _strings;
  final Map<String, String> _english;

  String operator [](String key) => _strings[key] ?? _english[key] ?? key;
}

/// Replace {name} placeholders: fmt('{n} m', {'n': 40}) -> '40 m'.
String fmt(String template, Map<String, Object> vars) => template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => vars.containsKey(m[1]) ? '${vars[m[1]]}' : m[0]!,
    );

/// Place names: current language + Japanese (requirements 1, F25).
/// `ja` is null when the current language is Japanese (avoid duplication).
({String primary, String? ja}) bilingual(L10n l10n, Lang lang) =>
    lang == Lang.ja ? (primary: l10n.ja, ja: null) : (primary: l10n[lang], ja: l10n.ja);

/// One-line form: "Hill Park / 高台公園" (or just "高台公園" in Japanese).
String bilingualText(L10n l10n, Lang lang, [String sep = ' / ']) {
  final b = bilingual(l10n, lang);
  return b.ja != null ? '${b.primary}$sep${b.ja}' : b.primary;
}

/// Badge label for an alert (F02): TSUNAMI WARNING / MAJOR TSUNAMI WARNING / TSUNAMI ADVISORY / EARTHQUAKE.
String alertBadgeLabel(Alert alert, Lang lang) {
  final c = commonStrings[lang]!;
  if (alert.type == HazardType.earthquake) return c.badgeEarthquake;
  return switch (alert.level) {
    AlertLevel.emergency => c.badgeMajorTsunamiWarning,
    AlertLevel.advisory => c.badgeTsunamiAdvisory,
    AlertLevel.warning => c.badgeTsunamiWarning,
  };
}

/// Badge label for the earthquake situation (INDOORS / OUTDOORS / IN CAR).
String eqSituationLabel(EqSituation s, Lang lang) {
  final c = commonStrings[lang]!;
  return switch (s) {
    EqSituation.indoors => c.badgeIndoors,
    EqSituation.outdoors => c.badgeOutdoors,
    EqSituation.car => c.badgeInCar,
  };
}
