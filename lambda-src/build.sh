#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

npm install --no-audit --no-fund --silent
npx tsc -p tsconfig.json

mkdir -p ../build

for fn in ingest notify; do
  rm -f "../build/${fn}.zip"
  (cd "dist/${fn}" && zip -q -X -r "../../../build/${fn}.zip" handler.js)
done

echo "built build/ingest.zip build/notify.zip"
