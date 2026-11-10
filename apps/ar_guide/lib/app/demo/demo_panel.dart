// Demo control panel (requirements 9). Presenter-facing, Japanese labels.
// Port of mocks/evacuate/src/demo/DemoPanel.tsx. Shown in the sheet that components.dart opens.
import 'package:flutter/material.dart';

import '../data/alerts.dart';
import '../i18n/i18n.dart';
import '../live/live_alerts.dart';
import '../live/live_doc.dart';
import '../logic/margin.dart';
import '../screens/meta.dart';
import '../state/action_rules.dart';
import '../state/derive.dart';
import '../state/scenarios.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';

const List<AlertLevel> _levelOrder = [AlertLevel.advisory, AlertLevel.warning, AlertLevel.emergency];

const Map<ExpectedHeight, String> _heightLabels = {
  ExpectedHeight.m1: '1 m',
  ExpectedHeight.m3: '3 m',
  ExpectedHeight.m5: '5 m',
  ExpectedHeight.m10: '10 m',
  ExpectedHeight.over10: '10 m 超',
  ExpectedHeight.huge: '巨大（10 m 超として判定）',
  ExpectedHeight.high: '高い（3 m として判定）',
};

const Map<MarginLevel, String> _marginLabels = {
  MarginLevel.ample: '余裕あり',
  MarginLevel.low: '余裕が少ない（Go higher.）',
  MarginLevel.short: '足りない（Go higher. NOW）',
};

const Map<LiveStatus, String> _liveStatusLabels = {
  LiveStatus.off: 'OFF（デモパネルで操作）',
  LiveStatus.connecting: '接続中…',
  LiveStatus.live: '接続中（受信待ち）',
  LiveStatus.cache: '未接続（オフライン・キャッシュ）',
  LiveStatus.error: 'エラー（デモパネルで操作）',
};

const Map<RulesSource, String> _rulesSourceLabels = {
  RulesSource.remote: 'Remote Config',
  RulesSource.defaults: '既定値',
  RulesSource.cached: 'キャッシュ',
};

const Map<String, String> _liveKindLabels = {
  'major-tsunami-warning': '大津波警報',
  'tsunami-warning': '津波警報',
  'tsunami-advisory': '津波注意報',
  'cleared': '解除',
  'cancelled': '取消',
};

String _pushLabel(PushSupport support, PushState state) {
  if (support == PushSupport.checking) return '確認中…';
  if (support == PushSupport.unavailable) return '使えません（Firebase 未設定。google-services.json を置いてください）';
  return switch (state) {
    PushState.idle => '未設定',
    PushState.working => '設定中…',
    PushState.enabled => '受け取る（トピック登録済み）',
    PushState.denied => '拒否されています',
    PushState.error => 'エラー',
  };
}

String _clock(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String p(int v) => v.toString().padLeft(2, '0');
  return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
}

/// The value as the web prints it: 3, over10, huge ...
String _heightRaw(ExpectedHeight h) => h.name.startsWith('m') ? h.name.substring(1) : h.name;

String _number(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

const Color _accent = Color(0xFF2B5C9E);
const Color _danger = Color(0xFFB3261E);
const Color _muted = Color(0xFF5C5459);

class DemoPanel extends StatelessWidget {
  const DemoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.watch(context);
    final live = context.live;
    final s = store.state;
    void patch(StatePatch p) => store.patch(p);
    final nav = store.nav;
    final margin = store.margin;

    final screen = store.screen;
    final fresh = freshness(s);
    final prio = topPriorityAction(s, nav.inHazardZone);
    final tsunami = s.alerts.where((a) => a.type == HazardType.tsunami).firstOrNull;
    final hasEq = s.alerts.any((a) => a.type == HazardType.earthquake);
    final scenario = scenarios.where((x) => x.id == s.scenarioId).firstOrNull;
    final levelIdx = tsunami == null ? -1 : _levelOrder.indexOf(tsunami.level);
    List<Alert> withoutTsunami() => s.alerts.where((a) => a.type != HazardType.tsunami).toList();

    void setTsunami(AlertLevel? sel) => patch(StatePatch(
          alerts: sel == null ? withoutTsunami() : [...withoutTsunami(), withLevel(tsunami ?? alertTsunami, sel)],
        ));

    // A new bulletin replaces the tsunami alert. The store detects the change and shows the band.
    void replaceTsunami(AlertLevel level, ExpectedHeight height) => patch(StatePatch(alerts: [
          ...withoutTsunami(),
          (tsunami ?? alertTsunami).copyWith(level: level, expectedHeight: height, issuedAt: s.now),
        ]));

    void upgrade() {
      final level = _levelOrder[(levelIdx + 1).clamp(0, _levelOrder.length - 1)];
      replaceTsunami(level, maxHeight(tsunami?.expectedHeight, defaultHeight[level]) ?? defaultHeight[level]!);
    }

    void raise() {
      final h = raisedHeight(tsunami?.expectedHeight);
      if (tsunami != null && h != null) replaceTsunami(tsunami.level, h);
    }

    void downgrade() {
      if (levelIdx <= 0) return;
      final level = _levelOrder[levelIdx - 1];
      replaceTsunami(level, defaultHeight[level]!);
    }

    void setEq(bool on) {
      final rest = s.alerts.where((a) => a.type != HazardType.earthquake).toList();
      patch(StatePatch(alerts: on ? [alertEarthquake, ...rest] : rest));
    }

    void fireNotification() {
      patch(const StatePatch(lockScreen: true));
      final (title, body) = _quakeNotification[s.lang]!;
      store.platform.notify(title, body);
    }

    final latest = live.latest;
    final receivedAt = live.receivedAt;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _accent), visualDensity: VisualDensity.compact),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Readout(rows: [
                ('モード', deriveMode(s, nav.inHazardZone).name),
                ('画面', '${screen.label} ${screenMeta[screen]!.name}'),
                ('仮想時刻', '${formatJst(s.now)} JST'),
                (
                  '鮮度',
                  '${fresh.stale ? 'Stale' : 'Fresh'}（${fresh.ageMin.toStringAsFixed(0)} 分前${s.online ? '' : '・オフライン'}${s.online && s.feedPaused ? '・更新停止中' : ''}）'
                ),
                ('最優先行動', '${prio.rank}: ${prio.kind.name}'),
                (
                  '余裕の判定',
                  '${margin.level == null ? '—' : _marginLabels[margin.level]}${margin.marginM == null ? '' : '（差 ${margin.marginM!.toStringAsFixed(1)} m）'}${margin.designated == null ? '' : '・指定避難場所'}'
                ),
                ('行動ルール', '${store.rules.rulesVersion}（${_rulesSourceLabels[store.rules.source]}）'),
              ]),
              _Section(title: 'シナリオ', open: true, children: [
                for (final sc in scenarios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                        backgroundColor: sc.id == s.scenarioId ? const Color(0x222B5C9E) : null,
                      ),
                      onPressed: () => store.loadScenario(sc.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sc.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(sc.description, style: const TextStyle(fontSize: 11, color: _muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                _Hint('選択中: ${scenario?.label ?? ''}'),
                _Buttons([_Btn('リセット', () => store.loadScenario(s.scenarioId), danger: true)]),
              ]),
              _Section(title: 'Live alerts（Firestore）', open: true, children: [
                _Check('Firestore の警報を反映する', live.enabled, live.setEnabled),
                _Readout(rows: [
                  ('接続', '${_liveStatusLabels[live.status]}${live.enabled && !s.online ? '・デモはオフライン（戻ると反映）' : ''}'),
                  if (live.error != null) ('エラー', live.error!),
                  (
                    '受信',
                    latest != null && receivedAt != null
                        ? '${_clock(receivedAt)} ${_liveKindLabels[latest.kind] ?? latest.kind}${latest.expectedHeight == null ? '' : ' ${_heightRaw(latest.expectedHeight!)}'}（Serial ${latest.serial}・${latest.infoType}・${latest.change}）${live.latestApplied ? '' : '・未反映'}'
                        : 'なし'
                  ),
                  if (latest != null && (latest.arrivalTime != null || latest.arrivalCondition != null))
                    ('到達予想', hhmm(latest.arrivalTime) ?? latest.arrivalCondition ?? ''),
                ]),
                const _Hint(
                    'services/alert-ingest が書いた alerts/{EventID}（みなと湾）の最新の電文を、下の「災害」の操作と同じ形で反映します（同じ EventID・Serial は 1 回だけ）。OFF・エラー・オフラインの間は、これまでどおりデモパネルで操作できます。リセットで受信した状態も消えます。'),
              ]),
              _Section(title: '通知', children: [
                _Buttons([
                  _Btn('通知を出す', fireNotification),
                  _Btn(
                    '通知を受け取る',
                    live.pushSupport != PushSupport.supported || live.pushState == PushState.working ? null : live.enablePush,
                  ),
                ]),
                _Hint(
                    'FCM: ${_pushLabel(live.pushSupport, live.pushState)}${live.pushError == null ? '' : '（${live.pushError}）'}${live.lastPushAt == null ? '' : '・前面で受信 ${_clock(live.lastPushAt!)}（表示はしない）'}'),
                const _Hint('「通知を出す」は S01 を表示し、端末の通知も出します（許可済みの場合のみ）。「通知を受け取る」は通知を許可して FCM のトピックに登録し、アプリを閉じているときに警報を通知します。'),
              ]),
              _Section(title: '災害', children: [
                _Check('揺れ', s.shaking, (v) => patch(StatePatch(shaking: v))),
                const _Hint('津波警報レベル'),
                _Seg<AlertLevel?>(
                  value: tsunami?.level,
                  onChanged: setTsunami,
                  options: const [
                    (null, 'なし'),
                    (AlertLevel.advisory, '注意報'),
                    (AlertLevel.warning, '警報'),
                    (AlertLevel.emergency, '大津波'),
                  ],
                ),
                _Select<ExpectedHeight>(
                  label: '予想される高さ',
                  value: tsunami?.expectedHeight,
                  disabledHint: '（津波の警報なし）',
                  options: _heightLabels.entries.map((e) => (e.key, e.value)).toList(),
                  onChanged: tsunami == null ? null : (h) => replaceTsunami(tsunami.level, h),
                ),
                const _Hint('警報の変化（帯で知らせる。格上げ・引き上げは再通知と判定のやり直し）'),
                _Buttons([
                  _Btn('格上げする', levelIdx >= _levelOrder.length - 1 ? null : upgrade),
                  _Btn('高さを引き上げる', tsunami == null || raisedHeight(tsunami.expectedHeight) == null ? null : raise),
                  _Btn('格下げする', levelIdx <= 0 ? null : downgrade),
                  _Btn('解除する', s.alerts.isEmpty ? null : () => patch(const StatePatch(alerts: [])), danger: true),
                ]),
                _Range('余裕ありとする差', s.marginAmpleM, 0, 30, ' m', (v) => patch(StatePatch(marginAmpleM: v))),
                _Range('10 m 超のとき必要な標高', s.hugeMinElevM, 0, 40, ' m', (v) => patch(StatePatch(hugeMinElevM: v))),
                _Hint(
                    '現在地の標高 ${margin.elevMinM != null ? '${margin.elevMinM!.toStringAsFixed(1)} m' : '不明'}${margin.approximate && margin.elevMaxM != null ? '〜${margin.elevMaxM!.toStringAsFixed(1)} m（誤差円内）' : ''} / 判定に使う高さ ${margin.heightInUse == null ? 'なし' : _heightRaw(margin.heightInUse!)}（格下げしても最大値を使う）'),
                _Check('地震の警報', hasEq, setEq),
                _Select<EqSituation>(
                  label: '地震時の状況',
                  value: s.eqSituation,
                  options: const [(EqSituation.indoors, 'INDOORS'), (EqSituation.outdoors, 'OUTDOORS'), (EqSituation.car, 'IN CAR')],
                  onChanged: (v) => patch(StatePatch(eqSituation: v)),
                ),
              ]),
              _Section(title: '通信', children: [
                // Going back online resumes updates (clears feedPaused).
                _Check('オンライン', s.online, (v) => patch(v ? const StatePatch(online: true, feedPaused: false) : const StatePatch(online: false))),
                _Check('更新を止める（取得失敗）', s.feedPaused, (v) => patch(StatePatch(feedPaused: v))),
                _Range('鮮度しきい値', s.staleThresholdMin, 1, 30, '分', (v) => patch(StatePatch(staleThresholdMin: v))),
                _Buttons([
                  _Btn('最終取得を 15 分前にする', () => patch(StatePatch(lastFetchAt: s.now - 15 * minuteMs, feedPaused: true))),
                  _Btn('時計 +5 分', () => patch(StatePatch(now: s.now + 5 * minuteMs))),
                ]),
                const _Hint('オンライン中は毎分自動で取得します。「更新を止める」かオフラインの間だけ最終取得時刻が止まり、しきい値を超えると Stale になります。'),
              ]),
              _Section(title: '位置', children: [
                _Select<GpsPermission>(
                  label: '位置情報の許可',
                  value: s.gps.permission,
                  options: const [(GpsPermission.granted, '許可'), (GpsPermission.denied, '拒否'), (GpsPermission.prompt, '未確認')],
                  onChanged: (v) => patch(StatePatch(gps: GpsPatch(permission: v))),
                ),
                _Range('GPS 精度 ±', s.gps.accuracyM, 10, 300, ' m', (v) => patch(StatePatch(gps: GpsPatch(accuracyM: v))), step: 5),
                _Buttons([
                  _Btn('手動ピンを解除${s.manualPin != null ? '' : '（なし）'}', s.manualPin == null ? null : () => patch(const StatePatch(clearManualPin: true))),
                ]),
              ]),
              _Section(title: '歩行', children: [
                _Buttons([
                  _Btn(s.walk.playing ? '一時停止' : '再生', () => patch(StatePatch(walk: WalkPatch(playing: !s.walk.playing))), on: s.walk.playing),
                  _Btn('進捗リセット', () => patch(const StatePatch(walk: WalkPatch(progressM: 0, playing: false)))),
                  _Btn('高台フラグ解除', () => patch(const StatePatch(onHighGround: false))),
                ]),
                _Seg<double>(
                  value: s.walk.speed,
                  onChanged: (v) => patch(StatePatch(walk: WalkPatch(speed: v))),
                  options: const [(1, '×1'), (2, '×2'), (4, '×4')],
                ),
                _Hint('進捗 ${s.walk.progressM.toStringAsFixed(0)} m / 高台: ${s.onHighGround ? 'はい' : 'いいえ'}'),
              ]),
              _Section(title: '画面', children: [
                _Check('画面オフ', s.screenOff, (v) => patch(StatePatch(screenOff: v))),
                _Check('端末を持ち上げる', s.deviceRaised, (v) => patch(StatePatch(deviceRaised: v))),
                _Check('画面が切り替わったら読み上げる', s.autoSpeak, (v) => patch(StatePatch(autoSpeak: v))),
              ]),
              _Section(title: 'AR', children: [
                _Check('カメラ権限', s.ar.cameraPermission, (v) => patch(StatePatch(ar: ArPatch(cameraPermission: v)))),
                _Check('対応端末', s.ar.supported, (v) => patch(StatePatch(ar: ArPatch(supported: v)))),
                _Range('方位精度 ±', s.ar.headingAccuracyDeg, 0, 45, '°', (v) => patch(StatePatch(ar: ArPatch(headingAccuracyDeg: v)))),
                _Check('追跡中', s.ar.tracking, (v) => patch(StatePatch(ar: ArPatch(tracking: v)))),
                _Check('目印を認識', s.ar.landmarkFound, (v) => patch(StatePatch(ar: ArPatch(landmarkFound: v)))),
                _Check('認識枠を表示', s.ar.showDetection, (v) => patch(StatePatch(ar: ArPatch(showDetection: v)))),
              ]),
              _Section(title: '通報', children: [
                _Check('発信を有効にする', s.dialerEnabled, (v) => patch(StatePatch(dialerEnabled: v))),
                const Text('注意: 有効にすると 110 / 119 のボタンで実際にダイヤラーが開きます。', style: TextStyle(color: _danger, fontSize: 12)),
              ]),
              _Section(title: '言語', children: [
                _Select<Lang>(
                  label: '表示言語',
                  value: s.lang,
                  options: [for (final l in langs) (l, langNativeNames[l]!)],
                  onChanged: (v) => patch(StatePatch(lang: v)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Demo "send notification": an earthquake alert in the app's language (title, body).
const Map<Lang, (String, String)> _quakeNotification = {
  Lang.en: ('Safe Japan: EARTHQUAKE', 'Drop, cover, and hold on until the shaking stops.'),
  Lang.ja: ('Safe Japan: 地震', '身を守ってください。頭を守り、揺れが収まるまで動かないでください。'),
  Lang.zhHans: ('Safe Japan：地震', '请保护好自己。护住头部，摇晃停止前不要移动。'),
  Lang.ko: ('Safe Japan: 지진', '몸을 보호하세요. 머리를 보호하고 흔들림이 멈출 때까지 움직이지 마세요.'),
  Lang.ar: ('Safe Japan: زلزال', 'احمِ نفسك. احمِ رأسك ولا تتحرك حتى يتوقف الاهتزاز.'),
};

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.open = false});

  final String title;
  final bool open;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        initiallyExpanded: open,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
}

class _Readout extends StatelessWidget {
  const _Readout({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 84, child: Text(k, style: const TextStyle(color: _muted, fontSize: 12))),
                    Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: const TextStyle(color: _muted, fontSize: 11)),
      );
}

class _Check extends StatelessWidget {
  const _Check(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          Switch(value: value, onChanged: onChanged),
        ],
      );
}

class _Range extends StatelessWidget {
  const _Range(this.label, this.value, this.min, this.max, this.unit, this.onChanged, {this.step = 1});

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${_number(value)}$unit'),
          Slider(value: value.clamp(min, max), min: min, max: max, divisions: ((max - min) / step).round(), onChanged: onChanged),
        ],
      );
}

class _Btn {
  const _Btn(this.label, this.onTap, {this.danger = false, this.on = false});

  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool on;
}

class _Buttons extends StatelessWidget {
  const _Buttons(this.buttons);

  final List<_Btn> buttons;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final b in buttons)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: b.danger ? _danger : null,
                backgroundColor: b.on ? const Color(0x222B5C9E) : null,
              ),
              onPressed: b.onTap,
              child: Text(b.label),
            ),
        ],
      );
}

class _Seg<T> extends StatelessWidget {
  const _Seg({required this.value, required this.options, required this.onChanged, super.key});

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        children: [
          for (final (id, label) in options)
            ChoiceChip(label: Text(label), selected: id == value, onSelected: (_) => onChanged(id)),
        ],
      );
}

class _Select<T> extends StatelessWidget {
  const _Select({required this.label, required this.value, required this.options, required this.onChanged, this.disabledHint});

  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            disabledHint: disabledHint == null ? null : Text(disabledHint!),
            items: [for (final (id, text) in options) DropdownMenuItem(value: id, child: Text(text, overflow: TextOverflow.ellipsis))],
            onChanged: change == null ? null : (v) => v == null ? null : change(v),
          ),
        ),
      ],
    );
  }
}
