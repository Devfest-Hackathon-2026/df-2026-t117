// Feature F: plays the Japanese help phrase (helpJaText). Reuses the app's read-aloud classes (SpeechPlayer,
// VoiceClips, DeviceSpeechOutput): the Chirp 3 HD clip in assets/voice/help/ is played when its manifest text
// matches the phrase, otherwise (missing / stale / unplayable clip) the device TTS reads it in Japanese with
// the readings dictionary (高台 -> たかだい), exactly like the guidance speech.
//
// While it plays, the regular guidance speech is stopped, and any guidance that starts meanwhile (a turn
// announcement while walking, an announcement on entering a screen) is cancelled at once, so the two never
// talk over each other. Afterwards guidance continues with its next announcement as usual.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/app_platform.dart';
import '../platform/speech.dart';
import '../platform/voice_clips.dart';
import '../state/types.dart';
import 'help_strings.dart';

/// Manifest of the help clip, written by tools/voice/help-ja.mjs (same format as assets/voice/manifest.json).
const String helpManifestAsset = 'assets/voice/help/manifest.json';

/// One output for every help card (one extra player for the app, created on first use).
final SpeechOutput _deviceOutput = DeviceSpeechOutput();

class HelpVoice {
  HelpVoice({required this.guidance, SpeechOutput? output, Future<String> Function()? loadManifest})
    : _player = SpeechPlayer(output ?? _deviceOutput, VoiceClips()) {
    _ready = (loadManifest ?? () => rootBundle.loadString(helpManifestAsset))()
        .then(_player.clips.setManifest)
        // No manifest: an empty table, so the phrase goes to the TTS (and the player never loads the
        // guidance manifest into this table).
        .catchError((Object _) => _player.clips.setManifest('{}'));
    guidance.speaking.addListener(_onGuidance);
  }

  /// The app's speech (guidance). Stopped while the help phrase plays.
  final AppPlatform guidance;
  final SpeechPlayer _player;
  late final Future<void> _ready;
  bool _disposed = false;

  /// true while the help phrase is playing.
  ValueListenable<bool> get playing => _player.speaking;

  void _onGuidance() {
    if (_player.speaking.value && guidance.speaking.value) guidance.cancelSpeech();
  }

  /// Stops the guidance speech and plays the phrase from the start.
  Future<void> play() async {
    guidance.cancelSpeech();
    await _ready;
    if (_disposed) return;
    _player.speak(helpJaText, Lang.ja);
  }

  void stop() => _player.cancel();

  void dispose() {
    _disposed = true;
    guidance.speaking.removeListener(_onGuidance);
    _player.cancel();
  }
}
