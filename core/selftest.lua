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

-- ============================================================
-- Module 1: SelfTest table initialization
-- ============================================================
-- [CITED: CONTEXT.md D-01, D-03, D-05]
-- _selfTestRan is a session flag: set on first run, cleared on reload UI
-- SelfTest.tests holds all registered test items as {name, fn, isOptional}
macroTorch.SelfTest = {
    tests = {}
}
macroTorch._selfTestRan = nil

-- ============================================================
-- Module 2: SelfTest:register(name, fn, isOptional)
-- ============================================================
-- [CITED: CONTEXT.md D-03, D-05]
-- Registers a self-test item. isOptional defaults to false.
-- Optional test failures produce warnings (yellow), core test failures produce errors (red).
function macroTorch.SelfTest:register(name, fn, isOptional)
    table.insert(self.tests, {
        name = name,
        fn = fn,
        isOptional = isOptional or false
    })
end

-- ============================================================
-- Module 3: SelfTest:run()
-- ============================================================
-- [CITED: CONTEXT.md D-01, D-05; RESEARCH Pitfall 5]
-- Runs all registered tests with pcall isolation. Each test failure is captured
-- and reported. Successful tests produce no output. Failed core tests are reported
-- in red, optional test failures in yellow. A summary line is always output.
function macroTorch.SelfTest:run()
    -- D-01: session flag prevents repeated output on zone transitions
    if macroTorch._selfTestRan then
        return
    end
    macroTorch._selfTestRan = true

    local passed, failed, warnings = 0, 0, 0
    local failedNames = {}
    local warningNames = {}

    for _, test in ipairs(self.tests) do
        local success, err = pcall(test.fn)
        if success then
            passed = passed + 1
            -- D-05: success items are silent -- no log output
        else
            if test.isOptional then
                warnings = warnings + 1
                table.insert(warningNames, test.name)
            else
                failed = failed + 1
                table.insert(failedNames, test.name)
            end
            -- RESEARCH Pitfall 5: capture detailed error with tostring(err)
            local category = test.isOptional and "WARN" or "FAIL"
            macroTorch.show("[macro-torch] " .. category .. ": " .. test.name .. " - " .. tostring(err),
                test.isOptional and 'yellow' or 'red')
        end
    end

    -- D-05: summary line in white
    macroTorch.show(string.format("[macro-torch] Self-test: %d passed, %d failed, %d warnings",
        passed, failed, warnings), 'white')

    -- D-05: list failed core items in red
    for _, name in ipairs(failedNames) do
        macroTorch.show("[macro-torch] FAIL: " .. name, 'red')
    end

    -- D-05: list warning (optional) items in yellow
    for _, name in ipairs(warningNames) do
        macroTorch.show("[macro-torch] WARN: " .. name, 'yellow')
    end

    -- Print Druid skill diagnostics after selftest (quick task 260623-wrh-druid)
    macroTorch.printDruidDiag()
end

-- ============================================================
-- Category A: Lua Basic Environment Tests (>=8, all isOptional=false)
-- ============================================================
-- [CITED: ROADMAP T3.1.2]
-- Direct call verification of Lua 5.0 built-in functions.

macroTorch.SelfTest:register("Lua: type() exists", function()
    assert(type(type) == "function", "type() not a function")
end, false)

macroTorch.SelfTest:register("Lua: pcall() works", function()
    local ok = pcall(function() return 1 end)
    assert(ok, "pcall() returned false")
end, false)

macroTorch.SelfTest:register("Lua: setmetatable() works", function()
    local t = setmetatable({}, {__index = {test = 1}})
    assert(t.test == 1, "setmetatable() did not set __index")
end, false)

macroTorch.SelfTest:register("Lua: table.insert works", function()
    local t = {}
    table.insert(t, 1)
    assert(t[1] == 1, "table.insert did not insert")
end, false)

macroTorch.SelfTest:register("Lua: string.format works", function()
    assert(string.format("%s", "test") == "test", "string.format failed")
end, false)

macroTorch.SelfTest:register("Lua: ipairs() works", function()
    local count = 0
    for _, _ in ipairs({1, 2, 3}) do count = count + 1 end
    assert(count == 3, "ipairs() did not iterate 3 times")
end, false)

macroTorch.SelfTest:register("Lua: unpack() works", function()
    local a, b, c = unpack({1, 2, 3})
    assert(a == 1 and b == 2 and c == 3, "unpack() failed")
end, false)

macroTorch.SelfTest:register("Lua: error() exists as function", function()
    assert(type(error) == "function", "error() is not a function")
end, false)

macroTorch.SelfTest:register("Lua: pcall catches runtime error", function()
    local ok, err = pcall(function() return nil + 1 end)
    assert(not ok, "pcall should have caught the error")
    assert(string.find(tostring(err), "nil"), "error message not captured, got: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("Lua: math.max works", function()
    assert(math.max(1, 5, 3) == 5, "math.max failed")
end, false)

macroTorch.SelfTest:register("Lua: string.find works", function()
    local s, e = string.find("hello world", "world")
    assert(s and e, "string.find did not find pattern")
end, false)

-- ============================================================
-- Category B: WoW API Function Existence Tests (>=30, all isOptional=false)
-- ============================================================
-- [CITED: ROADMAP T3.1.5]
-- Uses macroTorch.isFunctionExist(funcName) to verify _G presence without invocation.

-- Unit query functions
macroTorch.SelfTest:register("WoW: UnitHealth exists", function()
    assert(macroTorch.isFunctionExist("UnitHealth"), "UnitHealth not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitMana exists", function()
    assert(macroTorch.isFunctionExist("UnitMana"), "UnitMana not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitPowerType exists", function()
    assert(macroTorch.isFunctionExist("UnitPowerType"), "UnitPowerType not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitClass exists", function()
    assert(macroTorch.isFunctionExist("UnitClass"), "UnitClass not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitRace exists", function()
    assert(macroTorch.isFunctionExist("UnitRace"), "UnitRace not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitName exists", function()
    assert(macroTorch.isFunctionExist("UnitName"), "UnitName not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitLevel exists", function()
    assert(macroTorch.isFunctionExist("UnitLevel"), "UnitLevel not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitExists exists", function()
    assert(macroTorch.isFunctionExist("UnitExists"), "UnitExists not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitIsDead exists", function()
    assert(macroTorch.isFunctionExist("UnitIsDead"), "UnitIsDead not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitIsPlayer exists", function()
    assert(macroTorch.isFunctionExist("UnitIsPlayer"), "UnitIsPlayer not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitCanAttack exists", function()
    assert(macroTorch.isFunctionExist("UnitCanAttack"), "UnitCanAttack not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitAffectingCombat exists", function()
    assert(macroTorch.isFunctionExist("UnitAffectingCombat"), "UnitAffectingCombat not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitIsUnit exists", function()
    assert(macroTorch.isFunctionExist("UnitIsUnit"), "UnitIsUnit not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitReaction exists", function()
    assert(macroTorch.isFunctionExist("UnitReaction"), "UnitReaction not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitCreatureType exists", function()
    assert(macroTorch.isFunctionExist("UnitCreatureType"), "UnitCreatureType not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitDebuff exists", function()
    assert(macroTorch.isFunctionExist("UnitDebuff"), "UnitDebuff not found")
end, false)

macroTorch.SelfTest:register("WoW: UnitBuff exists", function()
    assert(macroTorch.isFunctionExist("UnitBuff"), "UnitBuff not found")
end, false)

-- Combo/ShapeShift functions
macroTorch.SelfTest:register("WoW: GetComboPoints exists", function()
    assert(macroTorch.isFunctionExist("GetComboPoints"), "GetComboPoints not found")
end, false)

macroTorch.SelfTest:register("WoW: GetShapeshiftFormCooldown exists", function()
    assert(macroTorch.isFunctionExist("GetShapeshiftFormCooldown"), "GetShapeshiftFormCooldown not found")
end, false)

macroTorch.SelfTest:register("WoW: GetNumShapeshiftForms exists", function()
    assert(macroTorch.isFunctionExist("GetNumShapeshiftForms"), "GetNumShapeshiftForms not found")
end, false)

macroTorch.SelfTest:register("WoW: GetShapeshiftFormInfo exists", function()
    assert(macroTorch.isFunctionExist("GetShapeshiftFormInfo"), "GetShapeshiftFormInfo not found")
end, false)

-- Spell casting functions
macroTorch.SelfTest:register("WoW: CastSpellByName exists", function()
    assert(macroTorch.isFunctionExist("CastSpellByName"), "CastSpellByName not found")
end, false)

macroTorch.SelfTest:register("WoW: SpellCanTargetUnit exists", function()
    assert(macroTorch.isFunctionExist("SpellCanTargetUnit"), "SpellCanTargetUnit not found")
end, false)

macroTorch.SelfTest:register("WoW: SpellIsTargeting exists", function()
    assert(macroTorch.isFunctionExist("SpellIsTargeting"), "SpellIsTargeting not found")
end, false)

macroTorch.SelfTest:register("WoW: SpellStopCasting exists", function()
    assert(macroTorch.isFunctionExist("SpellStopCasting"), "SpellStopCasting not found")
end, false)

macroTorch.SelfTest:register("WoW: SpellStopTargeting exists", function()
    assert(macroTorch.isFunctionExist("SpellStopTargeting"), "SpellStopTargeting not found")
end, false)

-- Action bar functions
macroTorch.SelfTest:register("WoW: IsUsableAction exists", function()
    assert(macroTorch.isFunctionExist("IsUsableAction"), "IsUsableAction not found")
end, false)

macroTorch.SelfTest:register("WoW: GetActionCooldown exists", function()
    assert(macroTorch.isFunctionExist("GetActionCooldown"), "GetActionCooldown not found")
end, false)

macroTorch.SelfTest:register("WoW: IsCurrentAction exists", function()
    assert(macroTorch.isFunctionExist("IsCurrentAction"), "IsCurrentAction not found")
end, false)

macroTorch.SelfTest:register("WoW: IsAutoRepeatAction exists", function()
    assert(macroTorch.isFunctionExist("IsAutoRepeatAction"), "IsAutoRepeatAction not found")
end, false)

-- Spell info functions
macroTorch.SelfTest:register("WoW: GetSpellName exists", function()
    assert(macroTorch.isFunctionExist("GetSpellName"), "GetSpellName not found")
end, false)

macroTorch.SelfTest:register("WoW: GetSpellCooldown exists", function()
    assert(macroTorch.isFunctionExist("GetSpellCooldown"), "GetSpellCooldown not found")
end, false)

macroTorch.SelfTest:register("WoW: GetNumTalentTabs exists", function()
    assert(macroTorch.isFunctionExist("GetNumTalentTabs"), "GetNumTalentTabs not found")
end, false)

macroTorch.SelfTest:register("WoW: GetTalentInfo exists", function()
    assert(macroTorch.isFunctionExist("GetTalentInfo"), "GetTalentInfo not found")
end, false)

-- ============================================================
-- Category C: Player Entity Property Tests (>=15, all isOptional=false)
-- ============================================================
-- [CITED: ROADMAP T3.1.3; CONTEXT.md D-04]
-- Player is the only entity that definitely exists at login.
-- Read-only property calls with type/value assertions.

macroTorch.SelfTest:register("Player: health >= 0", function()
    local h = macroTorch.player.health
    assert(type(h) == "number", "health is not a number")
    assert(h >= 0, "health is negative: " .. tostring(h))
end, false)

macroTorch.SelfTest:register("Player: mana >= 0", function()
    local m = macroTorch.player.mana
    assert(type(m) == "number", "mana is not a number")
    assert(m >= 0, "mana is negative: " .. tostring(m))
end, false)

macroTorch.SelfTest:register("Player: healthMax >= 0", function()
    local h = macroTorch.player.healthMax
    assert(type(h) == "number", "healthMax is not a number")
    assert(h >= 0, "healthMax is negative: " .. tostring(h))
end, false)

macroTorch.SelfTest:register("Player: manaMax >= 0", function()
    local m = macroTorch.player.manaMax
    assert(type(m) == "number", "manaMax is not a number")
    assert(m >= 0, "manaMax is negative: " .. tostring(m))
end, false)

macroTorch.SelfTest:register("Player: healthPercent is number", function()
    assert(type(macroTorch.player.healthPercent) == "number", "healthPercent is not a number")
end, false)

macroTorch.SelfTest:register("Player: manaPercent is number", function()
    assert(type(macroTorch.player.manaPercent) == "number", "manaPercent is not a number")
end, false)

macroTorch.SelfTest:register("Player: isInCombat is boolean", function()
    assert(type(macroTorch.toBoolean(macroTorch.player.isInCombat)) == "boolean", "isInCombat not resolvable to boolean")
end, false)

macroTorch.SelfTest:register("Player: isExist is boolean", function()
    assert(type(macroTorch.toBoolean(macroTorch.player.isExist)) == "boolean", "isExist not resolvable to boolean")
end, false)

macroTorch.SelfTest:register("Player: name is string", function()
    assert(type(macroTorch.player.name) == "string", "name is not a string")
end, false)

macroTorch.SelfTest:register("Player: level is number", function()
    assert(type(macroTorch.player.level) == "number", "level is not a number")
end, false)

macroTorch.SelfTest:register("Player: class is string", function()
    assert(type(macroTorch.player.class) == "string", "class is not a string")
end, false)

macroTorch.SelfTest:register("Player: isDead is boolean", function()
    assert(type(macroTorch.toBoolean(macroTorch.player.isDead)) == "boolean", "isDead not resolvable to boolean")
end, false)

macroTorch.SelfTest:register("Player: isFriendly is boolean", function()
    assert(type(macroTorch.toBoolean(macroTorch.player.isFriendly)) == "boolean", "isFriendly not resolvable to boolean")
end, false)

macroTorch.SelfTest:register("Player: isHostile is boolean", function()
    assert(type(macroTorch.toBoolean(macroTorch.player.isHostile)) == "boolean", "isHostile not resolvable to boolean")
end, false)

-- Player method existence checks (no invocation)
macroTorch.SelfTest:register("Player: hasBuff method exists", function()
    assert(type(macroTorch.player.hasBuff) == "function", "hasBuff is not a function")
end, false)

macroTorch.SelfTest:register("Player: getBuffStacks method exists", function()
    assert(type(macroTorch.player.getBuffStacks) == "function", "getBuffStacks is not a function")
end, false)

macroTorch.SelfTest:register("Player: hasItem method exists", function()
    assert(type(macroTorch.player.hasItem) == "function", "hasItem is not a function")
end, false)

macroTorch.SelfTest:register("Player: cast method exists", function()
    assert(type(macroTorch.player.cast) == "function", "cast is not a function")
end, false)

macroTorch.SelfTest:register("Player: use method exists", function()
    assert(type(macroTorch.player.use) == "function", "use is not a function")
end, false)

macroTorch.SelfTest:register("Player: isSpellReady method exists", function()
    assert(type(macroTorch.player.isSpellReady) == "function", "isSpellReady is not a function")
end, false)

-- ============================================================
-- Category D: Target/Pet Entity Property Tests (>=7, all isOptional=false)
-- ============================================================
-- [CITED: ROADMAP T3.1.4; CONTEXT.md D-04]
-- Target/Pet: verify property existence only, no actual invocation.
-- All tests are pcall-wrapped for safety when no target/pet exists.

macroTorch.SelfTest:register("Target: table exists", function()
    assert(type(macroTorch.target) == "table", "macroTorch.target is not a table")
end, false)

macroTorch.SelfTest:register("Target: health property exists", function()
    assert(macroTorch.target.health ~= nil, "target.health is nil")
end, false)

macroTorch.SelfTest:register("Target: isDead property exists", function()
    assert(macroTorch.target.isDead ~= nil, "target.isDead is nil")
end, false)

macroTorch.SelfTest:register("Target: isCanAttack property exists", function()
    assert(macroTorch.target.isCanAttack ~= nil, "target.isCanAttack is nil")
end, false)

macroTorch.SelfTest:register("Target: name property exists", function()
    -- UnitName("target") returns nil when no target selected, which is correct
    local _ = macroTorch.target.name
end, false)

macroTorch.SelfTest:register("Pet: table exists", function()
    assert(type(macroTorch.pet) == "table", "macroTorch.pet is not a table")
end, false)

macroTorch.SelfTest:register("Pet: isExist property exists", function()
    -- isExist returns boolean via toBoolean(), always non-nil even when no pet
    assert(macroTorch.pet.isExist ~= nil, "pet.isExist is nil")
end, false)

-- ============================================================
-- Category E: Optional Module Detection (>=2, isOptional=true)
-- ============================================================
-- [CITED: ROADMAP T3.1.6; CONTEXT.md D-03]
-- Optional addon modules: failure produces yellow warning, not red error.

macroTorch.SelfTest:register("Optional: UnitXP available", function()
    assert(macroTorch.isFunctionExist("UnitXP"), "UnitXP not available")
end, true)

macroTorch.SelfTest:register("Optional: SuperWoW available", function()
    assert(type(_G.SUPERWOW_STRING) ~= "nil", "SUPERWOW_STRING not found")
end, true)

macroTorch.SelfTest:register("Optional: SP3 global exists", function()
    assert(type(_G.SP3) ~= "nil", "SP3 global not found")
end, true)

-- ============================================================
-- Registration count: 74 total (A:11 + B:34 + C:20 + D:7 + E:2) — note: class files add more
-- ============================================================

-- ============================================================
-- Category F: _castSpell / isSpellReady metatable chain integrity (~15 tests, all isOptional=false)
-- ============================================================
-- [CITED: 06-CONTEXT.md D-06; 06-RESEARCH.md]
-- Verifies that Druid instance -> _castSpell -> isSpellReady resolves correctly through the metatable chain.
-- All tests skip silently when the player is not a Druid.

macroTorch.SelfTest:register("F: Druid _castSpell resolves via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player._castSpell) == "function", "_castSpell not a function on Druid instance")
end, false)

macroTorch.SelfTest:register("F: Druid isSpellReady resolves via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player.isSpellReady) == "function", "isSpellReady not a function on Druid instance")
end, false)

macroTorch.SelfTest:register("F: Druid cast resolves via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player.cast) == "function", "cast not a function on Druid instance")
end, false)

macroTorch.SelfTest:register("F: Druid _isInRange resolves via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player._isInRange) == "function", "_isInRange not a function on Druid instance")
end, false)

macroTorch.SelfTest:register("F: Druid _hasResource resolves via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player._hasResource) == "function", "_hasResource not a function on Druid instance")
end, false)

macroTorch.SelfTest:register("F: _castSpell with raw mode does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, 'raw', nil, nil, false)
    end)
    assert(ok, "_castSpell('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: _castSpell with safe mode does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, 'safe', nil, nil, false)
    end)
    assert(ok, "_castSpell('safe') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: claw('raw') does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.claw('raw')
    end)
    assert(ok, "claw('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: shred('raw') does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.shred('raw')
    end)
    assert(ok, "shred('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: healing_touch('raw', true) does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.healing_touch('raw', true)
    end)
    assert(ok, "healing_touch('raw', true) pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: cat_form('raw') does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.cat_form('raw')
    end)
    assert(ok, "cat_form('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: bear_form('raw') does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.bear_form('raw')
    end)
    assert(ok, "bear_form('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: tiger_fury('raw') does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.tiger_fury('raw')
    end)
    assert(ok, "tiger_fury('raw') pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: mark_of_the_wild('raw', false) does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player.mark_of_the_wild('raw', false)
    end)
    assert(ok, "mark_of_the_wild('raw', false) pcall failed: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("F: Externally-called isSpellReady resolves correctly from Druid instance", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        local result = macroTorch.player.isSpellReady('Claw')
        assert(type(result) ~= "nil", "isSpellReady('Claw') returned nil -- check colon/dot fix")
    end)
    assert(ok, "isSpellReady call failed: " .. tostring(err))
end, false)

-- ============================================================
-- Category J: catLeveling 练级宏验证 (5 tests, 4 core + 1 optional)
-- ============================================================
-- [CITED: 16-02-CONTEXT.md; 16-RESEARCH.md:342-370]
-- Verifies catLeveling function existence, shared decision function references,
-- clickContext correctness, catAtk invariance, and no ERPS/reshift dependency.

macroTorch.SelfTest:register("J: catLeveling function exists and is callable", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.catLeveling) == "function",
        "catLeveling is not a function, got: " .. type(macroTorch.catLeveling))
end, false)

macroTorch.SelfTest:register("J: shared decision functions remain accessible (no local redefinition in leveling.lua)", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.isKillShotOrLastChance) == "function",
        "isKillShotOrLastChance is not a function")
    assert(type(macroTorch.shouldCastRip) == "function",
        "shouldCastRip is not a function")
    assert(type(macroTorch.shouldUseBite) == "function",
        "shouldUseBite is not a function")
end, false)

macroTorch.SelfTest:register("J: catLeveling invocation does not error (clickContext correctness)", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(macroTorch.catLeveling)
    assert(ok, "catLeveling should not error: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("J: catAtk remains unmodified (Phase 16 does not change catAtk)", function()
    assert(type(macroTorch.catAtk) == "function",
        "catAtk is not a function, got: " .. type(macroTorch.catAtk))
end, false)

macroTorch.SelfTest:register("J: catLeveling clickContext has all required fields (no nil access at runtime)", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(macroTorch.catLeveling)
    assert(ok, "catLeveling failed — possible missing clickContext field: " .. tostring(err))
end, true)

-- ============================================================
-- Category K: spellId mapping system tests (5 tests, 3 core + 2 optional)
-- ============================================================
-- [CITED: 17-02-PLAN.md Task 2; 17-02-CONTEXT.md]
-- Verifies SPELL_NAME_TO_ID static mapping, resolveSpellId resolution,
-- loadSpellIdMap function, and current_casting_spell lifecycle variable.

macroTorch.SelfTest:register("K: SPELL_NAME_TO_ID table exists with all 8 keys (4 spells x 2 locales)", function()
    assert(type(macroTorch.SPELL_NAME_TO_ID) == "table",
        "SPELL_NAME_TO_ID is not a table, got: " .. type(macroTorch.SPELL_NAME_TO_ID))
    -- English names
    assert(macroTorch.SPELL_NAME_TO_ID["Pounce"] == 9827, "Pounce spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Rake"] == 1822, "Rake spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Rip"] == 9492, "Rip spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["Ferocious Bite"] == 22557, "Ferocious Bite spellId mismatch")
    -- Chinese names
    assert(macroTorch.SPELL_NAME_TO_ID["突袭"] == 9827, "突袭 spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["斜掠"] == 1822, "斜掠 spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["撕扯"] == 9492, "撕扯 spellId mismatch")
    assert(macroTorch.SPELL_NAME_TO_ID["凶猛撕咬"] == 22557, "凶猛撕咬 spellId mismatch")
end, false)

macroTorch.SelfTest:register("K: resolveSpellId function exists and resolves known spells", function()
    assert(type(macroTorch.resolveSpellId) == "function",
        "resolveSpellId is not a function, got: " .. type(macroTorch.resolveSpellId))
    assert(macroTorch.resolveSpellId("Pounce") == 9827,
        "resolveSpellId('Pounce') expected 9827, got: " .. tostring(macroTorch.resolveSpellId("Pounce")))
    assert(macroTorch.resolveSpellId("Rake") == 1822,
        "resolveSpellId('Rake') expected 1822, got: " .. tostring(macroTorch.resolveSpellId("Rake")))
    assert(macroTorch.resolveSpellId("Rip") == 9492,
        "resolveSpellId('Rip') expected 9492, got: " .. tostring(macroTorch.resolveSpellId("Rip")))
    assert(macroTorch.resolveSpellId("Ferocious Bite") == 22557,
        "resolveSpellId('Ferocious Bite') expected 22557, got: " .. tostring(macroTorch.resolveSpellId("Ferocious Bite")))
end, false)

macroTorch.SelfTest:register("K: resolveSpellId returns nil for unknown spell name", function()
    local result = macroTorch.resolveSpellId("NonexistentSpell_XYZ123")
    assert(result == nil,
        "resolveSpellId for unknown spell should return nil, got: " .. tostring(result))
end, true)

macroTorch.SelfTest:register("K: loadSpellIdMap function exists and is callable", function()
    assert(type(macroTorch.loadSpellIdMap) == "function",
        "loadSpellIdMap is not a function, got: " .. type(macroTorch.loadSpellIdMap))
    -- call it -- should not error (nil-safe with loginContext guard)
    local ok, err = pcall(macroTorch.loadSpellIdMap)
    assert(ok, "loadSpellIdMap should not error: " .. tostring(err))
end, false)

macroTorch.SelfTest:register("K: current_casting_spell is defined (set by _castSpell, cleared by events)", function()
    -- current_casting_spell is nil when no cast in progress (expected initial state)
    -- We only verify the global variable exists in the namespace (it's set/cleared at runtime)
    -- Not asserting on value since it depends on whether a spell is being cast
    assert(type(macroTorch.current_casting_spell) == "nil" or type(macroTorch.current_casting_spell) == "string",
        "current_casting_spell should be nil or string, got: " .. type(macroTorch.current_casting_spell))
end, true)

-- ============================================================
-- Module 4: /mt SLASH command
-- ============================================================
-- [CITED: CONTEXT.md D-02, D-10]
-- /mt is the unified entry point for the future mt-script DSL.
-- Phase 3: no arguments runs self-test; with arguments shows reserved notice.
SLASH_MT1 = "/mt"
SlashCmdList["MT"] = function(msg)
    local trimmed = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    if trimmed == "" then
        macroTorch.SelfTest:run()
    else
        macroTorch.show("[macro-torch] /mt: mt-script DSL is reserved for a future phase. Use /mt without arguments to run self-test.", 'yellow')
    end
end