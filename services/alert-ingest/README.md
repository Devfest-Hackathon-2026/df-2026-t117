# alert-ingest（警報の取り込みと配信）

ハッカソン実装範囲 H1（[architecture.md 10 節](../../mocks/evacuate/docs/architecture.md#10-ハッカソン実装範囲2026-11-09-締切)）。
気象庁の防災情報 XML（津波警報・注意報・予報 VTSE41）を受け取り、Firestore に記録して二重送信を防ぎ（D6）、FCM のトピックと Web のクライアント（H2）へ配信する Cloud Run サービス。

```
電文（XML）─POST /ingest─▶ Cloud Run: alert-ingest
                              ├─ 解析（種別・高さ・到達予想時刻・予報区・EventID・Serial・InfoType）
                              ├─ Firestore sentAlerts/{EventID_Serial_InfoType} を create()（作れた処理だけが送る）
                              ├─ Firestore alerts/{EventID} に最新の状態を書く（モックが購読）
                              ├─ FCM トピック demo-minato-bay にデータだけを送る（優先度 高）
                              └─ Firestore fcmTokens の全トークンへ同じデータを sendEachForMulticast（Web のモック用、H2）
```

- 本番の受け口（気象庁電文の即時配信サービス（外部の有料サービス）の WebSocket・気象庁 Atom フィード）は使わず、電文を ID トークン付きで直接送る（10.2）
- 認証はアプリでは行わない。Cloud Run の IAM（`--no-allow-unauthenticated`）で守る
- 表示する文言はクライアントが多言語データから選ぶ。サーバーは種別・レベルなどのデータだけを送る
- Web の FCM SDK はトピックを直接購読できない。そのため、モック（`mocks/evacuate`）が通知の許可を得たときに自分のトークンを `fcmTokens`（自動 ID）に書き、このサービスがトピック送信に加えて全トークンへ送る（[architecture.md 10.4](../../mocks/evacuate/docs/architecture.md#104-h2-の構成モックへの警報の反映)）

## 処理の流れ

1. 電文を解析する。津波警報・注意報・予報以外の電文、`ALLOWED_STATUSES` にない運用種別（既定では「試験」）、対象の予報区を含まない電文は配信しない（`ignored`）
2. `sentAlerts/{EventID}_{Serial}_{InfoType}` を `create()` で作る（状態 `sending`）
   - すでにあれば送らない（`duplicate`）。別の処理が送っている途中なら `in-progress`（503 と `Retry-After` を返し、送信元に再送させる。その処理が落ちていても、`STALE_SENDING_MS` のあとの再送で送り直せる）
   - `failed` の記録や、`sending` のまま `STALE_SENDING_MS` たった記録は取り直して送り直す
   - Firestore に届かない（UNAVAILABLE / DEADLINE_EXCEEDED）ときだけ、記録なしで送る（D7、`sent-unrecorded`）。権限の不足など、それ以外の Firestore のエラーでは送らずに 500 を返す
3. `alerts/{EventID}` を書き換える（トランザクション）。`change` は、送信に成功した最新の状態（`notified`）と比べる。送信に失敗した電文や送信中に止まった電文の再送でも、格上げを取りこぼさない。電文の新しさは (Serial, 発表 < 訂正) で比べ、書かれている状態より古い電文は書かず、送らない（`superseded`）。取消は Serial によらず反映し、その EventID の最後の状態として固定する（以後の発表・訂正は `superseded`。`serial` は最大値を保つ）
4. FCM に送り、記録の `sent` と `alerts/{EventID}.notified` の更新を 1 つのトランザクションで書く。送信に失敗したら `failed` にして 502 を返す（再送すれば送り直す）
5. トピックへの送信に成功したら、`fcmTokens` のうち `expireAt` が未来のもの（`expireAt` の新しい順に最大 `MAX_WEB_TOKENS` 件。読み出しは 3 秒で諦める）を読み、同じトークンをまとめてから、同じメッセージを 500 件ずつ `sendEachForMulticast` で送る。`invalid-argument`（トークンの形式の誤り。偽のトークン）・`registration-token-not-registered`・`invalid-registration-token` で失敗したトークンは、そのトークンのドキュメントをすべて削除する。`unavailable`・`internal`・`quota-exceeded` などの一時的なエラーでは消さない。この送信は追加の経路なので、失敗しても電文の結果は変えない（再送させるとトピックに二重に送るため。モックの状態は Firestore の購読で更新される）。結果は応答とログの `webPush`（`tokens` / `success` / `failure` / `removed` / `skipped` / `error`）に出す
   - 記録なしで送る経路（D7、Firestore に届かないとき）では `fcmTokens` を読まず、トピックだけに送る（`webPush.skipped = "firestore-unreachable"`）

### 応答

| 結果 | HTTP | 意味 |
|---|---|---|
| `sent` / `sent-unrecorded` | 200 | 送った |
| `duplicate` / `superseded` / `ignored` | 200 | 送らなかった（再送は不要） |
| `in-progress` | 503 | 別の処理が送っている途中。`Retry-After`（`STALE_SENDING_MS` の秒数）のあとに再送する |
| `invalid` | 400 | 電文が読めない |
| `failed` | 502 | FCM への送信に失敗（再送してよい） |
| `sent-unconfirmed` | 503 | FCM には送ったが、送信後の記録を書けなかった。`Retry-After` のあとに再送する（送り直して記録と基準をそろえる。二重の通知はアプリが警報 ID で消す） |

## データの形

### `alerts/{EventID}`（モックが購読する）

| フィールド | 例 | 内容 |
|---|---|---|
| `alertId` / `eventId` | `"20261108094000"` | 警報 ID（= EventID）。通知の collapse key にも使う |
| `serial` | `3` | 電文の Serial |
| `infoType` | `"発表"` | 発表 / 訂正 / 取消 |
| `jmaStatus` | `"訓練"` | 通常 / 訓練 / 試験 |
| `kind` | `"major-tsunami-warning"` | `major-tsunami-warning` / `tsunami-warning` / `tsunami-advisory` / `cleared` / `cancelled` |
| `level` | `"emergency"` | モックの `AlertLevel` と同じ（`advisory` / `warning` / `emergency`）。解除・取消は `null` |
| `change` | `"height-up"` | `new` / `upgrade` / `downgrade` / `height-up` / `height-down` / `same` / `cleared` / `cancelled` |
| `previousKind` / `previousLevel` | | 前の状態 |
| `maxHeight` | `{ meters: 10, label: null, description: "１０ｍ超", over: true }` | 予想される高さ。「巨大」「高い」は `label` に入り `meters` は `null`。本文に数値がなければ description（全角）から読む |
| `expectedHeight` | `3` / `"over10"` / `"huge"` | モックの `ExpectedHeight`（`1 | 3 | 5 | 10 | 'over10' | 'huge' | 'high'`）と同じ形（requirements.md F84）。「10m 超」は `over10`、「巨大」は `huge`、「高い」は `high`。区分外の値は、それ以上の最小の区分に切り上げる（例: 3.5 → `5`。元の値は `maxHeight`）。高さの比較では巨大 = 10m 超、高い = 3m として扱う |
| `arrivalTime` | `"2026-11-08T10:05:00+09:00"` | 到達予想時刻 |
| `arrivalCondition` | `"ただちに津波来襲と予測"` | 時刻の代わりの状況（第１波の到達を確認 など） |
| `issuedAt` | `"2026-11-08T10:00:00+09:00"` | 発表時刻（Head/ReportDateTime） |
| `areaId` / `areaName` | `"minato-bay"` / `"みなと湾（架空）"` | 町 |
| `sourceAreas` | `[{ code, name, kindName }]` | 判断の元にした電文の津波予報区 |
| `headline` | | 電文の見出し（日本語。参考用） |
| `notified` | `{ serial, infoType, kind, level, maxHeight }` | 送信に成功した最新の状態。`change` の基準（クライアントは使わなくてよい） |
| `updatedAt` | | 書いた時刻 |

町の状態は、対象の予報区のうち最も重い項目（レベル → 高さの順）の種別・高さ・到達予想時刻で表す。

### FCM の data（すべて文字列）

`type`（`tsunami`）, `alertId`, `eventId`, `serial`, `infoType`, `jmaStatus`, `kind`, `level`（解除・取消は `none`）, `change`, `issuedAt`, `areaId`, あれば `expectedHeight`（`1` / `3` / `5` / `10` / `over10` / `huge` / `high`）, `heightMeters`, `heightOver`, `heightLabel`, `arrivalTime`, `arrivalCondition`。

Android は優先度 high・`collapseKey` = 警報 ID、Web Push は `Urgency: high`・`Topic` = 警報 ID。他社 OS の通知基盤はデータだけの通知を優先度の低いバックグラウンド通知としてしか送れないので、他社 OS での表示は本番のアプリ（重大な警報の通知の許可、D10）で扱う。

### `fcmTokens/{自動 ID}`（Web のクライアントが作る）

| フィールド | 内容 |
|---|---|
| `token` | FCM の登録トークン |
| `createdAt` | 書いた時刻（`serverTimestamp()`） |
| `expireAt` | 登録の期限。書いた時刻から 47 時間後（クライアントの時計で計算）。TTL で消す |
| `platform` | `web-android` / `web-mobile` / `web-desktop` |

ルール（`firestore.rules`）: クライアントは create だけができる。フィールドはこの 4 つだけ、`token` は 20〜1024 文字、`createdAt` = リクエストの時刻、`expireAt` はリクエストの時刻より後で 2 日以内、`platform` は 32 文字以内。読む・変える・消すはサーバーだけ。

公開の Web 設定だけで誰でも作れるので、偽のトークンを大量に書いて本物を押し出す攻撃に備えて次のようにしている（App Check は使わない）。

- 登録は 2 日以内に切れ、TTL で消える。モックは開くたびに（同じトークンでも 1 時間以上たっていれば）新しいドキュメントとして登録し直すので、本物のトークンは常に新しい側に残る
- サーバーは有効期限内のものだけを新しい順に `MAX_WEB_TOKENS`（既定 200）件読む。偽のトークンは送信すると `invalid-argument` になるので削除する
- ドキュメント ID をトークンにしないのは、update を禁止したまま登録し直せるようにするため（同じ ID の 2 回目の書き込みは update 扱いになり拒否される）。同じトークンの重複はサーバーがまとめる
- `expireAt == request.time + 2 日` をルールで直接は検査できない（クライアントは serverTimestamp に時間を足せない）ので、「request.time より後、2 日以内」を検査する

### `sentAlerts/{EventID}_{Serial}_{InfoType}`（サーバーだけ）

`state`（`sending` / `sent` / `failed` / `superseded` / `skipped`）, `attempts`, `createdAt`, `updatedAtMs`, `sentAt`, `messageId`, `error`, `expireAt`。`expireAt` に Firestore の TTL ポリシーを設定して古い記録を消す。

## 設定（環境変数）

| 名前 | 既定値 | 内容 |
|---|---|---|
| `DEMO_AREA_OVERRIDE` | `false` | `true` なら、どの津波予報区の電文でも「みなと湾」の警報として扱う（デモでは `true`） |
| `TARGET_AREA_CODES` | （なし） | `DEMO_AREA_OVERRIDE=false` のとき対象にする津波予報区コード（カンマ区切り） |
| `FCM_TOPIC` | `demo-minato-bay` | 配信先のトピック |
| `AREA_ID` / `AREA_NAME` | `minato-bay` / `みなと湾（架空）` | 町の ID と名前 |
| `ALLOWED_STATUSES` | `通常,訓練` | 配信する運用種別。デモで訓練電文を使うため「訓練」を含めている。**本番の取得元（D4）につなぐ前に「訓練」を外す** |
| `STALE_SENDING_MS` | `60000` | `sending` のまま、この時間たったら送り直してよい |
| `SENT_TTL_DAYS` | `7` | `sentAlerts.expireAt` の日数 |
| `MAX_BODY_BYTES` | `1000000` | 受け付ける本文の上限 |
| `MAX_WEB_TOKENS` | `200` | `fcmTokens` のうち読む最大数（有効期限内、新しい順）。`0` なら Web へは送らない |

秘密情報は使わない。Firestore と FCM へは、実行時サービスアカウントの ADC で接続する（鍵ファイルは作らない）。

## ローカルでの開発

依存パッケージを導入し、型チェック・テスト・ビルドを行う。

```sh
npm ci
npm test        # 型チェック + テスト（Firestore と FCM は fake）
npm run build
```

テスト用の電文は `test/fixtures/` にある。気象庁の電文の形式（VTSE41）に合わせた**架空の電文**で、実在の警報ではない。

| ファイル | 内容 |
|---|---|
| `01-warning-issued.xml` | 津波警報の発表（宮城県 3m、福島県は注意報） |
| `02-major-upgrade.xml` | 大津波警報への格上げ（5m） |
| `03-height-raised.xml` | 高さの引き上げ（10m 超、ただちに来襲） |
| `04-downgrade-advisory.xml` | 津波注意報への格下げ |
| `05-cleared.xml` | 解除 |
| `11`〜`13` | 別の地震での注意報の発表・訂正・取消 |
| `21-tall-qualitative.xml` | 定性的な高さ（巨大・高い） |
| `91-tsunami-info.xml` | 対象外の電文（津波情報） |

## デプロイ手順

2026-11-09 にこの手順でデプロイした（H2 の内容でリビジョン 2）。デプロイ用のサービスアカウント（鍵なし。gcloud でなりすまして使う）には、`--source` のデプロイに要るバケット作成の権限を与えていない。そのため、ローカルでコンテナのイメージをビルドして Artifact Registry に push し、`--image` でデプロイする。

前提: プロジェクト `devfest2026-oauthmountains`、リージョン `asia-northeast1`、Firestore（Native モード）と FCM が有効。

```sh
PROJECT=devfest2026-oauthmountains
REGION=asia-northeast1
SA=alert-ingest@${PROJECT}.iam.gserviceaccount.com
REPO=<Artifact Registry のコンテナ用リポジトリ名>
IMAGE=${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/alert-ingest:$(git rev-parse --short HEAD)

# 1. 実行時サービスアカウント（鍵は作らない）
gcloud iam service-accounts create alert-ingest --project "$PROJECT" \
  --display-name "TASUKU alert-ingest"
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member "serviceAccount:${SA}" --role roles/datastore.user
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member "serviceAccount:${SA}" --role roles/firebasecloudmessaging.admin

# 2. イメージをローカルでビルドして push（services/alert-ingest で実行）
gcloud auth configure-docker "${REGION}-docker.pkg.dev"
docker build -t "$IMAGE" .
docker push "$IMAGE"

# 3. デプロイ
gcloud run deploy alert-ingest --project "$PROJECT" --region "$REGION" \
  --image "$IMAGE" \
  --service-account "$SA" \
  --no-allow-unauthenticated \
  --min-instances 0 --max-instances 2 \
  --set-env-vars DEMO_AREA_OVERRIDE=true,FCM_TOPIC=demo-minato-bay

# 4. 電文を送る人に呼び出し権限を付ける（未認証の公開はしない）
gcloud run services add-iam-policy-binding alert-ingest --project "$PROJECT" --region "$REGION" \
  --member "user:<送る人のアカウント>" --role roles/run.invoker

# 5. Firestore のルールと TTL（firebase.json が firestore.rules を参照する）
firebase deploy --only firestore:rules --project "$PROJECT"
gcloud firestore fields ttls update expireAt --collection-group sentAlerts \
  --enable-ttl --project "$PROJECT"
gcloud firestore fields ttls update expireAt --collection-group fcmTokens \
  --enable-ttl --project "$PROJECT"
```

- デプロイする人（またはなりすますサービスアカウント）に要る権限: Artifact Registry のリポジトリへの書き込み（`roles/artifactregistry.writer`）、Cloud Run のデプロイ（`roles/run.developer` 相当）、実行時 SA への `roles/iam.serviceAccountUser`。Cloud Build とバケット作成の権限は要らない
- 手順 5（Firestore のルールの反映と TTL の有効化）は、2026-11-09 時点では反映予定
- Firebase CLI を使わない場合は、Firebase コンソールの Firestore →「ルール」に `firestore.rules` の内容を貼り付けて公開する
- `fcmTokens` の TTL（`expireAt`）は、有効になるまで数分〜数十分かかる。TTL の削除は期限から最大 24 時間ほど遅れることがあるが、サーバーは `expireAt` が未来のものだけを読むので、遅れても送り先には入らない
- `fcmTokens` の読み出し（`expireAt` の範囲と並べ替え。単一フィールドのインデックスで足りる）と削除にも、実行時 SA の `roles/datastore.user` を使う（追加の権限は不要）。Web Push の証明書（VAPID 鍵）の公開鍵は、モックの `src/platform/firebaseConfig.ts` にある

## デモでの送り方

```sh
# 1 通送る
scripts/send-sample.sh test/fixtures/01-warning-issued.xml

# 発表 → 格上げ → 高さの引き上げ → 格下げ → 解除 を 8 秒おきに送る（EventID は毎回新しくなる）
scripts/send-sample.sh --scenario
```

`gcloud auth print-identity-token` の ID トークンを付けて送る。送る人のアカウントに `roles/run.invoker` が必要。
同じ電文を送り直すと二重送信の防止で `duplicate` になるので、繰り返すときは `EVENT_ID=$(date +%Y%m%d%H%M%S)` を付ける。
