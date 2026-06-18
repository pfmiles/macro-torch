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
macroTorch.Hunter = macroTorch.Player:new()

function macroTorch.Hunter:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.raptor_strike(mode)
        return obj._castSpell({ en = 'Raptor Strike', zh = '猛禽一击' }, mode, nil, nil, false)
    end

    function obj.mongoose_bite(mode)
        return obj._castSpell({ en = 'Mongoose Bite', zh = '猫鼬撕咬' }, mode, nil, nil, false)
    end

    function obj.arcane_shot(mode)
        return obj._castSpell({ en = 'Arcane Shot', zh = '奥术射击' }, mode, nil, nil, false)
    end

    function obj.multi_shot(mode)
        return obj._castSpell({ en = 'Multi-Shot', zh = '多重射击' }, mode, nil, nil, false)
    end

    function obj.hunters_mark(mode)
        return obj._castSpell({ en = "Hunter's Mark", zh = '猎人印记' }, mode, nil, nil, false)
    end

    function obj.serpent_sting(mode)
        return obj._castSpell({ en = 'Serpent Sting', zh = '毒蛇钉刺' }, mode, nil, nil, false)
    end

    function obj.wing_clip(mode)
        return obj._castSpell({ en = 'Wing Clip', zh = '摔绊' }, mode, nil, nil, false)
    end

    function obj.concussive_shot(mode)
        return obj._castSpell({ en = 'Concussive Shot', zh = '震荡射击' }, mode, nil, nil, false)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.disengage(mode)
        return obj._castSpell({ en = 'Disengage', zh = '逃脱' }, mode, nil, nil, true)
    end

    -- Type B with conditional logic: Call Pet or Dismiss Pet based on pet existence
    function obj.call_pet(mode)
        if macroTorch.pet and macroTorch.pet.isExist then
            return obj._castSpell({ en = 'Dismiss Pet', zh = '解散宠物' }, mode, nil, nil, true)
        else
            return obj._castSpell({ en = 'Call Pet', zh = '召唤宠物' }, mode, nil, nil, true)
        end
    end

    return obj
end

-- player fields to function mapping
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditinal props (reserved for future class-specific lazy-computed fields)
}

macroTorch.hunter = macroTorch.Hunter:new()
macroTorch.registerPlayerClass("Hunter", macroTorch.Hunter)

-- tracing spell trace/immune via declarative SpellTrace:register() API
macroTorch.SpellTrace:register('Serpent Sting', {
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})

-- Hunter class-specific self-test registrations
-- All tests are optional (isOptional=true) and guard on UnitClass('player') ~= 'Hunter'

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

-- Skill method existence tests (11 methods)
macroTorch.SelfTest:register("Hunter: skill method raptor_strike exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.raptor_strike) == "function", "raptor_strike is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method mongoose_bite exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.mongoose_bite) == "function", "mongoose_bite is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method arcane_shot exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.arcane_shot) == "function", "arcane_shot is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method multi_shot exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.multi_shot) == "function", "multi_shot is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method hunters_mark exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.hunters_mark) == "function", "hunters_mark is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method serpent_sting exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.serpent_sting) == "function", "serpent_sting is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method wing_clip exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.wing_clip) == "function", "wing_clip is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method concussive_shot exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.concussive_shot) == "function", "concussive_shot is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method disengage exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.disengage) == "function", "disengage is not a function")
end, true)

macroTorch.SelfTest:register("Hunter: skill method call_pet exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.call_pet) == "function", "call_pet is not a function")
end, true)