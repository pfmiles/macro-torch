-- Druid one-button combo macro methods (routing layer)

function macroTorch.casterAtk()
    if not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.player.isInCombat then
        macroTorch.player.wrath()
    elseif not macroTorch.target.buffed('Moonfire', 'Spell_Nature_StarFall') then
        macroTorch.player.moonfire()
    elseif not macroTorch.target.buffed('Faerie Fire', 'Spell_Nature_FaerieFire') then
        macroTorch.player.faerie_fire()
    elseif not macroTorch.target.buffed('Insect Swarm', 'Spell_Nature_InsectSwarm') then
        macroTorch.player.insect_swarm()
    elseif macroTorch.context.starfireNext then
        if macroTorch.player.starfire() then
            macroTorch.context.starfireNext = false
        end
    else
        if macroTorch.player.wrath() then
            macroTorch.context.starfireNext = true
        end
    end
end

-- 这是猫德一键输出宏逻辑，目标是dps最大化，利用好当前猫德伤害机制，利用好每一点能量，尽可能使能量不溢出、也不因为能量不足而卡技能
--- The 'E' key regular dps function for feral cat druid
--- if rough, all combats are considered short
function macroTorch.catAtk(rough)
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
    -- the energy resetting value after reshift
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

    clickContext.isTargetDummy = macroTorch.toBoolean(
            macroTorch.target.isCanAttack and
            string.find(macroTorch.target.name, 'Training Dummy'))

    -- 0.idol recover, equip the current normal relic if not equipped
    macroTorch.recoverNormalRelic(clickContext, clickContext.normalRelic)

    -- 1.health & mana saver in combat *
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
        if macroTorch.shouldUseManaPotion() then
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
        -- 5.opener mod, 根据等级动态判断：高于阈值用Pounce（增加claw伤害），低于阈值用Ravage秒杀
        -- 阈值由 getOpenerHealthThreshold() 计算 (60级=1500, 50-59=1000, 40-49=600, 30-39=300, <30=150)
        -- [NEW GUARD] D-02: skip opener module if neither opener skill is available
        local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
        local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
        if clickContext.prowling then
            if hasPounce and not target.isImmune('Pounce') and target.health >= macroTorch.getOpenerHealthThreshold() then
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
        -- 保持FF(野性精灵之火)效果，如果目标不免疫FF的话; 且由于精灵之火的释放成本很低，无须消耗能量，成本仅仅是1s的GCD，且跟其它攻击技能或普通攻击一样有概率触发ooc，因此我会在"没有别的事情可干"的时候释放一发精灵之火，即使目标身上已有该效果
        macroTorch.keepFF(clickContext)
        -- 11.普通攻击技能模块，攒星的主要技能，主要是claw和shred, 根据实测结果，依据目标身上的流血效果数量和当前自己的站位而灵活选择claw或shred释放
        if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 and (macroTorch.isRakePresent(clickContext) or clickContext.isImmuneRake) then
            macroTorch.regularAttack(clickContext)
        end
        -- 12.reshift模块，从cat形态变身到cat形态(形态不实际改变的"变身"，乌龟服特有技能)
        -- 将能量固定重置为60。判断逻辑：当"无事可做"时释放，即当前能量不足以支持任何合理技能时
        -- reshift energy is now dynamically computed by computeReshiftEnergy() (Furor + Wolfshead Helm)
        macroTorch.reshiftMod(clickContext)
    end
end

function macroTorch.druidAtk(rough)
    if macroTorch.player.isInCatForm then
        if macroTorch.player.level >= 60 then
            macroTorch.catAtk(rough)
        else
            macroTorch.catLeveling()
        end
    elseif macroTorch.player.isInBearForm then
        macroTorch.bearAtk(rough)
    else
        macroTorch.casterAtk()
    end
end

function macroTorch.druidAoe()
    if macroTorch.player.isInBearForm then
        macroTorch.bearAoe()
    elseif macroTorch.player.isInCatForm then
        return -- No cat form AoE in vanilla WoW
    elseif macroTorch.player.humanFormMana >= 880 then
        macroTorch.player.hurricane('ready')
    end
end

function macroTorch.druidHeal()
    if macroTorch.player.isInCatForm then
        macroTorch.player.cat_form('ready')
        return
    elseif macroTorch.player.isInBearForm then
        if macroTorch.player.isFormActive('Dire Bear Form') then
            macroTorch.player.dire_bear_form('ready')
        else
            macroTorch.player.bear_form('ready')
        end
        return
    end

    if macroTorch.player.isInGroup or macroTorch.player.isInRaid then
        local lowestUnit, lowestHp = macroTorch.findMostDamagedGroupMember()
        if lowestHp >= 90 then
            return
        end
        TargetUnit(lowestUnit)
        if lowestHp < 50 then
            macroTorch.player.healing_touch(nil, false)
        elseif lowestHp < 70 then
            if not macroTorch.target.buffed(nil, 'Spell_Nature_ResistNature') then
                macroTorch.player.regrowth(nil, false)
            elseif not macroTorch.target.buffed(nil, 'Spell_Nature_Rejuvenation') then
                macroTorch.player.rejuvenation(nil, false)
            else
                macroTorch.player.healing_touch(nil, false)
            end
        else
            if not macroTorch.target.buffed(nil, 'Spell_Nature_Rejuvenation') then
                macroTorch.player.rejuvenation(nil, false)
            end
        end
    else
        if not macroTorch.player.buffed(nil, 'Spell_Nature_Rejuvenation') then
            macroTorch.player.rejuvenation(nil, true)
            return
        end
        if not macroTorch.player.buffed(nil, 'Spell_Nature_ResistNature') then
            macroTorch.player.regrowth(nil, true)
            return
        end
        macroTorch.player.healing_touch(nil, true)
    end
end

function macroTorch.druidDefend()
    if macroTorch.player.isSpellReady('Barkskin (Feral)') then
        macroTorch.player.barkskin('ready')
        return
    end

    if not macroTorch.player.isInBearForm then
        macroTorch.player.dire_bear_form('ready')
        return
    end

    if macroTorch.player.isInBearForm and macroTorch.player.isSpellReady('Frenzied Regeneration') then
        macroTorch.player.frenzied_regeneration('ready')
    end
end

function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    if target.distance < 8 then
        macroTorch.player.bash('ready')
    elseif target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end

macroTorch.SelfTest:register("Druid: combo methods -- catAtk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.catAtk) == "function", "catAtk not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- druidAtk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidAtk) == "function", "druidAtk not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- casterAtk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.casterAtk) == "function", "casterAtk not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- druidAoe exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidAoe) == "function", "druidAoe not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- druidHeal exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidHeal) == "function", "druidHeal not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- druidDefend exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidDefend) == "function", "druidDefend not a function")
end, true)

macroTorch.SelfTest:register("Druid: combo methods -- druidControl exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidControl) == "function", "druidControl not a function")
end, true)