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
---战士专用---
---远程逻辑
function macroTorch.wroRangedAtk(reapLine)
    macroTorch.startAutoShoot()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    CastSpellByName('Throw')
end

---近战固定前置策略
function macroTorch.meleeCommonTactics(reapLine)
    local t = 'target'
    local p = 'player'

    -- 开始攻击
    macroTorch.startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end

    -- 自动喝药
    macroTorch.useItemIfHealthPercentLessThan(p, 20, 'Healing Potion')
    -- 自动吃糖
    macroTorch.useItemIfHealthPercentLessThan(p, 20, 'Healthstone')

    -- 上自身buff
    macroTorch.wroBuffs()
    -- 给敌方叠debuff
    macroTorch.wroDebuffs()

    -- 当前目标拉住
    if not macroTorch.isTargetAttackingMe() then
        CastSpellByName('Taunt')
    end

    -- 优先用掉复仇
    macroTorch.CastSpellByName('Revenge')
end

---近战单体逻辑
function macroTorch.wroMeleeAtk(reapLine)
    local t = 'target'

    macroTorch.meleeCommonTactics(reapLine)

    -- 挂流血
    if not macroTorch.isBleedingNoEffectTarget(t) then
        macroTorch.castIfBuffAbsent(t, 'Rend', SPELL_TEXTURE_MAP['Rend'])
    end

    -- 在团队中时叠破甲
    local targetIsBoss = UnitClassification(t) == 'worldboss'
    if GetNumPartyMembers() >= 4 and targetIsBoss and macroTorch.getTargetBuffOrDebuffLayers(t, SPELL_TEXTURE_MAP['Sunder Armor']) < 5 then
        CastSpellByName('Sunder Armor')
    else
        CastSpellByName('Shield Slam')
    end

    ---CastSpellByName('Slam')
end

--- aoe逻辑
function macroTorch.wroAoe(reapLine)
    local t = 'target'
    local p = 'player'

    macroTorch.meleeCommonTactics(reapLine)

    macroTorch.castIfBuffAbsent(t, 'Demoralizing Shout', SPELL_TEXTURE_MAP['Demoralizing Shout'])
    macroTorch.castIfBuffAbsent(t, 'Thunder Clap', SPELL_TEXTURE_MAP['Thunder Clap'])

    if not macroTorch.isActionCooledDown('Spell_Nature_ThunderClap') then
        CastSpellByName('Cleave')
    end
end

---buff逻辑
function macroTorch.wroBuffs()
    local p = 'player'
    if UnitMana(p) >= 10 then
        macroTorch.castIfBuffAbsent(p, 'Shield Block', 'Ability_Defend')
    end
    if UnitMana(p) >= 10 then
        macroTorch.castIfBuffAbsent(p, 'Battle Shout', 'Ability_Warrior_BattleShout')
    end
    if UnitAffectingCombat(p) and UnitMana(p) < 10 then
        CastSpellByName('Bloodrage')
    end
end

---debuff逻辑
function macroTorch.wroDebuffs()
    local t = 'target'
end

--- 战士一键输出
---@param pvp boolean whether or not attack player targets
function macroTorch.wroAtk(pvp, reapLine, mainStanceIdx)
    local p = 'player'
    -- 切回主姿态
    if not macroTorch.isStanceActive(mainStanceIdx) then
        CastShapeshiftForm(mainStanceIdx)
    end
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
        -- 如果当前地方目标在近距离
        if CheckInteractDistance(t, 3) then
            macroTorch.wroMeleeAtk(reapLine)
        else
            macroTorch.wroRangedAtk(reapLine)
        end
    else
        -- 如果没有目标，有限支援宠物目标，否则搜寻最近敌人目标
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and macroTorch.isTargetValidCanAttack(pt) and
            (pvp or not macroTorch.isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
            if CheckInteractDistance(t, 3) then
                macroTorch.wroMeleeAtk(reapLine)
            else
                macroTorch.wroRangedAtk(reapLine)
            end
        end
    end
end

--- 临时冲锋
function macroTorch.tmpCharge(pvp)
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) then
        if not pvp and macroTorch.isPlayerOrPlayerControlled(t) then
            return
        end
        if CheckInteractDistance(t, 3) then
            return
        end
        -- 切战斗姿态
        if not macroTorch.isStanceActive(1) then
            CastShapeshiftForm(1)
        end
        CastSpellByName('Charge')
    end
end

--- 战士控制
function macroTorch.wroCtrl(pvp)
    local t = 'target'
    if not pvp and macroTorch.isPlayerOrPlayerControlled(t) then
        return
    end
    local p = 'player'
    if UnitAffectingCombat(p) then
        if not macroTorch.isBuffOrDebuffPresent(t, 'Ability_ShockWave') then
            if macroTorch.isStanceActive(2) and UnitMana(p) < 7 then
                CastSpellByName('Battle Stance')
            end
            CastSpellByName('Hamstring')
        end
    else
        if not macroTorch.isStanceActive(1) and UnitMana(p) < 7 then
            CastSpellByName('Battle Stance')
        end
        CastSpellByName('Charge')
    end
end

function macroTorch.wroInterrupt()
    local p = 'player'
    if macroTorch.isStanceActive(3) and UnitMana(p) < 7 then
        CastSpellByName('Defensive Stance')
    end
    CastSpellByName('Shield Bash')
end

--- 大保命逻辑
function macroTorch.warriorDefence()
    if not macroTorch.isStanceActiveByName('Defensive Stance') then
        CastSpellByName('Defensive Stance')
    end
    if macroTorch.isActionCooledDown(SPELL_TEXTURE_MAP['Disarm']) and UnitMana('player') >= 20 then
        CastSpellByName('Disarm')
    else
        if macroTorch.isActionCooledDown(SPELL_TEXTURE_MAP['Shield Wall']) then
            CastSpellByName('Shield Wall')
        end
    end
    UseInventoryItem(13)
end
