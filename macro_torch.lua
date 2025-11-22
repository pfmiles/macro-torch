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
if not macroTorch then
    macroTorch = {}
end
--- all spell names which has a lasting effect on the enemy
if not macroTorch.effectLastingSpells then
    macroTorch.effectLastingSpells = {
        ["Rake"] = true,
        ["Rip"] = true,
        ["Pounce"] = true,
    }
end

-- global event listening
local frame = CreateFrame("Frame")

-- frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
-- frame:RegisterEvent("PLAYER_DEAD")
-- frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
-- frame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")

-- super wow specific
if SUPERWOW_STRING then
    frame:RegisterEvent("UNIT_CASTEVENT")
    -- frame:RegisterEvent("RAW_COMBATLOG")
end

function macroTorch.eventHandle()
    if event == 'PLAYER_LOGIN' then
        -- on player login
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- on player entering world
        macroTorch.loginContext = {}
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
    elseif event == 'SPELLCAST_START' then
        -- on spell cast start
    elseif event == 'SPELLCAST_STOP' then
        -- on spell cast stop
    elseif event == 'SPELLCAST_FAILED' then
        -- on spell cast failed
    elseif event == 'SPELLCAST_INTERRUPTED' then
        -- on spell cast interrupted
    elseif event == 'PLAYER_REGEN_ENABLED' then
        -- combat exiting
        if macroTorch.context then
            macroTorch.inCombat = false
            macroTorch.context = {}
        end
        macroTorch.show('Exiting combat!')
    elseif event == 'PLAYER_REGEN_DISABLED' then
        -- combat entering
        if not macroTorch.context then
            macroTorch.context = {}
        end
        macroTorch.inCombat = true
        macroTorch.show('Entering combat!')
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- macroTorch.show("event: " ..
        --     tostring(event) ..
        --     ", arg1: " ..
        --     tostring(arg1) ..
        --     ", arg2: " ..
        --     tostring(arg2) ..
        --     ", arg3: " ..
        --     tostring(arg3) ..
        --     ", arg4: " ..
        --     tostring(arg4) ..
        --     ", arg5: " ..
        --     tostring(arg5) ..
        --     ", arg6: " ..
        --     tostring(arg6))
        -- when player melee combat or spell is dodged, parried, blocked or resisted
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == "PLAYER_DEAD" then
        -- on player dead
    elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        -- when player get a buff
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        -- when player lose a buff
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        -- macroTorch.show("event: " ..
        --     tostring(event) ..
        --     ", arg1: " ..
        --     tostring(arg1) ..
        --     ", arg2: " ..
        --     tostring(arg2) ..
        --     ", arg3: " ..
        --     tostring(arg3) ..
        --     ", arg4: " ..
        --     tostring(arg4) ..
        --     ", arg5: " ..
        --     tostring(arg5) ..
        --     ", arg6: " ..
        --     tostring(arg6))
    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then

    elseif event == "UNIT_CASTEVENT" then
        -- when player myself cast a spell
        if arg1 == macroTorch.player.guid and arg3 == 'CAST' then
            -- record self bleeding spell cast
            if arg4 == 9827 then
                -- pounce
                macroTorch.recordCastTable('Pounce')
            end
            if arg4 == 9904 then
                -- rake
                macroTorch.recordCastTable('Rake')
            end
            if arg4 == 9896 then
                -- rip
                macroTorch.recordCastTable('Rip')
            end
        end
    elseif event == "RAW_COMBATLOG" then
        -- when player cast a spell
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
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- player dodged mob's attack
    end
end

frame:SetScript("OnEvent", macroTorch.eventHandle)

function macroTorch.recordCastTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.context.landTable then
        macroTorch.context.landTable = {}
    end
    if not macroTorch.context.landTable[spell] then
        macroTorch.context.landTable[spell] = {}
    end
    macroTorch.context.landTable[spell][macroTorch.target.name] = GetTime()
    macroTorch.show(spell ..
        ' cast on ' ..
        macroTorch.target.name .. ' is recorded/renewed to landTable: ' ..
        macroTorch.context.landTable[spell][macroTorch.target.name])
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

    if not arg1 then
        return
    end

    -- landTable的写入已由UNIT_CASTEVENT事件负责，只记录自己的动作，更加准确
    -- Your Rake crits Apprentice Training Dummy for 597.
    -- Your Rake hits Heroic Training Dummy for 173.
    -- local _, _, spell, mob = string.find(arg1, "Your (.-) hits (.-) for %d+%.")
    -- if not spell or not mob then
    --     _, _, spell, mob = string.find(arg1, "Your (.-) crits (.-) for %d+%.")
    -- end
    -- if spell and mob then
    --     -- macroTorch.show("HIT DETECTED: Spell[" .. spell .. "] by [" .. mob .. "]")
    --     if not macroTorch.context.landTable then
    --         macroTorch.context.landTable = {}
    --     end
    --     if not macroTorch.context.landTable[spell] then
    --         macroTorch.context.landTable[spell] = {}
    --     end
    --     macroTorch.context.landTable[spell][mob] = GetTime()
    -- end

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
    if spell and mob then
        -- macroTorch.show("IMMUNE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] immune")
        macroTorch.target.recordImmune(spell)
    end
end
