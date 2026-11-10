// Pronunciation dictionary: what the speech engine is given instead of the displayed text.
// Port of mocks/evacuate/src/platform/readings.ts.
import '../state/types.dart';

const Map<Lang, Map<String, String>> _readings = {
  Lang.ja: {'高台公園': 'たかだいこうえん', '高台': 'たかだい'},
};

/// [text] as it should be read aloud. Replaced in one pass, longest word first.
String applyReadings(String text, Lang lang) {
  final dict = _readings[lang];
  if (dict == null) return text;
  final words = dict.keys.toList()..sort((a, b) => b.length - a.length);
  return text.replaceAllMapped(RegExp(words.join('|'), unicode: true), (m) => dict[m[0]]!);
}
