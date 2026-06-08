---
phase: 03-spell-trace
plan: 02
subsystem: api
tags: [lua, spell-trace, declarative-api, wurst, wrapper-pattern]

# Dependency graph
requires:
  - phase: 02-events-system
    provides: spell_trace_core.lua with setSpellTracing/setTraceSpellImmune functions and tracingSpells/traceSpellImmunes tables
provides:
  - macroTorch.SpellTrace namespace table (reserved for future extensions per D-08)
  - SpellTrace:register(name, config) declarative API as thin wrapper over setSpellTracing/setTraceSpellImmune
affects:
  - 03-04 (SM_Extend_Druid will use SpellTrace:register() to replace command-style calls)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Table:method() pattern for namespace-scoped APIs (SpellTrace:register — project's first : syntax method)"
    - "Wrapper/Delegation pattern: register() calls existing setSpellTracing/setTraceSpellImmune, no new state"

key-files:
  created: []
  modified:
    - core/spell_trace_core.lua — added SpellTrace namespace + register() at line 48 (after setTraceSpellImmuneByName, before maintainLandTables)

key-decisions:
  - "Placed SpellTrace code between setTraceSpellImmuneByName and maintainLandTables — after immune tracing helpers, before land table logic, establishing natural section boundary"
  - "Used : method syntax (function macroTorch.SpellTrace:register) — establishing project convention for namespace-scoped APIs"
  - "Kept spellId as direct config field (not resolved via getSpellUniqIdByName) — matches RESEARCH A3/Pitfall 1 finding that GetSpellName() returns nil during addon load"

patterns-established:
  - "Declaration-driven API wrapping: config table {spellId, immune, land, debuffTexture} replaces dual command-style calls"
  - "Table:method() convention for namespace-scoped APIs in macroTorch global namespace"

requirements-completed:
  - R4

# Metrics
duration: 3min
completed: 2026-06-08
---

# Phase 03 Plan 02: SpellTrace:register() 声明式 API

**向 core/spell_trace_core.lua 添加 macroTorch.SpellTrace 命名空间和 SpellTrace:register(name, config) 声明式注册 API，内部委托给现有 setSpellTracing/setTraceSpellImmune，底层数据表和处理逻辑不变。**

## Performance

- **Duration:** 3min
- **Started:** 2026-06-08T13:09:06Z
- **Completed:** 2026-06-08T13:12:23Z (approximate)
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- 创建 `macroTorch.SpellTrace = {}` 命名空间表（预留扩展点 per D-08）
- 实现 `SpellTrace:register(name, config)` 声明式 API，使用 `:` 方法语法（项目首个 Table:method() 模式）
- `config.land=true` 时内部调用 `macroTorch.setSpellTracing(config.spellId, name)`
- `config.immune=true` 时内部调用 `macroTorch.setTraceSpellImmune(name, config.debuffTexture)`
- 现有 `setSpellTracing` / `setTraceSpellImmune` 函数签名和行为完全不变
- 不引入新状态 — register() 仅委托到现有内部函数，操作现有 tracingSpells/traceSpellImmunes 表
- `./build.sh` 构建成功，产物完整性验证通过

## Task Commits

Each task was committed atomically:

1. **Task 1: 添加 SpellTrace 命名空间和 :register() API** - `7b55d77` (feat)

## Files Created/Modified
- `core/spell_trace_core.lua` — 插入 19 行：SpellTrace 命名空间表 + register() 方法定义（第 48-66 行），位于 setTraceSpellImmuneByName 之后、maintainLandTables 之前

## Decisions Made
- SpellTrace 代码插入位置：在 `setTraceSpellImmuneByName` 和 `maintainLandTables` 之间（第 47-48 行之间），形成自然的 immune tracing / land tracing 章节分割
- 方法语法：使用 `function macroTorch.SpellTrace:register(name, config)` — 与 plan 中的 `:` 语法设计一致，为 future plans 中的 SelfTest:register/run 建立先例
- spellId 字段处理：直接从 config 读取传递，不通过 `getSpellUniqIdByName` 解析 — 与 RESEARCH A3/Pitfall 1 结论一致（addon 加载期间 GetSpellName() 返回 nil）

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — single task with clear insertion point, no complications.

## Known Stubs

None detected.

## Threat Flags

No new threat surface introduced. The T-03-04 disposition (accept) was validated: register() passes config fields directly to existing functions without data modification or transformation.

## Next Phase Readiness
- SpellTrace:register() API 已可用，等待 03-04 plan 中 SM_Extend_Druid.lua 调用
- 现有 setSpellTracing/setTraceSpellImmune 仍可直接调用（不鼓励但不阻断），向后兼容
- 构建系统无变化，spell_trace_core.lua 在 build_order.txt 中的位置不变

---
*Phase: 03-spell-trace*
*Completed: 2026-06-08*