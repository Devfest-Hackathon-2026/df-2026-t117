# Remote Config: 行動ルール

architecture.md D1・2 節の「行動ルール Remote Config のキャッシュ」。アプリ（`apps/ar_guide`）は起動時に Remote Config を取得して有効化し、しきい値をシナリオの初期状態に使う。有効化した値は端末に残るので、オフラインでも前回取得したルールで動く。

| パラメータ | 型 | アプリ内の既定値 | 受け付ける範囲 | 使う場所 |
| --- | --- | --- | --- | --- |
| `rules_version` | 文字列 | `builtin` | 1〜64 文字 | デモパネルの「行動ルール」 |
| `margin_ample_m` | 数値 | 10 | 0〜30 | 余裕ありとする差（m） |
| `huge_min_elev_m` | 数値 | 20 | 0〜40 | 10 m 超のとき必要な標高（m） |
| `stale_threshold_min` | 数値 | 10 | 1〜30 | 鮮度しきい値（分） |

- 範囲外・数値でない値は、その項目だけアプリ内の既定値にする（`lib/app/state/action_rules.dart`）
- google-services.json がない・取得に失敗した・何も公開していないときは既定値。表示は「既定値」
- 取得に失敗して前回の値を使ったときは「キャッシュ」、今回取得できたときは「Remote Config」
- 取得は起動時に 1 回（タイムアウト 5 秒、最短の取得間隔 30 分）。デモパネルのスライダーで上書きでき、リセット・シナリオ選択でルールの値に戻る

## 公開する

`template.json` のパラメータを、今のテンプレートに上書きで混ぜて公開する（ほかのパラメータ・条件は残す）。

```sh
node tools/remote-config/publish.mjs            # 確認だけ（混ぜた結果を表示）
node tools/remote-config/publish.mjs --publish  # 公開
```

- REST API: `GET https://firebaseremoteconfig.googleapis.com/v1/projects/devfest2026-oauthmountains/remoteConfig` で ETag を取り、`PUT`（`If-Match: <ETag>`）で公開する
- トークンは `gcloud auth print-access-token --impersonate-service-account=$IMPERSONATE`（`IMPERSONATE` の既定はスクリプトに書いた開発用のサービスアカウント）。自分の gcloud ログインで公開するときは `IMPERSONATE= node ...`、手元のトークンを使うときは `ACCESS_TOKEN=...`
- サービスアカウントのキーは作らない
- 権限: 使うアカウントに「Firebase Remote Config 管理者」（`roles/firebaseremoteconfig.admin`）が要る。ないと `GET_TEMPLATE` の `PERMISSION_DENIED` になる
- コンソール（Firebase コンソール → Remote Config）で同じパラメータを手で追加してもよい

ルールを変えたら `rules_version` も上げる（例: `2026-11-10.2`）。
