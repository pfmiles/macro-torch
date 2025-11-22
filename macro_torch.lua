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

-- some machanisms impl

--- all spell names which has a lasting effect on the enemy
if not macroTorch.effectLastingSpells then
    macroTorch.effectLastingSpells = {
        ["Rake"] = true,
        ["Rip"] = true,
        ["Pounce"] = true,
    }
end

function macroTorch.isEffectLastingSpell(spell)
    return spell and macroTorch.effectLastingSpells[spell] or false
end

-- load the immuneTable from SM_EXTEND.immuneTable persistent var
function macroTorch.loadImmuneTable()
    -- init immuneTable and bind it to the SM_EXTEND.immuneTable persistent var
    if not SM_EXTEND then
        SM_EXTEND = {}
    end
    if not SM_EXTEND.immuneTable then
        SM_EXTEND.immuneTable = {}
    end
    if not macroTorch.context.immuneTable then
        macroTorch.context.immuneTable = SM_EXTEND.immuneTable
    end
end

-- records battle status
function macroTorch.CheckDodgeParryBlockResist(unitId, event, arg1)
    macroTorch.loadImmuneTable()
    -- macroTorch.show('CheckDodgeParryBlockResist: ' .. event .. ', msg: ' .. arg1)
    if not macroTorch.context then
        macroTorch.context = {}
    end

    if not arg1 then
        return
    end
    -- Your Rake crits Apprentice Training Dummy for 597.
    -- Your Rake hits Heroic Training Dummy for 173.
    local _, _, spell, mob = string.find(arg1, "Your (.-) hits (.-) for %d+%.")
    if not spell or not mob then
        _, _, spell, mob = string.find(arg1, "Your (.-) crits (.-) for %d+%.")
    end
    if spell and mob then
        -- macroTorch.show("HIT DETECTED: Spell[" .. spell .. "] by [" .. mob .. "]")
        if not macroTorch.context.landTable then
            macroTorch.context.landTable = {}
        end
        if not macroTorch.context.landTable[spell] then
            macroTorch.context.landTable[spell] = {}
        end
        macroTorch.context.landTable[spell][mob] = GetTime()
    end

    -- 尝试从 arg1 中匹配完整句式：Your <技能名> was dodged by <怪物名>.
    local _, _, spell, mob = string.find(arg1, "Your (.-) was dodged by (.-)%.")
    if spell and mob then
        -- macroTorch.show("DODGE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] dodged")
        if not macroTorch.context.dodgeTable then
            macroTorch.context.dodgeTable = {}
        end
        if not macroTorch.context.dodgeTable[spell] then
            macroTorch.context.dodgeTable[spell] = {}
        end
        macroTorch.context.dodgeTable[spell][mob] = GetTime()
    end
    -- Your Claw is parried by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(arg1, "Your (.-) is parried by (.-)%.")
    if spell and mob then
        -- macroTorch.show("PARRY DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] parried")
        if not macroTorch.context.parryTable then
            macroTorch.context.parryTable = {}
        end
        if not macroTorch.context.parryTable[spell] then
            macroTorch.context.parryTable[spell] = {}
        end
        macroTorch.context.parryTable[spell][mob] = GetTime()
    end
    --- Your Rake was resisted by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(arg1, "Your (.-) was resisted by (.-)%.")
    if spell and mob then
        -- macroTorch.show("RESIST DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] resisted")
        if not macroTorch.context.resistTable then
            macroTorch.context.resistTable = {}
        end
        if not macroTorch.context.resistTable[spell] then
            macroTorch.context.resistTable[spell] = {}
        end
        macroTorch.context.resistTable[spell][mob] = GetTime()
    end
    --- Your Rake failed. Vilemust Shadowstalker is immune.
    local _, _, spell, mob = string.find(arg1, "Your (.-) failed. (.-) is immune%.")
    if spell and mob and macroTorch.isEffectLastingSpell(spell) then
        macroTorch.show("IMMUNE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] immune")
        if not macroTorch.context.immuneTable[spell] then
            macroTorch.context.immuneTable[spell] = {}
        end
        if not macroTorch.target.isPlayerControlled then
            macroTorch.context.immuneTable[spell][mob] = GetTime()
        end
    end
end

--- all events handle globally
function macroTorch.eventHandle(event)
    if event == 'PLAYER_REGEN_ENABLED' then
        -- combat exiting
        if macroTorch.context then
            macroTorch.inCombat = false

            macroTorch.context.rakeTimer = nil
            macroTorch.context.ripTimer = nil
            macroTorch.context.ffTimer = nil
            macroTorch.context.pounceTimer = nil
            macroTorch.context.targetHealthVector = nil
        end
        macroTorch.show('Exiting combat!')
    elseif event == 'PLAYER_TARGET_CHANGED' then
        -- target changed
        if macroTorch.player.isInCombat and macroTorch.target.isCanAttack then
            if macroTorch.context then
                macroTorch.context.rakeTimer = nil
                macroTorch.context.ripTimer = nil
                macroTorch.context.ffTimer = nil
                macroTorch.context.pounceTimer = nil
                macroTorch.context.targetHealthVector = nil
            end
            macroTorch.show('Target change in combat!')
        end
    elseif event == 'PLAYER_REGEN_DISABLED' then
        -- combat entering
        if not macroTorch.context then
            macroTorch.context = {}
        end
        macroTorch.inCombat = true
        macroTorch.show('Entering combat!')
    elseif event == "UI_ERROR_MESSAGE" then
        -- on ui error message
        if not macroTorch.context then
            macroTorch.context = {}
        end
        -- arg1 is a global var be set automatically, see https://wow.gamepedia.com/UI_ERROR_MESSAGE
        -- SPELL_FAILED_NOT_BEHIND is a global constant, see https://wow.gamepedia.com/Constants/SPELL_FAILED_NOT_BEHIND
        if (arg1 == SPELL_FAILED_NOT_BEHIND) then
            macroTorch.context.behindAttackFailedTime = GetTime()
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- when player melee combat or spell is dodged, parried, blocked or resisted
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- player dodged mob's attack
    end
end
