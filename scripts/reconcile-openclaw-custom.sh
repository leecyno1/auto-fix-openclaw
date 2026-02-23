#!/usr/bin/env bash
set -Eeuo pipefail

# Replay local customizations after OpenClaw upgrade or repair.

OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
OPENCLAW_INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-}"

CUSTOM_NPM_DEPS="${CUSTOM_NPM_DEPS:-@larksuiteoapi/node-sdk}"
CUSTOM_OVERLAY_DIR="${CUSTOM_OVERLAY_DIR:-$HOME/.config/openclaw/overlay}"
CUSTOM_CONFIG_OVERRIDE="${CUSTOM_CONFIG_OVERRIDE:-$HOME/.config/openclaw/custom-overrides.json}"
CUSTOM_POST_RECONCILE_CMD="${CUSTOM_POST_RECONCILE_CMD:-}"

resolve_install_dir() {
  if [[ -n "$OPENCLAW_INSTALL_DIR" ]]; then
    echo "$OPENCLAW_INSTALL_DIR"
    return 0
  fi
  if [[ -n "$OPENCLAW_BIN" ]]; then
    python3 - "$OPENCLAW_BIN" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1]).resolve()
if path.is_file():
    path = path.parent

for _ in range(12):
    pkg = path / "package.json"
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        if data.get("name") == "openclaw":
            print(path)
            sys.exit(0)
    if path.parent == path:
        break
    path = path.parent
sys.exit(1)
PY
    return $?
  fi
  return 1
}

deep_merge_json() {
  local base="$1"
  local override="$2"
  python3 - "$base" "$override" <<'PY'
import json
import pathlib
import sys

base_path = pathlib.Path(sys.argv[1])
override_path = pathlib.Path(sys.argv[2])

base = json.loads(base_path.read_text(encoding="utf-8"))
override = json.loads(override_path.read_text(encoding="utf-8"))

def merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = merge(out[k], v) if k in out else v
        return out
    return b

merged = merge(base, override)
base_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(str(base_path))
PY
}

echo "[reconcile] start"

install_dir="$(resolve_install_dir || true)"
if [[ -n "$install_dir" ]]; then
  echo "[reconcile] openclaw install dir: $install_dir"
else
  echo "[reconcile] warning: openclaw install dir not resolved, skip install-dir operations"
fi

if [[ -n "$install_dir" && -n "${CUSTOM_NPM_DEPS// }" ]]; then
  # shellcheck disable=SC2086
  npm install --prefix "$install_dir" $CUSTOM_NPM_DEPS
fi

if [[ -n "$install_dir" && -d "$CUSTOM_OVERLAY_DIR" ]]; then
  echo "[reconcile] applying overlay: $CUSTOM_OVERLAY_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$CUSTOM_OVERLAY_DIR"/ "$install_dir"/
  else
    cp -a "$CUSTOM_OVERLAY_DIR"/. "$install_dir"/
  fi
fi

if [[ -f "$CUSTOM_CONFIG_OVERRIDE" && -f "$OPENCLAW_CONFIG_PATH" ]]; then
  echo "[reconcile] merging config override: $CUSTOM_CONFIG_OVERRIDE"
  deep_merge_json "$OPENCLAW_CONFIG_PATH" "$CUSTOM_CONFIG_OVERRIDE"
  python3 -m json.tool "$OPENCLAW_CONFIG_PATH" >/dev/null
fi

if [[ -n "$CUSTOM_POST_RECONCILE_CMD" ]]; then
  echo "[reconcile] running post hook"
  /bin/bash -lc "$CUSTOM_POST_RECONCILE_CMD"
fi

if [[ -n "$OPENCLAW_BIN" ]]; then
  "$OPENCLAW_BIN" gateway restart || true
  sleep 6
  "$OPENCLAW_BIN" health --json || true
fi

echo "[reconcile] done"
