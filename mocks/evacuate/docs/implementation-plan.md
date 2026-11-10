# TASUKU モック 実装計画

[requirements.md](requirements.md) を実装するための、開発エージェント向けの共通ルールと分担。

## 1. 体制

| 役割 | 担当 |
|---|---|
| 分割・依頼・監視（危険な操作がないかの確認） | オーケストレーター（Opus 5.5） |
| 重いタスクの開発 | 開発エージェント（Opus 5.5） |
| 軽〜中程度のタスクの開発 | 開発エージェント（Sonnet 5.5） |
| レビュー | レビューエージェント（Opus 5.5、読み取りのみ） |

## 2. 全エージェント共通のルール（必ず守る）

1. 編集してよいのは `mocks/evacuate/` の中の、**自分の担当ファイル**だけ。それ以外は読むだけ
   - 共有ファイル（`src/state/*`、`src/i18n/index.ts`、`src/components/*` など T0 が作ったもの）をどうしても変える必要があるときは、**追加だけの最小限の変更**にとどめ、最終報告に変更点を書く
2. git の操作は `git status` / `git diff` / `git log` の閲覧のみ。commit / push / reset / checkout / stash などはしない
3. デプロイ・公開（Vercel など）をしない
4. 依存パッケージを増やさない。使ってよいのは `react` `react-dom` `vite` `@vitejs/plugin-react` `typescript` `@types/react` `@types/react-dom` のみ（`npm install` は T0 だけが行う）。必要なら最終報告で提案する
5. `.env` などの秘密情報ファイルを開かない・表示しない（`mocks/travel-scheduler/.env` が存在する）
6. アプリのコードから外部と通信しない（`fetch` で外部 API を呼ばない）。例外は `index.html` の Google Fonts の読み込みのみ
7. `rm -rf` などの一括削除をしない。自分が作ったファイル以外は削除しない
8. 開発サーバーを起動したままにしない。確認は `npx tsc --noEmit -p .` と `npm run build` で行う。ほかのエージェントが並行で作業中のため、**自分の担当外のファイルの型エラーは無視してよい**（報告には書く）
9. 実在の警報・地名・住所・電話の自動発信を使わない（`tel:` は確認ダイアログ＋デモパネルで有効化したときだけ）
10. 画面は `docs/images/` の画像を Read ツールで開いて見ながら、見た目を合わせる

## 3. 技術構成

```
mocks/evacuate/
  package.json / vite.config.ts / tsconfig.json / index.html
  public/ar/            AR の背景画像（任意。street.jpg があれば使う）
  src/
    main.tsx / App.tsx
    styles/tokens.css   デザイントークン（CSS 変数）
    styles/global.css
    state/types.ts      状態・データの型
    state/store.tsx     React Context + useReducer。useAppState() / useDispatch()
    state/derive.ts     deriveMode() / resolveScreen() / 優先度・鮮度の判定
    state/scenarios.ts  デモシナリオの初期状態
    data/alerts.ts      モックの警報
    data/town.ts        架空の町（T1）
    data/landmarks.ts   AR 用の目印（T5）
    data/articles.ts    防災コラム（T3）
    i18n/index.ts       言語の判定・保存、useLang()、useT()、common の文言、RTL
    logic/route.ts      道路グラフ・ダイクストラ（T1）
    logic/nav.ts        経路上の位置・次の曲がり角・到着判定・useNavigation()（T1）
    platform/speech.ts  読み上げ / vibrate.ts 振動 / orientation.ts 傾き（T5）
    components/         共通 UI（T0）、TownMap（T1）、pictograms/（T2）
    screens/            画面ごとに 1 ファイル（S01.tsx など）
    demo/DemoPanel.tsx  デモ操作パネル（T4）
```

### 3.1 状態（`src/state/types.ts`、T0 が作る）

```ts
type Lang = 'en' | 'ja' | 'zh-Hans' | 'ko' | 'ar';
type L10n = Record<Lang, string>;           // 多言語テキスト
type HazardType = 'earthquake' | 'tsunami';
type AlertLevel = 'advisory' | 'warning' | 'emergency';
interface Alert { id: string; type: HazardType; level: AlertLevel; area: L10n; issuedAt: number; source: 'JMA'; }
type EqSituation = 'indoors' | 'outdoors' | 'car';
interface Point { x: number; y: number }    // 町の座標（m）。左上原点、x=東、y=南

type ScreenId = 'S01'|'S02'|'S03'|'S04'|'S05'|'S06'|'S07'|'S08'|'S09'|'S10'|'S11'|'S12'
              | 'H00'|'A01'|'A02'|'A03'|'A04';

interface AppState {
  lang: Lang;
  now: number;                 // 仮想時計（ms）。初期 09:41 JST
  online: boolean;
  lastFetchAt: number;
  staleThresholdMin: number;   // 10
  alerts: Alert[];
  shaking: boolean;
  eqSituation: EqSituation;
  gps: { permission: 'granted' | 'denied' | 'prompt'; accuracyM: number; position: Point };
  manualPin: Point | null;     // S07 で確定したピン
  onHighGround: boolean;       // 「On high ground」を押した／到着した
  guideStep: 'action' | 'nav'; // S03（行動）か S04（ナビ）か
  walk: { playing: boolean; speed: number; progressM: number };
  screenOff: boolean;
  deviceRaised: boolean;
  ar: { cameraPermission: boolean; supported: boolean; headingAccuracyDeg: number;
        tracking: boolean; landmarkFound: boolean; showDetection: boolean };
  dialerEnabled: boolean;
  lockScreen: boolean;         // S01 を出している
  overlay: ScreenId[];         // 手動で開いたサブ画面のスタック（言語・緊急通報・地図・詳細など）
  scenarioId: string;
  toast: string | null;
}
```

アクション: `patch`（部分更新）、`loadScenario`、`navigate`（overlay に積む）、`back`、`tick`（仮想時計と歩行を進める）、`showToast`。

### 3.2 画面の決め方（`resolveScreen`、T0 が作る）

1. `lockScreen` → S01
2. `overlay` が空でなければ最後の画面
3. `deriveMode()` の結果で決める
   - `normal` → H00
   - `shake` → S02
   - `safe` → S06
   - ~~`locate` → S07~~（FB4 で廃止。位置がおおまかなら `evacuate` のまま S03 / S05 に標識の案内を出す。requirements.md 7.1・14.5）
   - `evacuate`:
     - オンライン: `guideStep==='action'` → S03。`nav` → AR 条件をすべて満たせば S11、端末を持ち上げているのに AR 条件（精度・追跡・通行確認）を満たさなければ S12、それ以外は S04
     - オフライン: `action` → S05、`nav` → S08
     - オフライン・カメラ権限なし・非対応端末のときは S11/S12 に入らない（S04/S05 系のまま）

優先度（requirements 7.2）と鮮度（7.3）の判定関数も `derive.ts` に置く。

### 3.3 文言（i18n）
- 共通の文言（ボタン・ヘッダー・バッジ）は `src/i18n/index.ts` の `common` に 5 言語で置く（T0）
- 画面ごとの文言は、**その画面のファイルの中**に 5 言語分を持つ: `const t = useT({ en: {...}, ja: {...}, 'zh-Hans': {...}, ko: {...}, ar: {...} })`
- 地名・住所は `L10n` で持ち、表示時は「現在の言語＋日本語」を並べる
- アラビア語では `<html dir="rtl">`。左右の矢印は反転する

### 3.4 地図（T1 の `TownMap`）
- 町は 600 m × 450 m 程度。西が海、海岸沿いに危険区域（斜線）、東が高台。避難先（旗）は `Hill Park / 高台公園` ほか 1〜2 か所
- props の例: `variant: 'mini' | 'full'`、`routeColor: 'blue' | 'yellow' | 'none'`、`showAccuracy`、`pinEditable` / `onPinChange`、`showHeading`
- ルート・現在地・次の曲がり角は `useNavigation()` から取る（S04・S07・S08・S11・S12 で同じ値を使う）

## 4. タスク分割

| タスク | 内容 | 担当モデル | 依存 | 担当ファイル |
|---|---|---|---|---|
| T0 基盤 | Vite 雛形、`npm install`、トークン・共通 CSS、PhoneFrame（PC はスマホ枠＋右にデモパネルの場所、実機は全画面）、StatusBar（仮想時計・DEMO）、Header、Badge、BigButton、FooterMeta、Toast、store / types / derive / scenarios / alerts、i18n 基盤と common、全画面のプレースホルダー、仮想時計と歩行の tick | Opus | なし | 雛形一式、`src/main.tsx` `App.tsx` `styles/*` `state/*` `data/alerts.ts` `i18n/index.ts` `components/*`（TownMap と pictograms を除く） |
| T1 地図・経路 | 町データ、TownMap（SVG）、道路グラフ、ダイクストラ（体力消耗・階段・危険区域・通行止め）、経路上の位置、次の曲がり角、到着判定、`useNavigation()`、簡単なテスト用スクリプト | Opus | T0 | `data/town.ts` `logic/*` `components/TownMap.tsx`（+ css） |
| T2 誘導画面 | ピクトグラム（頭を守る・車内で待つ・車を降りる・屋外で身を守る・高台へ・待機）、S01 S02 S03 S05 S06 H00 | Sonnet | T0 | `components/pictograms/*` `screens/S01〜S03,S05,S06,H00` |
| T3 サブ画面 | S09 言語、S10 緊急通報、A01 許可説明、A02 警報詳細、A03 災害種別ガイド、A04 防災コラム（`data/articles.ts`） | Sonnet | T0 | `screens/S09,S10,A01〜A04` `data/articles.ts` |
| T4 デモパネル | DemoPanel（シナリオ、通知、揺れ、警報、オンライン、GPS、歩行、画面オフ、仮想時計、AR の各条件、tel: 有効化）、シナリオ 1〜4・3b の調整 | Sonnet | T0 | `demo/*`、`state/scenarios.ts`（T0 から引き継ぎ） |
| T5 ナビ・AR | S04 S07 S08 S11 S12、音声・振動・画面オフ中の案内、傾き検知、AR の背景（SVG の街路イラスト、`public/ar/street.jpg` があれば優先）、曲がり矢印の重ね描き、目印の認識枠、`data/landmarks.ts` | Opus | T1 | `screens/S04,S07,S08,S11,S12` `platform/*` `data/landmarks.ts` |
| R レビュー | 要件との差分・不具合・安全面（誤発信、外部通信、秘密情報）のレビュー | Opus | T1〜T5 | なし（読み取りのみ） |
| F 修正 | レビュー指摘の修正。重さに応じて Opus / Sonnet に振る | — | R | 指摘箇所 |

進め方: T0 → T1・T2・T3・T4 を並行 → T5 → R → F → 最終確認。
