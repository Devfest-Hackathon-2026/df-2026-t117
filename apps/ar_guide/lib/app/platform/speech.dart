// Read-aloud. Port of mocks/evacuate/src/platform/speech.ts: phrases with a Chirp clip are played as MP3, the
// rest (numbers, missing clips) goes to the device's TTS, one after another. If a clip cannot be played, that
// part and everything after it are read with the TTS.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../i18n/i18n.dart';
import '../state/types.dart';
import 'readings.dart';
import 'voice_clips.dart';

/// The two sound outputs (replaced by a fake in tests).
abstract class SpeechOutput {
  /// Completes when the clip has ended (or was stopped). Throws when it cannot be played.
  Future<void> playClip(String asset);
  Future<void> stopClip();

  /// Completes when the text has been read (or was stopped).
  Future<void> speakTts(String text, Lang lang);
  Future<void> stopTts();
}

/// speak() waits at most this long for the manifest.
const Duration manifestWait = Duration(milliseconds: 300);

/// Upper bound for one TTS part: after it the part counts as finished even without a completion event.
Duration ttsLimit(String text, Lang lang) {
  final perChar = lang == Lang.ja || lang == Lang.zhHans || lang == Lang.ko ? 200 : 120;
  return Duration(milliseconds: 1500 + perChar * text.length);
}

class SpeechPlayer {
  SpeechPlayer(this.output, [VoiceClips? clips]) : clips = clips ?? VoiceClips();

  final SpeechOutput output;
  final VoiceClips clips;
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// Bumped on every speak / cancel, so an interrupted sequence does nothing more.
  int _generation = 0;
  Future<void> _stopped = Future.value();

  void _stopOutputs() {
    final before = _stopped;
    _stopped = () async {
      await before;
      try {
        await output.stopClip();
      } catch (_) {}
      try {
        await output.stopTts();
      } catch (_) {}
    }();
  }

  /// Interrupts anything being spoken. Returns false only for an empty text.
  bool speak(String text, Lang lang) {
    if (text.isEmpty) return false;
    final gen = ++_generation;
    _stopOutputs();
    speaking.value = true;
    unawaited(_run(text, lang, gen));
    return true;
  }

  void cancel() {
    _generation++;
    _stopOutputs();
    speaking.value = false;
  }

  Future<void> _run(String text, Lang lang, int gen) async {
    if (!clips.loaded) await clips.load().timeout(manifestWait, onTimeout: () {});
    await _stopped;
    final parts = clips.split(text, lang) ?? [SpeechPart.tts(text)];
    for (var i = 0; i < parts.length; i++) {
      if (gen != _generation) return;
      final part = parts[i];
      if (!part.isClip) {
        await _tts(part.text, lang, gen, hasNext: i < parts.length - 1);
        continue;
      }
      try {
        await output.playClip(part.asset!);
      } catch (_) {
        if (gen != _generation) return;
        await _tts(parts.sublist(i).map((p) => p.text).join(' '), lang, gen, hasNext: false);
        break;
      }
    }
    if (gen == _generation) speaking.value = false;
  }

  /// [hasNext]: another part follows this one in the same utterance.
  Future<void> _tts(String text, Lang lang, int gen, {required bool hasNext}) async {
    if (text.isEmpty) return;
    final spoken = applyReadings(text, lang);
    try {
      await output.speakTts(spoken, lang).timeout(ttsLimit(spoken, lang));
    } on TimeoutException {
      // The part counts as finished, but the engine may still be reading. If another part follows, silence
      // it so that part does not talk over it; the last part is left to finish (only the waiting stops).
      if (!hasNext || gen != _generation) return;
      try {
        await output.stopTts();
      } catch (_) {}
    } catch (_) {
      // An engine error only ends this part.
    }
  }
}

/// The part of just_audio's AudioPlayer that DeviceSpeechOutput uses (replaced by a fake in tests).
abstract class ClipPlayer {
  /// just_audio: becomes true on play() and stays true until pause() / stop(), also after a clip has ended.
  bool get playing;
  Future<void> setAsset(String asset);

  /// just_audio: completes when the clip ends or is paused / stopped, and at once when already [playing].
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
}

/// The part of flutter_tts that DeviceSpeechOutput uses (replaced by a fake in tests).
abstract class TtsEngine {
  Future<void> setLanguage(String tag);

  /// Completes when the text has been read (or was stopped).
  Future<void> speak(String text);
  Future<void> stop();
}

class _JustAudioClipPlayer implements ClipPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  bool get playing => _player.playing;

  @override
  Future<void> setAsset(String asset) async {
    await _player.setAsset(asset);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();
}

class _FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _setup;

  Future<void> _ready() => _setup ??= () async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.5); // flutter_tts maps 0.5 to Android's normal rate
  }();

  @override
  Future<void> setLanguage(String tag) async {
    await _ready();
    await _tts.setLanguage(tag);
  }

  @override
  Future<void> speak(String text) async {
    await _ready();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// just_audio for the clips, flutter_tts for the rest. Both are created on first use.
///
/// Two rules keep one voice at a time:
///  - A request that was stopped while it was still preparing (pause / setAsset / setLanguage) never starts
///    playback afterwards: every stop bumps [_stops], and each request checks it after every await.
///  - Each clip starts from a paused player. just_audio keeps `playing` true after a clip ends, so without
///    the pause the next setAsset would start at once and play() would return immediately: the next part
///    (often the TTS for a number) would then talk over that clip.
class DeviceSpeechOutput implements SpeechOutput {
  DeviceSpeechOutput({ClipPlayer Function()? newClipPlayer, TtsEngine Function()? newTts})
    : _newClipPlayer = newClipPlayer ?? _JustAudioClipPlayer.new,
      _newTts = newTts ?? _FlutterTtsEngine.new;

  final ClipPlayer Function() _newClipPlayer;
  final TtsEngine Function() _newTts;
  ClipPlayer? _player;
  TtsEngine? _tts;

  /// Bumped by every stopClip / stopTts. A request started before the bump is superseded.
  int _stops = 0;

  /// A clip is a few seconds long; this only guards against a player that never reports the end.
  static const Duration _clipLimit = Duration(seconds: 30);

  @override
  Future<void> playClip(String asset) async {
    final token = _stops;
    final player = _player ??= _newClipPlayer();
    if (player.playing) await player.pause();
    if (token != _stops) return;
    await player.setAsset(asset);
    if (token != _stops) return;
    await player.play().timeout(_clipLimit);
  }

  @override
  Future<void> stopClip() async {
    _stops++;
    await _player?.stop();
  }

  @override
  Future<void> speakTts(String text, Lang lang) async {
    final token = _stops;
    final tts = _tts ??= _newTts();
    await tts.setLanguage(langSpeechTags[lang]!);
    if (token != _stops) return;
    await tts.speak(text);
  }

  @override
  Future<void> stopTts() async {
    _stops++;
    await _tts?.stop();
  }
}
