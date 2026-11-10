// Feature F "Ask for help in Japanese": the card (Japanese + meaning per language, RTL in Arabic), the entry
// buttons on S04 / S10, and the player (clip, TTS fallback with readings, guidance stopped while playing).
import 'dart:async';
import 'dart:io';

import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/help/help_card.dart';
import 'package:ar_guide/app/help/help_card_open.dart';
import 'package:ar_guide/app/help/help_strings.dart';
import 'package:ar_guide/app/help/help_voice.dart';
import 'package:ar_guide/app/i18n/i18n.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/platform/speech.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The guidance speech: records speak / cancel.
class GuidancePlatform implements AppPlatform {
  final _speaking = ValueNotifier<bool>(false);
  int cancels = 0;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  bool speak(String text, Lang lang) {
    _speaking.value = true;
    return true;
  }

  @override
  void cancelSpeech() {
    cancels++;
    _speaking.value = false;
  }

  @override
  void vibrate(List<int> pattern) {}

  @override
  void notify(String title, String body) {}
}

/// Same shape as the fake in platform_test.dart: a clip "plays" until [hold] completes.
class FakeOutput implements SpeechOutput {
  final log = <String>[];
  final failing = <String>{};
  Completer<void>? hold;

  /// The hold of the clip that is playing now (a stop ends that clip only).
  Completer<void>? _current;

  @override
  Future<void> playClip(String asset) async {
    log.add('clip:$asset');
    if (failing.contains(asset)) throw StateError('cannot play');
    final h = hold;
    if (h == null) return;
    _current = h;
    await h.future;
  }

  @override
  Future<void> speakTts(String text, Lang lang) async => log.add('tts:${lang.name}:$text');

  @override
  Future<void> stopClip() async {
    final h = _current;
    _current = null;
    if (h != null && !h.isCompleted) h.complete();
  }

  @override
  Future<void> stopTts() async {}
}

const String clipAsset = 'assets/voice/help/ja.mp3';

void main() {
  // flutter test runs in the package root; the card gets the bundled manifest's text.
  final manifest = File(helpManifestAsset).readAsStringSync();
  late FakeOutput output;

  setUp(() {
    output = FakeOutput()..hold = Completer<void>();
    createHelpVoice = (guidance) => HelpVoice(guidance: guidance, output: output, loadManifest: () async => manifest);
  });
  tearDown(() {
    createHelpVoice = (guidance) => HelpVoice(guidance: guidance);
  });

  Future<(AppStore, GuidancePlatform)> pumpApp(WidgetTester tester, Lang lang, ScreenId screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = GuidancePlatform();
    final store = AppStore(scenarioId: '4', lang: lang, platform: platform);
    await tester.pumpWidget(MaterialApp(theme: tkMaterialTheme(), home: AppShell(store: store, runClock: false)));
    store.patch(StatePatch(overlay: [screen]));
    await tester.pump();
    return (store, platform);
  }

  Future<void> openCard(WidgetTester tester) async {
    final entry = find.byKey(const ValueKey('help-ja-entry'));
    await tester.ensureVisible(entry);
    await tester.pump();
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  test('the bundled clip was made from the current Japanese text (re-run tools/voice/help-ja.mjs if not)', () {
    expect(manifest, contains('"text": "$helpJaText"'));
    expect(manifest, contains('たかだい'));
    expect(File(clipAsset).existsSync(), isTrue);
  });

  test('every language has every string', () {
    final keys = helpDict[Lang.en]!.keys.toSet();
    for (final lang in Lang.values) {
      expect(helpDict[lang]!.keys.toSet(), keys, reason: lang.name);
    }
  });

  for (final lang in Lang.values) {
    testWidgets('S04 opens the card in ${lang.name}: Japanese + meaning', (tester) async {
      await pumpApp(tester, lang, ScreenId.s04);
      final t = Tr.of(helpDict, lang);
      expect(find.text(t['entry']), findsOneWidget);
      await openCard(tester);
      expect(tester.takeException(), isNull);
      for (final line in helpJaLines) {
        expect(find.text(line), findsOneWidget);
      }
      if (lang == Lang.ja) {
        expect(find.text(t['meaningLabel']), findsNothing);
      } else {
        expect(find.text(t['meaning1']), findsOneWidget);
        expect(find.text(t['meaning2']), findsOneWidget);
      }
      final cardDir = Directionality.of(tester.element(find.text(t['title'])));
      expect(cardDir, lang == Lang.ar ? TextDirection.rtl : TextDirection.ltr);
      // The Japanese stays left-to-right, also in Arabic.
      final jaText = tester.widget<Text>(find.text(helpJaLines.first));
      expect(jaText.textDirection, TextDirection.ltr);
    });
  }

  testWidgets('the open card is counted, so raising the phone does not switch S04 to AR', (tester) async {
    await pumpApp(tester, Lang.en, ScreenId.s04);
    expect(helpCardsOpen.value, 0);
    await openCard(tester);
    expect(helpCardsOpen.value, 1);
    await tester.tap(find.byKey(const ValueKey('help-ja-close')));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCard), findsNothing);
    expect(helpCardsOpen.value, 0);
  });

  testWidgets('S10 has the entry too, and the card works on a small phone in Arabic', (tester) async {
    await pumpApp(tester, Lang.ar, ScreenId.s10);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pump();
    await openCard(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(HelpCard), findsOneWidget);
    expect(find.text(helpDict[Lang.ar]!['meaning2']!), findsOneWidget);
  });

  testWidgets('opening plays the clip once and stops the guidance; the button stops and replays', (tester) async {
    final (_, guidance) = await pumpApp(tester, Lang.en, ScreenId.s04);
    guidance.speak('Turn right', Lang.en);
    await openCard(tester);
    expect(guidance.speaking.value, isFalse);
    expect(guidance.cancels, greaterThan(0));
    expect(output.log, ['clip:$clipAsset']);
    expect(find.text('Stop'), findsOneWidget);

    // Guidance that starts while the phrase plays is cancelled at once.
    final before = guidance.cancels;
    guidance.speak('Turn left', Lang.en);
    expect(guidance.speaking.value, isFalse);
    expect(guidance.cancels, before + 1);

    await tester.tap(find.byKey(const ValueKey('help-ja-play')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Play in Japanese'), findsOneWidget);

    output.hold = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('help-ja-play')));
    await tester.pump();
    await tester.pump();
    expect(output.log, ['clip:$clipAsset', 'clip:$clipAsset']);
    expect(find.text('Stop'), findsOneWidget);

    // Closing the card stops the phrase; guidance is free to speak again.
    await tester.tap(find.byKey(const ValueKey('help-ja-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HelpCard), findsNothing);
    final cancels = guidance.cancels;
    guidance.speak('Turn left', Lang.en);
    expect(guidance.speaking.value, isTrue);
    expect(guidance.cancels, cancels);
  });

  group('HelpVoice', () {
    test('plays the bundled clip for the Japanese text', () async {
      final guidance = GuidancePlatform();
      final out = FakeOutput();
      final voice = HelpVoice(guidance: guidance, output: out, loadManifest: () async => manifest);
      await voice.play();
      await pumpEventQueue();
      expect(out.log, ['clip:$clipAsset']);
      expect(voice.playing.value, isFalse);
      voice.dispose();
    });

    test('falls back to Japanese TTS with the readings when the clip cannot be played', () async {
      final out = FakeOutput()..failing.add(clipAsset);
      final voice = HelpVoice(guidance: GuidancePlatform(), output: out, loadManifest: () async => manifest);
      await voice.play();
      await pumpEventQueue();
      // The player trims the trailing separator (？) as for every phrase; 高台 is read as たかだい.
      expect(out.log, ['clip:$clipAsset', 'tts:ja:すみません、助けてください。津波から逃げています。たかだいはどこですか']);
      voice.dispose();
    });

    test('falls back to TTS when the manifest is missing', () async {
      final out = FakeOutput();
      final voice = HelpVoice(
        guidance: GuidancePlatform(),
        output: out,
        loadManifest: () => Future<String>.error(StateError('missing')),
      );
      await voice.play();
      await pumpEventQueue();
      expect(out.log.single, startsWith('tts:ja:'));
      expect(out.log.single, contains('たかだい'));
      voice.dispose();
    });
  });
}
