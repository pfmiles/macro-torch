---
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
verified: 2026-08-17T00:00:00Z
status: human_needed
score: 15/19 must-haves verified
behavior_unverified: 4
overrides_applied: 0
behavior_unverified_items:
  - truth: "UNIT_SPELLCAST_SUCCEEDED event fires and arg2 (spellName) is recorded into castTable when the spell is in the name-keyed tracingSpells set"
    test: "Cast any land-tracing spell (e.g. Rake) on a target mob and verify via /mt debug that recordCastTable is called with the correct spellName"
    expected: "recordCastTable receives the spellName string (not a spellId number). The castTable entry is populated."
    why_human: "WoW event handling requires the actual game client running. Presence checks confirm the handler code is correct, but event delivery and parameter passing can only be verified in-game."
  - truth: "recordCastTable skips duplicate pushes when the same spellName lands on the same mob within 0.2s"
    test: "Cast a land-tracing spell rapidly (within 0.2s) on the same target and verify only one cast record is pushed, not two"
    expected: "Only one entry in castTable for that spell+mob combination despite two rapid casts"
    why_human: "The dedup logic depends on GetTime() return values and LRUStack.top state at runtime. Code review confirms the algorithm, but race conditions and actual timing can only be verified in-game under real GCD constraints."
  - truth: "All Druid land-tracing spells (Pounce, Rake, Rip, Ferocious Bite) continue to register and record successfully"
    test: "Cast each of the 4 Druid land-tracing spells (Pounce, Rake, Rip, Ferocious Bite) on a target mob and verify cast events are recorded"
    expected: "Each spell's cast is recorded in castTable with the correct spellName as key"
    why_human: "Registration code is verified present, but actual event recording requires the WoW client to fire UNIT_SPELLCAST_SUCCEEDED events for these specific spells."
  - truth: "All Category K and N tests pass via /mt self-test"
    test: "In-game, type /mt and verify that all Category K (5 tests) and Category N (4 tests) pass without assertion failures"
    expected: "Self-test summary shows zero failures for K and N tests"
    why_human: "Self-test assertions depend on macroTorch runtime state (tracingSpells contents, loginContext, etc.) which are only populated when the addon is loaded in the WoW client."
gaps: []
---

# Phase 24: UNIT_SPELLCAST_SUCCEEDED Cast Recording Verification Report

**Phase Goal:** 用标准 WoW 1.12 事件 UNIT_SPELLCAST_SUCCEEDED 替代 SuperWoW 的 UNIT_CASTEVENT 作为 cast 记录链路，消除对全局 spellId 的依赖。
**Verified:** 2026-08-17
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

#### Plan 24-01 (tracingSpells refactor + UNIT_SPELLCAST_SUCCEEDED + dedup)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | UNIT_SPELLCAST_SUCCEEDED event fires and arg2 (spellName) is recorded into castTable when the spell is in the name-keyed tracingSpells set | PRESENT_BEHAVIOR_UNVERIFIED | Handler present at `core/events.lua:162-166`: `if arg1 == "player" and arg2 and macroTorch.tracingSpells[arg2] then macroTorch.recordCastTable(arg2) end`. Code correctly wired, but event delivery requires in-game verification. |
| 2 | UNIT_CASTEVENT handler no longer calls recordCastTable | VERIFIED | `grep 'recordCastTable' core/events.lua` shows zero matches in UNIT_CASTEVENT block (lines 107-142). Only the auto-correction logic (lines 119-141) remains, which does NOT call recordCastTable. |
| 3 | tracingSpells is keyed by spellName (string) with value true | VERIFIED | `core/spell_trace_core.lua:27`: `macroTorch.tracingSpells[spellName] = true`. Setter function uses single spellName parameter; no spellId mapping. |
| 4 | SpellTrace:register land=true path calls setSpellTracing(name) without resolveSpellId | VERIFIED | `core/spell_trace_core.lua:75-76`: `if config.land then macroTorch.setSpellTracing(name) end`. No resolveSpellId call in the land branch. |
| 5 | maintainLandTables iterates tracingSpells by name | VERIFIED | `core/spell_trace_core.lua:113`: `for spellName in pairs(macroTorch.tracingSpells) do`. Correct for name-keyed set (key IS the spellName). |
| 6 | recordCastTable skips duplicate pushes when same spellName+mob within 0.2s | PRESENT_BEHAVIOR_UNVERIFIED | Dedup logic present at `core/spell_trace_core.lua:136-141`: `local last = castTable[spell][mob].top; if last and (GetTime() - last) < 0.2 then return end`. Algorithm correct, but actual timing behavior requires in-game validation. |
| 7 | All 4 Druid land-tracing spells (Pounce, Rake, Rip, Ferocious Bite) continue to register and record successfully | PRESENT_BEHAVIOR_UNVERIFIED | Registration verified: `classes/druid/Druid.lua:683-698` shows all 4 spells with `land=true` via SpellTrace:register. Recording requires in-game event delivery. |
| 8 | build.sh produces a valid SM_Extend.lua | VERIFIED | `./build.sh` exit code 0. Output: `SM_Extend.lua` at 9,241 lines, 370,936 bytes. Contains all expected code patterns. |

#### Plan 24-02 (current_casting_spell removal + deprecation markers)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 9 | Player._castSpell no longer sets current_casting_spell (entire bridge block removed) | VERIFIED | `grep 'current_casting_spell' entity/Player.lua` returns zero results. The _castSpell function (lines 42-84) flows: locale selection -> readiness check -> distance+resource checks -> unified cast path. No bridge variable set. |
| 10 | SPELL_ID_AUTO_CORRECT, resolveSpellId, _spellIdMonitored, and loadSpellIdMap are marked -- DEPRECATED | VERIFIED | 6 DEPRECATED markers across 4 files: `macro_torch.lua:25` (SPELL_ID_AUTO_CORRECT), `spell_trace_core.lua:18,51,78` (_spellIdMonitored, resolveSpellId, monitorSpellId), `spell_trace_immune.lua:104` (loadSpellIdMap), `combat_context.lua:40` (call site). All match pattern: `DEPRECATED.*Phase 24`. |
| 11 | loadSpellIdMap call gated behind SPELL_ID_AUTO_CORRECT check | VERIFIED | `core/combat_context.lua:42-44`: `if macroTorch.SPELL_ID_AUTO_CORRECT then macroTorch.loadSpellIdMap() end`. Default `SPELL_ID_AUTO_CORRECT = false` means no-op. |
| 12 | DEPRECATED markers explain retained-for-legacy purpose | VERIFIED | All 6 markers include "Retained for legacy" or equivalent language. Example: `macro_torch.lua:26`: "Retained for legacy SuperWoW spellId auto-correction (opt-in via /run)." |
| 13 | cast->land->immune chain no longer references any spellId-based data structure | VERIFIED | Active code path (excluding deprecated blocks) shows zero spellId-based lookups in tracingSpells or castTable. Only remaining numeric references are in dead-code auto-correction paths. |
| 14 | build.sh produces a valid SM_Extend.lua | VERIFIED | Build exit 0. SM_Extend.lua contains all DEPRECATED markers. |

#### Plan 24-03 (selftest updates)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 15 | Category K tests reference name-keyed tracingSpells and do not test current_casting_spell lifecycle | VERIFIED | `core/selftest.lua:620-680`: 5 K tests. K1 validates tracingSpells structure with name keys (Pounce/Rake/Rip/Ferocious Bite = true) and type-checks all keys are strings. K2 tests setSpellTracing(spellName) single-arg signature. Zero current_casting_spell references in selftest. |
| 16 | Category N tests acknowledge deprecated SPELL_ID_AUTO_CORRECT and resolveSpellId/loadSpellIdMap as legacy | VERIFIED | `core/selftest.lua:801-878`: 4 N tests (all optional). N1 verifies default=false and boolean type. N2/N3 verify resolveSpellId legacy correction paths. N4 verifies loadSpellIdMap no-op when switch is false. All use "deprecated" language. |
| 17 | All Category K and N tests pass via /mt self-test | PRESENT_BEHAVIOR_UNVERIFIED | Test code is syntactically correct and builds cleanly. Cannot execute WoW's /mt command outside the game client. |
| 18 | SPELL_NAME_TO_ID static table verified to still exist | VERIFIED | `core/selftest.lua:652-660` (K3): asserts type=table and verifies 4 Druid spell IDs (Pounce=9827, Rake=9904, Rip=9896, Ferocious Bite=31018). |
| 19 | build.sh produces a valid SM_Extend.lua | VERIFIED | Build exit 0. SM_Extend.lua contains updated Category K and N tests. |

**Score:** 15/19 truths verified (4 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `core/spell_trace_core.lua` | name-keyed tracingSpells, simplified setSpellTracing, dedup logic | VERIFIED | 326 lines. All required changes present. Minor: stale header comment at lines 67-72 references old API (spellId field, old setSpellTracing signature). |
| `core/events.lua` | Active UNIT_SPELLCAST_SUCCEEDED handler, UNIT_CASTEVENT cast-recording removed | VERIFIED | 183 lines. Active handler at line 162-166. UNIT_CASTEVENT block (107-142) has no recordCastTable call. |
| `entity/Player.lua` | current_casting_spell bridge removed, unified cast path preserved | VERIFIED | 794 lines. _castSpell (42-84) is clean - no current_casting_spell. obj.cast + return true preserved. |
| `core/spell_trace_immune.lua` | DEPRECATED marker on loadSpellIdMap, function retained | VERIFIED | Marker at line 104. Function body preserved (lines 110-135). |
| `macro_torch.lua` | DEPRECATED marker on SPELL_ID_AUTO_CORRECT, default false | VERIFIED | Marker at line 25. `macroTorch.SPELL_ID_AUTO_CORRECT = false` at line 37. |
| `core/combat_context.lua` | loadSpellIdMap gated behind SPELL_ID_AUTO_CORRECT | VERIFIED | Gate at lines 42-44. DEPRECATED comment at line 40. |
| `core/selftest.lua` | Category K (5 tests) and Category N (4 tests) updated | VERIFIED | K: 5 tests (lines 613-680), N: 4 tests (lines 801-876). All syntactically correct and build-clean. |

### Key Link Verification

#### Plan 24-01 Key Links

| From | To | Via | Status |
|------|----|-----|--------|
| UNIT_SPELLCAST_SUCCEEDED handler | recordCastTable | `events.lua:164-165`: `if arg1 == "player" and arg2 and macroTorch.tracingSpells[arg2] then macroTorch.recordCastTable(arg2) end` | WIRED |
| SpellTrace:register land=true path | setSpellTracing(name) | `spell_trace_core.lua:75-76`: `if config.land then macroTorch.setSpellTracing(name) end` | WIRED |
| recordCastTable dedup | LRUStack.top | `spell_trace_core.lua:138-141`: `local last = castTable[spell][mob].top; if last and (GetTime() - last) < 0.2 then return end` | WIRED |

#### Plan 24-02 Key Links

| From | To | Via | Status |
|------|----|-----|--------|
| SpellTrace:register | setSpellTracing(name) | `spell_trace_core.lua:75-76`: name-based registration, no spellId interposed | WIRED |
| loadSpellIdMap gating | SPELL_ID_AUTO_CORRECT guard | `combat_context.lua:42`: `if macroTorch.SPELL_ID_AUTO_CORRECT then` prevents work when disabled | WIRED |

#### Plan 24-03 Key Links

| From | To | Via | Status |
|------|----|-----|--------|
| Category K: tracingSpells validation | name-keyed structure | `selftest.lua:625-637`: asserts string keys + value=true for all 4 Druid spells | WIRED |
| Category N: deprecation awareness | default-false legacy status | `selftest.lua:807-812`: asserts boolean type + default=false | WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build produces valid SM_Extend.lua | `./build.sh` | exit 0, output 9241 lines | PASS |
| SM_Extend.lua contains UNIT_SPELLCAST_SUCCEEDED handler | `grep 'UNIT_SPELLCAST_SUCCEEDED.*tracingSpells' SM_Extend.lua` | Handler present at expected pattern | PASS |
| SM_Extend.lua contains dedup logic | `grep -c 'GetTime.*last.*0.2' SM_Extend.lua` | 1 match | PASS |
| SM_Extend.lua contains all 6 DEPRECATED markers | `grep -c 'DEPRECATED.*Phase 24' SM_Extend.lua` | 6 matches | PASS |
| Selftest Category K: 5 tests present | `grep -c 'SelfTest:register.*"K:"' core/selftest.lua` | 5 tests | PASS |
| Selftest Category N: 4 tests present | `grep -c 'SelfTest:register.*"N:"' core/selftest.lua` | 4 tests | PASS |
| No current_casting_spell in selftest | `grep 'current_casting_spell' core/selftest.lua` | 0 matches | PASS |
| No current_casting_spell in Player.lua | `grep 'current_casting_spell' entity/Player.lua` | 0 matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REQ-24-TRACER | 24-01-PLAN | tracingSpells name-keyed refactor + UNIT_SPELLCAST_SUCCEEDED handler + recordCastTable dedup | SATISFIED | All 8 truths verified or present. Code is structurally correct and builds cleanly. |
| REQ-24-CLEANUP | 24-02-PLAN | Remove current_casting_spell bridge + mark spellId infrastructure deprecated | SATISFIED | All 6 truths verified. Bridge fully removed. 6 DEPRECATED markers in place. loadSpellIdMap gated. |
| REQ-24-SELFTEST | 24-03-PLAN | Update Category K and N selftests for Phase 24 architecture | SATISFIED | 5 K tests + 4 N tests present and syntactically correct. Build passes. Cannot execute in-game from verifier. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `core/spell_trace_core.lua` | 67-72 | Stale API documentation comments | WARNING | Header comment for SpellTrace:register still references old API: `{spellId, immune, land, debuffTexture}` and `setSpellTracing(spellId, name)`. The actual implementation is correct, but the comment misleads future readers. |
| `core/spell_trace_core.lua` | 96 | Stale inline comment | INFO | Comment references `tracingSpells[id] = name` (old key pattern), but the code around it is deprecated anyway. Low impact. |
| `core/selftest.lua` | 680 (missing) | Missing registration count comment | INFO | Category K section lacks the `-- Registration count: Category K adds 5 tests (3 core + 2 optional)` comment that the plan specified (Task 1). The header at line 613 covers the same information. |

### Human Verification Required

#### 1. UNIT_SPELLCAST_SUCCEEDED Event Handling

**Test:** Cast any of the 4 Druid land-tracing spells (Pounce, Rake, Rip, Ferocious Bite) on a target mob. Enable debug mode and observe the cast recording output.

**Expected:** The cast is recorded via UNIT_SPELLCAST_SUCCEEDED (arg2 = spellName string). The debug prints show `"{spellName} cast on {mob} is recorded/renewed to castTable"`. The castTable entry uses the spell name string as the key.

**Why human:** WoW event delivery and parameter passing can only be verified in the actual game client. The handler code is present and correctly wired, but the WoW runtime determines whether UNIT_SPELLCAST_SUCCEEDED fires correctly for these specific spells.

---

#### 2. recordCastTable Deduplication (0.2s window)

**Test:** Cast Rake rapidly on the same target. In normal gameplay, this requires cat form energy pooling. Verify only one cast record is pushed to castTable per actual cast, not two.

**Expected:** Despite both UNIT_SPELLCAST_SUCCEEDED and (on SuperWoW) UNIT_CASTEVENT potentially firing for the same cast, only one entry appears in castTable for that spell+mob combination.

**Why human:** The dedup logic depends on actual GetTime() return values and the GCD timing of the WoW client. The 0.2s threshold is based on GCD minimum of 1.0s, but this needs in-game confirmation.

---

#### 3. All 4 Druid Spells Record Successfully

**Test:** Cast each of the 4 spells (Pounce, Rake, Rip, Ferocious Bite) on target mobs and verify they are all recorded in castTable.

**Expected:** Each cast produces an entry in castTable with the correct spell name as the key. Subsequent land/immune calculations use these cast records.

**Why human:** The registration code is verified present, but actual event recording requires the WoW client to fire UNIT_SPELLCAST_SUCCEEDED events for these specific Druid spells.

---

#### 4. Self-Test Category K and N

**Test:** In-game, type `/mt` and observe the self-test output in the chat frame.

**Expected:** 
- Category K: 5 tests, all passing. Specifically K1 verifies all 4 spells as name-keyed in tracingSpells with no numeric keys. K2 verifies setSpellTracing single-arg signature. K3-K5 verify legacy infrastructure retained.
- Category N: 4 tests, all passing. N1 confirms SPELL_ID_AUTO_CORRECT defaults to false. N2/N3 verify resolveSpellId legacy paths. N4 verifies loadSpellIdMap no-ops.

**Why human:** Self-test assertions depend on runtime macroTorch state (tracingSpells populated by Druid.lua SpellTrace:register calls, loginContext initialized via onPlayerEnteringWorld). These are only available when the addon is fully loaded in the WoW client.

---

### Minor Issues (non-blocking)

1. **Stale header comment** in `core/spell_trace_core.lua:67-72`: The SpellTrace:register function's documentation comment still references `spellId` as a config field and says `setSpellTracing(spellId, name)`. The actual implementation at line 76 correctly uses `setSpellTracing(name)`. This comment should be updated to reflect the Phase 24 API.

2. **Missing registration count comment** after Category K in `core/selftest.lua`: The plan specified a `-- Registration count: Category K adds 5 tests (3 core + 2 optional)` comment after K5, but it was not added. The header at line 613 covers the same information but the pattern is inconsistent with other categories (L, M, N).

---

_Verified: 2026-08-17_
_Verifier: Claude (gsd-verifier)_