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
--]]

-- energy tick forensics probe (quick 260915-tt3): flag-gated, additive-only, SavedVariables-only instrumentation

-- Session flag: the nil-guard re-arms the default on every login; a
-- mid-session /run macroTorch.energyProbe = true toggle needs no reload.
if macroTorch.energyProbe == nil then
    macroTorch.energyProbe = false
end

-- Probe-only persistence sink: lines land exclusively in the probeTick
-- buffer, capped at 2500 entries. The first-write nil-guards mirror the
-- macroTorch.log double-guard so a fresh MACRO_TORCH_LOG SavedVariables
-- table still rebuilds the nursery on first call. This function never
-- writes the chat frame and never reroutes through the shared display sink.
function macroTorch.energyProbeLog(line)
    if not MACRO_TORCH_LOG then MACRO_TORCH_LOG = { messages = {}, maxSize = 500 } end
    if not MACRO_TORCH_LOG.probeTick then MACRO_TORCH_LOG.probeTick = { messages = {}, maxSize = 2500 } end
    while macroTorch.tableLen(MACRO_TORCH_LOG.probeTick.messages) >= MACRO_TORCH_LOG.probeTick.maxSize do table.remove(MACRO_TORCH_LOG.probeTick.messages, 1) end
    table.insert(MACRO_TORCH_LOG.probeTick.messages, tostring(line))
end

-- Per-event-name baselines for deltas: energy and timestamp bucketed by the
-- event string (Lua 5.0 grammar, no hash-length operator in this file).
local lastEnergy = {}
local lastTime = {}
local lastPollEnergy = nil
local pollAccum = 0

-- Sole occurrence of the chat energize event name: registration and the
-- matching branch below both reference this local.
local CHAT_ENERGIZE_EVENT = "CHAT_MSG_SPELL_PERIODIC_SELF_ENERGIZE"

-- Standalone frame: no shared frame, no shared handler with core/events.lua,
-- so no double dispatch of UNIT events can occur.
local probeFrame = CreateFrame("Frame")
probeFrame:RegisterEvent("UNIT_ENERGY")
probeFrame:RegisterEvent("UNIT_MANA")
probeFrame:RegisterEvent(CHAT_ENERGIZE_EVENT)
probeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Shared EV line emitter: one UnitMana call with its two returns per firing
-- (energy + max, SuperWoW dual-return); worker arg varies by source channel.
local function recordEvLine(evName, evArg)
    local now = GetTime()
    local e, m = UnitMana('player')
    m = m or 0
    local d = math.floor(e - (lastEnergy[evName] or e))
    local dt = 0
    if lastTime[evName] then
        dt = math.floor((now - lastTime[evName]) * 1000)
    end
    lastEnergy[evName] = e
    lastTime[evName] = now
    macroTorch.energyProbeLog(string.format("EPR|EV|%s|t=%.3f|earg=%s|e=%s|m=%s|d=%d|dt=%d", evName, now, tostring(evArg), tostring(e), tostring(m), d, dt))
end

-- WoW 1.12 frame-script convention: global event / arg1 carry the payload.
local function probeOnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Fresh session baseline: reset unconditionally, emit nothing while
        -- the flag is off (zero output, zero persistent writes).
        lastEnergy = {}
        lastTime = {}
        lastPollEnergy = nil
        pollAccum = 0
        if not macroTorch.energyProbe then return end
        local form = '0'
        -- Defensive getter read: any missing player reference or getter
        -- error degrades to '0' instead of interrupting the event chain.
        local okForm, inCatForm = pcall(function() return macroTorch.player and macroTorch.player.isInCatForm end)
        if okForm and inCatForm then
            form = '1'
        end
        local okNet, bIn, bOut, latHome, latWorld = pcall(GetNetStats)
        local net = 'pcfail'
        if okNet then
            net = tostring(bIn) .. '/' .. tostring(bOut) .. '/' .. tostring(latHome) .. '/' .. tostring(latWorld)
        end
        macroTorch.energyProbeLog(string.format("EPR|SES|t=%.3f|form=%s|net=%s", GetTime(), form, net))
        return
    end
    if not macroTorch.energyProbe then return end
    if event == "UNIT_ENERGY" or event == "UNIT_MANA" then
        -- Non-player units are skipped whole: zero rows, zero API reads.
        -- Player firings are all recorded (both directions, zero deltas too).
        if arg1 ~= 'player' then return end
        recordEvLine(event, arg1)
    elseif event == CHAT_ENERGIZE_EVENT then
        -- Self energize chat line: no unit guard by design (SELF channel);
        -- arg1 carries the spell energize message text.
        recordEvLine(event, arg1)
    end
end

-- Accumulating poll: elapsed tallies until 1.0, then one line per frame and
-- the remainder carries over (no reset, prevents long-term drift).
local function probeOnUpdate(elapsed)
    if not macroTorch.energyProbe then
        pollAccum = 0
        return
    end
    pollAccum = pollAccum + elapsed
    if pollAccum < 1.0 then return end
    local e, m = UnitMana('player')
    m = m or 0
    local d = e - (lastPollEnergy or e)
    lastPollEnergy = e
    local c = UnitAffectingCombat('player') and '1' or '0'
    pollAccum = pollAccum - 1.0
    macroTorch.energyProbeLog(string.format("EPR|POLL|t=%.3f|e=%s|m=%s|d=%d|c=%s", GetTime(), tostring(e), tostring(m), d, c))
end

probeFrame:SetScript("OnEvent", probeOnEvent)
probeFrame:SetScript("OnUpdate", probeOnUpdate)