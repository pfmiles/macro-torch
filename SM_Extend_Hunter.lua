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
---猎人专用---
macroTorch.Hunter = macroTorch.Player:new()

function macroTorch.Hunter:new()
    local obj = {}

    -- cast spell by name
    -- @param spellName string spell name
    -- @param onSelf boolean true if cast on self, current target otherwise
    -- function obj.cast(spellName, onSelf)
    --     macroTorch.castSpellByName(spellName, 'spell')
    -- end

    -- impl hint: original '__index' & metatable setting:
    -- self.__index = self
    -- setmetatable(obj, self)

    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.HUNTER_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.HUNTER_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })

    function obj.callPet()
        if macroTorch.pet.isExist then
            macroTorch.player.cast('Dismiss Pet')
        else
            macroTorch.player.cast('Call Pet')
        end
    end

    return obj
end

-- player fields to function mapping
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props
    -- ['comboPoints'] = function(self)
    --     return GetComboPoints()
    -- end,
    -- conditinal props
}

macroTorch.hunter = macroTorch.Hunter:new()

-- tracing certain spells and maintain the landTable
-- macroTorch.setSpellTracingByName('Serpent Sting', 'spell')

-- register druid spells immune tracing
macroTorch.setTraceSpellImmuneByName('Serpent Sting', 'spell')

function macroTorch.hunterAtk()
    local player = macroTorch.player
    local target = macroTorch.target
    local pet = macroTorch.pet
    local clickContext = {}
    clickContext.RAPTOR_E = 32
    clickContext.MONGOOSE_E = 28

    clickContext.ARCANE_E = 35
    clickContext.MULTI_E = 100

    clickContext.prowling = player.buffed('Shadowmeld')

    player.targetEnemy()
    if target.isCanAttack and macroTorch.isFightStarted(clickContext) then
        pet.attack()
        if target.distance < 8 then
            -- melee logic
            player.startAutoAtk()
            macroTorch.safeMongooseBite(clickContext)
            macroTorch.safeRaptorStrike(clickContext)
        else
            -- ranged logic
            if not target.buffed(nil, 'Ability_Hunter_SniperShot') then
                player.cast("Hunter's Mark")
            end
            player.startAutoShoot()
            macroTorch.safeArcaneShot(clickContext)
            macroTorch.safeMultiShot(clickContext)
        end
    end
end

function macroTorch.hunterSting()
    local player = macroTorch.player
    local target = macroTorch.target
    if not target.buffed('Serpent Sting') and not target.isImmune('Serpent Sting') then
        player.cast('Serpent Sting')
    end
end

function macroTorch.hunterCtrl()
    if macroTorch.target.distance < 8 then
        macroTorch.player.cast('Wing Clip')
    else
        macroTorch.player.cast('Concussive Shot')
    end
end

function macroTorch.readyRaptorStrike(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Raptor Strike') then
        player.cast('Raptor Strike')
    end
end

function macroTorch.safeRaptorStrike(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.RAPTOR_E then
        macroTorch.readyRaptorStrike(clickContext)
    end
end

function macroTorch.readyMongooseBite(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Mongoose Bite') then
        player.cast('Mongoose Bite')
    end
end

function macroTorch.safeMongooseBite(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.MONGOOSE_E then
        macroTorch.readyMongooseBite(clickContext)
    end
end

function macroTorch.readyArcaneShot(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Arcane Shot') then
        player.cast('Arcane Shot')
    end
end

function macroTorch.safeArcaneShot(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.ARCANE_E then
        macroTorch.readyArcaneShot(clickContext)
    end
end

function macroTorch.readyMultiShot(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Multi-Shot') then
        player.cast('Multi-Shot')
    end
end

function macroTorch.safeMultiShot(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.MULTI_E then
        macroTorch.readyMultiShot(clickContext)
    end
end
