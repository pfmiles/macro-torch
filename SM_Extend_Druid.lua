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
        macroTorch.RIP_BASE_DURATION = 10

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
                macroTorch.RIP_BASE_DURATION
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

    -- 这是猫德一键输出宏逻辑，目标是dps最大化，利用好当前猫德伤害机制，利用好每一点能量，尽可能使能量不溢出、也不因为能量不足而卡技能
    --- The 'E' key regular dps function for feral cat druid
    --- if rough, all combats are considered short
    function obj.catAtk(rough)
        -- clickContext是单次点击范围内的context，用作取值cache优化
        local clickContext = {}

        clickContext.rough = macroTorch.toBoolean(rough)

        -- energy costs of certain skills
        clickContext.POUNCE_E = 50
        clickContext.CLAW_E = macroTorch.computeClaw_E()
        clickContext.SHRED_E = macroTorch.computeShred_E()
        clickContext.RAKE_E = macroTorch.computeRake_E()
        clickContext.BITE_E = 35
        clickContext.RIP_E = 30
        clickContext.TIGER_E = macroTorch.computeTiger_E()

        -- durations of certain time lasting spell effects
        clickContext.TIGER_DURATION = macroTorch.computeTiger_Duration()
        macroTorch.RIP_BASE_DURATION = 10
        macroTorch.RAKE_DURATION = 9
        clickContext.FF_DURATION = 40
        clickContext.POUNCE_DURATION = 18

        -- erps is short for energy restoration per second, 这里给出了当前游戏阶段猫德拥有的所有回能机制的每秒回能期望
        clickContext.AUTO_TICK_ERPS = 20 / 2
        clickContext.TIGER_ERPS = 10 / 3
        clickContext.RAKE_ERPS = macroTorch.computeRake_Erps()
        clickContext.RIP_ERPS = macroTorch.computeRip_Erps()
        clickContext.POUNCE_ERPS = macroTorch.computePounce_Erps()
        clickContext.BERSERK_ERPS = 20 / 2

        -- the threat/aggro threshold to use cower
        macroTorch.COWER_THREAT_THRESHOLD = 75
        -- the energy resetting value after reshift
        -- TODO reshift energy restore should consider the head enchant: whether the wolfheart enchant exists
        clickContext.RESHIFT_ENERGY = 60
        clickContext.RESHIFT_E_DIFF_THRESHOLD = 0
        -- the health line of urgent, whether to use some life saving items/spells
        clickContext.PLAYER_URGENT_HP_THRESHOLD = 15

        local player = macroTorch.player
        local target = macroTorch.target
        clickContext.prowling = player.isProwling
        clickContext.berserk = player.isBerserk
        clickContext.comboPoints = player.comboPoints
        clickContext.ooc = player.isOoc
        clickContext.isBehind = target.isCanAttack and player.isBehindTarget

        clickContext.isInBearForm = player.isFormActive('Dire Bear Form')
        clickContext.isInCatForm = player.isFormActive('Cat Form')

        clickContext.isImmuneRake = target.isImmune('Rake')
        clickContext.isImmuneRip = target.isImmune('Rip')

        -- normal relic指接下来的战斗默认穿戴的relic，若目标免疫流血效果则使用Ferocity, 否则使用Savagery
        if clickContext.isImmuneRip then
            clickContext.normalRelic = 'Idol of Ferocity'
        else
            clickContext.normalRelic = 'Idol of Savagery'
        end

        -- 0.idol recover, equip the current normal relic if not equipped
        macroTorch.recoverNormalRelic(clickContext, clickContext.normalRelic)

        -- 1.health & mana saver in combat *
        if macroTorch.isFightStarted(clickContext) then
            macroTorch.combatUrgentHPRestore(clickContext)
            -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态读到的是energy不是真正的mana，这个逻辑后续再写
        end
        -- 2.targetEnemy，自动切换目标，如果当前目标不满足存在且是可攻击目标的条件
        if not target.isCanAttack then
            player.targetEnemy()
        else
            -- 3.keep autoAttack, in combat & not prowling *
            if macroTorch.isFightStarted(clickContext) then
                player.startAutoAtk()
            end
            -- 4.rushMod, including trinkets, berserk and potions, normally triggered by holding shift while fighting
            macroTorch.burstMod(clickContext)
            -- roughly bear form logic branch, TODO 其实bear形态逻辑应该完全从catAtck逻辑中剥离出来，在最上层的宏里面通过当前形态来路由
            if clickContext.isInBearForm then
                macroTorch.bearAtk(clickContext)
                return
            end
            -- 5.opener mod, 因为Ravage差不多可以秒掉1500血以内的目标，除此之外均使用Pounce以增加后续claw的伤害
            if clickContext.prowling then
                if not target.isImmune('Pounce') and target.health >= 1500 then
                    macroTorch.safePounce(clickContext)
                else
                    player.cast('Ravage')
                end
            end

            -- 7.oocMod: 没有潜行且ooc 或 前行但目标正在攻击我
            if not clickContext.prowling or target.isAttackingMe then
                -- ooc = Omen of Clarity, 为施法节能状态, 这里实现该状态的技能逻辑，目的为尽可能dps最大化
                macroTorch.oocMod(clickContext)
            end
            -- 6.termMod: 终结技模块，实际上这里就只是bite模块，因为rip在单独自己的模块里处理了
            macroTorch.termMod(clickContext)
            -- 8.OT mod, 处理快要OT时的情况，比如使用Cower降低威胁值，或直接无敌药水暂时避免boss攻击我
            macroTorch.otMod(clickContext)
            -- 9.tiger fury模块，战斗中时刻保持tiger fury buff
            macroTorch.keepTigerFury(clickContext)
            -- 10.debuffMod, including rip, rake and FF
            if clickContext.rough or macroTorch.isTrivialBattleOrPvp(clickContext) then
                -- 如果是pvp或者预判出本次战斗持续时间很短，则无须做5星rip，直接低星rip让claw受益即可，因为rip是持续流血效果，回报周期长，目标坚持不了那么久
                macroTorch.quickKeepRip(clickContext)
            else
                -- 非pvp，且战斗时间相对较长，做5星rip最大化其流血伤害
                macroTorch.keepRip(clickContext)
            end
            -- 保持rake流血效果，如果目标不免疫流血的话
            macroTorch.keepRake(clickContext)
            -- 保持FF(野性精灵之火)效果，如果目标不免疫FF的话; 且由于精灵之火的释放成本很低，无须消耗能量，成本仅仅是1s的GCD，且跟其它攻击技能或普通攻击一样有概率触发ooc，因此我会在“没有别的事情可干”的时候释放一发精灵之火，即使目标身上已有该效果
            macroTorch.keepFF(clickContext)
            -- 11.普通攻击技能模块，攒星的主要技能，主要是claw和shred, 根据实测结果，依据目标身上的流血效果数量和当前自己的站位而灵活选择claw或shred释放
            if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 and (macroTorch.isRakePresent(clickContext) or clickContext.isImmuneRake) then
                macroTorch.regularAttack(clickContext)
            end
            -- 12.reshift模块，意思是从cat形态变身到cat形态(即形态不实际改变的“变身”，这是乌龟服特有的技能)，其作用是将自身能量固定重置为60；此模块需要判断当前释放reshift是否“划算”从而决定是否释放
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

function macroTorch.burstMod(clickContext)
    local player = macroTorch.player
    local target = macroTorch.target
    -- put on the flags
    if IsShiftKeyDown() then
        if not macroTorch.context.burstFlags then
            macroTorch.context.burstFlags = {}
        end
    end
    -- consume the flags
    if macroTorch.context.burstFlags then
        local flags = macroTorch.context.burstFlags

        -- berserk
        if not flags.berserk then
            if not clickContext.berserk then
                player.cast('Berserk')
            end
            flags.berserk = true
            return
        end

        -- juju flurry
        if not flags.jujuFlurry then
            if not player.hasBuff('INV_Misc_MonsterScales_17') and not clickContext.isInBearForm and player.hasItem('Juju Flurry') and player.isItemInBagCooledDown('Juju Flurry') and not target.isPlayerControlled then
                player.use('Juju Flurry', true)
            end
            flags.jujuFlurry = true
            return
        end

        -- ATK power
        if not flags.atkPowerBurst then
            macroTorch.atkPowerBurst(clickContext)
            flags.atkPowerBurst = true
            return
        end

        -- reset flags if all set
        if flags.berserk and flags.jujuFlurry and flags.atkPowerBurst then
            macroTorch.context.burstFlags = nil
        end
    end
end

function macroTorch.recoverNormalRelic(clickContext, relicName)
    if not macroTorch.target.isCanAttack then
        return
    end
    local player = macroTorch.player
    if not player.isFormActive('Cat Form') then
        return
    end
    if not player.hasItem(relicName) or player.isRelicEquipped(relicName) then
        return
    end
    if not macroTorch.isFightStarted(clickContext) or (clickContext.comboPoints < 5 and not clickContext.ooc and player.mana + (macroTorch.computeErps(clickContext) * 2.5) <= 100) then
        -- macroTorch.show('Recovering normal relic at energy: ' .. player.mana)
        macroTorch.player.ensureRelicEquipped(relicName)
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

function macroTorch.computeRake_Erps()
    local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
    if ancientBrutalityRank == 0 then
        return 0  -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 3  -- Base 3 seconds

    -- Check if Savagery idol was equipped when Rake was cast (snapshot mechanic)
    if macroTorch.context and macroTorch.context.lastRakeEquippedSavagery then
        tickInterval = tickInterval * 0.9  -- 10% shorter tick interval
    end

    return energyPerTick / tickInterval
end

function macroTorch.computeRip_Erps()
    local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
    if ancientBrutalityRank == 0 then
        return 0  -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 2  -- Base 2 seconds

    -- Check if Savagery idol was equipped when Rip was cast (snapshot mechanic)
    if macroTorch.context and macroTorch.context.lastRipEquippedSavagery then
        tickInterval = tickInterval * 0.9  -- 10% shorter tick interval
    end

    return energyPerTick / tickInterval
end

function macroTorch.computePounce_Erps()
    local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
    if ancientBrutalityRank == 0 then
        return 0  -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 3  -- Pounce tick interval is always 3 seconds, not affected by equipment

    return energyPerTick / tickInterval
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
macroTorch.setTraceSpellImmune('Faerie Fire (Feral)', 'Spell_Nature_FaerieFire')

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
    -- Count active bleeding effects
    local bleedCount = 0
    if macroTorch.isRakePresent(clickContext) then
        bleedCount = bleedCount + 1
    end
    if macroTorch.isRipPresent(clickContext) then
        bleedCount = bleedCount + 1
    end
    if macroTorch.isPouncePresent(clickContext) then
        bleedCount = bleedCount + 1
    end

    -- Determine which methods to use based on ooc
    -- ooc doesn't consume energy, so use ready methods instead of safe methods
    local shredMethod = clickContext.ooc and macroTorch.readyShred or macroTorch.safeShred
    local clawMethod = clickContext.ooc and macroTorch.readyClaw or macroTorch.safeClaw

    -- New logic based on bleeding count:
    -- 0-1 bleeding: prioritize shred (if behind and not failed)
    -- 2 bleeding: prioritize claw (even with ooc, because both readyShred and readyClaw don't consume energy)
    -- 3+ bleeding: always use claw, even with ooc
    if bleedCount <= 1 then
        -- 0 or 1 bleeding: use shred if conditions met
        if clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed then
            shredMethod(clickContext)
        else
            clawMethod(clickContext)
        end
    elseif bleedCount == 2 then
        -- 2 bleeding: prioritize claw, but if ooc and behind then still use shred
        if clickContext.ooc and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed then
            shredMethod(clickContext)
        else
            clawMethod(clickContext)
        end
    else
        -- 3+ bleeding: always use claw
        clawMethod(clickContext)
    end
end

function macroTorch.isTrivialBattleOrPvp(clickContext)
    return macroTorch.target.isPlayerControlled or
            macroTorch.isTrivialBattle(clickContext)
end

-- determine whether this would be a short battle(the target will die very soon)
function macroTorch.isTrivialBattle(clickContext)
    if clickContext.isTrivialBattle == nil then
        local trivialDieTime = 25
        -- if the target's max health is less than we attack 15s with 500dps each person
        clickContext.isTrivialBattle = macroTorch.target.willDieInSeconds(trivialDieTime) or
                macroTorch.target.healthMax <=
                        (macroTorch.player.mateNearMyTargetCount + 1) * 500 * trivialDieTime
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
        clickContext.isFightStarted = (not clickContext.prowling and
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
    -- 排除掉训练木桩的情况
    if string.find(macroTorch.target.name, 'Training Dummy') then
        return
    end
    local player = macroTorch.player
    local target = macroTorch.target
    if not player.isInCombat
            or not target.isInCombat
            or clickContext.prowling
            or macroTorch.isKillShotOrLastChance(clickContext)
            or not target.isCanAttack
            or target.isPlayerControlled
            or not macroTorch.player.isInGroup then
        return
    end
    if target.isAttackingMe and not player.isSpellReady('Cower') and target.classification == 'worldboss' then
        -- boss正在攻击我且Cower没好，直接使用无敌药水
        player.use('Invulnerability Potion', true)
    end

    -- 当目前威胁值大于一定阈值，使用cower降低威胁值; TODO 这里需要使用safeCower，且应考虑利用reshift回能，若能量不足的话;回能逻辑或许不必专门写在这里，而是交给通用的回能模块
    if macroTorch.canDoReshift(clickContext) then
        return
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then
        macroTorch.readyCower(clickContext)
    end
end

function macroTorch.termMod(clickContext)
    -- 若目标已经可斩杀，优先斩杀，否则做常规的5星撕咬
    macroTorch.tryBiteKillShot(clickContext)
    macroTorch.cp5Bite(clickContext)
end

function macroTorch.cp5Bite(clickContext)
    -- 若目标身上还不存在rip效果，一般5星时是优先rip而非bite的，除非目标本来就免疫流血
    if clickContext.comboPoints == 5 and (clickContext.isImmuneRip or macroTorch.isRipPresent(clickContext)) then
        -- bite有个机制：会将当前能量扣除使用bite的能量后剩余的能量转化为额外的伤害，若ooc则更是能将当前所有energy都转化为伤害打出
        -- 但经过实测，让bite转换多余能量还不如将多余能量打成其它技能收益来得大；ooc时bite也不如先用其它技能用掉ooc效果再bite，因此这里设置一个“bite之前泄能逻辑”来最大化dps
        -- 需要注意的是，泄能逻辑需要考虑一个特殊情况：bite是会刷新目标身上的流血效果的，因此为了不让rip效果断掉，我仅在目标身上流血效果还剩足够时间时泄能，若rip效果快没了，则需要马上bite刷新rip时间，否则若让rip断掉的话得不偿失；
        -- 这里定义一个“rip效果快结束了”概念的时间，来决定当前是否该泄能；目前只考虑rip，暂不考虑rake效果，因为rake持续时间本来就很短(默认9s)，在当前游戏阶段的装备条件下，很难连续暴击在9s内攒齐5星来打bite刷新双流血效果(技能暴击将一次性攒2颗星)，因此目前暂不强求rake效果一定被bite续上；only discharge energy when rip time left is greater then 1.8s
        if not ((macroTorch.isRipPresent(clickContext) and macroTorch.ripLeft(clickContext) <= 1.8)) then
            macroTorch.energyDischargeBeforeBite(clickContext)
        end
        -- 以是否ooc判断当前该使用ready版本或是safe版本逻辑
        if clickContext.ooc then
            macroTorch.readyBite(clickContext)
        else
            macroTorch.safeBite(clickContext)
        end
    end
end

-- 撕咬前的泄能逻辑: 当前多余能量用作撕咬加成不划算，将其拆成2个技能使用
function macroTorch.energyDischargeBeforeBite(clickContext)
    -- Try to discharge energy with regular attack first
    if clickContext.ooc
            or (macroTorch.player.mana >= clickContext.BITE_E + clickContext.SHRED_E and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed)
            or macroTorch.player.mana >= clickContext.BITE_E + clickContext.CLAW_E then
        macroTorch.regularAttack(clickContext)
        return
    end

    -- If regular attack not possible and no Rake, use Rake
    if not macroTorch.isRakePresent(clickContext) and macroTorch.player.mana >= clickContext.BITE_E + clickContext.RAKE_E then
        macroTorch.safeRake(clickContext)
    end
end

function macroTorch.oocMod(clickContext)
    if not clickContext.ooc then
        return
    end
    -- 如果目标已经可斩杀，直接斩杀，不用考虑其它逻辑了
    macroTorch.tryBiteKillShot(clickContext)
    if clickContext.comboPoints < 5 then
        -- 使用普通攒星逻辑来用掉本次ooc的机会
        macroTorch.regularAttack(clickContext)
    else
        -- 已经5星，则调用5星bite模块，让bite模块去处理各种情况
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

-- 预测判断当前是否只有最后一次机会攻击目标了，目标可能快死了
function macroTorch.isKillShotOrLastChance(clickContext)
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

-- 判断目标是否快死了，我只有最后一次攻击机会了，那么此时应该尽量用bite把当前剩余的星都用掉从而最大化dps,不浪费星
function macroTorch.tryBiteKillShot(clickContext)
    if macroTorch.isKillShotOrLastChance(clickContext) then
        if clickContext.comboPoints > 0 then
            macroTorch.player.cast('Ferocious Bite')
        else
            -- 如果当前没星的话也只能做普通攻击
            macroTorch.regularAttack(clickContext)
        end
    end
end

function macroTorch.reshiftMod(clickContext)
    -- 如果当前做reshift“划算”，则做reshift
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

-- 判断当前做reshift是否划算，结合当前能量余量、当前的总ERPS值、以及当前身上是否有tiger fury buff来综合判断
function macroTorch.canDoReshift(clickContext)
    if not macroTorch.player.isInCombat or clickContext.prowling or clickContext.ooc then
        return false
    end
    return macroTorch.computeReshiftEarning(clickContext) > clickContext.RESHIFT_E_DIFF_THRESHOLD
end

-- 计算当前如果做reshift能“赚”多少能量
function macroTorch.computeReshiftEarning(clickContext)
    if clickContext.computeReshiftEarning == nil then
        -- 由于每时每刻身上都保持tiger fury是默认硬性要求，而reshift释放后会清掉身上的tiger fury效果，因此reshift后真正“赚”的能量需要扣除reshift后一定会再补放tiger fury的消耗
        -- 当前的“赚取”能量计算方法逻辑为：reshift重置到的能量(60) 减去固定补tiger的能量，再减去reshift前身上剩余的能量，再减去当前ERPS值在1.5s GCD(这是reshift释放后的GCD)后的预期恢复能量值，若是正数就代表有得赚,即此时reshift值得做
        clickContext.computeReshiftEarning = clickContext.RESHIFT_ENERGY - clickContext.TIGER_E - macroTorch.player.mana -
                (macroTorch.computeErps(clickContext) * 1.5)
    end
    return clickContext.computeReshiftEarning
end

-- tiger fury when near
function macroTorch.keepTigerFury(clickContext)
    -- 在距离目标20码以内才使用tiger fury，避免过早使用浪费buff时间
    if macroTorch.isTigerPresent(clickContext) or macroTorch.target.distance > 20 then
        return
    end
    macroTorch.safeTigerFury(clickContext)
end

-- 普通版的rip逻辑，与快战版不同，普通版rip逻辑力求rip持续伤害最大化，因此只会打5星rip
function macroTorch.keepRip(clickContext)
    -- Check preconditions for applying Rip
    if not macroTorch.isFightStarted(clickContext)
            or macroTorch.isRipPresent(clickContext)
            or clickContext.comboPoints < 5
            or clickContext.isImmuneRip
            or macroTorch.isKillShotOrLastChance(clickContext)
            or not macroTorch.isNearBy(clickContext) then
        return
    end

    -- Boost attack power for important targets
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst(clickContext)
    end

    -- 普通版rip逻辑会要求尽量在rip时穿戴流血idol(Idol of Savagery)
    -- Switch relic if needed and apply Rip
    local shouldEquipSavagery = not clickContext.rough and not macroTorch.isTrivialBattleOrPvp(clickContext)
    macroTorch.dischargeEnergyChangeRelicAndRip(clickContext, shouldEquipSavagery)
end

-- energy discharge needed due to possible energy overflow before rip
function macroTorch.dischargeEnergyChangeRelicAndRip(clickContext, equipSavagery)
    -- ooc: just discharge energy
    if clickContext.ooc then
        macroTorch.regularAttack(clickContext)
        return
    end

    -- need to switch relic and have it
    if equipSavagery and macroTorch.player.hasItem('Idol of Savagery') and not macroTorch.player.isRelicEquipped('Idol of Savagery') then
        -- 2.5s = 1.5s for relic change + 1s for possible ooc
        if macroTorch.player.mana + macroTorch.computeErps(clickContext) * 2.5 > 100 then
            macroTorch.regularAttack(clickContext)
            return
        end
        macroTorch.player.ensureRelicEquipped('Idol of Savagery')
        return
    end

    -- about to rip: check if energy would overflow during 2s (1s rip gcd + 1s possible ooc)
    if macroTorch.player.mana + macroTorch.computeErps(clickContext) * 2 - clickContext.RIP_E > 100 then
        macroTorch.regularAttack(clickContext)
        return
    end

    macroTorch.safeRip(clickContext)
end

-- 快战版的keep rip, 由于预估战斗会很快结束，因此上rip的目的是为了增强claw，而不是为了rip那点流血效果伤害，因此这里只打低星rip以求速度挂上流血
function macroTorch.quickKeepRip(clickContext)
    -- 经过实测，如果此时星数已经大于等于3星，则此时挂rip的收益还不如直接打一发bite,之后再攒到1-2星再打rip，因为目标预计会很快死亡，rip流血效果的回报周期太长，目标活不了那么久，因此不如直接打bite造成直接伤害
    -- 当然了，打bite之前也要考虑先泄能，为了dps最大化,利用好每一点能量
    -- For cp >= 3: discharge and bite
    if clickContext.comboPoints >= 3 and not macroTorch.isRipPresent(clickContext) and not clickContext.isImmuneRip then
        macroTorch.energyDischargeBeforeBite(clickContext)
        macroTorch.safeBite(clickContext)
        return
    end

    -- For cp < 3: quick apply Rip
    -- 这里先排除一些不应该rip的情况
    if not macroTorch.isFightStarted(clickContext)
            or macroTorch.isRipPresent(clickContext)
            or clickContext.comboPoints == 0
            or clickContext.comboPoints >= 3
            or clickContext.isImmuneRip
            or macroTorch.isKillShotOrLastChance(clickContext)
            or not macroTorch.isNearBy(clickContext) then
        return
    end

    -- 如果是重要目标，则rip也要伴随攻强饰品的使用，因为rip的流血伤害随ap加成
    -- Boost attack power for important targets
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst(clickContext)
    end

    -- 在快战版的rip逻辑中，无须要求更换流血idol，因为战斗速度很快，更换idol会带来1.5s GCD，可能得不偿失
    -- Apply Rip without switching relic (rough or pvp mode)
    macroTorch.dischargeEnergyChangeRelicAndRip(clickContext, false)
end

function macroTorch.keepRake(clickContext)
    -- in no condition rake on 5cp
    if not macroTorch.isFightStarted(clickContext) or clickContext.comboPoints == 5 or macroTorch.isRakePresent(clickContext) or clickContext.isImmuneRake or macroTorch.isKillShotOrLastChance(clickContext) then
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
                    or player.mana >= clickContext.RAKE_E and not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake and clickContext.comboPoints < 5
                    or player.mana >= clickContext.RIP_E and not macroTorch.isRipPresent(clickContext) and not clickContext.isImmuneRip and clickContext.comboPoints == 5
                    or player.mana >= clickContext.RIP_E and not macroTorch.isRipPresent(clickContext) and not clickContext.isImmuneRip and clickContext.comboPoints > 0 and macroTorch.isTrivialBattleOrPvp(clickContext)
                    or macroTorch.isTrivialBattleOrPvp(clickContext) and macroTorch.isFFPresent(clickContext) and (player.mana + macroTorch.computeErps(clickContext)) >= clickContext.TIGER_E
                    or clickContext.comboPoints == 5
                    or macroTorch.isKillShotOrLastChance(clickContext)) then
        return
    end
    macroTorch.safeFF(clickContext)
end

-- tiger fury效果是否还在，通过自身身上是否存在buff图标 + buff效果持续剩余时间是否到0来双重判断
function macroTorch.isTigerPresent(clickContext)
    if clickContext.isTigerPresent == nil then
        clickContext.isTigerPresent = macroTorch.toBoolean(macroTorch.player.hasBuff('Ability_Mount_JungleTiger') and
                macroTorch.tigerLeft(clickContext) > 0)
    end
    return clickContext.isTigerPresent
end

-- 由于游戏官方api获取debuff剩余时间不准，这里的debuff剩余时间由我自己实现倒计时计数，以记录准确的debuff剩余时间
function macroTorch.tigerLeft(clickContext)
    if clickContext.tigerLeft == nil then
        local tigerLeft = 0
        if not not macroTorch.loginContext.tigerTimer then
            tigerLeft = clickContext.TIGER_DURATION - (GetTime() - macroTorch.loginContext.tigerTimer)
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

-- 由于官方api获取buff/debuff剩余时间不准确，因此这里的ripLeft时间只能自己记录和计算
function macroTorch.ripLeft(clickContext)
    if clickContext.ripLeft == nil then
        local lastLandedRipTime = macroTorch.peekLandEvent('Rip')
        if not lastLandedRipTime then
            clickContext.ripLeft = 0
        else
            -- rip的连击点数每增一点，持续时间加2s
            local ripDur = macroTorch.RIP_BASE_DURATION
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

-- 由于官方api获取buff/debuff剩余时间不准确，因此这里的rakeLeft时间只能自己记录和计算
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
                ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. tostring(clickContext.comboPoints))
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
        macroTorch.loginContext.tigerTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.tigerSelfGCD(clickContext)
    if clickContext.tigerSelfGCD == nil then
        if not macroTorch or not macroTorch.loginContext or not macroTorch.loginContext.tigerTimer then
            clickContext.tigerSelfGCD = 0
        else
            local selfGCDLeft = 1 - (GetTime() - macroTorch.loginContext.tigerTimer)
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
    local player = macroTorch.player
    local target = macroTorch.target

    -- trinket
    if player.isTrinket2CooledDown() then
        player.useTrinket2()
    end

    -- juju power
    if not player.hasBuff('INV_Misc_MonsterScales_11') and not clickContext.isInBearForm and player.hasItem('Juju Power') and player.isItemInBagCooledDown('Juju Power') and not target.isPlayerControlled then
        player.use('Juju Power', true)
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
    clickContext.FF_DURATION = 40

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
        elseif player.mana >= 25 and player.isSpellReady('Savage Bite') then
            player.cast('Savage Bite')
        elseif player.isSpellReady('Challenging Roar') then
            player.cast('Challenging Roar')
        end
    end
    -- ff when nothing to do
    macroTorch.safeFF(clickContext)
end

function macroTorch.pokemonLoad()
    local battleChickenSaying = 'Go, Battle Chicken! I choose you!'
    local arcaniteDragonlingSaying = 'Come on out, Arcanite Dragonling!'
    local trackingHoundSaying = 'Go, Tracking Hound! I choose you!'
    local glowingCatFigurineSaying = 'Go, Glowing Cat! I choose you!'

    local orderedTable = {
        keys = {
            battleChickenSaying,
            arcaniteDragonlingSaying,
            trackingHoundSaying,
            glowingCatFigurineSaying
        },
        values = {
            [battleChickenSaying] = 'Gnomish Battle Chicken',
            [arcaniteDragonlingSaying] = 'Arcanite Dragonling',
            [trackingHoundSaying] = 'Dog Whistle',
            [glowingCatFigurineSaying] = 'Glowing Cat Figurine'
        }
    }
    macroTorch.player.loadUseableItem(orderedTable, 'Blackhand\'s Breadth')
end
