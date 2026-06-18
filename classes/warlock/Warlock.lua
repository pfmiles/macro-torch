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
---术士专用 start---
macroTorch.Warlock = macroTorch.Player:new()

function macroTorch.Warlock:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "WARLOCK_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.immolate(mode)
        return obj._castSpell({ en = 'Immolate', zh = '献祭' }, mode, 30, nil, false)
    end

    function obj.corruption(mode)
        return obj._castSpell({ en = 'Corruption', zh = '腐蚀术' }, mode, 30, nil, false)
    end

    function obj.curse_of_agony(mode)
        return obj._castSpell({ en = 'Curse of Agony', zh = '痛苦诅咒' }, mode, 30, nil, false)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.demon_skin(mode)
        return obj._castSpell({ en = 'Demon Skin', zh = '恶魔皮肤' }, mode, nil, nil, true)
    end

    return obj
end

-- player fields to function mapping
macroTorch.WARLOCK_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditional props (reserved for future class-specific lazy-computed fields)
}

macroTorch.warlock = macroTorch.Warlock:new()
macroTorch.registerPlayerClass("Warlock", macroTorch.Warlock)

-- SpellTrace: no Warlock spells currently traced

-- Warlock class-specific self-test registrations
-- Category: class definition integrity (isOptional=true, UnitClass('player') ~= 'Warlock' guard)
macroTorch.SelfTest:register("Warlock: WARLOCK_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.WARLOCK_FIELD_FUNC_MAP) == "table", "WARLOCK_FIELD_FUNC_MAP not a table")
end, true)

macroTorch.SelfTest:register("Warlock: singleton warlock exists", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.warlock) == "table", "macroTorch.warlock not a table")
end, true)

macroTorch.SelfTest:register("Warlock: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Warlock"] ~= nil, "Warlock not in registry")
end, true)

-- Category: skill method existence (isOptional=true, UnitClass('player') ~= 'Warlock' guard)
macroTorch.SelfTest:register("Warlock: skill method immolate exists", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.warlock.immolate) == "function", "immolate not a function")
end, true)

macroTorch.SelfTest:register("Warlock: skill method corruption exists", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.warlock.corruption) == "function", "corruption not a function")
end, true)

macroTorch.SelfTest:register("Warlock: skill method curse_of_agony exists", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.warlock.curse_of_agony) == "function", "curse_of_agony not a function")
end, true)

macroTorch.SelfTest:register("Warlock: skill method demon_skin exists", function()
    if UnitClass('player') ~= 'Warlock' then return end
    assert(type(macroTorch.warlock.demon_skin) == "function", "demon_skin not a function")
end, true)