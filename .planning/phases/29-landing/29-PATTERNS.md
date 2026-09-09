# Phase 29: 统一 landing 判定重构 - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 6 (5 modified + 1 doc deletion; 2 verification-only)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `core/spell_trace_core.lua` | utility (framework module) | event-driven (game event callbacks + 0.1s periodic task -> landTable writes + chat announcements) | itself (in-file purge/pair skeletons) + `eb56a257:core/spell_trace_core.lua:68-190` (archived maintainLandTables/computeLandTable) | exact (same file, historical variant) |
| `classes/druid/Druid.lua` | provider/hook (class module: declarative registration + land listener) | event-driven (listener callback) | `classes/druid/Druid.lua:802-856` (existing register block + FB renewal listener) | exact |
| `classes/hunter/Hunter.lua` | provider (class module: declarative registration only) | event-driven | `classes/hunter/Hunter.lua:151-165` + `classes/druid/Druid.lua:802-828` | exact |
| `classes/druid/selftest.lua` | test | batch (pcall-isolated stubbed fixtures) | `classes/druid/selftest.lua:763-930+` (Category Q: Q-01..Q-07 CR-01 fixture discipline) | exact |
| Todo file `druid-rip-land-forensics-next-cd.md` | docs deletion | n/a | none needed (plain `git rm`; locate at execution time — not in current working tree, likely already moved/closed per quick 260909-w3r) | n/a |
| `core/events.lua` | VERIFICATION-ONLY — no change (D-01 auto: tier-2 iterates `auraApplySpellPatterns` table, so pattern-table population changes ripple automatically) | event router | `core/events.lua:130-164` | confirmed-no-op |
| `core/spell_trace_immune.lua` | VERIFICATION-ONLY — no structural change (immune path 2 reactivates behaviorally via restored land supply) | event-driven (0.1s consumer) | itself | confirmed-no-op |

## Pattern Assignments

### 1. `core/spell_trace_core.lua` (utility, event-driven)

This file is both the target and its own best analog. Four sub-refactors, each with an in-file or in-history pattern:

#### 1a. `LAND_INTENT_TTL` constant + register signature (D-09/D-10)

**Analog:** `core/spell_trace_core.lua:13-15` (constant), `core/spell_trace_core.lua:60-84` (register)

**Constant pattern** (lines 13-15):
```lua
macroTorch.DEBUFF_LAND_LAG = 0.2
-- intent pending-window seconds before expiry (event-driven land pairing)
macroTorch.LAND_INTENT_TTL = 2
```
D-10: value -> 0.9, comment -> "默认证据接收窗，register 参数可逐技能覆盖" (English: default evidence window, overridable per-spell via register).

**Register pattern** (lines 60-84). Current land branch to be replaced (D-01: delete `landSources` write, keep pattern registration derived from natural attributes, add `intentTtl`):
```lua
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
```
Per DESIGN-CONTEXT: register 改签名与守卫（pattern-safe 断言）—— the concat-built pattern comment becomes an explicit assertion (registered names free of Lua find-pattern metacharacters). Note: `events.lua:157-163` still consumes `macroTorch.auraApplySpellPatterns`, so the table stays; only its population trigger changes (driven by natural attribute — planner to pick the concrete driver field, e.g. debuff-carrying/missile property; do NOT delete the table itself).

#### 1b. Intent seeding with ttl (D-07/D-08)

**Analog:** `core/spell_trace_core.lua:114-125` (intentTable seeding inside recordCastTable)

```lua
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
```
D-07: push adds `ttl = config.intentTtl or macroTorch.LAND_INTENT_TTL`. Planner note: `recordCastTable` currently has no `config`; it needs the per-spell ttl lookup (e.g. a registry keyed by spell name populated at register time). `recordCastTable` also carries the 0.2s dedup guard from cast path in `eb56a257` history (same shape as current, lines 103-108: `if last and (GetTime() - last) < 0.2 then return end`).

#### 1c. Window reads become `intent.ttl` (D-05/D-07)

**Analog:** `core/spell_trace_core.lua:163-194` (pairLandIntent purge+pair) and `core/spell_trace_core.lua:365-406` (finalizeFail)

```lua
function macroTorch.pairLandIntent(spell, landTime)
    ...
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
```
Change: `macroTorch.LAND_INTENT_TTL` -> `intent.ttl` in both passes (purge walks per-intent; pair uses the candidate intent's own ttl). `finalizeFail` lines 384-385 similarly:
```lua
        if (intent.state == 'pending' or intent.state == 'landed') and
                (failTime - intent.castAt) <= macroTorch.LAND_INTENT_TTL then
```
D-04/D-07: the window becomes `0 <= (failTime - intent.castAt) <= intent.ttl` (windowed fail veto replaces the negative-diff tolerance comment block at lines 380-383). Revoke machinery below it (lines 386-400, `removeMatch` revocation via `landTime == intent.landAt`, red cancellation line) is kept verbatim — fail-wins (D-06).

**Phase-28 sibling pattern to imitate (newest purge/pair, `core/spell_trace_core.lua:202-229`)** — `pairCpDamageIntent` shows the current house style for windowed purge+pair and keeps referencing the global constant (cpDamage keeps using `LAND_INTENT_TTL` per D-17, so its lines 210, 221 must NOT be rewritten — only their source value changes to 0.9 automatically).

#### 1d. recordLandEvent dedup layer + renewal exemption (D-02/D-11)

**Analog:** `core/spell_trace_core.lua:291-314` (current recordLandEvent)

```lua
function macroTorch.recordLandEvent(spell, landTime)
    ...
    macroTorch.loginContext.landTable[spell][mob].push(landTime)
    if macroTorch.landListeners and macroTorch.landListeners[spell] then
        for _, listener in ipairs(macroTorch.landListeners[spell]) do
            listener(spell, landTime)
        end
    end
end
```
D-02: insert cast-dimension predicate before `push` — `lastLand >= lastCast` drops the late-positive evidence (use `peekCastEvent`/`peekLandEvent`, lines 482-491, the in-file peek helpers). Same-cast single land; earliest arrival wins within a quality tier (no re-push needed — first arrival already at top). D-11: new `macroTorch.recordLandEventRenewal(spell, time)` wraps the same push+dispatch but skips the dedup predicate (it deliberately writes a new anchor). The guard shape of both = the recordLandEvent guard block verbatim (lines 292-307).

#### 1e. Revive maintainLandTables + computeLandTable (D-03/D-04/D-13/D-14)

**Analog (git history of the same tracked file):** `git show eb56a257:core/spell_trace_core.lua` — `maintainLandTables` at lines 68-76, `computeLandTable` at line 150. This is the tracked origin (current `core/spell_trace_core.lua` is track-verified), not a mirror.

```lua
-- set up the land event generation for spells set tracing
function macroTorch.maintainLandTables()
    if not macroTorch.tracingSpells or macroTorch.tableLen(macroTorch.tracingSpells) == 0 or not macroTorch.inCombat then
        return
    end
    for spellName in pairs(macroTorch.tracingSpells) do
        macroTorch.computeLandTable(spellName)
    end
end
macroTorch.registerPeriodicTask('maintainLandTables', { interval = 0.1, task = macroTorch.maintainLandTables })
```

```lua
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
```

Modernization per D-03/D-04/D-13/D-14 (skeleton + guard shape copy verbatim; logic swapped):
- blip window becomes `intent.ttl`-driven: infer fires only after `blip > ttl` (window silent) OR intent expired — planner resolves exact anchor source (per-spell ttl lookup keyed by spell, see 1b note). Hardcoded 0.02/0.9/0.05 become named constants (module-level, English comment).
- Recent event silence predicates replace `lastLanded == lastCast` (cast-predicate dedup, see 1d) and the ±0.05s fail adjacency with windowed fail veto `cast <= failTime <= cast + ttl` (D-04). Condition must check "no self-hit / no paired apply / no windowed fail" before pushing — never competing with game events (only fires on full-window silence).
- Announcement: `'blue'`, message `{spell} cast on {mob} landed: {time} (inferred)` (D-13/D-14) — the current-period `show()` discipline (plain `show()`, color literal, see 2. Shared Patterns).
- `maintainLandTables` guard copies `spellsImmuneTracing`'s guard shape (see 1f) but gates on `macroTorch.tracingSpells` + `macroTorch.inCombat` exactly as archived.

#### 1f. Cleanup: onSelfDamageLine early-return gate + landSources table/consumers

**Analog:** `core/spell_trace_core.lua:411-441` (onSelfDamageLine) — remove lines 425-427:
```lua
    if (macroTorch.landSources[spell] or 'self-hit') ~= 'self-hit' then
        return
    end
```
Keep the `tracingSpells` gate (line 422-424) and the green announce-before-record order (lines 429-440, causal-order comment is load-bearing). Delete `macroTorch.landSources` module init (lines 21-24). Grep showed no other `landSources` consumers besides register, onSelfDamageLine, and selftest Q-01.

### 2. `classes/druid/Druid.lua` (provider/hook, event-driven)

**Analog:** `classes/druid/Druid.lua:802-856` (existing — the exact lines to edit)

**Register block** (lines 802-828) — delete `landSource` fields from Pounce (806) and Rip (817); Rake/FB already default. Comment lines 803/809/814 explain the per-skill channel rationale — update to the unified OR language. FF block (825-828) untouched (land=false, deferred).

**FB renewal listener** (lines 830-856):
```lua
macroTorch.onLandEvent('Ferocious Bite', function(spell, landTime)
    local clickContext = {}
    if macroTorch.isRakePresent(clickContext) then
        macroTorch.show('Renewing rake... left: ' ...
                .. ', expDuration: ' .. tostring(macroTorch.computeRake_Duration()) .. 's' ..
                .. ', bleed idol: ' .. tostring(macroTorch.loginContext.lastRakeEquippedSavagery))
        macroTorch.recordLandEvent('Rake', landTime)
    end
    if macroTorch.isRipPresent(clickContext) then
        macroTorch.show('Renewing rip... left: ' ...
                .. ', expDuration: ' .. tostring(macroTorch.computeRip_Duration()) .. 's' ..
                .. ', bleed idol: ' .. tostring(macroTorch.loginContext.lastRipEquippedSavagery))
        macroTorch.recordLandEvent('Rip', landTime)
    end
end)
```
D-08/D-11: `recordLandEvent('Rake'/'Rip', landTime)` -> `recordLandEventRenewal(...)` at lines 847 and 854. `isRipPresent`/`isRakePresent` precondition and the CR-01 two-arg listener signature stay.

### 3. `classes/hunter/Hunter.lua` (provider, event-driven)

**Analog:** `classes/hunter/Hunter.lua:151-165` (existing — exact lines to edit)

```lua
macroTorch.SpellTrace:register('Serpent Sting', {
    spellName = 'Serpent Sting', land = true,
    landSource = 'aura-apply',
    immune = true, debuffTexture = 'Ability_Hunter_Quickshot'
})
```
D-12: delete `landSource = 'aura-apply',` and add `intentTtl = 2` (both Serpent 155-159 and Scorpid 161-165; comment lines 151-154 update to explain ballistic flight window). Druid skills all keep default 0.9 — no `intentTtl` field added in Druid.lua.

### 4. `classes/druid/selftest.lua` (test, batch)

**Analog:** `classes/druid/selftest.lua:763-930+` — Category Q, the CR-01 fixture discipline (also lines 396-460 show the older pcall form).

**Q-01 rewrite target** (lines 771-784): currently asserts `macroTorch.landSources[...]` values. D-15: rewrite as unified-OR behavior assertion (assert `landSources` table is absent; assert `tracingSpells` entries still `true` for Pounce/Rake/Rip/FB; assert per-spell ttl registry values: hunter stings 2, druid default 0.9). Test name string in `SelfTest:register("Cat Q-01: ...", function() ... end, true)` — the `, true` = isOptional, preserved.

**Fixture discipline to copy for the six new cases (D-16)** — from Q-02 (lines 786-825) and Q-04/Q-05 (seeded-intent form, lines 850-907):
```lua
macroTorch.SelfTest:register("Cat Q-02: aura-apply line pairs the cast intent and lands at apply time", function()
    local savedLoginContext = macroTorch.loginContext
    local savedTarget = macroTorch.target
    -- the paired apply now prints a green land line (2026-08-30 feedback
    -- restore); stub show so the test run leaves no chat noise
    local savedShow = macroTorch.show
    local fakeLoginContext = {}
    local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
    macroTorch.loginContext = fakeLoginContext
    macroTorch.target = fakeTarget
    macroTorch.show = function() end
    local pcallRes = true
    local intentResult, intentState, intentLandAt, ripLandTop
    pcallRes = pcall(function()
        macroTorch.recordCastTable('Rip')
        -- recordCastTable stamps the intent with the real client clock; align the
        -- seeded castAt into the fake pair window around the 1000.5 apply time
        -- (write to the fake context's own intent only)
        fakeLoginContext.intentTable['Rip']['QTestMob'].top.castAt = 999.0
        intentResult = macroTorch.processRawAuraApply('Rip',
            '0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 1000.5)
        ...
    end)
    macroTorch.loginContext = savedLoginContext
    macroTorch.target = savedTarget
    macroTorch.show = savedShow
    assert(pcallRes, "Q-02 pcall failed")
    assert(intentState == 'landed', ...)
    ...
end, true)
```
Invariants a new case must honor (Category Q header comment, lines 763-769): fake loginContext/target built before install; framework calls inside pcall; results captured to locals; globals restored by raw assignment; asserts run only AFTER restore; no test writes `macroTorch.tracingSpells`, `landSources`, `landListeners`, or real loginContext sub-tables. Seeded-intent pattern (Q-04 lines 855-859): build `fakeLoginContext.intentTable[spell][mob] = macroTorch.LRUStack:new(32)` and `push({ state = 'pending', castAt = N, landAt = nil })`, then drive `pairLandIntent`/`finalizeFail` directly with explicit clock values.

Six new cases (D-16), all following Q-02..Q-07 shapes, likely numbered Q-08..Q-13:
1. no-evidence -> inference triggers after ttl (`computeLandTable` + fake castTable/landTable/failTable stacks);
2. apply arriving late for same cast is rejected (cast-predicate dedup) — drive `recordLandEvent`/`processRawAuraApply` with `lastLand >= lastCast`;
3. fail inside window vetoes inference, fail outside window does not;
4. intentTtl 0.9 vs 2 boundary (register with explicit `intentTtl` or seeded `intent.ttl`);
5. renewal exemption (`recordLandEventRenewal` writes new anchor despite `lastLand >= lastCast`);
6. remote late-arrival: apply 1s after cast still pairs when window is 2 (stubbed per-spell ttl).

### 5. Todo file deletion

`druid-rip-land-forensics-next-cd.md` — closed per CONTEXT "Folded Todos"; remove via git. Not present in current working tree (forensics instrumentation already removed by quick 260909-w3r); locate by name at execution start (search `.planning/` recursively) — if absent, the deletion task reduces to a no-op with verification.

### 6. `core/events.lua` (VERIFICATION-ONLY, no edit)

**Analog/read target:** `core/events.lua:130-164`. Tier-2 (lines 156-163) iterates the precompiled table:
```lua
        if arg2 then
            for spellName, pattern in pairs(macroTorch.auraApplySpellPatterns) do
                if string.find(arg2, pattern) then
                    macroTorch.processRawAuraApply(spellName, arg2, macroTorch.target.guid, GetTime())
                    break
                end
            end
        end
```
CONFIRMED: no edit needed IF register keeps populating `auraApplySpellPatterns` (see 1a — the table survives, only its fill trigger changes). Planner must cross-check the population driver against this consumer.

## Shared Patterns

### Guard shape (apply to every new/modified function in spell_trace_core.lua)
**Source:** `core/spell_trace_core.lua:292-307` (recordLandEvent head) — the universal entry guard:
```lua
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
        return
    end
    -- lazy-init the per-spell/mob sub-table, then LRUStack:new(...)
```
Same shape in `recordCastTable` (87-101), `pairLandIntent` (164-175), `finalizeFail` (366-377), and the archived `computeLandTable`.

### LRUStack data-structure API
**Source:** `core/periodic.lua:17-92` (git-tracked). Fields: `.elements` (array), `.top` (via `ES_FIELD_FUNC_MAP` accessor, lines 81-87), `.size`. Methods: `push` (31-36, head-drop bounded), `pop`, `anyMatch` (45-52), `allMatch`, `removeMatch` (65-72, newest-match removal = land-entry revocation). All new land inference/dedup code reads `peekCastEvent`/`peekLandEvent`/`peekFailEvent` (spell_trace_core.lua:462-491) rather than stacks directly — failTable items are `{ time, failType }` pairs (see recordFailTable line 146), landTable/castTable items are bare timestamps.

### Periodic task registration
**Source:** `core/spell_trace_immune.lua:63-64` (same-file-package precedent):
```lua
macroTorch.registerPeriodicTask('spellsImmuneTracing',
    { interval = 0.1, task = macroTorch.spellsImmuneTracing })
```
Revived `maintainLandTables` re-registers the exact archived line (`eb56a257` line 76). `registerPeriodicTask` defined in `core/periodic.lua:127-129`. Task names are unique registry keys — do not reuse an existing name.

### Announcement discipline (show + color)
**Source:** `core/spell_trace_core.lua:355-357` (green, announce-BEFORE-record causal order) and `:437-440` (same for self-hit), `:394-399` (red cancellation), archived computeLandTable (blue). Rules: plain `macroTorch.show(msg, 'green'|'red'|'blue')`, English message text, announce precedes `recordLandEvent` so listener output follows the landed line (causal-order comment at 429-435 is load-bearing and survives the gate removal).

### Selftest registration + isolation
**Source:** `classes/druid/selftest.lua:763-769` (CR-01 discipline) + `core/selftest.lua:604-652` (Category K simple-assert form for non-stubbed registry checks). `SelfTest:register(name, fn, isOptional)`; optional tests guard `if UnitClass('player') ~= 'X' then return end`. Q-01 rewrite is non-stubbed (asserts module-level registries directly, like Category K); the six new behavioral cases are stubbed (fakeLoginContext/fakeTarget/pcall/show-stub/restore-then-assert).

### Lua 5.0 / build / style gates (apply to ALL files)
- Lua 5.0 tokens only: no `#` length operator (use `macroTorch.tableLen`), no `goto`, no `::` labels.
- LF line endings (.gitattributes enforced); English code comments and commit messages.
- `SM_EXTEND.lua` (repo root, case `SM_Extend.lua`) is a build artifact: never edited, build runs on user's Windows+Cygwin side.
- bbcheck bracket-balance discipline applies to edited Lua blocks.

## No Analog Found

None — every modified file is its own best analog (in-file or in-git-history patterns), which is expected for a refactor phase.

## Open Detail Flags for Planner (not pattern blockers)

1. **auraApplySpellPatterns population driver** (1a): the table consumer in `events.lua:157` must keep working after `landSource` deletion. Planner picks the concrete natural-attribute field that triggers pattern building for Pounce/Rip/Serpent/Scorpid (current set: exactly the four spells with `landSource = 'aura-apply'` and `debuffTexture + immune = true`).
2. **Per-spell ttl lookup in computeLandTable** (1e): archived code has no ttl; D-05 says inference anchor/window read the per-spell ttl. Recommend a module-level `macroTorch.landIntentTtls[name]` registry written by register (default 0.9), read by recordCastTable seeding, pairLandIntent, finalizeFail, and computeLandTable.
3. **cpDamage untouched** (1c): `pairCpDamageIntent` keeps the global-constant reference — the 0.9 value change flows automatically (D-17).

## Metadata

**Analog search scope:** `core/`, `classes/druid/`, `classes/hunter/`, git history (`eb56a257` pre-refactor spell_trace_core.lua)
**Files scanned:** 10 read (`spell_trace_core.lua`, `spell_trace_immune.lua`, `events.lua`, `periodic.lua`, `core/selftest.lua` (partial), `Druid.lua` (partial), `Hunter.lua` (partial), `druid/selftest.lua` (partial), `29-CONTEXT.md`, `DESIGN-CONTEXT.md`) + 1 git-object (`eb56a257:core/spell_trace_core.lua`)
**Pattern extraction date:** 2026-09-10
**Tracked-source gate:** all named analogs verified via `git ls-files` (core/spell_trace_core.lua, core/periodic.lua, core/events.lua, core/spell_trace_immune.lua, classes/druid/Druid.lua, classes/druid/selftest.lua, classes/hunter/Hunter.lua); the archived computeLandTable is cited as git history of the tracked file, not a mirror.