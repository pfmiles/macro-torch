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
    local berserk = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Druid_Berserk')
    local comboPoints = GetComboPoints()
    local ooc = macroTorch.isBuffOrDebuffPresent(p, 'Spell_Shadow_ManaBurn')
    local isBehind = macroTorch.isTargetValidCanAttack(t) and UnitXP('behind', 'player', 'target') or false

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
            if not berserk then
                CastSpellByName('Berserk')
            end
            UseInventoryItem(14)
        end
        -- 5.starterMod
        if prowling then
            CastSpellByName(startMove)
        end
        -- 6.termMod: term on rip or killshot
        macroTorch.termMod(comboPoints, player)
        -- 7.OT mod
        lazyScript.SlashCommand('otMod')
        -- 8.energy res mod
        if not prowling and not berserk and macroTorch.tigerLeft() < 3.5 then
            macroTorch.energyReshift(player, ooc, isBehind, comboPoints)
        end
        -- 9.combatBuffMod - tiger's fury *
        if macroTorch.target.isInMediumRange then
            macroTorch.keepTigerFury(player)
        end
        -- 10.debuffMod, including rip, rake and FF
        if player.isInCombat and not prowling then
            macroTorch.keepRip(comboPoints, player)
            macroTorch.keepRake(player)
            macroTorch.keepFF(ooc, player)
        end
        -- 11.oocMod
        if not prowling and ooc and isBehind and comboPoints < 5 then
            CastSpellByName('Shred')
        end
        -- 12.regular attack tech mod
        if not prowling and comboPoints < 5 and macroTorch.isRakePresent() and SpellReady('Claw') and player.mana >= 40 then
            CastSpellByName('Claw')
        end
    end
end

function macroTorch.termMod(comboPoints, player)
    if macroTorch.biteKillshot(comboPoints, player) then
        return
    else
        macroTorch.cp5Bite(comboPoints, player)
    end
end

function macroTorch.cp5Bite(comboPoints, player)
    if comboPoints == 5 and SpellReady('Ferocious Bite') and player.mana >= 35 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        CastSpellByName('Ferocious Bite')
        if macroTorch.isRipPresent() then
            macroTorch.ripTimer = GetTime()
        end
        if macroTorch.isRakePresent() then
            macroTorch.rakeTimer = GetTime()
        end
    end
end

function macroTorch.biteKillshot(comboPoints, player)
    local targetHealth = macroTorch.target.health
    if player.mana >= 35 and SpellReady('Ferocious Bite') and
        (comboPoints == 1 and targetHealth < 1446 or
            comboPoints == 2 and targetHealth < 1700 or
            comboPoints == 3 and targetHealth < 1960 or
            comboPoints == 4 and targetHealth < 2214 or
            comboPoints == 5 and targetHealth < 2470) then
        CastSpellByName('Ferocious Bite')
        -- refresh rip & rake timer if they present
        if macroTorch.isRipPresent() then
            macroTorch.ripTimer = GetTime()
        end
        if macroTorch.isRakePresent() then
            macroTorch.rakeTimer = GetTime()
        end
        return true
    else
        return false
    end
end

function macroTorch.energyReshift(player, ooc, isBehind, comboPoints)
    -- clean all energy before reshift
    macroTorch.cleanBeforeReshift(ooc, isBehind, player, comboPoints)
    -- the player.mana here actually means energy
    if player.mana < 23 and macroTorch.tigerLeft() < 1.5 then
        CastSpellByName('Reshift')
        macroTorch.show('Reshift!!! energy = ' .. player.mana .. ', tigerLeft = ' .. macroTorch.tigerLeft())
    end
end

function macroTorch.cleanBeforeReshift(ooc, isBehind, player, comboPoints)
    if ooc then
        if isBehind then
            CastSpellByName('Shred')
        else
            CastSpellByName('Claw')
        end
    end
    macroTorch.keepRake(player)
    macroTorch.termMod(comboPoints, player)
    if isBehind and player.mana >= 48 then
        CastSpellByName('Shred')
    end
    if player.mana >= 40 then
        CastSpellByName('Claw')
    end
end

function macroTorch.keepTigerFury(player)
    if macroTorch.isTigerPresent() then
        return
    end

    if SpellReady('Tiger\'s Fury') and player.mana >= 30 then
        CastSpellByName('Tiger\'s Fury')
        macroTorch.tigerTimer = GetTime()
    end
end

function macroTorch.keepRip(comboPoints, player)
    if macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.isImmune('Rip') then
        return
    end

    if SpellReady('Rip') and player.mana >= 30 then
        CastSpellByName('Rip')
        macroTorch.ripTimer = GetTime()
    end
end

function macroTorch.keepRake(player)
    if macroTorch.isRakePresent() or macroTorch.isImmune('Rake') then
        return
    end

    if SpellReady('Rake') and player.mana >= 35 then
        CastSpellByName('Rake')
        macroTorch.rakeTimer = GetTime()
    end
end

function macroTorch.keepFF(ooc, player)
    if (macroTorch.isFFPresent() and macroTorch.ffLeft() > 0.2) or ooc or player.mana > 23 or macroTorch.isImmune('Faerie Fire (Feral)') then
        return
    end
    if SpellReady('Faerie Fire (Feral)') then
        CastSpellByName('Faerie Fire (Feral)')
        macroTorch.ffTimer = GetTime()
    end
end

function macroTorch.isTigerPresent()
    return buffed('Tiger\'s Fury') and macroTorch.tigerLeft() > 0
end

function macroTorch.tigerLeft()
    local tigerLeft = 0
    if not not macroTorch.tigerTimer then
        tigerLeft = 18 - (GetTime() - macroTorch.tigerTimer)
        if tigerLeft < 0 then
            tigerLeft = 0
        end
    else
        tigerLeft = 0
    end
    return tigerLeft
end

function macroTorch.isRipPresent()
    return buffed('Rip', 'target') and macroTorch.ripLeft() > 0
end

function macroTorch.ripLeft()
    local ripLeft = 0
    if not not macroTorch.ripTimer then
        ripLeft = 18 - (GetTime() - macroTorch.ripTimer)
        if ripLeft < 0 then
            ripLeft = 0
        end
    else
        ripLeft = 0
    end
    return ripLeft
end

function macroTorch.isRakePresent()
    return buffed('Rake', 'target') and macroTorch.rakeLeft() > 0
end

function macroTorch.rakeLeft()
    local rakeLeft = 0
    if not not macroTorch.rakeTimer then
        rakeLeft = 9 - (GetTime() - macroTorch.rakeTimer)
        if rakeLeft < 0 then
            rakeLeft = 0
        end
    else
        rakeLeft = 0
    end
    return rakeLeft
end

function macroTorch.isFFPresent()
    return buffed('Faerie Fire (Feral)', 'target') and macroTorch.ffLeft() > 0
end

function macroTorch.ffLeft()
    local ffLeft = 0
    if not not macroTorch.ffTimer then
        ffLeft = 40 - (GetTime() - macroTorch.ffTimer)
        if ffLeft < 0 then
            ffLeft = 0
        end
    else
        ffLeft = 0
    end
    return ffLeft
end
