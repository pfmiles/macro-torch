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
-- provides independent event frame, 15 event registrations, eventHandle dispatch

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
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- super wow specific
if SUPERWOW_STRING ~= nil then
    frame:RegisterEvent("UNIT_CASTEVENT")
    frame:RegisterEvent("RAW_COMBATLOG")
end

function macroTorch.eventHandle()
    if event == 'PLAYER_LOGIN' then
        -- on player login
    elseif event == 'PLAYER_ENTERING_WORLD' then
        macroTorch.onPlayerEnteringWorld()
        -- Defer selfTest by ~30 frames (~0.5s at 60fps) so UI subsystems
        -- (tooltip, inventory) are fully initialized before tests that depend
        -- on them (e.g. computeReshiftEnergy creates a cached GameTooltip frame;
        -- creating it too early produces a persistent bad state that causes
        -- session-long failures like Wolfsheart detection).
        if not macroTorch._selfTestRan then
            -- Defer selftest by ~30 frames (~0.5s at 60fps) to ensure GameTooltip
            -- manager is fully initialized before creating the cached _tooltipScanFrame.
            -- A single OnUpdate frame is not enough on all hardware configurations.
            macroTorch._selfTestFrame = macroTorch._selfTestFrame or CreateFrame("Frame")
            macroTorch._selfTestDelay = 30
            macroTorch._selfTestFrame:SetScript("OnUpdate", function()
                macroTorch._selfTestDelay = macroTorch._selfTestDelay - 1
                if macroTorch._selfTestDelay > 0 then
                    return
                end
                macroTorch.SelfTest:run()
                macroTorch._selfTestFrame:SetScript("OnUpdate", nil)
            end)
        end
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
        -- self-hit land dispatch: 'Your <skill> hits/crits <target>' lines are
        -- client-authenticated (own-cast chat filter), so the land needs no
        -- intent pairing — onSelfDamageLine pairs best-effort only
        if event == 'CHAT_MSG_SPELL_SELF_DAMAGE' then
            macroTorch.onSelfDamageLine(arg1, GetTime())
        end
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
        local unitId, _, castType = arg1, arg2, arg3
        -- only CAST events carry spellId data; MAINHAND/OFFHAND are auto-attack swings
        if unitId == macroTorch.player.guid and castType == 'CAST' then
            -- Bridge-based spell identification: _castSpell sets _pendingCastSpellName
            -- (always English name) before calling CastSpellByName; UNIT_CASTEVENT
            -- fires shortly after. Zero manual spellId maintenance.
            -- Also handles instant spells correctly (UNIT_SPELLCAST_SUCCEEDED does
            -- not fire for instant spells on 1.12.1/SuperWoW).
            if macroTorch._pendingCastSpellName then
                if macroTorch.tracingSpells[macroTorch._pendingCastSpellName] then
                    macroTorch.recordCastTable(macroTorch._pendingCastSpellName)
                end
                macroTorch._pendingCastSpellName = nil
            end
        end
    elseif event == "RAW_COMBATLOG" then
        -- [cpDamage] phase 28 channel gate: dispatch SELF_DAMAGE raw lines to
        -- the cpDamage parser before the tier-1 whitelist returns below. The
        -- gate consumes the line here and the tier-1 set stays untouched, so
        -- land consumers keep seeing only the two periodic channels - the two
        -- consumers stay fully disjoint per channel. The existing
        -- CHAT_MSG_SPELL_SELF_DAMAGE chat-filter branch earlier in this
        -- handler is not touched; this gate only serves the RAW stream.
        if macroTorch.cpDamageLog and arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' and arg2 then
            macroTorch.onCpDamageLine(arg2, GetTime())
        end
        -- production event-driven land handler (three-tier filter, debug
        -- decision #6).
        -- Tier 1 (channel whitelist): only the two periodic-damage channels
        -- carry aura-apply lines; every other channel returns immediately
        -- without touching arg2.
        if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then
            return
        end
        -- Tier 2 + Tier 3 (substring precheck + registered spell match):
        -- O(N) string.find over the precompiled per-spell patterns, N =
        -- registered aura-apply spells; the pattern embeds the
        -- ' is afflicted by ' precheck so a non-apply line costs at most N
        -- finds with zero allocation on the hot path. apply lines are
        -- target-owned, so the land must pair with our own cast intent inside
        -- processRawAuraApply (hits/crits lands arrive via our own chat
        -- filter on CHAT_MSG_SPELL_SELF_DAMAGE instead).
        if arg2 then
            for spellName, pattern in pairs(macroTorch.auraApplySpellPatterns) do
                if string.find(arg2, pattern) then
                    macroTorch.processRawAuraApply(spellName, arg2, macroTorch.target.guid, GetTime())
                    break
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1=unit (e.g. "player"), arg2=spellName, arg3=rank, arg4=target
        if arg1 == "player" and arg2 and macroTorch.tracingSpells[arg2] then
            macroTorch.recordCastTable(arg2)
        end
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