#!/usr/bin/env bash
# デモ用: テスト用の電文を、ID トークン付きで alert-ingest に送る。
#
# 使い方:
#   scripts/send-sample.sh test/fixtures/01-warning-issued.xml [ほかの電文 ...]
#   scripts/send-sample.sh --scenario            # 発表 → 格上げ → 引き上げ → 格下げ → 解除 を順に送る
#
# 環境変数:
#   SERVICE_URL  送り先（省略時は gcloud で alert-ingest の URL を調べる）
#   REGION       既定 asia-northeast1
#   EVENT_ID     指定すると電文の EventID を置き換える。同じ電文でデモを繰り返すとき、
#                二重送信の防止で止まらないよう、毎回新しい値（例: $(date +%Y%m%d%H%M%S)）にする
#   INTERVAL     --scenario で電文の間に待つ秒数（既定 8）
#
# 呼び出す人のアカウントに、サービスの roles/run.invoker が必要。
set -euo pipefail

cd "$(dirname "$0")/.."

REGION="${REGION:-asia-northeast1}"
INTERVAL="${INTERVAL:-8}"

if [[ $# -eq 0 ]]; then
  sed -n '2,16p' "$0"
  exit 1
fi

files=()
if [[ "$1" == "--scenario" ]]; then
  files=(
    test/fixtures/01-warning-issued.xml
    test/fixtures/02-major-upgrade.xml
    test/fixtures/03-height-raised.xml
    test/fixtures/04-downgrade-advisory.xml
    test/fixtures/05-cleared.xml
  )
  EVENT_ID="${EVENT_ID:-$(date +%Y%m%d%H%M%S)}"
else
  files=("$@")
fi

if [[ -z "${SERVICE_URL:-}" ]]; then
  SERVICE_URL="$(gcloud run services describe alert-ingest --region "$REGION" --format 'value(status.url)')"
fi
TOKEN="$(gcloud auth print-identity-token)"

first=1
for f in "${files[@]}"; do
  if [[ $first -eq 0 && "${1:-}" == "--scenario" ]]; then
    sleep "$INTERVAL"
  fi
  first=0
  body="$(cat "$f")"
  if [[ -n "${EVENT_ID:-}" ]]; then
    body="$(printf '%s' "$body" | sed -E "s#<EventID>[^<]*</EventID>#<EventID>${EVENT_ID}</EventID>#")"
  fi
  echo "==> $f${EVENT_ID:+ (EventID=$EVENT_ID)}"
  printf '%s' "$body" | curl -sS -X POST "$SERVICE_URL/ingest" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/xml; charset=utf-8" \
    --data-binary @- \
    -w '\n(HTTP %{http_code})\n'
done
