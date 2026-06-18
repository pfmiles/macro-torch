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
---法师专用 start---
macroTorch.Mage = macroTorch.Player:new()

function macroTorch.Mage:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "MAGE_FIELD_FUNC_MAP"))

    -- Type A: enemy target only (onSelf=false)
    function obj.frostbolt(mode, rank)
        return obj._castSpell({ en = 'Frostbolt', zh = '寒冰箭' }, mode, 30, nil, false, rank)
    end

    -- Type B: self target only (onSelf=true)
    function obj.frost_armor(mode, rank)
        return obj._castSpell({ en = 'Frost Armor', zh = '冰甲术' }, mode, nil, nil, true, rank)
    end

    -- Type C: flexible target (used by castIfBuffAbsent on friendly or self)
    function obj.arcane_intellect(mode, onSelf, rank)
        return obj._castSpell({ en = 'Arcane Intellect', zh = '奥术智慧' }, mode, nil, nil, onSelf, rank)
    end

    return obj
end

-- player fields to function mapping
macroTorch.MAGE_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditinal props (reserved for future class-specific lazy-computed fields)
}

macroTorch.mage = macroTorch.Mage:new()
macroTorch.registerPlayerClass("Mage", macroTorch.Mage)

-- SpellTrace: no Mage spells currently traced

-- Mage class-specific self-test registrations
-- All tests are optional (isOptional=true) and guard on UnitClass('player') ~= 'Mage'

-- Infrastructure tests
macroTorch.SelfTest:register("Mage: MAGE_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(type(macroTorch.MAGE_FIELD_FUNC_MAP) == "table", "MAGE_FIELD_FUNC_MAP is not a table")
end, true)

macroTorch.SelfTest:register("Mage: singleton mage exists", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(type(macroTorch.mage) == "table", "macroTorch.mage is not a table")
end, true)

macroTorch.SelfTest:register("Mage: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Mage"] ~= nil, "Mage not in PLAYER_CLASS_REGISTRY")
end, true)

-- Skill method existence tests (3 methods)
macroTorch.SelfTest:register("Mage: skill method frostbolt exists", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(type(macroTorch.mage.frostbolt) == "function", "frostbolt is not a function")
end, true)

macroTorch.SelfTest:register("Mage: skill method frost_armor exists", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(type(macroTorch.mage.frost_armor) == "function", "frost_armor is not a function")
end, true)

macroTorch.SelfTest:register("Mage: skill method arcane_intellect exists", function()
    if UnitClass('player') ~= 'Mage' then return end
    assert(type(macroTorch.mage.arcane_intellect) == "function", "arcane_intellect is not a function")
end, true)