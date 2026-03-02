<p align="center">
  <img src="./assets/logo-autofix-openclaw.svg" width="140" alt="auto-fix-openclaw logo" />
</p>

<h1 align="center">auto-fix-openclaw</h1>

<p align="center">
  Production-grade self-heal framework for OpenClaw gateway.<br/>
  面向“断联、升级回归、跨环境适配”的持续自愈系统。
</p>

## 项目定位

`auto-fix-openclaw` 用于持续守护 OpenClaw 网关可用性，目标是将“人工抢修”升级为“自动探测 + 自动修复 + 可审计复盘”的工程化流程。

## 核心能力总览

### 1) 连续健康探测

- 周期执行：
  - `openclaw health --json`
  - `openclaw gateway status --json`
- 探测结果分层：
  - `healthy`
  - `degraded`（可达但健康不通过）
  - `unhealthy`

### 2) 分层修复链路（确定性优先）

- 第一层：`openclaw gateway restart`
- 第二层：`openclaw doctor --repair --non-interactive --yes`
- 第三层：service manager 重启（`systemctl --user` / `launchctl`）
- 第四层：AI provider 兜底（Codex / Claude Code，支持 fallback）

### 3) 升级回放（Reconcile）

- 版本变更可触发 reconcile
- 支持 overlay + custom config 回放
- 用于降低升级后连接漂移/回归风险

### 4) 捕获与审计

- 每次尝试写入 `~/.auto-fix-openclaw/attempts/<timestamp>/`
- 关键产物：
  - `result.json`
  - `error-summary.txt`
  - `*.log` / `*.exit`
- 输出 Prometheus 文本指标：`metrics.prom`

### 5) 稳定性保护（反抖）

- 冷却窗口（cooldown）
- 每日修复上限（daily cap）
- 连续失败熔断（circuit breaker）
- 单实例锁（防并发修复）

### 6) 安全与兼容模式

- `AUTO_FIX_OPENCLAW_COMMAND_EXEC_MODE=safe|shell`
  - `safe`（默认）：argv 解析执行，降低注入风险
  - `shell`：兼容历史 shell 语法配置
- `AUTO_FIX_OPENCLAW_REPAIR_ON_DEGRADED=0|1`
  - `0`：degraded 默认记录不修复
  - `1`：degraded 进入修复链路

## 快速开始

```bash
cd auto-fix-openclaw
./install.sh --launchd --init-baseline   # macOS
# or
./install.sh --systemd --init-baseline   # Linux

auto-fix-openclaw status
auto-fix-openclaw run-once --source bootstrap-verify
```

## 常用命令

```bash
auto-fix-openclaw status
auto-fix-openclaw run-once --source manual
auto-fix-openclaw repair-now --provider codex
auto-fix-openclaw repair-now --provider claudecode
auto-fix-openclaw check
auto-fix-openclaw metrics
auto-fix-openclaw doctor-dry-run
auto-fix-openclaw reset-state
```

## 文档索引（功能与运维）

- 完整功能说明：`docs/feature-spec.zh-CN.md`
- 架构说明：`docs/architecture.md`
- 配置参考：`docs/config-reference.md`
- 运维手册：`docs/runbook.md`
- 迁移说明：`docs/migration-from-fix-my-claw.md`

## 目录结构

- `bin/auto-fix-openclaw`：主 CLI
- `config/auto-fix-openclaw.env.example`：配置模板
- `scripts/reconcile-openclaw-custom.sh`：升级回放脚本
- `scripts/capture-openclaw-custom.sh`：补丁捕获脚本
- `scripts/providers/*.sh`：AI provider 适配脚本
- `deploy/systemd-user/*`：Linux 用户态服务
- `deploy/launchd/*`：macOS launchd 配置
- `tests/*`：回归与验证脚本

## License

MIT
