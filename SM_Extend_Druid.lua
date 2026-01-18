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

        macroTorch.POUNCE_DURATION = 18
        macroTorch.TIGER_DURATION = macroTorch.computeTiger_Duration()
        macroTorch.RAKE_DURATION = 9
        macroTorch.RIP_DURATION = 10

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
            ', POUNCE_DURATION: ' ..
            macroTorch.POUNCE_DURATION ..
            ', TIGER_DURATION: ' ..
            macroTorch.TIGER_DURATION ..
            ', RAKE_DURATION: ' ..
            macroTorch.RAKE_DURATION ..
            ', RIP_DURATION: ' ..
            macroTorch.RIP_DURATION
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

    function obj.prowl()
        if not obj.buffed('Prowl') then
            obj.cast('Prowl')
        end
    end

    function obj.trackHumanoids()
        if not obj.buffed('Track Humanoids') then
            obj.cast('Track Humanoids')
        end
    end

    --- The 'E' key regular dps function for feral cat druid
    --- if rough, then no back attacks
    function obj.catAtk(rough, speedRun)
        local clickContext = {}

        clickContext.rough = rough
        clickContext.speedRun = speedRun

        clickContext.POUNCE_E = 50
        clickContext.CLAW_E = macroTorch.computeClaw_E()
        clickContext.SHRED_E = macroTorch.computeShred_E()
        clickContext.RAKE_E = macroTorch.computeRake_E()
        clickContext.BITE_E = 35
        clickContext.RIP_E = 30
        clickContext.TIGER_E = macroTorch.computeTiger_E()

        clickContext.TIGER_DURATION = macroTorch.computeTiger_Duration()
        macroTorch.RIP_DURATION = 10
        macroTorch.RAKE_DURATION = 9
        clickContext.FF_DURATION = 40
        clickContext.POUNCE_DURATION = 18

        clickContext.AUTO_TICK_ERPS = 20 / 2
        clickContext.TIGER_ERPS = 10 / 3
        clickContext.RAKE_ERPS = 5 / 3
        clickContext.RIP_ERPS = 5 / 2
        clickContext.POUNCE_ERPS = 5 / 3
        clickContext.BERSERK_ERPS = 20 / 2

        macroTorch.COWER_THREAT_THRESHOLD = 75
        clickContext.RESHIFT_ENERGY = 60
        clickContext.RESHIFT_E_DIFF_THRESHOLD = 0
        clickContext.PLAYER_URGENT_HP_THRESHOLD = 10

        local player = macroTorch.player
        local target = macroTorch.target
        clickContext.prowling = player.isProwling
        clickContext.berserk = player.isBerserk
        clickContext.comboPoints = player.comboPoints
        clickContext.ooc = player.isOoc
        clickContext.isBehind = target.isCanAttack and player.isBehindTarget

        -- 0.idol dance
        macroTorch.idolDance(clickContext)

        -- 1.health & mana saver in combat *
        if macroTorch.isFightStarted(clickContext) then
            macroTorch.combatUrgentHPRestore(clickContext)
            -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
        end
        -- 2.targetEnemy *
        if not target.isCanAttack then
            player.targetEnemy()
        else
            -- 3.keep autoAttack, in combat & not prowling *
            if macroTorch.isFightStarted(clickContext) then
                player.startAutoAtk()
                if clickContext.speedRun then
                    macroTorch.keepSpeedRunBuffs(clickContext)
                end
            end
            -- 4.rushMod, incuding trinckets, berserk and potions *
            if IsShiftKeyDown() then
                if not clickContext.berserk then
                    player.cast('Berserk')
                end
                -- juju flurry
                if not player.hasBuff('INV_Misc_MonsterScales_17') and not player.isFormActive('Dire Bear Form') then
                    if player.hasItem('Juju Flurry') and not target.isPlayerControlled then
                        player.use('Juju Flurry', true)
                    end
                end
                macroTorch.atkPowerBurst(clickContext)
            end
            -- roughly bear form logic branch
            if player.isFormActive('Dire Bear Form') then
                macroTorch.bearAtk(clickContext)
                return
            end
            -- 5.starterMod
            if clickContext.prowling then
                if not clickContext.rough then
                    if not target.isImmune('Pounce') and target.health >= 1500 then
                        macroTorch.safePounce(clickContext)
                    else
                        player.cast('Ravage')
                    end
                else
                    macroTorch.safeClaw(clickContext)
                end
            end

            -- 7.oocMod: 没有前行且ooc 或 前行但目标正在攻击我
            if (not clickContext.prowling or target.isAttackingMe) and clickContext.ooc then
                macroTorch.oocMod(clickContext)
            end
            -- 6.termMod: term on rip or killshot
            macroTorch.termMod(clickContext)
            -- 8.OT mod
            macroTorch.otMod(clickContext)
            -- 9.combatBuffMod - tiger's fury *
            macroTorch.keepTigerFury(clickContext)
            -- 10.debuffMod, including rip, rake and FF
            if macroTorch.isTrivialBattleOrPvp(clickContext) then
                -- no need to do deep rip when pvp
                macroTorch.quickKeepRip(clickContext)
            else
                macroTorch.keepRip(clickContext)
            end
            macroTorch.keepRake(clickContext)
            macroTorch.keepFF(clickContext)
            -- 11.regular attack tech mod
            if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 and (macroTorch.isRakePresent(clickContext) or target.isImmune('Rake')) then
                macroTorch.regularAttack(clickContext)
            end
            -- 12.energy res mod
            macroTorch.reshiftMod(clickContext)
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

function macroTorch.idolDance(clickContext)
    local player = macroTorch.player
    local target = macroTorch.target
    if macroTorch.player.isFormActive('Cat Form') then
        if clickContext.comboPoints == 5 then
            if player.hasItem('Idol of Savagery')
                and not target.isImmune('Rip')
                and not macroTorch.isRipPresent(clickContext)
                and not target.willDieInSeconds(20)
                and not macroTorch.isTrivialBattle(clickContext) then
                player.ensureRelicEquipped('Idol of Savagery')
            end
        else
            if player.hasItem('Idol of Ferocity') then
                player.ensureRelicEquipped('Idol of Ferocity')
            end
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

function macroTorch.keepSpeedRunBuffs(clickContext)
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
            local clickContext = {}
            if macroTorch.isRakePresent(clickContext) then
                macroTorch.show('Renewing rake... left: ' ..
                    tostring(macroTorch.rakeLeft(clickContext)) ..
                    ', bleed idol: ' .. tostring(macroTorch.context.lastRakeEquippedSavagery))
                macroTorch.recordCastTable('Rake')
            end
            if macroTorch.isRipPresent(clickContext) then
                macroTorch.show('Renewing rip... left: ' ..
                    tostring(macroTorch.ripLeft(clickContext)) ..
                    ', bleed idol: ' .. tostring(macroTorch.context.lastRipEquippedSavagery))
                macroTorch.recordCastTable('Rip')
            end
        end
        macroTorch.context.lastProcessedBiteEvent = landEvent
    end)
end

macroTorch.registerPeriodicTask('consumeDruidBattleEvents',
    { interval = 0.1, task = macroTorch.consumeDruidBattleEvents })

function macroTorch.regularAttack(clickContext)
    -- claw with at least 1 bleeding effect or shred
    if clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed and not clickContext.rough
        and not macroTorch.isRakePresent(clickContext)
        and not macroTorch.isRipPresent(clickContext)
        and not macroTorch.isPouncePresent(clickContext) then
        macroTorch.safeShred(clickContext)
    else
        macroTorch.safeClaw(clickContext)
    end
end

function macroTorch.isTrivialBattleOrPvp(clickContext)
    return macroTorch.target.isPlayerControlled or
        macroTorch.isTrivialBattle(clickContext)
end

function macroTorch.isTrivialBattle(clickContext)
    if clickContext.isTrivialBattle == nil then
        -- if the target's max health is less than we attack 15s with 500dps each person
        clickContext.isTrivialBattle = macroTorch.target.healthMax <=
            (macroTorch.player.mateNearMyTargetCount + 1) * 500 * 20
    end
    return clickContext.isTrivialBattle
end

function macroTorch.combatUrgentHPRestore(clickContext)
    local p = 'player'
    if macroTorch.isItemCooledDown('Healthstone') then
        macroTorch.useItemIfHealthPercentLessThan(p, clickContext.PLAYER_URGENT_HP_THRESHOLD, 'Healthstone')
    elseif macroTorch.isItemCooledDown('Healing Potion') then
        macroTorch.useItemIfHealthPercentLessThan(p, clickContext.PLAYER_URGENT_HP_THRESHOLD, 'Healing Potion')
    end
end

-- whether the fight has started, considering prowling
function macroTorch.isFightStarted(clickContext)
    if clickContext.isFightStarted == nil then
        clickContext.isFightStarted =
            (not clickContext.prowling and
                (macroTorch.player.isInCombat
                    or macroTorch.inCombat
                    or macroTorch.target.isPlayerControlled
                    or (macroTorch.target.isHostile and macroTorch.target.isInCombat)
                ))
            or (clickContext.prowling and macroTorch.target.isAttackingMe)
    end
    return clickContext.isFightStarted
end

function macroTorch.otMod(clickContext)
    if string.find(macroTorch.target.name, 'Training Dummy') then
        return
    end
    local player = macroTorch.player
    local target = macroTorch.target
    if not player.isInCombat
        or not target.isInCombat
        or clickContext.prowling
        or macroTorch.isKillshotOrLastChance(clickContext)
        or not target.isCanAttack
        or target.isPlayerControlled
        or not macroTorch.player.isInGroup then
        return
    end
    if target.isAttackingMe and not player.isSpellReady('Cower') and target.classification == 'worldboss' then
        player.use('Invulnerability Potion', true)
    end
    if macroTorch.canDoReshift(clickContext) then
        return
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then
        macroTorch.readyCower(clickContext)
    end
end

function macroTorch.termMod(clickContext)
    macroTorch.tryBiteKillshot(clickContext)
    macroTorch.cp5Bite(clickContext)
end

function macroTorch.cp5Bite(clickContext)
    if clickContext.comboPoints == 5 and (macroTorch.target.isImmune('Rip') or macroTorch.isRipPresent(clickContext)) then
        -- only discharge enerty when rip time left is greater then 1.8s
        if not ((macroTorch.isRipPresent(clickContext) and macroTorch.ripLeft(clickContext) <= 1.8)) then
            macroTorch.energyDischargeBeforeBite(clickContext)
        end
        if clickContext.ooc then
            macroTorch.readyBite(clickContext)
        else
            macroTorch.safeBite(clickContext)
        end
    end
end

-- 撕咬前的泄能逻辑: 当前多余能量用作撕咬加成不划算，将其拆成2个技能使用
function macroTorch.energyDischargeBeforeBite(clickContext)
    if clickContext.ooc then
        -- macroTorch.show('Discharging before bite(ooc), rip left: ' .. macroTorch.ripLeft(clickContext))
        if clickContext.isBehind then
            macroTorch.readyShred(clickContext)
        else
            macroTorch.readyClaw(clickContext)
        end
    elseif macroTorch.player.mana >= clickContext.BITE_E + clickContext.SHRED_E and clickContext.isBehind then
        -- macroTorch.show('Discharging before bite, rip left: ' .. macroTorch.ripLeft(clickContext))
        macroTorch.safeShred(clickContext)
    elseif macroTorch.player.mana >= clickContext.BITE_E + clickContext.CLAW_E then
        -- macroTorch.show('Discharging before bite, rip left: ' .. macroTorch.ripLeft(clickContext))
        macroTorch.safeClaw(clickContext)
    end
end

function macroTorch.oocMod(clickContext)
    macroTorch.tryBiteKillshot(clickContext)
    if clickContext.comboPoints < 5 then
        if clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed and not clickContext.rough then
            macroTorch.readyShred(clickContext)
        else
            macroTorch.readyClaw(clickContext)
        end
    else
        -- cp5 bite when ooc
        macroTorch.cp5Bite(clickContext)
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

function macroTorch.isKillshotOrLastChance(clickContext)
    if macroTorch.target.willDieInSeconds(2) then
        return true
    end
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    local isPvp = macroTorch.target.isPlayerControlled or macroTorch.player.isInBattleField()
    if macroTorch.player.isInGroup and fightWorldBoss then
        -- fight world boss in a group or raid
        return clickContext.comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a 5-man group
        local nearMateNum = macroTorch.player.mateNearMyTargetCount or 0
        local less = 4 - nearMateNum
        -- if less > 0 then
        --     macroTorch.show('nearMateNum: ' .. tostring(nearMateNum) .. ', less: ' .. tostring(less))
        -- end
        return clickContext.comboPoints == 1 and
            targetHealth <
            (macroTorch.KS_CP1_Health_group - less * (macroTorch.KS_CP1_Health_group - macroTorch.KS_CP1_Health) / 4) or
            clickContext.comboPoints == 2 and
            targetHealth <
            (macroTorch.KS_CP2_Health_group - less * (macroTorch.KS_CP2_Health_group - macroTorch.KS_CP2_Health) / 4) or
            clickContext.comboPoints == 3 and
            targetHealth <
            (macroTorch.KS_CP3_Health_group - less * (macroTorch.KS_CP3_Health_group - macroTorch.KS_CP3_Health) / 4) or
            clickContext.comboPoints == 4 and
            targetHealth <
            (macroTorch.KS_CP4_Health_group - less * (macroTorch.KS_CP4_Health_group - macroTorch.KS_CP4_Health) / 4) or
            clickContext.comboPoints == 5 and
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
        return clickContext.comboPoints == 1 and
            targetHealth < (macroTorch.KS_CP1_Health_group + macroTorch.KS_CP1_Health_raid_pps * more) or
            clickContext.comboPoints == 2 and
            targetHealth < (macroTorch.KS_CP2_Health_group + macroTorch.KS_CP2_Health_raid_pps * more) or
            clickContext.comboPoints == 3 and
            targetHealth < (macroTorch.KS_CP3_Health_group + macroTorch.KS_CP3_Health_raid_pps * more) or
            clickContext.comboPoints == 4 and
            targetHealth < (macroTorch.KS_CP4_Health_group + macroTorch.KS_CP4_Health_raid_pps * more) or
            clickContext.comboPoints == 5 and
            targetHealth < (macroTorch.KS_CP5_Health_group + macroTorch.KS_CP5_Health_raid_pps * more)
    else
        -- fight alone or pvp
        return clickContext.comboPoints == 1 and targetHealth < macroTorch.KS_CP1_Health or
            clickContext.comboPoints == 2 and targetHealth < macroTorch.KS_CP2_Health or
            clickContext.comboPoints == 3 and targetHealth < macroTorch.KS_CP3_Health or
            clickContext.comboPoints == 4 and targetHealth < macroTorch.KS_CP4_Health or
            clickContext.comboPoints == 5 and targetHealth < macroTorch.KS_CP5_Health
    end
end

function macroTorch.tryBiteKillshot(clickContext)
    if macroTorch.isKillshotOrLastChance(clickContext) then
        if clickContext.comboPoints > 0 then
            macroTorch.player.cast('Ferocious Bite')
        else
            if macroTorch.player.isBehindTarget then
                macroTorch.safeShred(clickContext)
            end
            macroTorch.readyClaw(clickContext)
        end
    end
end

function macroTorch.reshiftMod(clickContext)
    if macroTorch.canDoReshift(clickContext) then
        macroTorch.readyReshift(clickContext)
    end
end

function macroTorch.computeErps(clickContext)
    local erps = clickContext.AUTO_TICK_ERPS
    if macroTorch.isTigerPresent(clickContext) then
        erps = erps + clickContext.TIGER_ERPS
    end
    if macroTorch.isRakePresent(clickContext) then
        erps = erps + clickContext.RAKE_ERPS
    end
    if macroTorch.isRipPresent(clickContext) then
        erps = erps + clickContext.RIP_ERPS
    end
    if macroTorch.isPouncePresent(clickContext) then
        erps = erps + clickContext.POUNCE_ERPS
    end
    if clickContext.berserk then
        erps = erps + clickContext.BERSERK_ERPS
    end
    return erps
end

-- reshift at anytime in battle & not prowling & not ooc when: the current 'enerty restoration per-second' is lesser than '30 - currentEnergyBeforeReshift'
function macroTorch.canDoReshift(clickContext)
    if not macroTorch.player.isInCombat or clickContext.prowling or clickContext.ooc then
        return false
    end
    return macroTorch.computeReshiftEarning(clickContext) > clickContext.RESHIFT_E_DIFF_THRESHOLD
end

function macroTorch.computeReshiftEarning(clickContext)
    if clickContext.computeReshiftEarning == nil then
        clickContext.computeReshiftEarning = clickContext.RESHIFT_ENERGY - clickContext.TIGER_E - macroTorch.player.mana -
            (macroTorch.computeErps(clickContext) * 1.5)
    end
    return clickContext.computeReshiftEarning
end

-- tiger fury when near
function macroTorch.keepTigerFury(clickContext)
    if macroTorch.isTigerPresent(clickContext) or macroTorch.target.distance > 20 then
        return
    end
    macroTorch.safeTigerFury(clickContext)
end

function macroTorch.keepRip(clickContext)
    if not macroTorch.isFightStarted(clickContext) or macroTorch.isRipPresent(clickContext) or clickContext.comboPoints < 5 or macroTorch.target.isImmune('Rip') or macroTorch.isKillshotOrLastChance(clickContext) then
        return
    end
    -- boost attack power to rip when fighting world boss or player-controlled target
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst(clickContext)
    end
    macroTorch.safeRip(clickContext)
end

-- originates from keepRip, but no need to rip at 5cp
function macroTorch.quickKeepRip(clickContext)
    -- quick keep rip, do at any cp
    if not macroTorch.isFightStarted(clickContext) or macroTorch.isRipPresent(clickContext) or clickContext.comboPoints == 0 or macroTorch.target.isImmune('Rip') or macroTorch.isKillshotOrLastChance(clickContext) then
        return
    end
    -- boost attack power to rip when fighting world boss or player-controlled target
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst(clickContext)
    end
    macroTorch.safeRip(clickContext)
end

function macroTorch.keepRake(clickContext)
    -- in no condition rake on 5cp
    if not macroTorch.isFightStarted(clickContext) or clickContext.comboPoints == 5 or macroTorch.isRakePresent(clickContext) or macroTorch.target.isImmune('Rake') or macroTorch.isKillshotOrLastChance(clickContext) then
        return
    end
    -- boost attack power to rake when fighting world boss
    if macroTorch.target.classification == 'worldboss' and macroTorch.isNearBy(clickContext) then
        macroTorch.atkPowerBurst(clickContext)
    end
    macroTorch.safeRake(clickContext)
end

function macroTorch.isNearBy(clickContext)
    if clickContext.isNearBy == nil then
        clickContext.isNearBy = macroTorch.target.distance <= 3
    end
    return clickContext.isNearBy
end

-- no FF in: 1) melee range if other techs can use, 2) when ooc 3) immune 4) killshot 5) eager to reshift 6) cp5 7) player not in combat 8) prowling 9) target not in combat
-- all in all: if in combat and there's nothing to do, then FF, no matter if FF debuff present, we wish to trigger more ooc through instant FFs
function macroTorch.keepFF(clickContext)
    local player = macroTorch.player
    if clickContext.ooc
        or macroTorch.target.isImmune('Faerie Fire (Feral)')
        or macroTorch.canDoReshift(clickContext)
        or not macroTorch.isFightStarted(clickContext)
        or not macroTorch.target.isInCombat
        or macroTorch.isNearBy(clickContext) and (
            player.mana >= clickContext.CLAW_E and clickContext.comboPoints < 5
            or player.mana >= clickContext.BITE_E and clickContext.comboPoints == 5
            or player.mana >= clickContext.RAKE_E and not macroTorch.isRakePresent(clickContext) and not macroTorch.target.isImmune('Rake') and clickContext.comboPoints < 5
            or player.mana >= clickContext.RIP_E and not macroTorch.isRipPresent(clickContext) and not macroTorch.target.isImmune('Rip') and clickContext.comboPoints == 5
            or player.mana >= clickContext.RIP_E and not macroTorch.isRipPresent(clickContext) and not macroTorch.target.isImmune('Rip') and clickContext.comboPoints > 0 and macroTorch.isTrivialBattleOrPvp(clickContext)
            or macroTorch.isTrivialBattleOrPvp(clickContext) and macroTorch.isFFPresent(clickContext) and (player.mana + macroTorch.computeErps(clickContext)) >= clickContext.TIGER_E
            or clickContext.comboPoints == 5
            or macroTorch.isKillshotOrLastChance(clickContext)) then
        return
    end
    macroTorch.safeFF(clickContext)
end

function macroTorch.isTigerPresent(clickContext)
    if clickContext.isTigerPresent == nil then
        clickContext.isTigerPresent = macroTorch.toBoolean(macroTorch.player.hasBuff('Ability_Mount_JungleTiger') and
            macroTorch.tigerLeft(clickContext) > 0)
    end
    return clickContext.isTigerPresent
end

function macroTorch.tigerLeft(clickContext)
    if clickContext.tigerLeft == nil then
        local tigerLeft = 0
        if not not macroTorch.context.tigerTimer then
            tigerLeft = clickContext.TIGER_DURATION - (GetTime() - macroTorch.context.tigerTimer)
            if tigerLeft < 0 then
                tigerLeft = 0
            end
        else
            tigerLeft = 0
        end
        clickContext.tigerLeft = tigerLeft
    end
    return clickContext.tigerLeft
end

function macroTorch.isRipPresent(clickContext)
    if clickContext.isRipPresent == nil then
        clickContext.isRipPresent = macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_GhoulFrenzy') and
            macroTorch.ripLeft(clickContext) > 0)
    end
    return clickContext.isRipPresent
end

function macroTorch.ripLeft(clickContext)
    if clickContext.ripLeft == nil then
        local lastLandedRipTime = macroTorch.peekLandEvent('Rip')
        if not lastLandedRipTime then
            clickContext.ripLeft = 0
        else
            -- rip的连击点数每增一点，持续时间加2s
            local ripDur = macroTorch.RIP_DURATION
            if macroTorch.context.lastRipAtCp then
                ripDur = ripDur + (macroTorch.context.lastRipAtCp - 1) * 2
            end
            -- if Savagery idol equipped, reduce rip duration by 10%
            if macroTorch.context.lastRipEquippedSavagery then
                ripDur = ripDur * 0.9
            end
            local ripLeft = ripDur - (GetTime() - lastLandedRipTime)
            if ripLeft < 0 then
                ripLeft = 0
            end
            clickContext.ripLeft = ripLeft
        end
    end
    return clickContext.ripLeft
end

function macroTorch.isRakePresent(clickContext)
    if clickContext.isRakePresent == nil then
        clickContext.isRakePresent = macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_Druid_Disembowel') and
            macroTorch.rakeLeft(clickContext) > 0)
    end
    return clickContext.isRakePresent
end

function macroTorch.rakeLeft(clickContext)
    if clickContext.rakeLeft == nil then
        local lastLandedRakeTime = macroTorch.peekLandEvent('Rake')
        if not lastLandedRakeTime then
            clickContext.rakeLeft = 0
        else
            local rakeDuration = macroTorch.RAKE_DURATION
            if macroTorch.context.lastRakeEquippedSavagery then
                rakeDuration = rakeDuration * 0.9
            end
            local rakeLeft = rakeDuration - (GetTime() - lastLandedRakeTime)
            if rakeLeft < 0 then
                rakeLeft = 0
            end
            clickContext.rakeLeft = rakeLeft
        end
    end
    return clickContext.rakeLeft
end

function macroTorch.isFFPresent(clickContext)
    if clickContext.isFFPresent == nil then
        clickContext.isFFPresent = macroTorch.toBoolean(macroTorch.target.hasBuff('Spell_Nature_FaerieFire') and
            macroTorch.ffLeft(clickContext) > 0)
    end
    return clickContext.isFFPresent
end

function macroTorch.ffLeft(clickContext)
    if clickContext.ffLeft == nil then
        local ffLeft = 0
        if not not macroTorch.context.ffTimer then
            ffLeft = clickContext.FF_DURATION - (GetTime() - macroTorch.context.ffTimer)
            if ffLeft < 0 then
                ffLeft = 0
            end
        else
            ffLeft = 0
        end
        clickContext.ffLeft = ffLeft
    end
    return clickContext.ffLeft
end

function macroTorch.isPouncePresent(clickContext)
    if clickContext.isPouncePresent == nil then
        clickContext.isPouncePresent = macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_Druid_SupriseAttack') and
            macroTorch.pounceLeft(clickContext) > 0)
    end
    return clickContext.isPouncePresent
end

function macroTorch.pounceLeft(clickContext)
    if clickContext.pounceLeft == nil then
        local lastLandedPounceTime = macroTorch.peekLandEvent('Pounce')
        if not lastLandedPounceTime then
            clickContext.pounceLeft = 0
        else
            local pounceLeft = clickContext.POUNCE_DURATION - (GetTime() - lastLandedPounceTime)
            if pounceLeft < 0 then
                pounceLeft = 0
            end
            clickContext.pounceLeft = pounceLeft
        end
    end
    return clickContext.pounceLeft
end

function macroTorch.readyReshift(clickContext)
    if macroTorch.player.isSpellReady('Reshift') then
        macroTorch.show('Reshift!!! energy = ' ..
            macroTorch.player.mana ..
            ', earning: ' ..
            macroTorch.computeReshiftEarning(clickContext) .. ', tigerLeft = ' .. macroTorch.tigerLeft(clickContext))
        macroTorch.player.cast('Reshift')
        return true
    end
    return false
end

function macroTorch.safeShred(clickContext)
    return macroTorch.player.mana >= clickContext.SHRED_E and macroTorch.readyShred(clickContext)
end

function macroTorch.readyShred(clickContext)
    if macroTorch.player.isSpellReady('Shred') then
        macroTorch.player.cast('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw(clickContext)
    return macroTorch.player.mana >= clickContext.CLAW_E and macroTorch.readyClaw(clickContext)
end

function macroTorch.readyClaw(clickContext)
    if macroTorch.player.isSpellReady('Claw') then
        macroTorch.player.cast('Claw')
        return true
    end
    return false
end

function macroTorch.safeRake(clickContext)
    if macroTorch.player.isSpellReady('Rake') and macroTorch.isGcdOk(clickContext) and macroTorch.player.mana >= clickContext.RAKE_E and macroTorch.isNearBy(clickContext) then
        macroTorch.show('Rake!!! Rake present: ' ..
            tostring(macroTorch.isRakePresent(clickContext)) ..
            ', bleed idol equipped: ' ..
            tostring(macroTorch.player.isRelicEquipped('Idol of Savagery')))
        macroTorch.context.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        macroTorch.player.cast('Rake')
        return true
    end
    return false
end

function macroTorch.safeRip(clickContext)
    if macroTorch.player.isSpellReady('Rip') and macroTorch.isGcdOk(clickContext) and macroTorch.player.mana >= clickContext.RIP_E and macroTorch.isNearBy(clickContext) then
        macroTorch.show('Rip!!! At cp: ' ..
            tostring(clickContext.comboPoints) ..
            ', rip present: ' ..
            tostring(macroTorch.isRipPresent(clickContext)) ..
            ', bleed idol equipped: ' ..
            tostring(macroTorch.player.isRelicEquipped('Idol of Savagery')))
        macroTorch.context.lastRipEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        macroTorch.player.cast('Rip')
        macroTorch.context.lastRipAtCp = clickContext.comboPoints
        return true
    end
    return false
end

function macroTorch.isGcdOk(clickContext)
    if clickContext.isGcdOk == nil then
        clickContext.isGcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
    end
    return clickContext.isGcdOk
end

function macroTorch.safeBite(clickContext)
    return macroTorch.player.mana >= clickContext.BITE_E and macroTorch.readyBite(clickContext)
end

function macroTorch.readyBite(clickContext)
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.player.cast('Ferocious Bite')
        macroTorch.show('Bite at energy: ' .. macroTorch.player.mana .. ', ooc: ' .. tostring(clickContext.ooc))
        return true
    end
    return false
end

function macroTorch.safeFF(clickContext)
    if macroTorch.player.isSpellReady('Faerie Fire (Feral)') and macroTorch.isGcdOk(clickContext) then
        macroTorch.show('FF!!! FF present: ' ..
            tostring(macroTorch.isFFPresent(clickContext)) ..
            ', FF left: ' ..
            tostring(macroTorch.ffLeft(clickContext)) ..
            ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. clickContext.comboPoints)
        macroTorch.player.cast('Faerie Fire (Feral)')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeTigerFury(clickContext)
    if macroTorch.player.isSpellReady('Tiger\'s Fury') and macroTorch.tigerSelfGCD(clickContext) == 0 and macroTorch.player.mana >= clickContext.TIGER_E then
        -- macroTorch.show('Tiger!!! Tiger present: ' ..
        --     tostring(macroTorch.isTigerPresent(clickContext)) ..
        --     ', tiger left: ' .. macroTorch.tigerLeft(clickContext))
        macroTorch.player.cast('Tiger\'s Fury')
        macroTorch.context.tigerTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.tigerSelfGCD(clickContext)
    if clickContext.tigerSelfGCD == nil then
        if not macroTorch or not macroTorch.context or not macroTorch.context.tigerTimer then
            clickContext.tigerSelfGCD = 0
        else
            local selfGCDLeft = 1 - (GetTime() - macroTorch.context.tigerTimer)
            if selfGCDLeft < 0 then
                selfGCDLeft = 0
            end
            clickContext.tigerSelfGCD = selfGCDLeft
        end
    end
    return clickContext.tigerSelfGCD
end

function macroTorch.safePounce(clickContext)
    if macroTorch.player.isSpellReady('Pounce') and macroTorch.isGcdOk(clickContext) and macroTorch.player.mana >= clickContext.POUNCE_E and macroTorch.isNearBy(clickContext) then
        macroTorch.player.cast('Pounce')
        return true
    end
    return false
end

function macroTorch.readyCower(clickContext)
    if macroTorch.player.isSpellReady('Cower') then
        macroTorch.show('current threat: ' .. macroTorch.player.threatPercent .. ' doing ready cower!!!')
        macroTorch.player.cast('Cower')
        return true
    end
    return false
end

-- burst through boosting attack power
function macroTorch.atkPowerBurst(clickContext)
    macroTorch.player.useTrinket2()
    -- juju power
    if not macroTorch.player.hasBuff('INV_Misc_MonsterScales_11') and macroTorch.player.hasItem('Juju Power') and not macroTorch.target.isPlayerControlled then
        macroTorch.player.use('Juju Power', true)
    end
end

function macroTorch.druidBuffs()
    local clickContext = {}
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
    local clickContext = {}
    local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
    -- if in melee range then use bear bash else bear charge
    -- if not in bear form, be bear first
    if not inBearForm then
        macroTorch.player.cast('Dire Bear Form')
    end
    if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
        macroTorch.player.cast('Enrage')
    end
    if macroTorch.isNearBy(clickContext) then
        macroTorch.player.cast('Bash')
    else
        if macroTorch.isSpellExist('Feral Charge', 'spell') then
            macroTorch.player.cast('Feral Charge')
        end
    end
end

function macroTorch.druidDefend()
    local clickContext = {}
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
    local clickContext = {}
    -- if target is of type beast or dragonkin, use Hibernate, else use [Entangling Roots]
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.cast('Hibernate')
    else
        macroTorch.player.cast('Entangling Roots')
    end
end

function macroTorch.bearAoe()
    local clickContext = {}
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
    local clickContext = {}
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
    macroTorch.safeFF(clickContext)
end

-- for some problematic battle
function macroTorch.bruteForce()
    local clickContext = {}

    local player = macroTorch.player
    local target = macroTorch.target

    clickContext.prowling = player.isProwling
    clickContext.berserk = player.isBerserk
    clickContext.comboPoints = player.comboPoints
    clickContext.ooc = player.isOoc
    clickContext.isBehind = target.isCanAttack and player.isBehindTarget

    -- 1.health & mana saver in combat *
    if macroTorch.inCombat then
        macroTorch.combatUrgentHPRestore(clickContext)
        -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
    end
    -- 3.keep autoAttack, in combat & not prowling *
    if macroTorch.inCombat then
        player.startAutoAtk()
    end
    -- 4.rushMod, incuding trinckets, berserk and potions *
    if IsShiftKeyDown() then
        if not clickContext.berserk then
            player.cast('Berserk')
        end
        -- juju flurry
        if not player.hasBuff('INV_Misc_MonsterScales_17') and not player.isFormActive('Dire Bear Form') then
            if player.hasItem('Juju Flurry') then
                player.use('Juju Flurry', true)
            end
        end
        macroTorch.atkPowerBurst(clickContext)
    end
    if macroTorch.isKillshotOrLastChance(clickContext) then
        if clickContext.comboPoints > 0 then
            player.cast('Ferocious Bite')
        else
            macroTorch.readyClaw(clickContext)
        end
    else
        macroTorch.keepTigerFury(clickContext)
        if clickContext.comboPoints < 5 then
            if not target.isImmune('Rake') and not macroTorch.isRakePresent(clickContext) then
                player.cast('Rake')
            else
                if clickContext.isBehind and (not macroTorch.isRipPresent(clickContext) and not macroTorch.isRakePresent(clickContext) and not macroTorch.isPouncePresent(clickContext) or clickContext.ooc) then
                    player.cast('Shred')
                else
                    macroTorch.readyClaw(clickContext)
                end
            end
        else
            if macroTorch.isRipPresent(clickContext) or macroTorch.target.isImmune('Rip') then
                player.cast('Ferocious Bite')
            else
                player.cast('Rip')
            end
        end
    end
    macroTorch.keepFF(clickContext)
    -- 12.energy res mod
    macroTorch.reshiftMod(clickContext)
end
