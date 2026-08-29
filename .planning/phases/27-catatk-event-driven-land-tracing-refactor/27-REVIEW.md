---
phase: 27-catatk-event-driven-land-tracing-refactor
reviewed: 2026-08-29T06:30:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
  - classes/druid/selftest.lua
  - classes/hunter/Hunter.lua
  - core/events.lua
  - core/periodic.lua
  - core/spell_trace_core.lua
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues-found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-08-29T06:30:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues-found

## Summary

Review of the phase-27 event-driven land-tracing rework across the three core files (spell_trace_core.lua, events.lua, periodic.lua) and the four class/selftest files. The state-machine machinery itself (TTL purge/pair passes, fail-wins revocation, LRUStack:removeMatch bounds, guid ownership parse, three-tier RAW filter, see below for the verified-clean list) is sound; the Lua 5.0 audit is clean (zero `#` length operator, zero goto/labels, zero 4-arg string.find in the changed hunks), and Category Q's CR-01 stub/restore discipline is correctly ordered (restore by raw assignment happens before any assert in Q-02..Q-07; no writes to real registries or real loginContext sub-tables).

However, one critical argument-order mismatch between the listener dispatcher (`listener(spell, landTime)` at core/spell_trace_core.lua:214) and the Ferocious Bite renewal listener (`function(landTime)` at classes/druid/Druid.lua:713) silently poisons the Rake/Rip land stacks with the string `'Ferocious Bite'` and detonates as Lua arithmetic errors on the next bleed-clock evaluation — the exact combat path this phase exists to repair. The Category Q battery ships green without ever executing the renewal body (Q-07's `hasBuff=false` stub short-circuits the real listener), so the tests provide false confidence on the miswired line.

Verified-clean (no findings raised): `removeMatch` loop bounds are exact (tableLen counts the pure-array `elements` via pairs(); the numeric `for` limit is evaluated once and it returns immediately after `table.remove`, so no re-index hazard); `pairLandIntent` purge/pair passes are internally consistent and never pair failed/landed/expired intents; `finalizeFail` revocation uses exact float equality on the same `now` value recorded by `recordLandEvent`; CheckDodgeParryBlockResist still runs before onSelfDamageLine on CHAT_MSG_SPELL_SELF_DAMAGE and the UNIT_CASTEVENT bridge reads byte-for-byte unchanged; Q-09's deleted-machinery assertions match the repo state (`maintainLandTables`/`computeLandTable`/`consumeDruidBattleEvents` truly absent outside the Q-09 guards); isRipPresent/ripLeft computation and the safeRip decision lines survive intact as the summaries claim; `spell_trace_immune.lua` remains a valid consumer of the event-derived lands (its 0.1s consume task still matches the new evidence source) and DEBUFF_LAND_LAG is not dead code.

## Critical Issues

### CR-01: FB renewal listener receives the spell name instead of landTime — poisons Rake/Rip land stacks with a string, then crashes on arithmetic

**File:** `classes/druid/Druid.lua:713` (payload at :719 and :725); dispatch contract at `core/spell_trace_core.lua:213-215`
**Issue:** `recordLandEvent` dispatches listeners with two arguments: `listener(spell, landTime)` (spell_trace_core.lua:214). The Ferocious Bite renewal listener is declared with a single parameter: `macroTorch.onLandEvent('Ferocious Bite', function(landTime) ... end)` (Druid.lua:713). In Lua, the first argument wins, so the local variable `landTime` is bound to the string `'Ferocious Bite'`. The listener then executes `macroTorch.recordLandEvent('Rake', landTime)` (line 719) and `macroTorch.recordLandEvent('Rip', landTime)` (line 725), pushing the string onto the numeric land stacks. Impact chain:

1. From that moment, `peekLandEvent('Rake'/'Rip')` returns `'Ferocious Bite'` as the stack top.
2. The next evaluation of `rakeLeft` (Druid.lua:1142, `rakeDuration - (GetTime() - lastLandedRakeTime)`) or `ripLeft` (Druid.lua:1113) raises the Lua 5.0 error "attempt to perform arithmetic on a string value" on every catAtk click — the rotation hard-crashes each click until 100 further pushes evict the poisoned entry.
3. On the second consecutive FB land with bleeds up, the error is raised inside the listener itself during `recordLandEvent` dispatch (the `isRakePresent` gate re-reads the poisoned top), propagating out of the event handler.
4. The `'Renewing rake...'` diagnostics lie: the `show` line computes `rakeLeft` before the poison push, so the chat output displays a healthy countdown while the renewal did not actually restart the clock.
5. `spell_trace_immune.lua:49` (`GetTime() - landEvent`) also throws on the poisoned entry inside the 0.1s periodic consumer (caught by the pcall wrapper there, but the immune/definite-bleeding tracing silently stops updating).

This is precisely the failure class the phase exists to eliminate (broken Rip/Rake land evidence → wrong `isRipPresent` → premature recast), reintroduced at the integration seam.

Why the shipped tests do not catch it: Q-07 drives the real listener through `onSelfDamageLine` but the fake target's `hasBuff` returns false (selftest.lua:906), so `isRakePresent`/`isRipPresent` short-circuit and none of the renewal lines execute; Q-08 only asserts listener presence (selftest.lua:924-929).

**Fix:**
```lua
-- classes/druid/Druid.lua:713 — accept the framework's (spell, landTime) contract
macroTorch.onLandEvent('Ferocious Bite', function(spell, landTime)
    local clickContext = {}
    if macroTorch.isRakePresent(clickContext) then
        macroTorch.show('Renewing rake... left: ' ..
                tostring(macroTorch.rakeLeft(clickContext)) ..
                ', bleed idol: ' .. tostring(macroTorch.loginContext.lastRakeEquippedSavagery))
        macroTorch.recordLandEvent('Rake', landTime)
    end
    if macroTorch.isRipPresent(clickContext) then
        macroTorch.show('Renewing rip... left: ' ..
                tostring(macroTorch.ripLeft(clickContext)) ..
                ', bleed idol: ' .. tostring(macroTorch.loginContext.lastRipEquippedSavagery))
        macroTorch.recordLandEvent('Rip', landTime)
    end
end)
```
Alternative: change the dispatcher to `listener(landTime)` (spell_trace_core.lua:214) — but only if all current and future listeners are documented as single-parameter. The listener-side fix is minimal and keeps the general dispatch contract.

## Warnings

### WR-01: Category Q battery never executes the renewal body — false-green coverage that let CR-01 through

**File:** `classes/druid/selftest.lua:900-922` (Q-07), `924-929` (Q-08)
**Issue:** The only end-to-end dispatcher exercise (Q-07) stubs `hasBuff = function(self) return false end` (line 906) precisely so the real FB renewal listener becomes a no-op — meaning the listener's renewal branches (the exact lines containing CR-01) are never executed by any test, and Q-08 asserts presence only. A land-listener with an argument-order bug ships with a fully green Category Q. This is a test-reliability gap, not just style: the battery's stated purpose (27-03: "behavioral regression layer encoding the correctness predicates") includes the renewal wiring, and a string-push into the land stack is undetectable by assert-through-nil (the poisoned value is truthy, so `not lastLandedRakeTime` checks in rakeLeft/ripLeft do not reject it either).
**Fix:** Add a Category Q test that runs the true renewal path under CR-01 discipline: fake `loginContext` with a `landTable` whose `Rake`/`Rip`/`QTestMob` LRUStacks contain numeric entries, fake target with `hasBuff = function() return true end`, drive `macroTorch.onSelfDamageLine('Your Ferocious Bite hits QTestMob for 548.', 5.0)`, restore globals, then assert `landTable['Rake']['QTestMob'].top == 5.0` and `type(landTable['Rip']['QTestMob'].top) == 'number'`. This test fails on the CR-01 code and passes after the fix.

### WR-02: Aura-apply ownership is cast-intent pairing only — an ally's apply of the same spell within the 2s TTL records a land on our target

**File:** `core/spell_trace_core.lua:245-249` (pair step in processRawAuraApply), `core/events.lua:147-154` (RAW dispatch)
**Issue:** Per the debug evidence, the RAW apply line carries only the victim GUID and no caster identity. Ownership therefore rests entirely on "we cast within LAND_INTENT_TTL=2s" plus the victim-GUID match. In a multi-druid (Rip/Pounce) or multi-hunter (Serpent/Scorpid Sting) raid, an ally's apply of the same spell to the same target inside our 2s intent window pairs with our pending intent and records a land that restarts our self-reported bleed clocks — a false renewal. The pre-phase chain could not do this (the ripLeft clock was driven solely by our own event chain, the sandbagged "所有权鉴权" leg called out as non-degradable in the debug constraints). The fail-wins path self-corrects the worst case (our failed cast produces a `Your Rip failed/parried...` fail line that finalizes and revokes the paired land), but the silent case — our cast succeeded and the server suppressed our apply line (locked evidence: same-caster refresh skips the apply) while the ally's apply arrived in our window — records a land offset by up to ~2s against the 16.2s clock model.
**Fix:** Tighten the pairing window for aura-apply spells. The debug samples measured apply lines arriving 1-40ms after the cast record; the 2s TTL exists for cast-bridge latency, not apply latency. Either shorten TTL per spell (e.g., a `maxApplyDelay` field in the register config, defaulting to ~0.5s for instant-cast auras), or require that no same-spell fail event exists in the window before recording (fail presence check inside the pair step). At minimum, document the residual cross-caster false-pair in a comment at `processRawAuraApply` so future changes do not assume strict ownership.

## Info

### IN-01: Aura-apply find patterns are built by unescaped concatenation — latent breakage if a future aura-apply spell name contains Lua pattern metacharacters

**File:** `core/spell_trace_core.lua:66`
**Issue:** `macroTorch.auraApplySpellPatterns[name] = ' is afflicted by ' .. name .. '%.'` interpolates the raw spell name into a Lua pattern. The four current aura-apply names (Pounce, Rip, Serpent Sting, Scorpid Sting) contain no magic characters (`( ) . % + - * ? [ ] ^ $`), so the shipped patterns are safe, but any future aura-apply registration whose spell name contains e.g. `(` (many WoW spells: "Faerie Fire (Feral)") would miscompile the find pattern and silently drop lands.
**Fix:** Escape pattern metacharacters when building the key, e.g. `local function patternEscape(s) return s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0") end`, or split the precheck from the name match (`string.find(arg2, ' is afflicted by ', 1, true)` plus an anchored plain-text compare of the remainder).

### IN-02: `pairs()` iteration over `auraApplySpellPatterns` in the combat-log hot path is safe today but unguarded against future runtime registration

**File:** `core/events.lua:147-154`
**Issue:** The tier-2/3 loop iterates `macroTorch.auraApplySpellPatterns` with `pairs()` while `SpellTrace:register` mutates the same table. Today every registration is at file-load scope (Druid.lua:682-705, Hunter.lua:155-164), before any combat-log event can fire, so no mutation-during-iteration hazard exists. However, Lua 5.0 leaves table insertion during `pairs()` iteration undefined (rehash can skip or repeat entries), and nothing prevents a future runtime registration (e.g., a registered land listener calling `SpellTrace:register` mid-fight, or a profile-swap feature).
**Fix:** Cheap hardening: keep the map as the source of truth but snapshot its keys into an array at registration time and iterate `ipairs` over the snapshot in the RAW handler; or at least document the invariant ("registrations load-time only") on the registry declaration.

### IN-03: Pounce registration omits the `spellName` invariant field carried by its siblings

**File:** `classes/druid/Druid.lua:682-686`
**Issue:** Pounce's register config (Druid.lua:682-686) omits the `spellName` key that every sibling registration carries (Rip at 687-697, Rake, Ferocious Bite at 699-702; Serpent Sting and Scorpid Sting in Hunter.lua:155-164). The guard-invariant check at `core/spell_trace_core.lua:74-77` only runs when `config.spellName` is present, so Pounce is not covered by this misregistration tripwire. No current bug — the registration name and the chat-parsed name happen to match — but the tripwire (which exists for the exact failTable key-mismatch failure mode described in its own comment) is unevenly deployed.
**Fix:** Add `spellName = 'Pounce'` to the Pounce register config for consistency with the guard's intent.