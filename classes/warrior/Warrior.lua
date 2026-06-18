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
---战士专用 start---
macroTorch.Warrior = macroTorch.Player:new()

function macroTorch.Warrior:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "WARRIOR_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.throw(mode, rank)
        return obj._castSpell({ en = 'Throw', zh = '投掷' }, mode, nil, nil, false, rank)
    end

    function obj.taunt(mode, rank)
        return obj._castSpell({ en = 'Taunt', zh = '嘲讽' }, mode, nil, nil, false, rank)
    end

    function obj.revenge(mode, rank)
        return obj._castSpell({ en = 'Revenge', zh = '复仇' }, mode, nil, nil, false, rank)
    end

    function obj.rend(mode, rank)
        return obj._castSpell({ en = 'Rend', zh = '撕裂' }, mode, nil, nil, false, rank)
    end

    function obj.sunder_armor(mode, rank)
        return obj._castSpell({ en = 'Sunder Armor', zh = '破甲攻击' }, mode, nil, nil, false, rank)
    end

    function obj.shield_slam(mode, rank)
        return obj._castSpell({ en = 'Shield Slam', zh = '盾牌猛击' }, mode, nil, nil, false, rank)
    end

    function obj.demoralizing_shout(mode, rank)
        return obj._castSpell({ en = 'Demoralizing Shout', zh = '挫志怒吼' }, mode, nil, nil, false, rank)
    end

    function obj.thunder_clap(mode, rank)
        return obj._castSpell({ en = 'Thunder Clap', zh = '雷霆一击' }, mode, nil, nil, false, rank)
    end

    function obj.cleave(mode, rank)
        return obj._castSpell({ en = 'Cleave', zh = '顺劈斩' }, mode, nil, nil, false, rank)
    end

    function obj.hamstring(mode, rank)
        return obj._castSpell({ en = 'Hamstring', zh = '断筋' }, mode, nil, nil, false, rank)
    end

    function obj.shield_bash(mode, rank)
        return obj._castSpell({ en = 'Shield Bash', zh = '盾击' }, mode, nil, nil, false, rank)
    end

    function obj.disarm(mode, rank)
        return obj._castSpell({ en = 'Disarm', zh = '缴械' }, mode, nil, nil, false, rank)
    end

    function obj.charge(mode, rank)
        return obj._castSpell({ en = 'Charge', zh = '冲锋' }, mode, 25, nil, false, rank)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.shield_block(mode, rank)
        return obj._castSpell({ en = 'Shield Block', zh = '盾牌格挡' }, mode, nil, nil, true, rank)
    end

    function obj.battle_shout(mode, rank)
        return obj._castSpell({ en = 'Battle Shout', zh = '战斗怒吼' }, mode, nil, nil, true, rank)
    end

    function obj.bloodrage(mode, rank)
        return obj._castSpell({ en = 'Bloodrage', zh = '血性狂暴' }, mode, nil, nil, true, rank)
    end

    function obj.shield_wall(mode, rank)
        return obj._castSpell({ en = 'Shield Wall', zh = '盾墙' }, mode, nil, nil, true, rank)
    end

    return obj
end

-- player fields to function mapping
macroTorch.WARRIOR_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditinal props (reserved for future class-specific lazy-computed fields)
}

macroTorch.warrior = macroTorch.Warrior:new()
macroTorch.registerPlayerClass("Warrior", macroTorch.Warrior)

-- SpellTrace: no Warrior spells currently traced
-- (Warrior spells use castIfBuffAbsent pattern for Rend/Demoralizing Shout/Thunder Clap — immune tracing not implemented yet)

-- Warrior class-specific self-test registrations
-- All tests are optional (isOptional=true) and guard on UnitClass('player') ~= 'Warrior'

-- Infrastructure tests
macroTorch.SelfTest:register("Warrior: WARRIOR_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.WARRIOR_FIELD_FUNC_MAP) == "table", "WARRIOR_FIELD_FUNC_MAP is not a table")
end, true)

macroTorch.SelfTest:register("Warrior: singleton warrior exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior) == "table", "macroTorch.warrior is not a table")
end, true)

macroTorch.SelfTest:register("Warrior: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Warrior"] ~= nil, "Warrior not in PLAYER_CLASS_REGISTRY")
end, true)

-- Skill method existence tests (17 methods)
macroTorch.SelfTest:register("Warrior: skill method throw exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.throw) == "function", "throw is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method taunt exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.taunt) == "function", "taunt is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method revenge exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.revenge) == "function", "revenge is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method rend exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.rend) == "function", "rend is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method sunder_armor exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.sunder_armor) == "function", "sunder_armor is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method shield_slam exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.shield_slam) == "function", "shield_slam is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method demoralizing_shout exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.demoralizing_shout) == "function", "demoralizing_shout is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method thunder_clap exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.thunder_clap) == "function", "thunder_clap is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method cleave exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.cleave) == "function", "cleave is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method hamstring exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.hamstring) == "function", "hamstring is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method shield_bash exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.shield_bash) == "function", "shield_bash is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method disarm exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.disarm) == "function", "disarm is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method charge exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.charge) == "function", "charge is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method shield_block exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.shield_block) == "function", "shield_block is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method battle_shout exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.battle_shout) == "function", "battle_shout is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method bloodrage exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.bloodrage) == "function", "bloodrage is not a function")
end, true)

macroTorch.SelfTest:register("Warrior: skill method shield_wall exists", function()
    if UnitClass('player') ~= 'Warrior' then return end
    assert(type(macroTorch.warrior.shield_wall) == "function", "shield_wall is not a function")
end, true)