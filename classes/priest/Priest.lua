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
---牧师专用 start---
macroTorch.Priest = macroTorch.Player:new()

function macroTorch.Priest:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "PRIEST_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.holy_fire(mode)
        return obj._castSpell({ en = 'Holy Fire', zh = '神圣之火' }, mode, 30, nil, false)
    end

    function obj.shadow_word_pain(mode)
        return obj._castSpell({ en = 'Shadow Word: Pain', zh = '暗言术：痛' }, mode, 30, nil, false)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.inner_fire(mode)
        return obj._castSpell({ en = 'Inner Fire', zh = '心灵之火' }, mode, nil, nil, true)
    end

    -- Type C skills: flexible target (onSelf parameter exposed)
    function obj.power_word_fortitude(mode, onSelf)
        return obj._castSpell({ en = 'Power Word: Fortitude', zh = '真言术：韧' }, mode, nil, nil, onSelf)
    end

    function obj.heal(mode, onSelf)
        return obj._castSpell({ en = 'Heal', zh = '治疗术' }, mode, nil, nil, onSelf)
    end

    function obj.lesser_heal(mode, onSelf)
        return obj._castSpell({ en = 'Lesser Heal', zh = '次级治疗术' }, mode, nil, nil, onSelf)
    end

    function obj.renew(mode, onSelf)
        return obj._castSpell({ en = 'Renew', zh = '恢复' }, mode, nil, nil, onSelf)
    end

    return obj
end

-- player fields to function mapping
macroTorch.PRIEST_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditional props (reserved for future class-specific lazy-computed fields)
}

macroTorch.priest = macroTorch.Priest:new()
macroTorch.registerPlayerClass("Priest", macroTorch.Priest)

-- SpellTrace: no Priest spells currently traced

-- Priest class-specific self-test registrations
-- Category: class definition integrity (isOptional=true, UnitClass('player') ~= 'Priest' guard)
macroTorch.SelfTest:register("Priest: PRIEST_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.PRIEST_FIELD_FUNC_MAP) == "table", "PRIEST_FIELD_FUNC_MAP not a table")
end, true)

macroTorch.SelfTest:register("Priest: singleton priest exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest) == "table", "macroTorch.priest not a table")
end, true)

macroTorch.SelfTest:register("Priest: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Priest"] ~= nil, "Priest not in registry")
end, true)

-- Category: skill method existence (isOptional=true, UnitClass('player') ~= 'Priest' guard)
macroTorch.SelfTest:register("Priest: skill method holy_fire exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.holy_fire) == "function", "holy_fire not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method shadow_word_pain exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.shadow_word_pain) == "function", "shadow_word_pain not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method inner_fire exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.inner_fire) == "function", "inner_fire not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method power_word_fortitude exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.power_word_fortitude) == "function", "power_word_fortitude not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method heal exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.heal) == "function", "heal not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method lesser_heal exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.lesser_heal) == "function", "lesser_heal not a function")
end, true)

macroTorch.SelfTest:register("Priest: skill method renew exists", function()
    if UnitClass('player') ~= 'Priest' then return end
    assert(type(macroTorch.priest.renew) == "function", "renew not a function")
end, true)