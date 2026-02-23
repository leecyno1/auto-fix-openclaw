#!/usr/bin/env bash
set -Eeuo pipefail

# Capture custom OpenClaw code changes into a replayable overlay.
# Supports per-version baselines and patch manifest history.

OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
OPENCLAW_INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-}"
CUSTOM_CAPTURE_BASE_DIR="${CUSTOM_CAPTURE_BASE_DIR:-$HOME/.config/openclaw/reconcile}"
CUSTOM_CAPTURE_BASELINES_DIR="${CUSTOM_CAPTURE_BASELINES_DIR:-$CUSTOM_CAPTURE_BASE_DIR/baselines}"
CUSTOM_CAPTURE_OVERLAY_DIR="${CUSTOM_CAPTURE_OVERLAY_DIR:-$HOME/.config/openclaw/overlay}"
CUSTOM_CAPTURE_INCLUDE_PATHS="${CUSTOM_CAPTURE_INCLUDE_PATHS:-dist,plugins,package.json}"
CUSTOM_CAPTURE_UPDATE_BASELINE="${CUSTOM_CAPTURE_UPDATE_BASELINE:-1}"
CUSTOM_CAPTURE_MANIFEST_JSON="${CUSTOM_CAPTURE_MANIFEST_JSON:-$CUSTOM_CAPTURE_BASE_DIR/patch-manifest.json}"

usage() {
  cat <<'EOF_USAGE'
capture-openclaw-custom.sh

Usage:
  capture-openclaw-custom.sh init-baseline   Build baseline checksums for current OpenClaw version
  capture-openclaw-custom.sh diff            Show changed/new/deleted files
  capture-openclaw-custom.sh capture         Export changed/new files to overlay and write patch-manifest.json
  capture-openclaw-custom.sh version         Print detected OpenClaw version
EOF_USAGE
}

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

openclaw_version() {
  if [[ -z "$OPENCLAW_BIN" ]]; then
    echo "unknown"
    return 0
  fi
  "$OPENCLAW_BIN" --version 2>/dev/null | head -n 1 | tr -cd '[:alnum:]._-'
}

baseline_path_for_version() {
  local version="$1"
  echo "$CUSTOM_CAPTURE_BASELINES_DIR/${version}.sha256"
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

list_candidate_files() {
  local install_dir="$1"
  IFS=',' read -r -a includes <<<"$CUSTOM_CAPTURE_INCLUDE_PATHS"
  local found_any=0
  for rel in "${includes[@]}"; do
    rel="$(echo "$rel" | xargs)"
    [[ -z "$rel" ]] && continue
    local path="$install_dir/$rel"
    if [[ -f "$path" ]]; then
      found_any=1
      printf "%s\n" "$path"
    elif [[ -d "$path" ]]; then
      found_any=1
      find "$path" -type f
    fi
  done

  if [[ "$found_any" -eq 0 ]]; then
    find "$install_dir" -type f ! -path "*/node_modules/*" ! -path "*/.git/*"
  fi
}

build_manifest() {
  local install_dir="$1"
  local out_file="$2"
  : >"$out_file"
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    local rel hash
    rel="${file#$install_dir/}"
    hash="$(sha256_file "$file")"
    printf "%s\t%s\n" "$hash" "$rel" >>"$out_file"
  done < <(list_candidate_files "$install_dir" | sort)
}

require_baseline() {
  local baseline="$1"
  if [[ ! -f "$baseline" ]]; then
    echo "baseline not found: $baseline" >&2
    echo "run: $0 init-baseline" >&2
    exit 1
  fi
}

diff_manifests() {
  local baseline="$1"
  local current="$2"
  python3 - "$baseline" "$current" <<'PY'
import pathlib
import sys

baseline_path = pathlib.Path(sys.argv[1])
current_path = pathlib.Path(sys.argv[2])

def load(path):
    out = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        hash_, rel = line.split("\t", 1)
        out[rel] = hash_
    return out

b = load(baseline_path)
c = load(current_path)

for rel in sorted(set(b) | set(c)):
    if rel not in b:
        print(f"new\t{rel}")
    elif rel not in c:
        print(f"deleted\t{rel}")
    elif b[rel] != c[rel]:
        print(f"changed\t{rel}")
PY
}

append_patch_manifest() {
  local diff_file="$1"
  local version="$2"
  local install_dir="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  python3 - "$CUSTOM_CAPTURE_MANIFEST_JSON" "$diff_file" "$timestamp" "$version" "$install_dir" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
diff_path = pathlib.Path(sys.argv[2])
timestamp = sys.argv[3]
version = sys.argv[4]
install_dir = sys.argv[5]

items = []
for line in diff_path.read_text(encoding="utf-8", errors="ignore").splitlines():
    if not line.strip():
        continue
    status, rel = line.split("\t", 1)
    items.append({"status": status, "path": rel})

if manifest_path.exists():
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        data = {"captures": []}
else:
    data = {"captures": []}

captures = data.setdefault("captures", [])
captures.append({
    "time": timestamp,
    "openclawVersion": version,
    "installDir": install_dir,
    "changeCount": len(items),
    "changes": items,
})

manifest_path.parent.mkdir(parents=True, exist_ok=True)
manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(str(manifest_path))
PY
}

cmd="${1:-}"
install_dir="$(resolve_install_dir || true)"
if [[ -z "$install_dir" && "$cmd" != "help" && "$cmd" != "--help" && "$cmd" != "-h" && "$cmd" != "" ]]; then
  echo "cannot resolve openclaw install dir; set OPENCLAW_INSTALL_DIR" >&2
  exit 1
fi

mkdir -p "$CUSTOM_CAPTURE_BASE_DIR" "$CUSTOM_CAPTURE_BASELINES_DIR" "$CUSTOM_CAPTURE_OVERLAY_DIR"
version="$(openclaw_version)"
baseline_file="$(baseline_path_for_version "$version")"

case "$cmd" in
  init-baseline)
    build_manifest "$install_dir" "$baseline_file"
    echo "baseline created: $baseline_file"
    ;;
  diff)
    require_baseline "$baseline_file"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    build_manifest "$install_dir" "$tmp"
    diff_manifests "$baseline_file" "$tmp"
    ;;
  capture)
    require_baseline "$baseline_file"
    tmp_manifest="$(mktemp)"
    tmp_diff="$(mktemp)"
    trap 'rm -f "$tmp_manifest" "$tmp_diff"' EXIT
    build_manifest "$install_dir" "$tmp_manifest"
    diff_manifests "$baseline_file" "$tmp_manifest" >"$tmp_diff"

    changed_count=0
    deleted_count=0
    while IFS=$'\t' read -r status rel; do
      [[ -n "${status:-}" ]] || continue
      src="$install_dir/$rel"
      dst="$CUSTOM_CAPTURE_OVERLAY_DIR/$rel"
      case "$status" in
        new|changed)
          mkdir -p "$(dirname "$dst")"
          cp -f "$src" "$dst"
          changed_count=$((changed_count + 1))
          ;;
        deleted)
          rm -f "$dst"
          deleted_count=$((deleted_count + 1))
          ;;
      esac
    done <"$tmp_diff"

    append_patch_manifest "$tmp_diff" "$version" "$install_dir" >/dev/null

    if [[ "$CUSTOM_CAPTURE_UPDATE_BASELINE" == "1" ]]; then
      cp "$tmp_manifest" "$baseline_file"
    fi

    echo "captured files: $changed_count, removed overlay files: $deleted_count, version: $version"
    echo "patch manifest: $CUSTOM_CAPTURE_MANIFEST_JSON"
    ;;
  version)
    echo "$version"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    usage
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
