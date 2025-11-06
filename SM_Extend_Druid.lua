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

--- The 'E' key regular dps function for feral cat druid
--- if rough, then no back attacks
function macroTorch.catAtk(rough)
    local p = 'player'
    local t = 'target'
    macroTorch.POUNCE_E = 50
    macroTorch.CLAW_E = 37
    macroTorch.SHRED_E = 54
    macroTorch.RAKE_E = 32
    macroTorch.BITE_E = 35
    macroTorch.RIP_E = 30
    macroTorch.TIGER_E = 30

    macroTorch.TIGER_DURATION = 18
    macroTorch.RIP_DURATION = 18
    macroTorch.RAKE_DURATION = 9
    macroTorch.FF_DURATION = 40
    macroTorch.POUNCE_DURATION = 18

    macroTorch.AUTO_TICK_ERPS = 20 / 2
    macroTorch.TIGER_ERPS = 10 / 3
    macroTorch.RAKE_ERPS = 5 / 3
    macroTorch.RIP_ERPS = 5 / 2
    macroTorch.POUNCE_ERPS = 5 / 3
    macroTorch.BERSERK_ERPS = 20 / 2

    macroTorch.COWER_THREAT_THRESHOLD = 80
    macroTorch.RESHIFT_ENERGY = 60
    macroTorch.RESHIFT_E_DIFF_THRESHOLD = 2.5
    macroTorch.BURST_ITEM_LOC = 14
    macroTorch.PLAYER_URGENT_HP_THRESHOLD = 10

    local player = macroTorch.player
    local prowling = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Ambush')
    local berserk = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Druid_Berserk')
    local comboPoints = GetComboPoints()
    local ooc = macroTorch.isBuffOrDebuffPresent(p, 'Spell_Shadow_ManaBurn')
    local isBehind = macroTorch.isTargetValidCanAttack(t) and UnitXP('behind', 'player', 'target') or false

    -- 1.health & mana saver in combat *
    if macroTorch.isFightStarted(prowling) then
        macroTorch.combatUrgentHPRestore()
        -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
    end
    -- 2.targetEnemy *
    if not macroTorch.target.isCanAttack then
        macroTorch.targetEnemyMod()
    else
        -- maintain THV
        macroTorch.maintainTHV()
        -- 3.keep autoAttack, in combat & not prowling *
        if macroTorch.isFightStarted(prowling) then
            player.startAutoAtk()
        end
        -- 4.rushMod, incuding trinckets, berserk and potions *
        if IsShiftKeyDown() then
            if not berserk then
                CastSpellByName('Berserk')
            end
            macroTorch.atkPowerBurst()
        end
        -- roughly bear form logic branch
        if macroTorch.player.isFormActive('Dire Bear Form') then
            macroTorch.bearAtk()
            return
        end
        -- 5.starterMod
        if prowling then
            if not rough then
                if not macroTorch.isImmune('Pounce') then
                    -- macroTorch.show('Pounce immune: ' .. tostring(macroTorch.isImmune('Pounce')) .. ', do safePounce!')
                    macroTorch.safePounce()
                else
                    macroTorch.show('Pounce immune: ' .. tostring(macroTorch.isImmune('Pounce')) .. ', do Ravage!')
                    CastSpellByName('Ravage')
                end
            else
                macroTorch.safeClaw()
            end
        end
        -- 7.oocMod
        if (not prowling or macroTorch.target.isAttackingMe) and ooc then
            macroTorch.tryBiteKillshot(comboPoints)
            macroTorch.cp5ReadyBite(comboPoints)
            -- no shred/claw at cp5 when ooc
            if comboPoints < 5 then
                if isBehind and not player.isBehindAttackJustFailed and not rough then
                    macroTorch.readyShred()
                else
                    macroTorch.readyClaw()
                end
            end
        end
        -- 6.termMod: term on rip or killshot
        macroTorch.termMod(comboPoints)
        -- 8.OT mod
        macroTorch.otMod(player, prowling, ooc, berserk, comboPoints)
        -- 9.combatBuffMod - tiger's fury *
        macroTorch.keepTigerFury()
        -- 10.debuffMod, including rip, rake and FF
        if macroTorch.isTrivialBattleOrPvp() then
            -- no need to do deep rip when pvp
            macroTorch.quickKeepRip(comboPoints, prowling)
        else
            macroTorch.keepRip(comboPoints, prowling)
        end
        macroTorch.keepRake(comboPoints, prowling)
        macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
        -- 11.regular attack tech mod
        if macroTorch.isFightStarted(prowling) and comboPoints < 5 and (macroTorch.isRakePresent() or macroTorch.isImmune('Rake')) then
            macroTorch.safeClaw()
        end
        -- 12.energy res mod
        macroTorch.reshiftMod(player, prowling, ooc, berserk)
    end
end

function macroTorch.isTrivialBattleOrPvp()
    local player = macroTorch.player
    local target = macroTorch.target
    return target.isPlayerControlled or
        (
        -- if the target's max health is less than we attack 15s with 500dps each person
            (player.isInRaid or player.isInGroup) and (target.healthMax <= (macroTorch.mateNearMyTargetCount() + 1) * 500 * 15)
        )
end

function macroTorch.combatUrgentHPRestore()
    local p = 'player'
    if macroTorch.isItemCooledDown('Healthstone') then
        macroTorch.useItemIfHealthPercentLessThan(p, macroTorch.PLAYER_URGENT_HP_THRESHOLD, 'Healthstone')
    elseif macroTorch.isItemCooledDown('Healing Potion') then
        macroTorch.useItemIfHealthPercentLessThan(p, macroTorch.PLAYER_URGENT_HP_THRESHOLD, 'Healing Potion')
    end
end

-- whether the fight has started, considering prowling
function macroTorch.isFightStarted(prowling)
    return (not prowling and
            (macroTorch.player.isInCombat
                or macroTorch.inCombat
                or macroTorch.target.isPlayerControlled
                or (macroTorch.target.isHostile and macroTorch.target.isNearBy)
            ))
        or (prowling and macroTorch.target.isAttackingMe)
end

function macroTorch.otMod(player, prowling, ooc, berserk, comboPoints)
    local target = macroTorch.target
    if macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not player.isInCombat
        or not target.isInCombat
        or prowling
        or macroTorch.isKillshotOrLastChance(comboPoints)
        or not target.isCanAttack
        or target.isPlayerControlled
        or not macroTorch.player.isInGroup then
        return
    end
    if (target.isAttackingMe or macroTorch.playerThreatPercent() > 97) and not SpellReady('Cower') and target.classification == 'worldboss' then
        player.use('Invulnerability Potion', true)
    end
    if (target.isAttackingMe or (target.classification == 'worldboss' and macroTorch.playerThreatPercent() >= macroTorch.COWER_THREAT_THRESHOLD)) and target.distance < 15 then
        macroTorch.readyCower()
    end
end

function macroTorch.targetEnemyMod()
    if macroTorch.target.isFriendly and macroTorch.targettarget.isCanAttack then
        AssistUnit('target')
    else
        ClearTarget()
        TargetNearestEnemy()
    end
end

function macroTorch.termMod(comboPoints)
    macroTorch.tryBiteKillshot(comboPoints)
    macroTorch.cp5Bite(comboPoints)
end

function macroTorch.cp5Bite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.safeBite()
    end
end

-- for ooc only
function macroTorch.cp5ReadyBite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.readyBite()
    end
end

macroTorch.KS_CP1_Health = 750
macroTorch.KS_CP2_Health = 1000
macroTorch.KS_CP3_Health = 1250
macroTorch.KS_CP4_Health = 1500
macroTorch.KS_CP5_Health = 1750

macroTorch.KS_CP1_Health_group = 1500
macroTorch.KS_CP2_Health_group = 1850
macroTorch.KS_CP3_Health_group = 2250
macroTorch.KS_CP4_Health_group = 2650
macroTorch.KS_CP5_Health_group = 3000

macroTorch.KS_CP1_Health_raid_pps = macroTorch.KS_CP1_Health_group / 5
macroTorch.KS_CP2_Health_raid_pps = macroTorch.KS_CP2_Health_group / 5
macroTorch.KS_CP3_Health_raid_pps = macroTorch.KS_CP3_Health_group / 5
macroTorch.KS_CP4_Health_raid_pps = macroTorch.KS_CP4_Health_group / 5
macroTorch.KS_CP5_Health_raid_pps = macroTorch.KS_CP5_Health_group / 5

-- maintain the target health vector
function macroTorch.maintainTHV()
    if macroTorch.context then
        local target = macroTorch.target
        if not macroTorch.context.targetHealthVector then
            macroTorch.context.targetHealthVector = {}
        end
        if target.isCanAttack and target.isInCombat then
            table.insert(macroTorch.context.targetHealthVector, { target.health, GetTime() })
            while macroTorch.tableLen(macroTorch.context.targetHealthVector) > 100 do
                table.remove(macroTorch.context.targetHealthVector, 1)
            end
        end
    end
end

-- compute current health-reducing-per-second
function macroTorch.currentHRPS()
    if macroTorch.tableLen(macroTorch.context.targetHealthVector) < 2 then
        return 0
    end

    -- 使用最小二乘法拟合线性回归，计算血量减少的速率
    local sumX = 0
    local sumY = 0
    local sumXY = 0
    local sumXX = 0
    local n = macroTorch.tableLen(macroTorch.context.targetHealthVector)

    -- 计算各项求和值
    for i = 1, n do
        local health, time = unpack(macroTorch.context.targetHealthVector[i])
        sumX = sumX + time
        sumY = sumY + health
        sumXY = sumXY + time * health
        sumXX = sumXX + time * time
    end

    -- 计算线性回归的斜率（即HRPS）
    local slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)

    -- 返回斜率的相反数，因为我们要的是血量减少速率
    return -slope
end

function macroTorch.isKillshotOrLastChance(comboPoints)
    if macroTorch.isLastChance() then
        return true
    end
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    local isPvp = macroTorch.target.isPlayerControlled or GetBattlefieldInstanceRunTime() > 0
    if macroTorch.player.isInGroup and fightWorldBoss then
        -- fight world boss in a group or raid
        return comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a 5-man group
        local nearMateNum = macroTorch.mateNearMyTargetCount() or 0
        local less = 4 - nearMateNum
        if less > 0 then
            macroTorch.show('nearMateNum: ' .. tostring(nearMateNum) .. ', less: ' .. tostring(less))
        end
        return comboPoints == 1 and
            targetHealth <
            (macroTorch.KS_CP1_Health_group - less * (macroTorch.KS_CP1_Health_group - macroTorch.KS_CP1_Health) / 4) or
            comboPoints == 2 and
            targetHealth <
            (macroTorch.KS_CP2_Health_group - less * (macroTorch.KS_CP2_Health_group - macroTorch.KS_CP2_Health) / 4) or
            comboPoints == 3 and
            targetHealth <
            (macroTorch.KS_CP3_Health_group - less * (macroTorch.KS_CP3_Health_group - macroTorch.KS_CP3_Health) / 4) or
            comboPoints == 4 and
            targetHealth <
            (macroTorch.KS_CP4_Health_group - less * (macroTorch.KS_CP4_Health_group - macroTorch.KS_CP4_Health) / 4) or
            comboPoints == 5 and
            targetHealth <
            (macroTorch.KS_CP5_Health_group - less * (macroTorch.KS_CP5_Health_group - macroTorch.KS_CP5_Health) / 4)
    elseif macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a raid
        local raidNum = GetNumRaidMembers() or 0
        local nearMateNum = macroTorch.mateNearMyTargetCount() or 0
        -- if nearMateNum < raidNum - 1 then
        --     macroTorch.show('raidNum: ' .. tostring(raidNum) .. ', nearMateNum: ' .. tostring(nearMateNum))
        -- end

        local more = nearMateNum - 5 + 1
        if more < 0 then
            more = 0
        end
        return comboPoints == 1 and
            targetHealth < (macroTorch.KS_CP1_Health_group + macroTorch.KS_CP1_Health_raid_pps * more) or
            comboPoints == 2 and
            targetHealth < (macroTorch.KS_CP2_Health_group + macroTorch.KS_CP2_Health_raid_pps * more) or
            comboPoints == 3 and
            targetHealth < (macroTorch.KS_CP3_Health_group + macroTorch.KS_CP3_Health_raid_pps * more) or
            comboPoints == 4 and
            targetHealth < (macroTorch.KS_CP4_Health_group + macroTorch.KS_CP4_Health_raid_pps * more) or
            comboPoints == 5 and
            targetHealth < (macroTorch.KS_CP5_Health_group + macroTorch.KS_CP5_Health_raid_pps * more)
    else
        -- fight alone or pvp
        return comboPoints == 1 and targetHealth < macroTorch.KS_CP1_Health or
            comboPoints == 2 and targetHealth < macroTorch.KS_CP2_Health or
            comboPoints == 3 and targetHealth < macroTorch.KS_CP3_Health or
            comboPoints == 4 and targetHealth < macroTorch.KS_CP4_Health or
            comboPoints == 5 and targetHealth < macroTorch.KS_CP5_Health
    end
end

function macroTorch.isLastChance()
    if macroTorch.currentHRPS() <= 0 then
        return false
    end
    local ret = macroTorch.target.health <= macroTorch.currentHRPS() * 2
    -- if ret then
    --     macroTorch.show('Last chance! 2*HRPS: ' .. tostring(macroTorch.currentHRPS() * 2))
    -- end
    return ret
end

function macroTorch.tryBiteKillshot(comboPoints)
    if macroTorch.isKillshotOrLastChance(comboPoints) then
        if comboPoints > 0 then
            CastSpellByName('Ferocious Bite')
        else
            CastSpellByName('Claw')
        end
    end
end

function macroTorch.reshiftMod(player, prowling, ooc, berserk)
    if macroTorch.canDoReshift(player, prowling, ooc, berserk) then
        macroTorch.readyReshift()
    end
end

-- reshift at anytime in battle & not prowling & not ooc when: the current 'enerty restoration per-second' is lesser than '30 - currentEnergyBeforeReshift'
function macroTorch.canDoReshift(player, prowling, ooc, berserk)
    if not player.isInCombat or prowling or ooc then
        return false
    end
    local erps = macroTorch.AUTO_TICK_ERPS
    if macroTorch.isTigerPresent() then
        erps = erps + macroTorch.TIGER_ERPS
    end
    if macroTorch.isRakePresent() then
        erps = erps + macroTorch.RAKE_ERPS
    end
    if macroTorch.isRipPresent() then
        erps = erps + macroTorch.RIP_ERPS
    end
    if macroTorch.isPouncePresent() then
        erps = erps + macroTorch.POUNCE_ERPS
    end
    if berserk then
        erps = erps + macroTorch.BERSERK_ERPS
    end
    local diff = macroTorch.RESHIFT_ENERGY - macroTorch.TIGER_E - player.mana - erps
    local ret = diff > macroTorch.RESHIFT_E_DIFF_THRESHOLD

    -- if ret then
    --     macroTorch.show('Current reshift profit: ' ..
    --         tostring(30 - player.mana) ..
    --         ', current erps: ' ..
    --         tostring(erps) .. ', diff: ' .. tostring(diff) .. ', can do reshift!')
    -- end
    return ret
end

-- tiger fury when near
function macroTorch.keepTigerFury()
    if macroTorch.isTigerPresent() or macroTorch.target.distance > 15 then
        return
    end
    macroTorch.safeTigerFury()
end

function macroTorch.keepRip(comboPoints, prowling)
    if not macroTorch.isFightStarted(prowling) or macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.isImmune('Rip') or macroTorch.isKillshotOrLastChance(comboPoints) then
        return
    end
    -- boost attack power to rip when fighting world boss or player-controlled target
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst()
    end
    macroTorch.safeRip()
end

-- originates from keepRip, but no need to rip at 5cp
function macroTorch.quickKeepRip(comboPoints, prowling)
    -- quick keep rip, do at any cp
    if not macroTorch.isFightStarted(prowling) or macroTorch.isRipPresent() or comboPoints == 0 or macroTorch.isImmune('Rip') or macroTorch.isKillshotOrLastChance(comboPoints) then
        return
    end
    -- boost attack power to rip when fighting world boss or player-controlled target
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst()
    end
    macroTorch.safeRip()
end

function macroTorch.keepRake(comboPoints, prowling)
    -- in no condition rake on 5cp
    if not macroTorch.isFightStarted(prowling) or comboPoints == 5 or macroTorch.isRakePresent() or macroTorch.isImmune('Rake') or macroTorch.isKillshotOrLastChance(comboPoints) then
        return
    end
    -- boost attack power to rake when fighting world boss
    if macroTorch.target.classification == 'worldboss' and macroTorch.target.isNearBy then
        macroTorch.atkPowerBurst()
    end
    macroTorch.safeRake()
end

-- no FF in: 1) melee range if other techs can use, 2) when ooc 3) immune 4) killshot 5) eager to reshift 6) cp5 7) player not in combat 8) prowling 9) target not in combat
-- all in all: if in combat and there's nothing to do, then FF, no matter if FF debuff present, we wish to trigger more ooc through instant FFs
function macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
    if ooc
        or macroTorch.isImmune('Faerie Fire (Feral)')
        or macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not macroTorch.isFightStarted(prowling)
        or not macroTorch.target.isInCombat
        or macroTorch.target.isNearBy and (
            player.mana >= macroTorch.CLAW_E and comboPoints < 5
            or player.mana >= macroTorch.BITE_E and comboPoints == 5
            or player.mana >= macroTorch.RAKE_E and not macroTorch.isRakePresent() and not macroTorch.isImmune('Rake') and comboPoints < 5
            or player.mana >= macroTorch.RIP_E and not macroTorch.isRipPresent() and not macroTorch.isImmune('Rip') and comboPoints == 5
            or comboPoints == 5
            or macroTorch.isKillshotOrLastChance(comboPoints)) then
        return
    end
    macroTorch.safeFF()
end

function macroTorch.isTigerPresent()
    return buffed('Tiger\'s Fury') and macroTorch.tigerLeft() > 0
end

function macroTorch.tigerLeft()
    local tigerLeft = 0
    if not not macroTorch.context.tigerTimer then
        tigerLeft = macroTorch.TIGER_DURATION - (GetTime() - macroTorch.context.tigerTimer)
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
    if not not macroTorch.context.ripTimer then
        ripLeft = macroTorch.RIP_DURATION - (GetTime() - macroTorch.context.ripTimer)
        if ripLeft < 0 then
            ripLeft = 0
        end
    else
        ripLeft = 0
    end
    return ripLeft
end

function macroTorch.isRakePresent()
    return macroTorch.toBoolean(buffed('Rake', 'target') and macroTorch.rakeLeft() > 0)
end

function macroTorch.rakeLeft()
    local rakeLeft = 0
    if not not macroTorch.context.rakeTimer then
        rakeLeft = macroTorch.RAKE_DURATION - (GetTime() - macroTorch.context.rakeTimer)
        if rakeLeft < 0 then
            rakeLeft = 0
        end
    else
        rakeLeft = 0
    end
    return rakeLeft
end

function macroTorch.isFFPresent()
    return buffed('Faerie Fire ', 'target') and macroTorch.ffLeft() > 0
end

function macroTorch.ffLeft()
    local ffLeft = 0
    if not not macroTorch.context.ffTimer then
        ffLeft = macroTorch.FF_DURATION - (GetTime() - macroTorch.context.ffTimer)
        if ffLeft < 0 then
            ffLeft = 0
        end
    else
        ffLeft = 0
    end
    return ffLeft
end

function macroTorch.isPouncePresent()
    return buffed('Pounce', 'target') and macroTorch.pounceLeft() > 0
end

function macroTorch.pounceLeft()
    local pounceLeft = 0
    if not not macroTorch.context.pounceTimer then
        pounceLeft = macroTorch.POUNCE_DURATION - (GetTime() - macroTorch.context.pounceTimer)
        if pounceLeft < 0 then
            pounceLeft = 0
        end
    else
        pounceLeft = 0
    end
    return pounceLeft
end

function macroTorch.readyReshift()
    if SpellReady('Reshift') then
        CastSpellByName('Reshift')
        macroTorch.show('Reshift!!! energy = ' .. macroTorch.player.mana .. ', tigerLeft = ' .. macroTorch.tigerLeft())
        return true
    end
    return false
end

function macroTorch.safeShred()
    return macroTorch.player.mana >= macroTorch.SHRED_E and macroTorch.readyShred()
end

function macroTorch.readyShred()
    if SpellReady('Shred') then
        CastSpellByName('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw()
    return macroTorch.player.mana >= macroTorch.CLAW_E and macroTorch.readyClaw()
end

function macroTorch.readyClaw()
    if SpellReady('Claw') then
        CastSpellByName('Claw')
        return true
    end
    return false
end

function macroTorch.safeRake()
    if SpellReady('Rake') and macroTorch.player.mana >= macroTorch.RAKE_E then
        macroTorch.show('Rake present: ' .. tostring(macroTorch.isRakePresent()) .. ' doing rake now.')
        CastSpellByName('Rake')
        macroTorch.context.rakeTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeRip()
    if SpellReady('Rip') and macroTorch.player.mana >= macroTorch.RIP_E then
        CastSpellByName('Rip')
        macroTorch.context.ripTimer = GetTime()
        macroTorch.show('Ripped at combo points: ' .. tostring(GetComboPoints()))
        return true
    end
    return false
end

function macroTorch.safeBite()
    return macroTorch.player.mana >= macroTorch.BITE_E and macroTorch.readyBite()
end

function macroTorch.readyBite()
    if SpellReady('Ferocious Bite') then
        CastSpellByName('Ferocious Bite')
        if macroTorch.isRipPresent() then
            macroTorch.context.ripTimer = GetTime()
        end
        if macroTorch.isRakePresent() then
            macroTorch.context.rakeTimer = GetTime()
        end
        return true
    end
    return false
end

function macroTorch.safeFF()
    if SpellReady('Faerie Fire (Feral)') then
        -- CastSpellByName('Faerie Fire (Feral)')
        -- lazyScript.SlashCommand('ff')
        macroTorch.player.cast('Faerie Fire (Feral)')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeTigerFury()
    if SpellReady('Tiger\'s Fury') and macroTorch.player.mana >= macroTorch.TIGER_E then
        CastSpellByName('Tiger\'s Fury')
        macroTorch.context.tigerTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safePounce()
    if SpellReady('Pounce') and macroTorch.player.mana >= macroTorch.POUNCE_E then
        CastSpellByName('Pounce')
        macroTorch.context.pounceTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.readyCower()
    if SpellReady('Cower') then
        CastSpellByName('Cower')
        macroTorch.show('current threat: ' .. macroTorch.playerThreatPercent() .. ' doing ready cower!!!')
        return true
    end
    return false
end

function macroTorch.playerThreatPercent()
    local TWT = macroTorch.TWT
    local p = 0
    if TWT and TWT.threats and TWT.threats[TWT.name] then p = TWT.threats[TWT.name].perc or 0 end
    return p
end

-- burst through boosting attack power
function macroTorch.atkPowerBurst()
    if GetInventoryItemCooldown("player", macroTorch.BURST_ITEM_LOC) == 0 then
        UseInventoryItem(macroTorch.BURST_ITEM_LOC)
    end
    if not buffed('Juju Power') and macroTorch.isItemExist('Juju Power') and not macroTorch.target.isPlayerControlled then
        macroTorch.player.use('Juju Power', true)
    end
end

function macroTorch.druidBuffs()
    if not buffed('Mark of the Wild', 'player') then
        CastSpellByName('Mark of the Wild', true)
    end
    if not buffed('Thorns', 'player') then
        CastSpellByName('Thorns', true)
    end
    if not buffed('Nature\'s Grasp', 'player') then
        CastSpellByName('Nature\'s Grasp', true)
    end
end

-- get the distance between specified unit and my target
function macroTorch.unitTargetDistance(unitId)
    if not UnitExists(unitId) or UnitIsDead(unitId) or not macroTorch.target.isExist then
        return nil
    end
    local distance = UnitXP("distanceBetween", unitId, "target")
    if not distance or distance < 0 then
        return nil
    end
    return distance
end

-- count mates number near my current targetHealthVector, excludeing myself
function macroTorch.mateNearMyTargetCount()
    local function mateNearMyTarget(unitId)
        local dis = macroTorch.unitTargetDistance(unitId)
        if not dis then
            return false
        end
        return dis <= 43
    end
    local nearMates = macroTorch.filterGroupMates(mateNearMyTarget)
    return macroTorch.tableLen(nearMates)
end

function macroTorch.druidStun()
    local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
    -- if in melee range then use bear bash else bear charge
    -- if not in bear form, be bear first
    if not inBearForm then
        macroTorch.player.cast('Dire Bear Form')
    end
    if inBearForm and macroTorch.player.mana == 0 and SpellReady('Enrage') then
        macroTorch.player.cast('Enrage')
    end
    if macroTorch.target.isNearBy then
        macroTorch.player.cast('Bash')
    else
        if macroTorch.isSpellExist('Feral Charge', 'spell') then
            macroTorch.player.cast('Feral Charge')
        end
    end
end

function macroTorch.druidDefend()
    -- [Barkskin (Feral)][Frenzied Regeneration]
    if SpellReady('Barkskin (Feral)') then
        macroTorch.player.cast('Barkskin (Feral)')
    end
    if SpellReady('Frenzied Regeneration') then
        local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
        if not inBearForm then
            macroTorch.player.cast('Dire Bear Form')
        end
        if inBearForm and macroTorch.player.mana == 0 and SpellReady('Enrage') then
            macroTorch.player.cast('Enrage')
        end
        macroTorch.player.cast('Frenzied Regeneration')
    end
end

function macroTorch.druidControl()
    -- if target is of type beast or dragonkin, use Hibernate, else use [Entangling Roots]
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.cast('Hibernate')
    else
        macroTorch.player.cast('Entangling Roots')
    end
end

function macroTorch.bearAoe()
    if not macroTorch.player.isFormActive('Dire Bear Form') then
        return
    end
    -- if no [Demoralizing Roar] buff on target, use [Demoralizing Roar]
    if macroTorch.target.isCanAttack and not buffed('Demoralizing Roar', 'target') then
        macroTorch.player.cast('Demoralizing Roar')
    end
    if SpellReady('Swipe') then
        macroTorch.player.cast('Swipe')
    end
end

function macroTorch.bearAtk()
    if not macroTorch.player.isFormActive('Dire Bear Form') then
        return
    end
    if macroTorch.player.mana == 0 and SpellReady('Enrage') then
        macroTorch.player.cast('Enrage')
    end
    local target = macroTorch.target
    -- if target is not attacking me and it's not a player controlled target and Growl ready, use Growl
    -- if target.isCanAttack and not target.isPlayerControlled and not target.isAttackingMe and SpellReady('Growl') then
    --     macroTorch.player.cast('Growl')
    -- end
    -- [Savage Bite] as soon as I can, then [Maul] blindly
    if SpellReady('Savage Bite') then
        macroTorch.player.cast('Savage Bite')
    end
    if SpellReady('Maul') then
        macroTorch.player.cast('Maul')
    end
    macroTorch.safeFF()
end
