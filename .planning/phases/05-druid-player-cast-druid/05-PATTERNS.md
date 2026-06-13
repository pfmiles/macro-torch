# Phase 05: Druid 技能方法封装改造 - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `entity/Player.lua` | model (base class) | request-response | `entity/Player.lua` (existing `cast`, `isSpellReady`, `use` methods) | exact (modify same file) |
| `classes/druid/Druid.lua` | model (subclass constructor) | request-response | `classes/druid/Druid.lua` (existing `prowl`, `catAtk` methods) | exact (modify same file) |
| `classes/druid/cat.lua` | service (combat logic) | event-driven | `classes/druid/cat.lua` (existing `safeShred`/`readyShred` pattern, `regularAttack`) | exact (modify same file) |
| `classes/druid/bear.lua` | service (combat logic) | event-driven | `classes/druid/bear.lua` (existing `safeMaul`/`readyMaul` pattern, `bearAtk`) | exact (modify same file) |
| `classes/druid/utility.lua` | service (utility) | event-driven | `classes/druid/utility.lua` (existing `player.cast()` calls within utility functions) | exact (modify same file) |

## Pattern Assignments

### 1. `entity/Player.lua` -- ADD: `_castSpell`, `_isInRange`, `_hasResource` methods

**Analog:** `entity/Player.lua` (its own `Player:new()` constructor, existing `cast`, `isSpellReady` methods)

**Existing `cast` method pattern** (entity/Player.lua lines 26-31):
```lua
    -- cast spell by name
    -- @param spellName string spell name
    -- @param onSelf boolean true if cast on self, current target otherwise
    function obj.cast(spellName, onSelf)
        macroTorch.castSpellByName(spellName, 'spell')
    end
```

**Existing `isSpellReady` method pattern** (entity/Player.lua lines 99-104):
```lua
    -- tell if the specified spell is ready
    -- @param spellName string spell name
    -- @return boolean true if ready, false otherwise
    function obj.isSpellReady(spellName)
        return macroTorch.toBoolean(SpellReady(spellName) and macroTorch.isSpellCooledDown(spellName, 'spell'))
    end
```

**Existing `use` method pattern for self-targeting parameter** (entity/Player.lua lines 33-41):
```lua
    -- use item in bag by name
    -- @param itemName string item name
    -- @param onSelf boolean true if use on self, current target otherwise
    function obj.use(itemName, onSelf)
        local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
        if bagId and slotIndex then
            UseContainerItem(bagId, slotIndex, onSelf)
        end
    end
```

**Pattern for `_castSpell` -- insert into `Player:new()` after `obj.cast` (after line 31):**
New methods follow the same `function obj.methodName(...)` closure pattern used by all existing methods in Player:new(). The `_` prefix convention is not used elsewhere in Player.lua, but is explicitly specified in the design (D-05) to indicate "internal/private helper".

```lua
    -- Internal: shared spell casting helper with locale support, readiness, and resource checks
    -- @param localeNames table { en = 'EnglishName', zh = '中文名' }
    -- @param mode string|nil nil='ready', 'raw'=no checks, 'safe'=all checks
    -- @param range number|nil distance in yards, nil = melee (no check)
    -- @param resourceCost number|function|nil cost or function returning cost, nil = skip check
    -- @param onSelf boolean true if cast on self
    -- @return boolean true if spell was cast
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

    -- Internal: check if current target is within casting range
    -- @param range number distance in yards, nil/0 = melee (always in range if target exists)
    -- @return boolean
    function obj._isInRange(range)
        if not macroTorch.target or not macroTorch.target.isExist then
            return false
        end
        if type(range) ~= 'number' or range <= 0 then
            return true  -- nil/0 range = melee, always considered in range if target exists
        end
        return macroTorch.target.distance <= range
    end

    -- Internal: check if player has sufficient resource for spell
    -- @param cost number resource cost (energy/rage/mana)
    -- @return boolean
    -- WoW 1.12.1: UnitMana('player') returns energy in cat, rage in bear, mana in caster
    function obj._hasResource(cost)
        return self.mana >= cost
    end
```

**Error handling pattern from existing `use` method** (entity/Player.lua lines 33-41):
- Guard clauses with early returns (no try/catch in WoW 1.12.1 Lua)
- `return false` for all failure cases
- `return true` on success

**Validation pattern from `isSpellReady`** (entity/Player.lua line 103):
- Uses `macroTorch.toBoolean()` to coerce values to boolean
- Method signature uses `@param` / `@return` LuaDoc comments

**Resource pattern from `_hasResource` analog**:
- `self.mana` on Player instances maps to `UnitMana('player')` via `Unit.lua` FIELD_FUNC_MAP (entity/Unit.lua line 126-128):
```lua
    ['manaLost'] = function(self)
        return UnitManaMax(self.ref) - UnitMana(self.ref)
    end,
```

**Distance pattern from `_isInRange` analog**:
- `macroTorch.target.distance` defined in Unit.lua FIELD_FUNC_MAP (entity/Unit.lua lines 135-136):
```lua
    ['distance'] = function(self)
        return UnitXP and UnitXP("distanceBetween", "player", self.ref) or 0
    end,
```
- `macroTorch.target.isExist` is inherited from Unit base class -- checks if target unit exists

---

### 2. `classes/druid/Druid.lua` -- ADD: ~43 skill methods in `Druid:new()`

**Analog:** `classes/druid/Druid.lua` (existing `prowl`, `trackHumanoids`, `catAtk` methods in `Druid:new()`)

**Existing skill method pattern** (classes/druid/Druid.lua lines 85-95):
```lua
    function obj.prowl()
        if not obj.buffed('Prowl') then
            obj.cast('Prowl')
        end
    end

    function obj.trackHumanoids()
        if not obj.buffed('Track Humanoids') then
            obj.cast('Track Humanoids')
        end
    end
```

**Pattern for new skill methods -- Type A (enemy target, onSelf=false):**
Insert into `Druid:new()` after line 95 (after existing `trackHumanoids` method). Each method is 1-4 lines, forwarding to `self:_castSpell(...)`:

```lua
    -- Cat form skills (Type A: enemy target only)
    function obj.claw(mode)
        return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
    end

    function obj.shred(mode)
        return self:_castSpell({ en = 'Shred', zh = '撕碎' }, mode, nil, macroTorch.computeShred_E, false)
    end

    function obj.rake(mode)
        return self:_castSpell({ en = 'Rake', zh = '斜掠' }, mode, nil, macroTorch.computeRake_E, false)
    end

    function obj.rip(mode)
        return self:_castSpell({ en = 'Rip', zh = '撕扯' }, mode, nil, 30, false)
    end

    function obj.ferocious_bite(mode)
        return self:_castSpell({ en = 'Ferocious Bite', zh = '凶猛撕咬' }, mode, nil, 35, false)
    end

    function obj.pounce(mode)
        return self:_castSpell({ en = 'Pounce', zh = '突袭' }, mode, nil, 50, false)
    end

    function obj.cower(mode)
        return self:_castSpell({ en = 'Cower', zh = '畏缩' }, mode, nil, 20, false)
    end

    function obj.faerie_fire_feral(mode)
        return self:_castSpell({ en = 'Faerie Fire (Feral)', zh = '精灵之火（野性）' }, mode, nil, 0, false)
    end

    function obj.ravage(mode)
        return self:_castSpell({ en = 'Ravage', zh = '毁灭' }, mode, nil, 50, false)
    end

    -- Bear form skills (Type A: enemy target only, using fixed rage costs as placeholders)
    function obj.growl(mode)
        return self:_castSpell({ en = 'Growl', zh = '低吼' }, mode, nil, 10, false)
    end

    function obj.bash(mode)
        return self:_castSpell({ en = 'Bash', zh = '猛击' }, mode, nil, 10, false)
    end

    function obj.swipe(mode)
        return self:_castSpell({ en = 'Swipe', zh = '横扫' }, mode, nil, 15, false)
    end

    function obj.maul(mode)
        return self:_castSpell({ en = 'Maul', zh = '重击' }, mode, nil, 10, false)
    end

    function obj.demoralizing_roar(mode)
        return self:_castSpell({ en = 'Demoralizing Roar', zh = '挫志咆哮' }, mode, nil, 10, false)
    end

    function obj.feral_charge(mode)
        return self:_castSpell({ en = 'Feral Charge', zh = '野性冲锋' }, mode, 25, nil, false)
    end

    function obj.challenging_roar(mode)
        return self:_castSpell({ en = 'Challenging Roar', zh = '挑战咆哮' }, mode, nil, 15, false)
    end

    -- Caster form skills (Type A: enemy target only)
    function obj.wrath(mode)
        return self:_castSpell({ en = 'Wrath', zh = '愤怒' }, mode, 30, nil, false)
    end

    function obj.moonfire(mode)
        return self:_castSpell({ en = 'Moonfire', zh = '月火术' }, mode, 30, nil, false)
    end

    function obj.starfire(mode)
        return self:_castSpell({ en = 'Starfire', zh = '星火术' }, mode, 30, nil, false)
    end

    function obj.entangling_roots(mode)
        return self:_castSpell({ en = 'Entangling Roots', zh = '纠缠根须' }, mode, 30, nil, false)
    end

    function obj.hibernate(mode)
        return self:_castSpell({ en = 'Hibernate', zh = '休眠' }, mode, 30, nil, false)
    end

    function obj.faerie_fire(mode)
        return self:_castSpell({ en = 'Faerie Fire', zh = '精灵之火' }, mode, 30, nil, false)
    end

    function obj.insect_swarm(mode)
        return self:_castSpell({ en = 'Insect Swarm', zh = '虫群' }, mode, 30, nil, false)
    end

    function obj.soothe_animal(mode)
        return self:_castSpell({ en = 'Soothe Animal', zh = '安抚动物' }, mode, 30, nil, false)
    end
```

**Pattern for new skill methods -- Type B (self target, onSelf=true):**
```lua
    -- Form skills (Type B: self target only)
    function obj.bear_form(mode)
        return self:_castSpell({ en = 'Bear Form', zh = '熊形态' }, mode, nil, nil, true)
    end

    function obj.dire_bear_form(mode)
        return self:_castSpell({ en = 'Dire Bear Form', zh = '巨熊形态' }, mode, nil, nil, true)
    end

    function obj.cat_form(mode)
        return self:_castSpell({ en = 'Cat Form', zh = '猫形态' }, mode, nil, nil, true)
    end

    function obj.travel_form(mode)
        return self:_castSpell({ en = 'Travel Form', zh = '旅行形态' }, mode, nil, nil, true)
    end

    function obj.aquatic_form(mode)
        return self:_castSpell({ en = 'Aquatic Form', zh = '水栖形态' }, mode, nil, nil, true)
    end

    -- Self buff skills (Type B: self target only)
    function obj.dash(mode)
        return self:_castSpell({ en = 'Dash', zh = '急奔' }, mode, nil, 0, true)
    end

    function obj.tiger_fury(mode)
        return self:_castSpell({ en = "Tiger's Fury", zh = '猛虎之怒' }, mode, nil, macroTorch.computeTiger_E, true)
    end

    function obj.barkskin(mode)
        return self:_castSpell({ en = 'Barkskin', zh = '树皮术' }, mode, nil, 0, true)
    end

    function obj.track_humanoids(mode)
        return self:_castSpell({ en = 'Track Humanoids', zh = '追踪人型' }, mode, nil, 0, true)
    end

    function obj.natures_swiftness(mode)
        return self:_castSpell({ en = "Nature's Swiftness", zh = '自然迅捷' }, mode, nil, 0, true)
    end

    function obj.tranquility(mode)
        return self:_castSpell({ en = 'Tranquility', zh = '宁静' }, mode, nil, nil, true)
    end

    function obj.hurricane(mode)
        return self:_castSpell({ en = 'Hurricane', zh = '飓风' }, mode, nil, nil, true)
    end

    function obj.innervate(mode)
        return self:_castSpell({ en = 'Innervate', zh = '激活' }, mode, nil, 0, true)
    end

    function obj.rebirth(mode)
        return self:_castSpell({ en = 'Rebirth', zh = '复生' }, mode, nil, nil, true)
    end

    function obj.frenzied_regeneration(mode)
        return self:_castSpell({ en = 'Frenzied Regeneration', zh = '狂暴回复' }, mode, nil, 10, true)
    end

    function obj.enrage(mode)
        return self:_castSpell({ en = 'Enrage', zh = '激怒' }, mode, nil, 0, true)
    end

    function obj.reshift(mode)
        return self:_castSpell({ en = 'Reshift', zh = '变身' }, mode, nil, 0, true)
    end

    function obj.berserk(mode)
        return self:_castSpell({ en = 'Berserk', zh = '狂暴' }, mode, nil, 0, true)
    end

    function obj.natures_grasp(mode)
        return self:_castSpell({ en = "Nature's Grasp", zh = '自然之握' }, mode, nil, nil, true)
    end
```

**Pattern for new skill methods -- Type C (flexible target, onSelf exposed):**
```lua
    -- Flexible target skills (Type C: onSelf parameter exposed)
    function obj.healing_touch(mode, onSelf)
        return self:_castSpell({ en = 'Healing Touch', zh = '治疗之触' }, mode, 40, nil, onSelf)
    end

    function obj.regrowth(mode, onSelf)
        return self:_castSpell({ en = 'Regrowth', zh = '愈合' }, mode, 40, nil, onSelf)
    end

    function obj.rejuvenation(mode, onSelf)
        return self:_castSpell({ en = 'Rejuvenation', zh = '回春术' }, mode, 40, nil, onSelf)
    end

    function obj.remove_curse(mode, onSelf)
        return self:_castSpell({ en = 'Remove Curse', zh = '驱除诅咒' }, mode, 40, nil, onSelf)
    end

    function obj.abolish_poison(mode, onSelf)
        return self:_castSpell({ en = 'Abolish Poison', zh = '驱毒术' }, mode, 40, nil, onSelf)
    end

    function obj.cure_poison(mode, onSelf)
        return self:_castSpell({ en = 'Cure Poison', zh = '消毒术' }, mode, 40, nil, onSelf)
    end

    function obj.mark_of_the_wild(mode, onSelf)
        return self:_castSpell({ en = 'Mark of the Wild', zh = '野性印记' }, mode, 30, nil, onSelf)
    end

    function obj.gift_of_the_wild(mode, onSelf)
        return self:_castSpell({ en = 'Gift of the Wild', zh = '野性赐福' }, mode, 30, nil, onSelf)
    end

    function obj.thorns(mode, onSelf)
        return self:_castSpell({ en = 'Thorns', zh = '荆棘术' }, mode, 30, nil, onSelf)
    end
```

**IMPORTANT: Remove existing old `obj.prowl()` and `obj.trackHumanoids()` methods (lines 85-95) since they will be replaced by the new skill methods above.**

**IMPORTANT: Remove the commented-out `obj.cast()` block (lines 22-27) per RESEARCH.md Pitfall 2.**

**Location for new methods:** All skill methods are added inside `Druid:new()`, after the `obj.trackHumanoids()` removal and before the existing `obj.catAtk()` method. The exact insertion point is after line 28 (after the `setmetatable` call) and before line 30 (the `obj.showEnergyUsageSet` method).

---

### 3. `classes/druid/cat.lua` -- MODIFY: replace `player.cast()` calls, DELETE safe/ready functions

**Analog:** `classes/druid/cat.lua` (its own existing patterns)

**Pattern: safe/ready function pair to delete** (cat.lua lines 301-310):
```lua
-- DELETE these 2 functions:
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
```

**Pattern: regularAttack replacement** (cat.lua lines 46-57):
```lua
-- BEFORE:
function macroTorch.regularAttack(clickContext)
    local shredMethod = clickContext.ooc and macroTorch.readyShred or macroTorch.safeShred
    local clawMethod = clickContext.ooc and macroTorch.readyClaw or macroTorch.safeClaw
    if macroTorch.shouldUseShred(clickContext) then
        shredMethod(clickContext)
    else
        clawMethod(clickContext)
    end
end

-- AFTER:
function macroTorch.regularAttack(clickContext)
    if macroTorch.shouldUseShred(clickContext) then
        if clickContext.ooc then
            macroTorch.player.shred()        -- ooc: ready mode
        else
            macroTorch.player.shred('safe')   -- normal: safe mode
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

**Pattern: direct `player.cast()` call replacement** (cat.lua line 18, line 164):
```lua
-- BEFORE:
    player.cast('Berserk')
-- AFTER:
    player.berserk()

-- BEFORE:
    macroTorch.player.cast('Ferocious Bite')
-- AFTER:
    macroTorch.player.ferocious_bite('raw')
```

**Pattern: bite-ready call replacement with mode** (cat.lua lines 351-358):
```lua
-- BEFORE (inside macroTorch.readyBite):
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.player.cast('Ferocious Bite')
-- AFTER (inside macroTorch.readyBite):
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.player.ferocious_bite('ready')
```

**Pattern: safeBite replacement** (cat.lua lines 348-349):
```lua
-- BEFORE:
    return macroTorch.player.mana >= clickContext.BITE_E and macroTorch.readyBite(clickContext)
-- AFTER (safeBite now only checks energy, then delegates to readyBite which uses 'ready' mode):
    return macroTorch.player.mana >= clickContext.BITE_E and macroTorch.readyBite(clickContext)
    -- (readyBite internally uses player.ferocious_bite('ready') instead of player.cast('Ferocious Bite'))
```

**Complete list of safe/ready functions to DELETE from cat.lua:**
- `macroTorch.safeShred` (lines 301-303)
- `macroTorch.readyShred` (lines 304-310)
- `macroTorch.safeClaw` (lines 311-313)
- `macroTorch.readyClaw` (lines 314-320)
- `macroTorch.safeRake` (lines 321-332)
- `macroTorch.safeRip` (lines 333-347)
- `macroTorch.safeBite` (lines 348-349)
- `macroTorch.readyBite` (lines 350-358) -- replaced with skill method call
- `macroTorch.safeTigerFury` (lines 359-368)
- `macroTorch.safePounce` (lines 370-376)
- `macroTorch.readyCower` (lines 377-384)
- `macroTorch.safeCower` (lines 385-390)

**Note on `safeRake`, `safeRip`, `safeTigerFury`, `safePounce`, `safeFF`:** These functions contain additional side effects (recording lastRakeEquippedSavagery, lastRipEquippedSavagery, tigerTimer, ffTimer) and debug `macroTorch.show()` calls. When replacing with skill method calls, the side effect logic must be retained in the calling context (e.g., `macroTorch.keepRake` in Druid.lua must set `macroTorch.loginContext.lastRakeEquippedSavagery` before calling `player.rake('safe')`). The `_castSpell` method itself does NOT handle these side effects.

**Special case: `safeFF` uses `isGcdOk` check not in `_castSpell`. Per RESEARCH.md Open Question 3, keep GCD checking in the caller and use `player.faerie_fire_feral('raw')`:**
```lua
-- BEFORE (Druid.lua lines 990-1002):
function macroTorch.safeFF(clickContext)
    if macroTorch.player.isSpellReady('Faerie Fire (Feral)') and macroTorch.isGcdOk(clickContext) then
        macroTorch.show('FF!!! ...')
        macroTorch.player.cast('Faerie Fire (Feral)')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end

-- AFTER: This function stays but uses the new skill method:
function macroTorch.safeFF(clickContext)
    if macroTorch.player.isSpellReady('Faerie Fire (Feral)') and macroTorch.isGcdOk(clickContext) then
        macroTorch.show('FF!!! FF present: ' ..
                tostring(macroTorch.isFFPresent(clickContext)) ..
                ', FF left: ' ..
                tostring(macroTorch.ffLeft(clickContext)) ..
                ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. tostring(clickContext.comboPoints))
        macroTorch.player.faerie_fire_feral('raw')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end
```

**Pattern for oocMod call replacement** (cat.lua lines 142-160):
```lua
-- The function structure stays identical -- only internal player.cast() calls change
-- Line 164: macroTorch.player.cast('Ferocious Bite') -> macroTorch.player.ferocious_bite('raw')
```

**Pattern for reshift call replacement** (cat.lua line 296):
```lua
-- BEFORE: macroTorch.player.cast('Reshift')
-- AFTER:  macroTorch.player.reshift('ready')
```

---

### 4. `classes/druid/bear.lua` -- MODIFY: replace `player.cast()` calls, DELETE safe/ready functions

**Analog:** `classes/druid/bear.lua` (its own existing pattern)

**Pattern: safe/ready function pair to replace** (bear.lua lines 2-11):
```lua
-- DELETE these 2 functions:
function macroTorch.safeMaul(clickContext)
    return macroTorch.player.mana >= clickContext.MAUL_E and macroTorch.readyMaul(clickContext)
end
function macroTorch.readyMaul(clickContext)
    if macroTorch.player.isSpellReady('Maul') then
        macroTorch.player.cast('Maul')    -- becomes: macroTorch.player.maul('ready')
        return true
    end
    return false
end

-- AFTER: No safeMaul/readyMaul functions. Callers use:
--   macroTorch.player.maul()       for 'ready' (nil = default ready mode)
--   macroTorch.player.maul('safe') for 'safe'
```

**Complete list of functions to DELETE from bear.lua:**
- `macroTorch.safeMaul` (lines 2-4)
- `macroTorch.readyMaul` (lines 5-11)
- `macroTorch.safeSavageBite` (lines 12-14)
- `macroTorch.readySavageBite` (lines 15-21)
- `macroTorch.readyGrowl` (lines 22-28)
- `macroTorch.safeDemoralizingRoar` (lines 29-31)
- `macroTorch.readyDemoralizingRoar` (lines 32-38)
- `macroTorch.safeSwipe` (lines 39-41)
- `macroTorch.readySwipe` (lines 42-48)

**Pattern: caller replacement when safe/ready functions are deleted** (bear.lua):
```lua
-- bearOocMod (line 49-55): readySavageBite -> player.ferocious_bite('ready')
    macroTorch.player.ferocious_bite('ready')

-- bearOtMod (line 56-76): readyGrowl -> player.growl('ready'), safeSavageBite -> player.ferocious_bite('safe')
    if macroTorch.player.growl('ready') then ... end
    macroTorch.player.ferocious_bite('safe')

-- bearDebuffMod (line 77-81): safeDemoralizingRoar -> player.demoralizing_roar('safe')
    macroTorch.player.demoralizing_roar('safe')

-- bearRegularAttack (line 92-103): safeSavageBite -> player.ferocious_bite('safe'), safeMaul -> player.maul('safe')
    if not clickContext.rough and clickContext.rage > clickContext.RAGE_DUMP_THRESHOLD and macroTorch.player.ferocious_bite('safe') then
    if macroTorch.player.maul('safe') then

-- bearAoe (line 111-127): safeSwipe -> player.swipe('safe')
    if macroTorch.player.swipe('safe') then

-- bearReshiftMod (line 104-110): player.cast('Reshift') -> player.reshift('ready')
    macroTorch.player.reshift('ready')
```

**Note on 'Savage Bite':** The bear.lua code casts 'Savage Bite' which is the bear form version. The skill method `ferocious_bite` with `{ en = 'Ferocious Bite', zh = '凶猛撕咬' }` should work for both cat and bear forms since `getSpellIdByName` finds spells by name. However, if 'Savage Bite' is a different spell name, we need a separate `savage_bite` method. Based on RESEARCH.md line 676, the assumption is 'Savage Bite' is bear form FB and `ferocious_bite` covers it. If this is wrong in-game, add a separate `savage_bite` skill method.

---

### 5. `classes/druid/utility.lua` -- MODIFY: replace `player.cast()` calls

**Analog:** `classes/druid/utility.lua` (its own existing pattern)

**Pattern: buff self-replacement** (utility.lua lines 2-13):
```lua
-- BEFORE:
function macroTorch.druidBuffs()
    local clickContext = {}
    if not macroTorch.player.buffed('Mark of the Wild') then
        macroTorch.player.cast('Mark of the Wild', true)
    end
    if not macroTorch.player.buffed('Thorns') then
        macroTorch.player.cast('Thorns', true)
    end
    if not macroTorch.player.buffed('Nature\'s Grasp') then
        macroTorch.player.cast('Nature\'s Grasp', true)
    end
end

-- AFTER:
function macroTorch.druidBuffs()
    local clickContext = {}
    if not macroTorch.player.buffed('Mark of the Wild') then
        macroTorch.player.mark_of_the_wild(nil, true)
    end
    if not macroTorch.player.buffed('Thorns') then
        macroTorch.player.thorns(nil, true)
    end
    if not macroTorch.player.buffed('Nature\'s Grasp') then
        macroTorch.player.natures_grasp()
    end
end
```

**Pattern: utility replacement table** (all utility.lua calls):
```lua
-- Line 5:  macroTorch.player.cast('Mark of the Wild', true)    -> macroTorch.player.mark_of_the_wild(nil, true)
-- Line 8:  macroTorch.player.cast('Thorns', true)              -> macroTorch.player.thorns(nil, true)
-- Line 11: macroTorch.player.cast('Nature\'s Grasp', true)     -> macroTorch.player.natures_grasp()
-- Line 20: macroTorch.player.cast('Dire Bear Form')            -> macroTorch.player.dire_bear_form()
-- Line 24: macroTorch.player.cast('Reshift')                   -> macroTorch.player.reshift()
-- Line 27: macroTorch.player.cast('Bash')                      -> macroTorch.player.bash()
-- Line 30: macroTorch.player.cast('Feral Charge')              -> macroTorch.player.feral_charge()
-- Line 38: macroTorch.player.cast('Barkskin (Feral)')          -> macroTorch.player.barkskin()
-- Line 43: macroTorch.player.cast('Dire Bear Form')            -> macroTorch.player.dire_bear_form()
-- Line 46: macroTorch.player.cast('Enrage')                    -> macroTorch.player.enrage()
-- Line 48: macroTorch.player.cast('Frenzied Regeneration')     -> macroTorch.player.frenzied_regeneration()
-- Line 55: macroTorch.player.cast('Hibernate')                 -> macroTorch.player.hibernate()
-- Line 57: macroTorch.player.cast('Entangling Roots')          -> macroTorch.player.entangling_roots()
```

**Note on `druidBuffs`:** Current code creates a `local clickContext = {}` but does nothing with it. This is an unused variable that can optionally be removed.

---

### 6. `classes/druid/Druid.lua` -- ADDITIONAL: replace `player.cast()` in existing code

**Analog:** `classes/druid/Druid.lua` (self, existing `catAtk` body)

**Pattern: opener mod replacement** (Druid.lua line 191 and inside `safePounce`/caller):
```lua
-- Line 191 (inside catAtk):
-- BEFORE: player.cast('Ravage')
-- AFTER:  player.ravage()
-- Note: Ravage is Type A, but this call site uses no resource check and trusts spell will land.
-- Use bare player.ravage() (nil = default ready mode) since it's inside an opener branch where
-- the player is prowling and energy is available.
```

**Pattern: `safePounce` call site** (Druid.lua line 189):
```lua
-- Line 189: macroTorch.safePounce(clickContext)
-- After deletion of safePounce from cat.lua, this call becomes inlined or:
-- Since safePounce checks: isSpellReady + isGcdOk + mana + isNearBy, then casts
-- The caller in catAtk needs to check these conditions before calling player.pounce('safe'):
-- In practice, the `_castSpell` 'safe' mode covers mana + isNearBy (if range passed as nil it checks nil->melee->target exists),
-- but does NOT cover isGcdOk. If isGcdOk is needed, it must be checked before calling player.pounce('safe').
-- Per the safePounce function body, add GCD check at call site:
    if clickContext.prowling then
        if not target.isImmune('Pounce') and target.health >= 1500 then
            if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
                macroTorch.player.pounce('safe')
            end
        else
            player.ravage()
        end
    end
```

**Note on `macroTorch.safePounce` side effects:** Unlike safeRake/safeRip, safePounce has no snapshot recording side effects. Direct replacement with `player.pounce('safe')` is safe provided the caller handles `isGcdOk` and `isNearBy` externally.

---

## Shared Patterns

### Metatable Inheritance Chain
**Source:** `entity/Player.lua` line 469, `classes/druid/Druid.lua` line 29
**Apply to:** Understanding of `self:_castSpell()` resolution

```lua
-- Player.lua line 469:
    setmetatable(obj, macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP"))

-- Druid.lua line 29:
    setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))
```

When a Druid instance calls `self:_castSpell(...)`, Lua searches: Druid instance -> Druid methods -> Druid prototype (Druid:new() closure) -> Player prototype fields -> Player methods (Player:new() closure). Since `_castSpell` is defined in `Player:new()`, it will be found on the Player prototype's metatable, and `self:cast(spellName, onSelf)` within `_castSpell` will also resolve through the same chain back to `Player.cast`.

### Method Comment Convention
**Source:** Throughout `entity/Player.lua` (e.g., lines 26-31, 99-104)
**Apply to:** All new methods

```lua
    -- short purpose description
    -- @param paramName type description
    -- @param paramName type description
    -- @return type description
    function obj.methodName(param1, param2)
```

### No `#` Length Operator
**Source:** CLAUDE.md project instructions
**Apply to:** Any table operations in new code

WoW 1.12.1 embedded Lua does NOT support the `#` unary length operator. Use `macroTorch.tableLen(tbl)` or `table.insert(tbl, val)`. This is not needed in `_castSpell` since it does not use table length, but is noted for awareness.

### Function Reference Pattern for resourceCost
**Source:** `classes/druid/Druid.lua` lines 343-387 (compute functions)
**Apply to:** Type A cat form skill methods that use dynamic energy costs

```lua
-- Pattern: function reference passed as argument, called with zero args at check time
function obj.claw(mode)
    return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end

-- In _castSpell:
--     if type(resourceCost) == 'function' then
--         cost = resourceCost()    -- calls macroTorch.computeClaw_E()
```

### Safe Mode Side Effects Pattern
**Source:** `classes/druid/cat.lua` lines 321-332 (safeRake), 333-347 (safeRip)
**Apply to:** Callers that need snapshot recording before skill method call

```lua
-- Pattern for safeRake replacement:
-- The old safeRake recorded: macroTorch.loginContext.lastRakeEquippedSavagery = ...
-- BEFORE calling player.rake('safe'), the CALLER must record the snapshot:
    macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
    macroTorch.player.rake('safe')

-- Pattern for safeRip replacement:
    macroTorch.loginContext.lastRipEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
    macroTorch.player.rip('safe')
    macroTorch.context.lastRipAtCp = clickContext.comboPoints

-- Pattern for safeTigerFury replacement:
    macroTorch.player.tiger_fury('safe')
    macroTorch.loginContext.tigerTimer = GetTime()
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | -- | -- | All files have exact analogs within themselves |

All files being modified are existing files with established patterns. The new additions follow the same patterns used elsewhere in the same files.

## Metadata

**Analog search scope:**
- `entity/Player.lua` -- full file read (682 lines)
- `entity/Unit.lua` -- targeted reads (distance, mana fields)
- `classes/druid/Druid.lua` -- full file read (1070 lines)
- `classes/druid/cat.lua` -- full file read (410 lines)
- `classes/druid/bear.lua` -- full file read (194 lines)
- `classes/druid/utility.lua` -- full file read (93 lines)
- `biz_util.lua` -- targeted read (castSpellByName)
- `docs/spell_refactor_plan_druid.txt` -- full file read (320 lines)

**Files scanned:** 8
**Pattern extraction date:** 2026-06-13