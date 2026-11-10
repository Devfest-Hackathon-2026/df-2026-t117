// TASUKU design tokens (requirements.md section 3; mocks/evacuate/src/styles/tokens.css).
// Screens import this one file for the tokens and the shared components.
import 'package:flutter/material.dart';

import '../src/fonts.dart';
import 'state/types.dart';

export '../src/fonts.dart' show TkFontScope, TkFonts, registerFontLicenses, tkFontLicenses;
export 'components.dart';

/// Background theme of a screen.
enum TkTheme { dark, light }

class TkColors {
  const TkColors._();

  // Core palette
  static const bgDark = Color(0xFF18161A); // dark background (guidance screens)
  static const btnDark = Color(0xFF2A272C); // dark button / header round buttons
  static const panelGrey = Color(0xFF2A272C); // S05 offline top panel
  static const red = Color(0xFFAE1428); // alert red (S02/S03/S04 top panel)
  static const maroon = Color(0xFF7A001B); // calm red (S06 waiting on high ground)
  static const yellow = Color(0xFFFFD54F); // emphasis yellow (badges, primary button, NOW)
  static const pictoBg = Color(0xFFFCE8E4); // pictogram card background
  static const pictoBgCream = Color(0xFFFDF6F1); // S06 pictogram card (cream)
  static const pictoLine = Color(0xFF1B2B2E); // pictogram ink
  static const lightBg = Color(0xFFFDF6F1); // light screens (language, emergency)
  static const lightCard = Color(0xFFF3ECEA); // light list items / round buttons on light bg
  static const lightCardPink = Color(0xFFF8E6E3); // "Show this location" card
  static const black = Color(0xFF17151A); // black button on light bg (Apply)
  static const white = Color(0xFFFFFFFF);

  // Text
  static const textOnDark = Color(0xFFFFFFFF);
  static const textMutedOnDark = Color(0xFFD7CFD3); // footer meta, secondary lines on dark
  static const textOnLight = Color(0xFF17151A);
  static const textMutedOnLight = Color(0xFF5C5459);
  static const outlineOnDark = Color(0xFFB9B0B5); // outline button border on dark

  // Map
  static const mapSea = Color(0xFFBAD3E6);
  static const mapLand = Color(0xFFE8E8E0);
  static const mapRoad = Color(0xFFFFFFFF);
  static const mapHazard = Color(0xFFF0C4BC);
  static const mapHazardStripe = Color(0xFFA8323A);
  static const mapRoute = Color(0xFF1A4F9C);
  static const mapRouteAr = Color(0xFFFFD54F);
  static const mapAccuracyFill = Color(0xFFCFE0F0);
  static const mapLabelSea = Color(0xFF1A4F9C);

  static Color background(TkTheme t) => t == TkTheme.dark ? bgDark : lightBg;
  static Color text(TkTheme t) => t == TkTheme.dark ? textOnDark : textOnLight;
  static Color muted(TkTheme t) => t == TkTheme.dark ? textMutedOnDark : textMutedOnLight;
}

class TkSizes {
  const TkSizes._();

  static const gutter = 24.0;
  static const statusH = 32.0;
  static const headerH = 64.0;
  static const btnH = 58.0; // >= 56 tap target
  static const roundBtn = 48.0;
  static const radiusCard = 22.0;
  static const radiusBadge = 10.0;
  static const fsHeadline = 52.0; // main instruction (>= 40 bold, requirements 10)
  static const fsTitle = 44.0; // sub-screen page title (Language, Call for help)
  static const fsButton = 22.0;
  static const fsBadge = 15.0;
  static const fsBody = 16.0;
  static const fsMeta = 14.0;
}

/// Text styles. The families are the bundled Noto fonts ([TkFonts], lib/src/fonts.dart), set per
/// language by [PhoneFrame] through [TkFontScope]; these styles only give size and weight. The web's
/// Nunito headings are not bundled: Noto Sans at the same weights is used.
class TkText {
  const TkText._();

  static const heading = TextStyle(fontWeight: FontWeight.w900);

  /// Main instruction. Non-Latin scripts are 6 px smaller with a taller line, as on the web.
  static TextStyle headline(Lang lang) => lang == Lang.en
      ? heading.copyWith(fontSize: TkSizes.fsHeadline, height: 1)
      : heading.copyWith(fontSize: TkSizes.fsHeadline - 6, height: 1.2);

  static const title = TextStyle(fontWeight: FontWeight.w900, fontSize: TkSizes.fsTitle, height: 1.05);
  static const button = TextStyle(fontWeight: FontWeight.w800, fontSize: TkSizes.fsButton, height: 1.15);
  static const meta = TextStyle(fontWeight: FontWeight.w700, fontSize: TkSizes.fsMeta, height: 1.4);
}

/// `theme:` of MaterialApp; the screens use the tokens directly. The fonts are the bundled Noto in the
/// English order; [TkFontScope] reorders them for the screen's language.
ThemeData tkMaterialTheme() => ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: TkColors.yellow, brightness: Brightness.dark),
      fontFamily: TkFonts.family(Lang.en),
      fontFamilyFallback: TkFonts.fallback(Lang.en),
    );
