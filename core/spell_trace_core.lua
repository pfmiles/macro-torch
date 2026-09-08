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
-- intent pending-window seconds before expiry (event-driven land pairing)
macroTorch.LAND_INTENT_TTL = 2
-- sets what spells to trace casts
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end
-- per-spell land source registry ('self-hit' default; 'aura-apply' lands come
-- from RAW_COMBATLOG aura-apply lines and require intent pairing)
if not macroTorch.landSources then
    macroTorch.landSources = {}
end
-- precompiled find patterns for aura-apply land spells (' is afflicted by <spell>.')
if not macroTorch.auraApplySpellPatterns then
    macroTorch.auraApplySpellPatterns = {}
end
function macroTorch.setSpellTracing(spellName)
    macroTorch.tracingSpells[spellName] = true
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

-- 声明式 spell trace 注册 API
-- config 字段: {immune, land, debuffTexture, spellName}
-- immune (boolean): 为 true 时调用 setTraceSpellImmune
-- land (boolean): 为 true 时调用 setSpellTracing(name)
-- debuffTexture (string): immune tracing 所需的 debuff 贴图纹理
-- spellName (string): 可选，应与注册名 name 一致，仅用于 guard invariant 校验
function macroTorch.SpellTrace:register(name, config)
    -- [CITED: PLAN 03-02 must_haves]
    if config.land then
        macroTorch.setSpellTracing(name)
        macroTorch.landSources[name] = config.landSource or 'self-hit'
        if config.landSource == 'aura-apply' then
            -- pattern is built by raw concatenation: the registered spell name
            -- enters a Lua find pattern, so names must stay free of pattern
            -- metacharacters (all four current aura-apply names qualify)
            macroTorch.auraApplySpellPatterns[name] = ' is afflicted by ' .. name .. '%.'
        end
    end
    -- Guard invariant: when config.spellName is set, it must equal
    -- the registration name. Otherwise immunity detection through
    -- fail events from chat message parsing silently breaks
    -- (failTable is keyed by the name parsed from chat, which must
    -- match the registration name).
    if config.spellName and config.spellName ~= name then
        macroTorch.show("[macro-torch] SpellTrace:register(" .. name ..
            "): spellName='" .. tostring(config.spellName) .. "' differs from registration name", 'red')
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
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
    -- dedup: skip if same spell on same mob within 0.2s
    -- prevents double-recording from duplicate event firings (Phase 24+ UNIT_SPELLCAST_SUCCEEDED only)
    local last = macroTorch.loginContext.castTable[spell][mob].top
    if last and (GetTime() - last) < 0.2 then
        return
    end
    macroTorch.loginContext.castTable[spell][mob].push(GetTime())
    -- macroTorch.show(spell ..
    --     ' cast on ' ..
    --     mob .. ' is recorded/renewed to castTable: ' ..
    --     macroTorch.loginContext.castTable[spell][mob].top)
    -- seed a cast intent consumed by event-driven land pairing (pairLandIntent);
    -- expires after LAND_INTENT_TTL if no land/fail event arrives
    if not macroTorch.loginContext.intentTable then
        macroTorch.loginContext.intentTable = {}
    end
    if not macroTorch.loginContext.intentTable[spell] then
        macroTorch.loginContext.intentTable[spell] = {}
    end
    if not macroTorch.loginContext.intentTable[spell][mob] then
        macroTorch.loginContext.intentTable[spell][mob] = macroTorch.LRUStack:new(32)
    end
    macroTorch.loginContext.intentTable[spell][mob].push({ state = 'pending', castAt = GetTime(), landAt = nil })
    -- [RAWDIAG2 quick 260907-mhh] arm the RAW_COMBATLOG forensics scout on a
    -- recorded in-combat Rip cast (pure additive state recording; no existing
    -- branch, return value or scheduling is touched). The scout itself dumps in
    -- events.lua's RAW_COMBATLOG branch, before the channel whitelist. Every arm
    -- resets the line/sample counters and the capture runs until combat exit —
    -- nothing disarms it before leaving combat. The rotation casts Rip once per
    -- fight (refreshes come from Ferocious Bite, not a recast), so each fight
    -- anchors one full capture (the decisive multi-cat overlap evidence is
    -- per-fight). State lives only in
    -- macroTorch.context: combat exit wipes it, nothing is persisted, and the
    -- gating shares no state with any other diagnostic switch.
    if spell == 'Rip' and macroTorch.rawdiag2Enabled and macroTorch.context and macroTorch.inCombat then
        macroTorch.context._rawdiag2Lines = 0
        macroTorch.context._rawdiag2Samples = 0
        macroTorch.context._rawdiag2Active = true
        macroTorch.context._rawdiag2Start = GetTime()
        macroTorch.log('[RAWDIAG2] scout armed by Rip cast record, until combat exit', 'green')
    end
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
    -- failType is threaded through so the revocation branch can name the fail
    -- type when it cancels a previously announced green landing (fail-wins)
    macroTorch.finalizeFail(spell, item[1], failType)
end
-- pairs a land event with an unconsumed cast intent recorded within
-- LAND_INTENT_TTL seconds before the land. First runs a purge pass expiring
-- stale pending intents, then picks the newest still-pending intent whose
-- castAt is <= landTime and inside the TTL window. Never pairs an intent
-- already failed or landed (the fail-wins guarantee).
function macroTorch.pairLandIntent(spell, landTime)
    if not spell or not macroTorch.target.isCanAttack then
        return nil
    end
    if not macroTorch.loginContext or not macroTorch.loginContext.intentTable or
            not macroTorch.loginContext.intentTable[spell] then
        return nil
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.intentTable[spell][mob] then
        return nil
    end
    local stack = macroTorch.loginContext.intentTable[spell][mob]
    -- purge pass: expire pending intents older than the TTL window
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and (landTime - intent.castAt) > macroTorch.LAND_INTENT_TTL then
            intent.state = 'expired'
        end
    end
    -- pair pass: newest pending intent whose cast precedes this land
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and intent.castAt <= landTime and
                (landTime - intent.castAt) <= macroTorch.LAND_INTENT_TTL then
            intent.state = 'landed'
            intent.landAt = landTime
            return intent
        end
    end
    return nil
end
-- [RAWDIAG2 quick 260907-mhh] read-only pending-intent stack depth for a spell
-- on the current target (feeds the safeRip ctx stamp's intentDepth field).
-- Pure forensics utility: zero writes, defined next to the intentTable it reads.
function macroTorch.rawdiag2IntentDepth(spell)
    local mob = macroTorch.target.name
    if macroTorch.loginContext and macroTorch.loginContext.intentTable and
            macroTorch.loginContext.intentTable[spell] and
            macroTorch.loginContext.intentTable[spell][mob] then
        return macroTorch.tableLen(macroTorch.loginContext.intentTable[spell][mob].elements)
    end
    return 0
end
-- cpDamage pairing (phase 28): purge/pair skeleton copied from pairLandIntent
-- but without state/landAt - damage pairing carries no fail-wins semantics.
-- The pairing key is guid + TTL window by default; when `want` is given the
-- paired intent's sample.spell must also equal it (WR-02: a stale intent must
-- never be consumed by a different skill's damage line). A guid match whose
-- spell mismatches matches nothing and consumes nothing, leaving the intent
-- pending for its own line. Reuses macroTorch.LAND_INTENT_TTL (2s, D-02).
function macroTorch.pairCpDamageIntent(guid, now, want)
    if not guid or not macroTorch.loginContext or not macroTorch.loginContext.cpDamageIntents then
        return nil
    end
    local stack = macroTorch.loginContext.cpDamageIntents
    -- purge pass: drop intents older than the TTL window
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if (now - intent.castAt) > macroTorch.LAND_INTENT_TTL then
            table.remove(stack.elements, i)
        end
    end
    -- pair pass: newest intent whose guid (and, when given, spell) matches
    -- inside the window. The spell gate lives inside the match condition on
    -- purpose: a guid match with a spell mismatch must not consume the
    -- intent, so the gate can never run after a table.remove.
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.guid ~= nil and intent.castAt <= now and
                (now - intent.castAt) <= macroTorch.LAND_INTENT_TTL and
                string.lower(intent.guid) == string.lower(guid) and
                (want == nil or (intent.sample and intent.sample.spell == want)) then
            table.remove(stack.elements, i)
            return intent.sample
        end
    end
    return nil
end
-- cpDamage line parser (phase 28): two Lua 5.0-legal string.find attempts in
-- order, never one combined pattern. Lua patterns have no | alternation and
-- captured subpatterns cannot take quantifiers, so a combined (hits|crits)
-- pattern would only ever match the literal text and never reach a real
-- damage line, silencing the whole collection chain. The verb is defined by
-- whichever pattern matched (the literal verb is itself the {hits, crits}
-- whitelist member, kept as the A3 tolerance). Neither pattern anchors the
-- line end, so "(N absorbed/blocked)" suffixes are tolerated. miss/dodge/
-- parry lines match neither pattern and are dropped with zero extra code
-- (D-03); a damage line that pairs with no intent (e.g. a plain white hit)
-- is dropped the same way.
function macroTorch.onCpDamageLine(eventMsg, now)
    if not macroTorch.cpDamageLog or not eventMsg then
        return
    end
    local _, _, spellName, guid, dmgStr = string.find(eventMsg, '^Your (.-) hits (0x[0-9A-Fa-f]+) for (%d+)%.')
    local crit = false
    if not guid then
        _, _, spellName, guid, dmgStr = string.find(eventMsg, '^Your (.-) crits (0x[0-9A-Fa-f]+) for (%d+)%.')
        crit = true
    end
    if not guid then
        return
    end
    -- spell whitelist (WR-02): only sampled skills may consume a pending
    -- intent. Any other spell's damage line (Rake in particular) is dropped
    -- here, BEFORE pairing, so it can never touch the intent stack.
    local want
    if spellName == 'Claw' then want = 'claw'
    elseif spellName == 'Shred' then want = 'shred'
    elseif spellName == 'Ferocious Bite' then want = 'bite' end
    if not want then
        return
    end
    local sample = macroTorch.pairCpDamageIntent(guid, now, want)
    if not sample then
        return
    end
    macroTorch.cpDamageEvent(sample, tonumber(dmgStr), crit)
end
-- assemble one [cpDamage] JSON line (phase 28). The fixed 11-field order
-- spell dmg crit e energyPool bleedCount isOoc isBehind cp t batch is part of
-- the encode/decode interop contract with tools/cpdamage.lua (RESEARCH 3).
function macroTorch.cpDamageEvent(sample, dmg, crit)
    local json = '{"spell":' .. macroTorch.jsonEncodeScalar(sample.spell) ..
        ',"dmg":' .. macroTorch.jsonEncodeScalar(dmg) ..
        ',"crit":' .. macroTorch.jsonEncodeScalar(crit) ..
        ',"e":' .. macroTorch.jsonEncodeScalar(sample.e) ..
        ',"energyPool":' .. macroTorch.jsonEncodeScalar(sample.energyPool) ..
        ',"bleedCount":' .. macroTorch.jsonEncodeScalar(sample.bleedCount) ..
        ',"isOoc":' .. macroTorch.jsonEncodeScalar(sample.isOoc) ..
        ',"isBehind":' .. macroTorch.jsonEncodeScalar(sample.isBehind) ..
        ',"cp":' .. macroTorch.jsonEncodeScalar(sample.cp) ..
        ',"t":' .. macroTorch.jsonEncodeScalar(sample.t) ..
        ',"batch":' .. macroTorch.jsonEncodeScalar(sample.batch) .. '}'
    macroTorch.log('[cpDamage] ' .. json)
end
-- records a land event on the landTable and dispatches registered listeners.
-- Does NOT touch intent state: pairing is the caller's job (aura-apply pairs
-- first and drops the land on no intent; self-hit pairs best-effort; the
-- bleed-renewal rewrites in 27-02 pair nothing).
function macroTorch.recordLandEvent(spell, landTime)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
        return
    end
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
    macroTorch.loginContext.landTable[spell][mob].push(landTime)
    if macroTorch.landListeners and macroTorch.landListeners[spell] then
        for _, listener in ipairs(macroTorch.landListeners[spell]) do
            listener(spell, landTime)
        end
    end
end
-- registers a listener invoked on every land event recorded for this spell
function macroTorch.onLandEvent(spell, fn)
    if not macroTorch.landListeners then
        macroTorch.landListeners = {}
    end
    if not macroTorch.landListeners[spell] then
        macroTorch.landListeners[spell] = {}
    end
    table.insert(macroTorch.landListeners[spell], fn)
end
-- handles a RAW aura-apply line ('<guid> is afflicted by <Spell>.') for an
-- aura-apply land source: parses the guid and requires a case-insensitive
-- match with the current target (ownership check), then pairs the line with a
-- cast intent — the land timestamp IS the apply event time. Returns the paired
-- intent, or nil when the line is not ours / does not pair.
function macroTorch.processRawAuraApply(spellName, rawText, targetGuid, now)
    if not spellName or not rawText then
        return nil
    end
    -- [RAWDIAG2 quick 260907-mhh] pair ledger armed only inside a live scout window.
    -- Combat exit wipes macroTorch.context, so the armed flag cannot leak into a
    -- later fight or into a selftest run (out-of-combat /mt never arms it).
    local armed = macroTorch.context and macroTorch.context._rawdiag2Active
    local markerPos = string.find(rawText, ' is afflicted by ')
    if not markerPos then
        if armed then
            macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:no-apply-marker', 'yellow')
        end
        return nil
    end
    local guid = string.sub(rawText, 1, markerPos - 1)
    if not targetGuid or string.lower(guid) ~= string.lower(targetGuid) then
        if armed then
            macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:guid-mismatch target=' .. tostring(targetGuid) .. ' line=' .. guid, 'yellow')
        end
        return nil
    end
    -- accepted residual risk (REVIEW.md WR-02 / SECURITY.md R-04): in a
    -- multi-feral scenario an allied Rip apply on the same target within our
    -- pending window can pair with our cast intent (<=2s land offset); fail
    -- events still resolve in our favor via fail-wins, and the silent
    -- apply-suppression case is accepted per debug decisions 2 and 6
    local intent = macroTorch.pairLandIntent(spellName, now)
    if intent then
        -- user-visible land feedback (restored per user request 2026-08-30):
        -- pairing succeeded, so this apply line is a genuine landing (and the
        -- target-is-attackable / loginContext guards all held for pairing).
        -- Announced BEFORE recordLandEvent for the same causal-order reason
        -- as the self-hit path: the announcement precedes listener
        -- consequences, keeping output order uniform across both sources.
        macroTorch.show(spellName .. ' cast on ' .. macroTorch.target.name ..
            ' landed: ' .. now, 'green')
        macroTorch.recordLandEvent(spellName, now)
    end
    if armed and intent then
        macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' pair-ok guid=' .. guid ..
            ' t=' .. string.format('%.3f', now), 'green')
    end
    if armed and not intent then
        macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:no-intent t=' ..
            string.format('%.3f', now), 'yellow')
    end
    return intent
end
-- finalizes an intent as failed when a fail event arrives: consumes the newest
-- pending/landed intent within the TTL window, revokes the land entry the
-- intent produced (if any), and marks it failed. Fail is final regardless of
-- whether the land or the fail event arrived first.
function macroTorch.finalizeFail(spell, failTime, failType)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext or not macroTorch.loginContext.intentTable or
            not macroTorch.loginContext.intentTable[spell] then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.intentTable[spell][mob] then
        return
    end
    local stack = macroTorch.loginContext.intentTable[spell][mob]
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        -- deliberately allows failTime slightly before castAt (negative
        -- window): same-frame arrival order must not flip fail-wins, so
        -- intent.state == 'pending' or 'landed' and a negative diff is
        -- still consumed
        if (intent.state == 'pending' or intent.state == 'landed') and
                (failTime - intent.castAt) <= macroTorch.LAND_INTENT_TTL then
            if intent.state == 'landed' and intent.landAt then
                -- revoke the land this intent produced (fail is final)
                if macroTorch.loginContext.landTable and macroTorch.loginContext.landTable[spell] and
                        macroTorch.loginContext.landTable[spell][mob] then
                    macroTorch.loginContext.landTable[spell][mob].removeMatch(function(landTime)
                        return landTime == intent.landAt
                    end)
                end
                -- user-visible cancellation notice: the failed cast revokes a
                -- landing that was previously announced in green (fail-wins);
                -- name the fail type so the player knows why the green line no
                -- longer holds (2026-08-30 user request)
                macroTorch.show(spell .. ' land on ' .. mob .. ' was cancelled by ' ..
                    tostring(failType or 'fail'), 'red')
            end
            intent.state = 'failed'
            intent.landAt = nil
            return
        end
    end
end
-- parses 'Your <skill> hits/crits <target>.' self-hit lines into land events
-- for registered self-hit land spells. The 'Your <skill>' prefix is
-- client-authenticated, so no intent pairing is required to record the land;
-- pairing is still attempted best-effort to consume the cast intent.
function macroTorch.onSelfDamageLine(eventMsg, now)
    if not eventMsg then
        return
    end
    local _, _, spell = string.find(eventMsg, 'Your (.-) hits ([^%.]+)%.')
    if not spell then
        _, _, spell = string.find(eventMsg, 'Your (.-) crits ([^%.]+)%.')
    end
    if not spell then
        return
    end
    if not macroTorch.tracingSpells[spell] then
        return
    end
    if (macroTorch.landSources[spell] or 'self-hit') ~= 'self-hit' then
        return
    end
    macroTorch.pairLandIntent(spell, now)
    -- user-visible land feedback (restored per user request 2026-08-30): the
    -- self-hit line IS the landing; print the green confirmation the pre-phase
    -- polling machinery used to emit. Plain show() — not a DIAG/RAWDIAG marker.
    -- Announced BEFORE recordLandEvent so the printed order matches
    -- causality: recordLandEvent dispatches land listeners synchronously,
    -- and their output (e.g. the Ferocious Bite Renewing lines) is a
    -- consequence of this hit and must follow the green landed line.
    if macroTorch.loginContext and macroTorch.target.isCanAttack then
        macroTorch.show(spell .. ' cast on ' .. macroTorch.target.name ..
            ' landed: ' .. now, 'green')
    end
    macroTorch.recordLandEvent(spell, now)
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