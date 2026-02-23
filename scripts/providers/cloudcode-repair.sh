#!/usr/bin/env bash
set -Eeuo pipefail
# Backward-compat alias. Use claudecode-repair.sh.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/claudecode-repair.sh" "$@"
