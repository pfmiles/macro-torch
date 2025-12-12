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
function macroTorch.catAtk(rough, speedRun)
    local p = 'player'
    local t = 'target'
    macroTorch.POUNCE_E = 50
    macroTorch.CLAW_E = 37
    macroTorch.SHRED_E = 54
    macroTorch.RAKE_E = 32
    macroTorch.BITE_E = 35
    macroTorch.RIP_E = 30
    macroTorch.TIGER_E = 25

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

    macroTorch.COWER_THREAT_THRESHOLD = 75
    macroTorch.RESHIFT_ENERGY = 60
    macroTorch.RESHIFT_E_DIFF_THRESHOLD = 0
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
        -- 3.keep autoAttack, in combat & not prowling *
        if macroTorch.isFightStarted(prowling) then
            player.startAutoAtk()
            if speedRun then
                macroTorch.keepSpeedRunBuffs()
            end
        end
        -- 4.rushMod, incuding trinckets, berserk and potions *
        if IsShiftKeyDown() then
            if not berserk then
                CastSpellByName('Berserk')
            end
            -- juju flurry
            if not macroTorch.player.hasBuff('INV_Misc_MonsterScales_17') then
                if player.hasItem('Juju Flurry') and not macroTorch.target.isPlayerControlled then
                    macroTorch.player.use('Juju Flurry', true)
                end
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
                if not macroTorch.target.isImmune('Pounce') and macroTorch.target.health >= 1500 then
                    macroTorch.safePounce()
                else
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
        if macroTorch.isFightStarted(prowling) and comboPoints < 5 and (macroTorch.isRakePresent() or macroTorch.target.isImmune('Rake')) then
            macroTorch.regularAttack(isBehind, rough)
        end
        -- 12.energy res mod
        macroTorch.reshiftMod(player, prowling, ooc, berserk)
    end
end

function macroTorch.keepSpeedRunBuffs()
    -- special juju flurry for speed run
    if macroTorch.target.healthPercent > 80 and not macroTorch.player.buffed('Juju Flurry', 'INV_Misc_MonsterScales_17') and macroTorch.player.isItemCooledDown('Juju Flurry') then
        macroTorch.player.use('Juju Flurry', true)
    end
end

-- tracing certain spells and maintain the landTable
macroTorch.setSpellTracing(9827, 'Pounce')
macroTorch.setSpellTracing(9904, 'Rake')
macroTorch.setSpellTracing(9896, 'Rip')
macroTorch.setSpellTracing(31018, 'Ferocious Bite')

-- register druid spells immune tracing
macroTorch.setTraceSpellImmune('Pounce', 'Ability_Druid_SupriseAttack')
macroTorch.setTraceSpellImmune('Rake', 'Ability_Druid_Disembowel')
macroTorch.setTraceSpellImmune('Rip', 'Ability_GhoulFrenzy')

function macroTorch.consumeDruidBattleEvents()
    -- deal with bites landing bleeding renewals
    macroTorch.consumeLandEvent('Ferocious Bite', function(landEvent)
        if GetTime() - landEvent > 0.4 or not macroTorch.target.isCanAttack then
            return
        end
        -- 近期有命中过bite，若cp大于0,且本次landed事件还未处理,则刷新rake & rip时间
        if macroTorch.context.lastProcessedBiteEvent and macroTorch.context.lastProcessedBiteEvent == landEvent then
            return
        end
        if GetComboPoints() > 0 then
            if macroTorch.isRakePresent() then
                macroTorch.show('Renewing rake...')
                macroTorch.recordCastTable('Rake')
            end
            if macroTorch.isRipPresent() then
                macroTorch.show('Renewing rip...')
                macroTorch.recordCastTable('Rip')
            end
        end
        macroTorch.context.lastProcessedBiteEvent = landEvent
    end)
end

macroTorch.registerPeriodicTask('consumeDruidBattleEvents',
    { interval = 0.1, task = macroTorch.consumeDruidBattleEvents })

function macroTorch.regularAttack(isBehind, rough)
    -- claw with at least 1 bleeding effect or shred
    if isBehind and not macroTorch.player.isBehindAttackJustFailed and not rough
        and not macroTorch.isRakePresent()
        and not macroTorch.isRipPresent()
        and not macroTorch.isPouncePresent() then
        macroTorch.safeShred()
    else
        macroTorch.safeClaw()
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
    if string.find(macroTorch.target.name, 'Training Dummy') then
        return
    end
    local target = macroTorch.target
    if not player.isInCombat
        or not target.isInCombat
        or prowling
        or macroTorch.isKillshotOrLastChance(comboPoints)
        or not target.isCanAttack
        or target.isPlayerControlled
        or not macroTorch.player.isInGroup then
        return
    end
    if (target.isAttackingMe or macroTorch.playerThreatPercent() > 97) and not player.isSpellReady('Cower') and target.classification == 'worldboss' then
        player.use('Invulnerability Potion', true)
    end
    if macroTorch.canDoReshift(player, prowling, ooc, berserk) then
        return
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
    if comboPoints == 5 and (macroTorch.target.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.safeBite()
    end
end

-- for ooc only
function macroTorch.cp5ReadyBite(comboPoints)
    if comboPoints == 5 and (macroTorch.target.isImmune('Rip') or macroTorch.isRipPresent()) then
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

macroTorch.registerPeriodicTask('maintainTHV', { interval = 0.1, task = macroTorch.maintainTHV })

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

function macroTorch.computeErps()
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
    if macroTorch.player.buffed('Berserk', 'Ability_Druid_Berserk') then
        erps = erps + macroTorch.BERSERK_ERPS
    end
    return erps
end

-- reshift at anytime in battle & not prowling & not ooc when: the current 'enerty restoration per-second' is lesser than '30 - currentEnergyBeforeReshift'
function macroTorch.canDoReshift(player, prowling, ooc, berserk)
    if not player.isInCombat or prowling or ooc then
        return false
    end
    local diff = macroTorch.RESHIFT_ENERGY - macroTorch.TIGER_E - player.mana - (macroTorch.computeErps() * 1.5)
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
    if not macroTorch.isFightStarted(prowling) or macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.target.isImmune('Rip') or macroTorch.isKillshotOrLastChance(comboPoints) then
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
    if not macroTorch.isFightStarted(prowling) or macroTorch.isRipPresent() or comboPoints == 0 or macroTorch.target.isImmune('Rip') or macroTorch.isKillshotOrLastChance(comboPoints) then
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
    if not macroTorch.isFightStarted(prowling) or comboPoints == 5 or macroTorch.isRakePresent() or macroTorch.target.isImmune('Rake') or macroTorch.isKillshotOrLastChance(comboPoints) then
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
    local energy1sLater = player.mana + macroTorch.computeErps()
    if ooc
        or macroTorch.target.isImmune('Faerie Fire (Feral)')
        or macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not macroTorch.isFightStarted(prowling)
        or not macroTorch.target.isInCombat
        or macroTorch.target.isNearBy and (
            energy1sLater >= macroTorch.CLAW_E and comboPoints < 5
            or energy1sLater >= macroTorch.BITE_E and comboPoints == 5
            or energy1sLater >= macroTorch.RAKE_E and not macroTorch.isRakePresent() and not macroTorch.target.isImmune('Rake') and comboPoints < 5
            or energy1sLater >= macroTorch.RIP_E and not macroTorch.isRipPresent() and not macroTorch.target.isImmune('Rip') and comboPoints == 5
            or energy1sLater >= macroTorch.RIP_E and not macroTorch.isRipPresent() and not macroTorch.target.isImmune('Rip') and comboPoints > 0 and macroTorch.isTrivialBattleOrPvp()
            or comboPoints == 5
            or macroTorch.isKillshotOrLastChance(comboPoints)) then
        return
    end
    macroTorch.safeFF()
end

function macroTorch.isTigerPresent()
    return macroTorch.toBoolean(macroTorch.player.hasBuff('Ability_Mount_JungleTiger') and macroTorch.tigerLeft() > 0)
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
    -- Ability_GhoulFrenzy
    return macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_GhoulFrenzy') and macroTorch.ripLeft() > 0)
end

function macroTorch.ripLeft()
    local lastLandedRipTime = macroTorch.peekLandEvent('Rip')
    if not lastLandedRipTime then
        return 0
    end
    local ripDur = macroTorch.RIP_DURATION
    if macroTorch.context.lastRipAtCp then
        ripDur = 10 + (macroTorch.context.lastRipAtCp - 1) * 2
    end
    local ripLeft = ripDur - (GetTime() - lastLandedRipTime)
    if ripLeft < 0 then
        ripLeft = 0
    end
    -- macroTorch.show('Rip left: ' .. ripLeft)
    return ripLeft
end

function macroTorch.isRakePresent()
    -- Ability_Druid_Disembowel
    return macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_Druid_Disembowel') and macroTorch.rakeLeft() > 0)
end

function macroTorch.rakeLeft()
    local lastLandedRakeTime = macroTorch.peekLandEvent('Rake')
    if not lastLandedRakeTime then
        return 0
    end
    local rakeLeft = macroTorch.RAKE_DURATION - (GetTime() - lastLandedRakeTime)
    if rakeLeft < 0 then
        rakeLeft = 0
    end
    -- macroTorch.show('Rake left: ' .. rakeLeft)
    return rakeLeft
end

function macroTorch.isFFPresent()
    -- Spell_Nature_FaerieFire
    return macroTorch.toBoolean(macroTorch.target.hasBuff('Spell_Nature_FaerieFire') and macroTorch.ffLeft() > 0)
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
    -- Ability_Druid_SupriseAttack
    return macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_Druid_SupriseAttack') and macroTorch.pounceLeft() > 0)
end

function macroTorch.pounceLeft()
    local lastLandedPounceTime = macroTorch.peekLandEvent('Pounce')
    if not lastLandedPounceTime then
        return 0
    end
    local pounceLeft = macroTorch.POUNCE_DURATION - (GetTime() - lastLandedPounceTime)
    if pounceLeft < 0 then
        pounceLeft = 0
    end
    return pounceLeft
end

function macroTorch.readyReshift()
    if macroTorch.player.isSpellReady('Reshift') then
        macroTorch.show('Reshift!!! energy = ' .. macroTorch.player.mana .. ', tigerLeft = ' .. macroTorch.tigerLeft())
        CastSpellByName('Reshift')
        return true
    end
    return false
end

function macroTorch.safeShred()
    return macroTorch.player.mana >= macroTorch.SHRED_E and macroTorch.readyShred()
end

function macroTorch.readyShred()
    if macroTorch.player.isSpellReady('Shred') then
        CastSpellByName('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw()
    return macroTorch.player.mana >= macroTorch.CLAW_E and macroTorch.readyClaw()
end

function macroTorch.readyClaw()
    if macroTorch.player.isSpellReady('Claw') then
        CastSpellByName('Claw')
        return true
    end
    return false
end

function macroTorch.safeRake()
    if macroTorch.player.isSpellReady('Rake') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.RAKE_E and macroTorch.target.isNearBy then
        macroTorch.show('Doing rake now! Rake present: ' ..
            tostring(macroTorch.target.hasBuff('Ability_Druid_Disembowel')) ..
            ', rake left: ' .. macroTorch.rakeLeft())
        CastSpellByName('Rake')
        return true
    end
    return false
end

function macroTorch.safeRip()
    if macroTorch.player.isSpellReady('Rip') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.RIP_E and macroTorch.target.isNearBy then
        macroTorch.show('Ripped at combo points: ' ..
            tostring(GetComboPoints()) ..
            ', rip present: ' ..
            tostring(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) .. ', rip left: ' .. macroTorch.ripLeft())
        CastSpellByName('Rip')
        macroTorch.context.lastRipAtCp = GetComboPoints()
        return true
    end
    return false
end

function macroTorch.isGcdOk()
    return macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
end

function macroTorch.safeBite()
    return macroTorch.player.mana >= macroTorch.BITE_E and macroTorch.readyBite()
end

function macroTorch.readyBite()
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk() and macroTorch.target.isNearBy then
        CastSpellByName('Ferocious Bite')
        return true
    end
    return false
end

function macroTorch.safeFF()
    if macroTorch.player.isSpellReady('Faerie Fire (Feral)') and macroTorch.isGcdOk() then
        -- macroTorch.show('FF present: ' ..
        --     tostring(macroTorch.isFFPresent()) ..
        --     ', FF left: ' .. macroTorch.ffLeft() .. ', doing FF now!')
        macroTorch.player.cast('Faerie Fire (Feral)')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeTigerFury()
    if macroTorch.player.isSpellReady('Tiger\'s Fury') and macroTorch.tigerSelfGCD() == 0 and macroTorch.player.mana >= macroTorch.TIGER_E then
        -- macroTorch.show('Tiger\'s Fury present: ' ..
        --     tostring(macroTorch.isTigerPresent()) ..
        --     ', tiger left: ' .. macroTorch.tigerLeft() .. ', doing tiger fury now!')
        CastSpellByName('Tiger\'s Fury')
        macroTorch.context.tigerTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.tigerSelfGCD()
    if not macroTorch or not macroTorch.context or not macroTorch.context.tigerTimer then
        return 0
    end
    local selfGCDLeft = 1 - (GetTime() - macroTorch.context.tigerTimer)
    if selfGCDLeft < 0 then
        selfGCDLeft = 0
    end
    return selfGCDLeft
end

function macroTorch.safePounce()
    if macroTorch.player.isSpellReady('Pounce') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.POUNCE_E and macroTorch.target.isNearBy then
        CastSpellByName('Pounce')
        return true
    end
    return false
end

function macroTorch.readyCower()
    if macroTorch.player.isSpellReady('Cower') then
        macroTorch.show('current threat: ' .. macroTorch.playerThreatPercent() .. ' doing ready cower!!!')
        CastSpellByName('Cower')
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
    -- juju power
    if not macroTorch.player.hasBuff('INV_Misc_MonsterScales_11') and macroTorch.player.hasItem('Juju Power') and not macroTorch.target.isPlayerControlled then
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
    if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
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
    if macroTorch.player.isSpellReady('Barkskin (Feral)') then
        macroTorch.player.cast('Barkskin (Feral)')
    end
    if macroTorch.player.isSpellReady('Frenzied Regeneration') then
        local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
        if not inBearForm then
            macroTorch.player.cast('Dire Bear Form')
        end
        if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
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
    if macroTorch.target.isCanAttack and not macroTorch.target.buffed('Demoralizing Roar', 'Ability_Druid_DemoralizingRoar') then
        macroTorch.player.cast('Demoralizing Roar')
    end
    if macroTorch.player.isSpellReady('Swipe') then
        macroTorch.player.cast('Swipe')
    end
end

function macroTorch.bearAtk()
    if not macroTorch.player.isFormActive('Dire Bear Form') then
        return
    end
    -- if macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
    --     macroTorch.player.cast('Enrage')
    -- end
    local target = macroTorch.target
    local player = macroTorch.player
    -- if target is not attacking me and it's not a player controlled target and Growl ready, use Growl
    -- if target.isCanAttack and not target.isPlayerControlled and not target.isAttackingMe and SpellReady('Growl') then
    --     macroTorch.player.cast('Growl')
    -- end
    -- [Savage Bite] as soon as I can, then [Maul] blindly
    if player.buffed('Clearcasting', 'Spell_Shadow_ManaBurn') and player.isSpellReady('Savage Bite') then
        player.cast('Savage Bite')
    end
    if macroTorch.player.isSpellReady('Maul') then
        macroTorch.player.cast('Maul')
    end
    if not target.isAttackingMe and not target.isPlayerControlled then
        if player.isSpellReady('Growl') then
            player.cast('Growl')
        elseif player.isSpellReady('Challenging Roar') then
            player.cast('Challenging Roar')
        end
    end
    macroTorch.safeFF()
end

-- for some problematic battle
function macroTorch.bruteForce()
    local p = 'player'

    local player = macroTorch.player
    local prowling = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Ambush')
    local berserk = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Druid_Berserk')
    local comboPoints = GetComboPoints()
    local ooc = macroTorch.isBuffOrDebuffPresent(p, 'Spell_Shadow_ManaBurn')

    -- 1.health & mana saver in combat *
    if macroTorch.inCombat then
        macroTorch.combatUrgentHPRestore()
        -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
    end
    -- 3.keep autoAttack, in combat & not prowling *
    if macroTorch.inCombat then
        player.startAutoAtk()
    end
    -- 4.rushMod, incuding trinckets, berserk and potions *
    if IsShiftKeyDown() then
        if not berserk then
            CastSpellByName('Berserk')
        end
        -- juju flurry
        if not macroTorch.player.hasBuff('INV_Misc_MonsterScales_17') then
            if player.hasItem('Juju Flurry') then
                macroTorch.player.use('Juju Flurry', true)
            end
        end
        macroTorch.atkPowerBurst()
    end
    -- 7.oocMod
    if ooc then
        macroTorch.tryBiteKillshot(comboPoints)
        macroTorch.cp5ReadyBite(comboPoints)
        -- no shred/claw at cp5 when ooc
        if comboPoints < 5 then
            if not player.isBehindAttackJustFailed then
                macroTorch.readyShred()
            else
                macroTorch.readyClaw()
            end
        end
    end
    -- 6.termMod: term on rip or killshot
    macroTorch.termMod(comboPoints)
    -- 9.combatBuffMod - tiger's fury *
    macroTorch.keepTigerFury()
    -- 10.debuffMod, including rip, rake and FF
    macroTorch.keepRip(comboPoints, prowling)
    macroTorch.keepRake(comboPoints, prowling)
    macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
    -- 11.regular attack tech mod
    if macroTorch.inCombat and comboPoints < 5 and (macroTorch.isRakePresent() or macroTorch.target.isImmune('Rake')) then
        macroTorch.regularAttack(nil, nil)
    end
    -- 12.energy res mod
    macroTorch.reshiftMod(player, prowling, ooc, berserk)
end
