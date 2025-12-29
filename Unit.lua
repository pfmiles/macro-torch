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

    -- tell if the unit has the specified spell/item caused buff or debuff
    -- @param spellOrItemName the name of the spell or item
    -- @return true if the unit has the specified buff or debuff, false otherwise
    function obj.hasBuff(spellOrItemName)
        local texture = macroTorch.getSpellOrItemBuffTexture(spellOrItemName)
        for i = 1, 40 do
            if string.find(tostring(UnitDebuff(obj.ref, i)), texture) or string.find(tostring(UnitBuff(obj.ref, i)), texture) then
                return true
            end
        end
        return false
    end

    function obj.buffed(buffName, buffTexture)
        if buffName then
            if buffed(buffName) then
                return true
            end
        end
        if buffTexture then
            return obj.hasBuff(buffTexture)
        end
        return false
    end

    -- get the count of stacks of buff or debuff
    -- @param spellOrItemName the name of the spell or item
    -- @return the count of stacks of buff or debuff
    function obj.getBuffStacks(spellOrItemName)
        local texture = macroTorch.getSpellOrItemBuffTexture(spellOrItemName)
        for i = 1, 40 do
            if string.find(tostring(UnitDebuff(obj.ref, i)), texture) then
                local b, c = UnitDebuff(obj.ref, i)
                if c then
                    return c
                else
                    return 0
                end
            elseif string.find(tostring(UnitBuff(obj.ref, i)), texture) then
                local b, c = UnitBuff(obj.ref, i)
                if c then
                    return c
                else
                    return 0
                end
            end
        end
        return 0
    end

    -- list all buffs texture, for debug only
    function obj.listBuffs()
        for i = 1, 60 do
            local b, blvl, bid, btype = UnitBuff(obj.ref, i)
            if b then
                macroTorch.show('Found Buff: ' ..
                    tostring(b) ..
                    ', level: ' .. tostring(blvl) .. ', id: ' .. tostring(bid) .. ', type: ' .. tostring(btype))
            end
        end
    end

    function obj.listDebuffs()
        for i = 1, 60 do
            local d, dlvl, dtype, did = UnitDebuff(obj.ref, i)
            if d then
                macroTorch.show('Found Debuff: ' ..
                    tostring(d) ..
                    ', level: ' .. tostring(dlvl) .. ', id: ' .. tostring(did) .. ', type: ' .. tostring(dtype))
            end
        end
    end

    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.UNIT_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.UNIT_FIELD_FUNC_MAP[k](t)
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

-- unit fields to function mapping
macroTorch.UNIT_FIELD_FUNC_MAP = {
    -- basic props
    ['guid'] = function(self)
        if SUPERWOW_STRING then
            local a, guid = UnitExists(self.ref)
            return guid
        else
            return nil
        end
    end,
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
    ['distance'] = function(self)
        return UnitXP("distanceBetween", "player", self.ref)
    end,
    -- elemental, undead, etc
    ['type'] = function(self)
        local t = UnitCreatureType(self.ref)
        if not t or string.find(t, "^%s*$") then
            t = 'Unknown'
        end
        return t
    end,
    -- mana, rage, energy, etc
    ['powerType'] = function(self)
        local i, n = UnitPowerType(self.ref)
        return tostring(i) .. "," .. tostring(n)
    end,
    ['name'] = function(self)
        return UnitName(self.ref)
    end,
    ['level'] = function(self)
        return UnitLevel(self.ref)
    end,
    -- Hunter, Mage, Warrior, etc
    ['class'] = function(self)
        return UnitClass(self.ref)
    end,
    -- Human, Troll, etc
    ['race'] = function(self)
        return UnitRace(self.ref)
    end,
    ['sex'] = function(self)
        return UnitSex(self.ref)
    end,
    -- elite, worldboss, etc
    ['classification'] = function(self)
        return UnitClassification(self.ref)
    end,
    -- Crab, Cat, etc
    ['creatureFamily'] = function(self)
        return UnitCreatureFamily(self.ref)
    end,
    -- Beast, Dragon, etc
    ['creatureType'] = function(self)
        return UnitCreatureType(self.ref)
    end,
    -- Alliance or Horde
    ['factionGroup'] = function(self)
        return UnitFactionGroup(self.ref)
    end,

    -- conditinal props
    ['isPlayerControlled'] = function(self)
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
    ['isHostile'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(self.isCanAttack and UnitIsEnemy(t, 'player'))
    end,
    ['isAttackingMe'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(self.isCanAttack and
            UnitName("player") == UnitName(t .. "target"))
    end,
    ['isAttackingMyPet'] = function(self)
        local t = self.ref
        return macroTorch.toBoolean(self.isCanAttack and
            UnitName("pet") == UnitName(t .. "target"))
    end,
    ['isNearBy'] = function(self)
        return macroTorch.toBoolean(CheckInteractDistance(self.ref, 3))
    end,
    ['isInMediumRange'] = function(self)
        return macroTorch.toBoolean(CheckInteractDistance(self.ref, 2))
    end,
    ['isInLongRange'] = function(self)
        return macroTorch.toBoolean(CheckInteractDistance(self.ref, 4))
    end,
    ['isDead'] = function(self)
        return macroTorch.toBoolean(UnitIsDead(self.ref))
    end,
    ['isExist'] = function(self)
        return macroTorch.toBoolean(UnitExists(self.ref))
    end,
    ['isInCombat'] = function(self)
        return macroTorch.toBoolean(UnitAffectingCombat(self.ref))
    end,
    ['isInRaid'] = function(self)
        return macroTorch.toBoolean(UnitInRaid(self.ref))
    end,
}
