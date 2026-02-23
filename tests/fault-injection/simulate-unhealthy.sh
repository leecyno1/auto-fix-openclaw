#!/usr/bin/env bash
set -Eeuo pipefail

# Simulates unhealthy OpenClaw by overriding OPENCLAW_BIN with a stub.

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cat > "$WORKDIR/openclaw" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "health" ]]; then
  echo '{"ok":false}'
  exit 1
fi
if [[ "$1" == "gateway" && "$2" == "status" ]]; then
  echo '{"reachable":false}'
  exit 1
fi
exit 1
STUB
chmod +x "$WORKDIR/openclaw"

export OPENCLAW_BIN="$WORKDIR/openclaw"
export AUTO_FIX_OPENCLAW_REPAIR_PROVIDER=disabled
export AUTO_FIX_OPENCLAW_RECONCILE_ON_UNHEALTHY=0

"${HOME}/.local/bin/auto-fix-openclaw" run-once --source fault-injection || true

echo "fault injection finished"
