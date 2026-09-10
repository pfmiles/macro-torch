# Phase 30: cpBuild 双保判定改造 - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning
**Origin:** 会话锁定决策（替代 discuss-phase；用户拍板"由我生成 CONTEXT.md"）
**Research:** 跳过（用户拍板；本对话已完成域调研）。本运行无 RESEARCH.md / VALIDATION.md——用户在研究前置门预选了"继续"，记为已确认的 gate override。

<domain>
## Phase Boundary

改造 cpBuild 测量系统为"双保判定"实证 instrumentation：

1. **保留并强化开关门控**：`macroTorch.cpBuildLog`（全局布尔，nil-guard 默认 false）是唯一持久化门——只有开关开启时 `[cpBuild]`/`[cpBuildT]` 行才经 `macroTorch.log` 写入 `MACRO_TORCH_LOG`；关闭时零 API 调用。
2. **新增双保判定 live 计时器**（DKI，double-keep instrumentation）：bite→满星耗时采样状态机，0.1s 轮询 `GetComboPoints()`，输出 `[cpBuildT]` 持久化行。
3. **新增离线分析脚本** `tools/cpbuild.lua`（用户拍板"连带离线分析脚本"）：T̄ / 实测达标率 / T 分布直方图 / 窗口结果矩阵。

范围锚定：不改 catAtk 决策逻辑、不改 [cpBuild] 既有行语义、D-06 范围锁不动（不记录 bite 行）；不动其它持久化通道（cpDamage 零触碰）。

## 为什么是这个判据形态（背景，规划时保持一致性）

- 双保判据 = bite 同时刷新 Rake+Rip 的机制下，"只靠 bite 维持双流血"是否可行的数学开关，模型见 `.planning/notes/cat-double-keep-threshold.md`（`P(N ≤ s) ≥ β`，`s = ⌊(D_rake−1)/k⌋`）。
- 理论推导已被放弃（暴击阈值→技能间隔 k→平均加星速度，三代判据逐步逼近"系统级直接测量"）。
- **最终锁定的判据形态**：实测 `T̄(bite→满5星) + 1s(bite GCD) < D_rake`，辅以实测达标率 `P(T ≤ D_rake−1)` 作为可调 β 口径。数据源必须是"目标态循环"（见 D-09 附注）。
</domain>

<decisions>
## Implementation Decisions

### 开关与持久化政策（用户明确要求）
- **D-01:** `macroTorch.cpBuildLog` 全局开关保留不变：nil-guard 默认 false、登录重置、`/run macroTorch.cpBuildLog=true` 热开。**所有 cpBuild 家族输出（[cpBuild] + [cpBuildT]）仅在该开关开启时走 `macroTorch.log` 持久化**；开关关闭时采样与轮询路径零 API 调用（短路段与既有 `macroTorch.cpBuildLog and ... or nil` 形状一致）。

### [cpBuild] 既有行（继承，不改）
- **D-02:** `[cpBuild] <skill> t=<t> cp=<cp> e=<e>` 行语义逐字节不变（Claw/Shred/Rake 被接受施法的施法前采样；`cpBuildLogSample`/`cpBuildLogEvent`，Druid.lua:348-371）。
- **D-03:** D-06 范围锁保留：cpBuild 永不记录 bite 行（Rip/FB/Pounce 同理）；bite 锚点由 DKI 的 cp 下跳检测提供，不需要 bite 行。

### DKI 状态机协议（封版）
- **D-04:** 三态 + 旁路：
  - `WAIT_ANCHOR → BUILDING`：`GetComboPoints()` 从 >1 下跳至 ≤1 记锚 t₀；
    - **cp=0 双义消歧**：同轮采样背查目标——目标完好 → 无残留天赋的 bite（真锚）；目标变化/死亡 → 取消回 WAIT_ANCHOR，不计样本。
  - `BUILDING → DONE`：cp 首达 5 记 t₁，样本 `T = t₁ − t₀` 落盘；
  - `DONE`：静默直到下一锚点（一窗一样本，窗口互斥）；
  - 旁路 1（截断）：BUILDING 中 cp 再次 >1→≤1 下跳（低星斩杀咬，无残留天赋时同样经 0-背查识别）→ 无样本，**计未达标分母 +1**；
  - 旁路 2（全局重置，优先级最高）：`PLAYER_TARGET_CHANGED` 或脱战（`PLAYER_REGEN_ENABLED` → `onCombatExit()`，events.lua 现成挂点）→ 回 WAIT_ANCHOR、丢弃进行中窗口**不计**（既不入 T̄ 也不入分母）；重置只清状态不清历史样本簿。
- **D-05:** 采样载具 = `periodic.lua` 0.1s 周期任务轮询 `comboPoints`（accessor `GetComboPoints() or 0`，Druid.lua:441-443）；锚点/里程碑误差 ≤0.1s（已拍板接受）。战斗未开始时轮询任务不注册/空转（零成本路径）。
- **D-06:** 输出行协议：
  - 完成窗口：`[cpBuildT] ok t=<sec>`
  - 截断窗口：`[cpBuildT] fail`
  - 取消/全局重置：不写任何行
  - 行格式走 `macroTorch.log`（聊天 + MACRO_TORCH_LOG 双写，受 D-01 门控）。

### 离线分析脚本（纳入本 phase，用户拍板）
- **D-07:** `tools/cpbuild.lua` 采用**路线 A 自包含**：复制 `tools/cpdamage.lua` 的 harness（readAll / extractMacroTorchLog / loadBlockSandboxed / getMessages / countList / CLI 模式 / selftest 电池范式），不触碰 cpdamage.lua。Lua 5.0 方言纪律与 cpdamage 一致（D-15）。
- **D-08:** 指标输出：按技能施法数；k（inter-cast interval）均值与直方图（1.5s 判定线分桶 `[<1.5),[1.5,2),[2,3),[3,5),[5,10),[≥10)`）；**断链切分**——[cpBuild] 无 batch 字段，相邻 t 差 > 阈值（文件头常量，默认 30s）视为跨战斗/跑路断链，不计入 k 统计；[cpBuildT] 统计：T̄、T 分布直方图、达标率 `P(T ≤ D_rake−1)`（D_rake 用实际值：默认 9s，Savagery 快照 ×0.9 → 8.1s，做成参数/双档输出）、窗口结果矩阵 ok/fail；dropped 统计（badLines）；`--selftest` 与 `--json-out` 对齐 cpdamage CLI。
- **D-09（附注，非代码）:** 打桩须在**目标态循环**下进行（现行循环每窗口硬打 Rake 补贴 +1 星且耗能最低 32e，会系统性低估真实 T̄ 并混淆能量轮廓）——记录为 UAT/实机验证前置条件，写入 SUMMARY 供用户执行时知悉。

### 工程约束（继承项目惯例）
- **D-10:** Lua 5.0 语法纪律（禁 `#` 长度运算符、禁 goto/label；自验需覆盖 5.0）。
- **D-11:** `SM_Extend.lua` 是构建产物，**永不手工编辑**；改动只落源码，构建由用户侧 build.sh 执行。
- **D-12:** 行尾 LF（.gitattributes 已建立）；每任务 bbcheck `BALANCED`（tools 在 `.planning/phases/27-.../tools/bbcheck.js`）+ `git diff --check`。
- **D-13:** selftest 扩展：按 CR-01 stub 纪律（rawget 快照 → 自有 key 遮蔽 → rawset 恢复**在 assert 之前**）新增 Category S-04+（状态机六转移 + 全局重置 + 开关门控的 stubbed 单测：`GetComboPoints`/`GetTime`/`macroTorch.log` 捕获）；`isOptional=true`。
- **D-14:** 本机（Linux）无 Lua 运行时——工具脚本 `--selftest` 与游戏内 selftest 的实机执行在用户的 Windows+Cygwin 环境；静态验证命令（bbcheck/grep 门/diff --check）在本机可跑。

### 明确不做
- 不改 `shouldDoReshift` 及任何 catAtk 决策（`RESHIFT_E_DIFF_THRESHOLD` 死常量原样保留，不在本 phase 接线）。
- 不动 `.planning/notes/cat-double-keep-threshold.md` 数学文档（残留星天赋的口径修正是否落文档另议，不进本 phase 代码范围）。
- 不注册新的客户端事件（计时器轮询自持；事件侧只复用 PLAYER_TARGET_CHANGED / PLAYER_REGEN_ENABLED 的既有 handler 挂点）。
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 改造面（本 phase）
- `classes/druid/Druid.lua` — cpBuildLogSample/cpBuildLogEvent（344-371）、comboPoints accessor（441-443）、D-06 范围锁注记（64-66）
- `macro_torch.lua` — cpBuildLog 开关模式（22-28）、CONFIG_OPTIONS 注册表（71-75）
- `core/periodic.lua` — 0.1s 周期任务框架（registerPeriodicTask/setRepeat、leastUpdateInterval=0.1）
- `core/events.lua` — PLAYER_TARGET_CHANGED（25/73）、PLAYER_REGEN_ENABLED→onCombatExit（30/90-93）
- `interface_debug.lua` — macroTorch.log（106-124，聊天 + MACRO_TORCH_LOG 双写 + 上限裁剪）
- `classes/druid/cat.lua` — safeBite/tryBiteKillShot 等咬击语义（214-222、441-459），仅作理解不修改

### 离线工具范式
- `tools/cpdamage.lua` — harness 范式全文（readAll/extractMacroTorchLog/loadBlockSandboxed/getMessages/CLI/selftest 电池）+ Lua 5.0 纪律 + fixture 坏行模式（1179-1190 对 [cpBuild] 行的处理是先例）

### 判据背景（只读）
- `.planning/notes/cat-double-keep-threshold.md` — 双保判据模型（P(N≤s)≥β、E₀/E₁、节奏墙、c\*(k) 表）
- `.planning/quick/260907-0ya-macrotorch-false-true-macrotorch-log/260907-0ya-SUMMARY.md` — [cpBuild] 立项溯源（double-keep measurement 原始目标）
- `.planning/ROADMAP.md` — Phase 30 Goal 摘要
</canonical_refs>