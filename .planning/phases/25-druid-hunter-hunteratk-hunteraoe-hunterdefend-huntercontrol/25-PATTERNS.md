# Phase 25: Hunter One-Button Macro Refactor - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 5 (3 modified, 2 created, 2 deleted)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Action | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|--------|------|-----------|----------------|---------------|
| `classes/hunter/Hunter.lua` | MODIFY (rewrite) | model | CRUD (cast spells) | `classes/druid/Druid.lua` | exact |
| `classes/hunter/combo.lua` | CREATE | service | event-driven (keypress) | `classes/druid/combo.lua` | exact |
| `build_order.txt` | MODIFY | config | N/A | `build_order.txt` (self) | exact |
| `classes/hunter/combat.lua` | DELETE | N/A | N/A | N/A (remove from build) | N/A |
| `classes/hunter/utility.lua` | DELETE | N/A | N/A | N/A (remove from build) | N/A |

## Pattern Assignments

---

### 1. `classes/hunter/Hunter.lua` (model, CRUD cast-spell)

**Analog:** `classes/druid/Druid.lua` + existing `classes/hunter/Hunter.lua`

#### 1.1 File Header / Copyright

The copyright/license header is identical across all files. Copy from existing `classes/hunter/Hunter.lua` lines 1-15 or `classes/druid/Druid.lua` lines 1-15.

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
---猎人专用 start---
```

#### 1.2 Class Construction Skeleton

Copy from existing `classes/hunter/Hunter.lua` lines 17-72. The class definition + metatable + singleton + registerPlayerClass framework is already correct. Keep it exactly as-is for the skeleton.

```lua
macroTorch.Hunter = macroTorch.Player:new()

function macroTorch.Hunter:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.raptor_strike(mode, rank)
        return obj._castSpell({ en = 'Raptor Strike', zh = '猛禽一击' }, mode, nil, nil, false, rank)
    end

    -- ... more skill methods ...

    return obj
end
```

**Key rules:**
- Every skill method goes inside `function macroTorch.Hunter:new()` before the `return obj`
- Method signature: `function obj.skill_name(mode, rank)`
- Calls `obj._castSpell(localeNames, mode, range, resourceCost, onSelf, rank)`

#### 1.3 Type A Skill Method (Enemy Target)

**Pattern source:** `classes/druid/Druid.lua` lines 25-27; existing `classes/hunter/Hunter.lua` lines 25-28

```lua
function obj.claw(mode, rank)
    return obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
end
```

**Hunter adaptation -- no resource cost (mana not modeled), add `range` for distance checks:**

```lua
-- Ranged shot (30yd range, no resource cost tracking for mana):
function obj.arcane_shot(mode, rank)
    return obj._castSpell({ en = 'Arcane Shot', zh = '奥术射击' }, mode, 30, nil, false, rank)
end

-- Melee skill (nil range = no range check, handled by isInRange logic):
function obj.raptor_strike(mode, rank)
    return obj._castSpell({ en = 'Raptor Strike', zh = '猛禽一击' }, mode, nil, nil, false, rank)
end
```

**`_castSpell` parameter mapping** (verified from `entity/Player.lua` lines 34-88):
| Param | Typical Hunter Value | Notes |
|-------|---------------------|-------|
| `localeNames` | `{en = '...', zh = '...'}` | Dual locale required |
| `mode` | `nil` (safe), `'ready'`, or `'raw'` | nil = full readiness+range check |
| `range` | `30` for shots, `nil` for melee, `nil` for traps/self | Hunter max range is 30yd (not 40) |
| `resourceCost` | `nil` | Mana not numerically modeled like energy/rage |
| `onSelf` | `false` for Type A, `true` for Type B | Type A = enemy target; Type B = self |
| `rank` | `nil` (max) or `1` (for arcane_shot R1 in mobTagging) | `nil` = highest learned rank |

#### 1.4 Type B Skill Method (Self Target / Traps)

**Pattern source:** `classes/druid/Druid.lua` lines 128-129; existing `classes/hunter/Hunter.lua` lines 58-59

```lua
-- Druid self-buff:
function obj.bear_form(mode, rank)
    return obj._castSpell({ en = 'Bear Form', zh = '熊形态' }, mode, nil, nil, true, rank)
end

-- Hunter self-buff / defense:
function obj.deterrence(mode, rank)
    return obj._castSpell({ en = 'Deterrence', zh = '威慑' }, mode, nil, nil, true, rank)
end

-- Hunter trap (self-placed at feet, onSelf=true, range=nil):
function obj.immolation_trap(mode, rank)
    return obj._castSpell({ en = 'Immolation Trap', zh = '献祭陷阱' }, mode, nil, nil, true, rank)
end
```

#### 1.5 FIELD_FUNC_MAP

**Pattern source:** existing `classes/hunter/Hunter.lua` lines 74-78

```lua
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditional props (reserved for future class-specific lazy-computed fields)
}
```

**Keep as-is.** No Hunter-specific computed properties are needed beyond what `entity/Player.lua` already provides (distance, health, isInCombat, targetEnemy, startAutoAtk, startAutoShoot, isAutoShooting, etc.).

#### 1.6 Singleton + registerPlayerClass

**Pattern source:** existing `classes/hunter/Hunter.lua` lines 80-81

```lua
macroTorch.hunter = macroTorch.Hunter:new()
macroTorch.registerPlayerClass("Hunter", macroTorch.Hunter)
```

**Keep exactly as-is.** Druid equivalent is in `classes/druid/Druid.lua` (same pattern, using `macroTorch.Druid:new()`).

#### 1.7 SpellTrace Registration

**Pattern source:** `classes/druid/Druid.lua` lines 680-700; existing `classes/hunter/Hunter.lua` lines 83-86 (to be modified)

**Druid canonical pattern:**
```lua
-- spell trace + immune registration via SpellTrace:register() API (name-based, no spellId needed)
macroTorch.SpellTrace:register('Pounce', {
    spellName = 'Pounce', land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellName = 'Rake', land = true,
    immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
```

**Hunter adaptation (modify existing + add new):**
```lua
-- tracing spell trace/immune via declarative SpellTrace:register() API
macroTorch.SpellTrace:register('Serpent Sting', {
    spellName = 'Serpent Sting', land = true,
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})
macroTorch.SpellTrace:register('Scorpid Sting', {
    spellName = 'Scorpid Sting', land = true,
    immune = true, debuffTexture = 'INV_Misc_QuestionMark'  -- TODO: verify exact texture
})
```

**Key differences from existing code:**
- Existing `Serpent Sting` registration (line 84-86) is MISSING `spellName` and `land` fields -- MUST add both
- `Scorpid Sting` registration is entirely NEW
- Do NOT register Hunter's Mark (per D-12)

#### 1.8 SelfTest Registration

**Pattern source:** existing `classes/hunter/Hunter.lua` lines 88-156 (13 tests -- expand to ~33); `classes/druid/combo.lua` lines 414-457 (for naming convention)

**Canonical SelfTest pattern:**
```lua
macroTorch.SelfTest:register("Hunter: description", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.skill_name) == "function", "skill_name is not a function")
end, true)
```

**Template for infrastructure tests (3 tests -- KEEP existing):**
```lua
-- Infrastructure tests
macroTorch.SelfTest:register("Hunter: HUNTER_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.HUNTER_FIELD_FUNC_MAP) == "table", "HUNTER_FIELD_FUNC_MAP is not a table")
end, true)

macroTorch.SelfTest:register("Hunter: singleton hunter exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter) == "table", "macroTorch.hunter is not a table")
end, true)

macroTorch.SelfTest:register("Hunter: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Hunter"] ~= nil, "Hunter not in PLAYER_CLASS_REGISTRY")
end, true)
```

**Template for skill method existence tests (KEEP existing 10 + ADD ~15 new):**
```lua
macroTorch.SelfTest:register("Hunter: skill method raptor_strike exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.raptor_strike) == "function", "raptor_strike is not a function")
end, true)
```

**All SelfTest registrations MUST:**
1. Start test name with `"Hunter: "` prefix
2. Guard with `if UnitClass('player') ~= 'Hunter' then return end`
3. Pass `true` as third argument (isOptional)
4. Each skill method gets exactly one test

---

### 2. `classes/hunter/combo.lua` (service, event-driven)

**Analog:** `classes/druid/combo.lua` (lines 1-457)

#### 2.1 File Header

**Pattern source:** `classes/druid/combo.lua` line 1

```lua
-- Hunter one-button combo macro methods (routing layer)
```

#### 2.2 Entry Routing -- `hunterAtk()`

**Pattern source:** `classes/druid/combo.lua` lines 183-195 (druidAtk -- form-based routing)

```lua
function macroTorch.druidAtk()
    if macroTorch.player.isInCatForm then
        if macroTorch.player.level >= 60 then
            macroTorch.catAtk()
        else
            macroTorch.catLeveling()
        end
    elseif macroTorch.player.isInBearForm then
        macroTorch.bearAtk()
    else
        macroTorch.casterAtk()
    end
end
```

**Hunter adaptation (distance-based routing, per D-01/D-03):**
```lua
function macroTorch.hunterAtk()
    if macroTorch.target.distance < 8 then
        return macroTorch.hunterAtkMelee()
    else
        return macroTorch.hunterAtkRanged()
    end
end
```

#### 2.3 Module Priority Chain -- `hunterAtkRanged()` / `hunterAtkMelee()`

**Pattern source:** `classes/druid/combo.lua` lines 49-181 (catAtk -- 12-module chain)

**Core pattern structure (catAtk):**
```lua
function macroTorch.catAtk()
    if not macroTorch.player.isInCatForm then
        return
    end

    -- clickContext is a per-keystroke cache
    local clickContext = {}

    -- cache setup: energy costs, durations, thresholds
    clickContext.CLAW_E = macroTorch.computeClaw_E()
    clickContext.PLAYER_URGENT_HP_THRESHOLD = 15

    local player = macroTorch.player
    local target = macroTorch.target
    clickContext.prowling = player.isProwling
    clickContext.isBehind = target.isCanAttack and player.isBehindTarget
    clickContext.isTargetDummy = macroTorch.toBoolean(
            macroTorch.target.isCanAttack and
            string.find(macroTorch.target.name, 'Training Dummy'))

    -- 0. recoverNormalRelic
    -- 1. combatUrgentHPRestore
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
    end
    -- 2. targetEnemy
    if not target.isCanAttack then
        player.targetEnemy()
    else
        -- 3. keep autoAttack
        if macroTorch.isFightStarted(clickContext) then
            player.startAutoAtk()
        end
        -- 4. burstMod (Shift+key trigger)
        macroTorch.burstMod(clickContext)
        -- 5. openerMod
        -- ... more modules ...
        -- 12. reshiftMod
    end
end
```

**Hunter adaptation -- clickContext fields (no energy tracking, add distance/threat):**
```lua
function macroTorch.hunterAtkRanged()
    local clickContext = {}
    -- no energy/rage costs (Hunter uses mana, not numerically modeled)
    clickContext.PLAYER_URGENT_HP_THRESHOLD = 15

    local player = macroTorch.player
    local target = macroTorch.target
    clickContext.isInCombat = player.isInCombat
    clickContext.isTargetDummy = macroTorch.toBoolean(
            target.isCanAttack and
            string.find(target.name, 'Training Dummy'))

    -- 1. combatUrgentHPRestore
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
    end
    -- 2. targetEnemy
    if not target.isCanAttack then
        player.targetEnemy()
        if not target.isCanAttack then return end
    end
    -- 3. startAutoShoot (every keystroke, per D-04)
    player.startAutoShoot()
    -- 4. burstMod (Shift trigger: trinkets + Aimed Shot per D-05)
    -- 5. openerMod (Hunter's Mark if not marked)
    -- 6. stingMod (Serpent Sting -> Scorpid Sting)
    -- 7. coreDPSMod (Arcane Shot -> Multi-Shot)
    -- 8. otMod (Disengage if threat too high)
    -- ... fillers ...
end
```

**Key differences from catAtk:**
- NO energy/mana cost tracking (mana not modeled)
- NO form check (Hunter has no shapeshift forms)
- `startAutoShoot()` instead of `startAutoAtk()` (ranged auto-shooting)
- `target.distance < 8` routing instead of form-based routing
- NO pet management (per D-08)
- NO Aspect management (per D-07)
- NO trap logic (per D-06, traps are in hunterAoe/hunterControl)

#### 2.4 isFightStarted Caching Pattern

**Pattern source:** `classes/druid/Druid.lua` lines 817-827

```lua
function macroTorch.isFightStarted(clickContext)
    if clickContext.isFightStarted == nil then
        clickContext.isFightStarted = (not clickContext.prowling and
                (macroTorch.player.isInCombat
                        or macroTorch.target.isPlayerControlled
                        or (macroTorch.target.isHostile and macroTorch.target.isInCombat)
                ))
                or (clickContext.prowling and macroTorch.target.isAttackingMe)
    end
    return clickContext.isFightStarted
end
```

**Hunter does NOT need to redefine this function.** Since Hunter has no `prowling` state, `clickContext.prowling` will always be nil/false, taking the first branch -- which is correct for Hunter. Just reuse `macroTorch.isFightStarted(clickContext)` as-is.

#### 2.5 Simple AoE Macro -- `hunterAoe()`

**Pattern source:** `classes/druid/combo.lua` lines 197-206 (druidAoe -- ~10 lines)

```lua
function macroTorch.druidAoe()
    if macroTorch.player.isInBearForm then
        macroTorch.bearAoe()
    elseif macroTorch.player.isInCatForm then
        return -- No cat form AoE in vanilla WoW
    elseif macroTorch.isSpellExist('Hurricane', 'spell')
            and macroTorch.player.humanFormMana >= 880 then
        macroTorch.player.hurricane('ready')
    end
end
```

**Hunter adaptation (distance routing, per D-13):**
```lua
function macroTorch.hunterAoe()
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not macroTorch.target.isCanAttack then return end
    end

    if macroTorch.target.distance < 8 then
        -- Melee AoE: traps (Explosive -> Immolation)
        if macroTorch.isSpellExist('Explosive Trap', 'spell')
                and macroTorch.player.isSpellReady('Explosive Trap') then
            macroTorch.player.explosive_trap('ready')
        elseif macroTorch.isSpellExist('Immolation Trap', 'spell')
                and macroTorch.player.isSpellReady('Immolation Trap') then
            macroTorch.player.immolation_trap('ready')
        end
    else
        -- Ranged AoE: Multi-Shot -> Volley
        macroTorch.player.startAutoShoot()
        if macroTorch.isSpellExist('Multi-Shot', 'spell') then
            macroTorch.player.multi_shot('ready')
        end
        if macroTorch.isSpellExist('Volley', 'spell')
                and macroTorch.player.isSpellReady('Volley') then
            macroTorch.player.volley('ready')
        end
    end
end
```

#### 2.6 Simple Defend Macro -- `hunterDefend()`

**Pattern source:** `classes/druid/combo.lua` lines 260-277 (druidDefend -- multi-check, but Hunter adapts to single-check)

**Druid multi-step defend:**
```lua
function macroTorch.druidDefend()
    if macroTorch.isSpellExist('Barkskin', 'spell')
            and macroTorch.player.isSpellReady('Barkskin (Feral)') then
        macroTorch.player.barkskin('ready')
        return
    end
    if not macroTorch.player.isInBearForm then
        macroTorch.player.dire_bear_form('ready')
        return
    end
    if macroTorch.isSpellExist('Frenzied Regeneration', 'spell')
            and macroTorch.player.isInBearForm
            and macroTorch.player.isSpellReady('Frenzied Regeneration') then
        macroTorch.player.frenzied_regeneration('ready')
    end
end
```

**Hunter adaptation (single-check, per D-14):**
```lua
function macroTorch.hunterDefend()
    if macroTorch.isSpellExist('Deterrence', 'spell')
            and macroTorch.player.isSpellReady('Deterrence') then
        macroTorch.player.deterrence('ready')
    end
end
```

**Key: uses `isSpellExist` guard + `isSpellReady` check, following the exact same pattern as Druid's Barkskin check.**

#### 2.7 Control Macro -- `hunterControl()`

**Pattern source:** `classes/druid/combo.lua` lines 279-309 (druidControl -- ~30 lines, distance-aware)

```lua
function macroTorch.druidControl()
    local target = macroTorch.target
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end
    -- form cancellation...
    if target.isBeastOrDragonkin()
            and macroTorch.isSpellExist('Hibernate', 'spell') then
        macroTorch.player.hibernate()
    elseif macroTorch.isSpellExist('Entangling Roots', 'spell') then
        macroTorch.player.entangling_roots()
    end
end
```

**Hunter adaptation (distance routing, per D-15):**
```lua
function macroTorch.hunterControl()
    local target = macroTorch.target
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then return end
    end

    if target.distance < 8 then
        -- Melee control: Wing Clip (slow+damage) or Freezing Trap (freeze)
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            macroTorch.player.wing_clip('ready')
        end
        if macroTorch.isSpellExist('Freezing Trap', 'spell')
                and macroTorch.player.isSpellReady('Freezing Trap') then
            macroTorch.player.freezing_trap('ready')
        end
    else
        -- Ranged control: Concussive Shot (slow) or Scatter Shot (confuse)
        if macroTorch.isSpellExist('Concussive Shot', 'spell') then
            macroTorch.player.concussive_shot('ready')
        end
        if macroTorch.isSpellExist('Scatter Shot', 'spell') then
            macroTorch.player.scatter_shot('ready')
        end
    end
end
```

#### 2.8 MobTagging -- `hunterMobTagging()`

**Pattern source:** `classes/druid/combo.lua` lines 343-412 (druidMobTagging -- ~70 lines, PvP filter + tag + auto-chain)

**Key pattern elements (druidMobTagging):**
```lua
function macroTorch.druidMobTagging()
    local player = macroTorch.player
    local target = macroTorch.target

    -- Caster form branch: Moonfire R1 tag
    if not player.isInCatForm and not player.isInBearForm then
        if not target.isCanAttack or target.distance > 30 or target.isPlayerControlled then
            player.targetEnemy()
            -- PvP filter: if selected player, clear and wait
            if target.isCanAttack and target.isPlayerControlled then
                ClearTarget()
            end
            return
        end
        player.moonfire('ready', 1)  -- rank 1, lowest mana
        -- Auto-chain: if mob is attacking me, switch to full rotation
        if target.isAttackingMe then
            macroTorch.druidAtk()
        end
        return
    end
    -- ... melee/feral branches ...
end
```

**Hunter adaptation (per D-16, D-17, D-18, D-19):**
```lua
function macroTorch.hunterMobTagging()
    local player = macroTorch.player
    local target = macroTorch.target

    -- PvP filter (per D-18): skip player targets
    if not target.isCanAttack or target.isPlayerControlled then
        player.targetEnemy()
        if target.isCanAttack and target.isPlayerControlled then
            ClearTarget()
        end
        return
    end

    if target.distance < 8 then
        -- Melee tag: Wing Clip (instant melee damage + slow, per D-17)
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            player.wing_clip('ready')
        end
        player.startAutoAtk()
    else
        -- Ranged tag: Arcane Shot rank 1 (instant, 30yd, lowest mana, per D-16)
        player.startAutoShoot()
        if macroTorch.isSpellExist('Arcane Shot', 'spell') then
            player.arcane_shot('ready', 1)  -- rank 1, lowest mana
        end
    end

    -- Auto-chain to hunterAtk if tag confirmed (per D-19)
    if target.isAttackingMe then
        macroTorch.hunterAtk()
    end
end
```

**Key difference from druidMobTagging:** No form-based branching. Distance routing replaces form routing.

#### 2.9 Combo Function SelfTest

**Pattern source:** `classes/druid/combo.lua` lines 414-457

```lua
macroTorch.SelfTest:register("Druid: combo methods -- catAtk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.catAtk) == "function", "catAtk not a function")
end, true)
```

**Hunter adaptation (5 tests -- one per macro function):**
```lua
macroTorch.SelfTest:register("Hunter: combo methods -- hunterAtk exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterAtk) == "function", "hunterAtk not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterAoe exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterAoe) == "function", "hunterAoe not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterDefend exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterDefend) == "function", "hunterDefend not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterControl exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterControl) == "function", "hunterControl not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterMobTagging exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterMobTagging) == "function", "hunterMobTagging not a function")
end, true)
```

---

### 3. `build_order.txt` (config, N/A)

**Analog:** `build_order.txt` lines 37-39 (current Hunter entries)

**Current state (lines 37-39):**
```
classes/hunter/Hunter.lua
classes/hunter/combat.lua
classes/hunter/utility.lua
```

**Required change:**
```
classes/hunter/Hunter.lua
classes/hunter/combo.lua       # ADD: new combo macro file
# classes/hunter/combat.lua    # REMOVE (or delete line)
# classes/hunter/utility.lua   # REMOVE (or delete line)
```

**Action:** Remove `classes/hunter/combat.lua` and `classes/hunter/utility.lua` lines. Add `classes/hunter/combo.lua` immediately after `classes/hunter/Hunter.lua`.

---

## Shared Patterns

### S-1: `_castSpell` Signature

**Source:** `entity/Player.lua` lines 34-88; used in all skill method definitions

```lua
obj._castSpell(localeNames, mode, range, resourceCost, onSelf, rank)
```

| Param | Type | Typical Hunter Value | Notes |
|-------|------|---------------------|-------|
| `localeNames` | table | `{en='...', zh='...'}` | Dual-locale required for zhCN support |
| `mode` | string/nil | nil = safe, 'ready' = readiness-only, 'raw' = no checks | nil includes range+readiness checks |
| `range` | number/nil | 30 for shots, nil for melee/traps/self | nil = no range check (melee is always in range if in targeting) |
| `resourceCost` | number/nil | nil | Mana not numerically modeled; `nil` skips resource check |
| `onSelf` | boolean | false (enemy) / true (self/traps) | Traps are onSelf=true (placed at feet) |
| `rank` | number/nil | nil (highest) / 1 (for hunterMobTagging) | Only arcane_shot uses rank=1 |

### S-2: `clickContext` Local Caching Pattern

**Source:** `classes/druid/combo.lua` lines 54-110

Every combo macro function creates a fresh `local clickContext = {}` at its start. Cached values include:
- Thresholds (`PLAYER_URGENT_HP_THRESHOLD = 15`)
- State flags (`isInCombat`, `isTargetDummy`)
- Computed values (`isFightStarted` is lazily cached via `macroTorch.isFightStarted(clickContext)`)

**Hunter clickContext fields (simpler -- no energy tracking):**
```lua
clickContext = {
    PLAYER_URGENT_HP_THRESHOLD = 15,
    isInCombat,
    isTargetDummy,
    isFightStarted,     -- lazy-cached by macroTorch.isFightStarted()
    -- no energy/rage/combo point tracking
}
```

### S-3: `isFightStarted` Gating

**Source:** `classes/druid/Druid.lua` lines 817-827

Modules 3+ in the priority chain are gated behind `macroTorch.isFightStarted(clickContext)`. Hunter reuses this function directly -- no modifications needed (no prowling logic for Hunter, takes the first branch correctly).

### S-4: `targetEnemy()` Pattern

**Source:** `entity/Player.lua` lines 205-214

```lua
if not target.isCanAttack then
    macroTorch.player.targetEnemy()
    if not target.isCanAttack then return end
end
```

Used in every combo macro that requires a target. Exact same pattern across hunterAoe, hunterControl, hunterMobTagging.

### S-5: `isSpellExist` + `isSpellReady` Guard

**Source:** throughout `classes/druid/combo.lua`

Every skill call is guarded by `isSpellExist` (talent-gated skills) and optionally `isSpellReady` (cooldown skills):

```lua
if macroTorch.isSpellExist('Multi-Shot', 'spell') then
    macroTorch.player.multi_shot('ready')
end
```

Skills expected by class design (always learned): guard with `isSpellExist` only.
Skills on cooldown (Deterrence, traps): guard with both `isSpellExist` + `isSpellReady`.

### S-6: `SelfTest:register` API

**Source:** `core/selftest.lua`

```lua
macroTorch.SelfTest:register("Category: name", function()
    if UnitClass('player') ~= 'ClassName' then return end
    assert(condition, "failure message")
end, isOptional)
```

- `name`: `"ClassName: descriptive text"`
- `fn`: must start with `UnitClass('player') ~= 'ClassName'` guard (returns early for other classes)
- `isOptional`: always `true` for class-specific tests

### S-7: Comment Style and Module Separation

**Source:** `classes/druid/combo.lua`

- Section comments: Chinese + English (e.g., `-- 猫德一键输出宏逻辑, dps最大化`)
- Module numbering: `-- 1. combatUrgentHPRestore`, `-- 2. targetEnemy`, etc.
- Inline comments: Chinese for implementation rationale

---

## No Analog Found

None. All files have exact analogs in the Druid class structure. This is a "pattern replication" phase -- the entire architecture mirrors Druid's.

| File | Analog | Match Quality |
|------|--------|---------------|
| `classes/hunter/Hunter.lua` | `classes/druid/Druid.lua` | exact -- same role, same pattern |
| `classes/hunter/combo.lua` | `classes/druid/combo.lua` | exact -- same role, same pattern |
| `build_order.txt` | `build_order.txt` lines 27-31 (Druid entries) | exact -- same config format |
| `classes/hunter/combat.lua` | N/A (deletion) | N/A |
| `classes/hunter/utility.lua` | N/A (deletion) | N/A |

## Metadata

**Analog search scope:** `classes/druid/`, `classes/hunter/`, `build_order.txt`
**Files scanned:** 8 (Druid.lua 1453 lines, druid/combo.lua 457 lines, Hunter.lua 156 lines, combat.lua 74 lines, utility.lua 32 lines, build_order.txt 57 lines, entity/Player.lua referenced sections, core/selftest.lua referenced sections)
**Pattern extraction date:** 2026-08-18
**Key risk:** The 25 assumed skill names/messages in RESEARCH.md Assumptions Log (Section 13) are [ASSUMED] from training data -- planner MUST flag these for user verification before implementation.