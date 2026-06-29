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
macroTorch.DEBUFF_LAND_LAG = 0.2
-- sets what spells to trace casts
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end
function macroTorch.setSpellTracing(spellGuid, spellName)
    if not macroTorch.tracingSpells[spellGuid] then
        macroTorch.tracingSpells[spellGuid] = spellName
    end
end
-- sets what spells to tracer immune
if not macroTorch.traceSpellImmunes then
    macroTorch.traceSpellImmunes = {}
end
-- register a spell to trace its immune, this spell must be also set tracing
function macroTorch.setTraceSpellImmune(spellName, spellDebuffTexture)
    if not macroTorch.traceSpellImmunes[spellName] then
        macroTorch.traceSpellImmunes[spellName] = spellDebuffTexture
    end
end
-- note: only works when the spell and the corresponding debuff has the same texture
function macroTorch.setTraceSpellImmuneByName(spellName, bookType)
    local spellDebuffTexture = macroTorch.getSpellTexture(spellName, bookType)
    if not spellDebuffTexture then
        return
    end
    macroTorch.setTraceSpellImmune(spellName, spellDebuffTexture)
end
-- SpellTrace 声明式 API 命名空间
-- [CITED: CONTEXT.md D-06, D-07, D-08; RESEARCH A3/Pitfall 1]
macroTorch.SpellTrace = {}

-- resolve spellId from runtime-corrected map (loginContext.spellIdMap) or static baseline (SPELL_NAME_TO_ID)
-- returns nil if spell unknown (caller must handle)
function macroTorch.resolveSpellId(spellName)
    if macroTorch.loginContext and macroTorch.loginContext.spellIdMap then
        local correctedId = macroTorch.loginContext.spellIdMap[spellName]
        if correctedId then
            return correctedId
        end
    end
    return macroTorch.SPELL_NAME_TO_ID[spellName]
end

-- 声明式 spell trace 注册 API
-- config 字段: {spellId, immune, land, debuffTexture}
-- spellId: 可选，仅当 land=true 时需要（用于 setSpellTracing 的数值 ID）
-- immune (boolean): 为 true 时调用 setTraceSpellImmune
-- land (boolean): 为 true 时调用 setSpellTracing(spellId, name)
-- debuffTexture (string): immune tracing 所需的 debuff 贴图纹理
function macroTorch.SpellTrace:register(name, config)
    -- [CITED: PLAN 03-02 must_haves]
    if config.land then
        local spellId = nil
        -- resolve via spellName first (new), then fallback to config.spellId (legacy)
        if config.spellName then
            spellId = macroTorch.resolveSpellId(config.spellName)
        end
        if not spellId then
            spellId = config.spellId
        end
        if not spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId resolved", 'red')
            return
        end
        macroTorch.setSpellTracing(spellId, name)
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
-- set up the land event generation for spells set tracing
function macroTorch.maintainLandTables()
    if not macroTorch.tracingSpells or macroTorch.tableLen(macroTorch.tracingSpells) == 0 or not macroTorch.inCombat then
        return
    end
    for _, spellName in pairs(macroTorch.tracingSpells) do
        macroTorch.computeLandTable(spellName)
    end
end
macroTorch.registerPeriodicTask('maintainLandTables', { interval = 0.1, task = macroTorch.maintainLandTables })
-- record traced spells' casts
function macroTorch.recordCastTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
        return
    end
    if not macroTorch.loginContext.castTable then
        macroTorch.loginContext.castTable = {}
    end
    if not macroTorch.loginContext.castTable[spell] then
        macroTorch.loginContext.castTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.castTable[spell][mob] then
        macroTorch.loginContext.castTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    macroTorch.loginContext.castTable[spell][mob].push(GetTime())
    -- macroTorch.show(spell ..
    --     ' cast on ' ..
    --     mob .. ' is recorded/renewed to castTable: ' ..
    --     macroTorch.loginContext.castTable[spell][mob].top)
end
-- record traced spells' failures, icluding all types of failures: miss, parry, resist, immune
-- it also computes the final 'landTable' immediately, cauz the cast event must arrived upon the fail event arrive
function macroTorch.recordFailTable(spell, failType)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
        return
    end
    if not macroTorch.loginContext.failTable then
        macroTorch.loginContext.failTable = {}
    end
    if not macroTorch.loginContext.failTable[spell] then
        macroTorch.loginContext.failTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.failTable[spell][mob] then
        macroTorch.loginContext.failTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    local item = { GetTime(), failType }
    macroTorch.loginContext.failTable[spell][mob].push(item)
    local lastCast = macroTorch.peekCastEvent(spell)
    macroTorch.show(spell ..
        ' failed on ' ..
        mob ..
        ' is recorded to failTable: ' ..
        item[1] .. '(' .. item[2] .. '), lag=' .. tostring(lastCast and (item[1] - lastCast) or 'noTracing'), 'red')
end
function macroTorch.computeLandTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    -- compute the final 'landTable'
    if not macroTorch.loginContext.landTable then
        macroTorch.loginContext.landTable = {}
    end
    if not macroTorch.loginContext.landTable[spell] then
        macroTorch.loginContext.landTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.landTable[spell][mob] then
        macroTorch.loginContext.landTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    local lastCast = macroTorch.peekCastEvent(spell) or 0
    -- blip: there must be a short delay to wait the possible fail event to come
    local blip = GetTime() - lastCast
    if lastCast == 0 or blip <= 0.02 or blip > 0.9 then
        return
    end
    local lastLanded = macroTorch.peekLandEvent(spell) or 0
    -- already processed for this cast evnet
    if lastLanded == lastCast then
        return
    end
    local lastFail = macroTorch.peekFailEvent(spell)
    local lastFailedTime = lastFail and lastFail[1] or 0
    -- if no fail event near around the cast event, then it's a successful landed cast
    if math.abs(lastFailedTime - lastCast) > 0.05 then
        macroTorch.loginContext.landTable[spell][mob].push(lastCast)
        macroTorch.show(spell ..
            ' cast on ' ..
            mob .. ' landed: ' .. lastCast, 'blue')
    end
end
function macroTorch.consumeLandEvent(spell, logic)
    if not spell or not logic or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] or not macroTorch.loginContext.landTable[spell][mob].top then
        return
    end
    logic(macroTorch.loginContext.landTable[spell][mob].top)
end
function macroTorch.consumeFailEvent(spell, logic)
    if not spell or not logic or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.failTable or not macroTorch.loginContext.failTable[spell] or not macroTorch.loginContext.failTable[spell][mob] or not macroTorch.loginContext.failTable[spell][mob].top then
        return
    end
    logic(macroTorch.loginContext.failTable[spell][mob].top)
end
function macroTorch.peekCastEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.castTable or not macroTorch.loginContext.castTable[spell] or not macroTorch.loginContext.castTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.castTable[spell][mob].top
end
function macroTorch.peekFailEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.failTable or not macroTorch.loginContext.failTable[spell] or not macroTorch.loginContext.failTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.failTable[spell][mob].top
end
function macroTorch.peekLandEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.landTable[spell][mob].top
end
function macroTorch.landTableAnyMatch(spell, predicate)
    if not spell or not predicate or not macroTorch.target.isCanAttack then
        return false
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return false
    end
    return macroTorch.loginContext.landTable[spell][mob].anyMatch(predicate)
end
function macroTorch.landTableAllMatch(spell, predicate)
    if not spell or not predicate or not macroTorch.target.isCanAttack then
        return false
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return false
    end
    return macroTorch.loginContext.landTable[spell][mob].allMatch(predicate)
end

-- records battle status
function macroTorch.CheckDodgeParryBlockResist(unitId, eventType, eventMsg)
    if not eventMsg then
        return
    end
    -- (commented-out: old landTable write via self-damage hits; replaced by UNIT_CASTEVENT)
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) missed (.-)%.")
    if spell and mob then
        -- macroTorch.show("MISS DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] missed")
        macroTorch.recordFailTable(spell, 'miss')
    end
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) was dodged by (.-)%.")
    if spell and mob then
        -- macroTorch.show("DODGE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] dodged")
        macroTorch.recordFailTable(spell, 'dodge')
    end
    -- Your Claw is parried by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) is parried by (.-)%.")
    if spell and mob then
        -- macroTorch.show("PARRY DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] parried")
        macroTorch.recordFailTable(spell, 'parry')
    end
    -- Your Rake was resisted by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) was resisted by (.-)%.")
    if spell and mob then
        -- macroTorch.show("RESIST DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] resisted")
        macroTorch.recordFailTable(spell, 'resist')
    end
    -- Your Rake was blocked by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) was blocked by (.-)%.")
    if spell and mob then
        -- macroTorch.show("BLOCK DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] blocked")
        macroTorch.recordFailTable(spell, 'block')
    end
    -- Your Rake failed. Vilemust Shadowstalker is immune.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) failed. (.-) is immune%.")
    if spell and mob then
        -- macroTorch.show("IMMUNE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] immune")
        macroTorch.recordFailTable(spell, 'immune')
    end
end