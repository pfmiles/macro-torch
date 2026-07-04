# Phase 18: spellId 自动更正机制改造方案（最终版） - Research

**Researched:** 2026-07-04
**Domain:** Lua 5.1 / WoW 1.12.1 addon — codebase-internal refactor, no external dependencies
**Confidence:** HIGH

## Summary

Phase 18 是对 Phase 17 spellId 动态更正机制的收尾改造。核心变更：将 `_castSpell` 中无条件的 `current_casting_spell` 设值改为以 `_spellIdMonitored` 白名单守卫，将白名单的维护入口合并到 `SpellTrace:register()` 中。四文件改动，零外部依赖，完全在代码库内部完成。

**Primary recommendation:** 在 `core/spell_trace_core.lua` 第 14 行附近初始化 `macroTorch._spellIdMonitored = {}`；在 `SpellTrace:register` 的 land 分支中，当 `config.spellName` 存在时写入白名单；在 `entity/Player.lua` `_castSpell` 中添加白名单守卫和 stale 检测；新增 Category L selftest（5 个用例）。所有改动遵循项目现有的全局 set table 模式和 `isOptional = isOptional or false` 默认参数模式。

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: 白名单注册时机** — `land=true + config.spellName 存在` 时，`SpellTrace:register` 自动将 `config.spellName` 加入 `macroTorch._spellIdMonitored[spellName] = true`。零额外配置，4 个 Druid 注册无需改动。
- **D-02: 白名单数据结构** — 独立 set table：`macroTorch._spellIdMonitored = {}`，在 `core/spell_trace_core.lua` 顶部初始化。`_castSpell` 通过 `macroTorch._spellIdMonitored[localeNames.en]` 做 O(1) 查表。
- **D-03: SpellTrace API — monitorSpellId 可选字段** — 新增 `config.monitorSpellId` 可选字段，**默认值 = `config.land`**（nil 视为 false）。当前 4 个 Druid land-tracing 注册无需改动（land=true 自动推导 monitorSpellId=true）。未来可通过 `monitorSpellId=false` 在 land=true 时排除，或 `monitorSpellId=true` 在 land=false 时纳入。
- **D-04: current_casting_spell stale 检测** — 保持 Phase 17 清除机制：UNIT_CASTEVENT 处理完 spellId 更正后 `current_casting_spell = nil`（events.lua:119）。新增 stale 检测：`_castSpell` 设置 `current_casting_spell` 前，若已非 nil（上次未清除），通过 `macroTorch.log()` 输出 warning，然后覆盖。
- **D-05: 向后兼容** — `config.spellId` 遗留注册（无 spellName）：不进白名单，land tracing 仍正常工作，但不参与 spellId 更正监控。`setSpellTracing(spellId, name)` 直接调用：不进白名单，保持现有行为不变。

### Claude's Discretion

- `_spellIdMonitored` 在 spell_trace_core.lua 中的具体初始化位置（SpellTrace 命名空间之前/之后）
- stale 检测 warning 的具体日志格式（使用 macroTorch.log 还是 macroTorch.show）
- `config.monitorSpellId` 默认值解析逻辑的具体实现（`if config.monitorSpellId == nil then monitor = config.land end`）
- Selftest Category L 的具体用例数量和覆盖范围

### Deferred Ideas (OUT OF SCOPE)

- **非 land-tracing 技能的 spellId 监控**：若未来某技能 land=false 但需要 spellId 更正，可通过 `monitorSpellId=true` 显式纳入
- **land=true 但排除监控**：若未来某环境 spellId 永远准确，可通过 `monitorSpellId=false` 排除
- **其他职业 land tracing 迁移**：Phase 8 已建立 SpellTrace:register 基础设施，未来职业添加 land tracing 时自动获得白名单监控
- **current_casting_spell 超时清除**：当前评估为过度设计，若 SuperWow 事件丢失问题在实战中被证实，届时再考虑

## Architectural Responsibility Map

Phase 18 的变更分散在 4 个文件中，每个文件的职责边界清晰，不存在跨层职责混淆：

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `_spellIdMonitored` 白名单初始化 + 自动注册 | Infrastructure (core/) | — | 与 `tracingSpells`、`traceSpellImmunes` 同属 spell trace 基础设施层 |
| `_castSpell` 白名单守卫 + stale 检测 | Entity (entity/) | — | `_castSpell` 是施法瓶颈，白名单守卫是施法流程的一部分 |
| `UNIT_CASTEVENT` spellId 更正 | Event Layer (core/) | — | events.lua 是事件处理唯一入口，Phase 17 逻辑保持不变 |
| Selftest Category L | Diagnostics (core/) | — | 验证白名单正确性的诊断代码 |
| 4 个 Druid SpellTrace:register 调用 | Class Logic (classes/) | — | 注册代码不需改动，自动从白名单机制中受益 |

## Standard Stack

Phase 18 使用纯项目内部技术栈，无外部库依赖。

### Core (Project-internal)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lua 5.1 (WoW 1.12.1 embedded) | 5.1 | 所有逻辑 | WoW 1.12.1 客户端内置，不可替换 |
| macroTorch global namespace | — | 模块组织 | 项目约束：WoW 1.12.1 不支持 `require`，所有符号必须全局可见 [VERIFIED: CLAUDE.md] |
| `macroTorch.tableLen(tbl)` | — | 表长度 | WoW 1.12.1 Lua 不支持 `#` 一元长度操作符 [VERIFIED: CLAUDE.md] |

### Supporting (Project-internal)

| Library | Purpose | When to Use |
|---------|---------|-------------|
| `macroTorch.show(a, color)` | 聊天框输出 | 用户可见的运行时通知 |
| `macroTorch.log(a, color)` | 聊天框输出 + SavedVariables 持久化 | 需要跨会话保留的诊断日志 |
| SM_EXTEND | SavedVariable 持久化 | spellId 更正数据跨会话存储（Phase 17 已建立，Phase 18 不改动） |
| `macroTorch.SpellTrace:register()` | 声明式 spell trace 注册 | 白名单自动维护入口 |
| `macroTorch.SelfTest:register()` | 声明式自检注册 | Category L 白名单验证 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 全局 set table (`_spellIdMonitored[name] = true`) | Array with linear scan | O(n) vs O(1)；`macroTorch.tableLen` 额外开销；与项目现有 `tracingSpells` 风格不一致 [ASSUMED] |
| 在 `_castSpell` 中调用 `resolveSpellId` 判断是否监控 | 白名单 set table | 每次施法都需调用 `resolveSpellId`，多一次 table 查找 + 字符串比较；白名单 O(1) 更高效 [ASSUMED] |

## Package Legitimacy Audit

Phase 18 不安装任何外部包。纯粹代码库内部重构，0 个外部依赖。

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      SpellTrace:register(name, config)           │
│                      (core/spell_trace_core.lua:63-83)           │
│                                                                 │
│  config.monitorSpellId 解析:                                     │
│    local shouldMonitor = (config.monitorSpellId ~= nil)          │
│      and config.monitorSpellId                                   │
│      or (config.land or false)                                   │
│                                                                 │
│  if shouldMonitor and config.spellName then                      │
│    ┌──────────────────────────────────────────────────┐         │
│    │  macroTorch._spellIdMonitored[config.spellName]   │         │
│    │    = true                                         │         │
│    └──────────────────────────────────────────────────┘         │
│         │                                                        │
│         │ 写入白名单 set（O(1) 写入）                             │
│         ▼                                                        │
│  macroTorch._spellIdMonitored = {                               │
│    ["Pounce"] = true,                                           │
│    ["Rake"] = true,                                             │
│    ["Rip"] = true,                                              │
│    ["Ferocious Bite"] = true,                                   │
│  }                                                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      _castSpell(localeNames, ...)                │
│                      (entity/Player.lua:42-94)                   │
│                                                                 │
│  if mode ~= 'ready' then                                        │
│    ┌──────────────────────────────────────────────────────┐     │
│    │  -- stale 检测                                       │     │
│    │  if macroTorch.current_casting_spell ~= nil then      │     │
│    │    macroTorch.log(warning_msg, 'yellow')              │     │
│    │  end                                                  │     │
│    │                                                       │     │
│    │  -- 白名单守卫（替代无条件设值）                        │     │
│    │  if macroTorch._spellIdMonitored[localeNames.en] then │     │
│    │    macroTorch.current_casting_spell = localeNames.en  │     │
│    │  end                                                  │     │
│    └──────────────────────────────────────────────────────┘     │
│  end                                                              │
│                                                                 │
│  CastSpellByName / obj.cast (施法执行)                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      UNIT_CASTEVENT handler                      │
│                      (core/events.lua:87-124)                    │
│                                                                 │
│  if castType == 'CAST' then                                     │
│    ┌──────────────────────────────────────────────────────┐     │
│    │  if current_casting_spell ~= nil then                 │     │
│    │    -- 比较 staticSpellId vs event spellId             │     │
│    │    -- 不一致 → 持久化 + tracingSpells key 迁移         │     │
│    │    -- (Phase 17 逻辑，完全不变)                        │     │
│    │  end                                                  │     │
│    │                                                       │     │
│    │  macroTorch.current_casting_spell = nil  -- 清除      │     │
│    │                                                       │     │
│    │  -- recordCastTable (tracing 查找)                     │     │
│    │  if spellId and macroTorch.tracingSpells[spellId]    │     │
│    │    then recordCastTable(...)                          │     │
│    │  end                                                  │     │
│    └──────────────────────────────────────────────────────┘     │
│  end                                                              │
└─────────────────────────────────────────────────────────────────┘
```

**Key design insight:** 白名单的写入和读取完全解耦。`SpellTrace:register` 在代码加载阶段写入白名单；`_castSpell` 在每次施法时读取白名单做 O(1) 查表；`UNIT_CASTEVENT` 在事件到达时读取 `current_casting_spell`（仅当白名单允许时才会被设置）。三者时间错开，无竞态。

### Recommended Project Structure

Phase 18 不创建新文件，仅修改 4 个现有文件：

```
core/spell_trace_core.lua   # 变更1: _spellIdMonitored 初始化 + SpellTrace:register 白名单写入
entity/Player.lua           # 变更2: _castSpell 白名单守卫 + stale 检测
core/events.lua             # 变更3: (不变 — Phase 17 逻辑保持)
core/selftest.lua           # 变更4: 新增 Category L 白名单验证 selftest
classes/druid/Druid.lua     # (不变 — 4 个 register 自动获得白名单监控)
```

### Pattern 1: Global Set Table Initialization

**What:** 在模块顶部初始化一个以 key 为索引、value 为 boolean 的 table，用于 O(1) 成员检测。

**When to use:** 当需要快速检查某个值是否属于某个集合时（白名单/黑名单）。

**Example (from existing codebase):**
```lua
-- Source: core/spell_trace_core.lua:15-17 (existing pattern)
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end

-- Phase 18 new: _spellIdMonitored follows same pattern
-- [CITED: CONTEXT.md D-02]
if not macroTorch._spellIdMonitored then
    macroTorch._spellIdMonitored = {}
end
```

### Pattern 2: Default Boolean Parameter

**What:** 使用 `(x ~= nil) and x or default` 模式处理 nil 布尔参数，既支持显式 false 也支持 nil→default。

**When to use:** 当 config 字段需要默认为另一个字段的值（如 `monitorSpellId` 默认 = `land`）。

**Example (from existing codebase):**
```lua
-- Source: core/selftest.lua:38 (existing pattern)
isOptional = isOptional or false

-- Phase 18 new: monitorSpellId defaults to config.land
-- [CITED: CONTEXT.md D-03]
local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)
```

**Why `(x ~= nil)` instead of `x or default`:** 当 `x = false` 时，`false or default` 会返回 `default`。对于 monitorSpellId，用户可能显式设置 `monitorSpellId = false` 来排除某个 land=true 的 spell，此时 `nil` vs `false` 必须区分。使用 `(config.monitorSpellId ~= nil) and config.monitorSpellId` 确保显式 false 被保留。

### Pattern 3: Bottleneck Guard

**What:** 在单一瓶颈函数中添加条件守卫，一处改动影响所有调用路径。

**When to use:** 当某个函数是所有调用路径的唯一入口时。

**Example:**
```lua
-- Source: entity/Player.lua:82-84 (existing bottleneck, Phase 17 bridge)
-- Phase 18 transforms from unconditional to guarded:
-- BEFORE (Phase 17):
if mode ~= 'ready' then
    macroTorch.current_casting_spell = localeNames.en
end

-- AFTER (Phase 18):
-- [CITED: CONTEXT.md D-02, D-04]
if mode ~= 'ready' then
    -- stale 检测（D-04）
    if macroTorch.current_casting_spell ~= nil then
        macroTorch.log("[macro-torch] current_casting_spell stale: " ..
            tostring(macroTorch.current_casting_spell) ..
            " (not cleared by previous UNIT_CASTEVENT)", 'yellow')
    end
    -- 白名单守卫（D-02）
    if macroTorch._spellIdMonitored[localeNames.en] then
        macroTorch.current_casting_spell = localeNames.en
    end
end
```

### Anti-Patterns to Avoid

- **将白名单检查逻辑放在 `UNIT_CASTEVENT` 回调中:** 一旦 `CastSpellByName` 发出，`current_casting_spell` 已经设置，事件回调再检查白名单为时已晚。守卫必须在 `_castSpell` 中（施法前），不在 events.lua 中。
- **将 `_spellIdMonitored` 初始化放在 SpellTrace 命名空间内:** `SpellTrace:register` 在类文件加载阶段可能被调用，如果 `_spellIdMonitored` 在 SpellTrace 命名空间内部初始化，其他模块对其的引用会变得间接。全局 set table 风格（与 `tracingSpells` 同级）更清晰。
- **使用 `#table` 长度操作符:** WoW 1.12.1 嵌入式 Lua 不支持。使用 `macroTorch.tableLen(tbl)` 或直接 key 查找。
- **使用 `macroTorch.log('warn', message)`:** `macroTorch.log` 实际签名为 `(a, color)`（`interface_debug.lua:103`），不是 `(level, message)`。stale 检测 warning 应使用 `macroTorch.log(message, 'yellow')`。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 白名单成员检测 | 线性扫描 array | set table `tbl[key]` | O(1) vs O(n)；与现有 `tracingSpells`、`traceSpellImmunes` 一致 |
| 默认布尔参数 | 自定义 sentinel 值 | `(x ~= nil) and x or default` | Lua 惯用模式；与现有 `isOptional = isOptional or false` 语义一致 [CITED: selftest.lua:38] |
| 条件守卫施法前检查 | 每个技能方法单独检查 | `_castSpell` 瓶颈守卫 | `_castSpell` 是所有 40+ Druid 技能方法的唯一施法瓶颈，一处改动全覆盖 [CITED: Phase 17 D-06] |

**Key insight:** 白名单机制的价值在于消除 `current_casting_spell` 的无条件污染。在 Phase 17 中，每次施法（包括 FF、Hibernate、Healing Touch 等不需要 spellId 监控的技能）都会设置 `current_casting_spell`，如果 UNIT_CASTEVENT 因为某些原因未触发（如非 SuperWow 客户端），该值就会残留。白名单将设置范围精确限制到需要 spellId 更正的技能，从根本上消除了残留污染。

## Runtime State Inventory

Phase 18 是代码重构，不涉及 rename/refactor/migration。跳过此节。

*(Phase 18 不创建或重命名任何文件、变量名、模块或标识符。所有变更都是纯逻辑添加：新增 table 初始化、守卫条件、selftest——不涉及 renaming 阶段才需要的 Runtime State Inventory。)*

## Common Pitfalls

### Pitfall 1: _spellIdMonitored 初始化顺序错误

**What goes wrong:** 如果 `_spellIdMonitored` 在 `SpellTrace:register` 调用之后才初始化，白名单写入失败（写入 nil table 不会报错但也不会生效）。

**Why it happens:** `SpellTrace:register` 调用在 `classes/druid/Druid.lua` 中，该文件在 `build_order.txt` 中位于 `core/spell_trace_core.lua` 之后。如果 `_spellIdMonitored` 初始化位置在 `SpellTrace:register` 函数定义之后但仍在同一文件加载结束时，Druid.lua 的 register 调用已经执行完毕。

**How to avoid:** 在 `core/spell_trace_core.lua` 的 `SpellTrace = {}` 行之前初始化 `_spellIdMonitored`（建议第 14 行，紧随 `tracingSpells` 初始化之后）。此时 Druid.lua 尚未加载，所有 register 调用都会安全写入已存在的 table。

**Warning signs:** Selftest L1 失败——白名单为空或缺少预期条目。

**Verified in build_order.txt:**
```
core/spell_id_map.lua      # line 21 (resolves before spell_trace_core)
core/spell_trace_core.lua  # line 22 (SpellTrace:register defined here)
...
classes/druid/Druid.lua    # line 28 (SpellTrace:register called here)
```
`_spellIdMonitored` 初始化在 `core/spell_trace_core.lua` 加载时执行（在 SpellTrace:register 函数定义之前）即可保证 Druid.lua 调用 register 时 table 已存在。当前四个文件（spell_id_map → spell_trace_core → spell_trace_immune → events → ... → Druid.lua）的加载顺序已经满足要求。[VERIFIED: build_order.txt]

### Pitfall 2: monitorSpellId 默认值逻辑的 nil-vs-false 混淆

**What goes wrong:** 使用 `local shouldMonitor = config.monitorSpellId or (config.land or false)` 时，`config.monitorSpellId = false` 会被 `false or default` 覆盖为 default值。

**Why it happens:** Lua 中 `false or x` 返回 `x`。如果用户显式设置 `monitorSpellId = false`（意为"即使这是一个 land-tracing spell，也不监控其 spellId"），`or` 短路会跳过 false 直接取 default。

**How to avoid:** 使用 `(config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)`。`nil` 检测确保仅当字段不存在时才走 default，显式 `false` 被保留。

**Warning signs:** 设置 `monitorSpellId=false` 后 spell 仍然被加入白名单。

### Pitfall 3: stale 检测产生噪音日志

**What goes wrong:** 如果在非 SuperWow 环境下（无 UNIT_CASTEVENT），每次施法都会触发 stale 警告。

**Why it happens:** `_castSpell` 设置 `current_casting_spell`，但 UNIT_CASTEVENT 从未清除它（因为事件不存在），导致每次施法都看到"上次未清除"的日志。

**How to avoid:** 此场景在 Phase 18 中已经被白名单机制缓解——只有白名单中的 spell 才会设置 `current_casting_spell`（当前仅 4 个 land-tracing Druid spells）。如果非 SuperWow 环境，这 4 个 spell 的 stale 警告仍然是合理的告警（spellId 更正机制完全不可用）。不应抑制此警告。

**Warning signs:** 聊天框中高频出现 stale 日志。

## Code Examples

### SpellTrace:register 白名单写入逻辑

```lua
-- Source: core/spell_trace_core.lua:63-83 (Phase 18 modified)
-- [CITED: CONTEXT.md D-01, D-03]
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        local spellId = nil
        if config.spellName then
            spellId = macroTorch.resolveSpellId(config.spellName)
        end
        if not spellId then
            spellId = config.spellId
        end
        if not spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId resolved", 'red')
            return
        end
        macroTorch.setSpellTracing(spellId, name)

        -- [NEW Phase 18] 白名单维护: monitorSpellId 默认 = config.land
        local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)
        if shouldMonitor and config.spellName then
            if not macroTorch._spellIdMonitored then
                macroTorch._spellIdMonitored = {}
            end
            macroTorch._spellIdMonitored[config.spellName] = true
        end
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

**Notable:** 白名单初始化 (`if not macroTorch._spellIdMonitored`) 放在 register 函数内部作为防御性检查。提案中的初始化位置（spell_trace_core.lua 顶部）也应该保留，但函数内的 guard 确保即使外部初始化被遗漏，白名单也能正常工作。

### _castSpell 白名单守卫 + stale 检测

```lua
-- Source: entity/Player.lua:77-93 (Phase 18 modified)
-- [CITED: CONTEXT.md D-02, D-04]
-- 4. Execute the cast
if mode ~= 'ready' then
    -- [NEW Phase 18 D-04] stale 检测
    if macroTorch.current_casting_spell ~= nil then
        macroTorch.log("[macro-torch] current_casting_spell was not cleared: " ..
            tostring(macroTorch.current_casting_spell) ..
            ", now overwritten by: " .. localeNames.en, 'yellow')
    end
    -- [NEW Phase 18 D-02] 白名单守卫: 仅受监控的 spell 才设 current_casting_spell
    if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then
        macroTorch.current_casting_spell = localeNames.en
    end
end
if onSelf then
    CastSpellByName(spellName, true)
else
    obj.cast(spellName, rank)
end
return true
```

**Notable:** `macroTorch._spellIdMonitored` 的 nil 检查是防御性的——在 `_spellIdMonitored` 初始化之前（理论上不可能，但安全第一）或为空时，白名单守卫静默跳过（等价于 Phase 17 行为但无 spellId 更正）。

## State of the Art

Phase 18 不是采用新技术——它是将 Phase 17 的"无条件桥接"模式精炼为"白名单守卫"模式，消除 `current_casting_spell` 的过度设置带来的潜在残留污染。

| Old Approach (Phase 17) | Current Approach (Phase 18) | When Changed | Impact |
|--------------------------|----------------------------|--------------|--------|
| `_castSpell` 无条件设置 `current_casting_spell` | 白名单守卫：仅 `_spellIdMonitored[spellName]` 为 true 时设置 | Phase 18 | 消除非监控 spell 的残留污染；自动注册无需手动配置 |
| `SpellTrace:register` 仅处理 tracing/immune | register 同时维护白名单（land + spellName 时自动加入） | Phase 18 | 零额外配置，注册即监控 |
| 无 stale 检测 | `_castSpell` 检测 `current_casting_spell` 未清除并 warning | Phase 18 | 早期发现事件丢失问题 |

**Deprecated/outdated:**
- 无条件 `current_casting_spell` 设值模式：Phase 17 的临时桥接被白名单机制取代。

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (项目内建自检框架) |
| Config file | none — 注册式，各模块调用 `SelfTest:register()` |
| Quick run command | 游戏内输入 `/mt`（无参数） |
| Full suite command | 游戏内输入 `/mt`（触发 PLAYER_ENTERING_WORLD 时自动运行） |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| L-1 | `_spellIdMonitored` 白名单包含 4 个 Druid land-tracing spell | unit (selftest) | 登录后自动运行 | Wave 0 |
| L-2 | `config.monitorSpellId` 默认值推导：nil -> `config.land` 值 | unit (selftest) | 登录后自动运行 | Wave 0 |
| L-3 | `config.monitorSpellId=false` 显式排除 | unit (selftest) | 登录后自动运行 | Wave 0 |
| L-4 | `config.monitorSpellId=true` 在 land=false 时纳入 | unit (selftest) | 登录后自动运行 | Wave 0 |
| L-5 | `config.spellId` 遗留路径不进白名单 | unit (selftest) | 登录后自动运行 | Wave 0 |

### Sampling Rate
- **Per task commit:** 游戏内 `/mt` 手动运行自检
- **Per wave merge:** 全部 selftest 绿色通过
- **Phase gate:** Category L 全部通过 + Category K 全部通过（回归）

### Wave 0 Gaps
- [ ] `core/selftest.lua` — 新增 Category L 5 个测试
- [ ] 白名单验证需要测试 `SpellTrace:register` 实际效果——在 selftest 中创建临时 mock config 调用 register 并验证 `_spellIdMonitored` 的内容

## Security Domain

Phase 18 是 WoW 1.12.1 纯客户端 addon 内部逻辑变更，不涉及网络通信、认证、授权、加密、用户数据处理。无适用的 ASVS 类别。

无安全威胁模式。

## Environment Availability

Step 2.6: SKIPPED（无外部依赖——Phase 18 是纯 Lua 代码变更，不引入新工具、服务、runtime、CLI 或数据库）

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `macroTorch.log(a, color)` 签名适用于 stale 检测 warning 日志（CONTEXT.md 建议的 `macroTorch.log('warn', ...)` 签名与实际函数定义 `interface_debug.lua:103` 不符） | Code Examples | 中等 — 如签名不同，stale warning 格式需调整。已验证实际签名为 `(a, color)` |
| A2 | `_spellIdMonitored` 的防御性 nil 检查在 `_castSpell` 中不会引入性能问题（O(1) table lookup，lazy evaluation） | Code Examples | 低 — 即使无此检查，`macroTorch._spellIdMonitored` 在初始化后永远非 nil |
| A3 | `SpellTrace:register` 函数内部的 `if not macroTorch._spellIdMonitored then` 防御性初始化不会与外部初始化冲突（幂等） | Code Examples | 低 — 两次初始化同一 table 为 `{}` 是安全的幂等操作（仅当外部初始化遗漏时才生效） |
| A4 | 现有 4 个 Druid register 中的 `config.spellName` 值与 `_castSpell` 传入的 `localeNames.en` 值完全一致（大小写、空格） | Architecture | 高 — 如果 spellName 不一致，白名单查表失败，该 spell 的 `current_casting_spell` 不会被设置。当前 Druid.lua 中使用 "Pounce", "Rake", "Rip", "Ferocious Bite"；需要在 _castSpell 的 localeTables 中验证对应的 `.en` 值一致 |

## Open Questions

1. **A4 — spellName 一致性验证**
   - What we know: Druid.lua 的 spell 方法使用 `localeNames.en` 设置 `_castSpell` 参数，需要验证 4 个 land-tracing spell 的 `localeNames.en` 与白名单 key 一致
   - What's unclear: Druid.lua 中 `druidPounce.en`, `druidRake.en`, `druidRip.en`, `druidFerociousBite.en` 的实际值
   - Recommendation: Phase 18 Plan 中应包含一个验证任务，确认 `_spellIdMonitored` key 与 `localeNames.en` 完全匹配

2. **`macroTorch.log` 用于 stale 检测的适当性**
   - What we know: `macroTorch.log` 同时写入聊天框和持久化日志。stale 检测 warning 使用 'yellow' color。
   - What's unclear: 在非 SuperWow 环境中，白名单 4 个 spell 的 stale warning 频率。理论上每个 spell 每次施法都会触发（因为 UNIT_CASTEVENT 不存在）
   - Recommendation: Claude's Discretion —— 若实际游戏测试发现噪音过大，可改为仅首次 stale 时输出 warning（添加 session flag）

## Sources

### Primary (HIGH confidence)
- `entity/Player.lua:42-94` — `_castSpell` 当前实现，Phase 18 修改点 [VERIFIED: codebase]
- `core/spell_trace_core.lua:1-83` — `tracingSpells` 初始化模式、`SpellTrace:register` 实现、`resolveSpellId` [VERIFIED: codebase]
- `core/events.lua:87-124` — UNIT_CASTEVENT spellId 更正逻辑（Phase 17，保持不变）[VERIFIED: codebase]
- `core/selftest.lua:34-39, 614-668` — `SelfTest:register` 默认参数模式、Category K 测试结构 [VERIFIED: codebase]
- `core/spell_id_map.lua:17-32` — SPELL_NAME_TO_ID 8 条目映射 [VERIFIED: codebase]
- `classes/druid/Druid.lua:614-633` — 当前 4 个 land-tracing register 调用 [VERIFIED: codebase]
- `interface_debug.lua:84-110` — `macroTorch.show` 和 `macroTorch.log` 实际签名 [VERIFIED: codebase]
- `build_order.txt` — 文件加载顺序验证 [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- `.planning/phases/17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr/17-CONTEXT.md` — Phase 17 决策（D-06, D-07 桥接生命周期）[CITED: Phase 17 CONTEXT]
- `.planning/phases/18-spellid-spellid-land-tracing-spellidmonitored-current-castin/18-CONTEXT.md` — Phase 18 决策（D-01 到 D-05）[CITED: Phase 18 CONTEXT]

### Tertiary (LOW confidence)
- 无。所有研究均基于代码库实证验证。

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 纯项目内部代码，零外部依赖，所有模式均可在代码库中找到先例
- Architecture: HIGH — 改动分散在 4 个文件，每处的职责边界明确；白名单写入/读取完全解耦
- Pitfalls: HIGH — 三个 pitfalls 均基于代码库分析的具体风险点，有明确的防范措施

**Research date:** 2026-07-04
**Valid until:** 2026-08-03 (30 天——代码库内部研究，稳定性高)