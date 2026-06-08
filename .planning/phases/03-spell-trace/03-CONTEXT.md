# Phase 3: 自检系统 + Spell Trace 配置化 - Context

**Gathered:** 2026-06-08
**Status:** Ready for planning

<domain>
## Phase Boundary

实现登录自检框架（SelfTest:register/run）并在 `PLAYER_ENTERING_WORLD` 首次触发，注册 60+ 项基础设施健康检查。将 spell trace 改为声明式 API `macroTorch.SpellTrace:register()`，完全替代现有命令式 `setSpellTracing`/`setTraceSpellImmune`。

覆盖需求: R4 (Spell Trace 配置化), R5 (登录自检)
</domain>

<decisions>
## Implementation Decisions

### SelfTest 触发策略
- **D-01:** 仅在首次 `PLAYER_ENTERING_WORLD` 自动触发自检，使用 session flag (`macroTorch._selfTestRan`) 防止跨区域重复输出。reload UI 后 flag 清空，自检重新运行。
- **D-02:** 提供 `/mt` SLASH 命令作为手动触发入口。`/mt` 是中远期 mt-script 自定义 DSL 的执行入口，Phase 3 先实现 selftest 触发（`/mt` 无参数时运行自检）。

### SelfTest 自检哲学与分层
- **D-03:** 自检定位为**基础设施健康检查**，非职业测试套件。优先级分层：
  - **第一层（核心必检）**：可选模块可用性（UnitXP, SP3, SuperWoW）、WoW API 函数存在性、Unit/Player 基类方法和属性完整性
  - **第二层（职业附加）**：当前加载职业的特定检测（如 Druid 猫形态技能存在性、talent 等级、能量常量范围）
- **D-04:** Player 是唯一登录时明确存在的实体，可对其做只读调用验证（`player.health`, `player.mana` 等）。其余实体（Target/Pet 等）仅验证方法和属性存在，不做实际调用。
- **D-05:** 纯报告模式。自检汇总输出到聊天框，不引入 `degradedMode` 或运行时降级机制。成功项不打印日志，仅汇总行 + 失败/warning 可见。可选模块失败报 warning（黄色），核心模块失败报 error（红色）。

### SpellTrace API 设计
- **D-06:** 采用完全替代 + 方法风格。`macroTorch.SpellTrace:register(name, config)` 声明式 API，config 字段 `{immune, land, debuffTexture}`。
- **D-07:** 底层 `setSpellTracing`/`setTraceSpellImmune` 改为内部实现细节（不鼓励直接调用），`SpellTrace:register()` 内部调用它们操作 `tracingSpells`/`traceSpellImmunes` 核心表。
- **D-08:** `macroTorch.SpellTrace` 表作为命名空间，为未来扩展预留空间（如 `SpellTrace:list()`, `SpellTrace:unregister()`）。

### Druid 自检覆盖边界
- **D-09:** 第一层基础设施自检完成后，对当前加载职业做深入检测。Druid 约 18 项核心必检 + 约 7 项 optional：
  - **核心（~18）**：猫形态技能存在性 10 项（Shred, Rip, Rake, Claw, Ferocious Bite, Tiger's Fury, Faerie Fire, Pounce, Ravage, Cower）+ talent 等级 5 项（Ancient Brutality, Omen of Clarity, Ferocity, Improved Shred, Blood Frenzy）+ 能量常量范围 3 项
  - **Optional（~7）**：DRUID_FIELD_FUNC_MAP 字段完整性 5 项（comboPoints, isOoc, isProwling, isBerserk, humanFormMana）+ 形态检测 2 项

### `/mt` 命令设计
- **D-10:** `/mt` 为未来 mt-script DSL 的统一入口。Phase 3 行为：无参数 → 运行自检；未来扩展：`/mt <script>` → 执行 mt-script。SLASH 命令注册为 `SLASH_MT1 = "/mt"`。

### Claude's Discretion
- SelfTest:run() 内部 pcall 实现细节、测试注册的组织方式
- SpellTrace:register() 内部对 setSpellTracing/setTraceSpellImmune 的调用逻辑
- `/mt` 命令处理函数的实现（当前仅 selftest 分支）
- selftest.lua 中测试函数的代码组织（是否按类别分组）
- build_order.txt 中 core/selftest.lua 的精确插入位置
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 3 完整实施步骤（3.1-3.4）、任务分解、验证命令
- `.planning/REQUIREMENTS.md` — R4 (Spell Trace 配置化) 和 R5 (登录自检) 验收标准
- `docs/REFACTOR_PLAN.md` — 原始重构计划 Step 3-4（自检 + spell trace 依据）

### Phase 1 & 2 决策（影响 Phase 3）
- `.planning/phases/01-classmetatable-entity/01-CONTEXT.md` — D-09 (build_order.txt 一次性全量)、D-10 (容错构建模式)
- `.planning/phases/02-events-system/02-CONTEXT.md` — D-01 (集中式事件注册)、D-02 (双文件 spell_trace 拆分)、D-03 (直接函数调用 + build_order 顺序)

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — SelfTest 挂载的 Event Layer、SpellTrace 所在的 Context Layer、OOP metatable 链
- `.planning/codebase/CONVENTIONS.md` — 全局函数命名惯例、FIELD_FUNC_MAP 模式、pcall 错误处理模式

### API 参考
- `.claude-reference/Functions.md` — WoW 1.12.1 完整 Macro API（需在自检中验证的函数列表）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **core/events.lua:52**: `-- Phase 3: macroTorch.SelfTest:run()` 预留注释，直接替换为调用
- **core/spell_trace_core.lua:13-47**: `setSpellTracing`/`setTraceSpellImmune` + `tracingSpells`/`traceSpellImmunes` 表初始化，SpellTrace:register 底层依赖
- **SM_Extend_Druid.lua:480-489**: 当前 4 个 `setSpellTracing` + 4 个 `setTraceSpellImmune` 调用对，需改写为 5+ 个 `SpellTrace:register()` 调用
- **macroTorch.show(msg, color)**: 自检汇总输出的唯一通道，支持 white/red/yellow/blue/green

### Established Patterns
- **全局函数命名**: 现有 ~50 个 macroTorch.* 函数均用全局函数风格。SpellTrace:register 是首个 `Table:method()` 模式，为未来命名空间扩展建立先例
- **pcall 错误处理**: OnUpdate handler 已使用 pcall 包裹（原 battle_event_queue.lua），SelfTest:run() 沿用此模式
- **session flag**: 当前代码无 session flag 先例，`macroTorch._selfTestRan` 将建立此模式
- **SLASH 命令**: WoW 1.12.1 标准 `SLASH_<NAME>1 = "/cmd"` 模式，`/mt` 为未来 mt-script DSL 预留

### Integration Points
- **core/events.lua:52**: `PLAYER_ENTERING_WORLD` 分支 — 插入 `SelfTest:run()` 调用
- **core/spell_trace_core.lua**: 在现有 `setSpellTracing`/`setTraceSpellImmune` 之后添加 `SpellTrace` 表和 `:register()` 方法
- **SM_Extend_Druid.lua:480-489**: 8 行命令式注册 → `SpellTrace:register()` 声明式调用
- **SM_Extend_Druid.lua 末尾**: 添加 `SelfTest:register()` 调用块（~25 项）
- **build_order.txt**: `core/selftest.lua` 需在 `core/events.lua` 之前（events.lua 调用 SelfTest:run()）
</code_context>

<specifics>
## Specific Ideas

- `/mt` 是中远期 mt-script 自定义 DSL 的执行入口，Phase 3 仅实现无参数时运行自检，设计需预留扩展点（参数解析、子命令路由）
</specifics>

<deferred>
## Deferred Ideas

- **mt-script DSL**: `/mt <script>` 执行自定义 DSL 脚本 — 属于未来 Phase，与当前自检+spell trace 配置化无关。`/mt` 命令设计已预留此扩展。
- **降级模式 (degradedMode)**: 自检失败后的运行时保护 — 当前采用纯报告模式，若未来需要可单独实现。

None — 讨论保持在 Phase 3 范围内。
</deferred>

---

*Phase: 03-自检系统 + Spell Trace 配置化*
*Context gathered: 2026-06-08*