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
---牧师专用---
---远程逻辑
function priestRangedAtk()
    startAutoShoot()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    if isActionCooledDown('Spell_Shadow_UnholyFrenzy') and UnitMana('player') >= 80 and getUnitHealthPercent('target') > 10 and GetNumPartyMembers() == 0 then
        stopAutoShoot()
        CastSpellByName('Mind Blast')
        -- else
        --     if isActionCooledDown('Spell_Arcane_StarFire') then
        --         CastSpellByName('Starshards')
        --     end
    end
end

---buff逻辑
function priestBuffs()
    local p = 'player'
    local t = 'target'
    if not isTargetValidFriendly(t) then
        t = p
    end
    castIfBuffAbsent(t, 'Power Word: Fortitude', 'Spell_Holy_WordFortitude')
    castIfBuffAbsent(p, 'Inner Fire', 'Spell_Holy_InnerFire')
end

---debuff逻辑
function priestDebuffs()
    local t = 'target'
    local p = 'player'
    if getUnitHealthPercent(t) > 10 and GetNumPartyMembers() == 0 then
        castIfBuffAbsent(t, 'Shadow Word: Pain', 'Spell_Shadow_ShadowWordPain')
    end
    useItemIfManaPercentLessThan(p, 10, 'Mana Potion')
    useItemIfHealthPercentLessThan(p, 20, 'Health Potion')
end

--- 牧师一键输出
---@param pvp boolean whether or not attack player targets
function priestAtk(pvp)
    priestBuffs()
    local t = 'target'
    if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
        if UnitAffectingCombat(t) then
            priestDebuffs()
        end
        if CheckInteractDistance(t, 3) then
            priestRangedAtk()
        else
            priestRangedAtk()
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) and
            (pvp or not isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
            if UnitAffectingCombat(t) then
                priestDebuffs()
            end
            if CheckInteractDistance(t, 3) then
                priestRangedAtk()
            else
                priestRangedAtk()
            end
        end
    end
end

--- 牧师控制
function priestCtrl(pvp)
end

--- 牧师治疗
function priestHeal()
    local p = 'player'
    local t = 'target'
    if not isTargetValidFriendly(t) then
        t = p
    end
    if getUnitHealthLost(t) > 300 then
        CastSpellByName('Heal')
    elseif getUnitHealthLost(t) > 140 then
        CastSpellByName('Lesser Heal')
    else
        castIfBuffAbsent(t, 'Renew', 'Spell_Holy_Renew')
    end
end
