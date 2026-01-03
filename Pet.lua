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

macroTorch.Pet = macroTorch.Unit:new("pet")

function macroTorch.Pet:new()
    local obj = {}

    -- PetAggressiveMode()   - Set your pet in aggressive mode.
    function obj.aggressiveMode()
        PetAggressiveMode()
    end

    -- PetAttack()   - Instruct your pet to attack your target.
    function obj.attack()
        PetAttack()
    end

    -- PetStopAttack()   - Stop the attack of the pet.
    function obj.stopAttack()
        PetStopAttack()
    end

    -- PetDefensiveMode()   - Set your pet in defensive mode.
    function obj.defensiveMode()
        PetDefensiveMode()
    end

    -- PetDismiss()   - Dismiss your pet.
    function obj.dismiss()
        PetDismiss()
    end

    -- PetFollow()   - Instruct your pet to follow you.
    function obj.follow()
        PetFollow()
    end

    -- PetPassiveMode()   - Set your pet into passive mode.
    function obj.passiveMode()
        PetPassiveMode()
    end

    -- PetWait()   - Instruct your pet to remain still.
    function obj.wait()
        PetWait()
    end

    function obj.togglePet()
        if HasPetUI() then
            if UnitIsDead("pet") then
                CastSpellByName("Revive Pet")
            else
                CastSpellByName("Dismiss Pet")
            end
        else
            CastSpellByName("Call Pet")
        end
    end

    function obj.cast(spellName)
        macroTorch.castSpellByName(spellName, 'pet')
    end

    function obj.isSpellCooledDown(spellName)
        return macroTorch.isSpellCooledDown(spellName, 'pet')
    end

    function obj.isAutoCast(spellName)
        local spellId = macroTorch.getSpellIdByName(spellName, 'pet')
        if not spellId then
            return false
        end
        return macroTorch.toBoolean(GetSpellAutocast(spellId, 'pet'))
    end

    function obj.toggleAutoCast(spellName)
        local spellId = macroTorch.getSpellIdByName(spellName, 'pet')
        if not spellId then
            return false
        end
        ToggleSpellAutocast(spellId, 'pet')
    end

    -- impl hint: original '__index' & metatable setting:
    -- self.__index = self
    -- setmetatable(obj, self)
    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.PET_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.PET_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })

    return obj
end

-- pet fields to function mapping
macroTorch.PET_FIELD_FUNC_MAP = {
    -- basic props
    -- ['threatPercent'] = function(self)
    --     local TWT = macroTorch.TWT
    --     local p = 0
    --     if TWT and TWT.threats and TWT.threats[TWT.name] then p = TWT.threats[TWT.name].perc or 0 end
    --     return p
    -- end,
    -- conditinal props
    ['isAttackActive'] = function(self)
        return macroTorch.toBoolean(IsPetAttackActive())
    end,
}

macroTorch.pet = macroTorch.Pet:new()
