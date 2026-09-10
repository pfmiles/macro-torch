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
-- default evidence window (s) before a silent cast is inferred landed;
-- the intentTtl register parameter overrides it per-spell; the cpDamage
-- pairing keeps referencing this constant (D-17)
macroTorch.LAND_INTENT_TTL = 0.9
-- sets what spells to trace casts
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end
-- per-spell evidence/ttl registry written by register, read by recordCastTable
-- seeding and the inference layer
if not macroTorch.landIntentTtls then
    macroTorch.landIntentTtls = {}
end
-- precompiled find patterns for aura-apply evidence lines of land-tracing
-- spells that carry a tracked debuff texture (natural-attribute driver,
-- no per-spell source field)
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
-- intentTtl (number, optional): per-spell evidence window override; defaults to LAND_INTENT_TTL
function macroTorch.SpellTrace:register(name, config)
    -- [CITED: PLAN 03-02 must_haves]
    if config.land then
        macroTorch.setSpellTracing(name)
        macroTorch.landIntentTtls[name] = config.intentTtl or macroTorch.LAND_INTENT_TTL
        if config.immune and config.debuffTexture then
            -- the aura-apply evidence channel exists for spells carrying a
            -- tracked debuff texture (natural attribute, no per-spell source
            -- field); the pattern is built by raw concatenation, so guard the
            -- name against Lua find-pattern metacharacters first
            if string.find(name, '[()%.%%%+%-%*%?%[%]%^%$]') then
                macroTorch.show("[macro-torch] SpellTrace:register(" .. name ..
                    "): name carries Lua find-pattern metacharacters, aura-apply channel skipped", 'red')
            else
                macroTorch.auraApplySpellPatterns[name] = ' is afflicted by ' .. name .. '%.'
            end
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
    -- expires after the intent's own ttl if no land/fail event arrives
    if not macroTorch.loginContext.intentTable then
        macroTorch.loginContext.intentTable = {}
    end
    if not macroTorch.loginContext.intentTable[spell] then
        macroTorch.loginContext.intentTable[spell] = {}
    end
    if not macroTorch.loginContext.intentTable[spell][mob] then
        macroTorch.loginContext.intentTable[spell][mob] = macroTorch.LRUStack:new(32)
    end
    macroTorch.loginContext.intentTable[spell][mob].push({ state = 'pending', castAt = GetTime(), landAt = nil,
        ttl = macroTorch.landIntentTtls[spell] or macroTorch.LAND_INTENT_TTL })
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
-- pairs a land event with an unconsumed cast intent whose own ttl window
-- (intent.ttl, defaulting to LAND_INTENT_TTL) covers the land. First runs a
-- purge pass expiring stale pending intents past their own ttl, then picks
-- the newest still-pending intent whose castAt is <= landTime and inside its
-- ttl window. Never pairs an intent already failed or landed (the fail-wins
-- guarantee).
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
    -- purge pass: expire pending intents older than their own ttl window
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and (landTime - intent.castAt) > (intent.ttl or macroTorch.LAND_INTENT_TTL) then
            intent.state = 'expired'
        end
    end
    -- pair pass: newest pending intent whose cast precedes this land
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and intent.castAt <= landTime and
                (landTime - intent.castAt) <= (intent.ttl or macroTorch.LAND_INTENT_TTL) then
            intent.state = 'landed'
            intent.landAt = landTime
            return intent
        end
    end
    return nil
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
-- D-02 cast-dimension coverage predicate, shared by the announce gates and
-- the record side: when the current cast already has a land (real evidence or
-- an earlier inference), a later evidence line for the same cast is dropped,
-- so the green announcement must be skipped for it as well (WR-01: a dropped
-- write must not print a landed line).
function macroTorch.isCastCovered(spell)
    local lastCast = macroTorch.peekCastEvent(spell)
    local lastLand = macroTorch.peekLandEvent(spell) or 0
    if lastCast and lastLand and lastLand >= lastCast then
        return true
    end
    return false
end
-- unified evidence entry: records a land event on the landTable and dispatches
-- registered listeners; the cast-dimension dedup inside keeps one land per
-- cast, earliest arrival wins. Renewal rewrites go through the exempt entry
-- recordLandEventRenewal instead. Does NOT touch intent state: pairing is the
-- caller's job (aura-apply pairs first and drops the land on no intent;
-- self-hit pairs best-effort).
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
    -- cast-dimension dedup keeps one land per cast, earliest arrival wins;
    -- renewal bypasses via the dedicated exempt entry; the predicate lives
    -- in isCastCovered so the announce gates evaluate the same condition
    if macroTorch.isCastCovered(spell) then
        return
    end
    macroTorch.loginContext.landTable[spell][mob].push(landTime)
    if macroTorch.landListeners and macroTorch.landListeners[spell] then
        for _, listener in ipairs(macroTorch.landListeners[spell]) do
            listener(spell, landTime)
        end
    end
end
-- renewal entry: deliberately writes a new anchor past the cast-dimension
-- dedup (FB listener call sites only). Guard shape, lazy-init, push and
-- listener dispatch mirror recordLandEvent verbatim; only the dedup
-- predicate is absent.
function macroTorch.recordLandEventRenewal(spell, landTime)
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
-- set up the land event generation for traced spells; silent-window inference rescue
function macroTorch.maintainLandTables()
    if not macroTorch.tracingSpells or macroTorch.tableLen(macroTorch.tracingSpells) == 0 or not macroTorch.inCombat then
        return
    end
    for spellName in pairs(macroTorch.tracingSpells) do
        macroTorch.computeLandTable(spellName)
    end
end
macroTorch.registerPeriodicTask('maintainLandTables', { interval = 0.1, task = macroTorch.maintainLandTables })
-- inference fallback revived per D-03/D-04: once a cast's own ttl window
-- elapses in full silence (no self-hit, no paired apply, no in-window fail)
-- the cast is declared landed anchored at its cast moment
function macroTorch.computeLandTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
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
    local lastCast = macroTorch.peekCastEvent(spell)
    if not lastCast then
        return
    end
    -- per-spell evidence window: hunter stings use 2, druid bleeds 0.9 — the
    -- same window that gates intent pairing and fail vetoes (one parameter,
    -- three reads)
    local ttl = macroTorch.landIntentTtls[spell] or macroTorch.LAND_INTENT_TTL
    -- window-still-open return replaces the old blip lower/upper double
    -- constant: the trigger edge IS the ttl, no magic numbers
    local blip = GetTime() - lastCast
    if blip <= ttl then
        return
    end
    -- cast-dimension coverage predicate (D-02 reuse): this cast is already
    -- covered by a real evidence landing or an earlier inference
    local lastLand = macroTorch.peekLandEvent(spell) or 0
    if lastLand >= lastCast then
        return
    end
    -- windowed fail veto (D-04): a fail at cast <= failTime <= cast + ttl
    -- vetoes this inference (replaces the old 0.05s adjacency heuristic);
    -- failTable entries are {time, failType} pairs
    local lastFail = macroTorch.peekFailEvent(spell)
    if lastFail and lastFail[1] >= lastCast and (lastFail[1] - lastCast) <= ttl then
        return
    end
    macroTorch.loginContext.landTable[spell][mob].push(lastCast)
    -- blue reserved for the inferred fallback so real green evidence stays
    -- visually distinguishable; the (inferred) suffix tells the player an
    -- apply-confirmed landing from a fallback inference
    macroTorch.show(spell .. ' cast on ' .. mob .. ' landed: ' .. lastCast .. ' ' .. '(inferred)', 'blue')
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
-- handles a RAW aura-apply line ('<guid> is afflicted by <Spell>.') — the
-- apply-evidence channel of the unified OR land flow: parses the guid and
-- requires a case-insensitive match with the current target (ownership
-- check), then pairs the line with a cast intent — the land timestamp IS the
-- apply event time. Returns the paired intent, or nil when the line is not
-- ours / does not pair.
function macroTorch.processRawAuraApply(spellName, rawText, targetGuid, now)
    if not spellName or not rawText then
        return nil
    end
    local markerPos = string.find(rawText, ' is afflicted by ')
    if not markerPos then
        return nil
    end
    local guid = string.sub(rawText, 1, markerPos - 1)
    if not targetGuid or string.lower(guid) ~= string.lower(targetGuid) then
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
        -- Gated on the same D-02 coverage outcome as the self-hit path, so an
        -- apply whose write is deduped (a self-hit already landed this cast)
        -- prints no misleading second green line (WR-01 symmetry).
        if not macroTorch.isCastCovered(spellName) then
            macroTorch.show(spellName .. ' cast on ' .. macroTorch.target.name ..
                ' landed: ' .. now, 'green')
        end
        macroTorch.recordLandEvent(spellName, now)
    end
    return intent
end
-- finalizes an intent as failed when a fail event arrives: consumes the newest
-- pending/landed intent inside its windowed fail veto (cast <= failTime <=
-- cast + intent.ttl), revokes the land entry the intent produced (if any),
-- and marks it failed. Fail is final regardless of whether the land or the
-- fail event arrived first.
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
        -- windowed fail veto (D-04): consume when cast <= failTime <=
        -- cast + intent.ttl; a same-frame fail (diff 0) still satisfies the
        -- lower bound, so fail-wins never depends on arrival order
        if (intent.state == 'pending' or intent.state == 'landed') and
                (failTime - intent.castAt) >= 0 and
                (failTime - intent.castAt) <= (intent.ttl or macroTorch.LAND_INTENT_TTL) then
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
-- parses 'Your <skill> hits/crits <target>.' self-hit lines into land events.
-- The 'Your <skill>' prefix is client-authenticated, so every traced spell's
-- self-hit line is land evidence (unified OR channel); no pairing is required
-- to record the land — pairing is attempted best-effort to consume the cast
-- intent, and recordLandEvent's cast dedup keeps one land per cast.
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
    macroTorch.pairLandIntent(spell, now)
    -- user-visible land feedback (restored per user request 2026-08-30): the
    -- self-hit line IS the landing; print the green confirmation the pre-phase
    -- polling machinery used to emit. Plain show() — not a DIAG/RAWDIAG marker.
    -- Announced BEFORE recordLandEvent so the printed order matches
    -- causality: recordLandEvent dispatches land listeners synchronously,
    -- and their output (e.g. the Ferocious Bite Renewing lines) is a
    -- consequence of this hit and must follow the green landed line.
    -- the announce is gated on the D-02 coverage outcome so a same-cast
    -- duplicate (dual-channel spell whose apply paired first) stays silent
    -- instead of printing a second green landed line for a dropped write
    -- (WR-01); the announce still precedes recordLandEvent, keeping the
    -- causal print order announced-before-listener-output intact
    if macroTorch.loginContext and macroTorch.target.isCanAttack and not macroTorch.isCastCovered(spell) then
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