-- Druid bear form combat functions (extracted from SM_Extend_Druid.lua)
function macroTorch.bearOocMod(clickContext)
    if not clickContext.ooc then
        return
    end
    -- Use Savage Bite when OOC is active (no rage cost)
    macroTorch.player.ferocious_bite('ready')
end
function macroTorch.bearOtMod(clickContext)
    -- Only when grouped and target not controlled by player
    if not clickContext.isInGroup or macroTorch.target.isPlayerControlled then
        return
    end

    -- If in rough mode, avoid using high threat skills to let others overtake our threat
    if clickContext.rough then
        return
    end

    -- If target not attacking me
    if not macroTorch.target.isAttackingMe then
        -- Try Growl first (costs no rage, only checks CD)
        if macroTorch.player.growl('ready') then
            return
        end
        -- If Growl on CD, use Savage Bite as high threat alternative
        macroTorch.player.ferocious_bite('safe')
    end
end
function macroTorch.bearDebuffMod(clickContext)
    -- Track Demoralizing Roar - works in both solo and group
    if not macroTorch.isDemoralizingRoarPresent(clickContext) then
        macroTorch.player.demoralizing_roar('safe')
    end
end
function macroTorch.bearFFMod(clickContext)
    -- Cast FF during free GCDs to trigger ooc procs (cast when rage < threshold)
    if clickContext.rage >= clickContext.FF_RAGE_THRESHOLD then
        return
    end

    -- Reuse existing FF logic
    macroTorch.safeFF(clickContext)
end
function macroTorch.bearRegularAttack(clickContext)
    -- High rage: Savage Bite (rage dump when above threshold)
    -- But avoid using Savage Bite in rough mode to reduce threat generation
    if not clickContext.rough and clickContext.rage > clickContext.RAGE_DUMP_THRESHOLD and macroTorch.player.ferocious_bite('safe') then
        return
    end

    -- Primary: Maul
    if macroTorch.player.maul('safe') then
        return
    end
end
function macroTorch.bearReshiftMod(clickContext)
    -- Threshold-based trigger (cast when below threshold)
    if clickContext.rage < clickContext.RESHIFT_RAGE_THRESHOLD and not clickContext.ooc then
        macroTorch.show('Reshift!!! Rage = ' .. macroTorch.player.mana)
        macroTorch.player.reshift('ready')
    end
end
function macroTorch.bearAoe()
    local clickContext = {}
    if not macroTorch.player.isInBearForm then
        return
    end

    -- Define rage cost for Swipe
    clickContext.SWIPE_E = 15
    clickContext.DEMORALIZING_ROAR_E = 10

    macroTorch.bearDebuffMod(clickContext)

    -- Use Swipe if we have enough rage
    if macroTorch.player.swipe('safe') then
        return
    end
end
function macroTorch.bearAtk(rough)
    -- clickContext is single-click context, used for value caching optimization
    local clickContext = {}
    clickContext.FF_DURATION = 40
    clickContext.rough = macroTorch.toBoolean(rough)

    local player = macroTorch.player
    local target = macroTorch.target

    -- rage costs of abilities
    clickContext.MAUL_E = 10
    clickContext.SAVAGE_BITE_E = 25
    clickContext.DEMORALIZING_ROAR_E = 10
    clickContext.SWIPE_E = 15

    -- rage thresholds
    clickContext.FF_RAGE_THRESHOLD = 10
    clickContext.RAGE_DUMP_THRESHOLD = 80
    clickContext.RESHIFT_RAGE_THRESHOLD = 1

    -- Cache player/target state
    clickContext.isInBearForm = player.isInBearForm
    if not clickContext.isInBearForm then
        return
    end

    clickContext.ooc = player.isOoc
    clickContext.isInGroup = player.isInGroup
    clickContext.rage = player.mana

    -- the health line of urgent, whether to use some life saving items/spells
    clickContext.PLAYER_URGENT_HP_THRESHOLD = 15

    -- 1. Health Saver
    if macroTorch.isFightStarted(clickContext) then
        macroTorch.combatUrgentHPRestore(clickContext)
    end

    -- 2. Target Enemy
    if not target.isCanAttack then
        player.targetEnemy()
    else
        -- 3. Keep AutoAttack
        if macroTorch.isFightStarted(clickContext) then
            player.startAutoAtk()
        end

        -- 5. ooc Mod
        macroTorch.bearOocMod(clickContext)

        -- 6. OT Mod (Tank version)
        macroTorch.bearOtMod(clickContext)

        -- 8. Debuff Mod
        macroTorch.bearDebuffMod(clickContext)

        -- 9.FF Mod - Cast FF during free GCDs to trigger ooc procs
        macroTorch.bearFFMod(clickContext)

        -- 10.Regular Attack - Primary: Maul, High rage: Savage Bite
        macroTorch.bearRegularAttack(clickContext)

        -- 11.Reshift Mod - Threshold-based trigger
        macroTorch.bearReshiftMod(clickContext)
    end
end
