#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p ../build

for fn in ingest notify; do
  rm -f "../build/${fn}.zip"
  (cd "$fn" && zip -q -X -r "../../build/${fn}.zip" handler.py)
done

echo "built build/ingest.zip build/notify.zip"
