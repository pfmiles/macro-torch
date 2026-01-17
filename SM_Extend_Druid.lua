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
macroTorch.Druid = macroTorch.Player:new()

function macroTorch.Druid:new()
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
            if macroTorch.DRUID_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.DRUID_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })

    function obj.showEnergyUsageSet()
        macroTorch.POUNCE_E = 50
        macroTorch.CLAW_E = macroTorch.computeClaw_E()
        macroTorch.SHRED_E = macroTorch.computeShred_E()
        macroTorch.RAKE_E = macroTorch.computeRake_E()
        macroTorch.BITE_E = 35
        macroTorch.RIP_E = 30
        macroTorch.TIGER_E = macroTorch.computeTiger_E()

        macroTorch.TIGER_DURATION = macroTorch.computeTiger_Duration()
        macroTorch.RAKE_DURATION = macroTorch.computeRake_Duration()

        macroTorch.show('POUNCE_E: ' ..
            macroTorch.POUNCE_E ..
            ', CLAW_E: ' ..
            macroTorch.CLAW_E ..
            ', SHRED_E: ' ..
            macroTorch.SHRED_E ..
            ', RAKE_E: ' ..
            macroTorch.RAKE_E ..
            ', BITE_E: ' ..
            macroTorch.BITE_E ..
            ', RIP_E: ' ..
            macroTorch.RIP_E ..
            ', TIGER_E: ' ..
            macroTorch.TIGER_E ..
            ', TIGER_DURATION: ' ..
            macroTorch.TIGER_DURATION ..
            ', RAKE_DURATION: ' ..
            macroTorch.RAKE_DURATION
        )
    end

    function obj.isRelicEquipped(relicName)
        return macroTorch.isRelicEquipped(relicName)
    end

    function obj.ensureRelicEquipped(relicName)
        if not obj.isRelicEquipped(relicName) then
            obj.equipRelic(relicName)
        end
        return obj.isRelicEquipped(relicName)
    end

    function obj.equipRelic(relicName)
        macroTorch.equipItem(relicName, 18)
    end

    --- The 'E' key regular dps function for feral cat druid
    --- if rough, then no back attacks
    function obj.catAtk(rough, speedRun)
        macroTorch.POUNCE_E = 50
        macroTorch.CLAW_E = macroTorch.computeClaw_E()
        macroTorch.SHRED_E = macroTorch.computeShred_E()
        macroTorch.RAKE_E = macroTorch.computeRake_E()
        macroTorch.BITE_E = 35
        macroTorch.RIP_E = 30
        macroTorch.TIGER_E = macroTorch.computeTiger_E()

        macroTorch.TIGER_DURATION = macroTorch.computeTiger_Duration()
        macroTorch.RIP_DURATION = 18
        macroTorch.RAKE_DURATION = macroTorch.computeRake_Duration()
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
        macroTorch.PLAYER_URGENT_HP_THRESHOLD = 10

        local player = macroTorch.player
        local target = macroTorch.target
        local prowling = player.isProwling
        local berserk = player.isBerserk
        local comboPoints = player.comboPoints
        local ooc = player.isOoc
        local isBehind = target.isCanAttack and player.isBehindTarget

        -- 0.idol dance
        macroTorch.idolDance()

        -- 1.health & mana saver in combat *
        if macroTorch.isFightStarted(prowling) then
            macroTorch.combatUrgentHPRestore()
            -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
        end
        -- 2.targetEnemy *
        if not target.isCanAttack then
            player.targetEnemy()
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
                    player.cast('Berserk')
                end
                -- juju flurry
                if not player.hasBuff('INV_Misc_MonsterScales_17') and not player.isFormActive('Dire Bear Form') then
                    if player.hasItem('Juju Flurry') and not target.isPlayerControlled then
                        player.use('Juju Flurry', true)
                    end
                end
                macroTorch.atkPowerBurst()
            end
            -- roughly bear form logic branch
            if player.isFormActive('Dire Bear Form') then
                macroTorch.bearAtk()
                return
            end
            -- 5.starterMod
            if prowling then
                if not rough then
                    if not target.isImmune('Pounce') and target.health >= 1500 then
                        macroTorch.safePounce()
                    else
                        player.cast('Ravage')
                    end
                else
                    macroTorch.safeClaw()
                end
            end

            -- 7.oocMod: 没有前行且ooc 或 前行但目标正在攻击我
            if (not prowling or target.isAttackingMe) and ooc then
                macroTorch.oocMod(rough, isBehind, comboPoints)
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
            if macroTorch.isFightStarted(prowling) and comboPoints < 5 and (macroTorch.isRakePresent() or target.isImmune('Rake')) then
                macroTorch.regularAttack(isBehind, rough)
            end
            -- 12.energy res mod
            macroTorch.reshiftMod(player, prowling, ooc, berserk)
        end
    end

    return obj
end

-- player fields to function mapping
macroTorch.DRUID_FIELD_FUNC_MAP = {
    -- basic props
    ['comboPoints'] = function(self)
        return GetComboPoints()
    end,
    -- conditinal props
    ['isOoc'] = function(self)
        return self.buffed('Clearcasting', 'Spell_Shadow_ManaBurn')
    end,
    ['isProwling'] = function(self)
        return self.buffed('Prowl', 'Ability_Ambush')
    end,
    ['isBerserk'] = function(self)
        return self.buffed('Berserk', 'Ability_Druid_Berserk')
    end,
}

macroTorch.druid = macroTorch.Druid:new()

function macroTorch.idolDance()
    if macroTorch.player.comboPoints == 5 then
        if macroTorch.player.hasItem('Idol of Savagery')
            and not macroTorch.target.isImmune('Rip')
            and not macroTorch.isRipPresent()
            and not macroTorch.target.willDieInSeconds(4)
            and not macroTorch.isTrivialBattle() then
            macroTorch.player.ensureRelicEquipped('Idol of Savagery')
        end
    else
        if macroTorch.player.hasItem('Idol of Ferocity') then
            macroTorch.player.ensureRelicEquipped('Idol of Ferocity')
        end
    end
end

function macroTorch.computeClaw_E()
    local CLAW_E = 45
    local player = macroTorch.player
    if player.isItemEquipped('Idol of Ferocity') then
        CLAW_E = CLAW_E - 3
    end
    CLAW_E = CLAW_E - player.talentRank('Ferocity')
    return CLAW_E
end

function macroTorch.computeShred_E()
    local SHRED_E = 60
    return SHRED_E - macroTorch.player.talentRank('Improved Shred') * 6
end

function macroTorch.computeRake_E()
    local RAKE_E = 40
    local player = macroTorch.player
    if player.isItemEquipped('Idol of Ferocity') then
        RAKE_E = RAKE_E - 3
    end
    return RAKE_E - player.talentRank('Ferocity')
end

function macroTorch.computeRake_Duration()
    local rakeDuration = 9
    if macroTorch.player.isRelicEquipped('Idol of Savagery') then
        rakeDuration = rakeDuration * 0.9
    end
    return rakeDuration
end

function macroTorch.computeTiger_E()
    local TIGER_E = 30
    if macroTorch.player.countEquippedItemNameContains('Cenarion') >= 5 then
        TIGER_E = TIGER_E - 5
    end
    return TIGER_E
end

function macroTorch.computeTiger_Duration()
    local tiger_duration = 6
    tiger_duration = tiger_duration + macroTorch.player.talentRank('Blood Frenzy') * 6
    return tiger_duration
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

-- 职业特定的天赋行为需要自己追踪
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
        -- 撕咬后还剩下cp，才说明刷新了rake & rip时间
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
    return macroTorch.target.isPlayerControlled or
        macroTorch.isTrivialBattle()
end

function macroTorch.isTrivialBattle()
    -- if the target's max health is less than we attack 15s with 500dps each person
    return macroTorch.target.healthMax <= (macroTorch.player.mateNearMyTargetCount + 1) * 500 * 20
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
                or (macroTorch.target.isHostile and macroTorch.target.isInCombat)
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
    if target.isAttackingMe and not player.isSpellReady('Cower') and target.classification == 'worldboss' then
        player.use('Invulnerability Potion', true)
    end
    if macroTorch.canDoReshift(player, prowling, ooc, berserk) then
        return
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then
        macroTorch.readyCower()
    end
end

function macroTorch.termMod(comboPoints)
    macroTorch.tryBiteKillshot(comboPoints)
    macroTorch.cp5Bite(comboPoints)
end

function macroTorch.cp5Bite(comboPoints)
    if comboPoints == 5 and (macroTorch.target.isImmune('Rip') or macroTorch.isRipPresent()) then
        -- only discharge enerty when rip time left is greater then 1.8s
        local leftLimit = 1.8
        if not ((macroTorch.isRipPresent() and macroTorch.ripLeft() <= leftLimit)) then
            macroTorch.energyDischargeBeforeBite()
        end
        if macroTorch.player.isOoc then
            macroTorch.readyBite()
        else
            macroTorch.safeBite()
        end
    end
end

-- 撕咬前的泄能逻辑: 当前多余能量用作撕咬加成不划算，将其拆成2个技能使用
function macroTorch.energyDischargeBeforeBite()
    if macroTorch.player.isOoc then
        if macroTorch.player.isBehindTarget then
            macroTorch.readyShred()
        else
            macroTorch.readyClaw()
        end
    elseif macroTorch.player.mana >= macroTorch.BITE_E + macroTorch.SHRED_E and macroTorch.player.isBehindTarget then
        macroTorch.safeShred()
    elseif macroTorch.player.mana >= macroTorch.BITE_E + macroTorch.CLAW_E then
        macroTorch.safeClaw()
    end
end

function macroTorch.oocMod(rough, isBehind, comboPoints)
    macroTorch.tryBiteKillshot(comboPoints)
    if comboPoints < 5 then
        if isBehind and not macroTorch.player.isBehindAttackJustFailed and not rough then
            macroTorch.readyShred()
        else
            macroTorch.readyClaw()
        end
    else
        -- cp5 bite when ooc
        macroTorch.cp5Bite(comboPoints)
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

function macroTorch.isKillshotOrLastChance(comboPoints)
    if macroTorch.target.willDieInSeconds(2) then
        return true
    end
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    local isPvp = macroTorch.target.isPlayerControlled or macroTorch.player.isInBattleField()
    if macroTorch.player.isInGroup and fightWorldBoss then
        -- fight world boss in a group or raid
        return comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a 5-man group
        local nearMateNum = macroTorch.player.mateNearMyTargetCount or 0
        local less = 4 - nearMateNum
        -- if less > 0 then
        --     macroTorch.show('nearMateNum: ' .. tostring(nearMateNum) .. ', less: ' .. tostring(less))
        -- end
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
        local raidNum = macroTorch.player.raidMemberCount or 0
        local nearMateNum = macroTorch.player.mateNearMyTargetCount or 0
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

function macroTorch.tryBiteKillshot(comboPoints)
    if macroTorch.isKillshotOrLastChance(comboPoints) then
        if comboPoints > 0 then
            macroTorch.player.cast('Ferocious Bite')
        else
            if macroTorch.player.isBehindTarget then
                macroTorch.safeShred()
            end
            macroTorch.readyClaw()
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
    if macroTorch.player.isBerserk then
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
    if macroTorch.isTigerPresent() or macroTorch.target.distance > 20 then
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
    if macroTorch.target.classification == 'worldboss' and macroTorch.isNearBy() then
        macroTorch.atkPowerBurst()
    end
    macroTorch.safeRake()
end

function macroTorch.isNearBy()
    return macroTorch.target.distance <= 3
end

-- no FF in: 1) melee range if other techs can use, 2) when ooc 3) immune 4) killshot 5) eager to reshift 6) cp5 7) player not in combat 8) prowling 9) target not in combat
-- all in all: if in combat and there's nothing to do, then FF, no matter if FF debuff present, we wish to trigger more ooc through instant FFs
function macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
    if ooc
        or macroTorch.target.isImmune('Faerie Fire (Feral)')
        or macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not macroTorch.isFightStarted(prowling)
        or not macroTorch.target.isInCombat
        or macroTorch.isNearBy() and (
            player.mana >= macroTorch.CLAW_E and comboPoints < 5
            or player.mana >= macroTorch.BITE_E and comboPoints == 5
            or player.mana >= macroTorch.RAKE_E and not macroTorch.isRakePresent() and not macroTorch.target.isImmune('Rake') and comboPoints < 5
            or player.mana >= macroTorch.RIP_E and not macroTorch.isRipPresent() and not macroTorch.target.isImmune('Rip') and comboPoints == 5
            or player.mana >= macroTorch.RIP_E and not macroTorch.isRipPresent() and not macroTorch.target.isImmune('Rip') and comboPoints > 0 and macroTorch.isTrivialBattleOrPvp()
            or macroTorch.isTrivialBattleOrPvp() and macroTorch.isFFPresent() and (player.mana + macroTorch.computeErps()) >= macroTorch.TIGER_E
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
    -- rip的连击点数每增一点，持续时间加2s
    local ripDur = macroTorch.RIP_DURATION
    if macroTorch.context.lastRipAtCp then
        ripDur = 10 + (macroTorch.context.lastRipAtCp - 1) * 2
    end
    -- if Savagery idol equipped, reduce rip duration by 10%
    if macroTorch.player.isRelicEquipped('Idol of Savagery') then
        ripDur = ripDur * 0.9
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
        macroTorch.player.cast('Reshift')
        return true
    end
    return false
end

function macroTorch.safeShred()
    return macroTorch.player.mana >= macroTorch.SHRED_E and macroTorch.readyShred()
end

function macroTorch.readyShred()
    if macroTorch.player.isSpellReady('Shred') then
        macroTorch.player.cast('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw()
    return macroTorch.player.mana >= macroTorch.CLAW_E and macroTorch.readyClaw()
end

function macroTorch.readyClaw()
    if macroTorch.player.isSpellReady('Claw') then
        if macroTorch.player.hasItem('Idol of Ferocity') then
            macroTorch.player.ensureRelicEquipped('Idol of Ferocity')
            macroTorch.player.cast('Claw')
        else
            macroTorch.player.cast('Claw')
        end
        return true
    end
    return false
end

function macroTorch.safeRake()
    if macroTorch.player.isSpellReady('Rake') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.RAKE_E and macroTorch.isNearBy() then
        macroTorch.show('Doing rake now! Rake present: ' ..
            tostring(macroTorch.target.hasBuff('Ability_Druid_Disembowel')) ..
            ', rake left: ' .. macroTorch.rakeLeft())
        macroTorch.player.cast('Rake')
        return true
    end
    return false
end

function macroTorch.safeRip()
    if macroTorch.player.isSpellReady('Rip') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.RIP_E and macroTorch.isNearBy() then
        macroTorch.show('Ripped at combo points: ' ..
            tostring(macroTorch.player.comboPoints) ..
            ', rip present: ' ..
            tostring(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) .. ', rip left: ' .. macroTorch.ripLeft())
        macroTorch.player.cast('Rip')
        macroTorch.context.lastRipAtCp = macroTorch.player.comboPoints
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
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk() and macroTorch.isNearBy() then
        macroTorch.player.cast('Ferocious Bite')
        macroTorch.show('Bite at energy: ' .. macroTorch.player.mana .. ', ooc: ' .. tostring(macroTorch.player.isOoc))
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
        macroTorch.player.cast('Tiger\'s Fury')
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
    if macroTorch.player.isSpellReady('Pounce') and macroTorch.isGcdOk() and macroTorch.player.mana >= macroTorch.POUNCE_E and macroTorch.isNearBy() then
        macroTorch.player.cast('Pounce')
        return true
    end
    return false
end

function macroTorch.readyCower()
    if macroTorch.player.isSpellReady('Cower') then
        macroTorch.show('current threat: ' .. macroTorch.player.threatPercent .. ' doing ready cower!!!')
        macroTorch.player.cast('Cower')
        return true
    end
    return false
end

-- burst through boosting attack power
function macroTorch.atkPowerBurst()
    macroTorch.player.useTrinket2()
    -- juju power
    if not macroTorch.player.hasBuff('INV_Misc_MonsterScales_11') and macroTorch.player.hasItem('Juju Power') and not macroTorch.target.isPlayerControlled then
        macroTorch.player.use('Juju Power', true)
    end
end

function macroTorch.druidBuffs()
    if not macroTorch.player.buffed('Mark of the Wild') then
        macroTorch.player.cast('Mark of the Wild', true)
    end
    if not macroTorch.player.buffed('Thorns') then
        macroTorch.player.cast('Thorns', true)
    end
    if not macroTorch.player.buffed('Nature\'s Grasp') then
        macroTorch.player.cast('Nature\'s Grasp', true)
    end
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
    if macroTorch.isNearBy() then
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
    if player.isOoc and player.isSpellReady('Savage Bite') then
        player.cast('Savage Bite')
    end
    -- if solo, auto demo roar when could
    if not player.isInGroup and not target.buffed('Demoralizing Roar', 'Ability_Druid_DemoralizingRoar') then
        player.cast('Demoralizing Roar')
    end
    -- normal attack
    if macroTorch.player.isSpellReady('Maul') then
        macroTorch.player.cast('Maul')
    end
    -- if in group, tanking
    if player.isInGroup and not target.isAttackingMe and not target.isPlayerControlled then
        if player.isSpellReady('Growl') then
            player.cast('Growl')
        elseif player.isSpellReady('Challenging Roar') then
            player.cast('Challenging Roar')
        end
    end
    -- ff when nothing to do
    macroTorch.safeFF()
end

-- for some problematic battle
function macroTorch.bruteForce()
    local player = macroTorch.player
    local target = macroTorch.target
    local prowling = player.isProwling
    local berserk = player.isBerserk
    local comboPoints = player.comboPoints
    local ooc = player.isOoc
    local isBehind = target.isCanAttack and player.isBehindTarget

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
            player.cast('Berserk')
        end
        -- juju flurry
        if not player.hasBuff('INV_Misc_MonsterScales_17') and not player.isFormActive('Dire Bear Form') then
            if player.hasItem('Juju Flurry') then
                player.use('Juju Flurry', true)
            end
        end
        macroTorch.atkPowerBurst()
    end
    if macroTorch.isKillshotOrLastChance(comboPoints) then
        if comboPoints > 0 then
            player.cast('Ferocious Bite')
        else
            macroTorch.readyClaw()
        end
    else
        macroTorch.keepTigerFury()
        if comboPoints < 5 then
            if not target.isImmune('Rake') and not macroTorch.isRakePresent() then
                player.cast('Rake')
            else
                if isBehind and (not macroTorch.isRipPresent() and not macroTorch.isRakePresent() and not macroTorch.isPouncePresent() or ooc) then
                    player.cast('Shred')
                else
                    macroTorch.readyClaw()
                end
            end
        else
            if macroTorch.isRipPresent() or macroTorch.target.isImmune('Rip') then
                player.cast('Ferocious Bite')
            else
                player.cast('Rip')
            end
        end
    end
    macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
    -- 12.energy res mod
    macroTorch.reshiftMod(player, prowling, ooc, berserk)
end
