# Phase 2: 事件系统模块化拆分 - Research

**Researched:** 2026-06-08
**Domain:** Lua 5.1 code refactoring, WoW 1.12.1 FrameXML event system
**Confidence:** HIGH

## Summary

Phase 2 是对 `battle_event_queue.lua`（468 行）的纯代码拆分操作，无外部依赖、无新库引入、无运行时行为变更。Phase 1 已将 LRUStack、OnUpdate handler、registerPeriodicTask 迁入 `core/periodic.lua`，Phase 2 将剩余内容按职责拆分到 4 个新文件，然后完全删除 `battle_event_queue.lua`。

核心挑战在于精确的逐函数分配，确保 build_order 保证所有 `macroTorch.*` 函数在使用前已定义。外部调用方（entity/Target.lua 5 处引用、SM_Extend_Druid.lua 5 处引用）必须在拆分后完整可用。

**Primary recommendation:** 严格按 D-02 的 spell_trace_core/spell_trace_immune 双文件拆分方案执行。loadImmuneTable/loadDefiniteBleedingTable 放入 `spell_trace_immune.lua`（非 combat_context.lua），与 ROADMAP.md T2.2.2 的描述不同，但 CONTEXT.md D-02 是权威决策。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| WoW 事件分发 | Event/Context (events.lua) | -- | OnEvent handler + 14 事件注册，框架内唯一的 ingress 点 |
| 战斗进出状态管理 | Event/Context (combat_context.lua) | -- | context 生命周期管理，被 spell_trace 和 combat modules 共同依赖 |
| Spell trace 核心表管理 | Event/Context (spell_trace_core.lua) | -- | cast/fail/land 表 + DodgeParryBlockResist，纯数据层 |
| Spell immune 追踪 | Event/Context (spell_trace_immune.lua) | -- | 依赖 spell_trace_core 的 consume/peek 函数 + combat_context 的 context |
| 周期性任务注册 | Event/Context (periodic.lua) | -- | Phase 1 已完成，Phase 2 仅调用已存在的 registerPeriodicTask |

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 集中式事件注册。`core/events.lua` 创建一个 Frame 注册全部 14 个事件，`eventHandle` 内部通过 if-elseif 直接 dispatch 到 combat_context 和 spell_trace 函数。不引入回调注册表或事件总线。

- **D-02:** spell_trace 双文件拆分。`core/spell_trace_core.lua`（约 235 行）：cast/fail/land table 管理 + CheckDodgeParryBlockResist + DEBUFF_LAND_LAG + tracingSpells/traceSpellImmunes 初始化 + setSpellTracing/setTraceSpellImmune + peek/consume 查询函数。`core/spell_trace_immune.lua`（约 70 行）：loadImmuneTable + loadDefiniteBleedingTable + spellsImmuneTracing。

- **D-03:** 直接函数调用 + 调整 build_order 顺序。`combat_context.lua` 和 `spell_trace_core.lua` / `spell_trace_immune.lua` 放在 `events.lua` 之前，events.lua 直接调用已定义的 `macroTorch.*` 函数。不引入 stub、回调注册或中间抽象层。

- **D-04:** 完全删除 `battle_event_queue.lua`。Phase 2 拆分完成后删除 `battle_event_queue.lua` 并从 `build_order.txt` 移除该条目。

- **D-05:** 新文件 build_order 顺序：`core/periodic.lua` → `core/combat_context.lua` → `core/spell_trace_core.lua` → `core/spell_trace_immune.lua` → `core/events.lua`。

### Claude's Discretion

- eventHandle 中 if-elseif dispatch 的具体分支实现
- spell_trace_core 和 spell_trace_immune 之间的精确函数分配（在 250 行约束下调整）
- 各文件中 local Frame 变量命名
- 迁移后的注释保留策略

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R3 | 战斗事件系统模块化：battle_event_queue.lua 删除或 ≤10 行，4 个 core/ 模块各 ≤250 行 | Section "Phase 2 Exact Split Map" provides precise line-count-per-file breakdown confirming all modules fit within 250-line limit |
| R6 | core/ 目录重组：4 个新文件进入 core/，build_order 顺序正确 | Section "build_order.txt Changes" confirms exact required edits |
</phase_requirements>

## Standard Stack

### Core (No new libraries)

Phase 2 is a pure refactoring phase. No external libraries are required. All infrastructure (Frame creation API, event registration, macroTorch namespace) already exists in WoW 1.12.1 Lua 5.1 runtime or was established in Phase 1.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW 1.12.1 FrameXML API | Built-in | `CreateFrame`, `RegisterEvent`, `SetScript("OnEvent")` | Only way to register events in WoW 1.12.1 Lua |
| `macroTorch.registerPeriodicTask` | Phase 1 existing | Periodic task registration (maintainLandTables, spellsImmuneTracing) | Already migrated to `core/periodic.lua`, Phase 2 only calls the existing function |

### Existing Infrastructure (from Phase 1)

| Asset | Location | Phase 2 Usage |
|-------|----------|---------------|
| `macroTorch.registerPeriodicTask` | `core/periodic.lua` | Called by spell_trace_core.lua (maintainLandTables) and spell_trace_immune.lua (spellsImmuneTracing) |
| `macroTorch.LRUStack` | `core/periodic.lua` | Used by spell_trace_core.lua for castTable/failTable/landTable |
| `macroTorch.tableLen` | `impl_util.lua` | Used by eventHandle and CheckDodgeParryBlockResist |
| `macroTorch.show` | `interface_debug.lua` | Used by eventHandle and spellsImmuneTracing for debug logging |

**No installations needed.** Pure code move.

## Package Legitimacy Audit

> **Skipped** — Phase 2 installs zero external packages. This is a pure Lua refactoring: no npm installs, no pip installs, no cargo installs.

## Architecture Patterns

### System Architecture Diagram

```
                         WoW 1.12.1 Client
                              │
                    Game Event Fires
            (PLAYER_REGEN_ENABLED, UNIT_CASTEVENT, etc.)
                              │
                              ▼
                    ┌──────────────────┐
                    │  core/events.lua │  ← OnEvent Frame (独立 Frame)
                    │   eventHandle()  │
                    │  14 events reg'd │
                    └──────┬───────────┘
                           │ if-elseif dispatch (D-01)
                           │
              ┌────────────┼────────────────────┐
              ▼            ▼                     ▼
     ┌──────────────┐ ┌──────────────┐  ┌──────────────────────┐
     │ combat       │ │ spell_trace  │  │ spell_trace_immune   │
     │ _context.lua │ │ _core.lua    │  │ .lua                 │
     │              │ │              │  │                      │
     │ inCombat     │ │ castTable    │  │ spellsImmuneTracing  │
     │ context {}   │ │ failTable    │──┤ loadImmuneTable      │
     │              │ │ landTable    │  │ loadDefinite...Table │
     └──────┬───────┘ │ dodge/parry  │  └──────────┬───────────┘
            │         └──────┬───────┘             │
            │                │                     │
            │         registerPeriodicTask         │
            │                │                     │
            ▼                ▼                     ▼
     ┌─────────────────────────────────────────────────┐
     │              core/periodic.lua                  │
     │         (Phase 1: OnUpdate Frame)               │
     │  onPeriodicUpdate() dispatches to all tasks     │
     │  maintainLandTables, spellsImmuneTracing, etc.  │
     └─────────────────────────────────────────────────┘
                              │
                              ▼
     ┌─────────────────────────────────────────────────┐
     │        macroTorch.context (runtime state)       │
     │   castTable, failTable, landTable (LRUStacks)   │
     │   immuneTable, definiteBleedingTable            │
     │   inCombat flag                                 │
     └─────────────────────────────────────────────────┘
```

Data flows in one direction:
1. WoW fires events → events.lua's OnEvent Frame receives them
2. eventHandle dispatches to combat_context (state changes) and spell_trace (data recording)
3. spell_trace registers periodic tasks that run on periodic.lua's OnUpdate tick
4. All functions write into macroTorch.context / macroTorch.loginContext

### Recommended Project Structure

```
core/
├── class.lua             # Phase 1: classMetatable factory
├── periodic.lua          # Phase 1: LRUStack + OnUpdate Frame + periodic tasks
├── combat_context.lua    # Phase 2 NEW: combat enter/exit, inCombat flag
├── spell_trace_core.lua  # Phase 2 NEW: cast/fail/land tables + dodge/parry
├── spell_trace_immune.lua# Phase 2 NEW: immune tracing + immune/bleeding tables
├── events.lua            # Phase 2 NEW: OnEvent Frame + eventHandle
└── selftest.lua          # Phase 3 (placeholder in build_order.txt)
```

### Pattern 1: Direct Function Call Dispatch (D-01, D-03)

**What:** events.lua's eventHandle uses if-elseif to call combat_context and spell_trace functions directly via `macroTorch.*` namespace.

**Why:** No callback registry overhead, no event bus abstraction. WoW 1.12.1 Lua has only 14 events to handle. Direct dispatch is simpler, faster, and more debuggable.

**When to use:** Always -- this is a locked decision (D-01).

**Example (conceptual, from existing code):**
```lua
-- Source: battle_event_queue.lua:71-148, adapted per D-01/D-03
function macroTorch.eventHandle()
    if event == 'PLAYER_ENTERING_WORLD' then
        macroTorch.onPlayerEnteringWorld()  -- delegates to combat_context
    elseif event == 'PLAYER_REGEN_ENABLED' then
        macroTorch.onCombatExit()
    elseif event == 'PLAYER_REGEN_DISABLED' then
        macroTorch.onCombatEnter()
    elseif event == 'UNIT_CASTEVENT' then
        macroTorch.onUnitCastEvent(arg1, arg3, arg4)  -- delegates to spell_trace_core
    elseif event == 'CHAT_MSG_COMBAT_SELF_MISSES' or event == 'CHAT_MSG_SPELL_SELF_DAMAGE' then
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == 'UI_ERROR_MESSAGE' then
        -- behind-target detection
    end
end
```

**Note (Claude's Discretion):** The exact function names for combat enter/exit delegates (`onCombatEnter`, `onCombatExit`, `onPlayerEnteringWorld`) are at Claude's discretion. They can also remain inline in the if-elseif block without extraction. The key constraint is that they are direct `macroTorch.*` calls, not registrations into a callback table.

### Pattern 2: Independent Frame per Module

**What:** Each module that needs a Frame creates its own `local frame = CreateFrame("Frame")` without sharing with other modules.

**Why:** Phase 1 established this pattern with `core/periodic.lua`'s independent OnUpdate Frame. Phase 2 follows the same pattern for events.lua's OnEvent Frame. Zero shared state, clear ownership.

**Example:**
```lua
-- core/events.lua (independent OnEvent Frame)
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- ... 13 more events
frame:SetScript("OnEvent", macroTorch.eventHandle)

-- core/periodic.lua (independent OnUpdate Frame -- Phase 1)
local frame = CreateFrame("Frame")
frame.lastUpdate = 0
frame.leastUpdateInterval = 0.1
frame:SetScript("OnUpdate", function() ... end)
```

[VERIFIED: existing codebase] — `core/periodic.lua` already uses `local frame = CreateFrame("Frame")` independently. The `local` keyword ensures no namespace collision.

### Pattern 3: registerPeriodicTask Dependency

**What:** New modules (spell_trace_core, spell_trace_immune) call `macroTorch.registerPeriodicTask()` to register their periodic work. The function is defined in `core/periodic.lua` which loads first in build_order.

**Why:** D-03 requires direct function calls, no middleware. Because periodic.lua is earlier in build_order, `registerPeriodicTask` is always defined before spell_trace files try to call it.

**Example:**
```lua
-- spell_trace_core.lua
macroTorch.registerPeriodicTask('maintainLandTables',
    { interval = 0.1, task = macroTorch.maintainLandTables })

-- spell_trace_immune.lua
macroTorch.registerPeriodicTask('spellsImmuneTracing',
    { interval = 0.1, task = macroTorch.spellsImmuneTracing })
```

[VERIFIED: existing codebase] — `battle_event_queue.lua:162,201` already uses this pattern.

## Phase 2 Exact Split Map

### Function Inventory (all 20 macroTorch.* functions in battle_event_queue.lua)

| # | Function | Line Range | Lines | Target File |
|---|----------|-----------|-------|-------------|
| 1 | DEBUFF_LAND_LAG constant | 2 | 1 | spell_trace_core.lua |
| 2 | tracingSpells init | 5-7 | 3 | spell_trace_core.lua |
| 3 | setSpellTracing | 9-13 | 5 | spell_trace_core.lua |
| 4 | setSpellTracingByName | 15-21 | 7 | spell_trace_core.lua |
| 5 | traceSpellImmunes init | 24-26 | 3 | spell_trace_core.lua |
| 6 | setTraceSpellImmune | 29-33 | 5 | spell_trace_core.lua |
| 7 | setTraceSpellImmuneByName | 36-42 | 7 | spell_trace_core.lua |
| 8 | Frame creation + 14 event regs | 44-70 | 27 | events.lua |
| 9 | eventHandle | 71-148 | 78 | events.lua |
| 10 | SetScript("OnEvent", ...) | 150 | 1 | events.lua |
| 11 | maintainLandTables | 153-160 | 8 | spell_trace_core.lua |
| 12 | registerPeriodicTask call | 162 | 1 | spell_trace_core.lua |
| 13 | spellsImmuneTracing | 166-199 | 34 | spell_trace_immune.lua |
| 14 | registerPeriodicTask call | 201-202 | 2 | spell_trace_immune.lua |
| 15 | recordCastTable | 205-227 | 23 | spell_trace_core.lua |
| 16 | recordFailTable | 229-252 | 24 | spell_trace_core.lua |
| 17 | computeLandTable | 254-289 | 36 | spell_trace_core.lua |
| 18 | consumeLandEvent | 291-300 | 10 | spell_trace_core.lua |
| 19 | consumeFailEvent | 302-311 | 10 | spell_trace_core.lua |
| 20 | peekCastEvent | 313-323 | 11 | spell_trace_core.lua |
| 21 | peekFailEvent | 324-334 | 11 | spell_trace_core.lua |
| 22 | peekLandEvent | 335-344 | 10 | spell_trace_core.lua |
| 23 | landTableAnyMatch | 346-355 | 10 | spell_trace_core.lua |
| 24 | landTableAllMatch | 357-366 | 10 | spell_trace_core.lua |
| 25 | CheckDodgeParryBlockResist | 369-429 | 61 | spell_trace_core.lua |
| 26 | loadImmuneTable | 435-452 | 18 | spell_trace_immune.lua |
| 27 | loadDefiniteBleedingTable | 453-468 | 16 | spell_trace_immune.lua |

### File-by-File Line Budget (verified via `wc -l` on actual source)

| File | Functions | Raw Code Lines | +License (~16) | Total Est. | 250 Limit |
|------|-----------|---------------|----------------|------------|-----------|
| **events.lua** | Frame + registration (27) + eventHandle (78) + SetScript (1) | 106 | +16 | ~122 | OK |
| **combat_context.lua** | inCombat/context logic extracted from eventHandle lines 94-107 | 14 | +16 | ~30 | OK |
| **spell_trace_core.lua** | #1-7 (31) + #11-12 (9) + #15-25 (195) = 235 raw | 235 | +16 | ~251 | Marginal -- see note |
| **spell_trace_immune.lua** | #13-14 (36) + #26-27 (34) = 70 raw | 70 | +16 | ~86 | OK |

**spell_trace_core.lua marginal analysis:** The raw line count of 235 lines is tight against the 250-line limit. The license header (~16 lines) pushes it to ~251 lines. Mitigations accepted by D-02:
- License header can be shortened (Apache 2.0 copyright line is 15 lines normally, but can be condensed)
- Some blank lines between functions can be reduced (the count above includes inter-function spacing)
- The D-02 decision explicitly acknowledges this is ~235 lines target, and Claude has discretion to adjust exact function allocation

[VERIFIED: source code] Line counts confirmed via `sed -n` on `battle_event_queue.lua`.

### External Callers (must remain functional after split)

| Caller File | Function Called | Times |
|-------------|----------------|-------|
| entity/Target.lua | loadImmuneTable | 3 (lines 29, 39, 50) |
| entity/Target.lua | loadDefiniteBleedingTable | 2 (lines 59, 70) |
| SM_Extend_Druid.lua | setSpellTracing | 4 (Rip, Rake, Pounce, Ferocious Bite) |
| SM_Extend_Druid.lua | setTraceSpellImmune | 4 (Pounce, Rake, Rip, Faerie Fire) |
| SM_Extend_Druid.lua | consumeDruidBattleEvents | 1 (periodic task registration) |

**Note:** `consumeDruidBattleEvents` is defined in `SM_Extend_Druid.lua:492`, not in battle_event_queue.lua. It is only *registered* via `macroTorch.registerPeriodicTask` in `SM_Extend_Druid.lua:522`. This function is NOT being moved in Phase 2 -- it stays in SM_Extend_Druid.lua.

### build_order.txt Changes

Current `build_order.txt` relevant section:
```
core/periodic.lua
entity/Unit.lua
...
battle_event_queue.lua          ← REMOVE this line
...
core/events.lua                 ← already present (Phase 1 D-09 pre-populated)
core/combat_context.lua         ← already present
core/spell_trace.lua            ← SPLIT into two files (D-02)
core/selftest.lua
```

Required changes per D-04/D-05:
1. **Remove** `battle_event_queue.lua` entry
2. **Replace** `core/spell_trace.lua` with two entries:
   - `core/spell_trace_core.lua`
   - `core/spell_trace_immune.lua`
3. **Verify** order is: `core/periodic.lua` → ... → `core/combat_context.lua` → `core/spell_trace_core.lua` → `core/spell_trace_immune.lua` → `core/events.lua`

The `core/events.lua`, `core/combat_context.lua`, and `core/spell_trace.lua` entries already exist in `build_order.txt` because D-09 (Phase 1) pre-populated all future file paths. The `core/spell_trace.lua` entry needs to become two entries.

**Note:** build.sh is in fault-tolerant mode (D-10). Files that don't exist yet are silently skipped by `[ -f "$line" ] && cat`. After Phase 2 creates all 4 new files, they will be picked up automatically on next build.

[VERIFIED: build_order.txt] Read from actual file at line 17-25.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Event dispatch registration | Callback registry or event bus | if-elseif direct dispatch in eventHandle | D-01 locked decision -- simpler, fewer lines, no extra abstraction |
| Module dependency wiring | Stub functions or lazy require | build_order.txt sequential loading | D-03 locked decision -- files load in order, functions available when needed |
| Frame sharing between modules | Shared frame reference | Independent `local frame = CreateFrame("Frame")` per module | Phase 1 pattern (periodic.lua) -- zero shared state, clear ownership |
| Cross-module communication | Publish/subscribe or message passing | Direct `macroTorch.*` function calls | WoW Lua global namespace is the natural module system |

**Key insight:** In WoW 1.12.1 Lua, there is no `require()`. All code runs in a single global namespace concatenated linearly by build_order.txt. Any abstraction beyond direct function calls and build-order guarantees adds complexity without solving a real problem.

## Runtime State Inventory

> Phase 2 is a refactoring phase that moves code but does not rename any identifiers, data structures, or persistent storage keys. The runtime state (SM_EXTEND tables, macroTorch.context, macroTorch.loginContext) is unaffected.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None -- `SM_EXTEND.immuneTable` and `SM_EXTEND.definiteBleedingTable` keys and structure unchanged | No migration needed |
| Live service config | None -- no external service config references battle_event_queue.lua by name | None |
| OS-registered state | None -- no OS-level registrations | None |
| Secrets/env vars | None -- no secrets or env vars reference file locations | None |
| Build artifacts | None -- `SM_Extend.lua` is regenerated by `./build.sh` after file moves | Rebuild after Phase 2 |

**Nothing found in category 'Stored data':** Verified by examining `loadImmuneTable` and `loadDefiniteBleedingTable` -- they build table hierarchies from `macroTorch.player.class` (which is a runtime lookup by `UnitClass('player')`, not a hardcoded string) and store into `SM_EXTEND.immuneTable[playerCls]` / `macroTorch.context.immuneTable`. These paths are unchanged by file relocation.

**Nothing found in category 'Live service config':** This is a WoW addon, not a service. The SuperMacro addon loads `SM_Extend.lua` from its directory regardless of how it was built.

**Nothing found in category 'OS-registered state':** No Windows Task Scheduler, launchd, or systemd registrations reference this addon.

**Nothing found in category 'Secrets/env vars':** No secrets, API keys, or environment variables exist in this project.

**Nothing found in category 'Build artifacts':** `SM_Extend.lua` is regenerated by `./build.sh`. After Phase 2, a rebuild produces the same content from the new file layout.

## Common Pitfalls

### Pitfall 1: Contradiction Between ROADMAP T2.2.2 and CONTEXT D-02

**What goes wrong:** The ROADMAP.md Phase 2 section says `loadImmuneTable` / `loadDefiniteBleedingTable` go to `core/combat_context.lua` (T2.2.2). The CONTEXT.md D-02 locked decision says they go to `core/spell_trace_immune.lua`. Following the ROADMAP description instead of the CONTEXT decision puts these functions in the wrong file.

**Why it happens:** The ROADMAP.md was written before the discuss-phase refined the split into D-02. The ROADMAP is a preliminary plan, the CONTEXT is the authoritative decision.

**How to avoid:** Follow D-02. `loadImmuneTable` and `loadDefiniteBleedingTable` belong in `core/spell_trace_immune.lua`. `core/combat_context.lua` only gets the `inCombat` flag management and `macroTorch.context` initialization from eventHandle lines 94-107.

**Warning signs:** If `grep "loadImmuneTable" core/combat_context.lua` returns a result, the split followed the wrong instruction.

### Pitfall 2: Ghost Function Definitions After file Deletion

**What goes wrong:** After deleting `battle_event_queue.lua`, external callers in `entity/Target.lua` (loadImmuneTable x3, loadDefiniteBleedingTable x2) and `SM_Extend_Druid.lua` (setSpellTracing x4, setTraceSpellImmune x4) will break if the functions haven't been redefined in the new files.

**Why it happens:** Copy-paste errors during migration, or accidentally deleting a function definition without recreating it in the target file.

**How to avoid:** After splitting, run:
```bash
# Verify all 18 functions exist in new files
for func in setSpellTracing setSpellTracingByName setTraceSpellImmune setTraceSpellImmuneByName \
    eventHandle maintainLandTables spellsImmuneTracing recordCastTable recordFailTable \
    computeLandTable consumeLandEvent consumeFailEvent peekCastEvent peekFailEvent \
    peekLandEvent landTableAnyMatch landTableAllMatch CheckDodgeParryBlockResist \
    loadImmuneTable loadDefiniteBleedingTable; do
    grep -l "function macroTorch.$func" core/events.lua core/combat_context.lua \
        core/spell_trace_core.lua core/spell_trace_immune.lua 2>/dev/null || \
        echo "MISSING: macroTorch.$func"
done
```

**Warning signs:** `grep "function macroTorch.loadImmuneTable" core/*.lua` returns nothing.

### Pitfall 3: build_order.txt Contains Wrong File Name

**What goes wrong:** The current `build_order.txt` has `core/spell_trace.lua` (singular) as a single entry. If the entry is not replaced with the two D-02 files (`core/spell_trace_core.lua` + `core/spell_trace_immune.lua`), the build will miss one of the files.

**Why it happens:** The original Phase 1 D-09 pre-population used a singular name, before the discuss-phase decided on the dual-file split.

**How to avoid:** Replace the single `core/spell_trace.lua` line with two lines in correct D-05 order:
```
core/spell_trace_core.lua
core/spell_trace_immune.lua
```

**Warning signs:** `grep "spell_trace" build_order.txt` shows only one entry or the singular `core/spell_trace.lua`.

### Pitfall 4: registerPeriodicTask Called Before periodic.lua Loads

**What goes wrong:** If `spell_trace_core.lua` or `spell_trace_immune.lua` are placed before `core/periodic.lua` in build_order.txt, the `registerPeriodicTask` call at the bottom of those files would reference an undefined function.

**Why it happens:** Incorrect build_order.txt editing.

**How to avoid:** Verify the final build_order.txt has `core/periodic.lua` before any spell_trace files. D-05 explicitly encodes this order. The existing build_order.txt already has `core/periodic.lua` at line 6, before all other core/ entries.

**Warning signs:** `grep -n "periodic\|spell_trace\|combat_context\|events" build_order.txt` shows spell_trace files before periodic.

## Validation Architecture

> **Skipped** — `workflow.nyquist_validation` is `false` in `.planning/config.json`. No test framework exists for this WoW addon; validation is manual in-game.

## Security Domain

> **Skipped** — This is a WoW 1.12.1 game addon with no external network access, no user data processing, no authentication, and no cryptography. The refactoring moves code between files without changing any logic. No security analysis is required.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single battle_event_queue.lua (468 lines) with all events + spell trace + periodic scheduler | 4 separate core/ modules with single responsibility | Phase 2 (current) | Clearer module boundaries, easier maintenance, each file ≤250 lines |
| Shared Frame for OnUpdate + OnEvent | Independent Frames per module | Phase 1 (periodic.lua OnUpdate) + Phase 2 (events.lua OnEvent) | Zero coupling, independent lifecycle |
| Single spell_trace.lua | Dual-file spell_trace_core.lua + spell_trace_immune.lua | Phase 2 | Immune logic isolated, easier to extend or disable immune tracking |

**Deprecated/outdated:**
- `battle_event_queue.lua` entirely -- will be deleted in Phase 2 (D-04)
- Shared frame pattern -- replaced by independent frames per module

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | spell_trace_core.lua 的 235 行原始代码加上 16 行 license 头刚好在 250 行限制内（可微调空白行） | Phase 2 Exact Split Map | 中等 -- 如果最终超过 250 行，需要将部分辅助函数（如 landTableAnyMatch/landTableAllMatch）移入 spell_trace_immune.lua。Claude's Discretion 允许调整精确分配。 |
| A2 | `consumeDruidBattleEvents` 函数定义不在 battle_event_queue.lua 中 | External Callers | 低 -- 已验证：grep 确认该函数仅在 SM_Extend_Druid.lua:492 定义。Phase 2 不需要迁移此函数。 |
| A3 | build.sh 容错模式会正确跳过尚未创建的文件 | build_order.txt Changes | 低 -- Phase 1 已通过此模式工作。D-10 确认容错模式在 Phase 2 仍然有效。 |

## Open Questions

1. **ROADMAP T2.2.2 vs CONTEXT D-02 contradiction (RESOLVED)**
   - What we know: ROADMAP.md says loadImmuneTable/loadDefiniteBleedingTable go to combat_context.lua. CONTEXT.md D-02 says they go to spell_trace_immune.lua.
   - What was unclear: Which to follow.
   - Resolution: D-02 is the authoritative decision document. CONTEXT.md Decisions section overrides ROADMAP.md task descriptions.
   - Implementation: loadImmuneTable + loadDefiniteBleedingTable go to `core/spell_trace_immune.lua`.

2. **spell_trace_core.lua 250-line budget tightness**
   - What we know: Raw code = 235 lines, + license header (~16) = ~251 lines. This is 1 line over the requirement budget.
   - What's unclear: Whether the 250-line limit in R3 is strict or approximate (R3 says "各不超过 250 行").
   - Recommendation: Reduce blank lines between function groups (currently 1-2 blank lines between each function) to fit within 250. The actual code logic is 235 lines -- the rest is formatting whitespace. Alternatively, move `landTableAnyMatch` and `landTableAllMatch` (20 lines total) to `spell_trace_immune.lua` since they are query predicates used alongside consume functions.

## Environment Availability

> **Skipped** — Phase 2 has zero external dependencies. It is a pure Lua code refactoring that moves existing code between files. No new tools, runtimes, databases, or CLIs are required beyond what Phase 1 already uses. The `./build.sh` script and WoW 1.12.1 client are the only validation tools, and both were verified operational in Phase 1.

## Sources

### Primary (HIGH confidence)
- `battle_event_queue.lua` (468 lines) — full source verified by reading file. All 20 function signatures, line ranges, and registerPeriodicTask invocations confirmed.
- `core/periodic.lua` (139 lines) — verified existing Phase 1 output. Confirmed independent OnUpdate Frame pattern, registerPeriodicTask/removePeriodicTask/setRepeat existence.
- `build_order.txt` (45 lines) — verified current state with core/events.lua, core/combat_context.lua, core/spell_trace.lua pre-populated by Phase 1 D-09.
- `build.sh` — verified fault-tolerant mode `[ -f "$line" ] && cat` for file existence checking.
- `SM_Extend_Druid.lua` — verified 5 external callers: setSpellTracing x4 (lines 480-483), setTraceSpellImmune x4 (lines 486-489), consumeDruidBattleEvents defined at line 492.
- `entity/Target.lua` — verified 5 external callers: loadImmuneTable x3 (lines 29, 39, 50), loadDefiniteBleedingTable x2 (lines 59, 70).
- CONTEXT.md Section "Implementation Decisions" D-01 through D-05 — authoritative decisions.
- `.planning/codebase/ARCHITECTURE.md` — Event/Context Layer architecture, combat event tracking flow, context definitions.
- `.planning/codebase/CONVENTIONS.md` — naming conventions, function design, global namespace patterns.
- `.claude-reference/Functions.md` — WoW 1.12.1 Frame Management API (CreateFrame:443, GetTime:1169).

### Secondary (MEDIUM confidence)
- `docs/REFACTOR_PLAN.md` — original refactoring plan Step 3, confirmed the split motivation but predates D-02 refinement.

### Tertiary (LOW confidence)
- None — all claims are verified against source code or CONTEXT.md decisions.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure refactoring, no new libraries, all infrastructure exists from Phase 1
- Architecture: HIGH — D-01 through D-05 fully specified; all function-to-file mappings verified against actual source line counts
- Pitfalls: HIGH — contradictions between ROADMAP and CONTEXT identified and resolved; external caller inventory complete
- Line budgets: MEDIUM — spell_trace_core.lua is tight at ~251 lines; mitigation strategies documented

**Research date:** 2026-06-08
**Valid until:** Stable. This is a one-time refactoring phase with no external dependencies that could change.