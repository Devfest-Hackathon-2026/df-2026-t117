// Guidance parameters received from the mock's S11 via the deep link
//   tasuku-ar://guide?turn=right&dist=12&dest=Hill%20Park&lang=en&bearing=80
// The link can come from any app or web page, so every value is validated and clamped; anything
// missing or invalid falls back to the demo default.

enum Turn { left, right, straight }

/// How the arrow is placed. `compass` works without ARCore (AQUOS wish4 is not ARCore-certified).
enum ArMode { auto, compass, arcore }

enum Lang {
  en('en'),
  ja('ja'),
  zhHans('zh-Hans'),
  ko('ko'),
  ar('ar');

  const Lang(this.code);
  final String code;

  bool get isRtl => this == Lang.ar;

  static Lang? parse(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (v == 'zh' || v == 'zh-hans' || v == 'zh-cn') return Lang.zhHans;
    for (final l in Lang.values) {
      if (l.code.toLowerCase() == v) return l;
    }
    return null;
  }
}

class GuideParams {
  const GuideParams({
    required this.turn,
    required this.distanceM,
    required this.dest,
    required this.destJa,
    required this.lang,
    this.bearingDeg,
    this.mode = ArMode.auto,
    this.fromLink = false,
  });

  static const defaultDest = 'Hill Park';
  static const defaultDestJa = '高台公園';
  static const maxDistanceM = 9999;
  static const maxNameLength = 40;

  /// Demo default (same values as the mock's S11 screenshot: Right, 12 m, Hill Park).
  static const demo = GuideParams(
    turn: Turn.right,
    distanceM: 12,
    dest: defaultDest,
    destJa: defaultDestJa,
    lang: Lang.en,
  );

  final Turn turn;
  final int distanceM;

  /// Destination name in the guidance language (or English).
  final String dest;

  /// Japanese name shown after a slash ("Hill Park / 高台公園"); null when unknown.
  final String? destJa;
  final Lang lang;

  /// Compass bearing (deg, 0 = north, clockwise) of the way to walk to the next turn.
  /// null = not given: the app takes the heading at start as the route direction (demo).
  final double? bearingDeg;

  /// `auto` uses ARCore when it is installed and supported, otherwise the compass mode.
  final ArMode mode;

  /// true when the values came from a deep link (false = demo default).
  final bool fromLink;

  /// Never throws: a malformed link (e.g. broken %-encoding, which makes `queryParameters` throw a
  /// FormatException) gives the demo default instead of keeping the previous link's values.
  static GuideParams fromUri(Uri? uri) {
    try {
      return _parse(uri);
    } catch (_) {
      return demo;
    }
  }

  static GuideParams _parse(Uri? uri) {
    if (uri == null || uri.scheme != 'tasuku-ar' || uri.host != 'guide') {
      return demo;
    }
    final q = uri.queryParameters;
    final turn = switch (q['turn']?.trim().toLowerCase()) {
      'left' => Turn.left,
      'right' => Turn.right,
      'straight' => Turn.straight,
      _ => demo.turn,
    };
    final distRaw = num.tryParse(q['dist']?.trim() ?? '');
    final dist = (distRaw == null || distRaw.isNaN || distRaw.isInfinite)
        ? demo.distanceM
        : distRaw.round().clamp(0, maxDistanceM);
    final dest = _cleanName(q['dest']) ?? defaultDest;
    final destJa = _cleanName(q['dest_ja']) ?? (dest == defaultDest ? defaultDestJa : null);
    final bearingRaw = num.tryParse(q['bearing']?.trim() ?? '');
    final bearing = (bearingRaw == null || bearingRaw.isNaN || bearingRaw.isInfinite)
        ? null
        : ((bearingRaw.toDouble() % 360) + 360) % 360;
    final mode = switch (q['mode']?.trim().toLowerCase()) {
      'compass' => ArMode.compass,
      'arcore' => ArMode.arcore,
      _ => ArMode.auto,
    };
    return GuideParams(
      turn: turn,
      distanceM: dist,
      dest: dest,
      destJa: destJa == dest ? null : destJa,
      lang: Lang.parse(q['lang']) ?? demo.lang,
      bearingDeg: bearing,
      mode: mode,
      fromLink: true,
    );
  }

  /// C0 controls, DEL, bidi embeddings / overrides (U+202A-202E) and isolates (U+2066-2069).
  /// Built from code points so the source file contains no invisible bidi characters.
  static final _unsafeChars = RegExp('[${_ch(0x00)}-${_ch(0x1f)}${_ch(0x7f)}'
      '${_ch(0x202a)}-${_ch(0x202e)}${_ch(0x2066)}-${_ch(0x2069)}]');

  static String _ch(int code) => String.fromCharCode(code);

  /// Removes control / bidi-override characters, collapses spaces and limits the length.
  static String? _cleanName(String? raw) {
    if (raw == null) return null;
    final cleaned = raw
        .replaceAll(_unsafeChars, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    final chars = cleaned.runes.toList();
    if (chars.length <= maxNameLength) return cleaned;
    return String.fromCharCodes(chars.take(maxNameLength));
  }
}
