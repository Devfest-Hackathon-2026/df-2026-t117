// Speech, vibration and notifications behind one interface, so the effects can be tested.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/types.dart';
import 'notifications.dart';
import 'speech.dart';

abstract class AppPlatform {
  /// true while something is being read aloud (F82: the Listen button shows "Stop").
  ValueListenable<bool> get speaking;

  /// Reads [text] aloud. Returns false when read-aloud is not available (the caller shows a toast).
  bool speak(String text, Lang lang);

  void cancelSpeech();

  /// [pattern] = [on, off, on, ...] in ms, as the web's navigator.vibrate.
  void vibrate(List<int> pattern);

  /// The re-notification (F88 / F89). The in-app part is the band on the guidance screens.
  void notify(String title, String body);
}

/// On the phone: Chirp clips + device TTS, the vibrator, and local notifications.
class DeviceAppPlatform implements AppPlatform {
  final SpeechPlayer _speech = SpeechPlayer(DeviceSpeechOutput());
  final LocalNotifier _notifier = LocalNotifier();

  static const _vibrator = MethodChannel('tasuku_ar/vibrate');

  @override
  ValueListenable<bool> get speaking => _speech.speaking;

  @override
  bool speak(String text, Lang lang) => _speech.speak(text, lang);

  @override
  void cancelSpeech() => _speech.cancel();

  @override
  void vibrate(List<int> pattern) {
    _vibrator.invokeMethod<void>('vibrate', {'pattern': pattern}).catchError((Object _) => _haptics(pattern));
  }

  /// Only if the channel fails: haptic pulses need no permission.
  void _haptics(List<int> pattern) {
    var at = 0;
    for (var i = 0; i < pattern.length; i++) {
      if (i.isEven) Timer(Duration(milliseconds: at), HapticFeedback.heavyImpact);
      at += pattern[i];
    }
  }

  @override
  void notify(String title, String body) {
    _notifier.showSimple(title, body).catchError((Object _) {});
  }
}
