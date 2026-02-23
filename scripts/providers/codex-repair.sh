#!/usr/bin/env bash
set -Eeuo pipefail

ATTEMPT_PATH="${AUTO_FIX_OPENCLAW_ATTEMPT_PATH:?missing AUTO_FIX_OPENCLAW_ATTEMPT_PATH}"
ERROR_SUMMARY_FILE="${AUTO_FIX_OPENCLAW_ERROR_SUMMARY_FILE:?missing AUTO_FIX_OPENCLAW_ERROR_SUMMARY_FILE}"
OPENCLAW_CONFIG_PATH="${AUTO_FIX_OPENCLAW_OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
SAFE_PATHS="${AUTO_FIX_OPENCLAW_SAFE_PATHS:-$HOME/.openclaw:$HOME/clawd}"
OPENCLAW_BIN="${AUTO_FIX_OPENCLAW_OPENCLAW_BIN:-openclaw}"
CODEX_BIN="${AUTO_FIX_OPENCLAW_CODEX_BIN:-$(command -v codex || true)}"
CODEX_MODEL="${AUTO_FIX_OPENCLAW_CODEX_MODEL:-gpt-5-codex}"
CODEX_TIMEOUT_SECS="${AUTO_FIX_OPENCLAW_CODEX_TIMEOUT_SECS:-240}"

if [[ -z "$CODEX_BIN" || ! -x "$CODEX_BIN" ]]; then
  echo "codex binary missing" >&2
  exit 2
fi

prompt_file="$ATTEMPT_PATH/codex-provider-prompt.txt"
output_file="$ATTEMPT_PATH/codex-output.log"
excerpt="$(sed -n '1,260p' "$ERROR_SUMMARY_FILE" 2>/dev/null || true)"

cat >"$prompt_file" <<EOF_PROMPT
Gateway health checks are failing.

Apply the minimal repair for OpenClaw startup/health.

Allowed write scope:
- ${SAFE_PATHS}

Hard rules:
- Do NOT edit files outside allowed write scope.
- Do NOT rotate or replace API keys/tokens.
- Prefer fixing malformed JSON/config references, stale service overrides, provider conflicts.
- Keep changes minimal and reversible.

Required verification:
1) python3 -m json.tool "${OPENCLAW_CONFIG_PATH}" > /dev/null (if file exists)
2) ${OPENCLAW_BIN} health --json

Artifacts path:
${ATTEMPT_PATH}

Error evidence excerpt:
${excerpt}
EOF_PROMPT

if command -v timeout >/dev/null 2>&1; then
  timeout "$CODEX_TIMEOUT_SECS" "$CODEX_BIN" exec \
    --full-auto \
    --sandbox workspace-write \
    --skip-git-repo-check \
    -m "$CODEX_MODEL" \
    -C "$HOME" \
    "$(cat "$prompt_file")" >"$output_file" 2>&1
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout "$CODEX_TIMEOUT_SECS" "$CODEX_BIN" exec \
    --full-auto \
    --sandbox workspace-write \
    --skip-git-repo-check \
    -m "$CODEX_MODEL" \
    -C "$HOME" \
    "$(cat "$prompt_file")" >"$output_file" 2>&1
else
  python3 - "$CODEX_TIMEOUT_SECS" "$CODEX_BIN" "$CODEX_MODEL" "$HOME" "$prompt_file" "$output_file" <<'PY'
import pathlib
import subprocess
import sys

timeout = int(sys.argv[1])
codex_bin = sys.argv[2]
model = sys.argv[3]
cwd = sys.argv[4]
prompt_file = pathlib.Path(sys.argv[5])
output_file = pathlib.Path(sys.argv[6])
prompt = prompt_file.read_text(encoding="utf-8", errors="ignore")

cmd = [
    codex_bin,
    "exec",
    "--full-auto",
    "--sandbox",
    "workspace-write",
    "--skip-git-repo-check",
    "-m",
    model,
    "-C",
    cwd,
    prompt,
]
with output_file.open("w", encoding="utf-8") as fp:
    try:
        proc = subprocess.run(cmd, stdout=fp, stderr=subprocess.STDOUT, timeout=timeout)
        sys.exit(proc.returncode)
    except subprocess.TimeoutExpired:
        sys.exit(124)
PY
fi
