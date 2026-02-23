# Runbook

## First-time bootstrap

1. Install with scheduler:
   - macOS: `./install.sh --launchd --init-baseline`
   - Linux: `./install.sh --systemd --init-baseline`
2. Configure notifications in env
3. Run `auto-fix-openclaw run-once --source bootstrap-verify`
4. Check `auto-fix-openclaw status`

## Recovery verification

- `auto-fix-openclaw check`
- `auto-fix-openclaw run-once --source manual-check`
- inspect latest attempt in `~/.auto-fix-openclaw/attempts/`

## If circuit breaker opens

- inspect latest `result.json`
- inspect `error-summary.txt`
- fix root cause
- `auto-fix-openclaw reset-state`
- rerun `auto-fix-openclaw run-once --source post-fix`

## Force diagnostics without mutation

- `auto-fix-openclaw doctor-dry-run`

## Upgrade OpenClaw safely

1. update OpenClaw
2. run `auto-fix-openclaw run-once --source post-upgrade`
3. confirm reconcile + health checks are green
