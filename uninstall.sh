#!/usr/bin/env bash
set -Eeuo pipefail

PREFIX="${AUTO_FIX_OPENCLAW_INSTALL_PREFIX:-$HOME/.local}"
INSTALL_DIR="${PREFIX}/share/auto-fix-openclaw"
BIN_DIR="${PREFIX}/bin"
ENV_FILE="${HOME}/.config/openclaw/auto-fix-openclaw.env"
STATE_DIR="${HOME}/.auto-fix-openclaw"

KEEP_STATE=1
KEEP_ENV=1

usage() {
  cat <<'EOF_USAGE'
uninstall.sh - remove auto-fix-openclaw

Usage:
  uninstall.sh [options]

Options:
  --purge-state   Remove ~/.auto-fix-openclaw artifacts
  --purge-env     Remove ~/.config/openclaw/auto-fix-openclaw.env
  -h, --help      Show help
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-state)
      KEEP_STATE=0
      shift
      ;;
    --purge-env)
      KEEP_ENV=0
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

if [[ -x "$BIN_DIR/auto-fix-openclaw" ]]; then
  "$BIN_DIR/auto-fix-openclaw" uninstall-launchd >/dev/null 2>&1 || true
  "$BIN_DIR/auto-fix-openclaw" uninstall-systemd >/dev/null 2>&1 || true
fi

rm -f "$BIN_DIR/auto-fix-openclaw" "$BIN_DIR/fix-my-claw"
rm -rf "$INSTALL_DIR"

if [[ "$KEEP_STATE" -eq 0 ]]; then
  rm -rf "$STATE_DIR"
fi

if [[ "$KEEP_ENV" -eq 0 ]]; then
  rm -f "$ENV_FILE"
fi

echo "Uninstalled auto-fix-openclaw"
