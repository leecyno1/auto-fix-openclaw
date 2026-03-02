# auto-fix-openclaw 完整功能说明（中文）

## 1. 产品目标

`auto-fix-openclaw` 旨在解决 OpenClaw 网关在生产环境中的高频稳定性问题：

- 连接中断（断联）
- 升级后回归（配置漂移、依赖变化）
- 多环境、多工具链下的一致性维护成本

核心原则：

1. 先确定性修复，再 AI 兜底
2. 全流程可审计、可观测
3. 防抖优先，避免修复风暴

---

## 2. 功能模块

### 2.1 健康探测模块

能力：

- 调用 `openclaw health --json`
- 调用 `openclaw gateway status --json`

状态分层：

- `healthy`：health 检查通过
- `degraded`：health 不通过，但 gateway status 可达
- `unhealthy`：health 与 status 均失败

说明：

- `check` 命令会输出上述状态文本。
- `run-once` 默认只对 `unhealthy` 执行修复；`degraded` 由 `AUTO_FIX_OPENCLAW_REPAIR_ON_DEGRADED` 决定是否修复。

### 2.2 修复编排模块

执行顺序：

1. `gateway restart`
2. `doctor --repair`
3. service manager restart
4. AI provider 修复（主 provider + fallback）

终止条件：

- 任一层修复后探测恢复即停止后续层。

### 2.3 Reconcile 回放模块

触发条件：

- 版本变更（可配置）
- unhealthy 场景（可配置）

职责：

- 回放本地 overlay
- 合并自定义配置
- 可选执行 post-reconcile command

### 2.4 Patch Capture 模块

功能：

- 初始化 baseline
- 对比当前安装目录变更
- 生成 overlay 与 patch-manifest 记录

输出：

- `~/.config/openclaw/overlay/`
- `~/.config/openclaw/reconcile/patch-manifest.json`

### 2.5 AI Provider 模块

支持：

- Codex
- Claude Code

特性：

- 主 provider 失败后自动 fallback
- 传递错误摘要与上下文给 provider
- 修复后自动 restart + 二次探测

### 2.6 防抖与熔断模块

机制：

- 冷却窗口 `AUTO_FIX_OPENCLAW_REPAIR_COOLDOWN_SECS`
- 每日修复上限 `AUTO_FIX_OPENCLAW_MAX_DAILY_REPAIRS`
- 连续失败熔断 `AUTO_FIX_OPENCLAW_MAX_CONSECUTIVE_FAILURES`

目标：

- 防止频繁重复修复导致系统抖动。

### 2.7 审计与可观测模块

能力：

- attempt 级目录留痕
- `result.json` 记录最终状态和动作摘要
- `metrics.prom` 输出指标
- 支持多通道通知（通过 OpenClaw message）

---

## 3. 运行模式

### 3.1 `run-once`

执行单次“探测 -> 决策 -> 修复（如需）-> 落盘”。

### 3.2 `daemon`

后台循环执行 `run-once`，按 `CHECK_INTERVAL_SECS` 调度。

### 3.3 调度集成

- Linux：`systemd --user` timer
- macOS：`launchd`

---

## 4. 配置模型

配置文件：`~/.config/openclaw/auto-fix-openclaw.env`

关键配置分组：

- Core（探测周期、防抖、熔断）
- Reconcile（回放命令、触发策略）
- Capture（变更捕获）
- AI Provider（主备与超时）
- Notify（通道与事件）
- Safety/Compatibility

重点开关：

- `AUTO_FIX_OPENCLAW_COMMAND_EXEC_MODE=safe|shell`
- `AUTO_FIX_OPENCLAW_REPAIR_ON_DEGRADED=0|1`

---

## 5. 安全边界

### 5.1 命令执行模式

- `safe`：argv 解析执行，shell 操作符不解释
- `shell`：兼容旧配置，允许 shell 行为

建议：生产环境优先使用 `safe`。

### 5.2 AI 执行边界

- provider 在 `SAFE_PATHS` 首路径为 cwd 执行
- 结合 prompt 约束与路径边界，降低误改风险

---

## 6. 结果判定与状态语义

### 6.1 `check` 输出

- `healthy`
- `degraded`
- `unhealthy`

### 6.2 `run-once` 常见结果

- `healthy`
- `degraded`
- `repaired`
- `repaired-by-reconcile`
- `repaired-by-ai`
- `unhealthy-skipped`
- `unhealthy-failed`

---

## 7. 回归测试覆盖

已有回归脚本：`tests/regression/guards.sh`

覆盖场景：

- cooldown guard
- daily limit guard
- circuit-open guard
- reconcile command injection guard
- shell compatibility mode
- degraded semantics
- provider fallback success
- daemon lock regression

---

## 8. 典型使用场景

1. 线上长周期运行，自动守护连接稳定性
2. 升级后自动回放本地 customization
3. 多团队环境统一修复标准化流程
4. 夜间无人值守场景的自动恢复

---

## 9. 非目标（边界说明）

- 不承诺“永不故障”，而是追求“故障可控恢复”
- 不替代业务级容灾，仅聚焦 OpenClaw 网关稳定性治理

---

## 10. 建议实践

- 初次上线先 `run-once` + `doctor-dry-run` 验证
- 先开 `safe` 模式，再按兼容需要切 `shell`
- 为 degraded 场景设置明确运营策略（观测或修复）
- 定期复盘 `attempts/` 与 `metrics.prom`
