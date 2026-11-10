// Pre-generated voice clips (Chirp 3 HD). Port of mocks/evacuate/src/platform/voiceClips.ts.
// assets/voice/ is a copy of mocks/evacuate/public/voice/ (see README).
// Matching is by the phrase text itself, so a stale clip is never played for an edited text.
import 'dart:convert';

import 'package:flutter/services.dart';

import '../state/types.dart';

/// One part of a spoken text: a clip to play ([asset] set), or text for the device's TTS ([asset] null).
class SpeechPart {
  const SpeechPart.clip(String this.asset, this.text);
  const SpeechPart.tts(this.text) : asset = null;

  final String? asset;
  final String text;
  bool get isClip => asset != null;
}

// Characters treated as separators between phrases. Keep in sync with tools/voice/generate.mjs (SEP).
final RegExp _sep = RegExp(r'[\s.。,，、،!！?？+]', unicode: true);

bool _isSep(String s, int i) => _sep.hasMatch(s[i]);

String _trimSep(String s) {
  var a = 0;
  var b = s.length;
  while (a < b && _isSep(s, a)) {
    a++;
  }
  while (b > a && _isSep(s, b - 1)) {
    b--;
  }
  return s.substring(a, b);
}

const String _base = 'assets/voice/';

const Map<String, Lang> _langKeys = {
  'en': Lang.en,
  'ja': Lang.ja,
  'zh-Hans': Lang.zhHans,
  'ko': Lang.ko,
  'ar': Lang.ar,
};

typedef _Entry = ({String phrase, String asset});

class VoiceClips {
  Map<Lang, List<_Entry>>? _table;
  Future<void>? _pending;

  bool get loaded => _table != null;

  /// Reads the manifest. Resolves when this attempt ends, loaded or not; never rejects.
  Future<void> load() {
    if (_table != null) return Future.value();
    return _pending ??= rootBundle
        .loadString('${_base}manifest.json')
        .then(setManifest)
        .catchError((Object _) {})
        .whenComplete(() => _pending = null);
  }

  /// Builds the table from the text of manifest.json.
  void setManifest(String json) {
    final clips = (jsonDecode(json) as Map<String, dynamic>)['clips'] as Map<String, dynamic>? ?? const {};
    final table = <Lang, List<_Entry>>{};
    clips.forEach((key, value) {
      final lang = _langKeys[key];
      if (lang == null) return;
      final entries = <_Entry>[
        for (final c in (value as Map<String, dynamic>).values)
          (phrase: _trimSep((c as Map<String, dynamic>)['text'] as String), asset: '$_base${c['file']}'),
      ]..removeWhere((e) => e.phrase.isEmpty);
      entries.sort((a, b) => b.phrase.length - a.phrase.length);
      table[lang] = entries;
    });
    _table = table;
  }

  /// Splits [text] into clip / TTS parts, in order. Returns null when no part has a clip.
  /// At each position the longest phrase that ends at a separator (or the end) becomes a clip; otherwise the
  /// text up to the next separator joins the current TTS part, which keeps its original spacing.
  List<SpeechPart>? split(String text, Lang lang) {
    final list = _table?[lang];
    if (list == null || list.isEmpty || text.isEmpty) return null;
    final parts = <SpeechPart>[];
    var ttsStart = -1;
    var ttsEnd = -1;
    void flushTts() {
      if (ttsStart >= 0 && _trimSep(text.substring(ttsStart, ttsEnd)).isNotEmpty) {
        parts.add(SpeechPart.tts(text.substring(ttsStart, ttsEnd).trim()));
      }
      ttsStart = -1;
    }

    var i = 0;
    while (i < text.length) {
      if (_isSep(text, i)) {
        i++;
        continue;
      }
      _Entry? hit;
      for (final e in list) {
        final end = i + e.phrase.length;
        if (text.startsWith(e.phrase, i) && (end >= text.length || _isSep(text, end))) {
          hit = e;
          break;
        }
      }
      if (hit != null) {
        flushTts();
        parts.add(SpeechPart.clip(hit.asset, hit.phrase));
        i += hit.phrase.length;
        continue;
      }
      var j = i;
      while (j < text.length && !_isSep(text, j)) {
        j++;
      }
      if (ttsStart < 0) ttsStart = i;
      ttsEnd = j;
      i = j;
    }
    flushTts();
    return parts.any((p) => p.isClip) ? parts : null;
  }
}
