#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PREFIX="${HOME}/.local"
PREFIX="${AUTO_FIX_OPENCLAW_INSTALL_PREFIX:-$DEFAULT_PREFIX}"
INSTALL_DIR="${PREFIX}/share/auto-fix-openclaw"
BIN_DIR="${PREFIX}/bin"
ENV_FILE="${HOME}/.config/openclaw/auto-fix-openclaw.env"

INSTALL_LAUNCHD=0
INSTALL_SYSTEMD=0
INIT_BASELINE=0

usage() {
  cat <<'EOF_USAGE'
install.sh - install auto-fix-openclaw into ~/.local

Usage:
  install.sh [options]

Options:
  --launchd         Install macOS launchd agent
  --systemd         Install Linux systemd user timer
  --init-baseline   Initialize custom patch baseline after install
  -h, --help        Show help
EOF_USAGE
}

set_env_line() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf "%q" "$value")"
  mkdir -p "$(dirname "$ENV_FILE")"
  touch "$ENV_FILE"
  python3 - "$ENV_FILE" "$key" "$escaped" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
out = []
found = False
for line in lines:
    if line.startswith(f"{key}="):
        out.append(f"{key}={value}")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"{key}={value}")
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

set_env_default() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf "%q" "$value")"
  mkdir -p "$(dirname "$ENV_FILE")"
  touch "$ENV_FILE"
  python3 - "$ENV_FILE" "$key" "$escaped" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
if any(line.startswith(f"{key}=") for line in lines):
    sys.exit(0)
lines.append(f"{key}={value}")
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --launchd)
      INSTALL_LAUNCHD=1
      shift
      ;;
    --systemd)
      INSTALL_SYSTEMD=1
      shift
      ;;
    --init-baseline)
      INIT_BASELINE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$(dirname "$ENV_FILE")"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SCRIPT_DIR"/ "$INSTALL_DIR"/
else
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  cp -a "$SCRIPT_DIR"/. "$INSTALL_DIR"/
fi

chmod +x "$INSTALL_DIR/bin/auto-fix-openclaw" "$INSTALL_DIR/install.sh"
chmod +x "$INSTALL_DIR/scripts/"*.sh
chmod +x "$INSTALL_DIR/scripts/providers/"*.sh

ln -sf "$INSTALL_DIR/bin/auto-fix-openclaw" "$BIN_DIR/auto-fix-openclaw"
ln -sf "$INSTALL_DIR/bin/auto-fix-openclaw" "$BIN_DIR/fix-my-claw"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$INSTALL_DIR/config/auto-fix-openclaw.env.example" "$ENV_FILE"
fi

set_env_line "AUTO_FIX_OPENCLAW_RECONCILE_CMD" "$INSTALL_DIR/scripts/reconcile-openclaw-custom.sh"
set_env_default "AUTO_FIX_OPENCLAW_CAPTURE_CMD" "$INSTALL_DIR/scripts/capture-openclaw-custom.sh capture"
set_env_default "AUTO_FIX_OPENCLAW_CAPTURE_ON_HEALTHY" "1"
set_env_default "AUTO_FIX_OPENCLAW_CAPTURE_INTERVAL_SECS" "21600"
set_env_default "AUTO_FIX_OPENCLAW_REPAIR_PROVIDER" "codex"
set_env_default "AUTO_FIX_OPENCLAW_REPAIR_PROVIDER_FALLBACK" "claudecode"
set_env_default "AUTO_FIX_OPENCLAW_CODEX_BIN" "$(command -v codex || true)"
set_env_default "AUTO_FIX_OPENCLAW_CLAUDE_CODE_BIN" "$(command -v claude || command -v claude-code || true)"
set_env_line "AUTO_FIX_OPENCLAW_CLAUDE_CODE_ARGS_TEMPLATE" "exec --full-auto --cwd {CWD} --prompt-file {PROMPT_FILE} --model {MODEL}"

chmod 600 "$ENV_FILE"

if [[ "$INSTALL_LAUNCHD" -eq 1 ]]; then
  "$INSTALL_DIR/bin/auto-fix-openclaw" install-launchd
fi

if [[ "$INSTALL_SYSTEMD" -eq 1 ]]; then
  "$INSTALL_DIR/bin/auto-fix-openclaw" install-systemd
fi

if [[ "$INIT_BASELINE" -eq 1 ]]; then
  "$INSTALL_DIR/scripts/capture-openclaw-custom.sh" init-baseline
fi

echo "Installed auto-fix-openclaw:"
echo "  binary  : $BIN_DIR/auto-fix-openclaw"
echo "  alias   : $BIN_DIR/fix-my-claw"
echo "  home    : $INSTALL_DIR"
echo "  env file: $ENV_FILE"
echo
echo "Next:"
echo "  1) ensure PATH has $BIN_DIR"
echo "  2) run: auto-fix-openclaw status"
echo "  3) run: auto-fix-openclaw run-once --source install-check"
