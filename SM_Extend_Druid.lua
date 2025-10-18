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

--- The 'E' key regular dps function for feral cat druid
function macroTorch.catAtk()
    local p = 'player'
    local t = 'target'
    macroTorch.POUNCE_E = 50
    macroTorch.CLAW_E = 37
    macroTorch.SHRED_E = 54
    macroTorch.RAKE_E = 32
    macroTorch.BITE_E = 35
    macroTorch.RIP_E = 30
    macroTorch.TIGER_E = 30
    macroTorch.AUTO_TICK_ERPS = 20 / 2
    macroTorch.TIGER_ERPS = 10 / 3
    macroTorch.RAKE_ERPS = 5 / 3
    macroTorch.RIP_ERPS = 5 / 2
    macroTorch.POUNCE_ERPS = 5 / 3
    macroTorch.BERSERK_ERPS = 20 / 2
    local player = macroTorch.player
    local prowling = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Ambush')
    local berserk = macroTorch.isBuffOrDebuffPresent(p, 'Ability_Druid_Berserk')
    local comboPoints = GetComboPoints()
    local ooc = macroTorch.isBuffOrDebuffPresent(p, 'Spell_Shadow_ManaBurn')
    local isBehind = macroTorch.isTargetValidCanAttack(t) and UnitXP('behind', 'player', 'target') or false

    -- 1.health & mana saver in combat *
    if player.isInCombat and not prowling then
        macroTorch.useItemIfHealthPercentLessThan(p, 20, 'Healing Potion')
        -- macroTorch.useItemIfManaPercentLessThan(p, 20, 'Mana Potion') TODO 由于cat形态下无法读取真正的mana，因此这里暂时作废
    end
    -- 2.targetEnemy *
    if not macroTorch.target.isCanAttack then
        macroTorch.targetEnemyMod()
    else
        -- 3.keep autoAttack, in combat & not prowling *
        if not prowling then
            player.startAutoAtk()
        end
        -- 4.rushMod, incuding trinckets, berserk and potions *
        if IsShiftKeyDown() then
            if not berserk then
                CastSpellByName('Berserk')
            end
            macroTorch.atkPowerBurst()
        end
        -- 5.starterMod
        if prowling then
            if not macroTorch.isImmune('Pounce') then
                macroTorch.show('Pounce immune: ' .. tostring(macroTorch.isImmune('Pounce')) .. ', do safePounce!')
                macroTorch.safePounce()
            else
                macroTorch.show('Pounce immune: ' .. tostring(macroTorch.isImmune('Pounce')) .. ', do Ravage!')
                CastSpellByName('Ravage')
            end
        end
        -- 7.oocMod
        if not prowling and ooc then
            macroTorch.tryBiteKillshot(comboPoints)
            macroTorch.cp5ReadyBite(comboPoints)
            -- no shred/claw at cp5 when ooc
            if comboPoints < 5 then
                if isBehind then
                    macroTorch.readyShred()
                else
                    macroTorch.readyClaw()
                end
            end
        end
        -- 6.termMod: term on rip or killshot
        macroTorch.termMod(comboPoints)
        -- 8.OT mod
        macroTorch.otMod(player, prowling, ooc, berserk, comboPoints)
        -- 9.combatBuffMod - tiger's fury *
        macroTorch.keepTigerFury()
        -- 10.debuffMod, including rip, rake and FF
        macroTorch.keepRip(comboPoints, player, prowling)
        macroTorch.keepRake(comboPoints, player, prowling)
        macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
        -- 11.regular attack tech mod
        if not prowling and comboPoints < 5 and macroTorch.isRakePresent() then
            macroTorch.safeClaw()
        end
        -- 12.energy res mod
        macroTorch.reshiftMod(player, prowling, ooc, berserk)
    end
end

function macroTorch.otMod(player, prowling, ooc, berserk, comboPoints)
    local target = macroTorch.target
    if macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not player.isInCombat
        or not target.isInCombat
        or prowling
        or macroTorch.isKillshot(comboPoints)
        or not target.isCanAttack
        or target.isPlayerControlled
        or not macroTorch.player.isInGroup then
        return
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and macroTorch.playerThreatPercent() >= 80) then
        macroTorch.show('current thread: ' .. macroTorch.playerThreatPercent() .. ' doing ready cower!!!')
        macroTorch.readyCower()
    end
end

function macroTorch.targetEnemyMod()
    if macroTorch.target.isFriendly and macroTorch.targettarget.isCanAttack then
        AssistUnit('target')
    else
        ClearTarget()
        TargetNearestEnemy()
    end
end

function macroTorch.termMod(comboPoints)
    macroTorch.tryBiteKillshot(comboPoints)
    macroTorch.cp5Bite(comboPoints)
end

function macroTorch.cp5Bite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.safeBite()
    end
end

-- for ooc only
function macroTorch.cp5ReadyBite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.readyBite()
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

function macroTorch.isKillshot(comboPoints)
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    local isPvp = macroTorch.target.isPlayerControlled or GetBattlefieldInstanceRunTime() > 0
    if macroTorch.player.isInGroup and fightWorldBoss then
        -- fight world boss in a group or raid
        return comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a 5-man group
        return comboPoints == 1 and targetHealth < macroTorch.KS_CP1_Health_group or
            comboPoints == 2 and targetHealth < macroTorch.KS_CP2_Health_group or
            comboPoints == 3 and targetHealth < macroTorch.KS_CP3_Health_group or
            comboPoints == 4 and targetHealth < macroTorch.KS_CP4_Health_group or
            comboPoints == 5 and targetHealth < macroTorch.KS_CP5_Health_group
    elseif macroTorch.player.isInRaid and not fightWorldBoss and not isPvp then
        -- normal battle in a raid
        local raidNum = GetNumRaidMembers() or 0
        local more = raidNum - 5
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
    if macroTorch.isKillshot(comboPoints) then
        CastSpellByName('Ferocious Bite')
    end
end

function macroTorch.reshiftMod(player, prowling, ooc, berserk)
    if macroTorch.canDoReshift(player, prowling, ooc, berserk) then
        macroTorch.readyReshift()
    end
end

-- reshift at anytime in battle & not prowling & not ooc when: the current 'enerty restoration per-second' is lesser than '30 - currentEnergyBeforeReshift'
function macroTorch.canDoReshift(player, prowling, ooc, berserk)
    if not player.isInCombat or prowling or ooc then
        return false
    end
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
    if berserk then
        erps = erps + macroTorch.BERSERK_ERPS
    end
    local diff = 30 - player.mana - erps
    local ret = diff > 2.5

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
    if macroTorch.isTigerPresent() or macroTorch.target.distance > 15 then
        return
    end
    macroTorch.safeTigerFury()
end

function macroTorch.keepRip(comboPoints, player, prowling)
    if not player.isInCombat or prowling or macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.isImmune('Rip') or macroTorch.isKillshot(comboPoints) then
        return
    end
    -- boost attack power to rip when fighting world boss or player-controlled target
    if macroTorch.target.classification == 'worldboss' or macroTorch.target.isPlayerControlled then
        macroTorch.atkPowerBurst()
    end
    macroTorch.safeRip()
end

function macroTorch.keepRake(comboPoints, player, prowling)
    -- in no condition rake on 5cp
    if not player.isInCombat or prowling or comboPoints == 5 or macroTorch.isRakePresent() or macroTorch.isImmune('Rake') or macroTorch.isKillshot(comboPoints) then
        return
    end
    macroTorch.safeRake()
end

-- no FF in: 1) melee range if other techs can use, 2) when ooc 3) immune 4) killshot 5) eager to reshift 6) cp5 7) player not in combat 8) prowling 9) target not in combat
-- all in all: if in combat and there's nothing to do, then FF, no matter if FF debuff present, we wish to trigger more ooc through instant FFs
function macroTorch.keepFF(ooc, player, comboPoints, prowling, berserk)
    if ooc
        or macroTorch.isImmune('Faerie Fire (Feral)')
        or macroTorch.canDoReshift(player, prowling, ooc, berserk)
        or not player.isInCombat
        or not macroTorch.target.isInCombat
        or prowling
        or macroTorch.target.isNearBy and (
            player.mana >= macroTorch.CLAW_E and comboPoints < 5
            or player.mana >= macroTorch.BITE_E and comboPoints == 5
            or player.mana >= macroTorch.RAKE_E and not macroTorch.isRakePresent() and comboPoints < 5
            or player.mana >= macroTorch.RIP_E and not macroTorch.isRipPresent() and comboPoints == 5
            or comboPoints == 5
            or macroTorch.isKillshot(comboPoints)) then
        return
    end
    macroTorch.safeFF()
end

function macroTorch.isTigerPresent()
    return buffed('Tiger\'s Fury') and macroTorch.tigerLeft() > 0
end

function macroTorch.tigerLeft()
    local tigerLeft = 0
    if not not macroTorch.context.tigerTimer then
        tigerLeft = 18 - (GetTime() - macroTorch.context.tigerTimer)
        if tigerLeft < 0 then
            tigerLeft = 0
        end
    else
        tigerLeft = 0
    end
    return tigerLeft
end

function macroTorch.isRipPresent()
    return buffed('Rip', 'target') and macroTorch.ripLeft() > 0
end

function macroTorch.ripLeft()
    local ripLeft = 0
    if not not macroTorch.context.ripTimer then
        ripLeft = 18 - (GetTime() - macroTorch.context.ripTimer)
        if ripLeft < 0 then
            ripLeft = 0
        end
    else
        ripLeft = 0
    end
    return ripLeft
end

function macroTorch.isRakePresent()
    return buffed('Rake', 'target') and macroTorch.rakeLeft() > 0
end

function macroTorch.rakeLeft()
    local rakeLeft = 0
    if not not macroTorch.context.rakeTimer then
        rakeLeft = 9 - (GetTime() - macroTorch.context.rakeTimer)
        if rakeLeft < 0 then
            rakeLeft = 0
        end
    else
        rakeLeft = 0
    end
    return rakeLeft
end

function macroTorch.isFFPresent()
    return buffed('Faerie Fire ', 'target') and macroTorch.ffLeft() > 0
end

function macroTorch.ffLeft()
    local ffLeft = 0
    if not not macroTorch.context.ffTimer then
        ffLeft = 40 - (GetTime() - macroTorch.context.ffTimer)
        if ffLeft < 0 then
            ffLeft = 0
        end
    else
        ffLeft = 0
    end
    return ffLeft
end

function macroTorch.isPouncePresent()
    return buffed('Pounce', 'target') and macroTorch.pounceLeft() > 0
end

function macroTorch.pounceLeft()
    local pounceLeft = 0
    if not not macroTorch.context.pounceTimer then
        pounceLeft = 18 - (GetTime() - macroTorch.context.pounceTimer)
        if pounceLeft < 0 then
            pounceLeft = 0
        end
    else
        pounceLeft = 0
    end
    return pounceLeft
end

function macroTorch.readyReshift()
    if SpellReady('Reshift') then
        CastSpellByName('Reshift')
        macroTorch.show('Reshift!!! energy = ' .. macroTorch.player.mana .. ', tigerLeft = ' .. macroTorch.tigerLeft())
        return true
    end
    return false
end

function macroTorch.safeShred()
    return macroTorch.player.mana >= macroTorch.SHRED_E and macroTorch.readyShred()
end

function macroTorch.readyShred()
    if SpellReady('Shred') then
        CastSpellByName('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw()
    return macroTorch.player.mana >= macroTorch.CLAW_E and macroTorch.readyClaw()
end

function macroTorch.readyClaw()
    if SpellReady('Claw') then
        CastSpellByName('Claw')
        return true
    end
    return false
end

function macroTorch.safeRake()
    if SpellReady('Rake') and macroTorch.player.mana >= macroTorch.RAKE_E then
        CastSpellByName('Rake')
        macroTorch.context.rakeTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeRip()
    if SpellReady('Rip') and macroTorch.player.mana >= macroTorch.RIP_E then
        CastSpellByName('Rip')
        macroTorch.context.ripTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeBite()
    return macroTorch.player.mana >= macroTorch.BITE_E and macroTorch.readyBite()
end

function macroTorch.readyBite()
    if SpellReady('Ferocious Bite') then
        CastSpellByName('Ferocious Bite')
        if macroTorch.isRipPresent() then
            macroTorch.context.ripTimer = GetTime()
        end
        if macroTorch.isRakePresent() then
            macroTorch.context.rakeTimer = GetTime()
        end
        return true
    end
    return false
end

function macroTorch.safeFF()
    if SpellReady('Faerie Fire (Feral)') then
        -- CastSpellByName('Faerie Fire (Feral)')
        lazyScript.SlashCommand('ff')
        macroTorch.context.ffTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeTigerFury()
    if SpellReady('Tiger\'s Fury') and macroTorch.player.mana >= macroTorch.TIGER_E then
        CastSpellByName('Tiger\'s Fury')
        macroTorch.context.tigerTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safePounce()
    if SpellReady('Pounce') and macroTorch.player.mana >= macroTorch.POUNCE_E then
        CastSpellByName('Pounce')
        macroTorch.context.pounceTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.readyCower()
    if SpellReady('Cower') then
        CastSpellByName('Cower')
        return true
    end
    return false
end

function macroTorch.playerThreatPercent()
    local TWT = macroTorch.TWT
    local p = 0
    if TWT and TWT.threats and TWT.threats[TWT.name] then p = TWT.threats[TWT.name].perc or 0 end
    return p
end

-- burst through boosting attack power
function macroTorch.atkPowerBurst()
    UseInventoryItem(14)
end

function macroTorch.druidBuffs()
    if not buffed('Mark of the Wild', 'player') then
        CastSpellByName('Mark of the Wild', true)
    end
    if not buffed('Thorns', 'player') then
        CastSpellByName('Thorns', true)
    end
    if not buffed('Nature\'s Grasp', 'player') then
        CastSpellByName('Nature\'s Grasp', true)
    end
end

function macroTorch.groupCast(spellFunction)
    -- local h, m, p, q, l, k = UnitHealth, UnitHealthMax, "player"; for i = 1, GetNumRaidMembers() do
    --     q = "raid" .. i; l = m(p) - h(p); k = m(q) - h(q); if CheckInteractDistance(q, 4) and l < k and h(q) > 1 then
    --         p = q; l = k;
    --     end
    -- end
    -- TargetUnit(p); CastSpellByName("治疗链(等级 " .. (l > 500 and 3 or 1) .. ")")
end
