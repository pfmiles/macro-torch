# Phase 17: catLeveling FF prowling guard + global spellId dynamic correction - Pattern Map

**Mapped:** 2026-06-29
**Files classified:** 8 (1 new, 7 modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Action | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|--------|------|-----------|----------------|---------------|
| `core/spell_id_map.lua` | NEW | config/data | static-lookup | `texture_map.lua` | role-match |
| `core/spell_trace_core.lua` | EDIT | service | event-driven | self (existing code extended) | exact |
| `core/spell_trace_immune.lua` | EDIT | service | request-response | self (existing `loadImmuneTable`) | exact |
| `core/events.lua` | EDIT | controller | event-driven | self (existing UNIT_CASTEVENT branch) | exact |
| `core/combat_context.lua` | EDIT | service | request-response | self (existing `onPlayerEnteringWorld`) | exact |
| `entity/Player.lua` | EDIT | model | request-response | self (existing `_castSpell`) | exact |
| `classes/druid/Druid.lua` | EDIT | controller/config | request-response | self (existing `SpellTrace:register` calls) | exact |
| `classes/druid/leveling.lua` | EDIT | controller | request-response | self (existing Module 9 FF guard) | exact |

## Pattern Assignments

### 1. `core/spell_id_map.lua` (config/data, static-lookup) -- NEW FILE

**Analog:** `texture_map.lua` -- Pure data table, no logic functions, same role.

**Pattern to copy (lines 1-47, whole file):**
```lua
--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   ...
]] --

-- Static data table: no if-guard on namespace (texture_map.lua skips the `if not` guard)
-- texture_map.lua: macroTorch.SPELL_TEXTURE_MAP = { ... }
-- spell_id_map.lua should follow the same pattern: macroTorch.SPELL_NAME_TO_ID = { ... }
```

**File structure pattern from texture_map.lua:**
- License header (Apache 2.0, 15 lines)
- Direct table assignment (no `if not ... then` guard -- consistent with texture_map.lua)
- English + Chinese dual-key flat table
- UPPER_SNAKE_CASE for table name: `macroTorch.SPELL_NAME_TO_ID`

**Data content pattern (from Druid.lua lines 25-46, locale tables):**
```lua
-- English names from Druid.lua _castSpell {en='...'} entries
-- Chinese names from Druid.lua _castSpell {zh='...'} entries
-- Spell IDs from Druid.lua lines 614-627 (existing hardcoded registrations)
macroTorch.SPELL_NAME_TO_ID = {
    -- English names
    ["Pounce"] = 9827,       -- Druid.lua:46
    ["Rake"] = 1822,         -- Druid.lua:33
    ["Rip"] = 9492,          -- Druid.lua:37
    ["Ferocious Bite"] = 22557,  -- Druid.lua:41
    -- Chinese names (verified from Druid.lua _castSpell zh entries)
    ["突袭"] = 9827,         -- Druid.lua:46, zh = '突袭'
    ["斜掠"] = 1822,         -- Druid.lua:33, zh = '斜掠'
    ["撕扯"] = 9492,         -- Druid.lua:37, zh = '撕扯'
    ["凶猛撕咬"] = 22557,     -- Druid.lua:41, zh = '凶猛撕咬'
}
```

**build_order.txt placement:**
Must be inserted BEFORE `core/spell_trace_core.lua` so `SPELL_NAME_TO_ID` is available when `SpellTrace:register()` runs. Insert between line 20 (`core/combat_context.lua`) and line 21 (`core/spell_trace_core.lua`).

---

### 2. `core/spell_trace_core.lua` (EDIT) -- SpellTrace:register spellName support

**Analog:** Self (existing code, lines 41-63)

**Current code pattern (lines 41-63):**
```lua
-- SpellTrace 声明式 API 命名空间
macroTorch.SpellTrace = {}

function macroTorch.SpellTrace:register(name, config)
    if config.land then
        if not config.spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId", 'red')
            return
        end
        macroTorch.setSpellTracing(config.spellId, name)
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

**Modification pattern -- resolveSpellId() function (new, add before SpellTrace:register):**

Place this function between `macroTorch.SpellTrace = {}` (line 43) and `function macroTorch.SpellTrace:register` (line 51). Follow the same function style: no local, CamelCase function name, `macroTorch.*` namespace.

```lua
-- resolve spellId from runtime-corrected map or static baseline
-- returns nil if spell unknown (caller must handle)
function macroTorch.resolveSpellId(spellName)
    if macroTorch.loginContext and macroTorch.loginContext.spellIdMap then
        local correctedId = macroTorch.loginContext.spellIdMap[spellName]
        if correctedId then
            return correctedId
        end
    end
    return macroTorch.SPELL_NAME_TO_ID[spellName]
end
```

**Modification pattern -- SpellTrace:register land branch (lines 53-58):**

Replace the simple `if not config.spellId` guard with resolve logic:
```lua
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        local spellId = nil
        -- resolve via spellName first (new), then fallback to config.spellId (legacy)
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
    end
    -- immune branch unchanged
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

---

### 3. `core/spell_trace_immune.lua` (EDIT) -- loadSpellIdMap() function

**Analog:** Self -- `loadImmuneTable()` (lines 67-82) -- identical pattern, different table name and binding target.

**Pattern to copy (lines 67-82, with key modifications):**
```lua
-- Source pattern: loadImmuneTable() at lines 67-82
function macroTorch.loadImmuneTable()
    if not macroTorch.context then return end                    -- guard
    if not SM_EXTEND then SM_EXTEND = {} end                     -- init SM_EXTEND
    if not SM_EXTEND.immuneTable then SM_EXTEND.immuneTable = {} end  -- init sub-table
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.immuneTable[playerCls] then
        SM_EXTEND.immuneTable[playerCls] = {}
    end
    if not macroTorch.context.immuneTable then                   -- bind reference
        macroTorch.context.immuneTable = SM_EXTEND.immuneTable[playerCls]
    end
end
```

**New function (add after loadDefiniteBleedingTable, line 102):**
```lua
-- load the spellIdMap from SM_EXTEND.spellIdMap persistent var
function macroTorch.loadSpellIdMap()
    if not macroTorch.loginContext then return end               -- NOTE: loginContext, NOT context
    if not SM_EXTEND then SM_EXTEND = {} end
    if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.spellIdMap[playerCls] then
        SM_EXTEND.spellIdMap[playerCls] = {}
    end
    if not macroTorch.loginContext.spellIdMap then               -- bind to loginContext
        macroTorch.loginContext.spellIdMap = SM_EXTEND.spellIdMap[playerCls]
    end
end
```

**Critical difference from loadImmuneTable:**
- `immuneTable` binds to `macroTorch.context` (combat-scoped, reset on combat exit at `combat_context.lua:24`)
- `spellIdMap` binds to `macroTorch.loginContext` (session-scoped, reset only on PLAYER_ENTERING_WORLD at `combat_context.lua:39`)
- This is correct because spellId corrections must survive combat exit/re-entry.

---

### 4. `core/events.lua` (EDIT) -- UNIT_CASTEVENT spellId correction

**Analog:** Self -- existing UNIT_CASTEVENT branch (lines 87-97) + `eventHandle` structure (lines 47-118)

**Existing pattern (lines 87-97):**
```lua
elseif event == "UNIT_CASTEVENT" then
    local unitId, targetId, castType, spellId, timeCost = arg1, arg2, arg3, arg4, arg5
    if unitId == macroTorch.player.guid and castType ~= 'MAINHAND' and castType ~= 'OFFHAND' then
        macroTorch.show('unitId=' .. tostring(unitId) .. ', targetId=' .. tostring(targetId) .. ', type=' .. tostring(castType) .. ', spellId=' .. tostring(spellId) .. ', timeCost=' .. tostring(timeCost))
    end
    if unitId == macroTorch.player.guid and castType == 'CAST' then
        if spellId and macroTorch.tracingSpells[spellId] then
            macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
        end
    end
```

**Modification pattern -- add spellId correction block after the existing `recordCastTable` call:**

```lua
elseif event == "UNIT_CASTEVENT" then
    local unitId, targetId, castType, spellId, timeCost = arg1, arg2, arg3, arg4, arg5
    if unitId == macroTorch.player.guid and castType ~= 'MAINHAND' and castType ~= 'OFFHAND' then
        macroTorch.show('unitId=' .. tostring(unitId) .. ', targetId=' .. tostring(targetId) .. ', type=' .. tostring(castType) .. ', spellId=' .. tostring(spellId) .. ', timeCost=' .. tostring(timeCost))
    end
    if unitId == macroTorch.player.guid and castType == 'CAST' then
        -- 1. Existing spell trace matching (unchanged)
        if spellId and macroTorch.tracingSpells[spellId] then
            macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
        end
        
        -- 2. NEW: Spell ID correction when current_casting_spell is set
        if macroTorch.current_casting_spell then
            local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
            if staticSpellId and staticSpellId ~= spellId then
                -- persist correction (same lazy-init pattern as loadImmuneTable)
                local playerCls = macroTorch.player.class
                if not SM_EXTEND then SM_EXTEND = {} end
                if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
                if not SM_EXTEND.spellIdMap[playerCls] then SM_EXTEND.spellIdMap[playerCls] = {} end
                SM_EXTEND.spellIdMap[playerCls][macroTorch.current_casting_spell] = spellId
                -- sync loginContext (may be nil if not yet loaded; same table ref if loaded)
                if macroTorch.loginContext and not macroTorch.loginContext.spellIdMap then
                    macroTorch.loginContext.spellIdMap = SM_EXTEND.spellIdMap[playerCls]
                end
                -- update tracingSpells key mapping
                if macroTorch.tracingSpells[staticSpellId] then
                    macroTorch.tracingSpells[spellId] = macroTorch.tracingSpells[staticSpellId]
                    macroTorch.tracingSpells[staticSpellId] = nil
                end
                macroTorch.show(string.format(
                    "[macro-torch] spellId corrected: %s %d -> %d",
                    macroTorch.current_casting_spell, staticSpellId, spellId
                ), 'yellow')
            end
            -- clear after processing (D-07)
            macroTorch.current_casting_spell = nil
        end
    end
```

**Error handling pattern:** Uses `macroTorch.show(..., 'yellow')` for informational messages (same as existing pattern at line 91). No try/catch needed -- Lua errors in event handlers are caught by WoW's event frame. The lazy-init `if not SM_EXTEND then` guards follow the `loadImmuneTable()` pattern at `spell_trace_immune.lua:70`.

---

### 5. `core/combat_context.lua` (EDIT) -- add loadSpellIdMap() call

**Analog:** Self -- `onPlayerEnteringWorld()` (lines 37-39) + events.lua line 51 (PLAYER_ENTERING_WORLD handler)

**Current pattern (lines 37-39):**
```lua
function macroTorch.onPlayerEnteringWorld()
    macroTorch.player = macroTorch.initPlayer()
    macroTorch.loginContext = {}
end
```

**Modification pattern -- add loadSpellIdMap call after loginContext init:**
```lua
function macroTorch.onPlayerEnteringWorld()
    macroTorch.player = macroTorch.initPlayer()
    macroTorch.loginContext = {}
    macroTorch.loadSpellIdMap()     -- NEW: load persisted spellId corrections
end
```

The call order matters: `loginContext` must be set to `{}` first (existing line 39), then `loadSpellIdMap()` binds `SM_EXTEND.spellIdMap[playerCls]` reference to it.

---

### 6. `entity/Player.lua` (EDIT) -- _castSpell sets current_casting_spell

**Analog:** Self -- `_castSpell` (lines 42-87) -- minimal surgical edit

**Current pattern (lines 42-87, key section lines 52-86):**
```lua
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf, rank)
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
        if not obj.isSpellReady(spellName) then
            return false
        end
    end

    -- 3. Distance + resource checks (skip for 'ready' and 'raw', default nil = safe)
    if mode ~= 'ready' and mode ~= 'raw' then
        if range and not onSelf and not obj._isInRange(range) then
            return false
        end
        if resourceCost then
            local cost
            if type(resourceCost) == 'function' then
                cost = resourceCost()
            else
                cost = resourceCost
            end
            if not obj._hasResource(cost) then
                return false
            end
        end
    end

    -- 4. Execute the cast
    if onSelf then
        CastSpellByName(spellName, true)
    else
        obj.cast(spellName, rank)
    end
    return true
end
```

**Modification pattern -- insert `current_casting_spell` set immediately before the cast execution (line 77 area):**

Insert after the resource check block (after line 75, before the `-- 4. Execute the cast` comment at line 77):
```lua
    -- 4. Execute the cast
    -- NEW: set current_casting_spell only when actually casting (mode ~= 'ready')
    if mode ~= 'ready' then
        macroTorch.current_casting_spell = spellName
    end
    if onSelf then
        CastSpellByName(spellName, true)
    else
        obj.cast(spellName, rank)
    end
    return true
```

**Key design decisions:**
- `spellName` resolves to the locale-specific name (English or Chinese), which matches the key used in `SPELL_NAME_TO_ID`
- `mode ~= 'ready'` guard: `mode='ready'` only checks readiness without casting, so it should NOT set `current_casting_spell`
- `mode='raw'` (cast directly without checks): DOES set `current_casting_spell` because a cast actually happens
- Default `mode=nil` (safe mode): DOES set `current_casting_spell` because a cast actually happens

---

### 7. `classes/druid/Druid.lua` (EDIT) -- SpellTrace:register call signatures

**Analog:** Self -- existing registrations (lines 611-633)

**Current pattern (lines 614-633):**
```lua
macroTorch.SpellTrace:register('Pounce', {
    spellId = 9827, land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellId = 1822, land = true,
    immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellId = 9492, land = true,
    immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellId = 22557, land = true,
    immune = false
})
macroTorch.SpellTrace:register('Faerie Fire (Feral)', {
    land = false,
    immune = true, debuffTexture = 'Spell_Nature_FaerieFire'
})
```

**Modification pattern -- replace `spellId` with `spellName` for land-traced spells:**
```lua
-- spellId replaced by spellName for dynamic name-based resolution
macroTorch.SpellTrace:register('Pounce', {
    spellName = 'Pounce',    -- NEW: replaces spellId=9827
    land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellName = 'Rake',      -- NEW: replaces spellId=1822
    land = true,
    immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellName = 'Rip',       -- NEW: replaces spellId=9492
    land = true,
    immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellName = 'Ferocious Bite',  -- NEW: replaces spellId=22557
    land = true,
    immune = false
})
-- Faerie Fire (Feral): UNCHANGED -- land=false, no spellId/spellName needed
macroTorch.SpellTrace:register('Faerie Fire (Feral)', {
    land = false,
    immune = true, debuffTexture = 'Spell_Nature_FaerieFire'
})
```

**TODO removal:** The comment on line 611 (`-- TODO 这里的spellId并不稳定...`) can be removed since the spellId instability is now addressed by the dynamic correction system.

---

### 8. `classes/druid/leveling.lua` (EDIT) -- FF prowling guard

**Analog:** Self -- existing Module 9 FF block (lines 212-224)

**Current pattern (lines 212-224):**
```lua
-- ============================================================
-- 模块9: 精灵之火(野性) -- 见缝插针填充技 (Faerie Fire Feral)
-- 非 OOM + 非免疫 => 作为兜底填充，不论目标是否已有 debuff
-- FF 无能量消耗且可能触发 OOC，在所有高优先级模块无动作时插入
-- ============================================================
if macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell')
        and not clickContext.ooc
        and not target.isImmune('Faerie Fire (Feral)')
        and player.isSpellReady('Faerie Fire (Feral)')
        and macroTorch.isGcdOk(clickContext) then
    player.faerie_fire_feral('raw')
    return
end
```

**Modification pattern -- add `not player.isProwling` guard:**

Insert after the `not clickContext.ooc` line, following the existing indentation and comment style:
```lua
-- ============================================================
-- 模块9: 精灵之火(野性) -- 见缝插针填充技 (Faerie Fire Feral)
-- 非 OOM + 非免疫 => 作为兜底填充，不论目标是否已有 debuff
-- FF 无能量消耗且可能触发 OOC，在所有高优先级模块无动作时插入
-- NOTE: FF cannot be cast while prowling (stealthed) -- WoW game mechanic constraint
-- ============================================================
if macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell')
        and not clickContext.ooc
        and not player.isProwling                           -- NEW: cannot cast FF while prowling
        and not target.isImmune('Faerie Fire (Feral)')
        and player.isSpellReady('Faerie Fire (Feral)')
        and macroTorch.isGcdOk(clickContext) then
    player.faerie_fire_feral('raw')
    return
end
```

**Pattern note:** Module 9 is the last module in catLeveling, so a `return` at its end is safe -- no subsequent modules are skipped. The guard simply prevents the FF module from executing when prowling, and execution falls through to the end of the function (no remaining modules to execute).

---

## Shared Patterns

### Copyright/License Header
**Source:** All existing `.lua` files (e.g., `core/spell_trace_core.lua` lines 1-11, `texture_map.lua` lines 1-15)
**Apply to:** `core/spell_id_map.lua` (new file)

```lua
--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]] --
```

### Global Variable Initialization Pattern
**Source:** `macro_torch.lua` lines 17-20, `texture_map.lua` line 17
**Apply to:** `core/spell_id_map.lua`

Two patterns exist in the codebase:
1. `macro_torch.lua` (root initialization): uses `if not macroTorch then ... end` guard
2. `texture_map.lua` (data file): **no guard** -- direct assignment

For `spell_id_map.lua`, prefer the **texture_map.lua pattern** (no guard) since `macroTorch` is already guaranteed to exist at that point in build_order.txt. If a guard is used, follow the `macro_torch.lua` pattern:
```lua
if not macroTorch.SPELL_NAME_TO_ID then
    macroTorch.SPELL_NAME_TO_ID = { ... }
end
```

### SM_EXTEND Lazy-Init Guard Pattern
**Source:** `core/spell_trace_immune.lua` lines 70-75, 89-94
**Apply to:** `core/events.lua` (UNIT_CASTEVENT spellId correction block), `core/spell_trace_immune.lua` (loadSpellIdMap)

```lua
if not SM_EXTEND then SM_EXTEND = {} end
if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
local playerCls = macroTorch.player.class
if not SM_EXTEND.spellIdMap[playerCls] then
    SM_EXTEND.spellIdMap[playerCls] = {}
end
```

### Error/Info Reporting Pattern
**Source:** `core/spell_trace_core.lua` line 55, `core/events.lua` line 91
**Apply to:** All spellId correction logic
```lua
macroTorch.show("[macro-torch] message text here", 'yellow')  -- warning/info
macroTorch.show("[macro-torch] message text here", 'red')     -- error
```

### Self-Test Registration Pattern
**Source:** `classes/druid/Druid.lua` lines 1164-1191
**Apply to:** New self-tests for spellId mapping
```lua
macroTorch.SelfTest:register("Druid: SPELL_NAME_TO_ID table has expected keys", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(macroTorch.SPELL_NAME_TO_ID["Pounce"] == 9827, "Pounce spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Rake"] == 1822, "Rake spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Rip"] == 9492, "Rip spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Ferocious Bite"] == 22557, "Ferocious Bite spellId mismatch")
end, true)
```

### build_order.txt Insertion Pattern
**Source:** `build_order.txt` line 21 (`core/spell_trace_core.lua`)
**Apply to:** Insert `core/spell_id_map.lua` BEFORE line 21

The new file must appear after `core/combat_context.lua` (line 20) and before `core/spell_trace_core.lua` (line 21) so that `SPELL_NAME_TO_ID` is available when `SpellTrace:register()` runs during addon bootstrap.

### WoW 1.12.1 Lua Constraints
**Source:** `CLAUDE.md` -- "no `#` operator, use `macroTorch.tableLen(tbl)`"
**Apply to:** All new code. No integer `#` table length operations. Use `macroTorch.tableLen(tbl)` or `table.insert(tbl, val)`.

---

## Reusable Assets (Already Exist -- Do NOT Recreate)

| Asset | Location | Usage in Phase 17 |
|-------|----------|-------------------|
| `macroTorch.player.isProwling` | `classes/druid/Druid.lua:316-318` (DRUID_FIELD_FUNC_MAP) | FF prowling guard condition |
| `macroTorch.show(msg, color)` | global (all .lua files use it) | Error/info reporting for spellId correction |
| `macroTorch.SpellTrace:register()` | `core/spell_trace_core.lua:51` | Extended to support `config.spellName` |
| `SM_EXTEND` SavedVariable | WoW built-in | Persistence for spellIdMap |
| `macroTorch.loginContext` | `core/combat_context.lua:39` | Binding target for spellIdMap reference |
| `macroTorch.tracingSpells` | `core/spell_trace_core.lua:15-21` | Key migration target on spellId correction |
| `macroTorch.setSpellTracing()` | `core/spell_trace_core.lua:18` | Called unchanged by SpellTrace:register |

## No Analog Found

None. All 8 files have exact or role-match analogs in the existing codebase.

## Metadata

**Analog search scope:** `core/`, `entity/`, `classes/druid/`, root
**Files scanned:** 12 (macro_torch.lua, texture_map.lua, build_order.txt, 9 source files)
**Pattern extraction date:** 2026-06-29
**Target platform:** WoW 1.12.1 (Turtle WoW) embedded Lua 5.0
**Dependencies:** SuperWoW API (UNIT_CASTEVENT)