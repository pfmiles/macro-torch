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
---小德专用start---
--- 近战动作策略
function macroTorch.xdMeleeSeq()
    local t = 'target'
    local p = 'player'
    macroTorch.startAutoAtk()
    if macroTorch.isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
        CastSpellByName('低吼')
        macroTorch.castIfBuffAbsent(t, '挫志咆哮', 'Druid_DemoralizingRoar')
        CastSpellByName('槌击')
    else
        --- 人形态
    end
end

--- 远程动作策略
function macroTorch.xdRangedSeq()
    local t = 'target'
    local p = 'player'
    macroTorch.startAutoAtk()
    if macroTorch.isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
    else
        --- 人形态
        CastSpellByName('愤怒')
    end
end

function macroTorch.xdAtk()
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) then
        if CheckInteractDistance(t, 3) then
            macroTorch.xdMeleeSeq()
        else
            macroTorch.xdRangedSeq()
        end
    else
        TargetNearestEnemy()
        if macroTorch.isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                macroTorch.xdMeleeSeq()
            else
                macroTorch.xdRangedSeq()
            end
        end
    end
end

--- 小德治疗序列
---@param onSelf boolean 是否对自己释放
function macroTorch.xdHealSeq(onSelf)
    local t
    if (onSelf) then
        t = 'player'
    else
        t = 'target'
    end
    if not macroTorch.isBuffOrDebuffPresent(t, 'Nature_ResistNature') then
        CastSpellByName('愈合', onSelf)
    end
    CastSpellByName('治疗之触', onSelf)
end

function macroTorch.xdHeal()
    if macroTorch.isTargetValidFriendly('target') then
        macroTorch.xdHealSeq(false)
    else
        macroTorch.xdHealSeq(true)
    end
end

--- The 'E' key regular dps function for feral cat druid
--- @param startMove boolean the move to be used to start a combat
--- @param regularMove boolean regular move to fight during a combat
function macroTorch.catAtk(startMove, regularMove)
    local p = 'player'
    local t = 'target'
    local player = macroTorch.player
    local prowling = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Ambush')
    -- 1.health & mana saver in combat *
    if player.isInCombat and not prowling then
        macroTorch.useItemIfHealthPercentLessThan(p, 20, 'Healing Potion')
        -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
    end
    -- 2.targetEnemy *
    if not macroTorch.isTargetValidCanAttack(t) then
        ClearTarget()
        TargetNearestEnemy()
    else
        -- 3.keep autoAttack, in combat & not prowling *
        if not prowling then
            player.startAutoAtk()
        end
        -- 4.rushMod, incuding trinckets, berserk and potions *
        if IsShiftKeyDown() then
            UseInventoryItem(14)
            CastSpellByName('Berserk')
        end
        -- 5.starterMod
        if prowling then
            CastSpellByName(startMove)
        end
        -- 6.energy res mod
        if not prowling and macroTorch.getBuffDuration(p, 'Ability_Mount_JungleTiger') < 2 then
            -- TODO 后续需要在刚tick完的1s之内Reshift从而不卡tick回能，也要找到cat状态下区分energy和mana的办法,目前这里的mana在cat形态下其实是energy
            if macroTorch.isBuffOrDebuffPresent(p, 'Ability_Druid_Berserk') then
                if player.mana < 20 then
                    macroTorch.show('Reshift!!!')
                    CastSpellByName('Reshift')
                end
            else
                if player.mana < 30 then
                    macroTorch.show('Reshift!!!')
                    CastSpellByName('Reshift')
                end
            end
        end
        -- 7.termMod
        lazyScript.SlashCommand('termMod')
        -- 8.OT mod
        lazyScript.SlashCommand('otMod')
        -- 9.combatBuffMod - tiger's fury *
        if not macroTorch.isBuffOrDebuffPresent(p, 'Ability_Mount_JungleTiger') and macroTorch.target.isInMediumRange then
            CastSpellByName('Tiger\'s Fury')
        end
        -- 10.debuffMod, including rip, rake and FF
        if player.isInCombat and not prowling then
            lazyScript.SlashCommand('debuffMod')
        end
        -- 11.regular attack tech mod
        if not prowling then
            CastSpellByName(regularMove)
        end
    end
end
