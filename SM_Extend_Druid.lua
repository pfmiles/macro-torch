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
--- @param startMove boolean the move to be used to start a combat
function macroTorch.catAtk(startMove)
    local p = 'player'
    local t = 'target'
    macroTorch.RESHIFT_WINDOW = 2.3
    macroTorch.RESHIFT_E_GATE = 25
    macroTorch.CLAW_E = 37
    macroTorch.SHRED_E = 48
    macroTorch.RAKE_E = 32
    macroTorch.BITE_E = 35
    macroTorch.RIP_E = 30
    macroTorch.TIGER_E = 30
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
            if not berserk and SpellReady('Berserk') then
                CastSpellByName('Berserk')
            end
            UseInventoryItem(14)
        end
        -- 5.starterMod
        if prowling then
            CastSpellByName(startMove)
        end
        -- 7.oocMod
        if not prowling and ooc then
            macroTorch.tryBiteKillshot(comboPoints)
            macroTorch.cp5ReadyBite(comboPoints)
            -- TODO consider not shred/claw on 5cp when ooc???
            if isBehind then
                macroTorch.readyShred()
            else
                macroTorch.readyClaw()
            end
        end
        -- 6.termMod: term on rip or killshot
        macroTorch.termMod(comboPoints)
        -- 8.OT mod
        lazyScript.SlashCommand('otMod')
        -- 9.combatBuffMod - tiger's fury *
        if macroTorch.target.distance <= 15 then
            macroTorch.keepTigerFury()
        end
        -- 10.debuffMod, including rip, rake and FF
        if player.isInCombat and not prowling then
            macroTorch.keepRip(comboPoints)
            macroTorch.keepRake(comboPoints)
            macroTorch.keepFF(ooc, player, comboPoints)
        end
        -- 11.regular attack tech mod
        if not prowling and comboPoints < 5 and macroTorch.isRakePresent() then
            macroTorch.safeClaw()
        end
        -- 12.energy res mod
        if not prowling and not berserk and macroTorch.tigerLeft() < macroTorch.RESHIFT_WINDOW then
            macroTorch.energyReshift(player, isBehind, comboPoints)
        end
    end
end

function macroTorch.targetEnemyMod()
    if macroTorch.target.isFriendly then
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

macroTorch.KS_CP1_Health_raid = 3000
macroTorch.KS_CP2_Health_raid = 3700
macroTorch.KS_CP3_Health_raid = 4500
macroTorch.KS_CP4_Health_raid = 5300
macroTorch.KS_CP5_Health_raid = 6000

function macroTorch.isKillshot(comboPoints)
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    if macroTorch.player.isInGroup and fightWorldBoss then
        -- fight world boss in a group or raid
        return comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid and not fightWorldBoss then
        -- normal battle in a 5-man group
        return comboPoints == 1 and targetHealth < macroTorch.KS_CP1_Health_group or
            comboPoints == 2 and targetHealth < macroTorch.KS_CP2_Health_group or
            comboPoints == 3 and targetHealth < macroTorch.KS_CP3_Health_group or
            comboPoints == 4 and targetHealth < macroTorch.KS_CP4_Health_group or
            comboPoints == 5 and targetHealth < macroTorch.KS_CP5_Health_group
    elseif macroTorch.player.isInRaid and not fightWorldBoss then
        -- normal battle in a raid
        return comboPoints == 1 and targetHealth < macroTorch.KS_CP1_Health_raid or
            comboPoints == 2 and targetHealth < macroTorch.KS_CP2_Health_raid or
            comboPoints == 3 and targetHealth < macroTorch.KS_CP3_Health_raid or
            comboPoints == 4 and targetHealth < macroTorch.KS_CP4_Health_raid or
            comboPoints == 5 and targetHealth < macroTorch.KS_CP5_Health_raid
    else
        -- fight alone
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

function macroTorch.energyReshift(player, isBehind, comboPoints)
    macroTorch.cleanBeforeReshift(isBehind, comboPoints)
    if player.mana <= macroTorch.RESHIFT_E_GATE then
        macroTorch.readyReshift()
    end
end

function macroTorch.cleanBeforeReshift(isBehind, comboPoints)
    macroTorch.termMod(comboPoints)
    macroTorch.keepRake(comboPoints)
    if isBehind then
        macroTorch.safeShred()
    else
        macroTorch.safeClaw()
    end
end

function macroTorch.keepTigerFury()
    if macroTorch.isTigerPresent() then
        return
    end
    macroTorch.safeTigerFury()
end

function macroTorch.keepRip(comboPoints)
    if macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.isImmune('Rip') or macroTorch.isKillshot(comboPoints) then
        return
    end
    macroTorch.safeRip()
end

function macroTorch.keepRake(comboPoints)
    -- in no condition rake on 5cp
    if comboPoints == 5 or macroTorch.isRakePresent() or macroTorch.isImmune('Rake') or macroTorch.isKillshot(comboPoints) then
        return
    end
    macroTorch.safeRake()
end

function macroTorch.keepFF(ooc, player, comboPoints)
    if (macroTorch.isFFPresent() and macroTorch.ffLeft() > 0.2)
        or ooc or player.mana >= macroTorch.CLAW_E
        or macroTorch.isImmune('Faerie Fire (Feral)')
        or macroTorch.tigerLeft() < macroTorch.RESHIFT_WINDOW
        or comboPoints == 5
        or not macroTorch.target.isNearBy
        or not macroTorch.player.isInCombat
        or macroTorch.isKillshot(comboPoints) then
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

function macroTorch.groupCast(spellFunction)
    -- local h, m, p, q, l, k = UnitHealth, UnitHealthMax, "player"; for i = 1, GetNumRaidMembers() do
    --     q = "raid" .. i; l = m(p) - h(p); k = m(q) - h(q); if CheckInteractDistance(q, 4) and l < k and h(q) > 1 then
    --         p = q; l = k;
    --     end
    -- end
    -- TargetUnit(p); CastSpellByName("治疗链(等级 " .. (l > 500 and 3 or 1) .. ")")
end
