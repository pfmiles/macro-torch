-- Druid one-button combo macro methods (routing layer)

function macroTorch.druidAtk(rough)
    if macroTorch.player.isInCatForm then
        macroTorch.player.catAtk(rough)
    elseif macroTorch.player.isInBearForm then
        macroTorch.bearAtk(rough)
    elseif not macroTorch.target.isCanAttack then
        return
    elseif not macroTorch.target.hasBuff('Spell_Nature_StarFall') then
        macroTorch.player.moonfire('safe')
    else
        macroTorch.player.wrath('safe')
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

    if macroTorch.player.isSpellReady('Rejuvenation') and
        macroTorch.player.healthPercent < 50 and
        not macroTorch.player.hasBuff('Spell_Nature_Rejuvenation') then
        macroTorch.player.rejuvenation('safe', true)
        return
    end

    if macroTorch.player.healthPercent < 40 then
        macroTorch.player.healing_touch('safe', true)
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
    else
        macroTorch.player.entangling_roots('safe')
    end
end

macroTorch.SelfTest:register("Druid: combo methods -- druidAtk exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidAtk) == "function", "druidAtk not a function")
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