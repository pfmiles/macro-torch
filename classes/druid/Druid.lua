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

    setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))

    -- Cat form skills (Type A: enemy target only)
    function obj.claw(mode, rank)
        return obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
    end

    function obj.shred(mode, rank)
        return obj._castSpell({ en = 'Shred', zh = '撕碎' }, mode, nil, macroTorch.computeShred_E, false, rank)
    end

    function obj.rake(mode, rank)
        return obj._castSpell({ en = 'Rake', zh = '斜掠' }, mode, nil, macroTorch.computeRake_E, false, rank)
    end

    function obj.rip(mode, rank)
        return obj._castSpell({ en = 'Rip', zh = '撕扯' }, mode, nil, 30, false, rank)
    end

    function obj.ferocious_bite(mode, rank)
        return obj._castSpell({ en = 'Ferocious Bite', zh = '凶猛撕咬' }, mode, nil, 35, false, rank)
    end

    function obj.pounce(mode, rank)
        return obj._castSpell({ en = 'Pounce', zh = '突袭' }, mode, nil, 50, false, rank)
    end

    function obj.cower(mode, rank)
        return obj._castSpell({ en = 'Cower', zh = '畏缩' }, mode, nil, 20, false, rank)
    end

    function obj.faerie_fire_feral(mode, rank)
        return obj._castSpell({ en = 'Faerie Fire (Feral)', zh = '精灵之火（野性）' }, mode, nil, 0, false, rank)
    end

    function obj.ravage(mode, rank)
        return obj._castSpell({ en = 'Ravage', zh = '毁灭' }, mode, nil, 50, false, rank)
    end

    -- Bear form skills (Type A: enemy target only, using fixed rage costs)
    function obj.growl(mode, rank)
        return obj._castSpell({ en = 'Growl', zh = '低吼' }, mode, nil, 10, false, rank)
    end

    function obj.bash(mode, rank)
        return obj._castSpell({ en = 'Bash', zh = '猛击' }, mode, nil, 10, false, rank)
    end

    function obj.swipe(mode, rank)
        return obj._castSpell({ en = 'Swipe', zh = '横扫' }, mode, nil, 15, false, rank)
    end

    function obj.maul(mode, rank)
        return obj._castSpell({ en = 'Maul', zh = '重击' }, mode, nil, 10, false, rank)
    end

    function obj.demoralizing_roar(mode, rank)
        return obj._castSpell({ en = 'Demoralizing Roar', zh = '挫志咆哮' }, mode, nil, 10, false, rank)
    end

    function obj.feral_charge(mode, rank)
        return obj._castSpell({ en = 'Feral Charge', zh = '野性冲锋' }, mode, 25, nil, false, rank)
    end

    function obj.challenging_roar(mode, rank)
        return obj._castSpell({ en = 'Challenging Roar', zh = '挑战咆哮' }, mode, nil, 15, false, rank)
    end

    -- Caster form skills (Type A: enemy target only)
    function obj.wrath(mode, rank)
        return obj._castSpell({ en = 'Wrath', zh = '愤怒' }, mode, 30, nil, false, rank)
    end

    function obj.moonfire(mode, rank)
        return obj._castSpell({ en = 'Moonfire', zh = '月火术' }, mode, 30, nil, false, rank)
    end

    function obj.starfire(mode, rank)
        return obj._castSpell({ en = 'Starfire', zh = '星火术' }, mode, 30, nil, false, rank)
    end

    function obj.entangling_roots(mode, rank)
        return obj._castSpell({ en = 'Entangling Roots', zh = '纠缠根须' }, mode, 30, nil, false, rank)
    end

    function obj.hibernate(mode, rank)
        return obj._castSpell({ en = 'Hibernate', zh = '休眠' }, mode, 30, nil, false, rank)
    end

    function obj.faerie_fire(mode, rank)
        return obj._castSpell({ en = 'Faerie Fire', zh = '精灵之火' }, mode, 30, nil, false, rank)
    end

    function obj.insect_swarm(mode, rank)
        return obj._castSpell({ en = 'Insect Swarm', zh = '虫群' }, mode, 30, nil, false, rank)
    end

    function obj.soothe_animal(mode, rank)
        return obj._castSpell({ en = 'Soothe Animal', zh = '安抚动物' }, mode, 30, nil, false, rank)
    end

    -- Form skills (Type B: self target only)
    function obj.bear_form(mode, rank)
        return obj._castSpell({ en = 'Bear Form', zh = '熊形态' }, mode, nil, nil, true, rank)
    end

    function obj.dire_bear_form(mode, rank)
        return obj._castSpell({ en = 'Dire Bear Form', zh = '巨熊形态' }, mode, nil, nil, true, rank)
    end

    function obj.cat_form(mode, rank)
        return obj._castSpell({ en = 'Cat Form', zh = '猫形态' }, mode, nil, nil, true, rank)
    end

    function obj.travel_form(mode, rank)
        return obj._castSpell({ en = 'Travel Form', zh = '旅行形态' }, mode, nil, nil, true, rank)
    end

    function obj.aquatic_form(mode, rank)
        return obj._castSpell({ en = 'Aquatic Form', zh = '水栖形态' }, mode, nil, nil, true, rank)
    end

    -- Self buff skills (Type B: self target only)
    function obj.prowl(mode, rank)
        return obj._castSpell({ en = 'Prowl', zh = '潜行' }, mode, nil, 0, true, rank)
    end

    function obj.dash(mode, rank)
        return obj._castSpell({ en = 'Dash', zh = '急奔' }, mode, nil, 0, true, rank)
    end

    function obj.tiger_fury(mode, rank)
        return obj._castSpell({ en = "Tiger's Fury", zh = '猛虎之怒' }, mode, nil, macroTorch.computeTiger_E, true, rank)
    end

    function obj.barkskin(mode, rank)
        return obj._castSpell({ en = 'Barkskin (Feral)', zh = '树皮术' }, mode, nil, 0, true, rank)
    end

    function obj.track_humanoids(mode, rank)
        return obj._castSpell({ en = 'Track Humanoids', zh = '追踪人型' }, mode, nil, 0, true, rank)
    end

    function obj.natures_swiftness(mode, rank)
        return obj._castSpell({ en = "Nature's Swiftness", zh = '自然迅捷' }, mode, nil, 0, true, rank)
    end

    function obj.tranquility(mode, rank)
        return obj._castSpell({ en = 'Tranquility', zh = '宁静' }, mode, nil, nil, true, rank)
    end

    function obj.hurricane(mode, rank)
        return obj._castSpell({ en = 'Hurricane', zh = '飓风' }, mode, nil, nil, true, rank)
    end

    function obj.innervate(mode, rank)
        return obj._castSpell({ en = 'Innervate', zh = '激活' }, mode, nil, 0, true, rank)
    end

    function obj.rebirth(mode, rank)
        return obj._castSpell({ en = 'Rebirth', zh = '复生' }, mode, nil, nil, true, rank)
    end

    function obj.frenzied_regeneration(mode, rank)
        return obj._castSpell({ en = 'Frenzied Regeneration', zh = '狂暴回复' }, mode, nil, 10, true, rank)
    end

    function obj.enrage(mode, rank)
        return obj._castSpell({ en = 'Enrage', zh = '激怒' }, mode, nil, 0, true, rank)
    end

    function obj.reshift(mode, rank)
        return obj._castSpell({ en = 'Reshift', zh = '变身' }, mode, nil, 0, true, rank)
    end

    function obj.berserk(mode, rank)
        return obj._castSpell({ en = 'Berserk', zh = '狂暴' }, mode, nil, 0, true, rank)
    end

    function obj.natures_grasp(mode, rank)
        return obj._castSpell({ en = "Nature's Grasp", zh = '自然之握' }, mode, nil, nil, true, rank)
    end

    -- Flexible target skills (Type C: onSelf parameter exposed)
    function obj.healing_touch(mode, onSelf, rank)
        return obj._castSpell({ en = 'Healing Touch', zh = '治疗之触' }, mode, 40, nil, onSelf, rank)
    end

    function obj.regrowth(mode, onSelf, rank)
        return obj._castSpell({ en = 'Regrowth', zh = '愈合' }, mode, 40, nil, onSelf, rank)
    end

    function obj.rejuvenation(mode, onSelf, rank)
        return obj._castSpell({ en = 'Rejuvenation', zh = '回春术' }, mode, 40, nil, onSelf, rank)
    end

    function obj.remove_curse(mode, onSelf, rank)
        return obj._castSpell({ en = 'Remove Curse', zh = '驱除诅咒' }, mode, 40, nil, onSelf, rank)
    end

    function obj.abolish_poison(mode, onSelf, rank)
        return obj._castSpell({ en = 'Abolish Poison', zh = '驱毒术' }, mode, 40, nil, onSelf, rank)
    end

    function obj.cure_poison(mode, onSelf, rank)
        return obj._castSpell({ en = 'Cure Poison', zh = '消毒术' }, mode, 40, nil, onSelf, rank)
    end

    function obj.mark_of_the_wild(mode, onSelf, rank)
        return obj._castSpell({ en = 'Mark of the Wild', zh = '野性印记' }, mode, 30, nil, onSelf, rank)
    end

    function obj.gift_of_the_wild(mode, onSelf, rank)
        return obj._castSpell({ en = 'Gift of the Wild', zh = '野性赐福' }, mode, 30, nil, onSelf, rank)
    end

    function obj.thorns(mode, onSelf, rank)
        return obj._castSpell({ en = 'Thorns', zh = '荆棘术' }, mode, 30, nil, onSelf, rank)
    end

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

    -- 这是猫德一键输出宏逻辑，目标是dps最大化，利用好当前猫德伤害机制，利用好每一点能量，尽可能使能量不溢出、也不因为能量不足而卡技能
    --- The 'E' key regular dps function for feral cat druid
    --- if rough, all combats are considered short
    function obj.catAtk(rough)
        if not macroTorch.player.isInCatForm then
            return
        end

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
        clickContext.COWER_E = 20

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
        -- [NEW] D-04: replaced hardcoded 60 with dynamic computation from Furor talent + Wolfshead Helm
        clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()
        clickContext.RESHIFT_E_DIFF_THRESHOLD = 0
        -- the health line of urgent, whether to use some life saving items/spells
        clickContext.PLAYER_URGENT_HP_THRESHOLD = 15

        local player = macroTorch.player
        local target = macroTorch.target
        clickContext.prowling = player.isProwling
        clickContext.berserk = player.isBerserk
        clickContext.comboPoints = player.comboPoints
        clickContext.ooc = player.isOoc
        clickContext.hasEssenceOfTheRed = player.hasEssenceOfTheRed
        clickContext.isBehind = target.isCanAttack and player.isBehindTarget

        clickContext.isInCatForm = player.isInCatForm

        clickContext.isImmuneRake = target.isImmune('Rake')
        clickContext.isImmuneRip = target.isImmune('Rip')

        -- 计算normal relic（接下来的战斗默认穿戴的relic）
        clickContext.normalRelic = macroTorch.computeNormalRelic(clickContext)

        clickContext.isTargetDummy = macroTorch.target.isCanAttack and
                string.find(macroTorch.target.name, 'Training Dummy')

        -- 0.idol recover, equip the current normal relic if not equipped
        macroTorch.recoverNormalRelic(clickContext, clickContext.normalRelic)

        -- 1.health & mana saver in combat *
        if macroTorch.isFightStarted(clickContext) then
            macroTorch.combatUrgentHPRestore(clickContext)
            if player.humanFormMana < 350 then
                player.use('Mana Potion')
            end
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
            -- 5.opener mod, 因为Ravage差不多可以秒掉1500血以内的目标，除此之外均使用Pounce以增加后续claw的伤害
            -- [NEW GUARD] D-02: skip opener module if neither opener skill is available
            local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
            local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
            if clickContext.prowling then
                if hasPounce and not target.isImmune('Pounce') and target.health >= 1500 then
                    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
                        macroTorch.player.pounce()
                    end
                elseif hasRavage then
                    player.ravage('ready')
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
            -- 12.reshift模块，从cat形态变身到cat形态(形态不实际改变的“变身”，乌龟服特有技能)
            -- 将能量固定重置为60。判断逻辑：当“无事可做”时释放，即当前能量不足以支持任何合理技能时
            -- TODO reshift energy restore should consider wolfheart head enchant
            macroTorch.reshiftMod(clickContext)
        end
    end

    return obj
end

-- player fields to function mapping
macroTorch.DRUID_FIELD_FUNC_MAP = {
    -- basic props
    ['comboPoints'] = function(self)
        return GetComboPoints() or 0
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
    ['isInCatForm'] = function(self)
        return self.isFormActive('Cat Form')
    end,
    ['isInBearForm'] = function(self)
        return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
    end,
    ['isInTravelForm'] = function(self)
        return self.isFormActive('Travel Form')
    end, -- reserved for future expansion
    ['isInAquaticForm'] = function(self)
        return self.isFormActive('Aquatic Form')
    end, -- reserved for future expansion
    ['isInCasterForm'] = function(self)
        return self.isFormActive('Moonkin Form')
    end, -- reserved for future expansion
    ['humanFormMana'] = function(self)
        return UnitMana(self.ref) or 0
    end,
}

macroTorch.druid = macroTorch.Druid:new()
macroTorch.registerPlayerClass("Druid", macroTorch.Druid)


-- 计算normal relic（接下来的战斗默认穿戴的relic）
-- 逻辑：
-- 1. 不在战斗时：免疫rip用fero/emerald_rot，不免疫用savagery
-- 2. 在战斗时：
--    - 快速战斗/PvP：保持原逻辑不变
--    - 普通战斗：如果rip已存在且目标不免疫rip，则使用fero/emerald_rot以便快速打出claw或造成更多伤害；否则用savagery
function macroTorch.computeNormalRelic(clickContext)
    if not macroTorch.player.isInCombat then
        -- 未进入战斗，按原逻辑
        if clickContext.isImmuneRip then
            return macroTorch.selectFerocityOrEmeraldRot()
        else
            return 'Idol of Savagery'
        end
    else
        -- 已进入战斗
        if macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough then
            -- 快速战斗/PvP，保持原逻辑
            if clickContext.isImmuneRip then
                return macroTorch.selectFerocityOrEmeraldRot()
            else
                return 'Idol of Savagery'
            end
        else
            -- 普通战斗，如果rip已存在且目标不免疫rip，则使用fero/emerald_rot
            if not clickContext.isImmuneRip and macroTorch.isRipPresent(clickContext) then
                return macroTorch.selectFerocityOrEmeraldRot()
            else
                return 'Idol of Savagery'
            end
        end
    end
end

-- 在Idol of Ferocity和Idol of the Emerald Rot之间选择
-- 逻辑：检查拥有情况（背包 or 身上）：如果只有一个存在，选那个
--       如果两个都存在：
--       - 若穿着8/8 Cenarion T1，选Ferocity（不冲突）
--       - 否则选Emerald Rot（与8/8 T1效果冲突）
function macroTorch.selectFerocityOrEmeraldRot()
    local IDOL_FEROCITY = 'Idol of Ferocity'
    local IDOL_EMERALD_ROT = 'Idol of the Emerald Rot'

    local player = macroTorch.player
    local hasFerocity = player.hasItem(IDOL_FEROCITY) or player.isRelicEquipped(IDOL_FEROCITY)
    local hasEmeraldRot = player.hasItem(IDOL_EMERALD_ROT) or player.isRelicEquipped(IDOL_EMERALD_ROT)

    -- 只存在一个时选那个
    if hasFerocity and not hasEmeraldRot then
        return IDOL_FEROCITY
    end
    if hasEmeraldRot and not hasFerocity then
        return IDOL_EMERALD_ROT
    end

    -- 两个都存在时，根据8/8 T1判断
    if hasFerocity and hasEmeraldRot then
        if player.countEquippedItemNameContains('Cenarion') >= 8 then
            return IDOL_FEROCITY
        else
            return IDOL_EMERALD_ROT
        end
    end

    -- 两个都不存在，默认返回Ferocity（兼容原逻辑）
    return IDOL_FEROCITY
end

function macroTorch.recoverNormalRelic(clickContext, relicName)
    if not macroTorch.target.isCanAttack then
        return
    end
    local player = macroTorch.player
    if not player.isInCatForm then
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

function macroTorch.computeReshiftEnergy()
    local energy = 0
    local player = macroTorch.player
    -- [NEW] D-04: Furor talent each rank gives +8 energy when reshifting
    energy = energy + player.talentRank('Furor') * 8
    -- [NEW] D-04: Wolfshead Helm provides +20 energy on shapeshift
    if player.isItemEquipped('Wolfshead Helm') then
        energy = energy + 20
    end
    return energy
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
        return 0 -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 3 -- Base 3 seconds

    -- Check if Savagery idol was equipped when Rake was cast (snapshot mechanic)
    if macroTorch.loginContext and macroTorch.loginContext.lastRakeEquippedSavagery then
        tickInterval = tickInterval * 0.9 -- 10% shorter tick interval
    end

    return energyPerTick / tickInterval
end

function macroTorch.computeRip_Erps()
    local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
    if ancientBrutalityRank == 0 then
        return 0 -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 2 -- Base 2 seconds

    -- Check if Savagery idol was equipped when Rip was cast (snapshot mechanic)
    if macroTorch.loginContext and macroTorch.loginContext.lastRipEquippedSavagery then
        tickInterval = tickInterval * 0.9 -- 10% shorter tick interval
    end

    return energyPerTick / tickInterval
end

function macroTorch.computePounce_Erps()
    local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
    if ancientBrutalityRank == 0 then
        return 0 -- No energy regeneration without talent
    end

    local energyPerTick = (ancientBrutalityRank == 1) and 3 or 5
    local tickInterval = 3 -- Pounce tick interval is always 3 seconds, not affected by equipment

    return energyPerTick / tickInterval
end

-- tracing certain spells and maintain the landTable (declarative style)
-- spell trace + immune registration via SpellTrace:register() API
macroTorch.SpellTrace:register('Pounce', {
    spellId = 9827, land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellId = 9904, land = true,
    immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellId = 9896, land = true,
    immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellId = 31018, land = true,
    immune = false  -- FB has consumeLandEvent but NO immune tracing in original code
})
macroTorch.SpellTrace:register('Faerie Fire (Feral)', {
    land = false,  -- FF is not spell-traced (no setSpellTracing call in original code)
    immune = true, debuffTexture = 'Spell_Nature_FaerieFire'
})

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

function macroTorch.shouldUseShred(clickContext)
    -- [NEW GUARD] D-03: Shred not learned -> always prefer Claw
    if not macroTorch.isSpellExist('Shred', 'spell') then
        return false
    end
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

    -- Check if we have infinite energy situation (Essence of the Red or similar buffs)
    -- When ERPS covers Shred cost, treat it like infinite ooc - Shred becomes free
    local erps = macroTorch.computeErps(clickContext)
    local infiniteEnergy = erps >= clickContext.SHRED_E

    -- Decision tree matching regularAttack logic
    if bleedCount <= 1 then
        -- ooc OR infinite energy: use Shred if behind (no effective energy cost)
        if clickContext.ooc or infiniteEnergy then
            return clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed
        end

        -- If energy will recover enough for Claw in 1s, use Shred for better damage, and preventing from energy overflow
        local energyIn1s = erps * 1
        if energyIn1s >= clickContext.CLAW_E then
            return clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed
        end

        -- For normal battles when we need to quickly build combo points for Rip:
        -- If not trivial/PvP, target not immune to Rip, and Rip not present, use Claw for faster CP generation
        if not macroTorch.isTrivialBattleOrPvp(clickContext) and
                not clickContext.isImmuneRip and
                not macroTorch.isRipPresent(clickContext) then
            return false
        end

        return clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed
    elseif bleedCount == 2 then
        -- With infinite energy (Essence of the Red), treat like ooc - always use Shred when behind
        return (clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed
    else
        return false -- 3+ bleeding always uses Claw
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


-- 撕咬前的泄能逻辑: 当前多余能量用作撕咬加成不划算，将其拆成2个技能使用


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


function macroTorch.computeErps(clickContext)
    -- Cache result to avoid redundant calculations per click
    if clickContext.computeErps ~= nil then
        return clickContext.computeErps
    end

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
    -- Essence of the Red grants +50 energy per second
    if clickContext.hasEssenceOfTheRed then
        erps = erps + 50
    end

    clickContext.computeErps = erps
    return erps
end

-- 判断是否应该在等待期间做reshift
-- 逻辑：如果自然恢复1.5s后能量足够，则等待；否则，reshift（利用这1.5s的等待时间）

-- 检查是否可以在等待窗口期间释放FF
-- 返回true当:
-- 1. 基础条件满足（非ooc、目标不免疫FF、不需要reshift）
-- 2. 能量将在1.5秒内自然恢复到足够水平（无需reshift）
-- 3. 当前能量不足以立即释放下一个技能
-- 4. 等待时间 >= 1.0秒（FF的GCD是1秒）
function macroTorch.shouldCastFFDuringWaitWindow(clickContext)
    -- 基础排除条件
    if clickContext.ooc
            or macroTorch.target.isImmune('Faerie Fire (Feral)')
            or macroTorch.shouldDoReshift(clickContext) then
        return false
    end

    -- 计算1.5秒GCD期间的预期能量恢复
    local energyDuringGcd = macroTorch.computeErps(clickContext) * 1.5
    local minAbilityCost = macroTorch.getMinimumAffordableAbilityCost(clickContext)

    local currentEnergy = macroTorch.player.mana
    local projectedEnergy = currentEnergy + energyDuringGcd

    -- 条件1: 1.5秒后能量将足够(无需reshift)
    -- 条件2: 当前能量不足(需要等待)
    if projectedEnergy >= minAbilityCost and currentEnergy < minAbilityCost then
        -- 计算需要等待的时间
        local energyNeeded = minAbilityCost - currentEnergy
        local erps = macroTorch.computeErps(clickContext)
        local waitSeconds = energyNeeded / erps

        -- 条件3: 等待时间足够释放FF (FF的GCD是1秒)
        return waitSeconds >= 1.0
    end

    return false
end

function macroTorch.getMinimumAffordableAbilityCost(clickContext)
    -- 1. Ferocious Bite check (highest priority in Term Mod)
    -- Note: Bite has priority over Tiger during kill shot or 5cp with rip
    if macroTorch.shouldUseBite(clickContext) then
        return clickContext.BITE_E, 'Bite'
    end

    -- 2. Tiger's Fury check (maintain buff if not active)
    if not macroTorch.isTigerPresent(clickContext) then
        return clickContext.TIGER_E, 'Tiger'
    end

    -- 3. Rip check (debuff maintenance)
    if macroTorch.shouldCastRip(clickContext) then
        return clickContext.RIP_E, 'Rip'
    end

    -- 4. Rake check (debuff maintenance)
    if not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
        return clickContext.RAKE_E, 'Rake'
    end

    -- 5. Shred check (using shred vs claw decision logic)
    if macroTorch.shouldUseShred(clickContext) then
        return clickContext.SHRED_E, 'Shred'
    end

    -- 6. Default to Claw (standard builder)
    return clickContext.CLAW_E, 'Claw'
end

-- tiger fury when near

-- Helper function to determine if Rip should be cast based on combo points and battle type
function macroTorch.shouldCastRip(clickContext)
    -- [NEW GUARD] D-03: Rip not learned -> cannot cast Rip
    if not macroTorch.isSpellExist('Rip', 'spell') then
        return false
    end
    -- Common preconditions that apply to both normal and quick battles
    if macroTorch.isRipPresent(clickContext)
            or clickContext.isImmuneRip
            or not macroTorch.isFightStarted(clickContext)
            or macroTorch.isKillShotOrLastChance(clickContext)
            or not macroTorch.isNearBy(clickContext) then
        return false
    end

    -- Determine CP requirements based on battle type
    if macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough then
        -- Quick battle: use 1-2 combo points
        return clickContext.comboPoints >= 1 and clickContext.comboPoints <= 2
    else
        -- Normal battle: use exactly 5 combo points
        return clickContext.comboPoints >= 5
    end
end

-- Helper function to determine if Ferocious Bite should be used
function macroTorch.shouldUseBite(clickContext)
    -- [NEW GUARD] D-03: Ferocious Bite not learned -> cannot use Bite
    if not macroTorch.isSpellExist('Ferocious Bite', 'spell') then
        return false
    end
    -- Kill shot phase: use bite with any combo points
    if macroTorch.isKillShotOrLastChance(clickContext) then
        return clickContext.comboPoints > 0
    end

    -- Quick battle without Rip and not immune: CP >= 3 should bite
    -- (to quickly consume CP and get to 1-2 CP for low-star Rip)
    if (macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough)
            and not clickContext.isImmuneRip
            and not macroTorch.isRipPresent(clickContext)
            and clickContext.comboPoints >= 3 then
        return true
    end

    -- Normal battle or quick battle with Rip immunity: CP5 should bite (Rip present OR target immune)
    if clickContext.comboPoints == 5 and (macroTorch.isRipPresent(clickContext) or clickContext.isImmuneRip) then
        return true
    end

    return false
end

-- 普通版的rip逻辑，与快战版不同，普通版rip逻辑力求rip持续伤害最大化，因此只会打5星rip

-- energy discharge needed due to possible energy overflow before rip

-- 快战版的keep rip, 由于预估战斗会很快结束，因此上rip的目的是为了增强claw，而不是为了rip那点流血效果伤害，因此这里只打低星rip以求速度挂上流血


function macroTorch.isNearBy(clickContext)
    if clickContext.isNearBy == nil then
        clickContext.isNearBy = macroTorch.target.distance <= 3
    end
    return clickContext.isNearBy
end

-- no FF in: 1) melee range if other techs can use, 2) when ooc 3) immune 4) killshot 5) eager to reshift 6) cp5 7) player not in combat 8) prowling 9) target not in combat
-- all in all: if in combat and there's nothing to do, then FF, no matter if FF debuff present, we wish to trigger more ooc through instant FFs

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
            local cp = macroTorch.context.lastRipAtCp
            if cp then
                ripDur = ripDur + (cp - 1) * 2
            end
            -- if Savagery idol equipped, reduce rip duration by 10%
            if macroTorch.loginContext and macroTorch.loginContext.lastRipEquippedSavagery then
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
            if macroTorch.loginContext and macroTorch.loginContext.lastRakeEquippedSavagery then
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

-- Demoralizing Roar debuff tracking (bear form) - only check presence, no duration needed
function macroTorch.isDemoralizingRoarPresent(clickContext)
    if clickContext.isDemoralizingRoarPresent == nil then
        clickContext.isDemoralizingRoarPresent = macroTorch.target.hasBuff('Ability_Druid_DemoralizingRoar')
    end
    return clickContext.isDemoralizingRoarPresent
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


function macroTorch.isGcdOk(clickContext)
    if clickContext.isGcdOk == nil then
        clickContext.isGcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
    end
    return clickContext.isGcdOk
end


function macroTorch.safeFF(clickContext)
    if macroTorch.player.isSpellReady('Faerie Fire (Feral)') and macroTorch.isGcdOk(clickContext) then
        macroTorch.show('FF!!! FF present: ' ..
                tostring(macroTorch.isFFPresent(clickContext)) ..
                ', FF left: ' ..
                tostring(macroTorch.ffLeft(clickContext)) ..
                ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. tostring(clickContext.comboPoints))
        macroTorch.player.faerie_fire_feral('raw')
        macroTorch.context.ffTimer = GetTime()
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


-- Bear helper functions (safe/ready variants)


-- burst through boosting attack power


-- Bear module functions


-- Druid class-specific self-test registrations
-- Category F1: removed (spell names are not _G functions)

-- Category F2/F3: removed (talent/energy tests not suitable for boot self-test)

-- Category G1: DRUID_FIELD_FUNC_MAP field integrity (5 items, isOptional=true)
-- These tests only apply when the player character is a Druid
macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP comboPoints exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player.comboPoints) == "number", "comboPoints not number")
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isOoc exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.player.isOoc
    assert(type(val) ~= "nil", "isOoc is nil")
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isProwling exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isProwling)
    assert(type(val) == "boolean", "isProwling not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isBerserk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.player.isBerserk
    assert(type(val) ~= "nil", "isBerserk is nil")
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP humanFormMana exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.player.humanFormMana
    assert(type(val) ~= "nil", "humanFormMana is nil")
end, true)

-- Category G2: Form detection semantic methods (5 items, isOptional=true)
macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInCatForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInCatForm)
    assert(type(val) == "boolean", "isInCatForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInBearForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInBearForm)
    assert(type(val) == "boolean", "isInBearForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInTravelForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInTravelForm)
    assert(type(val) == "boolean", "isInTravelForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInAquaticForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInAquaticForm)
    assert(type(val) == "boolean", "isInAquaticForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInCasterForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInCasterForm)
    assert(type(val) == "boolean", "isInCasterForm not boolean: " .. type(val))
end, true)
