-- Hunter one-button combo macro methods (routing layer)

function macroTorch.hunterAtkRanged()
    local clickContext = {}
    clickContext.PLAYER_URGENT_HP_THRESHOLD = 15
    clickContext.isTargetDummy = macroTorch.target.isCanAttack
            and string.find(macroTorch.target.name, 'Training Dummy')

    local player = macroTorch.player
    local target = macroTorch.target

    -- Module 1: combatUrgentHPRestore -- life-saving HP restore
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
    end

    -- Module 2: targetEnemy -- ensure a valid attackable target
    if not target.isCanAttack then
        player.targetEnemy()
        if not target.isCanAttack then return end
    end

    -- Module 3: startAutoShoot -- trigger auto-shoot every keystroke per D-04
    player.startAutoShoot()

    -- Module 4: burstMod -- Shift-gated burst (Rapid Fire + Aimed Shot) per D-05
    if IsShiftKeyDown() then
        if not macroTorch.context.burstFlags then
            macroTorch.context.burstFlags = {}
        end
    end
    if macroTorch.context.burstFlags then
        local flags = macroTorch.context.burstFlags
        -- Rapid Fire first (opens with ranged attack speed boost)
        if not flags.rapidFire then
            if macroTorch.isSpellExist('Rapid Fire', 'spell')
                    and macroTorch.player.isSpellReady('Rapid Fire')
                    and not macroTorch.player.buffed(nil, 'Ability_Hunter_RunningShot') then
                macroTorch.player.rapid_fire('ready')
                flags.rapidFire = true
                return
            end
        end
        -- Aimed Shot (3s cast, manual-only burst per D-05)
        if not flags.aimedShot then
            if macroTorch.isSpellExist('Aimed Shot', 'spell') then
                macroTorch.player.aimed_shot('ready')
                flags.aimedShot = true
                return
            end
        end
        -- All flags consumed, clean up state per T-25-06 mitigation
        macroTorch.context.burstFlags = nil
    end

    -- Module 5: openerMod -- Hunter's Mark on fight start
    if macroTorch.isFightStarted(clickContext) then
        if macroTorch.isSpellExist("Hunter's Mark", 'spell')
                and not target.buffed("Hunter's Mark", 'Ability_Hunter_SniperShot') then
            player.hunters_mark('ready')
            return
        end
    end

    -- Module 6: stingMod -- maintain sting debuffs during combat
    if macroTorch.isFightStarted(clickContext) then
        -- Serpent Sting (damage-over-time sting, priority)
        if macroTorch.isSpellExist('Serpent Sting', 'spell')
                and not target.buffed('Serpent Sting', 'Ability_Hunter_SniperShot') then
            player.serpent_sting()
            return
        end
        -- Scorpid Sting (debuff sting, secondary)
        if macroTorch.isSpellExist('Scorpid Sting', 'spell')
                and not target.buffed('Scorpid Sting', 'INV_Misc_QuestionMark') then
            player.scorpid_sting()
            return
        end
    end

    -- Module 7: coreDPSMod -- primary damage rotation (Arcane Shot -> Multi-Shot)
    if macroTorch.isFightStarted(clickContext) then
        -- Arcane Shot (instant, does not reset auto-shot timer)
        if macroTorch.isSpellExist('Arcane Shot', 'spell') then
            player.arcane_shot()
            return
        end
        -- Multi-Shot (instant AoE, secondary damage skill)
        if macroTorch.isSpellExist('Multi-Shot', 'spell') then
            player.multi_shot()
            return
        end
    end

    -- Module 8: otMod -- threat reduction via Disengage
    if macroTorch.isFightStarted(clickContext)
            and not clickContext.isTargetDummy then
        if macroTorch.isSpellExist('Disengage', 'spell')
                and player.isSpellReady('Disengage')
                and target.isAttackingMe
                and (player.isInGroup or player.isInRaid) then
            player.disengage('ready')
        end
    end
end

function macroTorch.hunterAtkMelee()
    local clickContext = {}
    clickContext.PLAYER_URGENT_HP_THRESHOLD = 15
    clickContext.isTargetDummy = macroTorch.target.isCanAttack
            and string.find(macroTorch.target.name, 'Training Dummy')

    local player = macroTorch.player
    local target = macroTorch.target

    -- Module 1: combatUrgentHPRestore -- life-saving HP restore
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
    end

    -- Module 2: targetEnemy -- ensure a valid attackable target
    if not target.isCanAttack then
        player.targetEnemy()
        if not target.isCanAttack then return end
    end

    -- Module 3: startAutoAtk -- melee auto-attack triggered after fight started
    if macroTorch.isFightStarted(clickContext) then
        player.startAutoAtk()
    end

    -- Module 4: burstMod -- simplified melee burst (Rapid Fire only, no Aimed Shot)
    if IsShiftKeyDown() then
        if not macroTorch.context.burstFlags then
            macroTorch.context.burstFlags = {}
        end
    end
    if macroTorch.context.burstFlags then
        local flags = macroTorch.context.burstFlags
        -- Rapid Fire (ranged attack speed boost, still beneficial for melee+weave)
        if not flags.rapidFireMelee then
            if macroTorch.isSpellExist('Rapid Fire', 'spell')
                    and macroTorch.player.isSpellReady('Rapid Fire')
                    and not macroTorch.player.buffed(nil, 'Ability_Hunter_RunningShot') then
                macroTorch.player.rapid_fire('ready')
                flags.rapidFireMelee = true
                return
            end
        end
        -- All flags consumed, clean up state
        macroTorch.context.burstFlags = nil
    end

    -- Module 5: coreMeleeMod -- Raptor Strike -> Mongoose Bite
    if macroTorch.isFightStarted(clickContext) then
        -- Raptor Strike (primary melee attack, always available)
        if macroTorch.isSpellExist('Raptor Strike', 'spell') then
            player.raptor_strike('ready')
            return
        end
        -- Mongoose Bite (reactive skill, conditional on dodge)
        if macroTorch.isSpellExist('Mongoose Bite', 'spell') then
            player.mongoose_bite('ready')
            return
        end
    end

    -- Module 6: otMod -- threat reduction via Disengage (same as ranged)
    if macroTorch.isFightStarted(clickContext)
            and not clickContext.isTargetDummy then
        if macroTorch.isSpellExist('Disengage', 'spell')
                and player.isSpellReady('Disengage')
                and target.isAttackingMe
                and (player.isInGroup or player.isInRaid) then
            player.disengage('ready')
        end
    end
end

function macroTorch.hunterAtk()
    if macroTorch.target.distance < 8 then
        return macroTorch.hunterAtkMelee()
    else
        return macroTorch.hunterAtkRanged()
    end
end

function macroTorch.hunterDefend()
    if macroTorch.isSpellExist('Deterrence', 'spell')
            and macroTorch.player.isSpellReady('Deterrence') then
        macroTorch.player.deterrence('ready')
    end
end

-- Hunter AoE one-button macro -- distance routing per D-13
-- Ranged (>=8yd): Multi-Shot -> Volley
-- Melee (<8yd): Explosive Trap -> Immolation Trap
function macroTorch.hunterAoe()
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not macroTorch.target.isCanAttack then return end
    end

    if macroTorch.target.distance < 8 then
        -- Melee AoE: traps placed at feet
        if macroTorch.isSpellExist('Explosive Trap', 'spell')
                and macroTorch.player.isSpellReady('Explosive Trap') then
            macroTorch.player.explosive_trap('ready')
        elseif macroTorch.isSpellExist('Immolation Trap', 'spell')
                and macroTorch.player.isSpellReady('Immolation Trap') then
            macroTorch.player.immolation_trap('ready')
        end
    else
        -- Ranged AoE: instant Multi-Shot + channeled Volley
        macroTorch.player.startAutoShoot()
        if macroTorch.isSpellExist('Multi-Shot', 'spell') then
            macroTorch.player.multi_shot('ready')
        end
        if macroTorch.isSpellExist('Volley', 'spell')
                and macroTorch.player.isSpellReady('Volley') then
            macroTorch.player.volley('ready')
        end
    end
end

-- Hunter control one-button macro -- distance routing per D-15
-- Melee (<8yd): Wing Clip (slow) + Freezing Trap (freeze)
-- Ranged (>=8yd): Concussive Shot (slow) + Scatter Shot (confuse, talent-gated)
function macroTorch.hunterControl()
    local target = macroTorch.target
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then return end
    end

    if target.distance < 8 then
        -- Melee control: Wing Clip always available, Freeze as secondary option
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            macroTorch.player.wing_clip('ready')
        end
        if macroTorch.isSpellExist('Freezing Trap', 'spell')
                and macroTorch.player.isSpellReady('Freezing Trap') then
            macroTorch.player.freezing_trap('ready')
        end
    else
        -- Ranged control: Concussive Shot always available, Scatter Shot talent-gated
        if macroTorch.isSpellExist('Concussive Shot', 'spell') then
            macroTorch.player.concussive_shot('ready')
        end
        if macroTorch.isSpellExist('Scatter Shot', 'spell') then
            macroTorch.player.scatter_shot('ready')
        end
    end
end

-- Hunter mob-tagging one-button macro -- distance routing + PvP filter + auto-chain per D-16/D-17/D-18/D-19
-- Ranged tag: Arcane Shot rank 1 (instant, 30yd, lowest mana)
-- Melee tag: Wing Clip (instant direct damage + slow)
-- PvP filter: skip player targets via ClearTarget()
-- Auto-chain: on tag confirmed (target.isAttackingMe), transition to hunterAtk()
function macroTorch.hunterMobTagging()
    local player = macroTorch.player
    local target = macroTorch.target

    -- PvP filter per D-18: skip player targets, refer to druidMobTagging double-check pattern
    if not target.isCanAttack or target.isPlayerControlled then
        player.targetEnemy()
        if target.isCanAttack and target.isPlayerControlled then
            ClearTarget()
        end
        return
    end

    if target.distance < 8 then
        -- Melee tag: Wing Clip per D-17 (instant melee damage + slow)
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            player.wing_clip('ready')
        end
        player.startAutoAtk()
    else
        -- Ranged tag: Arcane Shot rank 1 per D-16 (instant, 30yd, lowest mana)
        player.startAutoShoot()
        if macroTorch.isSpellExist('Arcane Shot', 'spell') then
            player.arcane_shot('ready', 1)  -- rank=1, lowest mana cost
        end
    end

    -- Auto-chain to hunterAtk if tag confirmed per D-19
    if target.isAttackingMe then
        macroTorch.hunterAtk()
    end
end

macroTorch.SelfTest:register("Hunter: combo methods -- hunterAtk exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterAtk) == "function", "hunterAtk not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterDefend exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterDefend) == "function", "hunterDefend not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterAoe exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterAoe) == "function", "hunterAoe not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterControl exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterControl) == "function", "hunterControl not a function")
end, true)

macroTorch.SelfTest:register("Hunter: combo methods -- hunterMobTagging exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterMobTagging) == "function", "hunterMobTagging not a function")
end, true)