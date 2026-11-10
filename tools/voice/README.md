# tools/voice — 誘導画面の音声ファイル（H6）

誘導画面（S01〜S06、S11）で読み上げる**固定の指示文**を、Google Cloud Text-to-Speech の **Chirp 3 HD** の声で MP3 にし、モック（`mocks/evacuate/public/voice/`）に同梱するスクリプトです（`mocks/evacuate/docs/architecture.md` 10 節の H6）。

## 何を作るか

- 対象の文は `phrases.mjs` の `PHRASES` に並べたもの。文そのものはモックのソース（画面ごとの `useT({...})` や `guideDict` などの辞書）から構文木で取り出すので、ここに文を二重に書かない
- 5 言語（en / ja / zh-Hans / ko / ar）。Text-to-Speech の言語コードは `en-US` / `ja-JP` / `cmn-CN` / `ko-KR` / `ar-XA`
- 声は `voices:list` で各言語に Chirp 3 HD の声（名前に `Chirp3-HD` を含む）があるかを確かめてから選ぶ。`PREFERRED_VOICE`（`Kore`）があればそれ、なければその言語の Chirp 3 HD の先頭。**Chirp 3 HD の声がない言語は生成しない**（モックは Web Speech API で読む）
- 出力: `mocks/evacuate/public/voice/<lang>/<key>.mp3` と `manifest.json`（キー → ファイル、元の文、声の名前、ハッシュ）
- **数値を含む文は作らない**（「Turn right in 40 meters.」、標高・余裕の文など）。`PHRASES` に数値を含む文が入るとエラーで止まる
- 同じ言語で区切り（空白・句読点・`+`）を除いて同じ文は 1 つにまとめる（`alsoFrom` に記録）
- 英語の大文字の語（`EARTHQUAKE`、`NOW` など）は 1 文字ずつ読まれないよう、先頭だけ大文字にして読ませる（manifest の `text` は画面の文のまま）

- 誤読する語は `mocks/evacuate/src/platform/readings.ts` の辞書に入れる（例: 高台 → たかだい）。表示の文は変えず、音声にするときだけ置き換える。manifest の `text` は表示の文（モックの照合用）、`reading` は合成に送った文で、ハッシュは `reading` から作る。Web Speech API で読む部分にも同じ辞書を使う

## モックでの再生

`mocks/evacuate/src/platform/speech.ts` の `speak()` が、読み上げる文を `manifest.json` の文に分けられるか調べます（`src/platform/voiceClips.ts`）。

- 音声ファイルのある部分は `<audio>` で、ない部分（数値を含む余裕の文など）は Web Speech API（`speechSynthesis`）で、順につないで読む（例: 「Stay here. HIGH GROUND 12 m above forecast」→ 2 つのファイル＋「12 m above forecast」を Web Speech API）。どの部分にも音声ファイルがなければ、文全体を Web Speech API で読む
- ある部分のファイルを再生できなかったときは、その部分から先だけを Web Speech API で読む
- manifest は起動時に読み、失敗したら `speak()` のたびに読み直す。`speak()` の時点で manifest がなければ最大 300 ms 待つ。1 件目の再生中に次のファイルを先読みする
- 照合はキーではなく**文そのもの**で行う。辞書の文を直したのに作り直していない場合は、古い音声を流さずに Web Speech API に戻る
- 自動読み上げ（F18）、読み上げボタンの「停止」（F80〜F82）、画面切り替えでの停止、画面オフ中に止めない扱いは、従来の `speak()` / `cancelSpeech()` のまま
- 他社 OS のブラウザなどの自動再生の制約（最初の操作の前は鳴らない）は Web Speech API と同じ扱い

## 実行方法

前提: `gcloud` にログイン済みで、スクリプトの `SERVICE_ACCOUNT` に書いた開発用のサービスアカウントになりすませること（`roles/iam.serviceAccountTokenCreator`）。Text-to-Speech API はプロジェクト `devfest2026-oauthmountains` で有効化済み。**鍵ファイルは作らない・使わない。**

```sh
npm ci --prefix mocks/evacuate            # 辞書を読むのにモックの依存パッケージを使う
node tools/voice/generate.mjs --dry-run   # API を呼ばずに、対象の文と生成する文字数を表示
node tools/voice/generate.mjs             # 差分だけ生成して manifest.json を更新
```

- アクセストークンはスクリプトの中で `gcloud auth print-access-token --impersonate-service-account=...` を実行して取り、メモリにだけ置く（表示しない・書き出さない）。REST の呼び出しには `x-goog-user-project: devfest2026-oauthmountains` を付ける
- **再生成**: 辞書の文を直したら、そのまま `node tools/voice/generate.mjs` を実行する。文・声・出力形式から作るハッシュが manifest と同じで、ファイルもあるものは API を呼ばない。`PHRASES` から外したキーのファイルは消える。全部作り直すときは `--force`
- 対象の文を増やすときは `phrases.mjs` に 1 行足す（読み上げで実際に読む文のうち、数値を含まないものだけ）

## 費用の目安

- 課金は合成した文字数（Chirp 3 HD は 100 万文字あたり 30 米ドル前後。無料枠は月 100 万文字）。2026-11-09 の初回生成は 90 件・921 文字、API 呼び出しは 95 回（`voices:list` 5 回を含む）で、無料枠の範囲
- 2 回目以降は差分だけなので、文を変えなければ `voices:list` の 5 回だけ
- 生成物は MP3（24 kHz）で合計約 0.65 MB

## help-ja.mjs — 「日本語で助けを求める」カードの日本語音声（機能 F）

Flutter アプリの S04・S10 から開くカード（`apps/ar_guide/lib/app/help/`）で流す日本語 1 文を、同じ Chirp 3 HD の声（`ja-JP-Chirp3-HD-Kore`）で作ります。モックにはこの機能がないので、`generate.mjs` とは別のスクリプトにしています。

- 文: `apps/ar_guide/lib/app/help/help_strings.dart` の `helpJaLines`（つないだ文を 1 つの MP3 にする）
- 読み: `apps/ar_guide/lib/app/platform/readings.dart` の日本語の辞書を当てて合成する（高台 → たかだい）。manifest の `text` は表示の文、`reading` は合成に送った文
- 出力: `apps/ar_guide/assets/voice/help/ja.mp3` と `manifest.json`（`assets/voice/manifest.json` と同じ形。アプリは文そのもので照合し、文が変わっていれば端末の TTS で読む）
- 認証・費用の考え方は `generate.mjs` と同じ（鍵ファイルは使わない）。合成は 36 文字

```sh
node tools/voice/help-ja.mjs --dry-run   # API を呼ばずに、表示の文・合成する文を表示
node tools/voice/help-ja.mjs             # 文・声・形式が変わったときだけ生成（--force で作り直し）
```

`mocks/evacuate/public/voice/` を `apps/ar_guide/assets/voice/` にコピーし直すときは、`help/` を消さないでください。
