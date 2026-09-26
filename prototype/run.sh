#!/usr/bin/env bash
# PROTOTYPE — 960×400 AM01S 布局，三个方向。throwaway，别合进 main。
# 用法：bash prototype/run.sh [A|B|C]   关掉：Ctrl+C
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
snap=/tmp/pub-proto-snapshot.json
if [ ! -s "$snap" ]; then
  node "$here/../../pub/extension/bin/pub-engine.mjs" snapshot --out "$snap" >/dev/null
fi
PUB_PROTO_VARIANT="${1:-A2}" PUB_PROTO_DIR="$here" exec quickshell -p "$here/shell.qml"
