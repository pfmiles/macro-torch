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
---盗贼专用 start---
macroTorch.Rogue = macroTorch.Player:new()

function macroTorch.Rogue:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "ROGUE_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.pick_pocket(mode)
        return obj._castSpell({ en = 'Pick Pocket', zh = '偷窃' }, mode, nil, nil, false)
    end

    function obj.ghostly_strike(mode)
        return obj._castSpell({ en = 'Ghostly Strike', zh = '鬼魅攻击' }, mode, nil, nil, false)
    end

    function obj.hemorrhage(mode)
        return obj._castSpell({ en = 'Hemorrhage', zh = '出血' }, mode, nil, nil, false)
    end

    function obj.sinister_strike(mode)
        return obj._castSpell({ en = 'Sinister Strike', zh = '邪恶攻击' }, mode, nil, nil, false)
    end

    function obj.backstab(mode)
        return obj._castSpell({ en = 'Backstab', zh = '背刺' }, mode, nil, nil, false)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.vanish(mode)
        return obj._castSpell({ en = 'Vanish', zh = '消失' }, mode, nil, nil, true)
    end

    function obj.preparation(mode)
        return obj._castSpell({ en = 'Preparation', zh = '伺机待发' }, mode, nil, nil, true)
    end

    return obj
end

-- player fields to function mapping
macroTorch.ROGUE_FIELD_FUNC_MAP = {
    ['comboPoints'] = function(self)
        return GetComboPoints() or 0
    end,
}

macroTorch.rogue = macroTorch.Rogue:new()
macroTorch.registerPlayerClass("Rogue", macroTorch.Rogue)

-- SpellTrace: no Rogue spells currently traced

-- Rogue class-specific self-test registrations
-- All tests are optional (isOptional=true) and guard on UnitClass('player') ~= 'Rogue'

-- Infrastructure tests
macroTorch.SelfTest:register("Rogue: ROGUE_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.ROGUE_FIELD_FUNC_MAP) == "table", "ROGUE_FIELD_FUNC_MAP is not a table")
end, true)

macroTorch.SelfTest:register("Rogue: comboPoints field exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.comboPoints) == "number", "comboPoints is not a number")
end, true)

macroTorch.SelfTest:register("Rogue: singleton rogue exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue) == "table", "macroTorch.rogue is not a table")
end, true)

macroTorch.SelfTest:register("Rogue: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Rogue"] ~= nil, "Rogue not in PLAYER_CLASS_REGISTRY")
end, true)

-- Skill method existence tests (7 methods)
macroTorch.SelfTest:register("Rogue: skill method pick_pocket exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.pick_pocket) == "function", "pick_pocket is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method ghostly_strike exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.ghostly_strike) == "function", "ghostly_strike is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method hemorrhage exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.hemorrhage) == "function", "hemorrhage is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method sinister_strike exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.sinister_strike) == "function", "sinister_strike is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method backstab exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.backstab) == "function", "backstab is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method vanish exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.vanish) == "function", "vanish is not a function")
end, true)

macroTorch.SelfTest:register("Rogue: skill method preparation exists", function()
    if UnitClass('player') ~= 'Rogue' then return end
    assert(type(macroTorch.rogue.preparation) == "function", "preparation is not a function")
end, true)

-- Rogue locale table English names are [ASSUMED] and need verification on Turtle WoW English client:
-- Pick Pocket, Ghostly Strike, Hemorrhage, Sinister Strike, Backstab, Vanish, Preparation
-- User should verify these match the actual spell names on an English WoW 1.12.1 client