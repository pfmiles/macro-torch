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

-- spell immune tracing and deterministic table loading
-- extracted from battle_event_queue.lua per D-02
-- provides spellsImmuneTracing, loadImmuneTable, loadDefiniteBleedingTable

-- set up the automatic immune tracing
-- KNOWN RACE WINDOW: The callback closures passed to consumeFailEvent and
-- consumeLandEvent reference macroTorch.target.isPlayerControlled. Between
-- when a spell event is recorded and when the periodic task (every 0.1s)
-- processes it, the player may have tab-targeted a different unit, causing
-- macroTorch.target to point to a different entity than the original event
-- target. This is acceptable for PvE content where targeting changes are
-- rare mid-combat. If stricter accuracy is needed in the future, store the
-- mob name inside the consume callback and perform an explicit API lookup.
function macroTorch.spellsImmuneTracing()
    if not macroTorch.traceSpellImmunes or macroTorch.tableLen(macroTorch.traceSpellImmunes) == 0 or not macroTorch.inCombat then
        return
    end
    macroTorch.loadImmuneTable()

    for spellName, spellDebuffTexture in pairs(macroTorch.traceSpellImmunes) do
        -- detect immune from fail events
        macroTorch.consumeFailEvent(spellName, function(failEvent)
            if GetTime() - failEvent[1] > 0.4 or failEvent[2] ~= 'immune' or not macroTorch.target.isCanAttack then
                return
            end
            -- 检测到近期的一次immune事件，若整个landTable均无有效land记录，则加入immune列表, 若有任意land记录，则加入definite表
            if not macroTorch.target.isDefiniteBleeding(spellName) and not macroTorch.target.isPlayerControlled then
                macroTorch.show("recording immune by fail event: " .. tostring(failEvent[2] .. ':' .. failEvent[1]))
                macroTorch.target.recordImmune(spellName)
            end
        end)
        -- detect immune from landed and no bleeding effect tests
        macroTorch.consumeLandEvent(spellName, function(landEvent)
            local timeElapsed = GetTime() - landEvent
            if timeElapsed <= macroTorch.DEBUFF_LAND_LAG or timeElapsed > 0.6 or not macroTorch.target.isCanAttack then
                return
            end
            -- 检测到合适时间以内的命中记录，若此时目标身上没有debuff, 则记录immune,否则删除immune记录
            if not macroTorch.target.hasBuff(spellDebuffTexture) and not macroTorch.target.isDefiniteBleeding(spellName) and not macroTorch.target.isPlayerControlled then
                macroTorch.show("recording immune by land event: " .. landEvent)
                macroTorch.target.recordImmune(spellName)
            else
                macroTorch.target.recordDefiniteBleeding(spellName)
            end
        end)
    end
end

macroTorch.registerPeriodicTask('spellsImmuneTracing',
    { interval = 0.1, task = macroTorch.spellsImmuneTracing })

-- load the immuneTable from SM_EXTEND.immuneTable persistent var
function macroTorch.loadImmuneTable()
    if not macroTorch.context then return end
    -- init immuneTable and bind it to the SM_EXTEND.immuneTable persistent var
    if not SM_EXTEND then
        SM_EXTEND = {}
    end
    if not SM_EXTEND.immuneTable then
        SM_EXTEND.immuneTable = {}
    end
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.immuneTable[playerCls] then
        SM_EXTEND.immuneTable[playerCls] = {}
    end
    if not macroTorch.context.immuneTable then
        macroTorch.context.immuneTable = SM_EXTEND.immuneTable[playerCls]
    end
end

-- load the definiteBleedingTable from SM_EXTEND.definiteBleedingTable persistent var
function macroTorch.loadDefiniteBleedingTable()
    if not macroTorch.context then return end
    -- init definiteBleedingTable and bind it to the SM_EXTEND.definiteBleedingTable persistent var
    if not SM_EXTEND then
        SM_EXTEND = {}
    end
    if not SM_EXTEND.definiteBleedingTable then
        SM_EXTEND.definiteBleedingTable = {}
    end
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.definiteBleedingTable[playerCls] then
        SM_EXTEND.definiteBleedingTable[playerCls] = {}
    end
    if not macroTorch.context.definiteBleedingTable then
        macroTorch.context.definiteBleedingTable = SM_EXTEND.definiteBleedingTable[playerCls]
    end
end