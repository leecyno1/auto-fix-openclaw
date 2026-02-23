# auto-fix-openclaw

Production-grade self-heal framework for OpenClaw gateway.

## What it does

- Monitors gateway health continuously (`openclaw health --json`, `openclaw gateway status --json`)
- Applies deterministic repair chain first (restart -> doctor -> service manager)
- Replays local custom customizations after upgrades (`reconcile`)
- Captures local code patches automatically (`baseline + overlay + patch-manifest.json`)
- Supports AI-assisted repair backends:
  - Codex (`codex` CLI)
  - Cloud Code (`cloud-code` adapter)
- Sends alert/recovery notifications through OpenClaw channels (Feishu, Telegram, Discord, etc.)
- Emits Prometheus text metrics (`metrics.prom`)

## Repository layout

- `bin/auto-fix-openclaw` - main CLI
- `config/auto-fix-openclaw.env.example` - runtime config template
- `scripts/reconcile-openclaw-custom.sh` - replay local customizations
- `scripts/capture-openclaw-custom.sh` - capture local code changes
- `scripts/providers/codex-repair.sh` - Codex repair adapter
- `scripts/providers/cloudcode-repair.sh` - Cloud Code repair adapter
- `deploy/systemd-user/*` - Linux user services/timer
- `deploy/launchd/com.openclaw.autofix.plist` - macOS launchd agent
- `install.sh` / `uninstall.sh` - install lifecycle scripts

## Install

```bash
cd auto-fix-openclaw
./install.sh --launchd --init-baseline   # macOS
# or
./install.sh --systemd --init-baseline   # Linux
```

Installed paths (default):

- binary: `~/.local/bin/auto-fix-openclaw`
- alias: `~/.local/bin/fix-my-claw`
- home: `~/.local/share/auto-fix-openclaw`
- env: `~/.config/openclaw/auto-fix-openclaw.env`
- runtime artifacts: `~/.auto-fix-openclaw/`

## Quick operations

```bash
auto-fix-openclaw status
auto-fix-openclaw run-once --source manual
auto-fix-openclaw check
auto-fix-openclaw metrics
auto-fix-openclaw doctor-dry-run
auto-fix-openclaw reset-state
```

## AI repair backends

Set in env:

```bash
AUTO_FIX_OPENCLAW_REPAIR_PROVIDER=codex
AUTO_FIX_OPENCLAW_REPAIR_PROVIDER_FALLBACK=cloudcode
```

### Codex

```bash
AUTO_FIX_OPENCLAW_CODEX_BIN=/opt/homebrew/bin/codex
AUTO_FIX_OPENCLAW_CODEX_MODEL=gpt-5-codex
```

### Cloud Code

```bash
AUTO_FIX_OPENCLAW_CLOUD_CODE_BIN=cloud-code
AUTO_FIX_OPENCLAW_CLOUD_CODE_ARGS_TEMPLATE='exec --full-auto --cwd "{CWD}" --prompt-file "{PROMPT_FILE}" --model "{MODEL}"'
```

## Notifications (Feishu/Telegram/Discord)

Use OpenClaw channel delivery via `openclaw message send`.

```bash
AUTO_FIX_OPENCLAW_NOTIFY_ENDPOINTS=feishu:oc_xxx,telegram:-1001234567890,discord:123456789012345678
AUTO_FIX_OPENCLAW_NOTIFY_ON=failed,recovered,reconcile
AUTO_FIX_OPENCLAW_NOTIFY_ACCOUNT=main
```

Endpoint format:

- `channel:target`
- `channel:target:account`

## Custom patch capture and replay

Initialize baseline per OpenClaw version:

```bash
~/.local/share/auto-fix-openclaw/scripts/capture-openclaw-custom.sh init-baseline
```

Capture later changes:

```bash
~/.local/share/auto-fix-openclaw/scripts/capture-openclaw-custom.sh capture
```

Outputs:

- `~/.config/openclaw/overlay/` - replayable overlay files
- `~/.config/openclaw/reconcile/patch-manifest.json` - change history
- `~/.config/openclaw/reconcile/baselines/<version>.sha256` - per-version baseline

## Safety model

- Single lock prevents concurrent heal loops
- Cooldown + daily cap + circuit breaker prevent flap storms
- AI repair only after deterministic repair chain fails
- AI write scope constrained by `AUTO_FIX_OPENCLAW_SAFE_PATHS`

## Uninstall

```bash
./uninstall.sh
# optional full cleanup
./uninstall.sh --purge-state --purge-env
```
