-- Druid cat form combat functions (extracted from SM_Extend_Druid.lua)
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
                player.berserk('ready')
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
function macroTorch.regularAttack(clickContext)
    -- Direct skill method calls with mode parameter
    -- ooc doesn't consume energy, so use ready mode ('ready') instead of safe mode
    if macroTorch.shouldUseShred(clickContext) then
        if clickContext.ooc then
            macroTorch.player.shred('ready')
        else
            macroTorch.player.shred()
        end
    else
        if clickContext.ooc then
            macroTorch.player.claw('ready')
        else
            macroTorch.player.claw()
        end
    end
end
function macroTorch.otMod(clickContext)
    -- 排除掉训练木桩的情况
    if clickContext.isTargetDummy then
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

    -- 当目前威胁值大于一定阈值，使用cower降低威胁值
    if macroTorch.shouldDoReshift(clickContext) then
        return
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then
        macroTorch.safeCower(clickContext)
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
        -- 当能量恢复速度超过最高耗能技能时，泄能变得无意义（能量必然溢出）
        local shouldDischarge = true

        -- Skip discharge if energy regeneration exceeds Shred cost (infinite energy scenario)
        if macroTorch.computeErps(clickContext) >= clickContext.SHRED_E then
            shouldDischarge = false
        end

        -- Check Rip duration
        if shouldDischarge and macroTorch.isRipPresent(clickContext) and macroTorch.ripLeft(clickContext) <= 2.3 then
            shouldDischarge = false
        end

        if shouldDischarge then
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
function macroTorch.energyDischargeBeforeBite(clickContext)
    -- Skip discharge when energy regeneration exceeds Shred cost (infinite energy scenario)
    if macroTorch.computeErps(clickContext) >= clickContext.SHRED_E then
        return
    end

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
    -- When energy regeneration exceeds Shred cost, skip ooc special handling
    -- and go through normal rotation to reach cp5 bite faster
    if macroTorch.computeErps(clickContext) >= clickContext.SHRED_E then
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
function macroTorch.tryBiteKillShot(clickContext)
    if macroTorch.isKillShotOrLastChance(clickContext) then
        if clickContext.comboPoints > 0 then
            macroTorch.player.ferocious_bite('raw')
        else
            -- 如果当前没星的话也只能做普通攻击
            macroTorch.regularAttack(clickContext)
        end
    end
end
function macroTorch.reshiftMod(clickContext)
    if not macroTorch.isSpellExist('Reshift', 'spell') then
        return
    end
    -- 如果当前做reshift”划算”，则做reshift
    local shouldDoReshift, nextMove, minAbilityCost = macroTorch.shouldDoReshift(clickContext)
    if shouldDoReshift then
        macroTorch.readyReshift(clickContext, nextMove, minAbilityCost)
    end
end
function macroTorch.shouldDoReshift(clickContext)
    -- [NEW CHECK] D-04: if reshift would give zero energy, skip entirely
    if clickContext.RESHIFT_ENERGY == 0 then
        return false
    end
    -- 不在战斗、潜行中、ooc时、或killshot/lastChance时，不做reshift
    if not macroTorch.player.isInCombat or clickContext.prowling or clickContext.ooc or macroTorch.isKillShotOrLastChance(clickContext) then
        return false
    end

    -- 计算1.5秒自然恢复后的预期能量
    local energyDuringGcd = macroTorch.computeErps(clickContext) * 1.5
    local projectedEnergy = macroTorch.player.mana + energyDuringGcd

    -- 获取可释放的最低技能能量消耗
    local minAbilityCost, nextMove = macroTorch.getMinimumAffordableAbilityCost(clickContext)

    -- 如果1.5秒自然恢复后能量足够 → 不reshift（避免1.5s GCD卡住技能）
    -- 如果1.5秒自然恢复后能量不够 → reshift（反正都要等，利用1.5s GCD）
    return math.ceil(projectedEnergy) < minAbilityCost, nextMove, minAbilityCost
end
function macroTorch.keepTigerFury(clickContext)
    -- 在距离目标20码以内才使用tiger fury，避免过早使用浪费buff时间
    if macroTorch.isTigerPresent(clickContext) or macroTorch.target.distance > 20 then
        return
    end
    macroTorch.safeTigerFury(clickContext)
end
function macroTorch.keepRip(clickContext)
    -- Use shared logic to check if Rip should be cast
    if not macroTorch.shouldCastRip(clickContext) then
        return
    end

    -- 普通版rip逻辑会要求尽量在rip时穿戴流血idol(Idol of Savagery)
    -- Switch relic if needed and apply Rip
    local shouldEquipSavagery = not clickContext.rough and not macroTorch.isTrivialBattleOrPvp(clickContext)
    macroTorch.dischargeEnergyChangeRelicAndRip(clickContext, shouldEquipSavagery)
end
function macroTorch.dischargeEnergyChangeRelicAndRip(clickContext, equipSavagery)
    -- ooc: just discharge energy
    if clickContext.ooc then
        macroTorch.regularAttack(clickContext)
        return
    end

    -- When energy regeneration exceeds Shred cost, discharge becomes meaningless
    -- Skip discharge logic and proceed directly to relic swap + rip
    local erps = macroTorch.computeErps(clickContext)
    local skipDischarge = erps >= clickContext.SHRED_E

    -- need to switch relic and have it
    if equipSavagery and macroTorch.player.hasItem('Idol of Savagery') and not macroTorch.player.isRelicEquipped('Idol of Savagery') then
        -- 2.5s = 1.5s for relic change + 1s for possible ooc
        -- With Essence of the Red, erps is so high that we never get the "waiting gap"
        -- where swapping would be "free". We swap anyway because Savagery is required for Rip.
        if not skipDischarge and macroTorch.player.mana + erps * 2.5 > 100 then
            macroTorch.regularAttack(clickContext)
            return
        end
        macroTorch.player.ensureRelicEquipped('Idol of Savagery')
        return
    end

    -- about to rip: check if energy would overflow during 2s (1s rip gcd + 1s possible ooc)
    -- With Essence of the Red, always skip discharge as energy will always "overflow"
    if not skipDischarge and macroTorch.player.mana + erps * 2 - clickContext.RIP_E > 100 then
        macroTorch.regularAttack(clickContext)
        return
    end

    -- Boost attack power for important targets
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst(clickContext)
    end

    macroTorch.safeRip(clickContext)
end
function macroTorch.quickKeepRip(clickContext)
    -- 经过实测，如果此时星数已经大于等于3星，则此时挂rip的收益还不如直接打一发bite,之后再攒到1-2星再打rip，因为目标预计会很快死亡，rip流血效果的回报周期太长，目标活不了那么久，因此不如直接打bite造成直接伤害
    -- 当然了，打bite之前也要考虑先泄能，为了dps最大化,利用好每一点能量
    -- For cp >= 3: discharge and bite
    if clickContext.comboPoints >= 3 and not macroTorch.isRipPresent(clickContext) and not clickContext.isImmuneRip then
        macroTorch.energyDischargeBeforeBite(clickContext)
        macroTorch.safeBite(clickContext)
        return
    end

    -- For cp < 3: quick apply Rip using shared logic
    if not macroTorch.shouldCastRip(clickContext) then
        return
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
    if ((macroTorch.target.classification == 'worldboss' and macroTorch.isRipPresent(clickContext) and not clickContext.isTargetDummy) or macroTorch.target.isPlayerControlled) and macroTorch.isNearBy(clickContext) then
        macroTorch.atkPowerBurst(clickContext)
    end
    macroTorch.safeRake(clickContext)
end
function macroTorch.keepFF(clickContext)
    -- Check if we should cast FF during reshift waiting window
    if macroTorch.shouldCastFFDuringWaitWindow(clickContext) then
        macroTorch.safeFF(clickContext)
    end
end
function macroTorch.readyReshift(clickContext, nextMove, minAbilityCost)
    if macroTorch.player.isSpellReady('Reshift') then
        macroTorch.show('Reshift!!! energy = ' ..
                macroTorch.player.mana ..
                ', nextMove: ' .. tostring(nextMove) ..
                ', curErps1.5: ' ..
                tostring(macroTorch.computeErps(clickContext) * 1.5) ..
                ', nextMoveCost: ' .. tostring(minAbilityCost) .. ', tigerLeft = ' .. macroTorch.tigerLeft(clickContext))
        macroTorch.player.reshift('ready')
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
        macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        macroTorch.player.rake('ready')
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
        macroTorch.loginContext.lastRipEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        macroTorch.player.rip('ready')
        macroTorch.context.lastRipAtCp = clickContext.comboPoints
        return true
    end
    return false
end
function macroTorch.safeBite(clickContext)
    return macroTorch.player.mana >= clickContext.BITE_E and macroTorch.readyBite(clickContext)
end
function macroTorch.readyBite(clickContext)
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.player.ferocious_bite('ready')
        macroTorch.show('Bite at energy: ' .. macroTorch.player.mana .. ', ooc: ' .. tostring(clickContext.ooc))
        return true
    end
    return false
end
function macroTorch.safeTigerFury(clickContext)
    if macroTorch.player.isSpellReady('Tiger\'s Fury') and macroTorch.tigerSelfGCD(clickContext) == 0 and macroTorch.player.mana >= clickContext.TIGER_E then
        -- macroTorch.show('Tiger!!! Tiger present: ' ..
        --     tostring(macroTorch.isTigerPresent(clickContext)) ..
        --     ', tiger left: ' .. macroTorch.tigerLeft(clickContext))
        macroTorch.player.tiger_fury('ready')
        macroTorch.loginContext.tigerTimer = GetTime()
        return true
    end
    return false
end
function macroTorch.readyCower(clickContext)
    if macroTorch.player.isSpellReady('Cower') then
        macroTorch.show('current threat: ' .. macroTorch.player.threatPercent .. ' doing ready cower!!!')
        macroTorch.player.cower('ready')
        return true
    end
    return false
end
function macroTorch.safeCower(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.player.mana >= clickContext.COWER_E and macroTorch.isNearBy(clickContext) then
        return macroTorch.readyCower(clickContext)
    end
    return false
end
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

    -- Mighty Rage Potion
    if not player.hasBuff('Ability_Warrior_InnerRage') and not clickContext.isInBearForm and player.hasItem('Mighty Rage Potion') and player.isItemInBagCooledDown('Mighty Rage Potion') and not target.isPlayerControlled then
        player.use('Mighty Rage Potion', true)
    end
end
