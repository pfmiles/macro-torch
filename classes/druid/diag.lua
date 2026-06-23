-- Druid diagnostic print function (quick task 260623-wrh-druid)
-- Prints all dynamic compute results to chat frame for in-game verification.
-- Can be invoked manually via: /run macroTorch.printDruidDiag()

function macroTorch.printDruidDiag()
    if UnitClass('player') ~= 'Druid' then
        return
    end

    macroTorch.show('[macro-torch] === Druid Skill Diagnostics ===', 'white')

    -- Energy Costs
    macroTorch.show('[macro-torch] --- Energy Costs ---', 'white')
    macroTorch.show('[macro-torch] Claw: ' .. tostring(macroTorch.computeClaw_E()), 'green')
    macroTorch.show('[macro-torch] Shred: ' .. tostring(macroTorch.computeShred_E()), 'green')
    macroTorch.show('[macro-torch] Rake: ' .. tostring(macroTorch.computeRake_E()), 'green')
    macroTorch.show("[macro-torch] Tiger's Fury: " .. tostring(macroTorch.computeTiger_E()), 'green')
    macroTorch.show('[macro-torch] Pounce: 50 (fixed)', 'green')
    macroTorch.show('[macro-torch] Bite: 35 (fixed)', 'green')
    macroTorch.show('[macro-torch] Rip: 30 (fixed)', 'green')
    macroTorch.show('[macro-torch] Cower: 20 (fixed)', 'green')

    -- Durations
    macroTorch.show('[macro-torch] --- Durations ---', 'white')
    macroTorch.show("[macro-torch] Tiger's Fury: " .. tostring(macroTorch.computeTiger_Duration()) .. 's', 'green')
    macroTorch.show('[macro-torch] FF (Faerie Fire): 40s (fixed)', 'green')
    macroTorch.show('[macro-torch] Pounce: 18s (fixed)', 'green')

    -- ERPS (Energy Per Second)
    macroTorch.show('[macro-torch] --- ERPS (Energy Per Second) ---', 'white')
    macroTorch.show('[macro-torch] Auto Tick: 10.00 (fixed)', 'green')
    macroTorch.show("[macro-torch] Tiger's Fury Tick: 3.33 (fixed)", 'green')
    macroTorch.show('[macro-torch] Rake Tick: ' .. string.format("%.2f", macroTorch.computeRake_Erps()), 'green')
    macroTorch.show('[macro-torch] Rip Tick: ' .. string.format("%.2f", macroTorch.computeRip_Erps()), 'green')
    macroTorch.show('[macro-torch] Pounce Tick: ' .. string.format("%.2f", macroTorch.computePounce_Erps()), 'green')
    macroTorch.show('[macro-torch] Total (computeErps): context-dependent -- requires clickContext', 'green')

    -- Reshift
    macroTorch.show('[macro-torch] --- Reshift ---', 'white')
    macroTorch.show('[macro-torch] Reshift Energy Gain: ' .. tostring(macroTorch.computeReshiftEnergy()), 'green')

    -- Level-Adaptive Estimates
    macroTorch.show('[macro-torch] --- Level-Adaptive Estimates ---', 'white')
    macroTorch.show('[macro-torch] Player Level: ' .. tostring(UnitLevel('player')), 'green')
    macroTorch.show('[macro-torch] Estimated DPS: ' .. tostring(macroTorch.estimatePlayerDPS()), 'green')
    macroTorch.show('[macro-torch] Kill Shot Threshold: ' .. tostring(macroTorch.getKSThreshold()), 'green')

    macroTorch.show('[macro-torch] === End Diagnostics ===', 'white')
end