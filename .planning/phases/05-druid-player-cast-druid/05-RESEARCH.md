# Phase 5: Druid 技能方法封装改造 - Research

**Researched:** 2026-06-13
**Domain:** Lua / WoW 1.12.1 Addon — 技能释放接口重构，多语言客户端兼容
**Confidence:** HIGH

## Summary

Phase 5 将 Druid 所有技能释放从字符串驱动的 `player.cast('SkillName')` 调用模式重构为技能对象方法（如 `player.claw()`、`player.prowl('safe')`）。核心技术方案来自 `docs/spell_refactor_plan_druid.txt`（权威技术方案），在 Player 基类新增 `_castSpell` 共享辅助方法实现 locale 选名、ready/safe 检查、资源验证，然后在 Druid 子类中定义 ~40 个极简技能方法（1-4 行参数转发）。

涉及 5 个文件的改动：`entity/Player.lua`（3 个新方法的基类基础设施）、`classes/druid/Druid.lua`（~40 个技能方法定义）、`classes/druid/cat.lua`（11 处调用替换 + 约 16 个 safe/ready 函数删除）、`classes/druid/bear.lua`（6 处调用替换 + 约 9 个 safe/ready 函数删除）、`classes/druid/utility.lua`（13 处调用替换）。总计约 32 处 `player.cast()` 调用点替换，约 23 个 safe/ready 包装函数删除。`build_order.txt` 无需变更。

**Primary recommendation:** 严格遵循 `spell_refactor_plan_druid.txt` 架构设计 — `_castSpell` 在 Player 基类，技能方法在 Druid:new()，mode 参数驱动三种释放策略，resourceCost 同时接受数字和函数引用。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 技能名 locale 选名 | Player 基类 (`_castSpell`) | — | 全局通用逻辑，不应在每个技能方法中重复 |
| spell ready 检查 | Player 基类 (`_castSpell`) | — | `self:isSpellReady()` 已存在于 Player 基类 |
| 施法距离检查 | Player 基类 (`_isInRange`) | — | 基于 `macroTorch.target.distance`（Unit 基类属性），通用逻辑 |
| 资源消耗检查 | Player 基类 (`_hasResource`) | — | 基于 `self.mana`（WoW API UnitMana 按形态自动返回对应资源） |
| 技能方法定义 | Druid 子类 (`classes/druid/Druid.lua`) | — | 职业特有，使用形态无关的接口定义 |
| 技能释放调度 | Druid 调用方 (`cat.lua`/`bear.lua`/`utility.lua`) | — | 战斗模块决定何时释放哪个技能（只关心 mode，不关心底层名） |

## Standard Stack

Phase 5 不引入任何外部依赖。这是纯 Lua 代码重构，所有基础设施已就位：

### Core (Existing Infrastructure)
| Library/Pattern | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW 1.12.1 Lua | Embedded | 运行环境 | 目标平台（Turtle WoW） |
| `GetLocale()` | WoW API | 客户端语言检测 | 返回 'enUS'/'zhCN' 等 [VERIFIED: .claude-reference/Functions.md line 1162] |
| `SpellReady()` | WoW API | 技能冷却就绪检查 | 现有 `isSpellReady()` 已使用 |
| `UnitMana('player')` | WoW API | 资源获取（能量/怒气/蓝量） | 按形态自动返回对应资源类型 |
| `macroTorch.target.distance` | Unit.lua FIELD_FUNC_MAP | 目标距离 | 现有距离计算属性 [VERIFIED: entity/Unit.lua lines 135-136] |

### Required Patterns (Already Established)
| Pattern | File | Role in Phase 5 |
|---------|------|-----------------|
| `macroTorch.classMetatable()` | `core/class.lua` | Druid 实例 metatable 链（已使用） |
| `player.cast(spellName, onSelf)` | `entity/Player.lua` | `_castSpell` 最终调用的释放方法 |
| `player.isSpellReady(spellName)` | `entity/Player.lua` | ready 检查 |
| `clickContext` 缓存模式 | `classes/druid/Druid.lua` | 能量消耗函数引用依赖此模式 |
| `macroTorch.computeClaw_E()` 等 | `classes/druid/Druid.lua` | 作为 resourceCost 函数引用传入 |

### Installation
```bash
# No external package installation required — this is a pure code refactoring.
# Verify existing build works:
./build.sh
```

## Package Legitimacy Audit

**No external packages installed.** Phase 5 is a pure code refactoring within the existing codebase. All dependencies (WoW 1.12.1 API, existing macroTorch infrastructure) are already present.

## Architecture Patterns

### System Architecture Diagram

```
User presses key
    |
    v
catAtk() / bearAtk() / druidBuffs() / etc.  (calling code in cat.lua/bear.lua/utility.lua)
    |
    |--- player.claw('safe')  (Druid instance method, defines in Druid.lua)
    |        |
    |        v
    |    self:_castSpell({ en='Claw', zh='爪击' }, 'safe', 近战, macroTorch.computeClaw_E, false)
    |        |
    |        v
    |    Player._castSpell()  (entity/Player.lua — 共享核心)
    |        |
    |        |--- 1. locale select: GetLocale() → 'enUS' or 'zhCN' → spellName
    |        |--- 2. mode != 'raw'? check self:isSpellReady(spellName) → false? return false
    |        |--- 3. mode == 'safe'?
    |        |      |--- range? check self:_isInRange(range) → false? return false
    |        |      |--- resourceCost?
    |        |             |--- type(n) == 'number' → cost = n
    |        |             |--- type(n) == 'function' → cost = n()
    |        |             |--- self:_hasResource(cost) → false? return false
    |        |--- 4. self:cast(spellName, onSelf) → return true
    |
    v
self:cast(spellName, onSelf)  (Player.cast, existing)
    |
    v
macroTorch.castSpellByName(spellName, 'spell')  (biz_util.lua)
    |
    v
CastSpell(spellId, 'spell')  (WoW API)

Key decision points:
- localeNames: luau table keyed by short locale prefix ('en'/'zh')
- mode: nil/'ready' (default), 'raw' (direct), 'safe' (ready + range + resource)
- resourceCost: number (fixed) OR function reference (dynamic, called with zero args)
- onSelf: false (Type A), true (Type B), transparent (Type C)
```

### Recommended Project Structure (Post-Phase 5)
```
entity/
  Player.lua                   # +3 methods: _castSpell, _isInRange, _hasResource
classes/druid/
  Druid.lua                    # +~40 skill methods in Druid:new()
  cat.lua                      # -~16 safe/ready functions, ~11 call site replacements
  bear.lua                     # -~9 safe/ready functions, ~6 call site replacements
  utility.lua                  # ~13 call site replacements
```

### Pattern 1: _castSpell — Shared Spell Casting Core

**What:** Single method on Player base class that encapsulates all locale selection, readiness checking, distance checking, and resource checking logic. Each class-specific skill method is a thin wrapper that forwards parameters.

**When to use:** Every Druid skill method (and future class skill methods) routes through this.

**Implementation reference (from spell_refactor_plan_druid.txt lines 17-42):**
```lua
-- In entity/Player.lua, inside Player:new():
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
    -- 1. locale-based spell name selection
    local locale = GetLocale()
    local spellName
    if locale == 'zhCN' then
        spellName = localeNames.zh
    else
        spellName = localeNames.en  -- fallback to English for all other locales
    end
    -- 2. ready check (skip for 'raw' mode)
    if mode ~= 'raw' then
        if not self:isSpellReady(spellName) then
            return false
        end
    end
    -- 3. safe checks: distance + resource
    if mode == 'safe' then
        if range then
            if not self:_isInRange(range) then
                return false
            end
        end
        if resourceCost then
            local cost
            if type(resourceCost) == 'function' then
                cost = resourceCost()
            else
                cost = resourceCost
            end
            if not self:_hasResource(cost) then
                return false
            end
        end
    end
    -- 4. cast the spell
    self:cast(spellName, onSelf)
    return true
end
```

**Key design decisions:**
- `GetLocale()` return value: 'enUS' or 'zhCN' [VERIFIED: .claude-reference/Functions.md line 1162, warcraft.wiki.gg]. On Turtle WoW, Chinese client returns 'zhCN'.
- Locale table uses short keys: `{ en = 'Claw', zh = '爪击' }` (not 'enUS'/'zhCN') — the method checks `locale == 'zhCN'` to pick zh, else falls back to en
- `resourceCost` as function: called with zero arguments (`cost = resourceCost()`), expects a number return
- `onSelf` parameter: directly passed to `self:cast(spellName, onSelf)` — preserving existing semantics
- Returns boolean: `true` if spell was cast, `false` if blocked by check

### Pattern 2: Three Skill Method Signatures

**What:** Three parameter profiles for skill methods based on target type.

**When to use:**
- Type A: Enemy-only spells (claw, shred, wrath, etc.) — ~27 skills
- Type B: Self-only spells (prowl, dash, forms, etc.) — ~18 skills
- Type C: Flexible target spells (heals, dispels, buffs) — ~9 skills

**Example:**
```lua
-- Type A: Enemy target only (onSelf fixed to false)
function obj.claw(mode)
    return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end

-- Type B: Self target only (onSelf fixed to true)
function obj.prowl(mode)
    return self:_castSpell({ en = 'Prowl', zh = '潜行' }, mode, nil, 0, true)
end

-- Type C: Flexible target (onSelf exposed)
function obj.healing_touch(mode, onSelf)
    return self:_castSpell({ en = 'Healing Touch', zh = '治疗之触' }, mode, 40, nil, onSelf)
end
```

### Pattern 3: Call-Site Replacement — safe/ready → mode Parameter

**What:** The existing safe/ready dual-function pattern is replaced by passing the appropriate mode string to the skill method.

**When to use:** Every call site that previously used `safeXxx(clickContext)` or `readyXxx(clickContext)`.

**Example:**
```lua
-- BEFORE (cat.lua):
function macroTorch.safeShred(clickContext)
    return macroTorch.player.mana >= clickContext.SHRED_E and macroTorch.readyShred(clickContext)
end
function macroTorch.readyShred(clickContext)
    if macroTorch.player.isSpellReady('Shred') then
        macroTorch.player.cast('Shred')
        return true
    end
    return false
end

-- AFTER: all of the above is deleted and replaced with mode-based calls:
-- ooc path (was readyShred): player.shred()      -- nil = ready mode
-- non-ooc path (was safeShred): player.shred('safe')  -- checks resource
```

### Pattern 4: resourceCost as Dynamic Function Reference

**What:** For spells with talent/item-dependent energy costs, the skill method accepts a function reference instead of a hardcoded number. `_castSpell` calls the function at check time to get the current cost.

**When to use:** Cat form energy abilities (claw, shred, rake, tiger_fury) where talents (Ferocity, Improved Shred) and items (Idol of Ferocity) modify costs.

**Example:**
```lua
function obj.claw(mode)
    -- macroTorch.computeClaw_E() returns current energy cost considering talents + idol
    return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end
-- In _castSpell: cost = resourceCost()  -- calls macroTorch.computeClaw_E() at check time
```

### Anti-Patterns to Avoid
- **Calling `GetLocale()` inside each skill method:** Locale detection should happen once in `_castSpell`, not duplicated across 40+ methods
- **Hardcoding 'enUS'/'zhCN' locale keys in the localeNames table:** Use short keys 'en'/'zh' for the table, let `_castSpell` map 'zhCN' to 'zh'
- **Defining skill methods outside Druid:new():** Must be in constructor to access `self:_castSpell()` via closure
- **Creating a new `cast` override in Druid:new():** The existing comment-blocked `cast` function in Druid.lua (line 26) must remain commented — skill methods use `_castSpell` not `cast`
- **Forgetting `onSelf` for utility.lua buff spells:** `player.cast('Mark of the Wild', true)` becomes `player.mark_of_the_wild(nil, true)` — Type C signature with `onSelf`
- **Using `#` length operator:** WoW 1.12.1 embedded Lua does not support `#` [CITED: CLAUDE.md]. Use `macroTorch.tableLen()` or `table.insert()`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spell name localization | Custom locale detection framework | `GetLocale()` WoW API + inline table `{ en='...', zh='...' }` | Already available, no framework needed [D-02: inline table decision] |
| Spell readiness checking | Re-implement GCD/cooldown logic | `self:isSpellReady(spellName)` existing Player method | Already exists in Player.lua:102-104 |
| Resource checking | Custom resource type detection | `self.mana` (WoW 1.12.1 UnitMana auto-resource) | WoW API returns correct resource per form: energy in cat, rage in bear, mana in caster [CITED: spell_refactor_plan_druid.txt line 49, CLAUDE.md] |
| Distance checking | Custom distance calculation | `macroTorch.target.distance` (existing Unit property) | Already exists in Unit.lua:135-136 via UnitXP('distanceBetween') |
| Spell casting | Direct CastSpellByName | `self:cast(spellName, onSelf)` existing Player method | Wraps macroTorch.castSpellByName which uses CastSpell(spellId, 'spell') via spellbook lookup |

**Key insight:** All underlying infrastructure already exists. Phase 5 adds a single `_castSpell` orchestration layer on top, not a new spell system. The 40+ skill methods are thin wrappers (1-4 lines each) that do nothing but forward parameters.

## Common Pitfalls

### Pitfall 1: Stale energy costs from clickContext

**What goes wrong:** When `resourceCost` is a function reference (e.g., `macroTorch.computeClaw_E()`), it's called inside `_castSpell` which runs during the module execution phase. If `catAtk` hasn't been called to initialize `clickContext` values yet, the function may read stale or nil values.

**Why it happens:** `computeClaw_E()` reads `macroTorch.player.talentRank('Ferocity')` and `macroTorch.player.isItemEquipped('Idol of Ferocity')` — these are always valid. The `macroTorch.compute*_E()` functions don't depend on clickContext; they query player state directly. This concern is actually a non-issue for the compute functions used in this phase.

**How to avoid:** Verify each `resourceCost` function reference's dependencies. The current energy calculation functions (`computeClaw_E`, `computeShred_E`, `computeRake_E`, `computeTiger_E`) all query player state (talents, equipped items) — not clickContext. They are safe to call from `_castSpell`.

**Warning signs:** If a future `resourceCost` function references `clickContext`, it will fail because `_castSpell` doesn't have access to clickContext. This is by design — skill methods are clickContext-agnostic.

### Pitfall 2: Druid.lua 'cast' method shadowing

**What goes wrong:** Druid.lua line 26 currently has a commented-out `obj.cast()` definition. If this is accidentally uncommented, it will shadow `Player.cast()` and break the entire refactoring chain (since `_castSpell` calls `self:cast()`).

**Why it happens:** The commented code is a leftover from a previous refactoring attempt. The comment `-- function obj.cast(spellName, onSelf)` at line 26 with `-- end` comments around it.

**How to avoid:** Remove the commented-out `cast` block from `Druid.lua` entirely during Phase 5. Do NOT uncomment it.

**Warning signs:** If SM_Extend.lua contains `function obj.cast` inside Druid:new(), the build order is wrong or the comment was removed.

### Pitfall 3: Gettysburg Address search failure for multi-word spell names

**What goes wrong:** Spells like "Faerie Fire (Feral)" or "Mark of the Wild" have multi-word names that must match exactly what `GetSpellName()` returns.

**Why it happens:** `getSpellIdByName` does case-insensitive comparison of the full spell name. The names in the locale table must match exactly what the WoW API returns, including capitalization (first letter of each word, rest lowercase is typical for enUS).

**How to avoid:** Use spell names from `spell_refactor_plan_druid.txt` Section 4 which documents the exact English names. Chinese names should match Turtle WoW zhCN client localization. Test in-game on both locales.

**Warning signs:** `isSpellReady()` returning false or `nil` spellId on an English client means the `en` key value doesn't match.

### Pitfall 4: OnSelf parameter being ignored by current cast()

**What goes wrong:** The existing `obj.cast(spellName, onSelf)` in Player.lua line 29-31 **ignores the onSelf parameter** — it calls `macroTorch.castSpellByName(spellName, 'spell')` which uses `CastSpell(spellId, bookType)` without an onSelf flag. The `_castSpell` passes `onSelf` through, but it has no effect in the current codebase.

**Why it happens:** The current spell casting infrastructure uses spell ID lookup (`CastSpell(spellId, bookType)`) rather than name-based casting which would need `onSelf`. Historically, the onSelf parameter was accepted but never implemented.

**How to avoid:** Document this explicitly. The `onSelf` parameter is preserved in the method signature for future use (when spell casting is potentially upgraded to support self-targeting through a different mechanism), but currently has no effect. This does not break anything since the old code also passed `onSelf=true` with no effect.

**Warning signs:** If self-targeting spells (Mark of the Wild, Thorns, Prowl) stop working on the player in-game, the onSelf parameter behavior has changed unexpectedly.

### Pitfall 5: Mode parameter 'ready' vs nil inconsistency

**What goes wrong:** The spec says mode `nil` == `'ready'` (default behavior). But if `nil` and `'ready'` have different code paths in `_castSpell`, call sites using `player.claw()` (nil) and `player.claw('ready')` would behave differently.

**Why it happens:** If the `_castSpell` implementation treats `nil` and `'ready'` differently — e.g., `mode == 'ready'` check would fail for `nil`.

**How to avoid:** Handle the default case explicitly:
```lua
if mode ~= 'raw' then  -- covers both nil (default) and 'ready'
    if not self:isSpellReady(spellName) then return false end
end
```
The distinction between nil and 'ready' is semantic only — both mean "do the ready check". Only 'raw' and 'safe' have different behavior.

**Warning signs:** If `player.claw()` works but `player.claw('ready')` doesn't (or vice versa), the mode check logic is wrong.

## Code Examples

### _castSpell — Complete Implementation (from spell_refactor_plan_druid.txt)
```lua
-- Source: docs/spell_refactor_plan_druid.txt lines 17-42
-- Added to Player:new() in entity/Player.lua
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
    -- 1. Locale-based spell name selection
    local locale = GetLocale()
    local spellName
    if locale == 'zhCN' and localeNames.zh then
        spellName = localeNames.zh
    else
        spellName = localeNames.en
    end

    -- 2. Readiness check (skip if mode is 'raw')
    if mode ~= 'raw' then
        if not self:isSpellReady(spellName) then
            return false
        end
    end

    -- 3. Safe mode: distance + resource checks
    if mode == 'safe' then
        if range and not self:_isInRange(range) then
            return false
        end
        if resourceCost then
            local cost
            if type(resourceCost) == 'function' then
                cost = resourceCost()
            else
                cost = resourceCost
            end
            if not self:_hasResource(cost) then
                return false
            end
        end
    end

    -- 4. Execute the cast
    self:cast(spellName, onSelf or false)
    return true
end
```

### _isInRange — Distance Check Helper
```lua
-- Source: spell_refactor_plan_druid.txt lines 47-48; existing pattern from entity/Unit.lua:135-136
-- Added to Player:new() in entity/Player.lua
function obj._isInRange(range)
    if not macroTorch.target or not macroTorch.target.isExist then
        return false
    end
    if type(range) ~= 'number' or range <= 0 then
        return true  -- nil/0 range = melee, always considered in range if target exists
    end
    return macroTorch.target.distance <= range
end
```

### _hasResource — Resource Check Helper
```lua
-- Source: spell_refactor_plan_druid.txt lines 47-49
-- Added to Player:new() in entity/Player.lua
-- WoW 1.12.1: UnitMana('player') returns energy in cat, rage in bear, mana in caster
function obj._hasResource(cost)
    return self.mana >= cost
end
```

### Skill Method — Type A (Enemy Target)
```lua
-- Source: spell_refactor_plan_druid.txt section 4.1
-- Added to Druid:new() in classes/druid/Druid.lua
function obj.claw(mode)
    return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end
```

### Skill Method — Type B (Self Target)
```lua
-- Source: spell_refactor_plan_druid.txt section 4.2
-- Added to Druid:new() in classes/druid/Druid.lua
function obj.prowl(mode)
    return self:_castSpell({ en = 'Prowl', zh = '潜行' }, mode, nil, 0, true)
end
```

### Skill Method — Type C (Flexible Target)
```lua
-- Source: spell_refactor_plan_druid.txt section 4.3
-- Added to Druid:new() in classes/druid/Druid.lua
function obj.mark_of_the_wild(mode, onSelf)
    return self:_castSpell({ en = 'Mark of the Wild', zh = '野性印记' }, mode, 30, nil, onSelf)
end
```

### Call-Site Migration Example — safeShred/readyShred → player.shred()
```lua
-- BEFORE (cat.lua — these functions are DELETED):
function macroTorch.safeShred(clickContext)
    return macroTorch.player.mana >= clickContext.SHRED_E and macroTorch.readyShred(clickContext)
end
function macroTorch.readyShred(clickContext)
    if macroTorch.player.isSpellReady('Shred') then
        macroTorch.player.cast('Shred')
        return true
    end
    return false
end

-- AFTER (cat.lua regularAttack — mode-based calls):
function macroTorch.regularAttack(clickContext)
    if macroTorch.shouldUseShred(clickContext) then
        if clickContext.ooc then
            macroTorch.player.shred()        -- ooc: ready mode (no energy check)
        else
            macroTorch.player.shred('safe')   -- normal: safe mode (checks energy)
        end
    else
        if clickContext.ooc then
            macroTorch.player.claw()          -- ooc: ready mode
        else
            macroTorch.player.claw('safe')    -- normal: safe mode
        end
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `player.cast('Claw')` string literal | `player.claw()` / `player.claw('safe')` method | Phase 5 | Type-safe, locale-agnostic, mode-aware |
| `safeShred(clickContext)` / `readyShred(clickContext)` dual functions | `player.shred('safe')` / `player.shred()` single method | Phase 5 | ~23 functions eliminated, mode parameter unified |
| English-only hardcoded spell names | `{ en = 'Claw', zh = '爪击' }` inline locale table | Phase 5 | Chinese client support |
| Resource check in every safe function | `_hasResource(cost)` centralized in `_castSpell` | Phase 5 | Single implementation, no duplication |

**Deprecated/outdated:**
- `player.cast(string)` pattern: replaced by skill object methods across all Druid files
- `macroTorch.safeShred/safeClaw/safeRake/safeRip/safeBite/safeCower/safeTigerFury/safePounce/readyShred/readyClaw/readyBite/readyCower/safeMaul/safeSwipe/safeSavageBite/safeDemoralizingRoar/readyMaul/readySwipe/readySavageBite/readyDemoralizingRoar/readyGrowl/readyReshift/safeFF` — all deleted

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Full replacement. All `player.cast('SkillName')` calls and safe/ready wrapper functions (~20+ functions) replaced with skill method calls in one pass. Old functions deleted. No thin wrappers retained.
- **D-02:** Inline locale tables. Each skill method directly contains `{ en = 'Claw', zh = '爪击' }`. No centralized constants table or external config file.
- **D-03:** Core first migration order. `classes/druid/Druid.lua` (skill method definitions) -> `classes/druid/cat.lua` (11 calls, most complex) -> `classes/druid/bear.lua` (6 calls) -> `classes/druid/utility.lua` (13 calls).
- **D-04:** All Druid skill methods (~40) centralized in `classes/druid/Druid.lua`'s `Druid:new()` constructor. Cat/bear/utility callers use `player.xxx()`. Skills are form-agnostic interface definitions.
- **D-05:** Player base class new `_castSpell(localeNames, mode, range, resourceCost, onSelf)` method in `entity/Player.lua`. Handles: locale selection -> ready check -> safe checks (distance + resource) -> `self:cast(spellName, onSelf)`.
- **D-06:** mode parameter: `nil` (default ready strategy), `'raw'` (direct cast, no checks), `'safe'` (ready + distance + resource checks).
- **D-07:** Three skill method signatures: Type A (enemy, onSelf=false), Type B (self, onSelf=true), Type C (flexible, onSelf exposed).
- **D-08:** resourceCost accepts both numbers (fixed cost) and function references (dynamic cost, e.g., `macroTorch.computeClaw_E`), resolved by `_castSpell` via type check.

### Claude's Discretion
- `_isInRange(range)` implementation (use existing `macroTorch.target.distance` pattern)
- `_hasResource(cost)` implementation (based on `self.mana`, WoW 1.12.1 auto-returns correct resource per form)
- Exact placement and coding style of new helper methods in `entity/Player.lua`
- Bear form dynamic cost concrete values (spec says "mark as fixed values first, refine later")
- Error handling and edge cases within `_castSpell` (nil target, etc.)

### Deferred Ideas (OUT OF SCOPE)
- Other class migrations (Hunter, Mage, Priest, Rogue, Warlock, Warrior) — separate future Phases
- Bear form rage cost calculation functions — Phase 5 uses fixed values, refined later
- Multi-language expansion beyond en/zh — current inline table approach sufficient
- Item/trinket method wrapping — spell methods only, `player.use()` unchanged

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `GetLocale()` returns 'zhCN' on Chinese Turtle WoW client | Architecture Patterns | LOW — verified via .claude-reference/Functions.md and warcraft.wiki.gg |
| A2 | Bear form skill resource costs can use fixed numeric values as placeholders | Skill Method List | LOW — explicit Claude's Discretion item, bear form secondary |
| A3 | `macroTorch.compute*_E()` functions do not depend on `clickContext` | Common Pitfalls | LOW — verified by reading function bodies in Druid.lua (lines 343-387) |
| A4 | `Range` parameter for melee skills is `nil` (meaning no distance check at nil) | _isInRange implementation | LOW — per spec, melee skills always in range if target exists |
| A5 | `self:cast(spellName, onSelf)` current implementation ignores onSelf | Architecture Patterns | NONE — verified by reading Player.lua line 29-31 |

## Open Questions (RESOLVED)

1. **Bear form rage cost fixed values** — RESOLVED
   - What we know: The current bear code uses fixed values (`MAUL_E = 10`, `SWIPE_E = 15`, etc.) with a todo comment about rage cost being dynamic
   - What's unclear: Whether these fixed values are accurate enough for Phase 5, or if the spec's "dynamic(function)" notation means we should create compute functions now
   - Recommendation: Use fixed numbers from existing bear code (`clickContext.MAUL_E = 10` etc.) as the resourceCost parameter. Move dynamic function creation to a future Phase per the Deferred Ideas.

2. **`player.cast('Ravage')` in Druid.lua opener mod** — RESOLVED
   - What we know: Line 191 of Druid.lua uses `player.cast('Ravage')` but Ravage is not in the spec's skill method list (Section 4 does not list Ravage as a standalone skill — it's only mentioned as an opener alternative to Pounce in Section 5 "Key Strategic Decisions")
   - What's unclear: Should Ravage get a skill method wrapper like `player.ravage()` or is this intentionally excluded?
   - Recommendation: Add `player.ravage()` as a Type A method (melee range, onSelf=false, enemy target). Even though the spec doesn't list it explicitly, consistency demands all `player.cast()` calls be replaced per D-01.

3. **`safeFF` uses `isGcdOk` pattern not matched by `_castSpell`** — RESOLVED
   - What we know: `macroTorch.safeFF()` (Druid.lua line 990-1002) checks `isGcdOk(clickContext)` in addition to spell readiness. The `_castSpell` spec does not include GCD checking.
   - What's unclear: Should GCD checking be added to `_castSpell` as an optional parameter, or should FF continue to use its custom wrapper?
   - Recommendation: Keep GCD checking outside `_castSpell` for now. The `safeFF` function can be rewritten to call `player.faerie_fire_feral('raw')` after its own external readiness/GCD checks. This avoids overcomplicating the `_castSpell` interface.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | build.sh | Yes | Darwin zsh 5.9 | — |
| node (gsd-tools) | Research/planning tooling | Yes | v22.17.0 | — |
| build.sh | Build verification | Yes | working | — |
| SM_Extend.lua generation | Full build cycle | Yes | Build OK | — |

**Missing dependencies with no fallback:** None — all required tooling available.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (manual in-game testing + build.sh syntax verification) |
| Config file | none |
| Quick run command | `./build.sh` (syntax check via Lua parser) |
| Full suite command | `./build.sh && echo "Build OK"` (then manual in-game test) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-01 | All player.cast() replacements + safe/ready function deletions | manual | `grep -c 'player\.cast(' classes/druid/*.lua` should be 0 | N/A (grep verification) |
| D-05 | _castSpell locale selection works on both enUS and zhCN clients | manual (in-game) | Cannot automate — requires WoW client | N/A |
| D-06 | Mode parameter behaves correctly (nil/'raw'/'safe') | manual | `./build.sh` for syntax + in-game for behavior | N/A |
| R8 | catAtk/bearAtk/druidBuffs behavior unchanged | manual (in-game) | `./build.sh` verifies all functions in SM_Extend.lua | N/A |

### Sampling Rate
- **Per task commit:** `./build.sh` (verifies no Lua syntax errors introduced)
- **Per wave merge:** `./build.sh` + grep verification (no remaining player.cast calls)
- **Phase gate:** Build OK + manual in-game test on English client (enUS)

### Wave 0 Gaps
- No automated test framework for WoW 1.12.1 Lua addons exists — runtime testing requires the WoW game client
- No CI/CD pipeline available for in-game behavior verification
- Manual testing required: verify all ~40 skills cast correctly in-game on English client, check that key functions (catAtk, regularAttack, keepRip, keepRake, keepFF, bearAtk, druidBuffs, druidStun, druidDefend, druidControl) behave identically to pre-refactor

## Security Domain

Phase 5 is a pure code refactoring with no security surface changes. No new external dependencies, no user input handling changes, no authentication or session management modifications.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not applicable (WoW addon) |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Not applicable |
| V5 Input Validation | No (pass-through) | Spell names come from hardcoded inline tables, not user input. The `mode` parameter is validated by simple string equality checks. |
| V6 Cryptography | No | Not applicable |

### Known Threat Patterns for WoW 1.12.1 Addon (Lua)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| None applicable | — | Phase 5 does not introduce any attack surface — it replaces string literals with method calls, all spell names are hardcoded |

## Skill Method Mapping: Druid ~40 Skills

Based on `spell_refactor_plan_druid.txt` sections 4.1-4.3, the following skill methods must be added to `Druid:new()`:

### Type A — Enemy Target Only (onSelf=false)
```lua
-- Cat form (energy)
obj.claw(mode)              → _castSpell({en='Claw',zh='爪击'}, mode, nil, macroTorch.computeClaw_E, false)
obj.shred(mode)             → _castSpell({en='Shred',zh='撕碎'}, mode, nil, macroTorch.computeShred_E, false)
obj.rake(mode)              → _castSpell({en='Rake',zh='斜掠'}, mode, nil, macroTorch.computeRake_E, false)
obj.rip(mode)               → _castSpell({en='Rip',zh='撕扯'}, mode, nil, 30, false)
obj.ferocious_bite(mode)    → _castSpell({en='Ferocious Bite',zh='凶猛撕咬'}, mode, nil, 35, false)
obj.pounce(mode)            → _castSpell({en='Pounce',zh='突袭'}, mode, nil, 50, false)
obj.cower(mode)             → _castSpell({en='Cower',zh='畏缩'}, mode, nil, 20, false)
obj.faerie_fire_feral(mode) → _castSpell({en='Faerie Fire (Feral)',zh='精灵之火（野性）'}, mode, nil, 0, false)
-- Bear form (rage) — using fixed values for now
obj.growl(mode)             → _castSpell({en='Growl',zh='低吼'}, mode, nil, 10, false) [ASSUMED: fixed cost]
obj.bash(mode)              → _castSpell({en='Bash',zh='猛击'}, mode, nil, 10, false) [ASSUMED: fixed cost]
obj.swipe(mode)             → _castSpell({en='Swipe',zh='横扫'}, mode, nil, 15, false)
obj.maul(mode)              → _castSpell({en='Maul',zh='重击'}, mode, nil, 10, false)
obj.demoralizing_roar(mode) → _castSpell({en='Demoralizing Roar',zh='挫志咆哮'}, mode, nil, 10, false)
obj.feral_charge(mode)      → _castSpell({en='Feral Charge',zh='野性冲锋'}, mode, 25, nil, false) [ASSUMED: 25yd max range, unknown cost]
obj.challenging_roar(mode)  → _castSpell({en='Challenging Roar',zh='挑战咆哮'}, mode, nil, 15, false) [ASSUMED: fixed cost]
-- Caster form (mana)
obj.wrath(mode)             → _castSpell({en='Wrath',zh='愤怒'}, mode, 30, nil, false) [ASSUMED: fixed mana cost, unknown value]
obj.moonfire(mode)          → _castSpell({en='Moonfire',zh='月火术'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.starfire(mode)          → _castSpell({en='Starfire',zh='星火术'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.entangling_roots(mode)  → _castSpell({en='Entangling Roots',zh='纠缠根须'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.hibernate(mode)         → _castSpell({en='Hibernate',zh='休眠'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.faerie_fire(mode)       → _castSpell({en='Faerie Fire',zh='精灵之火'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.insect_swarm(mode)      → _castSpell({en='Insect Swarm',zh='虫群'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
obj.soothe_animal(mode)     → _castSpell({en='Soothe Animal',zh='安抚动物'}, mode, 30, nil, false) [ASSUMED: fixed mana cost]
```

### Type B — Self Target Only (onSelf=true)
```lua
-- Forms
obj.bear_form(mode)         → _castSpell({en='Bear Form',zh='熊形态'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.dire_bear_form(mode)    → _castSpell({en='Dire Bear Form',zh='巨熊形态'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.cat_form(mode)          → _castSpell({en='Cat Form',zh='猫形态'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.travel_form(mode)       → _castSpell({en='Travel Form',zh='旅行形态'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.aquatic_form(mode)      → _castSpell({en='Aquatic Form',zh='水栖形态'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
-- Self buffs
obj.prowl(mode)             → _castSpell({en='Prowl',zh='潜行'}, mode, nil, 0, true)
obj.dash(mode)              → _castSpell({en='Dash',zh='急奔'}, mode, nil, 0, true)
obj.tiger_fury(mode)        → _castSpell({en="Tiger's Fury",zh='猛虎之怒'}, mode, nil, macroTorch.computeTiger_E, true)
obj.barkskin(mode)          → _castSpell({en='Barkskin',zh='树皮术'}, mode, nil, 0, true) [ASSUMED: barkskin name might be "Barkskin (Feral)" — verify in-game]
obj.track_humanoids(mode)   → _castSpell({en='Track Humanoids',zh='追踪人型'}, mode, nil, 0, true)
obj.natures_swiftness(mode) → _castSpell({en="Nature's Swiftness",zh='自然迅捷'}, mode, nil, 0, true)
obj.tranquility(mode)       → _castSpell({en='Tranquility',zh='宁静'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.innervate(mode)         → _castSpell({en='Innervate',zh='激活'}, mode, nil, 0, true)
obj.rebirth(mode)           → _castSpell({en='Rebirth',zh='复生'}, mode, nil, nil, true) [ASSUMED: mana cost unknown]
obj.frenzied_regeneration(mode) → _castSpell({en='Frenzied Regeneration',zh='狂暴回复'}, mode, nil, 10, true) [ASSUMED: fixed rage cost]
obj.enrage(mode)            → _castSpell({en='Enrage',zh='激怒'}, mode, nil, 0, true)
obj.reshift(mode)           → _castSpell({en='Reshift',zh='变身'}, mode, nil, 0, true)  -- Turtle WoW unique
obj.hurricane(mode)         → _castSpell({en='Hurricane',zh='飓风'}, mode, nil, nil, true) [ASSUMED: mana cost unknown, listed in both Type A and B — resolved to B]
```

### Type C — Flexible Target (onSelf exposed)
```lua
obj.healing_touch(mode, onSelf)    → _castSpell({en='Healing Touch',zh='治疗之触'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.regrowth(mode, onSelf)         → _castSpell({en='Regrowth',zh='愈合'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.rejuvenation(mode, onSelf)     → _castSpell({en='Rejuvenation',zh='回春术'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.remove_curse(mode, onSelf)     → _castSpell({en='Remove Curse',zh='驱除诅咒'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.abolish_poison(mode, onSelf)   → _castSpell({en='Abolish Poison',zh='驱毒术'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.cure_poison(mode, onSelf)      → _castSpell({en='Cure Poison',zh='消毒术'}, mode, 40, nil, onSelf) [ASSUMED: mana cost unknown]
obj.mark_of_the_wild(mode, onSelf) → _castSpell({en='Mark of the Wild',zh='野性印记'}, mode, 30, nil, onSelf) [ASSUMED: mana cost unknown]
obj.gift_of_the_wild(mode, onSelf) → _castSpell({en='Gift of the Wild',zh='野性赐福'}, mode, 30, nil, onSelf) [ASSUMED: mana cost unknown]
obj.thorns(mode, onSelf)           → _castSpell({en='Thorns',zh='荆棘术'}, mode, 30, nil, onSelf) [ASSUMED: mana cost unknown]
```

### Additional skill methods NOT in the spec but needed for full replacement
```lua
obj.ravage(mode)              → _castSpell({en='Ravage',zh='毁灭'}, mode, nil, 50, false) [ASSUMED: melee range, energy cost unknown]
obj.berserk(mode)             → _castSpell({en='Berserk',zh='狂暴'}, mode, nil, 0, true) [ASSUMED: self-buff, no cost]
obj.natures_grasp(mode)       → _castSpell({en="Nature's Grasp",zh='自然之握'}, mode, nil, nil, true) [ASSUMED: self-buff, mana cost unknown]
```

**Note on [ASSUMED] costs:** Many mana-based and rage-based skill costs are not documented in the existing codebase or spec. Phase 5 passes `nil` for unknown costs (meaning no resource check in `_castSpell`), preserving existing behavior where these spells are cast without energy/rage/mana checks. Future phases can add precise cost values.

## Call-Site Replacement Table

For the planner's reference, here is the complete mapping of all 32 `player.cast()` calls to their replacements:

### cat.lua (11 calls)
| Line | Old Code | New Code |
|------|----------|----------|
| 18 | `player.cast('Berserk')` | `player.berserk()` [ASSUMED] |
| 164 | `macroTorch.player.cast('Ferocious Bite')` | `player.ferocious_bite('raw')` |
| 296 | `macroTorch.player.cast('Reshift')` | `player.reshift('ready')` |
| 306 | `macroTorch.player.cast('Shred')` | `player.shred('ready')` |
| 316 | `macroTorch.player.cast('Claw')` | `player.claw('ready')` |
| 328 | `macroTorch.player.cast('Rake')` | `player.rake('ready')` |
| 342 | `macroTorch.player.cast('Rip')` | `player.rip('ready')` |
| 353 | `macroTorch.player.cast('Ferocious Bite')` | `player.ferocious_bite('ready')` |
| 364 | `macroTorch.player.cast('Tiger\'s Fury')` | `player.tiger_fury('ready')` |
| 372 | `macroTorch.player.cast('Pounce')` | `player.pounce('ready')` |
| 380 | `macroTorch.player.cast('Cower')` | `player.cower('ready')` |

### bear.lua (6 calls)
| Line | Old Code | New Code |
|------|----------|----------|
| 7 | `macroTorch.player.cast('Maul')` | `player.maul('ready')` |
| 17 | `macroTorch.player.cast('Savage Bite')` | `player.ferocious_bite('ready')` [ASSUMED: 'Savage Bite' is bear form FB] |
| 24 | `macroTorch.player.cast('Growl')` | `player.growl('ready')` |
| 34 | `macroTorch.player.cast('Demoralizing Roar')` | `player.demoralizing_roar('ready')` |
| 44 | `macroTorch.player.cast('Swipe')` | `player.swipe('ready')` |
| 108 | `macroTorch.player.cast('Reshift')` | `player.reshift('ready')` |

### utility.lua (13 calls)
| Line | Old Code | New Code |
|------|----------|----------|
| 5 | `macroTorch.player.cast('Mark of the Wild', true)` | `player.mark_of_the_wild(nil, true)` |
| 8 | `macroTorch.player.cast('Thorns', true)` | `player.thorns(nil, true)` |
| 11 | `macroTorch.player.cast('Nature\'s Grasp', true)` | `player.natures_grasp(nil)` [ASSUMED: Type B, onSelf=true] |
| 20 | `macroTorch.player.cast('Dire Bear Form')` | `player.dire_bear_form()` |
| 24 | `macroTorch.player.cast('Reshift')` | `player.reshift()` |
| 27 | `macroTorch.player.cast('Bash')` | `player.bash()` |
| 30 | `macroTorch.player.cast('Feral Charge')` | `player.feral_charge()` |
| 38 | `macroTorch.player.cast('Barkskin (Feral)')` | `player.barkskin()` [ASSUMED: name might be 'Barkskin (Feral)' vs 'Barkskin'] |
| 43 | `macroTorch.player.cast('Dire Bear Form')` | `player.dire_bear_form()` |
| 46 | `macroTorch.player.cast('Enrage')` | `player.enrage()` |
| 48 | `macroTorch.player.cast('Frenzied Regeneration')` | `player.frenzied_regeneration()` |
| 55 | `macroTorch.player.cast('Hibernate')` | `player.hibernate()` |
| 57 | `macroTorch.player.cast('Entangling Roots')` | `player.entangling_roots()` |

### Druid.lua (2 calls)
| Line | Old Code | New Code |
|------|----------|----------|
| 191 | `player.cast('Ravage')` | `player.ravage()` [ASSUMED] |
| 997 | `macroTorch.player.cast('Faerie Fire (Feral)')` | `player.faerie_fire_feral('raw')` |

## Sources

### Primary (HIGH confidence)
- `docs/spell_refactor_plan_druid.txt` — Complete technical specification: architecture, `_castSpell` flow, skill signatures, Druid skill inventory (~40 skills with en/zh names, ranges, costs), implementation steps
- `05-CONTEXT.md` — User decisions (D-01 through D-08) from discuss phase
- `entity/Player.lua` — Current Player:new() implementation, `cast()` method, `isSpellReady()`, metatable chain target
- `classes/druid/Druid.lua` — Current Druid:new() implementation, clickContext pattern, energy calculation functions
- `classes/druid/cat.lua` — All safe/ready wrapper functions and 11 player.cast() call sites
- `classes/druid/bear.lua` — All bear safe/ready functions and 6 player.cast() call sites
- `classes/druid/utility.lua` — 13 player.cast() call sites for buffs/control/defense
- `.claude-reference/Functions.md` — Confirmed `GetLocale()` API returns locale string like 'enUS' [line 1162]
- `warcraft.wiki.gg/wiki/API_GetLocale` — Confirmed 11 possible locale values including 'enUS', 'zhCN', 'zhTW'

### Secondary (MEDIUM confidence)
- `entity/Unit.lua` — `distance` field function via UnitXP('distanceBetween'), target existence check
- `biz_util.lua` — `castSpellByName(spellName, bookType)` implementation using CastSpell(spellId, bookType)
- `.planning/codebase/ARCHITECTURE.md` — Metatable inheritance chain, clickContext pattern, module execution order
- `.planning/codebase/CONVENTIONS.md` — Coding conventions: global functions, naming patterns, code style
- `build_order.txt` — Confirmed no new files needed; Phase 5 modifies existing files only

### Tertiary (LOW confidence)
- Bear form skill rage cost values — marked [ASSUMED] as fixed placeholders pending future dynamic calculation functions
- Caster form mana costs — marked [ASSUMED] as nil (no resource check) since current code doesn't check mana either
- Barkskin exact spell name ('Barkskin' vs 'Barkskin (Feral)') — marked [ASSUMED] pending in-game verification

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure Lua refactoring, no external dependencies, all infrastructure already in place
- Architecture: HIGH — design fully specified in `spell_refactor_plan_druid.txt`, confirmed against existing codebase patterns
- Pitfalls: HIGH — identified from existing codebase analysis (Player.cast ignoring onSelf, commented cast in Druid.lua, clickContext dependency concerns verified as non-issues)
- Skill method list: MEDIUM-HIGH — ~40 methods from the spec confirmed, some resource costs and a few spell names marked [ASSUMED]

**Research date:** 2026-06-13
**Valid until:** 2026-08-13 (subject to codebase changes)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| D-01 | Full replacement of all player.cast() + safe/ready functions | 32 call sites mapped in Call-Site Replacement Table, 23 functions to delete identified |
| D-02 | Inline locale tables | Pattern 2 in Architecture Patterns section |
| D-03 | Core-first migration order | Migration order documented in Locked Decisions |
| D-04 | All skills in Druid:new() | Skill Method List section with ~40 methods |
| D-05 | _castSpell in Player base class | Pattern 1 in Architecture Patterns, complete implementation code provided |
| D-06 | Mode parameter nil/raw/safe | Pitfall 5, Pattern 1 implementation |
| D-07 | Three signature types | Pattern 2, Skill Method List with type annotations |
| D-08 | resourceCost number or function | Pattern 4, _castSpell implementation with `type()` check |
| R8 | Druid cat logic unchanged | Call-site replacements preserve exact behavior; mode parameter maps to existing safe/ready logic |