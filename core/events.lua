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

-- event frame and centralized event handling
-- extracted from battle_event_queue.lua per D-01/D-03
-- provides independent event frame, 14 event registrations, eventHandle dispatch

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
frame:RegisterEvent("UI_ERROR_MESSAGE")

-- super wow specific
if SUPERWOW_STRING ~= nil then
    frame:RegisterEvent("UNIT_CASTEVENT")
    -- frame:RegisterEvent("RAW_COMBATLOG")
end

function macroTorch.eventHandle()
    if event == 'PLAYER_LOGIN' then
        -- on player login
    elseif event == 'PLAYER_ENTERING_WORLD' then
        macroTorch.onPlayerEnteringWorld()
        macroTorch.SelfTest:run()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        -- target changed
        if macroTorch.player.isInCombat and macroTorch.target.isCanAttack then
            if macroTorch.context then
                macroTorch.context.ffTimer = nil
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
        macroTorch.onCombatExit()
    elseif event == 'PLAYER_REGEN_DISABLED' then
        macroTorch.onCombatEnter()
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- when player melee combat or spell is dodged, parried, blocked or resisted
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == "PLAYER_DEAD" then
        -- on player dead
    elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        -- when player get a buff
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        -- when player lose a buff
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then

    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then

    elseif event == "UNIT_CASTEVENT" then
        -- when player myself cast a spell
        local unitId, targetId, castType, spellId, timeCost = arg1, arg2, arg3, arg4, arg5
        if unitId == macroTorch.player.guid and castType ~= 'MAINHAND' and castType ~= 'OFFHAND' then
            macroTorch.show('unitId=' .. tostring(unitId) .. ', targetId=' .. tostring(targetId) .. ', type=' .. tostring(castType) .. ', spellId=' .. tostring(spellId) .. ', timeCost=' .. tostring(timeCost))
        end
        if unitId == macroTorch.player.guid and castType == 'CAST' then
            if spellId and macroTorch.tracingSpells[spellId] then
                macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
            end
            -- spellId dynamic correction: compare event spellId with static baseline
            -- from _castSpell's current_casting_spell, persist mismatches to SM_EXTEND
            if macroTorch.current_casting_spell then
                local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
                if staticSpellId and staticSpellId ~= spellId then
                    -- lazy-init SM_EXTEND.spellIdMap (same pattern as loadImmuneTable)
                    if not SM_EXTEND then SM_EXTEND = {} end
                    if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
                    local playerCls = macroTorch.player.class
                    if not SM_EXTEND.spellIdMap[playerCls] then SM_EXTEND.spellIdMap[playerCls] = {} end
                    -- persist corrected spellId
                    SM_EXTEND.spellIdMap[playerCls][macroTorch.current_casting_spell] = spellId
                    -- sync to loginContext if already initialized
                    if macroTorch.loginContext and macroTorch.loginContext.spellIdMap then
                        macroTorch.loginContext.spellIdMap[macroTorch.current_casting_spell] = spellId
                    end
                    -- migrate tracingSpells key: old static id -> new event id
                    macroTorch.tracingSpells[spellId] = macroTorch.tracingSpells[staticSpellId]
                    macroTorch.tracingSpells[staticSpellId] = nil
                    macroTorch.show(string.format("[macro-torch] spellId corrected: %s %d -> %d",
                        macroTorch.current_casting_spell, staticSpellId, spellId), 'yellow')
                end
                -- clear bridge variable after processing (must clear even if no mismatch)
                macroTorch.current_casting_spell = nil
            end
        end
    elseif event == "RAW_COMBATLOG" then
        -- when player cast a spell
        -- local args_str = tostring(arg1) ..
        --     '_' .. tostring(arg2) .. '_' .. tostring(arg3) .. '_' .. tostring(arg4) .. '_' .. tostring(arg5)
        -- if args_str and string.find(string.lower(args_str), "dodge") then
        --     macroTorch.show(args_str)
        -- end
    elseif event == "UI_ERROR_MESSAGE" then
        -- on ui error message
        -- macroTorch.show('Error msg: ' ..
        --     tostring(arg1) .. '_' .. tostring(arg2) .. '_' .. tostring(arg3) .. '_' .. tostring(arg4))
        -- arg1 is a global var be set automatically, see https://wow.gamepedia.com/UI_ERROR_MESSAGE
        -- SPELL_FAILED_NOT_BEHIND is a global constant, see https://wow.gamepedia.com/Constants/SPELL_FAILED_NOT_BEHIND
        if (tostring(arg1) == 'You must be behind your target') then
            if macroTorch.context then
                macroTorch.context.behindAttackFailedTime = GetTime()
            end
        end
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- player dodged mob's attack
    end
end

frame:SetScript("OnEvent", macroTorch.eventHandle)