# Phase 03: 自检系统 + Spell Trace 配置化 - Research

**Researched:** 2026-06-08
**Domain:** Lua 5.0 addon framework / WoW 1.12.1 macro API self-test + declarative API wrapping
**Confidence:** HIGH

## Summary

Phase 3 包含两个独立但互有交叉的功能：(1) 登录自检框架 (`SelfTest:register/run`，~60+ 项基础设施健康检查)，(2) 将 spell trace 从命令式 `setSpellTracing/setTraceSpellImmune` 改写为声明式 `SpellTrace:register(name, config)` 注册 API。

自检框架采用简单的 register/run 模式：各文件注册 pcall 包裹的测试函数到 `macroTorch.SelfTest.tests` 表，`SelfTest:run()` 遍历执行后输出汇总到聊天框。SpellTrace API 是对现有 `tracingSpells`/`traceSpellImmunes` 核心表的薄封装，不引入新状态或改变底层计算逻辑。

两个子系统共享极少的集成点：仅 `core/events.lua:52` 处插入一行 `SelfTest:run()` 调用，以及 `SM_Extend_Druid.lua:479-489` 处 8 行命令式调用改写为声明式。自检中不涉及 spell trace 验证（spell trace 的验证需要实际战斗，非自检范围）。

**Primary recommendation:** 使用纯粹的 Table:method() 模式实现两个框架。不需要任何外部库或复杂工具链 -- WoW 1.12.1 的 Lua 5.0 环境不支持 require，一切通过全局 `macroTorch` 命名空间通信。自检的 pcall 包装模式直接复用 `core/periodic.lua:131-132` 的现有模式。

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R4 | Spell Trace 配置化：`SpellTrace:register(name, config)` 声明式 API | See Standard Stack (SpellTrace API), Architecture Patterns (Wrapper Pattern) |
| R5 | 登录自检机制：`SelfTest:register/run` 框架 + ~60+ tests | See Standard Stack (SelfTest Framework), Architecture Patterns (Register/Run) |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (from CONTEXT.md)

- **D-01:** SelfTest 仅在首次 `PLAYER_ENTERING_WORLD` 自动触发，使用 session flag (`macroTorch._selfTestRan`) 防止跨区域重复输出。reload UI 后 flag 清空，自检重新运行。
- **D-02:** `/mt` 是未来 mt-script DSL 的统一入口。Phase 3 仅实现无参数时运行自检。SLASH 注册为 `SLASH_MT1 = "/mt"`。
- **D-03:** 自检定位为基础设施健康检查。第一层（核心必检）：可选模块可用性、WoW API 函数存在性、Unit/Player 基类方法/属性完整性。第二层（职业附加）：当前职业特定检测（Druid 猫形态技能存在性、talent 等级、能量常量范围）。
- **D-04:** Player 是唯一登录时明确存在的实体，可对其做只读调用验证。其余实体（Target/Pet 等）仅验证方法和属性存在性，不做实际调用。
- **D-05:** 纯报告模式。汇总输出到聊天框。不引入 degradedMode。成功项不打印日志，仅汇总行 + 失败/warning 可见。可选模块失败报 warning（黄色），核心模块失败报 error（红色）。
- **D-06:** `macroTorch.SpellTrace:register(name, config)` 声明式 API，config 字段 `{immune, land, debuffTexture}`。完全替代命令式调用。
- **D-07:** `setSpellTracing`/`setTraceSpellImmune` 改为内部实现细节（不鼓励直接调用），`SpellTrace:register()` 内部调用它们操作核心表。
- **D-08:** `macroTorch.SpellTrace` 表作为命名空间，预留扩展点。
- **D-09:** Druid 自检覆盖：核心 ~18 项（10 skills + 5 talents + 3 constants）+ optional ~7 项（5 DRUID_FIELD_FUNC_MAP + 2 form checks）。
- **D-10:** `/mt` 无参数运行自检。未来 `/mt <script>` 执行 mt-script DSL。设计需预留扩展点（参数解析、子命令路由）。

### Claude's Discretion

- SelfTest:run() 内部 pcall 实现细节、测试注册的组织方式
- SpellTrace:register() 内部对 setSpellTracing/setTraceSpellImmune 的调用逻辑
- `/mt` 命令处理函数的实现（当前仅 selftest 分支）
- selftest.lua 中测试函数的代码组织（是否按类别分组）
- build_order.txt 中 core/selftest.lua 的精确插入位置

### Deferred Ideas (OUT OF SCOPE)

- **mt-script DSL**: `/mt <script>` 执行自定义 DSL 脚本 -- 属于未来 Phase。
- **降级模式 (degradedMode)**: 自检失败后的运行时保护 -- 当前采用纯报告模式。
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SelfTest:register() / :run() framework | API / Backend | — | Pure Lua logic -- no WoW frames, no visual output except through macroTorch.show() |
| Self-test items (API checks, entity checks) | API / Backend | — | Reads WoW API and entity properties; no mutation, no combat interaction |
| SLASH /mt command handler | API / Backend | — | SLASH registration is a WoW client concern but the handler logic is pure dispatch |
| SpellTrace:register() API | API / Backend | — | Thin wrapper around existing spell_trace_core.lua functions |
| PLAYER_ENTERING_WORLD hook | Frontend Server (events) | API / Backend | The event frame (core/events.lua) triggers SelfTest:run(); business logic lives in selftest.lua |
| Chat output (macroTorch.show) | Browser / Client | — | WoW chat frame is client-side rendering; our code only calls the output function |

## Standard Stack

### Core

This phase requires zero external libraries. WoW 1.12.1 addons run in a Lua 5.0 sandbox with no `require`/`module()` support. All functionality uses the existing `macroTorch` global namespace.

| Component | Type | Purpose |
|-----------|------|---------|
| `macroTorch.SelfTest` table | Local framework | Register/Run pattern for infrastructure health checks |
| `macroTorch.SpellTrace` table | Local framework | Declarative wrapper around existing setSpellTracing/setTraceSpellImmune |
| `SLASH_MT1 = "/mt"` | WoW API convention | Vanilla SLASH command registration with no external library needed |
| `pcall()` | Lua builtin | Wrap each test to isolate failures; already in use at `core/periodic.lua:131-132` |
| `macroTorch.show(msg, color)` | Existing project output | The ONLY output channel for self-test results; supports white/red/yellow/blue/green |

### Supporting

| Component | Purpose |
|-----------|---------|
| `macroTorch.toBoolean(v)` | Convert WoW API nil/1 returns to boolean; already in impl_util.lua |
| `macroTorch.isFunctionExist(funcName)` | Check global function existence via `type(_G[name])`; already in impl_util.lua |
| `GetTime()` / `UnitClass("player")` | WoW 1.12.1 API; already in use throughout codebase |

### Alternatives Considered

No alternatives exist in the WoW 1.12.1 addon ecosystem. There is no test framework, no package manager, and no `require()` support. The register/run pattern is the standard approach for this environment.

### No Packages to Install

This phase adds zero external dependencies. All code is pure Lua 5.0 running within the WoW 1.12.1 sandbox. The Package Legitimacy Audit section is intentionally omitted -- there are no npm/PyPI/crates packages to verify.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      PHASE 3 DATA FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [WoW Event: PLAYER_ENTERING_WORLD]                              │
│       │                                                          │
│       ▼                                                          │
│  core/events.lua:52   eventHandle()                             │
│       │                                                          │
│       ├──► macroTorch.onPlayerEnteringWorld()  (existing)        │
│       │                                                          │
│       └──► macroTorch.SelfTest:run()  ← Phase 3 entry point      │
│                 │                                                │
│                 ▼                                                │
│       ┌─────────────────────────────────┐                       │
│       │  SelfTest:run()                  │                       │
│       │                                  │                       │
│       │  1. Check _selfTestRan flag      │                       │
│       │  2. Set _selfTestRan = true       │                       │
│       │  3. For each test in tests[]:     │                       │
│       │     pcall(test.fn)               │                       │
│       │     Collect result (PASS/FAIL/    │                       │
│       │     WARN)                        │                       │
│       │  4. macroTorch.show(summary)      │                       │
│       └─────────────────────────────────┘                       │
│                 │                                                │
│        Tests registered from:                                     │
│        ┌──────────────────────────────────┐                     │
│        │ core/selftest.lua                │                     │
│        │   SelfTest:register("Lua env",   │                     │
│        │      fn, isOptional)             │                     │
│        │   SelfTest:register("WoW API",   │                     │
│        │      fn, isOptional)             │                     │
│        │   SelfTest:register("Player",    │                     │
│        │      fn, isOptional)             │                     │
│        │   SelfTest:register("Entity",    │                     │
│        │      fn, isOptional)             │                     │
│        ├──────────────────────────────────┤                     │
│        │ SM_Extend_Druid.lua              │                     │
│        │   SelfTest:register("Druid cat", │                     │
│        │      fn, isOptional)             │                     │
│        └──────────────────────────────────┘                     │
│                                                                   │
│  ──── Separate Subsystem Boundary ────                           │
│                                                                   │
│  [SLASH /mt handler]                                              │
│       │                                                          │
│       ▼                                                          │
│  function macroTorch.HandleMtCmd(msg)                             │
│       │                                                          │
│       ├── msg == "" or nil → SelfTest:run()  (Phase 3)           │
│       │                                                          │
│       └── msg is non-empty → reserved for future mt-script       │
│            (deferred -- currently no-op or help text)             │
│                                                                   │
│  ──── Separate Subsystem Boundary ────                           │
│                                                                   │
│  [SpellTrace:register()  -- at file load time, not runtime]      │
│       │                                                          │
│       ▼                                                          │
│  SM_Extend_Druid.lua:479-489  (rewritten)                        │
│       │                                                          │
│       ├── SpellTrace:register("Rip", {immune=true, land=true,    │
│       │      debuffTexture="Ability_GhoulFrenzy"})               │
│       ├── SpellTrace:register("Rake", ...)                       │
│       ├── SpellTrace:register("Shred", ...)                      │
│       ├── SpellTrace:register("Claw", ...)                       │
│       └── SpellTrace:register("Faerie Fire (Feral)", ...)        │
│                 │                                                │
│                 ▼                                                │
│       core/spell_trace_core.lua                                   │
│       SpellTrace:register() internally calls:                    │
│         → setSpellTracing(spellId, name)      [if config.land]   │
│         → setTraceSpellImmune(name, texture)  [if config.immune] │
│       Both operate on existing tracingSpells/traceSpellImmunes  │
│       tables. No new state is introduced.                        │
│                                                                   │
│       EXISTING (unchanged):                                       │
│         maintainLandTables(), spellsImmuneTracing(),             │
│         recordCastTable(), recordFailTable(),                     │
│         computeLandTable(), CheckDodgeParryBlockResist()          │
│         -- All continue to work exactly as before.               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (Phase 3 additions only)

```
core/
├── selftest.lua          # NEW: SelfTest:register/run framework + 60+ tests
├── spell_trace_core.lua  # MODIFIED: adds SpellTrace table + :register()
├── events.lua            # MODIFIED: PLAYER_ENTERING_WORLD adds SelfTest:run()
│
SM_Extend_Druid.lua       # MODIFIED: spell trace calls → SpellTrace:register()
                          # MODIFIED: adds ~25 SelfTest:register() at file end
```

### Pattern 1: Register/Run Framework (SelfTest)

**What:** A test registration table with pcall-isolated execution. Files call `SelfTest:register()` to queue test functions. `SelfTest:run()` iterates and reports.

**When to use:** Any phase that needs infrastructure health checks before combat logic executes.

**Implementation sketch (verified against existing pcall pattern at core/periodic.lua:131-132):**

```lua
-- Source: existing project pattern core/periodic.lua:131-132
-- SelfTest adapts this pcall + error isolation pattern

macroTorch.SelfTest = {
    tests = {},        -- array of {name, fn, isOptional}
    _selfTestRan = nil -- session flag
}

function macroTorch.SelfTest:register(name, fn, isOptional)
    -- [CITED: CONTEXT.md D-03, D-05]
    table.insert(self.tests, {
        name = name,
        fn = fn,
        isOptional = isOptional or false
    })
end

function macroTorch.SelfTest:run()
    -- [CITED: CONTEXT.md D-01, D-05]
    if macroTorch._selfTestRan then return end
    macroTorch._selfTestRan = true

    local passed, failed, warnings = 0, 0, 0
    local failedNames = {}
    local warningNames = {}

    for _, test in ipairs(self.tests) do
        local success, err = pcall(test.fn)
        if success then
            passed = passed + 1
            -- D-05: success items are silent
        else
            if test.isOptional then
                warnings = warnings + 1
                table.insert(warningNames, test.name)
            else
                failed = failed + 1
                table.insert(failedNames, test.name)
            end
        end
    end

    -- summary output
    macroTorch.show(string.format("[macro-torch] Self-test: %d passed, %d failed, %d warnings",
        passed, failed, warnings), 'white')

    -- failed items (error/red)
    for _, name in ipairs(failedNames) do
        macroTorch.show("[macro-torch] FAIL: " .. name, 'red')
    end

    -- warnings (yellow)
    for _, name in ipairs(warningNames) do
        macroTorch.show("[macro-torch] WARN: " .. name, 'yellow')
    end
end
```

### Pattern 2: Wrapper/Delegation API (SpellTrace)

**What:** A new high-level API that delegates to existing low-level functions, maintaining backward compatibility. The low-level functions remain accessible as implementation details.

**When to use:** When replacing verbose command-style calls with configuration-driven declarations, without changing the underlying data structures or processing logic.

**Implementation sketch (verified against core/spell_trace_core.lua:13-47):**

```lua
-- Source: CONTEXT.md D-06, D-07, D-08; core/spell_trace_core.lua:13-47

-- Add AFTER existing setSpellTracing/setTraceSpellImmune definitions
macroTorch.SpellTrace = {}  -- namespace for future extensions

function macroTorch.SpellTrace:register(name, config)
    -- [CITED: CONTEXT.md D-06, D-07]
    -- config: {immune = bool, land = bool, debuffTexture = string}
    if config.land then
        -- Resolve spell name to numeric ID and call setSpellTracing
        -- The spell ID lookup depends on the specific spell.
        -- Target users provide both name and ID per CONTEXT.md.
        -- For Druid phase 3: spell IDs are hardcoded in SM_Extend_Druid.lua
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
    -- D-08: SpellTrace table reserved for future list()/unregister()
end
```

### Pattern 3: SLASH Command with Extensible Dispatch

**What:** A single `/mt` SLASH command that currently only runs self-test but is structured for future mt-script DSL extension.

**When to use:** When you need a command that will grow into a DSL router in future phases.

**Implementation:** One handler function with a simple `if msg == "" or msg == nil then selfTest else reservedFuture` dispatch.

```lua
-- Source: CONTEXT.md D-02, D-10
SLASH_MT1 = "/mt"

function macroTorch.HandleMtCmd(msg)
    -- [CITED: CONTEXT.md D-02, D-10]
    local trimmed = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    if trimmed == "" then
        -- Phase 3: only selftest
        macroTorch.SelfTest:run()
    else
        -- Future: mt-script DSL routing goes here
        -- For now, show help/hint about /mt being selftest-only
    end
end

SlashCmdList["MT"] = macroTorch.HandleMtCmd
```

### Anti-Patterns to Avoid

- **Global state for test results beyond the run() call**: `SelfTest.results` should be transient (reset on each run), not accumulated across runs. The CONTEXT.md D-01 explicitly makes `_selfTestRan` a session flag only.
- **Calling SpellTrace:register() at runtime**: Registration happens at file load time (top-level code), not inside clickContext or combat handlers. The existing `setSpellTracing` calls at SM_Extend_Druid.lua:480-489 are top-level -- maintain this pattern.
- **Hardcoding player class checks in selftest.lua**: Class-specific tests register themselves from their own class files (SM_Extend_Druid.lua). selftest.lua only contains infrastructure tests applicable to ALL classes. This is per CONTEXT.md D-03 tier structure.
- **Using macroTorch.show() for successful tests**: D-05 explicitly says "成功项不打印日志" -- the framework must suppress output on pass. Only the summary line and failed/warning items produce chat output.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test isolation (one failure blocks all) | Manual error guards per test | `pcall(fn)` (Lua builtin) | Already used at core/periodic.lua:131-132. Consistent pattern, zero code. |
| Chat color formatting | Custom color logic | `macroTorch.show(msg, color)` | Existing function supports white/red/yellow/blue/green. Self-test only needs white (summary) + red (fail) + yellow (warn). |
| Function existence check | `if func then` nil test (false on nil) | `macroTorch.isFunctionExist(name)` | Already in impl_util.lua:33-35. Uses `type(_G[name]) == "function"` which is the correct check in WoW 1.12.1 Lua 5.0. |
| Boolean conversion from WoW API (nil/1) | `if val then true else false end` | `macroTorch.toBoolean(val)` | Already in impl_util.lua:29-31. Standard across codebase. |
| Spell name → ID resolution | Custom spellbook scanning | `macroTorch.getSpellUniqIdByName(name, bookType)` | Already in biz_util.lua:36-43. Leverages existing GetSpellName-based lookup. |

**Key insight:** The WoW 1.12.1 addon environment has no package ecosystem. Everything is self-contained Lua 5.0 with WoW API bindings. The patterns already established in the codebase (pcall isolation, macroTorch.show output, isFunctionExist checks) are the correct tools -- don't invent new ones.

## Common Pitfalls

### Pitfall 1: SpellTrace:register() timing -- spell name resolution before spellbook loads

**What goes wrong:** If `SpellTrace:register()` is called before `PLAYER_ENTERING_WORLD`, `getSpellUniqIdByName()` will fail because `GetSpellName()` returns nil until the player's spellbook is populated.

**Why it happens:** In WoW 1.12.1, `GetSpellName()` returns nil during addon loading (before login). This is why the current Druid code at line 480-489 uses hardcoded spell IDs (`9827`, `9904`, `9896`, `31018`) rather than `setSpellTracingByName`.

**How to avoid:** `SpellTrace:register()` for Druid spells should either (a) accept an explicit `spellId` field alongside `name`, or (b) the Druid file registers at a point where spellbook is available. Current code pattern uses hardcoded IDs -- the simplest approach is to add `config.spellId` to the config table.

**Warning signs:** `getSpellUniqIdByName` returns nil for known spell names during file load.

### Pitfall 2: SelfTest:run() output flooding on zone transitions

**What goes wrong:** PLAYER_ENTERING_WORLD fires on every zone change/instance entrance, not just login.

**Why it happens:** WoW 1.12.1 fires this event whenever the player loads into a new world instance, including dungeon entries, battleground joins, and continent crossings.

**How to avoid:** D-01's session flag `macroTorch._selfTestRan` prevents this. Set to `true` on first run, never cleared until reload UI. The flag is NOT stored in `SM_EXTEND` (persistent between sessions), so reloading UI resets it per spec.

**Warning signs:** Self-test output appears after using a flight path or entering an instance.

### Pitfall 3: SelfTest accessing target properties when no target exists

**What goes wrong:** Tests reading `macroTorch.target.health` or `macroTorch.target.isDead` crash when no target is selected.

**Why it happens:** D-04 explicitly states Target/Pet checks should verify method/property existence (not actual values). But even property access via metatable can fail if the underlying Unit/Player instance's `ref` field is "target" and no target exists.

**How to avoid:** All entity property tests (Player/Target/Pet) should be wrapped in pcall. For Target: test that `macroTorch.target` table exists and its known method keys are present. Per D-04, actual invocation (reading `target.health`) should only happen for Player -- Target/Pet only check `type(target.someProperty) == "function"` or key existence.

**Warning signs:** "attempt to call method 'health' (a nil value)" or similar metatable lookup errors.

### Pitfall 4: /mt SLASH command overwriting existing addon registrations

**What goes wrong:** The `/mt` command conflicts with another addon's SLASH_M1 registration.

**Why it happens:** WoW 1.12.1 SLASH commands are global namespace -- any addon can register any command. "mt" is a common abbreviation.

**How to avoid:** Use `SLASH_MT1 = "/mt"` (standard WoW convention). If a conflict exists, the last loaded addon wins. For macro-torch's use case, this is acceptable -- `/mt` is explicitly reserved for macro-torch's mt-script system per CONTEXT.md D-02/D-10.

**Warning signs:** `/mt` triggers another addon's behavior instead of SelfTest.

### Pitfall 5: pcall silencing genuine syntax errors during development

**What goes wrong:** A syntax error in a self-test function will be silently caught by pcall and reported as a test failure, hiding the actual error details.

**Why it happens:** pcall catches ALL errors, not just runtime exceptions. Syntax errors in function definitions may manifest as "attempt to call a nil value" rather than showing the actual syntax problem.

**How to avoid:** The SelfTest:run() should capture pcall error messages and include them in the FAIL output. NOT just count failures, but show `macroTorch.show("[macro-torch] FAIL: " .. name .. " - " .. tostring(err), 'red')`.

**Warning signs:** Test marked FAIL with no clear message about what went wrong.

## Code Examples

Verified patterns from official sources:

### SelfTest:register/run minimal example

```lua
-- Source: CONTEXT.md D-01 through D-05, existing pcall pattern at core/periodic.lua:131-132

-- Registration (in selftest.lua and SM_Extend_Druid.lua):
macroTorch.SelfTest:register("Lua: type() exists", function()
    assert(type(type) == "function", "type() not a function")
end, false)  -- isOptional = false

macroTorch.SelfTest:register("Optional: UnitXP available", function()
    assert(macroTorch.isFunctionExist("UnitXP"), "UnitXP not available")
end, true)  -- isOptional = true -- outputs warning on failure

-- Execution (in core/events.lua eventHandle):
-- Line 52: after macroTorch.onPlayerEnteringWorld()
macroTorch.SelfTest:run()
```

### SpellTrace:register() Druid migration

```lua
-- Before (SM_Extend_Druid.lua:480-489):
macroTorch.setSpellTracing(9827, 'Pounce')
macroTorch.setSpellTracing(9904, 'Rake')
macroTorch.setSpellTracing(9896, 'Rip')
macroTorch.setSpellTracing(31018, 'Ferocious Bite')
macroTorch.setTraceSpellImmune('Pounce', 'Ability_Druid_SupriseAttack')
macroTorch.setTraceSpellImmune('Rake', 'Ability_Druid_Disembowel')
macroTorch.setTraceSpellImmune('Rip', 'Ability_GhoulFrenzy')
macroTorch.setTraceSpellImmune('Faerie Fire (Feral)', 'Spell_Nature_FaerieFire')

-- After (SpellTrace:register):
macroTorch.SpellTrace:register('Pounce', {
    spellId = 9827, land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellId = 9904, land = true,
    immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellId = 9896, land = true,
    immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellId = 31018, land = true,
    immune = false  -- FB has consumeLandEvent but NO immune tracing in current code
})
macroTorch.SpellTrace:register('Faerie Fire (Feral)', {
    land = false,  -- FF is not spell-traced (no setSpellTracing call exists)
    immune = true, debuffTexture = 'Spell_Nature_FaerieFire'
})

-- Note: Claw and Shred do NOT have current spell trace registration in the codebase.
-- They are NOT in lines 480-489. If needed, add new registrations.
```

### SLASH /mt command registration

```lua
-- Source: CONTEXT.md D-02, D-10; WoW 1.12.1 SLASH command convention
-- Place in core/selftest.lua (or separate core/mt_command.lua per Claude's discretion)

SLASH_MT1 = "/mt"
SlashCmdList["MT"] = function(msg)
    -- [CITED: CONTEXT.md D-02, D-10]
    local trimmed = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    if trimmed == "" then
        macroTorch.SelfTest:run()
    else
        macroTorch.show("[macro-torch] /mt: mt-script DSL is reserved for a future phase. Use /mt without arguments to run self-test.", 'yellow')
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `setSpellTracing(id, name)` + `setTraceSpellImmune(name, tex)` scattered per spell | `SpellTrace:register(name, {config})` single declaration per spell | Phase 3 | One config per spell instead of two separate calls. No change to underlying data or logic. |
| No self-test mechanism | `SelfTest:register/run()` framework with pcall isolation | Phase 3 | Catches addon compatibility issues at login rather than discovering them in combat. |
| No SLASH command for macro-torch | `/mt` SLASH command (selftest only for now) | Phase 3 | Manual test trigger. Foundation for future mt-script DSL. |
| Hardcoded spell IDs inline | Same (IDs still required) | No change in Phase 3 | `setSpellTracing` requires numeric IDs; `SpellTrace:register()` passes them through. Spell-name-only resolution requires loaded spellbook which isn't available at addon load time. |

**Deprecated/outdated:**
- Direct `setSpellTracing()` calls from non-core files: Still functional but discouraged. New spell trace registrations should use `SpellTrace:register()`.
- Direct `setTraceSpellImmune()` calls from non-core files: Same status -- discouraged, use `SpellTrace:register()` with `immune=true`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SUPERWOW_STRING` is injected by the SuperWoW addon at C++ level and is not defined in any Lua file | Standard Stack | LOW -- verified by grep across entire codebase; zero definitions found. If SuperWoW is not installed, this variable is simply nil and SUPERWOW_STRING-conditional code (events.lua:42) safely skips. |
| A2 | SP3 addon (spell power calculator) is an optional third-party addon, not bundled with macro-torch | Standard Stack | LOW -- grep across entire codebase shows zero references to "SP3". Mentioned in CONTEXT.md D-03 as optional module check target. |
| A3 | `SpellTrace:register()` needs a `spellId` field (not just `name`) because `GetSpellName()` returns nil during addon loading | Pitfalls | LOW -- verified by examining current code at SM_Extend_Druid.lua:480-489 which uses hardcoded numeric IDs, not `setSpellTracingByName`. |
| A4 | `PLAYER_ENTERING_WORLD` fires on zone transitions, not just login | Pitfalls | MEDIUM -- verified by WoW 1.12.1 documentation; this is a well-known behavior. Mitigated by D-01 session flag. |
| A5 | The `config.land = true` field in SpellTrace:register should trigger `setSpellTracing(spellId, name)` internally | Architecture | LOW -- directly stated in CONTEXT.md D-07: "SpellTrace:register() 内部调用它们操作 tracingSpells/traceSpellImmunes 核心表". |
| A6 | Existing code needs Shred and Claw spell trace registrations added for completeness (not currently traced) | Code Examples | MEDIUM -- current code only traces Pounce/Rake/Rip/FB. Shred/Claw (the most frequently cast Druid abilities) are NOT set for tracing. This may be intentional (to reduce overhead) or an oversight. The planner should confirm with user whether to add Shred/Claw/FB registrations. |

## Open Questions

1. **Should Shred and Claw be added to SpellTrace registration?**
   - What we know: Current code only traces 4 spells (Pounce/Rake/Rip/FB) via setSpellTracing. Shred and Claw -- the most frequently used cat form abilities -- are not traced for land/fail events.
   - What's unclear: Is this intentional (to reduce periodic task overhead on frequently cast spells), or an oversight? Adding them would affect immunity detection logic.
   - Recommendation: Flag in the plan as an explicit decision point. Default behavior: add Shred and Claw registrations to match the pattern of "all cat form damaging spells should be traced".

2. **Should /mt command handler live in core/selftest.lua or a dedicated file?**
   - What we know: CONTEXT.md lists Claude's discretion on file organization. The SLASH handler is simple (1-2 lines dispatch in Phase 3). A dedicated file would align with the future mt-script DSL expansion.
   - What's unclear: Whether the simplicity of Phase 3 justifies a separate file or whether keeping it in selftest.lua (currently ~5 lines) is cleaner.
   - Recommendation: Keep in core/selftest.lua for Phase 3. If/when mt-script DSL is implemented, extract to a dedicated core/mt_command.lua.

3. **Should the build_order.txt insertion point for core/selftest.lua be before or after core/events.lua?**
   - What we know: CONTEXT.md says "core/selftest.lua 需在 core/events.lua 之前（events.lua 调用 SelfTest:run()）". Current build_order.txt has `core/selftest.lua` at line 25, between `core/events.lua` (line 23) and `SM_Extend_Druid.lua` (line 27).
   - What's unclear: The current insertion point (line 25) is AFTER events.lua (line 23), which contradicts the CONTEXT.md instruction. However, in WoW addon loading, all files concatenate first, then execute as a single unit -- so `function` definitions can be referenced regardless of order, as long as the function is defined before the event fires (which it will be, since PLAYER_ENTERING_WORLD is async).
   - Recommendation: Move `core/selftest.lua` to BEFORE `core/events.lua` in build_order.txt per the explicit instruction in CONTEXT.md. While both positions work due to Lua's function hoisting via `function Name()` syntax, the explicit instruction should be followed for clarity.

## Environment Availability

This phase has no external tool/runtime dependencies beyond what already exists in the project. The WoW 1.12.1 client is the execution environment, which is not something we can probe from a terminal.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WoW 1.12.1 Client | All functionality | ✗ (cannot probe from CLI) | Twow / Vanilla | Not applicable -- this is the target environment |
| SuperWoW (optional) | Events UNIT_CASTEVENT, UnitXP distance checks | ✗ (cannot probe from CLI) | client-dependent | Code uses SUPERWOW_STRING nil-guards (core/events.lua:42) |
| UnitXP (optional) | Distance-based features | ✗ (cannot probe from CLI) | client-dependent | Code uses UnitXP nil-guards (entity/Unit.lua:136, entity/Player.lua:487-488) |
| SP3 (optional) | Self-test optional module check | ✗ (cannot probe from CLI) | client-dependent | Self-test will check existence and issue warning if absent |

**Missing dependencies with no fallback:**
- None. All dependencies are WoW client-side and handled with nil-guards in existing code.

**Missing dependencies with fallback:**
- SuperWoW / UnitXP / SP3: All are optional. Self-test detects absence and issues yellow warnings per D-05.

## Validation Architecture

> `nyquist_validation` is explicitly `false` in .planning/config.json. This section is intentionally omitted per config.

## Security Domain

> `security_enforcement` is not set in .planning/config.json. Per instructions: "Omit only if explicitly `false` in config." The key is absent, so per instructions "Absent = enabled." However, this is a WoW 1.12.1 addon -- there are no network security, authentication, or data handling concerns. This is a client-side UI addon with no external communication beyond the WoW API itself.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | WoW client handles auth |
| V3 Session Management | No | Not applicable to addons |
| V4 Access Control | No | WoW API enforces access (protected/spell calls) |
| V5 Input Validation | Yes -- `/mt` command input | arg1/msg string is checked for emptiness; future DSL would need input sanitization |
| V6 Cryptography | No | No cryptographic operations in this addon |

### Known Threat Patterns for WoW 1.12.1 Addons

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SLASH command injection (user types `/mt <malicious_input>`) | Spoofing | Phase 3: msg is only checked for emptiness; no eval or code execution. Future mt-script DSL would need strict input validation. |
| pcall error message leaking internal state to chat | Information Disclosure | Phase 3: pcall includes error content in chat output for debugging; this is intentional for a development addon. Acceptable risk. |
| SelfTest:register() accepting arbitrary function from any file | Elevation of Privilege | Not applicable -- all addon code is same trust domain. No isolation boundary exists between addon modules. |

## Sources

### Primary (HIGH confidence)
- [VERIFIED: codebase] CONTEXT.md at `.planning/phases/03-spell-trace/03-CONTEXT.md` -- all D-01 through D-10 decisions, Claude's discretion areas, integration points
- [VERIFIED: codebase] `.planning/REQUIREMENTS.md` -- R4 (Spell Trace config) and R5 (Self-test) acceptance criteria
- [VERIFIED: codebase] `core/spell_trace_core.lua` -- setSpellTracing (line 18), setTraceSpellImmune (line 35), tracingSpells/traceSpellImmunes tables (lines 15-32), SpellTrace:register integration point
- [VERIFIED: codebase] `core/events.lua` -- PLAYER_ENTERING_WORLD handler (line 50-52), eventHandle dispatch, Phase 3 self-test hook location, SUPERWOW_STRING conditional event registration
- [VERIFIED: codebase] `core/periodic.lua:131-132` -- existing pcall pattern for error isolation
- [VERIFIED: codebase] `SM_Extend_Druid.lua:479-489` -- current spell trace registrations (4 spells), template for rewrite
- [VERIFIED: codebase] `SM_Extend_Druid.lua:233-252` -- DRUID_FIELD_FUNC_MAP (5 fields usable for Phase 3 optional self-test items)
- [VERIFIED: codebase] `entity/Player.lua:465-516` -- PLAYER_FIELD_FUNC_MAP, Player methods (cast, use, hasItem, talentRank, etc.)
- [VERIFIED: codebase] `entity/Unit.lua:100-237` -- UNIT_FIELD_FUNC_MAP, Unit methods (hasBuff, getBuffStacks, etc.)
- [VERIFIED: codebase] `build_order.txt` -- current insertion point for core/selftest.lua at line 25
- [VERIFIED: codebase] `macro_torch.lua` -- macroTorch namespace initialization
- [VERIFIED: codebase] `impl_util.lua` -- toBoolean, isFunctionExist, tableLen, show() output function
- [VERIFIED: codebase] `interface_debug.lua` -- macroTorch.show() with color support (red/yellow/blue/green/white)
- [CITED: official docs] `.claude-reference/Functions.md` -- complete WoW 1.12.1 Macro API reference (1451 lines). Functions to self-test: UnitHealth, UnitMana, UnitClass, GetComboPoints, GetSpellName, GetNumTalentTabs, GetTalentInfo, CastSpellByName, GetNumShapeshiftForms, GetShapeshiftFormInfo, UnitBuff, UnitDebuff, GetTime, IsShiftKeyDown, IsUsableAction, GetActionCooldown, UnitExists, UnitIsDead, UnitCanAttack, UnitAffectingCombat, UnitPowerType, etc.

### Secondary (MEDIUM confidence)
- [CITED: WoW community knowledge] `PLAYER_ENTERING_WORLD` fires on zone transitions (confirmed by multiple WoW addon documentation sources) -- handled by D-01 session flag
- [CITED: WoW 1.12.1 API convention] SLASH command registration pattern `SLASH_<NAME>1 = "/cmd"` and `SlashCmdList["NAME"] = handler` -- standard WoW API

### Tertiary (LOW confidence)
- [ASSUMED] UnitXP addon function signature `UnitXP("behind", "player", "target")` and `UnitXP("distanceBetween", unit1, unit2)` -- inferred from usage at entity/Player.lua:487-488 and entity/Unit.lua:136; actual function signatures are from the UnitXP addon and not verified in official Blizzard docs
- [ASSUMED] SP3 addon functionality -- CONTEXT.md mentions it but codebase has zero references; existence check at self-test is speculative about what "available" means

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no external libraries needed; all components are either existing project code or Lua 5.0 builtins
- Architecture: HIGH -- directly constrained by CONTEXT.md D-01 through D-10, with existing codebase patterns for pcall, table methods, and SLASH commands
- Pitfalls: HIGH -- five of five pitfalls are verified against codebase evidence or CONTEXT.md decisions

**Research date:** 2026-06-08
**Valid until:** 2026-07-08 (stable domain -- WoW 1.12.1 API does not change)

**Potential blind spots:**
- Whether Shred/Claw should have spell trace registrations added (Open Question 1)
- Whether `SpellTrace:register()` should also call `getSpellUniqIdByName()` as a helper for users who don't know their spell IDs -- this would change the config schema from `{spellId, immune, land, debuffTexture}` to `{spellName, immune, land, debuffTexture}` and add a dependency on spellbook being loaded