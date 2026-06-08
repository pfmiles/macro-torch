# Phase 2: 事件系统模块化拆分 - Context

**Gathered:** 2026-06-08
**Status:** Ready for planning

<domain>
## Phase Boundary

将 `battle_event_queue.lua`（468 行）按职责拆分到 `core/events.lua`、`core/combat_context.lua`、`core/spell_trace_core.lua`、`core/spell_trace_immune.lua`。拆分后 `battle_event_queue.lua` 完全删除，所有 `macroTorch.*` 函数在新文件中重新定义。

覆盖需求: R3 (战斗事件系统模块化), R6 (core/ 目录)
</domain>

<decisions>
## Implementation Decisions

### 事件注册架构
- **D-01:** 采用集中式。`core/events.lua` 创建一个 Frame 注册全部 14 个事件，`eventHandle` 内部通过 if-elseif 直接 dispatch 到 combat_context 和 spell_trace 函数。不引入回调注册表或事件总线。

### spell_trace 拆分粒度
- **D-02:** 采用双文件拆分。`core/spell_trace_core.lua`（约 235 行）：cast/fail/land table 管理 + CheckDodgeParryBlockResist + DEBUFF_LAND_LAG + tracingSpells/traceSpellImmunes 初始化 + setSpellTracing/setTraceSpellImmune + peek/consume 查询函数。`core/spell_trace_immune.lua`（约 70 行）：loadImmuneTable + loadDefiniteBleedingTable + spellsImmuneTracing。

### 模块间依赖方向
- **D-03:** 采用直接函数调用 + 调整 build_order 顺序。`combat_context.lua` 和 `spell_trace_core.lua` / `spell_trace_immune.lua` 放在 `events.lua` 之前，events.lua 直接调用已定义的 `macroTorch.*` 函数。不引入 stub、回调注册或中间抽象层。

### battle_event_queue 清理
- **D-04:** 完全删除。Phase 2 拆分完成后删除 `battle_event_queue.lua` 并从 `build_order.txt` 移除该条目。拆分验证通过 grep 确认所有 18 个 `macroTorch.*` 函数在新文件中已重新定义，外部调用方（SM_Extend_Druid.lua 5 个函数、entity/Target.lua 2 个函数）引用完整。

### build_order 调整
- **D-05:** 新文件顺序：`core/periodic.lua` → `core/combat_context.lua` → `core/spell_trace_core.lua` → `core/spell_trace_immune.lua` → `core/events.lua`。保证函数定义先于调用方加载。

### Claude's Discretion
- eventHandle 中 if-elseif dispatch 的具体分支实现
- spell_trace_core 和 spell_trace_immune 之间的精确函数分配（在 250 行约束下调整）
- 各文件中 local Frame 变量命名
- 迁移后的注释保留策略
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 2 完整实施步骤（2.1-2.4）、文件变更清单、验证命令
- `.planning/REQUIREMENTS.md` — R3 验收标准（battle_event_queue ≤10 行或删除、4 个 core/ 模块各 ≤250 行）
- `docs/REFACTOR_PLAN.md` — 原始重构计划 Step 3（battle_event_queue 拆分依据）

### Phase 1 决策（影响 Phase 2）
- `.planning/phases/01-classmetatable-entity/01-CONTEXT.md` — D-09（build_order.txt 一次性全量）、D-10（容错构建模式）、D-14（periodic.lua 独立 Frame）

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — Event/Context Layer 架构、Combat Event Tracking Flow、Periodic Task Scheduler
- `.planning/codebase/STRUCTURE.md` — 文件布局、构建拼接顺序、全局单例位置
- `.planning/codebase/CONVENTIONS.md` — 函数命名约定、全局命名空间模式、module 设计

### API 参考
- `.claude-reference/Functions.md` — WoW 1.12.1 完整 Macro API（CreateFrame, RegisterEvent, SetScript 等）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **battle_event_queue.lua** (468 行): 源文件，含 18 个 `macroTorch.*` 函数。eventHandle (~80 行 if-elseif)，spell trace 函数组 (~300 行)，combat context 逻辑 (~30 行)，immune 加载 (~60 行)。
- **core/periodic.lua**: Phase 1 产出，已包含 LRUStack + registerPeriodicTask + onPeriodicUpdate。spell_trace 的 maintainLandTables 和 spellsImmuneTracing 通过 registerPeriodicTask 注册。
- **build_order.txt**: 已包含 Phase 2 目标文件路径（core/events.lua 等），当前容错模式跳过不存在文件。

### Established Patterns
- **全局函数调用模式**: 所有 `macroTorch.*` 函数通过全局命名空间直接调用，无模块系统或依赖注入
- **Frame 管理**: periodic.lua 已建立独立 Frame 先例，events.lua 沿用此模式
- **文件加载顺序**: build_order.txt 保证函数定义先于调用方（D-05 调整后顺序）

### Integration Points
- **SM_Extend_Druid.lua**: 调用 setSpellTracing, setTraceSpellImmune, setSpellTracingByName, setTraceSpellImmuneByName, consumeDruidBattleEvents（5 个函数）
- **entity/Target.lua**: 调用 loadImmuneTable, loadDefiniteBleedingTable（2 个函数）
- **build_order.txt**: 需移除 `battle_event_queue.lua` 条目，确认 4 个新 core/ 文件条目存在且顺位正确
</code_context>

<specifics>
## Specific Ideas

None — 所有决策均基于 ROADMAP 和现有代码模式推导，无外部参考要求。
</specifics>

<deferred>
## Deferred Ideas

None — 讨论保持在 Phase 2 范围内。
</deferred>

---

*Phase: 02-事件系统模块化拆分*
*Context gathered: 2026-06-08*