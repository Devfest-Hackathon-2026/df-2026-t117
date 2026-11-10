# ar_guide — TASUKU アプリ（Flutter）

TASUKU の提出物の本体の Android アプリ。Web のモック `mocks/evacuate/` の全画面（S01〜S12・H00・A01〜A04）・デモ操作パネル・シナリオ・音声・Firestore / FCM を移した（PR #18〜#20）。起動すると `lib/app/` のアプリが開き、`tasuku-ar://guide` のディープリンクで開いたときだけ、従来の AR 画面に直接入る。AR 画面そのものの説明は、この節の後ろの「ar_guide — AR 案内アプリ（H4）」以降。

## アプリの土台（`lib/app/`）

| 場所 | 中身 | Web の対応 |
|---|---|---|
| `state/` | `AppState`・`StatePatch`・`derive`・シナリオ・時刻・`AppStore` | `src/state/` |
| `logic/` | 距離計算・高さ・余裕の判定・ルート・案内、効果（`NavEffects`・`AlertEffects`・`AppEffects`） | `src/logic/` |
| `data/` | 架空の町・警報・目印・コラム | `src/data/` |
| `i18n/` | 言語判定・`fmt`・`bilingual`・共通文言 | `src/i18n/` |
| `theme.dart`・`components.dart` | デザイントークンと共通部品 | `styles/tokens.css`・`src/components/` |
| `screens/` | 画面（`S01`〜`S12`・`H00`・`A01`〜`A04` に各 1 ファイル）、`registry.dart`、`meta.dart` | `src/screens/` |
| `demo/demo_panel.dart` | デモ操作（全項目）。右端のつまみから開くボトムシート | `src/demo/DemoPanel.tsx` |
| `platform/` | 音声（`speech.dart`・`voice_clips.dart`・`readings.dart`）、通知（`notifications.dart`）、`DeviceAppPlatform` | `src/platform/` |
| `live/` | Firestore の購読と FCM（`live_alerts.dart`・`live_doc.dart`・`live_backend.dart`）、通知の文面（`push_text.dart`） | `src/live/`・`public/firebase-messaging-sw.js` |
| `app_shell.dart` | `state` から画面を出す | `App.tsx` |

### 画面の足し方

画面ごとのファイルはすでにある。**`lib/app/screens/s03.dart` の中身を書き換えるだけ**でよく、`registry.dart` は変更しない（並行して作業しても衝突しない）。クラス名（`S03Screen`）は変えない。ファイル名は Dart の規約に合わせて小文字。

```dart
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';

const Dict _dict = {
  Lang.en: {'go': 'Go uphill'},
  Lang.ja: {'go': '高台へ'},
  // zhHans, ko, ar も
};

class S03Screen extends StatelessWidget {
  const S03Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState; // 変わると再描画される
    final nav = context.nav; // Web の useNavigation()
    final c = context.common; // 共通文言（Web の useCommon()）
    final t = context.t(_dict); // 画面の文言（Web の useT(dict)）
    return GuidanceLayout(
      headline: t['go'],
      actions: BigButton(
        label: c.onHighGround,
        onTap: () => context.store.patch(const StatePatch(onHighGround: true)),
      ),
      listen: ListenButton(text: t['go']),
      footer: FooterMeta(items: [c.jma, state.online ? null : c.stale]),
    );
  }
}
```

- 操作は `context.store` の `patch` / `loadScenario` / `navigate` / `back` / `tick` / `showToast`（Web の action と同じ粒度）。ボタンの `onTap` の中では `context.store` だけを使う（`context.appState` などは `build` の中だけ）
- `StatePatch` で `null` にしたい項目は `clearManualPin: true` のようにフラグで指定する
- 画面を開いた直後に状態を変えるときは `initState` から直接呼ばず、`WidgetsBinding.instance.addPostFrameCallback` を使う（描画中の通知になるため）
- 右から左の言語に対応するため、余白と配置は `EdgeInsetsDirectional`・`AlignmentDirectional` を使う
- 余裕の判定は `context.margin`（Web の `useMargin()`）
- 誘導画面の共通部品は `screens/_shared.dart`: `AlertBand`、`MarginCard`・`marginText()`、`heightLabel()`、`GuideFooter`、`AnnounceOnEnter`（Web の `useAnnounceOnEnter`）、`AnnounceFlash`、`TurnArrow`、`directionLabel()`・`metersLabel()`・`tsunamiBadge()`、`guideT(context)`（`goHigher`・`followSigns`・`setLocation`）
- 地図は `TownMap`（`variant`・`routeColor`・`showAccuracy`・`pinEditable` などは Web と同じ。`pin` を親が持つときは `controlledPin: true`。親いっぱいに広げるときは `fill: true`）、絵は `Pictogram(PictogramKind.goUphill)`。どちらも `_shared.dart` を import すると使える

### 文言の移し方

- 共通文言は `i18n/common_strings.dart`（Web から機械的に写した）。`context.common.listen` のように型付きで使う
- 各画面の辞書は画面のファイルに置く。Web の `{ en: { a: 'x' }, ... }` を、言語のキーを `Lang.en` / `Lang.ja` / `Lang.zhHans` / `Lang.ko` / `Lang.ar` に、中のキーを文字列にして写す
- RTL は `PhoneFrame` が `Directionality` で設定する（アラビア語のとき右から左）。時刻と `DEMO` は左から右のまま

### Web と変えた点

| 項目 | Flutter | 理由 |
|---|---|---|
| 名前 | 定数は `lowerCamelCase`、`ScreenId.s01`、`Route` → `EvacRoute`、`Badge` → `TkBadge` | Dart の規約、Flutter の同名クラスとの衝突 |
| `ExpectedHeight` | enum（`m1`, `m3`, `m5`, `m10`, `over10`, `huge`, `high`） | Web の数値と文字列の合併型の代わり |
| Web の `use〜()` 関数 | `useNavigation()` → `context.nav`、`useMargin()` → `context.margin`。効果は `AppEffects` が状態の変化ごとに実行 | Flutter に同じ仕組みがない |
| 通知の許可 | 起動時に求める（H00 やデモパネルのボタンからも可） | Web と違いユーザー操作の中で呼ぶ必要がない |
| 通知の言語 | アプリの現在の言語 | Service Worker は端末の言語だが、アプリは言語を選べる |
| 端末の傾き → `deviceRaised`（F36） | タップでの許可なしで、S04 / S11 / S12 を表示中かつ AR に入れるときだけ聞く（`logic/device_raise.dart`、Android 側の `TiltStream`）。前後の傾き 60° 以上で持ち上げ、30° 未満で下ろした（Web は 45° 未満。実機で床の矢印を見るときに地図へ戻らないよう下げた）。加えて 300 ms 続いたときだけ切り替える | Android ではこのセンサーに許可が要らない。手ぶれで S04 と S11 を行き来しないため |

フォントは Noto の可変フォントを `assets/fonts/` に同梱している（`docs/third-party.md` 3.1）。

Web の `useLiveAlerts()` は `context.live`（`live/live_alerts.dart`。H00 の通知ボタンは `context.live.enablePush`）。

### 音声

`assets/voice/` は `mocks/evacuate/public/voice/`（`manifest.json` と MP3）のコピー。音声を作り直したら、このフォルダーへコピーし直す。

クリップのある部分は音声の再生で MP3 を、数字などは端末の読み上げ機能で順に読む（規則は Web の `speech.ts`・`voiceClips.ts`・`readings.ts` と同じ）。

### Firebase（`google-services.json`）

`apps/ar_guide/android/app/google-services.json` に置く（Git には入れない）。**ファイルがなくてもビルドと起動ができる**（Android のビルド設定で、google-services プラグインはファイルがあるときだけ適用する）。その場合、デモパネルの Live alerts は「エラー」、FCM は「使えません」になり、他の動作は止まらない。

- Firestore: `alerts` を購読して store に反映（同じ電文は 1 回、起動時は 60 分以内のものだけ、ON/OFF、リセット）
- FCM: トピック `demo-minato-bay` を購読。アプリが閉じているときのデータメッセージは `firebaseBackgroundHandler` と通知のプラグインで 5 言語の通知にする。前面では表示しない（Firestore で画面が更新される）

ファイルを置いたあとの確認手順（Android 16 の実機で 11/09〜11/10 に、起動・`send-sample.sh --scenario` の電文の受け付け（HTTP 200）・バックグラウンドでの FCM の通知の受信までを確認済み）:

1. `fvm flutter build apk --debug` でビルドし、インストールする。Firebase の Android アプリのパッケージ名は `jp.tasuku.ar_guide`
2. 起動すると通知の許可のダイアログが出る → 許可する
3. デモパネルの「Live alerts」が「接続中（受信待ち）」、「通知」が「受け取る（トピック登録済み）」になること
4. `alerts` にデモの電文が入ると、受信欄に出て画面の警報が変わること。同じ電文では 1 回だけ変わること
5. アプリを閉じて（ホームに戻すだけでなくタスクからも消して）電文を送る → 通知が出て振動すること。押すとアプリが開くこと
6. 端末の音量を上げて「Listen」→ クリップと TTS が順に読まれること。「Stop」や画面の切り替えで止まること
7. 言語を変えてアプリを閉じ、開き直す → 言語が残っていること

---

## ar_guide — AR 案内アプリ（H4）

`mocks/evacuate/docs/architecture.md` 10 節の H4。最初は AR 画面（S11）だけを持つアプリとして作り、Web のモックの S11 からディープリンクで開いていた。現在はアプリ内の S11（`lib/app/screens/s11.dart`）がこの画面を使い、ディープリンクでも引き続き開ける。カメラ映像に曲がり矢印を重ねる。要件は `requirements.md` 6.4.1 節（F37〜F3C）。

> **DEMO**: 表示する経路・距離・目的地はデモの値。画面に常に `DEMO` バッジを出す。

## 前提にした端末

- デモ端末は **Android 16（API 36）の実機**。`compileSdk` / `targetSdk` は 36
- デモ端末は **ARCore の対応端末リストに載っていない**（[developers.google.com/ar/devices](https://developers.google.com/ar/devices)）。そのため、**ARCore なしで動く「コンパス方式」を主にした**。ARCore は対応端末でだけ使う任意の上乗せ
- Android 以外の OS 向けのビルドは今回は対象外。他社 OS のスマートフォンでは H5（Web の AR の代わり、モックの S11）を使う

## 2 つの方式

| 方式 | 使う端末 | 仕組み |
|---|---|---|
| コンパス（既定） | ARCore 非対応・未インストールの端末（デモ端末など） | `camera` プラグインのプレビューに、矢印を遠近で描いて重ねる。矢印は「曲がり角の方位（`bearing`）− 端末の向き（コンパス）」だけ回す。端末の傾き（加速度）から、床に貼ったように見える遠近をつける |
| ARCore（任意） | ARCore 対応で、ARCore がインストール済みの端末 | ARCore の平面検出で床を見つけ、床に矢印を固定する（Geospatial / VPS は使わないので屋内でも動く）。向きはコンパスの差で合わせる。ARCore が失敗したら自動でコンパス方式に切り替える |

- ARCore が未インストールでも、インストールは促さない（デモの流れを止めないため）。そのままコンパス方式で動く
- ディープリンクの `mode=compass` で、ARCore 対応端末でもコンパス方式を試せる

### 矢印を出さないとき（`AR paused`、モックの S12 相当）

| 状況 | 表示 | 要件 |
|---|---|---|
| カメラ権限が拒否された | `Check location` / `Camera access is off` ＋「カメラを許可」（「今後表示しない」なら「設定を開く」） | F3C |
| 方位センサーの精度が UNRELIABLE のまま 1 秒以上続いた（キャリブレーションが必要） | `Calibrate compass` ＋ 8 の字に振るアニメーション | F3B |
| 方位センサー（磁気センサー）がない | `Check location` / `This phone has no compass sensor` | F3C |
| カメラが使えない | `Check location` / `The camera is not available` | F3C |
| ARCore 方式で、床が見つからない／追跡が外れた | `Check location` ＋ 理由（床に向ける・暗い・速すぎるなど） | F3B |

方位の精度は、Android の磁気センサーの accuracy（`SensorManager.SENSOR_STATUS_*`）で判断する。

- UNRELIABLE（0）が **1 秒以上続いたら**止める（一瞬の低下では止めない）。0 以外に戻ればすぐ再開する
- LOW（1）では止めない。LOW のままの端末もあるので、矢印は出したまま、カードの下に小さく `Compass accuracy low`（`方位の精度低`）を出す

画面は案内中ずっとオンのまま（`FLAG_KEEP_SCREEN_ON`、コンパス方式・ARCore 方式の両方）。センサーはアプリがバックグラウンドのあいだ止める。

## 実装方式と選んだ理由

- **コンパス方式**
  - カメラ: [`camera`](https://pub.dev/packages/camera) 0.12（flutter.dev 公式、2026-10 更新、Android は CameraX）
  - 方位と傾き: **Android のネイティブコードで自作**（`OrientationStream`、EventChannel）。`TYPE_ROTATION_VECTOR` を使い、ない端末では加速度＋磁気センサーで計算する。既存の Flutter 用の方位センサーのプラグインは、更新が止まっているか、磁気センサーの精度（accuracy）を返さないので、キャリブレーションの判定（F3B）に使えない
  - 矢印: Flutter の `CustomPainter` で、床の上の矢印をピンホールカメラのモデルで投影して描く（`floor_arrow.dart`）
- **ARCore 方式**
  - **ARCore SDK（`com.google.ar:core:1.57.0`）を Android のネイティブコードから直接使い、端末の 3D 描画 API で描く**（`android/.../ar/`）。Platform View（Hybrid composition）と MethodChannel で Flutter につなぐ
  - 既存の Flutter 用の AR プラグインは使わなかった: どれも 2022〜2023 年から更新がなく、開発が終わった Sceneform に依存していて、Flutter 3.47 の最新のビルド環境でビルドできる保証がない
  - Sceneform の後継の 3D ライブラリも使わなかった: 描くのは床に貼る平らな矢印 1 つだけなので、カメラ背景と三角形を描くコード（約 400 行）で足りる。依存を ARCore SDK だけにでき、外部ライブラリの大きな API 変更の影響も受けない

## ディープリンク

```
tasuku-ar://guide?turn=right&dist=12&dest=Hill%20Park&lang=en&bearing=80
```

| 引数 | 値 | 既定値（引数なし・不正な値） |
|---|---|---|
| `turn` | `left` / `right` / `straight` | `right` |
| `dist` | 次の曲がり角までの距離（m、0〜9999 に丸める） | `12` |
| `dest` | 目的地名（最大 40 文字。制御文字・双方向制御文字は取り除く） | `Hill Park` |
| `dest_ja` | 目的地の日本語名（`Hill Park / 高台公園` の後半） | `dest` が `Hill Park` なら `高台公園` |
| `lang` | `en` / `ja` / `zh-Hans`（`zh` も可） / `ko` / `ar` | `en` |
| `bearing` | 曲がり角へ向かう方位（度。0 = 北、時計回り）。端末の向きは磁北基準で、真北への補正はしない（モックの地図は架空のため） | なし: 起動時に端末が向いている方向を経路の向きとみなす（デモ用） |
| `mode` | `auto` / `compass` / `arcore` | `auto`（ARCore が使えれば ARCore、だめならコンパス） |

リンクはどのアプリや Web ページからでも送れるので、すべての値を検証し、範囲外は丸めるか既定値にする。アプリを開いたまま別のリンクを受けると、その値に切り替わる（`singleTop`）。

## ビルド

Flutter は FVM で管理している（`.fvmrc` = `stable`、3.47.4）。

```powershell
cd apps/ar_guide
fvm use stable
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk
```

- `android/app/build.gradle.kts` の `ndkVersion` は、開発機に入っている `27.0.12077973` にしている（Flutter 3.47 の既定は 28.2）。このアプリと使っているプラグインにはネイティブコード（C/C++）がないので、ビルド時に出る「NDK のバージョンが違う」という警告は無視してよい。NDK 28.2 を入れた環境なら、その行を消して既定値に戻してよい
- Android のビルドツールのバージョンは、Flutter 3.47 の `flutter create` の既定のまま

## 実機へのインストール

adb は PATH にないので、Android SDK のパスで呼ぶ（開発用 PC のシェルの例）。

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices                        # 端末が "device" と出ること（USB デバッグを ON にしておく）
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

`fvm flutter run` でもよい（ホットリロードが使える）。

## ディープリンクのテスト

```powershell
& $adb shell am start -W -a android.intent.action.VIEW -d "tasuku-ar://guide?turn=left&dist=30"
& $adb shell am start -W -a android.intent.action.VIEW -d "tasuku-ar://guide?turn=right&dist=12&dest=Hill%20Park&lang=ja&bearing=80"
& $adb shell am start -W -a android.intent.action.VIEW -d "tasuku-ar://guide?turn=straight&dist=40&lang=ar&mode=compass"
```

bash から送るときは（パスの自動変換を止めるため）`MSYS_NO_PATHCONV=1` を付け、`&` を含む URL を引用符で囲む。`am start` に渡す URL の `&` は、端末側のシェルで解釈されないよう、全体を `'...'` で囲む必要がある場合がある（`adb shell "am start ... -d 'tasuku-ar://guide?turn=left&dist=30'"`）。

Web のモックからは `<a href="tasuku-ar://guide?...">` や `location.href = 'tasuku-ar://guide?...'` で開ける（Chrome はユーザー操作から開く必要がある）。

## 実機での確認手順（未確認。Android 16 の実機で行う）

1. インストールして起動 → カメラ権限のダイアログが出る。**拒否** → `AR paused` / `Camera access is off` と「カメラを許可」が出て、矢印が出ないこと
2. 「カメラを許可」→ 許可 → カメラ映像が全画面で出て、ヘッダー（`AR guidance`、`DEMO`、`Compass`）、`TSUNAMI WARNING`、`Right 12 m`、下部の `MAP`（`Hill Park / 高台公園`）が、ステータスバー・ナビゲーションバーと重ならないこと（edge-to-edge）。`MAP` シートは畳んだ状態で始まり、上下のドラッグ（またはつまみのタップ）で広がる・畳まれること。広げた地図の青い現在地マーカーが、端末を回すと向きを変えること。模式図の上は次の区間の `bearing` なので、カメラの矢印が正面を指すとき、マーカーは経路の上向きを指すこと。矢印が路面に貼り付いて手前から奥へ細くなり、シートを広げても根元がシートのすぐ上に見えること
3. 端末を床に向ける → 黄色い曲がり矢印が床に貼ったように見えること。端末を起こすと遠近が変わること
4. その場で体の向きを変える → 矢印が実際の方位を指したまま回ること（`bearing` を付けたリンクで確かめる。このアプリの方位は**磁北基準**で、日本では真北と 7〜8° ずれる。方位磁石アプリと比べるときは、そのアプリを磁北表示にする）
5. 磁石や金属の近くで精度を落とす → UNRELIABLE が 1 秒続くと `Calibrate compass` と 8 の字の案内が出て、矢印が消えること。8 の字に振ると戻ること。精度が LOW のときは矢印が出たまま `Compass accuracy low` が出ること
6. 案内を表示したまま放置 → 画面が暗くならないこと
7. カメラの起動中（起動直後）にホームボタンでバックグラウンドへ → 戻るとプレビューが動いていること
8. 上の「ディープリンクのテスト」の 3 本 → 方向・距離・言語（日本語・アラビア語の右から左の表示）が切り替わること。壊れたリンク（`dest=%E0%A4`）ではデモの値（`Right 12 m`）に戻ること
9. ヘッダーの戻るボタン → アプリが閉じ、前のアプリ（ブラウザのモック）に戻ること
10. （ARCore 対応端末があれば）`mode=auto` で `ARCore` 方式になり、床を検出すると矢印が床に固定されること。カメラを手で覆うと `AR paused` になること

## ファイル

| パス | 内容 |
|---|---|
| `lib/main.dart` | アプリ本体。ディープリンクの受け取り |
| `lib/src/guide_screen.dart` | S11（と S12 相当の停止表示）。方式の選択、カメラ、方位、停止の判定 |
| `lib/src/floor_arrow.dart` | コンパス方式の矢印（遠近で描く） |
| `lib/src/arcore_view.dart` | ARCore 方式の Platform View |
| `lib/src/widgets.dart` | ヘッダー、バッジ、カード、`MAP` シート、停止表示、8 の字の案内 |
| `lib/src/guide_params.dart` | ディープリンクの解釈と検証 |
| `lib/src/strings.dart` | 5 言語の文言（モックと同じ言い回し。新しい文言はデモ用の翻訳） |
| `android/.../MainActivity` | チャンネル、カメラ権限、ARCore の有無の確認 |
| `android/.../OrientationStream` | 方位・傾き・磁気センサーの精度 |
| `android/.../TiltStream` | 傾きだけ（重力センサー。「持ち上げたら AR」の判定用。S11 の方位と同時に動く） |
| `android/.../ar/` | ARCore セッションと 3D の描画 |

## 既知の制限

- コンパス方式は路面を検出していない。「端末の下方向にある平面を路面とみなし」、持つ高さ 1.4 m を仮定して端末の傾きから遠近を計算した見た目である。矢印が実際の道の形に沿うわけではない（段差・坂・障害物も考慮しない）
- 端末の向き（heading）は「カメラの向き＋端末の上端の向き」を足して求めているので、端末を水平より上（空のほう）へ 45° 以上向けると不安定になる（床に向けて使う前提）
- `ndkVersion` を開発機の `27.0.12077973` に固定している。NDK 28.2 のある環境では、その行を消して Flutter の既定値に戻してよい
- 方位は磁北基準。`bearing`（真北基準）との差の 7〜8°（日本）は補正していない

## 今後

- 地図（`MAP` シート）は模式図。モックの `TownMap` と同じ地図・現在地にするには、ルートの座標をリンクで渡す必要がある
- 音声の読み上げ（モックのスピーカーボタン）は入れていない（H6 の音声ファイルを使う想定）
- 目印の照合（F39）は入れていない
- 方位の精度の判定（UNRELIABLE が 1 秒続いたら止める）は、実機で様子を見て調整する
