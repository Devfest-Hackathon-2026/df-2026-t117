// Speech sequencing, voice clip splitting, live alert rules, notification text and the demo panel.
import 'dart:async';
import 'dart:convert';

import 'package:ar_guide/app/demo/demo_panel.dart';
import 'package:ar_guide/app/live/live_alerts.dart';
import 'package:ar_guide/app/live/live_backend.dart';
import 'package:ar_guide/app/live/live_doc.dart';
import 'package:ar_guide/app/live/push_text.dart';
import 'package:ar_guide/app/platform/app_platform.dart';
import 'package:ar_guide/app/platform/notifications.dart';
import 'package:ar_guide/app/platform/readings.dart';
import 'package:ar_guide/app/platform/speech.dart';
import 'package:ar_guide/app/platform/voice_clips.dart';
import 'package:ar_guide/app/state/store.dart';
import 'package:ar_guide/app/state/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOutput implements SpeechOutput {
  final log = <String>[];
  final failing = <String>{};
  Completer<void>? hold;

  @override
  Future<void> playClip(String asset) async {
    log.add('clip:$asset');
    if (hold != null) await hold!.future;
    if (failing.contains(asset)) throw StateError('cannot play');
  }

  @override
  Future<void> speakTts(String text, Lang lang) async => log.add('tts:$text');

  @override
  Future<void> stopClip() async {}

  @override
  Future<void> stopTts() async {}
}

class QuietPlatform implements AppPlatform {
  final _speaking = ValueNotifier<bool>(false);
  final notified = <String>[];

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  bool speak(String text, Lang lang) => true;

  @override
  void cancelSpeech() {}

  @override
  void vibrate(List<int> pattern) {}

  @override
  void notify(String title, String body) => notified.add(title);
}

class FakeBackend implements LiveBackend {
  FakeBackend({this.fails = false});

  final bool fails;
  final controller = StreamController<LiveSnapshot>.broadcast(sync: true);
  int registered = 0;

  @override
  Future<void> init() async {
    if (fails) throw StateError('no google-services.json');
  }

  @override
  Stream<LiveSnapshot> alerts() => controller.stream;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<void> registerPush(void Function() onForeground) async => registered++;
}

const _manifest = {
  'clips': {
    'en': {
      'a': {'file': 'en/a.mp3', 'text': 'Stay here.'},
      'b': {'file': 'en/b.mp3', 'text': 'HIGH GROUND'},
      'c': {'file': 'en/c.mp3', 'text': 'Stay'},
    },
  },
};

VoiceClips _clips() => VoiceClips()..setManifest(jsonEncode(_manifest));

const int _now = 1800000000000;

Map<String, dynamic> _doc({int serial = 1, String kind = 'tsunami-warning', String? level = 'warning', int? updatedAt, String areaId = 'minato-bay'}) => {
      'eventId': 'E1',
      'serial': serial,
      'infoType': '発表',
      'kind': kind,
      'level': level,
      'expectedHeight': 3,
      'areaId': areaId,
      'updatedAt': updatedAt ?? _now,
    };

LiveSnapshot _snap(Map<String, dynamic> data, {bool fromCache = false}) => (doc: parseAlertDoc('E1', data), fromCache: fromCache);

Future<(AppStore, LiveAlerts, FakeBackend)> _live({bool fails = false}) async {
  final store = AppStore(scenarioId: '1', lang: Lang.en, platform: QuietPlatform());
  final backend = FakeBackend(fails: fails);
  final live = LiveAlerts(store, backend, realNow: () => _now)..start();
  await pumpEventQueue();
  return (store, live, backend);
}

int _tsunamis(AppStore store) => store.state.alerts.where((a) => a.type == HazardType.tsunami).length;

void main() {
  group('voice clips', () {
    test('uses the longest phrase, ending at a separator, and keeps the rest for TTS', () {
      final parts = _clips().split('Stay here. HIGH GROUND 12 m above forecast', Lang.en)!;
      expect(parts.map((p) => p.asset), ['assets/voice/en/a.mp3', 'assets/voice/en/b.mp3', null]);
      expect(parts.last.text, '12 m above forecast');
    });

    test('returns null when there is no clip', () {
      expect(_clips().split('12 m', Lang.en), isNull);
      expect(_clips().split('Stay here.', Lang.ja), isNull);
    });

    test('readings replace the longest word first', () {
      expect(applyReadings('高台公園へ。高台', Lang.ja), 'たかだいこうえんへ。たかだい');
      expect(applyReadings('高台', Lang.en), '高台');
    });
  });

  group('speech player', () {
    test('plays clips and TTS in order, then stops speaking', () async {
      final out = FakeOutput();
      final player = SpeechPlayer(out, _clips());
      expect(player.speak('Stay here. 12 m', Lang.en), isTrue);
      expect(player.speaking.value, isTrue);
      await pumpEventQueue();
      expect(out.log, ['clip:assets/voice/en/a.mp3', 'tts:12 m']);
      expect(player.speaking.value, isFalse);
    });

    test('a failed clip reads it and the rest with TTS', () async {
      final out = FakeOutput()..failing.add('assets/voice/en/a.mp3');
      SpeechPlayer(out, _clips()).speak('Stay here. HIGH GROUND', Lang.en);
      await pumpEventQueue();
      expect(out.log, ['clip:assets/voice/en/a.mp3', 'tts:Stay here HIGH GROUND']);
    });

    test('cancel stops the sequence', () async {
      final out = FakeOutput()..hold = Completer();
      final player = SpeechPlayer(out, _clips());
      player.speak('Stay here. 12 m', Lang.en);
      await pumpEventQueue();
      player.cancel();
      expect(player.speaking.value, isFalse);
      out.hold!.complete();
      await pumpEventQueue();
      expect(out.log, ['clip:assets/voice/en/a.mp3']);
    });

    test('an empty text is not spoken', () {
      expect(SpeechPlayer(FakeOutput(), _clips()).speak('', Lang.en), isFalse);
    });
  });

  group('live alerts', () {
    test('applies a bulletin once', () async {
      final (store, live, backend) = await _live();
      backend.controller.add(_snap(_doc()));
      expect(live.status, LiveStatus.live);
      expect(store.state.alerts.last.id, 'jma-E1');
      final applied = store.state.alerts;
      backend.controller.add(_snap(_doc()));
      expect(identical(store.state.alerts, applied), isTrue);
      live.dispose();
    });

    test('at start, ignores an alert older than 60 minutes', () async {
      final (store, live, backend) = await _live();
      final before = _tsunamis(store);
      backend.controller.add(_snap(_doc(updatedAt: _now - 61 * 60 * 1000)));
      expect(_tsunamis(store), before);
      expect(live.latest, isNull);
      live.dispose();
    });

    test('waits for the server view before the first bulletin', () async {
      final (_, live, backend) = await _live();
      backend.controller.add(_snap(_doc(), fromCache: true));
      expect(live.status, LiveStatus.cache);
      expect(live.latest, isNull);
      live.dispose();
    });

    test('off: nothing is received until it is on again', () async {
      final (_, live, backend) = await _live();
      live.setEnabled(false);
      expect(live.status, LiveStatus.off);
      expect(backend.controller.hasListener, isFalse);
      live.setEnabled(true);
      expect(backend.controller.hasListener, isTrue);
      live.dispose();
    });

    test('offline: applied when the demo comes back online', () async {
      final (store, live, backend) = await _live();
      store.patch(const StatePatch(online: false));
      backend.controller.add(_snap(_doc()));
      expect(live.latestApplied, isFalse);
      store.patch(const StatePatch(online: true));
      expect(live.latestApplied, isTrue);
      expect(store.state.alerts.last.id, 'jma-E1');
      live.dispose();
    });

    test('reset forgets the bulletin and does not apply it again', () async {
      final (store, live, backend) = await _live();
      backend.controller.add(_snap(_doc()));
      store.loadScenario('1');
      expect(live.latest, isNull);
      backend.controller.add(_snap(_doc()));
      expect(live.latest, isNull);
      live.dispose();
    });

    test('a cancellation only removes the alert of the same event', () {
      final store = AppStore(scenarioId: '1', lang: Lang.en, platform: QuietPlatform());
      store.patch(liveAlertPatch(store.state, parseAlertDoc('E1', _doc())!)!);
      final other = parseAlertDoc('E2', {..._doc(kind: 'cancelled', level: null), 'eventId': 'E2'})!;
      expect(liveAlertPatch(store.state, other), isNull);
      store.patch(liveAlertPatch(store.state, parseAlertDoc('E1', _doc(serial: 2, kind: 'cancelled', level: null))!)!);
      expect(_tsunamis(store), 0);
    });

    test('rejects a broken document', () {
      expect(parseAlertDoc('E1', {'kind': 'nope', 'serial': 1}), isNull);
      expect(parseAlertDoc('E1', _doc(kind: 'cleared')), isNull);
    });

    test('without Firebase: shows the error, and FCM is unavailable', () async {
      final (_, live, _) = await _live(fails: true);
      expect(live.status, LiveStatus.error);
      expect(live.error, contains('google-services'));
      expect(live.pushSupport, PushSupport.unavailable);
      live.dispose();
    });

    test('subscribes to the topic after the permission', () async {
      final (_, live, backend) = await _live();
      expect(backend.registered, 1);
      expect(live.pushState, PushState.enabled);
      live.dispose();
    });
  });

  group('notification text', () {
    test('warning, with the upgrade line and the height', () {
      final c = pushContent({'type': 'tsunami', 'kind': 'tsunami-warning', 'level': 'warning', 'change': 'upgrade', 'expectedHeight': '3', 'alertId': 'A'}, Lang.ja)!;
      expect(c.title, '【デモ】 津波警報');
      expect(c.body, '格上げ\n今すぐ高台へ\n予想される高さ: 3 m\nみなと湾（架空）');
      expect(c.tag, 'tasuku-A');
      expect(c.urgent, isTrue);
    });

    test('cleared has no height and no vibration channel', () {
      final c = pushContent({'type': 'tsunami', 'kind': 'cleared', 'expectedHeight': 'huge'}, Lang.en)!;
      expect(c.lifted, isTrue);
      expect(c.body, 'Stay alert. Check official updates.\nMinato Bay (fictional)');
    });

    test('ignores other messages', () {
      expect(pushContent({'type': 'other', 'kind': 'cleared'}, Lang.en), isNull);
      expect(pushContent({'type': 'tsunami', 'kind': 'x'}, Lang.en), isNull);
    });

    test('the notification id is stable and positive', () {
      expect(notificationId('tasuku-A'), notificationId('tasuku-A'));
      expect(notificationId('tasuku-A'), isNot(notificationId('tasuku-B')));
      expect(notificationId('tasuku-A'), greaterThanOrEqualTo(0));
    });
  });

  group('demo panel', () {
    Future<(AppStore, QuietPlatform)> pump(WidgetTester tester) async {
      final platform = QuietPlatform();
      final store = AppStore(scenarioId: '1', lang: Lang.en, platform: platform);
      final live = LiveAlerts(store, FakeBackend(fails: true));
      addTearDown(live.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AppScope(store: store, child: LiveScope(live: live, child: const DemoPanel()))),
      ));
      live.start();
      await tester.pumpAndSettle();
      return (store, platform);
    }

    testWidgets('shows the readout and the error status', (tester) async {
      await pump(tester);
      expect(find.text('エラー（デモパネルで操作）'), findsOneWidget);
      expect(find.text('シナリオ'), findsOneWidget);
    });

    testWidgets('reset reloads the scenario', (tester) async {
      final (store, _) = await pump(tester);
      final run = store.state.scenarioRun;
      await tester.ensureVisible(find.text('リセット'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('リセット'));
      expect(store.state.scenarioRun, run + 1);
    });

    testWidgets('the notification button shows S01 and notifies', (tester) async {
      final (store, platform) = await pump(tester);
      await tester.ensureVisible(find.text('通知'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('通知'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('通知を出す'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('通知を出す'));
      expect(store.state.lockScreen, isTrue);
      expect(platform.notified, ['Safe Japan: EARTHQUAKE']);
    });
  });
}
