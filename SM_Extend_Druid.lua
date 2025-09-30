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
    if not macroTorch.isTargetValidCanAttack(t) then
        ClearTarget()
        TargetNearestEnemy()
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
            macroTorch.cp5ReadyBite(comboPoints)
            if isBehind then
                if SpellReady('Shred') then
                    CastSpellByName('Shred')
                end
            else
                if SpellReady('Claw') then
                    CastSpellByName('Claw')
                end
            end
        end
        -- 6.termMod: term on rip or killshot
        macroTorch.termMod(comboPoints)
        -- 8.OT mod
        lazyScript.SlashCommand('otMod')
        -- 9.combatBuffMod - tiger's fury *
        if macroTorch.target.isInMediumRange then
            macroTorch.keepTigerFury()
        end
        -- 10.debuffMod, including rip, rake and FF
        if player.isInCombat and not prowling then
            macroTorch.keepRip(comboPoints)
            macroTorch.keepRake()
            macroTorch.keepFF(ooc, player)
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

function macroTorch.termMod(comboPoints)
    if macroTorch.biteKillshot(comboPoints) then
        return
    else
        macroTorch.cp5Bite(comboPoints)
    end
end

function macroTorch.cp5Bite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        macroTorch.safeBite()
    end
end

-- for ooc only
function macroTorch.cp5ReadyBite(comboPoints)
    if comboPoints == 5 and (macroTorch.isImmune('Rip') or macroTorch.isRipPresent()) then
        if SpellReady('Ferocious Bite') then
            CastSpellByName('Ferocious Bite')
            if macroTorch.isRipPresent() then
                macroTorch.ripTimer = GetTime()
            end
            if macroTorch.isRakePresent() then
                macroTorch.rakeTimer = GetTime()
            end
            return true
        end
        return false
    end
end

function macroTorch.biteKillshot(comboPoints)
    local targetHealth = macroTorch.target.health
    if comboPoints == 1 and targetHealth < 1446 or
        comboPoints == 2 and targetHealth < 1700 or
        comboPoints == 3 and targetHealth < 1960 or
        comboPoints == 4 and targetHealth < 2214 or
        comboPoints == 5 and targetHealth < 2470 then
        return macroTorch.safeBite()
    else
        return false
    end
end

function macroTorch.energyReshift(player, isBehind, comboPoints)
    macroTorch.cleanBeforeReshift(isBehind, comboPoints)
    if player.mana <= 25 then
        macroTorch.safeReshift()
    end
end

function macroTorch.cleanBeforeReshift(isBehind, comboPoints)
    macroTorch.termMod(comboPoints)
    macroTorch.keepRake()
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
    if macroTorch.isRipPresent() or comboPoints < 5 or macroTorch.isImmune('Rip') then
        return
    end
    macroTorch.safeRip()
end

function macroTorch.keepRake()
    if macroTorch.isRakePresent() or macroTorch.isImmune('Rake') then
        return
    end
    macroTorch.safeRake()
end

function macroTorch.keepFF(ooc, player)
    if (macroTorch.isFFPresent() and macroTorch.ffLeft() > 0.2) or ooc or player.mana >= 40 or macroTorch.isImmune('Faerie Fire (Feral)') or macroTorch.tigerLeft() < macroTorch.RESHIFT_WINDOW then
        return
    end
    macroTorch.safeFF()
end

function macroTorch.isTigerPresent()
    return buffed('Tiger\'s Fury') and macroTorch.tigerLeft() > 0
end

function macroTorch.tigerLeft()
    local tigerLeft = 0
    if not not macroTorch.tigerTimer then
        tigerLeft = 18 - (GetTime() - macroTorch.tigerTimer)
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
    if not not macroTorch.ripTimer then
        ripLeft = 18 - (GetTime() - macroTorch.ripTimer)
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
    if not not macroTorch.rakeTimer then
        rakeLeft = 9 - (GetTime() - macroTorch.rakeTimer)
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
    if not not macroTorch.ffTimer then
        ffLeft = 40 - (GetTime() - macroTorch.ffTimer)
        if ffLeft < 0 then
            ffLeft = 0
        end
    else
        ffLeft = 0
    end
    return ffLeft
end

function macroTorch.safeReshift()
    if SpellReady('Reshift') then
        CastSpellByName('Reshift')
        macroTorch.show('Reshift!!! energy = ' .. macroTorch.player.mana .. ', tigerLeft = ' .. macroTorch.tigerLeft())
        return true
    end
    return false
end

function macroTorch.safeShred()
    if SpellReady('Shred') and macroTorch.player.mana >= 48 then
        CastSpellByName('Shred')
        return true
    end
    return false
end

function macroTorch.safeClaw()
    if SpellReady('Claw') and macroTorch.player.mana >= 40 then
        CastSpellByName('Claw')
        return true
    end
    return false
end

function macroTorch.safeRake()
    if SpellReady('Rake') and macroTorch.player.mana >= 35 then
        CastSpellByName('Rake')
        macroTorch.rakeTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeRip()
    if SpellReady('Rip') and macroTorch.player.mana >= 30 then
        CastSpellByName('Rip')
        macroTorch.ripTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeBite()
    if SpellReady('Ferocious Bite') and macroTorch.player.mana >= 35 then
        CastSpellByName('Ferocious Bite')
        if macroTorch.isRipPresent() then
            macroTorch.ripTimer = GetTime()
        end
        if macroTorch.isRakePresent() then
            macroTorch.rakeTimer = GetTime()
        end
        return true
    end
    return false
end

function macroTorch.safeFF()
    if SpellReady('Faerie Fire (Feral)') then
        -- CastSpellByName('Faerie Fire (Feral)')
        lazyScript.SlashCommand('ff')
        macroTorch.ffTimer = GetTime()
        return true
    end
    return false
end

function macroTorch.safeTigerFury()
    if SpellReady('Tiger\'s Fury') and macroTorch.player.mana >= 30 then
        CastSpellByName('Tiger\'s Fury')
        macroTorch.tigerTimer = GetTime()
        return true
    end
    return false
end
