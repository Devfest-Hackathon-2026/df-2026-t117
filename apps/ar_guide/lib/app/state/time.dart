// Virtual clock helpers. All times are shown in JST regardless of the device's timezone.
// Port of mocks/evacuate/src/state/time.ts.

const int _jstOffsetMs = 9 * 60 * 60 * 1000;
const int minuteMs = 60 * 1000;

/// 2026-11-08 09:41:00 JST (= 00:41:00 UTC). Initial virtual clock.
final int demoStartMs = DateTime.utc(2026, 11, 8, 0, 41).millisecondsSinceEpoch;

/// Build an epoch ms for a JST wall-clock time on the demo day (2026-11-08).
int jstOnDemoDay(int hh, int mm, [int ss = 0]) =>
    DateTime.utc(2026, 11, 8, hh, mm, ss).millisecondsSinceEpoch - _jstOffsetMs;

/// "HH:MM" in JST, e.g. "09:41".
String formatJst(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms + _jstOffsetMs, isUtc: true);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// "HH:MM JST", e.g. "09:40 JST".
String formatJstLabel(int ms) => '${formatJst(ms)} JST';
