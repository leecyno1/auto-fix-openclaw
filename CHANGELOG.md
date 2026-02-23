# Changelog

## 2.0.0

- Rename project to `auto-fix-openclaw`
- Cross-platform scheduler packaging (launchd + systemd)
- Add dual AI provider repair adapters (Codex + Claude Code) with fallback
- Add patch capture manifest (`patch-manifest.json`) with versioned baselines
- Add event-level notification policy and multi-channel endpoint routing
- Add Prometheus text metrics output
- Add dry-run diagnostics command
- Add uninstall script and migration docs

## 2.0.1

- Remove deprecated `cloudcode` provider naming and wrapper script
- Keep only `codex` and `claudecode` provider names
- Add `repair-now --provider codex|claudecode` for direct CLI repair trigger
