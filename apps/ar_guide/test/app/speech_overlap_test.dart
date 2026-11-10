// One voice at a time (S06 overlap on the device): DeviceSpeechOutput with a clip player that behaves like
// just_audio and a TTS engine whose steps take as long as the test says, plus the scenario 1 arrival.
import 'dart:async';
import 'dart:convert';

import 'package:ar_guide/app/app_shell.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/platform/speech.dart';
import 'package:ar_guide/app/platform/voice_clips.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:ar_guide/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What is audible right now, shared by the two fakes. [overlaps] records every moment both were sounding.
class _Speaker {
  String? clip;
  String? tts;
  final log = <String>[];
  final overlaps = <String>[];

  void check() {
    if (clip != null && tts != null) overlaps.add('$clip + $tts');
  }
}

/// Like just_audio's AudioPlayer: `playing` stays true after a clip ends; setAsset while playing starts the
/// new clip at once; play() while playing returns at once. A clip sounds until the test calls [end].
class _FakeClipPlayer implements ClipPlayer {
  _FakeClipPlayer(this.s);

  final _Speaker s;
  Completer<void>? loadGate;
  String? _asset;
  Completer<void>? _playing;
  bool _playFlag = false;

  @override
  bool get playing => _playFlag;

  void _start() {
    s.clip = _asset;
    s.log.add('clip start $_asset');
    s.check();
  }

  /// The clip that is sounding reaches its end (`playing` stays true, as in just_audio).
  void end() {
    if (s.clip == null) return;
    s.log.add('clip end ${s.clip}');
    s.clip = null;
    final p = _playing;
    _playing = null;
    if (p != null && !p.isCompleted) p.complete();
  }

  void _silence() {
    s.clip = null;
    final p = _playing;
    _playing = null;
    if (p != null && !p.isCompleted) p.complete();
  }

  @override
  Future<void> setAsset(String asset) async {
    final gate = loadGate;
    if (gate != null) await gate.future;
    _silence();
    _asset = asset;
    if (_playFlag) _start();
  }

  @override
  Future<void> play() async {
    if (_playFlag) return;
    _playFlag = true;
    _start();
    final p = _playing = Completer<void>();
    await p.future;
  }

  @override
  Future<void> pause() async {
    _playFlag = false;
    _silence();
  }

  @override
  Future<void> stop() async {
    _playFlag = false;
    _silence();
  }
}

/// TTS whose setLanguage can be held, and whose text sounds until the test calls [end].
class _FakeTts implements TtsEngine {
  _FakeTts(this.s);

  final _Speaker s;
  Completer<void>? languageGate;
  Completer<void>? _speaking;

  @override
  Future<void> setLanguage(String tag) async {
    final gate = languageGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> speak(String text) async {
    s.tts = text;
    s.log.add('tts start $text');
    s.check();
    final c = _speaking = Completer<void>();
    await c.future;
  }

  void end() {
    if (s.tts == null) return;
    s.log.add('tts end ${s.tts}');
    s.tts = null;
    final c = _speaking;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> stop() async {
    s.tts = null;
    final c = _speaking;
    if (c != null && !c.isCompleted) c.complete();
  }
}

const _manifest = {
  'clips': {
    'en': {
      'a': {'file': 'en/a.mp3', 'text': 'Stay here.'},
      'b': {'file': 'en/b.mp3', 'text': 'HIGH GROUND'},
      'c': {'file': 'en/c.mp3', 'text': 'Follow staff instructions'},
    },
  },
};

class _Rig {
  _Rig() {
    clip = _FakeClipPlayer(s);
    tts = _FakeTts(s);
    output = DeviceSpeechOutput(newClipPlayer: () => clip, newTts: () => tts);
    player = SpeechPlayer(output, VoiceClips()..setManifest(jsonEncode(_manifest)));
  }

  final s = _Speaker();
  late final _FakeClipPlayer clip;
  late final _FakeTts tts;
  late final DeviceSpeechOutput output;
  late final SpeechPlayer player;
}

/// Records what the screens and effects ask to read aloud.
class _Recorder implements AppPlatform {
  final spoken = <String>[];
  final _speaking = ValueNotifier<bool>(false);
  @override
  ValueListenable<bool> get speaking => _speaking;
  @override
  bool speak(String text, Lang lang) {
    spoken.add(text);
    return true;
  }

  @override
  void cancelSpeech() {}
  @override
  void vibrate(List<int> pattern) {}
  @override
  void notify(String title, String body) {}
}

void main() {
  group('DeviceSpeechOutput: one voice at a time', () {
    test('the S06 sentence: the TTS for the number waits until the clip before it has ended', () async {
      final r = _Rig();
      r.player.speak('Stay here. HIGH GROUND 25 m above forecast Follow staff instructions', Lang.en);
      await pumpEventQueue();
      expect(r.s.clip, 'assets/voice/en/a.mp3');
      r.clip.end();
      await pumpEventQueue();
      // The player still says `playing` after the first clip: the second must not return early.
      expect(r.s.clip, 'assets/voice/en/b.mp3');
      expect(r.s.tts, isNull);
      r.clip.end();
      await pumpEventQueue();
      expect(r.s.tts, '25 m above forecast');
      r.tts.end();
      await pumpEventQueue();
      expect(r.s.clip, 'assets/voice/en/c.mp3');
      r.clip.end();
      await pumpEventQueue();
      expect(r.player.speaking.value, isFalse);
      expect(r.s.overlaps, isEmpty);
      expect(r.s.log, [
        'clip start assets/voice/en/a.mp3',
        'clip end assets/voice/en/a.mp3',
        'clip start assets/voice/en/b.mp3',
        'clip end assets/voice/en/b.mp3',
        'tts start 25 m above forecast',
        'tts end 25 m above forecast',
        'clip start assets/voice/en/c.mp3',
        'clip end assets/voice/en/c.mp3',
      ]);
    });

    test('a TTS request interrupted during setLanguage never starts reading', () async {
      final r = _Rig();
      r.tts.languageGate = Completer();
      r.player.speak('12 m', Lang.en);
      await pumpEventQueue();
      expect(r.s.tts, isNull);
      r.player.speak('Stay here.', Lang.en);
      await pumpEventQueue();
      expect(r.s.clip, 'assets/voice/en/a.mp3');
      r.tts.languageGate!.complete();
      await pumpEventQueue();
      expect(r.s.tts, isNull);
      expect(r.s.overlaps, isEmpty);
      expect(r.s.log, ['clip start assets/voice/en/a.mp3']);
    });

    test('a clip request interrupted during setAsset never starts playing', () async {
      final r = _Rig();
      r.clip.loadGate = Completer();
      r.player.speak('Stay here.', Lang.en);
      await pumpEventQueue();
      r.player.cancel();
      await pumpEventQueue();
      r.clip.loadGate!.complete();
      r.clip.loadGate = null;
      await pumpEventQueue();
      expect(r.s.clip, isNull);
      expect(r.s.log, isEmpty);
      expect(r.clip.playing, isFalse);
    });
  });

  testWidgets('a TTS part that outlives its limit is silenced before the next part', (tester) async {
    final r = _Rig();
    r.player.speak('25 m above forecast Follow staff instructions', Lang.en);
    await tester.pump();
    expect(r.s.tts, '25 m above forecast');
    await tester.pump(ttsLimit('25 m above forecast', Lang.en) + const Duration(milliseconds: 10));
    expect(r.s.tts, isNull);
    expect(r.s.clip, 'assets/voice/en/c.mp3');
    expect(r.s.overlaps, isEmpty);
    r.player.cancel();
    await tester.pump();
  });

  for (final text in ['Water is 25 m above forecast', 'Stay here. 25 m above forecast']) {
    testWidgets('the last TTS part is not cut at its limit: "$text"', (tester) async {
      final r = _Rig();
      r.player.speak(text, Lang.en);
      await tester.pump();
      if (r.s.clip != null) {
        r.clip.end();
        await tester.pump();
      }
      final last = r.s.tts!;
      await tester.pump(ttsLimit(last, Lang.en) + const Duration(milliseconds: 10));
      // The player stops waiting, but the engine keeps reading to the end.
      expect(r.player.speaking.value, isFalse);
      expect(r.s.tts, last);
      r.tts.end();
      await tester.pump();
      expect(r.s.log.last, 'tts end $last');
    });
  }

  testWidgets('scenario 1: arriving at S06 announces it once', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rec = _Recorder();
    final store = AppStore(scenarioId: '1', lang: Lang.ja, platform: rec);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tkMaterialTheme(),
        home: AppShell(store: store, runClock: false),
      ),
    );
    store.patch(const StatePatch(lockScreen: false, shaking: false));
    await tester.pump(const Duration(seconds: 1));
    store.patch(const StatePatch(guideStep: GuideStep.nav, walk: WalkPatch(playing: true, speed: 4)));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 900 && store.screen != ScreenId.s06; i++) {
      store.tick(250);
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(store.screen, ScreenId.s06);
    final before = rec.spoken.length;
    for (var i = 0; i < 20; i++) {
      store.tick(250);
      await tester.pump(const Duration(milliseconds: 250));
    }
    final arrival = rec.spoken.sublist(before);
    expect(arrival, hasLength(1));
    expect(arrival.single, startsWith('ここで待機。'));
  });
}
