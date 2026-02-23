#!/usr/bin/env bash
set -Eeuo pipefail

ATTEMPT_PATH="${AUTO_FIX_OPENCLAW_ATTEMPT_PATH:?missing AUTO_FIX_OPENCLAW_ATTEMPT_PATH}"
ERROR_SUMMARY_FILE="${AUTO_FIX_OPENCLAW_ERROR_SUMMARY_FILE:?missing AUTO_FIX_OPENCLAW_ERROR_SUMMARY_FILE}"
OPENCLAW_CONFIG_PATH="${AUTO_FIX_OPENCLAW_OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
SAFE_PATHS="${AUTO_FIX_OPENCLAW_SAFE_PATHS:-$HOME/.openclaw:$HOME/clawd}"
OPENCLAW_BIN="${AUTO_FIX_OPENCLAW_OPENCLAW_BIN:-openclaw}"
CLOUD_CODE_BIN="${AUTO_FIX_OPENCLAW_CLOUD_CODE_BIN:-$(command -v cloud-code || true)}"
CLOUD_CODE_MODEL="${AUTO_FIX_OPENCLAW_CLOUD_CODE_MODEL:-}"
CLOUD_CODE_TIMEOUT_SECS="${AUTO_FIX_OPENCLAW_CLOUD_CODE_TIMEOUT_SECS:-300}"
CLOUD_CODE_ARGS_TEMPLATE="${AUTO_FIX_OPENCLAW_CLOUD_CODE_ARGS_TEMPLATE:-exec --full-auto --cwd \"$HOME\" --prompt-file \"{PROMPT_FILE}\"}"

if [[ -z "$CLOUD_CODE_BIN" || ! -x "$CLOUD_CODE_BIN" ]]; then
  echo "cloud-code binary missing" >&2
  exit 2
fi

prompt_file="$ATTEMPT_PATH/cloudcode-provider-prompt.txt"
output_file="$ATTEMPT_PATH/cloudcode-output.log"
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

args="${CLOUD_CODE_ARGS_TEMPLATE}"
args="${args//\{PROMPT_FILE\}/$prompt_file}"
args="${args//\{CWD\}/$HOME}"
if [[ -n "$CLOUD_CODE_MODEL" ]]; then
  args="${args//\{MODEL\}/$CLOUD_CODE_MODEL}"
else
  args="${args//\{MODEL\}/}"
fi

cmd="$CLOUD_CODE_BIN $args"

if command -v timeout >/dev/null 2>&1; then
  timeout "$CLOUD_CODE_TIMEOUT_SECS" /bin/bash -lc "$cmd" >"$output_file" 2>&1
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout "$CLOUD_CODE_TIMEOUT_SECS" /bin/bash -lc "$cmd" >"$output_file" 2>&1
else
  /bin/bash -lc "$cmd" >"$output_file" 2>&1
fi
