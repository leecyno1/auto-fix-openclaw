#!/usr/bin/env bash
set -Eeuo pipefail

BIN="${1:-$HOME/.local/bin/auto-fix-openclaw}"

"$BIN" status
"$BIN" check || true
"$BIN" metrics >/dev/null
"$BIN" run-once --source smoke-test || true

echo "smoke test completed"
