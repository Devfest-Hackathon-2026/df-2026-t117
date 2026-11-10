// Bundled Noto fonts (architecture D15: no runtime download, so text never turns into tofu offline).
// Files: assets/fonts/ (variable TTFs from google/fonts, OFL-1.1), declared in pubspec.yaml. See
// docs/third-party.md. Flutter maps `fontWeight` onto the variable `wght` axis, so the w400-w900 used
// by the screens all come from these files.
//
// The family order follows the web's per-language stacks (mocks/evacuate/src/styles/tokens.css):
// Latin first, then the CJK family of the screen's language, so Chinese gets Simplified Chinese glyph
// shapes rather than Japanese ones; Arabic puts Noto Sans Arabic first. The web's Nunito headings are
// not bundled: headings use Noto Sans at the same weights.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'guide_params.dart';

class TkFonts {
  const TkFonts._();

  static const latin = 'NotoSans';
  static const japanese = 'NotoSansJP';
  static const simplifiedChinese = 'NotoSansSC';
  static const korean = 'NotoSansKR';
  static const arabic = 'NotoSansArabic';

  /// First family for [lang].
  static String family(Lang lang) => lang == Lang.ar ? arabic : latin;

  /// The rest, tried in order for characters the first family lacks.
  static List<String> fallback(Lang lang) => switch (lang) {
        // Han in an English screen is a Japanese place name.
        Lang.en => const [japanese, simplifiedChinese, korean, arabic],
        Lang.ja => const [japanese, simplifiedChinese, korean, arabic],
        Lang.zhHans => const [simplifiedChinese, japanese, korean, arabic],
        Lang.ko => const [korean, japanese, simplifiedChinese, arabic],
        Lang.ar => const [latin, japanese, simplifiedChinese, korean],
      };

  /// Families for [lang], to merge into a text style.
  static TextStyle style(Lang lang) => TextStyle(fontFamily: family(lang), fontFamilyFallback: fallback(lang));

  /// Families for a Japanese name shown next to another language (always Japanese glyph shapes).
  static const japaneseName = TextStyle(
    locale: Locale('ja'),
    fontFamily: latin,
    fontFamilyFallback: [japanese, simplifiedChinese, korean, arabic],
  );
}

/// OFL texts of the bundled fonts (assets/fonts/), keyed by the families they cover.
const Map<String, List<String>> tkFontLicenses = {
  'assets/fonts/OFL-NotoSans.txt': [TkFonts.latin],
  'assets/fonts/OFL-NotoSansCJK.txt': [TkFonts.japanese, TkFonts.simplifiedChinese, TkFonts.korean],
  'assets/fonts/OFL-NotoSansArabic.txt': [TkFonts.arabic],
};

/// Adds the fonts' licenses to the app's license registry (the OFL asks for the text to ship with them).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: asset, value: families) in tkFontLicenses.entries) {
      yield LicenseEntryWithLineBreaks(families, await rootBundle.loadString(asset));
    }
  });
}

/// Gives the subtree the fonts of [lang]: the default text style and the Material theme's text styles
/// (Scaffold, buttons), which do not inherit the default text style.
class TkFontScope extends StatelessWidget {
  const TkFontScope({super.key, required this.lang, required this.child});

  final Lang lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = TkFonts.family(lang);
    final fallback = TkFonts.fallback(lang);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: family, fontFamilyFallback: fallback),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family, fontFamilyFallback: fallback),
      ),
      child: DefaultTextStyle.merge(style: TkFonts.style(lang), child: child),
    );
  }
}
