# Architecture

## Repair pipeline

1. Probe health (`openclaw health --json`, `openclaw gateway status --json`)
2. If version changed, run reconcile first
3. If unhealthy, run reconcile-on-unhealthy (optional)
4. Deterministic repair chain:
   - `openclaw gateway restart`
   - `openclaw doctor --repair --non-interactive --yes`
   - service manager restart (`systemctl --user` / `launchctl kickstart`)
5. AI repair provider (`codex` / `cloudcode`) with fallback
6. Verify and persist artifacts (`result.json`, logs, summaries)

## Main controls

- Locking: single instance via runtime lock dir
- Anti-flap: cooldown, daily cap, circuit breaker
- Audit: per-attempt directory under `~/.auto-fix-openclaw/attempts/`
- Notification: event-level dispatch using OpenClaw channel plugins

## Integrations

- OpenClaw CLI and channel plugins
- Codex CLI adapter
- Cloud Code adapter
- systemd (Linux user mode), launchd (macOS user mode)
