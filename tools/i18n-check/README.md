# tools/i18n-check — ビルド時の訳の点検（D1 / D12）

Flutter アプリ（`apps/ar_guide`）の誘導の文と警報の用語を、**英語の原文から Gemini で訳し直し**、**Cloud Translation API で英語に訳し戻して**、アプリの現在の訳と比べるスクリプトです（`mocks/evacuate/docs/architecture.md` の D1 / D12、§4.1）。結果は `docs/i18n-review.md`（日本語の表）と `docs/i18n-review.json` に書きます。

> **現時点では Cloud Translation API が使えない（無効のため HTTP 403）ので、逆翻訳は未実施です。** いまコミットしているレポートは、Gemini の訳し直しと Gemini の判定だけです。API が使えるようになったら `node tools/i18n-check/check.mjs` を流し直すと、逆翻訳つきのレポートになります。

**報告だけで、アプリの文と音声ファイル（`tools/voice`）は変えません。** 直すかどうかは人が判断し、直すときはアプリの辞書を手で直して `tools/voice` を流し直します。

## 何をするか

1. 対象の文を集める: `targets.mjs` の `TARGETS` に並べた辞書（誘導画面 S01〜S03・S05・S06 の画面の文、S04 は方向ラベル（左 / 右 / 直進）だけ、`guideDict` / `bandDict` / `cardDict` / `heightDict`、再通知・プッシュ通知の文、警報名のバッジなど。S11 の `turnAround` は AR 案内の `lib/src/strings.dart` から）。`tools/voice/phrases.mjs` で音声にしている文はすべて含む。原文は en、対象は ja / zh-Hans / ko / ar
2. **Gemini で訳し直す**（Vertex AI、構造化出力）。「外国人旅行者向けの緊急避難の指示。短く、命令形で、平易に。警報名は気象庁の多言語辞書の用語」と指示する
3. **Cloud Translation API v3 で英語に訳し戻す**: 現在の訳と Gemini の訳の両方。Gemini と別のエンジンにするのは、同じモデルの誤りを見逃さないため（D12）。**現時点では API が無効のため逆翻訳は未実施**（使えないときは省いて続け、レポートに理由を書く）
4. **Gemini で判定する**（構造化出力）: 現在の訳が原文の意味と緊急度を保っているか、短く平易か、警報名が公式の用語か。`major`（要修正）/ `minor`（改善の余地）/ `ok` と、短い理由（日本語）
5. プレースホルダー（`{n}` など）が原文と合わない訳は、判定にかかわらず `major` にする

### Dart の辞書の読み方

アプリの辞書は Dart の `const` リテラルで、形は `const Dict _dict = { Lang.en: {'key': 'text'}, ... }`、`commonStrings = { Lang.en: CommonStrings(key: 'text'), ... }`、AR 案内の `lib/src/strings.dart` の `const _en = S(key: 'text', ...)`（1 言語ずつ別の定数）の 3 つだけです。そこで `dart-dict.mjs` で **Dart のソースを字句（文字列・識別子・記号・コメント）に分け、この 3 つの形だけを読む**小さなパーサを書きました（`parseDartDicts` / `parseDartConsts`）。

- モックのソースを `tools/voice` のように構文木で読む方法もありますが、点検したいのは製品（Flutter）の文なので、アプリの辞書を直接読みます（モックとアプリの訳がずれても、アプリの訳を点検できる）
- Dart SDK や依存パッケージは不要（JavaScript の実行環境だけで動く）。文字列のエスケープ・raw 文字列・隣り合う文字列の連結・コメントに対応。値が文字列リテラルでない項目（式など）があればエラーで止まる
- 想定外の形に出会ったら推測せずにエラーで止まる

## 実行方法

前提: `gcloud` にログイン済みで、スクリプトの `SERVICE_ACCOUNT` に書いた開発用のサービスアカウントになりすませること（`roles/iam.serviceAccountTokenCreator`）。プロジェクト `devfest2026-oauthmountains` で Vertex AI API（`aiplatform.googleapis.com`）と Cloud Translation API（`translate.googleapis.com`）が有効なこと。**鍵ファイルは作らない・使わない。** JavaScript の実行環境はバージョン 22 以上。

```sh
node tools/i18n-check/check.mjs --dry-run   # API を呼ばずに、対象の文と呼び出し回数の見込みを表示
node tools/i18n-check/check.mjs --limit 3   # 先頭 3 件だけ点検して画面に出す（レポートは書かない）
node tools/i18n-check/check.mjs             # 全件を点検して docs/i18n-review.md / .json を書く
node --test tools/i18n-check/dart-dict.test.mjs   # パーサと文の集め方のテスト（API は呼ばない）
```

- `--model <名前>`: Gemini のモデル。既定は `check.mjs` の `DEFAULT_MODEL`（`gemini-3.5-flash`、`global` のエンドポイント。2026-11-10 に実際の呼び出しで確認）
- `--max-requests <数>`: API 呼び出しの上限（既定 300）。超えそうなら止まる
- `--no-judge`: Gemini の判定を省く
- アクセストークンはスクリプトの中で `gcloud auth print-access-token --impersonate-service-account=...` を実行して取り、メモリにだけ置く。REST の呼び出しには `x-goog-user-project: devfest2026-oauthmountains` を付ける
- Cloud Translation API が使えない（無効・権限なし）ときは、逆翻訳を省いて続け、レポートにその旨と理由を書く。そのときの判定は Gemini が訳文を直接読んで行う
- **キャッシュ**: 応答は `cache.json` に入れる（入力とモデルとプロンプトから作るハッシュがキー）。文を変えなければ再実行で API を呼ばない。プロンプトを変えたら `PROMPT_VERSION` を上げる。全部やり直すときは `cache.json` を消す
- 対象の文を増やすときは `targets.mjs` に 1 行足す

## 費用の目安

- 全件（88 件 × 4 言語）で、Gemini の呼び出しは訳し直し 88 回＋判定 88 回、Cloud Translation は 4 回（言語ごとにまとめて送る）。`thinkingLevel: LOW` で考える量を抑えている
- Gemini は 1 回あたり入力・出力とも数百トークン程度で、全件でも数十円以下。Cloud Translation は月 50 万文字まで無料で、全件でも数千文字
- 2 回目以降はキャッシュが効くので、変えた文の分だけ
