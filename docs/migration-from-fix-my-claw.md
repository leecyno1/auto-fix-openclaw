# Migration from fix-my-claw

`auto-fix-openclaw` accepts legacy `FIX_MY_CLAW_*` env variables.

Recommended migration:

1. install new project via `install.sh`
2. copy values from `~/.config/openclaw/fix-my-claw.env` into `~/.config/openclaw/auto-fix-openclaw.env`
3. rename to `AUTO_FIX_OPENCLAW_*`
4. switch launchd/systemd to new units
5. uninstall old fix-my-claw deployment
