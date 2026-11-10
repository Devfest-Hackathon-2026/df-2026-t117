// Bundled Noto fonts (D15): the right family per language, declared in pubspec.yaml, real TTF files,
// and the font weight drives the variable wght axis (the CJK files default to Thin).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class SilentPlatform implements AppPlatform {
  @override
  final ValueListenable<bool> speaking = ValueNotifier(false);
  @override
  bool speak(String text, Lang lang) => false;
  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

const allFamilies = [TkFonts.latin, TkFonts.japanese, TkFonts.simplifiedChinese, TkFonts.korean, TkFonts.arabic];

/// family -> asset path, from the `fonts:` section of pubspec.yaml.
Map<String, String> declaredFonts() {
  final result = <String, String>{};
  String? family;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final f = RegExp(r'^\s+- family:\s*(\S+)').firstMatch(line);
    if (f != null) family = f.group(1);
    final a = RegExp(r'^\s+- asset:\s*(\S+)').firstMatch(line);
    if (a != null && family != null) result[family] = a.group(1)!;
  }
  return result;
}

/// Dark pixels of [text] drawn in [style].
Future<int> ink(WidgetTester tester, TextStyle style, String text) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: Text(text, style: style.copyWith(color: Colors.black, fontSize: 40)),
        ),
      ),
    ),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  var n = 0;
  for (var i = 0; i < bytes!.length; i += 4) {
    if (bytes[i] < 128) n++;
  }
  return n;
}

void main() {
  test('each language starts with its own script family', () {
    expect(TkFonts.family(Lang.ar), TkFonts.arabic);
    for (final lang in [Lang.en, Lang.ja, Lang.zhHans, Lang.ko]) {
      expect(TkFonts.family(lang), TkFonts.latin, reason: lang.code);
    }
    // Han goes to the language's own CJK family first: Chinese never gets Japanese glyph shapes.
    expect(TkFonts.fallback(Lang.en).first, TkFonts.japanese);
    expect(TkFonts.fallback(Lang.ja).first, TkFonts.japanese);
    expect(TkFonts.fallback(Lang.zhHans).first, TkFonts.simplifiedChinese);
    expect(TkFonts.fallback(Lang.ko).first, TkFonts.korean);
    expect(TkFonts.fallback(Lang.ar).first, TkFonts.latin);
    expect(TkFonts.japaneseName.fontFamilyFallback!.first, TkFonts.japanese);
  });

  test('every language can reach all five families', () {
    for (final lang in Lang.values) {
      expect({TkFonts.family(lang), ...TkFonts.fallback(lang)}, allFamilies.toSet(), reason: lang.code);
    }
  });

  test('pubspec declares every family with a real TrueType file and its license', () {
    final fonts = declaredFonts();
    expect(fonts.keys.toSet(), allFamilies.toSet());
    for (final path in fonts.values) {
      final bytes = File(path).readAsBytesSync();
      expect(bytes.sublist(0, 4), [0, 1, 0, 0], reason: '$path is not a TrueType font');
      expect(bytes.length, greaterThan(500 * 1024), reason: path);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final license in tkFontLicenses.keys) {
      expect(File(license).readAsStringSync(), contains('SIL OPEN FONT LICENSE Version 1.1'), reason: license);
      expect(pubspec, contains('- $license'), reason: license);
    }
    expect(tkFontLicenses.values.expand((f) => f).toSet(), allFamilies.toSet());
  });

  for (final lang in Lang.values) {
    testWidgets('screens and the Material theme use the fonts of ${lang.code}', (tester) async {
      final store = AppStore(scenarioId: '4', lang: lang, platform: SilentPlatform());
      await tester.pumpWidget(MaterialApp(theme: tkMaterialTheme(), home: AppShell(store: store, runClock: false)));
      final context = tester.element(find.byType(TkHeader));
      final text = DefaultTextStyle.of(context).style;
      expect(text.fontFamily, TkFonts.family(lang));
      expect(text.fontFamilyFallback, TkFonts.fallback(lang));
      final material = Theme.of(context).textTheme.bodyMedium!;
      expect(material.fontFamily, TkFonts.family(lang));
      expect(material.fontFamilyFallback, TkFonts.fallback(lang));
    });
  }

  testWidgets('the font weight sets the wght axis of the variable CJK font', (tester) async {
    await tester.runAsync(() async {
      final bytes = File(declaredFonts()[TkFonts.japanese]!).readAsBytesSync();
      await (FontLoader('TestNotoSansJP')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    const style = TextStyle(fontFamily: 'TestNotoSansJP');
    final regular = await ink(tester, style.copyWith(fontWeight: FontWeight.w400), '東京避難');
    final black = await ink(tester, style.copyWith(fontWeight: FontWeight.w900), '東京避難');
    expect(regular, greaterThan(0));
    expect(black, greaterThan(regular * 1.4));
  });
}
