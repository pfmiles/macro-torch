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

-- parent class of all units
macroTorch.Unit = {}
-- constructor
function macroTorch.Unit:new(ref)
    local obj = { ref = ref }
    setmetatable(obj, {
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.UNIT_FIELD_FUNC_MAP[k] then
                return macroTorch.UNIT_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val then
                return class_val
            end
        end
    })
    return obj
end

-- unit fields to function mapping
macroTorch.UNIT_FIELD_FUNC_MAP = {
    -- basic props
    ['health'] = function(self)
        return UnitHealth(self.ref)
    end,
    ['mana'] = function(self)
        return UnitMana(self.ref)
    end,
    ['healthMax'] = function(self)
        return UnitHealthMax(self.ref)
    end,
    ['manaMax'] = function(self)
        return UnitManaMax(self.ref)
    end,
    ['healthLost'] = function(self)
        return UnitHealthMax(self.ref) - UnitHealth(self.ref)
    end,
    ['manaLost'] = function(self)
        return UnitManaMax(self.ref) - UnitMana(self.ref)
    end,
    ['healthPercent'] = function(self)
        return UnitHealth(self.ref) / UnitHealthMax(self.ref) * 100
    end,
    ['manaPercent'] = function(self)
        return UnitMana(self.ref) / UnitManaMax(self.ref) * 100
    end,

    -- conditinal props
    ['isPlayer'] = function(self)
        return macroTorch.toBoolean(UnitIsPlayer(self.ref) or UnitPlayerControlled(self.ref))
    end,
    ['isCanAttack'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(UnitExists(t) and not UnitIsDead(t) and UnitCanAttack('player', t))
    end,
    ['isFriendly'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(UnitExists(t) and not UnitIsDead(t) and UnitCanAssist('player', t))
    end,
    ['isAttackingMe'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(self.isCanAttack and UnitAffectingCombat(t) and
            UnitName("player") == UnitName(t .. "target"))
    end,
    ['isAttackingMyPet'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(self.isCanAttack and UnitAffectingCombat(t) and
            UnitName("pet") == UnitName(t .. "target"))
    end
}
