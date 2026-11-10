# 第三者の素材とライセンスの一覧

> **著作物利用シートの下書き。提出前にメンバーが確認する。**
> 2026-11-09 時点の `develop` をもとに作成し、2026-11-10 に Flutter アプリ（PR #18〜#20）の依存と素材を追記。「**要確認**」と書いた項目は、推測で埋めずに残している。提出前に確認して、結果をこの表に書き込む。

## 0. 要確認の一覧

| # | 項目 | 確認すること |
|---|---|---|
| 1 | 画面デザインの元資料（`mocks/evacuate/docs/images/*.png`） | 誰が作ったか。生成 AI や外部の素材・テンプレートを使っていないか |
| 2 | AR の背景画像 `public/ar/street.jpg` | 現在はリポジトリにない（未配置なら自作の SVG の街路を使う）。**置く場合は出所と利用条件を確認する** |
| 3 | AR の街路に描いた津波避難標識 | 自作の図だが、JIS Z 8210 の「津波避難場所」などの図記号に似せているか。似せている場合の扱い |
| 4 | Chirp 3 HD で作った音声ファイル（H6、`mocks/evacuate/public/voice/` の 90 件と、Flutter アプリに同梱したそのコピー `apps/ar_guide/assets/voice/`） | Google Cloud の利用規約上、生成した音声を作品に同梱して配ってよいか |
| 5 | ARCore SDK（`com.google.ar:core`） | ライセンスと、アプリ内に必要な表示（Google Play Services for AR の利用の告知）の有無 |
| 6 | Android のランチャーアイコン | Flutter のテンプレートの既定アイコンのまま（ファイルサイズが既定と一致）。提出物として差し替えるか |
| 7 | （解決済み）Firebase JS SDK | H2 のマージ後の `package-lock.json` で一覧を作り直した（1.1） |
| 8 | 気象庁の電文の形式・コード表 | 形式とコード（津波予報区の名前・コード）の利用に、気象庁の利用規約上の表示が要るか |
| 9 | Google Fonts を CDN から読み込むこと | 提出先の規定で外部 CDN の利用や表示が求められていないか |
| 10 | 防災コラムなどの文章 | 気象庁などの文を転載・引用している箇所がないか |
| 11 | `dbus` 0.8.0（MPL-2.0、Flutter の間接の依存） | Linux 版の通知だけで使い、Android の APK には入らないことの確認（入る場合は MPL-2.0 の表示の扱い） |
| 12 | Flutter アプリのライセンス表示 | APK の中で第三者のライセンスを見られるようにするか（Flutter の `showLicensePage` など）。提出先の規定で求められているか |

## 1. npm の依存

`package-lock.json` の各パッケージの `license` 欄を集計した（`dev: true` でないものを本番の依存とした）。lockfile に欄がなかった `limiter@1.1.5` だけは `npm view` の公開情報で補った。

作り直すときは、各ディレクトリで `npm ci` のあとに `npx license-checker --production --summary` を使う。

### 1.1 `mocks/evacuate`（Web のモック）

直接の依存: `firebase@13.2.0`（Apache-2.0、H2 で追加）、`react@19.2.8`・`react-dom@19.2.8`（MIT）

本番の依存（間接を含む）: 124 件。Apache-2.0 79 / MIT 29 / BSD-3-Clause 10 / ISC 5 / 0BSD 1。GPL などのコピーレフトのライセンスはない。

devDependencies（Vite・TypeScript・型定義など、配布物には入らない）: 111 件。MIT 102 / ISC 5 / Apache-2.0 2 / BSD-3-Clause 1 / CC-BY-4.0 1（`caniuse-lite`。ブラウザ対応表のデータ）

`public/firebase-messaging-sw.js`（通知を受けるサービスワーカー）は、ビルドの外にある静的ファイルなので、Firebase の SDK（13.2.0、Apache-2.0）を `www.gstatic.com` から `importScripts` で読み込む。

<details>
<summary>本番の依存の一覧（124 件）</summary>

| パッケージ | バージョン | ライセンス |
|---|---|---|
| @firebase/ai | 3.0.0 | Apache-2.0 |
| @firebase/analytics | 0.10.25 | Apache-2.0 |
| @firebase/analytics-compat | 0.2.31 | Apache-2.0 |
| @firebase/analytics-types | 0.8.5 | Apache-2.0 |
| @firebase/app | 0.16.5 | Apache-2.0 |
| @firebase/app-check | 0.13.1 | Apache-2.0 |
| @firebase/app-check-compat | 0.4.7 | Apache-2.0 |
| @firebase/app-check-interop-types | 0.3.5 | Apache-2.0 |
| @firebase/app-check-types | 0.5.5 | Apache-2.0 |
| @firebase/app-compat | 0.5.21 | Apache-2.0 |
| @firebase/app-types | 0.9.6 | Apache-2.0 |
| @firebase/auth | 1.13.9 | Apache-2.0 |
| @firebase/auth-compat | 0.6.14 | Apache-2.0 |
| @firebase/auth-interop-types | 0.2.6 | Apache-2.0 |
| @firebase/auth-types | 0.13.2 | Apache-2.0 |
| @firebase/component | 0.7.5 | Apache-2.0 |
| @firebase/crashlytics | 0.1.0 | Apache-2.0 |
| @firebase/data-connect | 0.7.4 | Apache-2.0 |
| @firebase/database | 1.1.5 | Apache-2.0 |
| @firebase/database-compat | 2.1.7 | Apache-2.0 |
| @firebase/database-types | 1.0.22 | Apache-2.0 |
| @firebase/firestore | 4.19.1 | Apache-2.0 |
| @firebase/firestore-compat | 0.4.17 | Apache-2.0 |
| @firebase/firestore-types | 3.0.5 | Apache-2.0 |
| @firebase/functions | 0.14.0 | Apache-2.0 |
| @firebase/functions-compat | 0.5.0 | Apache-2.0 |
| @firebase/functions-types | 0.6.5 | Apache-2.0 |
| @firebase/installations | 0.6.24 | Apache-2.0 |
| @firebase/installations-compat | 0.2.24 | Apache-2.0 |
| @firebase/installations-types | 0.5.5 | Apache-2.0 |
| @firebase/logger | 0.5.2 | Apache-2.0 |
| @firebase/messaging | 0.13.3 | Apache-2.0 |
| @firebase/messaging-compat | 0.2.30 | Apache-2.0 |
| @firebase/messaging-interop-types | 0.2.6 | Apache-2.0 |
| @firebase/performance | 0.7.14 | Apache-2.0 |
| @firebase/performance-compat | 0.2.27 | Apache-2.0 |
| @firebase/performance-types | 0.2.5 | Apache-2.0 |
| @firebase/remote-config | 0.9.3 | Apache-2.0 |
| @firebase/remote-config-compat | 0.2.30 | Apache-2.0 |
| @firebase/remote-config-types | 0.5.2 | Apache-2.0 |
| @firebase/storage | 0.14.6 | Apache-2.0 |
| @firebase/storage-compat | 0.4.6 | Apache-2.0 |
| @firebase/storage-types | 0.8.5 | Apache-2.0 |
| @firebase/util | 1.15.3 | Apache-2.0 |
| @firebase/webchannel-wrapper | 1.0.7 | Apache-2.0 |
| @grpc/grpc-js | 1.9.16 | Apache-2.0 |
| @grpc/proto-loader | 0.7.15 | Apache-2.0 |
| @opentelemetry/api | 1.9.1 | Apache-2.0 |
| @opentelemetry/api-logs | 0.220.0 | Apache-2.0 |
| @opentelemetry/browser-instrumentation | 0.6.0 | Apache-2.0 |
| @opentelemetry/core | 2.10.0 | Apache-2.0 |
| @opentelemetry/core | 2.9.0 | Apache-2.0 |
| @opentelemetry/exporter-logs-otlp-http | 0.220.0 | Apache-2.0 |
| @opentelemetry/exporter-trace-otlp-proto | 0.220.0 | Apache-2.0 |
| @opentelemetry/instrumentation | 0.220.0 | Apache-2.0 |
| @opentelemetry/instrumentation-document-load | 0.65.0 | Apache-2.0 |
| @opentelemetry/instrumentation-fetch | 0.220.0 | Apache-2.0 |
| @opentelemetry/instrumentation-xml-http-request | 0.220.0 | Apache-2.0 |
| @opentelemetry/otlp-exporter-base | 0.220.0 | Apache-2.0 |
| @opentelemetry/otlp-transformer | 0.220.0 | Apache-2.0 |
| @opentelemetry/resources | 2.9.0 | Apache-2.0 |
| @opentelemetry/resources | 2.10.0 | Apache-2.0 |
| @opentelemetry/sdk-logs | 0.220.0 | Apache-2.0 |
| @opentelemetry/sdk-metrics | 2.9.0 | Apache-2.0 |
| @opentelemetry/sdk-trace | 2.9.0 | Apache-2.0 |
| @opentelemetry/sdk-trace | 2.10.0 | Apache-2.0 |
| @opentelemetry/sdk-trace-base | 2.9.0 | Apache-2.0 |
| @opentelemetry/sdk-trace-base | 2.10.0 | Apache-2.0 |
| @opentelemetry/sdk-trace-web | 2.9.0 | Apache-2.0 |
| @opentelemetry/sdk-trace-web | 2.10.0 | Apache-2.0 |
| @opentelemetry/semantic-conventions | 1.43.0 | Apache-2.0 |
| @protobufjs/aspromise | 1.1.2 | BSD-3-Clause |
| @protobufjs/base64 | 1.1.2 | BSD-3-Clause |
| @protobufjs/codegen | 2.0.5 | BSD-3-Clause |
| @protobufjs/eventemitter | 1.1.1 | BSD-3-Clause |
| @protobufjs/fetch | 1.1.1 | BSD-3-Clause |
| @protobufjs/float | 1.0.2 | BSD-3-Clause |
| @protobufjs/path | 1.1.2 | BSD-3-Clause |
| @protobufjs/pool | 1.1.0 | BSD-3-Clause |
| @protobufjs/utf8 | 1.1.2 | BSD-3-Clause |
| @types/node | 26.6.6 | MIT |
| @types/react | 19.2.18 | MIT |
| ansi-regex | 5.0.1 | MIT |
| ansi-styles | 4.3.0 | MIT |
| cjs-module-lexer | 2.3.0 | MIT |
| cliui | 8.0.1 | ISC |
| color-convert | 2.0.1 | MIT |
| color-name | 1.1.4 | MIT |
| csstype | 3.2.3 | MIT |
| debug | 4.4.3 | MIT |
| emoji-regex | 8.0.0 | MIT |
| es-module-lexer | 3.0.4 | MIT |
| escalade | 3.2.0 | MIT |
| faye-websocket | 0.11.4 | Apache-2.0 |
| firebase | 13.2.0 | Apache-2.0 |
| get-caller-file | 2.0.5 | ISC |
| http-parser-js | 0.5.10 | MIT |
| idb | 7.1.1 | ISC |
| import-in-the-middle | 3.6.0 | Apache-2.0 |
| is-fullwidth-code-point | 3.0.0 | MIT |
| lodash.camelcase | 4.3.0 | MIT |
| long | 5.3.2 | Apache-2.0 |
| module-details-from-path | 1.0.4 | MIT |
| ms | 2.1.3 | MIT |
| protobufjs | 7.6.6 | BSD-3-Clause |
| re2js | 2.9.1 | MIT |
| react | 19.2.8 | MIT |
| react-dom | 19.2.8 | MIT |
| require-directory | 2.1.1 | MIT |
| require-in-the-middle | 8.0.1 | MIT |
| safe-buffer | 5.2.1 | MIT |
| scheduler | 0.27.0 | MIT |
| string-width | 4.2.3 | MIT |
| strip-ansi | 6.0.1 | MIT |
| tslib | 2.9.1 | 0BSD |
| undici-types | 8.9.0 | MIT |
| web-vitals | 5.3.0 | Apache-2.0 |
| web-vitals | 4.2.4 | Apache-2.0 |
| websocket-driver | 0.7.5 | Apache-2.0 |
| websocket-extensions | 0.1.4 | Apache-2.0 |
| wrap-ansi | 7.0.0 | MIT |
| y18n | 5.0.8 | ISC |
| yargs | 17.7.3 | MIT |
| yargs-parser | 21.1.1 | ISC |

</details>

### 1.2 `services/alert-ingest`（Cloud Run）

直接の依存: `fast-xml-parser@5.12.0`（MIT）、`firebase-admin@14.5.0`（Apache-2.0）

本番の依存（間接を含む）: 168 件。MIT 95 / Apache-2.0 39 / ISC 17 / BSD-3-Clause 11 / BlueOak-1.0.0 5 / 0BSD 1。GPL などのコピーレフトのライセンスはない。

devDependencies（`@types/node`・`tsx`・`typescript` とその依存）: 30 件。MIT 29 / Apache-2.0 1

<details>
<summary>本番の依存の一覧（168 件）</summary>

※ は `firebase-admin` の optionalDependencies（`@google-cloud/firestore`・`@google-cloud/storage`）とその依存。既定でインストールされ、Firestore への接続に使う。

| パッケージ | バージョン | ライセンス |
|---|---|---|
| @fastify/busboy | 3.2.5 | MIT |
| @firebase/app-check-interop-types | 0.3.5 | Apache-2.0 |
| @firebase/app-types | 0.9.6 | Apache-2.0 |
| @firebase/auth-interop-types | 0.2.6 | Apache-2.0 |
| @firebase/component | 0.7.5 | Apache-2.0 |
| @firebase/database | 1.1.5 | Apache-2.0 |
| @firebase/database-compat | 2.1.7 | Apache-2.0 |
| @firebase/database-types | 1.0.22 | Apache-2.0 |
| @firebase/logger | 0.5.2 | Apache-2.0 |
| @firebase/util | 1.15.3 | Apache-2.0 |
| @google-cloud/firestore ※ | 9.4.0 | Apache-2.0 |
| @google-cloud/firestore-api ※ | 0.2.0 | Apache-2.0 |
| @google-cloud/paginator ※ | 7.2.0 | Apache-2.0 |
| @google-cloud/projectify ※ | 6.2.1 | Apache-2.0 |
| @google-cloud/promisify ※ | 6.2.1 | Apache-2.0 |
| @google-cloud/storage ※ | 8.4.0 | Apache-2.0 |
| @grpc/grpc-js ※ | 1.14.7 | Apache-2.0 |
| @grpc/proto-loader ※ | 0.8.1 | Apache-2.0 |
| @isaacs/cliui ※ | 8.0.2 | ISC |
| @js-sdsl/ordered-map ※ | 4.4.2 | MIT |
| @nodable/entities | 3.1.0 | MIT |
| @opentelemetry/api ※ | 1.10.0 | Apache-2.0 |
| @pkgjs/parseargs ※ | 0.11.0 | MIT |
| @protobufjs/aspromise ※ | 1.1.2 | BSD-3-Clause |
| @protobufjs/base64 ※ | 1.1.2 | BSD-3-Clause |
| @protobufjs/codegen ※ | 2.0.5 | BSD-3-Clause |
| @protobufjs/eventemitter ※ | 1.1.1 | BSD-3-Clause |
| @protobufjs/fetch ※ | 1.1.1 | BSD-3-Clause |
| @protobufjs/float ※ | 1.0.2 | BSD-3-Clause |
| @protobufjs/path ※ | 1.1.2 | BSD-3-Clause |
| @protobufjs/pool ※ | 1.1.0 | BSD-3-Clause |
| @protobufjs/utf8 ※ | 1.1.2 | BSD-3-Clause |
| @types/jsonwebtoken | 9.0.10 | MIT |
| @types/ms | 2.1.0 | MIT |
| @types/node | 22.20.5 | MIT |
| abort-controller ※ | 3.0.0 | MIT |
| agent-base | 7.1.4 | MIT |
| ansi-regex ※ | 6.6.0 | MIT |
| ansi-regex ※ | 5.0.1 | MIT |
| ansi-styles ※ | 6.2.3 | MIT |
| ansi-styles ※ | 4.3.0 | MIT |
| anynum | 1.0.1 | MIT |
| async-retry ※ | 1.3.3 | MIT |
| balanced-match ※ | 1.0.2 | MIT |
| base64-js | 1.5.1 | MIT |
| bignumber.js | 9.3.1 | MIT |
| brace-expansion ※ | 2.1.7 | MIT |
| buffer-equal-constant-time | 1.0.1 | BSD-3-Clause |
| cliui ※ | 8.0.1 | ISC |
| color-convert ※ | 2.0.1 | MIT |
| color-name ※ | 1.1.4 | MIT |
| cross-spawn ※ | 7.0.6 | MIT |
| data-uri-to-buffer | 4.0.1 | MIT |
| debug | 4.4.3 | MIT |
| duplexify ※ | 4.1.3 | MIT |
| eastasianwidth ※ | 0.2.0 | MIT |
| ecdsa-sig-formatter | 1.0.11 | Apache-2.0 |
| emoji-regex ※ | 9.2.2 | MIT |
| emoji-regex ※ | 8.0.0 | MIT |
| end-of-stream ※ | 1.4.5 | MIT |
| escalade ※ | 3.2.0 | MIT |
| event-target-shim ※ | 5.0.1 | MIT |
| extend | 3.0.2 | MIT |
| fast-deep-equal | 3.1.3 | MIT |
| fast-xml-builder | 1.3.1 | MIT |
| fast-xml-parser | 5.12.0 | MIT |
| faye-websocket | 0.11.4 | Apache-2.0 |
| fetch-blob | 3.2.0 | MIT |
| firebase-admin | 14.5.0 | Apache-2.0 |
| foreground-child ※ | 3.3.1 | ISC |
| formdata-polyfill | 4.0.10 | MIT |
| functional-red-black-tree ※ | 1.0.1 | MIT |
| gaxios ※ | 7.1.3 | Apache-2.0 |
| gaxios ※ | 7.3.1 | Apache-2.0 |
| gaxios | 8.3.2 | Apache-2.0 |
| gcp-metadata ※ | 8.1.4 | Apache-2.0 |
| gcp-metadata | 9.2.3 | Apache-2.0 |
| get-caller-file ※ | 2.0.5 | ISC |
| glob ※ | 10.5.0 | ISC |
| google-auth-library ※ | 10.5.0 | Apache-2.0 |
| google-auth-library | 11.3.3 | Apache-2.0 |
| google-gax ※ | 5.0.8 | Apache-2.0 |
| google-gax ※ | 6.16.0 | Apache-2.0 |
| google-logging-utils ※ | 1.1.3 | Apache-2.0 |
| google-logging-utils | 2.1.1 | Apache-2.0 |
| gtoken ※ | 8.0.0 | MIT |
| html-entities ※ | 2.6.0 | MIT |
| http-parser-js | 0.5.10 | MIT |
| http-proxy-agent ※ | 7.0.2 | MIT |
| https-proxy-agent | 7.0.6 | MIT |
| inherits ※ | 2.0.4 | ISC |
| is-fullwidth-code-point ※ | 3.0.0 | MIT |
| is-unsafe | 2.0.3 | MIT |
| isexe ※ | 2.0.0 | ISC |
| jackspeak ※ | 3.4.3 | BlueOak-1.0.0 |
| jose | 6.2.15 | MIT |
| json-bigint | 1.0.0 | MIT |
| jsonwebtoken | 9.0.3 | MIT |
| jwa | 2.0.1 | MIT |
| jwks-rsa | 4.1.0 | MIT |
| jws | 4.0.1 | MIT |
| limiter | 1.1.5 | MIT |
| lodash.camelcase ※ | 4.3.0 | MIT |
| lodash.clonedeep | 4.5.0 | MIT |
| lodash.includes | 4.3.0 | MIT |
| lodash.isboolean | 3.0.3 | MIT |
| lodash.isinteger | 4.0.4 | MIT |
| lodash.isnumber | 3.0.3 | MIT |
| lodash.isplainobject | 4.0.6 | MIT |
| lodash.isstring | 4.0.1 | MIT |
| lodash.once | 4.1.1 | MIT |
| long ※ | 5.3.2 | Apache-2.0 |
| lru-cache | 11.5.3 | BlueOak-1.0.0 |
| lru-cache ※ | 10.4.3 | ISC |
| lru-memoizer | 3.0.0 | MIT |
| mime ※ | 3.0.0 | MIT |
| minimatch ※ | 9.0.9 | ISC |
| minipass ※ | 7.1.3 | BlueOak-1.0.0 |
| ms | 2.1.3 | MIT |
| node-domexception | 1.0.0 | MIT |
| node-fetch | 3.3.2 | MIT |
| object-hash ※ | 3.0.0 | MIT |
| once ※ | 1.4.0 | ISC |
| p-limit ※ | 3.1.0 | MIT |
| package-json-from-dist ※ | 1.0.1 | BlueOak-1.0.0 |
| path-expression-matcher | 1.6.2 | MIT |
| path-key ※ | 3.1.1 | MIT |
| path-scurry ※ | 1.11.1 | BlueOak-1.0.0 |
| proto3-json-serializer ※ | 3.0.4 | Apache-2.0 |
| proto3-json-serializer ※ | 4.1.0 | Apache-2.0 |
| protobufjs ※ | 7.6.6 | BSD-3-Clause |
| readable-stream ※ | 3.6.2 | MIT |
| require-directory ※ | 2.1.1 | MIT |
| retry ※ | 0.13.1 | MIT |
| retry-request ※ | 8.0.4 | MIT |
| retry-request ※ | 9.1.0 | MIT |
| rimraf ※ | 5.0.10 | ISC |
| safe-buffer | 5.2.1 | MIT |
| semver | 7.8.6 | ISC |
| shebang-command ※ | 2.0.0 | MIT |
| shebang-regex ※ | 3.0.0 | MIT |
| signal-exit ※ | 4.1.0 | ISC |
| stream-events ※ | 1.0.5 | MIT |
| stream-shift ※ | 1.0.3 | MIT |
| string_decoder ※ | 1.3.0 | MIT |
| string-width ※ | 5.1.2 | MIT |
| string-width ※ | 4.2.3 | MIT |
| strip-ansi ※ | 7.2.0 | MIT |
| strip-ansi ※ | 6.0.1 | MIT |
| strnum | 2.5.1 | MIT |
| stubs ※ | 3.0.0 | MIT |
| teeny-request ※ | 10.1.4 | Apache-2.0 |
| teeny-request ※ | 11.1.1 | Apache-2.0 |
| tslib | 2.9.1 | 0BSD |
| undici-types | 6.21.0 | MIT |
| util-deprecate ※ | 1.0.2 | MIT |
| web-streams-polyfill | 3.3.3 | MIT |
| websocket-driver | 0.7.5 | Apache-2.0 |
| websocket-extensions | 0.1.4 | Apache-2.0 |
| which ※ | 2.0.2 | ISC |
| wrap-ansi ※ | 8.1.0 | MIT |
| wrap-ansi ※ | 7.0.0 | MIT |
| wrappy ※ | 1.0.2 | ISC |
| xml-naming | 0.3.0 | MIT |
| y18n ※ | 5.0.8 | ISC |
| yargs ※ | 17.7.3 | MIT |
| yargs-parser ※ | 21.1.1 | ISC |
| yocto-queue ※ | 0.1.0 | MIT |

</details>

## 2. Flutter（`apps/ar_guide`）

`pubspec.lock` の直接の依存と、Android 側の依存（2026-11-10 時点の `develop`、PR #18〜#25 のあと）。ライセンスは pub のキャッシュ（`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<パッケージ>-<バージョン>\LICENSE`）の本文で確かめた。

| 名前 | バージョン | 種類 | ライセンス | 備考 |
|---|---|---|---|---|
| Flutter SDK | 3.47.4（stable） | SDK | BSD-3-Clause | エンジンが同梱するサードパーティの表示は、アプリの `LicenseRegistry` に入る |
| camera | 0.12.2 | 直接（本番） | BSD-3-Clause | flutter.dev 公式。Android では `camera_android_camerax` 0.7.6+1（BSD-3-Clause）経由で AndroidX CameraX（Apache-2.0）を使う |
| firebase_core | 5.1.0 | 直接（本番） | BSD-3-Clause | FlutterFire（Firebase 公式）。Android 側で Firebase Android SDK（Apache-2.0）を使う |
| cloud_firestore | 7.1.0 | 直接（本番） | BSD-3-Clause | FlutterFire。`alerts` の購読 |
| firebase_messaging | 17.0.1 | 直接（本番） | BSD-3-Clause | FlutterFire。トピック `demo-minato-bay` の購読 |
| firebase_remote_config | 7.0.1 | 直接（本番） | BSD-3-Clause | FlutterFire。行動ルールのしきい値の取得（`firebase_remote_config_platform_interface` 3.0.9・`firebase_remote_config_web` 1.10.16 も BSD-3-Clause） |
| flutter_local_notifications | 22.3.3 | 直接（本番） | BSD-3-Clause | Michael Bui。FCM のデータメッセージを 5 言語の通知にする |
| just_audio | 0.10.6 | 直接（本番） | MIT | Ryan Heise。Chirp 3 HD の MP3 の再生。LICENSE に「ExoPlayer（Apache-2.0）を含む」と併記あり（Android では AndroidX Media3 / ExoPlayer を使う） |
| flutter_tts | 4.2.5 | 直接（本番） | MIT | Daniel Lutton。数字など、音声ファイルのない部分を端末の TTS で読む |
| shared_preferences | 2.5.6 | 直接（本番） | BSD-3-Clause | flutter.dev 公式。選んだ言語の保存 |
| flutter_lints | 6.0.0 | 直接（開発） | BSD-3-Clause | 配布物には入らない |
| flutter_test | SDK | 直接（開発） | BSD-3-Clause | 配布物には入らない |
| ARCore SDK for Android（`com.google.ar:core`） | 1.57.0 | Android（Gradle） | **要確認 5** | 使用には Google APIs 利用規約と ARCore の追加規約が適用される。端末に Google Play Services for AR が要る（未インストールでもアプリはコンパス方式で動く） |
| Kotlin 標準ライブラリ・AndroidX | Flutter 3.47 の既定 | Android（Gradle） | Apache-2.0 | `flutter create` の既定の構成 |

方位センサー（コンパス）と「持ち上げたら AR」の傾きは pub のパッケージを使わず、Kotlin で自作した（`OrientationStream.kt`・`TiltStream.kt`）。

主な間接の依存（`pubspec.lock` の hosted のパッケージを LICENSE の本文で分類）:

| ライセンス | パッケージ |
|---|---|
| BSD-3-Clause | flutter.dev / dart.dev / FlutterFire の大半（`_flutterfire_internals`・各 `*_platform_interface`・`*_web`・`camera_android_camerax`・`shared_preferences_android`・`path_provider`・`jni`・`jni_flutter`・`jni_util`・`crypto`・`http`・`collection` など） |
| MIT | `audio_session` 0.2.4、`just_audio_platform_interface` 4.6.0、`just_audio_web` 0.4.16、`synchronized` 3.6.1、`uuid` 4.6.0、`petitparser` 7.0.2、`xml` 7.0.1、`yaml` 3.1.4 |
| Apache-2.0 | `rxdart` 0.28.0、`material_color_utilities` 0.13.0、`clock` 1.1.3、`fake_async` 1.3.3（テスト用） |
| BSD-2-Clause | `timezone` 0.11.2（`flutter_local_notifications` の依存） |
| MPL-2.0 | `dbus` 0.8.0（`flutter_local_notifications_linux` の依存。Linux 版だけで使い、Android の APK には入らないと考える。**要確認 11**） |

GPL などの強いコピーレフトのライセンスはない。

- フォントは Noto の可変フォントを同梱した（3.1）
- ランチャーアイコンは Flutter のテンプレートの既定のまま（要確認 6）
- 参考: [ARCore の利用規約](https://developers.google.com/ar/develop/terms)、[ARCore のプライバシーの要件](https://developers.google.com/ar/develop/privacy-requirements)

## 3. フォント

`mocks/evacuate/index.html` で Google Fonts の CSS を読み込み、`src/styles/tokens.css` で使っている。**フォントのファイルはリポジトリに同梱していない**（Google Fonts の CDN から配信）。

| フォント | 太さ | 用途 | ライセンス | 配信 |
|---|---|---|---|---|
| Nunito | 800, 900 | 見出し（ラテン文字） | SIL Open Font License 1.1 | Google Fonts（CDN） |
| Noto Sans | 400, 600, 700, 800 | 本文（ラテン文字） | SIL Open Font License 1.1 | Google Fonts（CDN） |
| Noto Sans JP | 400, 700, 900 | 日本語 | SIL Open Font License 1.1 | Google Fonts（CDN） |
| Noto Sans SC | 400, 700, 900 | 簡体中国語 | SIL Open Font License 1.1 | Google Fonts（CDN） |
| Noto Sans KR | 400, 700, 900 | 韓国語 | SIL Open Font License 1.1 | Google Fonts（CDN） |
| Noto Sans Arabic | 400, 700, 900 | アラビア語 | SIL Open Font License 1.1 | Google Fonts（CDN） |

- requirements.md に候補として書いた **M PLUS Rounded 1c は使っていない**
- 通信がないと読み込めず、端末のフォントで表示される。Flutter のアプリには同梱した（3.1、architecture.md D15）
- 参考: [Google Fonts の FAQ](https://developers.google.com/fonts/faq)

### 3.1 Flutter のアプリに同梱したフォント（`apps/ar_guide/assets/fonts/`）

architecture.md D15 に沿って、Noto をアプリに同梱した（`google_fonts` パッケージによる実行時の取得は使わない）。通信が切れても文字化けしない。

[google/fonts](https://github.com/google/fonts) のコミット `5bb28733cec313b63fbd415b574b5ae35c8aa8b8` の `ofl/<family>/` から、可変フォント（wght 100〜900）の TTF を**改変せずに**取得した。画面で使う太さ（400〜900）はすべてこの 1 ファイルから出る。ファイル名だけ `NotoSansJP[wght].ttf` → `NotoSansJP-VF.ttf` のように変えた。

| フォント | ファイル | バージョン | 大きさ | ライセンス | 取得元 |
|---|---|---|---|---|---|
| Noto Sans | `NotoSans-VF.ttf` | 2.015 | 2.0 MB | SIL Open Font License 1.1 | [`ofl/notosans/NotoSans[wdth,wght].ttf`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/notosans) |
| Noto Sans JP | `NotoSansJP-VF.ttf` | 2.004 | 9.6 MB | SIL Open Font License 1.1 | [`ofl/notosansjp/NotoSansJP[wght].ttf`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/notosansjp) |
| Noto Sans SC | `NotoSansSC-VF.ttf` | 2.004 | 17.8 MB | SIL Open Font License 1.1 | [`ofl/notosanssc/NotoSansSC[wght].ttf`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/notosanssc) |
| Noto Sans KR | `NotoSansKR-VF.ttf` | 2.004 | 10.4 MB | SIL Open Font License 1.1 | [`ofl/notosanskr/NotoSansKR[wght].ttf`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/notosanskr) |
| Noto Sans Arabic | `NotoSansArabic-VF.ttf` | 2.012 | 0.8 MB | SIL Open Font License 1.1 | [`ofl/notosansarabic/NotoSansArabic[wdth,wght].ttf`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/notosansarabic) |

- ライセンスの全文は同じフォルダに置き、APK にも入れて `LicenseRegistry` に登録した（`lib/src/fonts.dart` の `registerFontLicenses`）
  - `OFL-NotoSans.txt`: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic)
  - `OFL-NotoSansCJK.txt`（JP・SC・KR 共通）: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'
  - `OFL-NotoSansArabic.txt`: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/arabic)
- CJK の 3 つは予約フォント名（'Source'）があるので、サブセット化などの改変はしていない（改変すると名前を変える必要がある）
- 言語ごとの順番は Web と同じ（`lib/src/fonts.dart`）。ラテン文字は Noto Sans、漢字は画面の言語の CJK フォントを先に使う（簡体中国語に日本語の字形が出ない）。アラビア語は Noto Sans Arabic が先
- Web の見出しの Nunito は同梱していない（Noto Sans の同じ太さで代える）
- APK に入る大きさ: 24.2 MB（圧縮後。展開すると 40.7 MB）

## 4. 画像・ピクトグラム・アイコン

| 素材 | 場所 | 出所 | 状態 |
|---|---|---|---|
| ピクトグラム 6 点（頭を守る・屋外で身を守る・高台へ・ここで待機・車内で待つ・車を降りる） | `mocks/evacuate/src/components/pictograms/` | チームが SVG で描き起こしたもの（各ファイルの先頭に `original artwork` と記載） | 自作 |
| UI のアイコン（警告・地球儀・電話・スピーカーなど 18 種） | `mocks/evacuate/src/components/Icon.tsx` | インラインの SVG。外部のアイコンセットは依存に入っていない | 自作（パスを既存のアイコンセットから写していないかは、作った人に念のため確認） |
| 架空の町の地図 | `mocks/evacuate/src/components/TownMap.tsx`、`src/data/town.ts` | 座標から SVG で描画 | 自作 |
| AR の街路のイラスト | `mocks/evacuate/src/screens/_arScene.tsx` | SVG で描いたもの（`original SVG illustration`） | 自作 |
| AR の街路に描いた青い津波避難標識 | 同上 `EvacuationSign` | SVG で描いたもの | **要確認 3** |
| AR の背景写真 `public/ar/street.jpg` | （リポジトリにない） | 出所不明 | **要確認 2**。置かなければ自作の SVG を使うので、提出物には含まれない |
| 画面デザインの元資料 11 枚、機能一覧 7 枚、AR のデモガイド | `mocks/evacuate/docs/images/` | チームのメンバーがコミットしたもの | **要確認 1** |
| Android のランチャーアイコン | `apps/ar_guide/android/app/src/main/res/mipmap-*/` | Flutter のテンプレートの既定 | **要確認 6** |
| AR アプリの矢印 | `apps/ar_guide/lib/src/floor_arrow.dart`、`android/.../ar/ArrowRenderer.kt` | コードで描画 | 自作 |
| Flutter アプリのピクトグラム・地図 | `apps/ar_guide/lib/app/pictograms.dart`・`svg_path.dart`・`town_map.dart` | モックの自作 SVG（上の行）のパスを Dart に移したもの | 自作 |
| Flutter アプリの UI のアイコン（デモパネルのつまみの `Icons.tune` など） | Flutter の Material Icons（`uses-material-design: true` で MaterialIcons のフォントを同梱） | Google の Material Icons | Apache-2.0 |

## 5. 音声

| 素材 | 出所 | 状態 |
|---|---|---|
| 誘導画面の指示の音声ファイル（`mocks/evacuate/public/voice/<言語>/*.mp3` と `manifest.json`） | Google Cloud Text-to-Speech の Chirp 3 HD（声 Kore）で、チームが書いた文を読み上げて生成した（`tools/voice/generate.mjs`）。5 言語 × 18 文 = 90 件、合成 921 文字、MP3 合計約 0.65 MB。2026-11-09 に生成 | **要確認 4** |
| 同じ音声ファイルの Flutter アプリへの同梱（`apps/ar_guide/assets/voice/<言語>/*.mp3` と `manifest.json`、約 0.8 MB） | 上の 90 件のコピー（`pubspec.yaml` の `assets` で APK に入る） | **要確認 4** |
| 「日本語で助けを求める」カードの日本語音声（`apps/ar_guide/assets/voice/help/ja.mp3` と `manifest.json`、約 22 KB） | Google Cloud Text-to-Speech の Chirp 3 HD（`ja-JP-Chirp3-HD-Kore`）で、チームが書いた日本語の文を読み上げて生成した（`tools/voice/help-ja.mjs`）。1 件、合成 36 文字。2026-11-10 に生成 | **要確認 4** |
| 数値を含む文と、音声ファイルがないときの読み上げ | Web はブラウザの Web Speech API、Flutter は `flutter_tts` 経由の端末の TTS（いずれも端末の OS の音声）。ファイルは配らない | 確認不要と考える |

確認先:

- [Google Cloud の利用規約](https://cloud.google.com/terms) と [サービス固有の規約](https://cloud.google.com/terms/service-terms)
- [生成 AI の使用禁止に関するポリシー](https://policies.google.com/terms/generative-ai/use-policy)
- [Text-to-Speech のドキュメント（Chirp 3: HD の音声）](https://cloud.google.com/text-to-speech/docs/chirp3-hd)

## 6. 気象庁の電文の形式

- `services/alert-ingest/test/fixtures/` の電文 10 通は、**チームが作った架空の電文**。実在の警報ではない（各ファイルの先頭にそう書いている）
- 形式は気象庁の防災情報 XML（津波警報・注意報・予報 VTSE41）に合わせている。津波予報区の名前とコード（宮城県・福島県など）は気象庁のコード表のもの
- デモでは `DEMO_AREA_OVERRIDE=true` で、どの予報区の電文も架空の町「みなと湾」の警報として扱う
- 確認先（要確認 8）: [気象庁防災情報 XML フォーマット](https://xml.kishou.go.jp/)、[気象庁ホームページの利用規約](https://www.jma.go.jp/jma/kishou/info/coment.html)

## 7. 地図・地域のデータ

- 舞台は**架空の町「みなと湾（Minato Bay）」**。海岸線・危険区域・道路・標高・避難場所・住所・目印は、すべて `mocks/evacuate/src/data/` にチームが手で書いた値（`town.ts`・`landmarks.ts` の先頭に `Fictional ... NOT a real place` と記載）
- OpenStreetMap・国土地理院・国土数値情報・Google Maps Platform などの**実在の地図データは使っていない**（`src/` に該当する読み込みや URL がないことを確認した）
- 本番では OpenStreetMap（ODbL）と国土地理院・国土数値情報の公的データを使う予定で、そのときは出典をアプリに表示する（architecture.md 4.2）

## 8. 文章

- 画面の文言（5 言語）と防災コラムは、チームが書いたデモ用の文。中国語・韓国語・アラビア語はネイティブの確認をしていない
- 気象庁の案内（「海岸付近で強い揺れを感じたら警報を待たずに避難」など）は、内容を参考にした要約で、文の転載はしていない（**要確認 10**）

## 9. 開発に使ったツール（配布物には入らない）

Node.js・npm・Vite・TypeScript・tsx・FVM・Android SDK・Gradle・gcloud CLI・GitHub CLI。開発には AI のコーディング支援（Claude Code）を使った。
