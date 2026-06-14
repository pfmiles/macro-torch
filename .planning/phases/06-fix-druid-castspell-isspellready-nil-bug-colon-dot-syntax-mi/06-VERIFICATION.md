---
phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi
verified: 2026-06-14
status: human_needed
score: 15/15 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run /mt in-game on Druid character"
    expected: "All Category F tests pass (15 passed, 0 failed)"
    why_human: "Requires WoW 1.12.1 client with addon loaded; cannot verify programmatically"
  - test: "Execute Type A/B/C skill tests from HUMAN-UAT.md in-game"
    expected: "No Lua errors; skills cast correctly in each mode (ready/safe/raw)"
    why_human: "CastSpellByName requires WoW client; manual testing only"
  - test: "Execute catAtk one-button macro integration test"
    expected: "Skills fire automatically; combo points build/consume; no Lua errors"
    why_human: "Complex in-game combat interaction; cannot verify programmatically"
  - test: "External isSpellReady call returns true/false (not nil)"
    expected: "macroTorch.player.isSpellReady('Claw') returns boolean, not nil"
    why_human: "SpellReady WoW API call requires WoW client"
  - test: "Non-Druid character: Category F tests silently skip"
    expected: "/mt shows 0 Category F failures on non-Druid characters"
    why_human: "Requires WoW client with non-Druid character logged in"
---

# Phase 06: Fix Druid _castSpell isSpellReady nil bug — Verification Report

**Phase Goal:** Fix `_castSpell` colon/dot syntax mismatch in entity/Player.lua and classes/druid/Druid.lua that causes isSpellReady to always return nil. Add selftest tests for metatable chain integrity.

**Verified:** 2026-06-14
**Status:** human_needed
**Score:** 15/15 must-haves verified

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `_castSpell` line 52 uses `obj.isSpellReady(spellName)` not `self:isSpellReady(spellName)` (per D-02) | VERIFIED | entity/Player.lua:52 reads `if not obj.isSpellReady(spellName) then` |
| 2 | `_castSpell` line 59 uses `obj._isInRange(range)` not `self:_isInRange(range)` (per D-02) | VERIFIED | entity/Player.lua:59 reads `if range and not obj._isInRange(range) then` |
| 3 | `_castSpell` line 69 uses `obj._hasResource(cost)` not `self:_hasResource(cost)` (per D-02) | VERIFIED | entity/Player.lua:69 reads `if not obj._hasResource(cost) then` |
| 4 | `_castSpell` line 79 uses `obj.cast(spellName, false)` not `self:cast(spellName, false)` (per D-02) | VERIFIED | entity/Player.lua:79 reads `obj.cast(spellName, false)` |
| 5 | All 53 Druid skill methods use `obj._castSpell(...)` not `self:_castSpell(...)` (per D-03) | VERIFIED | grep confirms 0 `self:_castSpell`, 53 `obj._castSpell(` in classes/druid/Druid.lua |
| 6 | entity/Player.lua has zero `self:xxx()` calls (per D-01) | VERIFIED | grep confirms 0 matches for `self:isSpellReady\|self:_isInRange\|self:_hasResource\|self:cast` |
| 7 | classes/druid/Druid.lua has zero `self:_castSpell` calls (per D-03) | VERIFIED | grep confirms 0 matches for `self:_castSpell` |
| 8 | isSpellReady/cast/_isInRange/_hasResource definitions remain dot syntax unchanged (per D-01, D-04, D-05) | VERIFIED | All 5 method definitions confirmed as `function obj.methodName(...)` dot syntax in entity/Player.lua |
| 9 | _hasResource line 102 `self.mana` unchanged (per D-05, Pitfall 3) | VERIFIED | entity/Player.lua:102 reads `return self.mana and self.mana >= cost` |
| 10 | All Category F selftest tests registered (at least 15, isOptional=false) (per D-06) | VERIFIED | 15 tests registered in core/selftest.lua lines 464-568, all with `false` third argument |
| 11 | Category F tests skip on non-Druid characters (per D-06) | VERIFIED | All 15 tests begin with `if UnitClass('player') ~= 'Druid' then return end` guard |
| 12 | HUMAN-UAT.md exists at classes/druid/HUMAN-UAT.md (per D-07) | VERIFIED | File exists and is readable |
| 13 | HUMAN-UAT.md covers Type A, Type B, Type C skills | VERIFIED | grep confirms 4 Type A, 4 Type B, 4 Type C section references |
| 14 | HUMAN-UAT.md covers ready, safe, raw modes | VERIFIED | grep confirms mode coverage: 'ready' (4), 'safe' (3), 'raw' (3) |
| 15 | HUMAN-UAT.md includes /mt pre-test verification step | VERIFIED | 2 references to /mt found in HUMAN-UAT.md |

**Score:** 15/15 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `entity/Player.lua` | Fixed _castSpell internal calls with correct dot syntax | VERIFIED | 4 lines changed (52, 59, 69, 79): `self:xxx()` -> `obj.xxx()`. Zero `self:` calls remain. All 5 method definitions unchanged. |
| `classes/druid/Druid.lua` | Fixed Druid skill methods with `obj._castSpell` dot calls | VERIFIED | 53 lines changed (26-239): all `self:_castSpell(` -> `obj._castSpell(`. Zero `self:_castSpell` calls remain. |
| `core/selftest.lua` | Category F metatable chain integrity tests (15 tests) | VERIFIED | 113 lines added, 15 tests registered with `isOptional=false`, all Druid-guarded, all pcall-wrapped for invocations |
| `classes/druid/HUMAN-UAT.md` | Manual test checklist | VERIFIED | Exists with Type A/B/C sections, mode coverage, /mt pre-test, integration test, regression checks |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Druid skill method `obj.claw(mode)` | `obj._castSpell` via metatable __index chain | `obj._castSpell(...)` dot call resolves through classMetatable __index: DRUID_FIELD_FUNC_MAP -> macroTorch.Druid -> macroTorch.Player | WIRED | `core/class.lua` classMetatable step 2 (`cls[k]`) finds `_castSpell` on macroTorch.Druid (inherited from Player:new() closure) |
| `obj._castSpell` internal `obj.isSpellReady(spellName)` | Player instance `isSpellReady` closure | `obj` upvalue = Player instance, dot call passes correct single argument | WIRED | entity/Player.lua:52 uses `obj.isSpellReady(spellName)`. `obj` correctly resolves to Player instance; no parameter misalignment. |
| HUMAN-UAT.md /mt verification step | core/selftest.lua Category F tests | SLASH command /mt triggers SelfTest:run() | WIRED | HUMAN-UAT.md includes pre-test /mt step; Category F tests are registered in selftest.lua |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| entity/Player.lua _castSpell | `spellName` | `localeNames.en` or `localeNames.zh` from hardcoded locale tables in skill methods | Yes (static locale table) | FLOWING — spell names flow from skill method constants through _castSpell to CastSpellByName |
| entity/Player.lua _castSpell | `isSpellReady(spellName)` return | WoW API `SpellReady(spellName)` via `toBoolean()` | Yes (WoW API returns boolean-equivalent) | FLOWING — parameter now correctly passes spellName (not table); requires in-game verification |
| classes/druid/Druid.lua skill methods | `mode` parameter | Passed from caller (e.g. 'raw', 'safe', 'ready') | Yes (string literal from caller) | FLOWING — mode correctly passed as second argument to _castSpell |
| core/selftest.lua Category F | `type(macroTorch.player._castSpell)` | Druid instance metatable chain | Yes (function reference or nil) | FLOWING — metatable resolution test; produces real type result |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|---------|
| Build succeeds | `./build.sh && echo $?` | Exit code 0, SM_Extend.lua exists | PASS |
| Build output has zero `self:` calls | `grep -c 'self:isSpellReady\|self:_isInRange\|self:_hasResource' SM_Extend.lua` | 0 | PASS |
| Build output has zero `self:_castSpell` | `grep -c 'self:_castSpell' SM_Extend.lua` | 0 | PASS |
| Build output has Category F tests | `grep -c 'Category F:' SM_Extend.lua` | 1 | PASS |
| Cat F tests invoke obj._castSpell (not self) | `grep "macroTorch.player" core/selftest.lua | grep -E "_castSpell\|claw\|isSpellReady" | head -5` | All use dot syntax `macroTorch.player.xxx()` — correct | PASS |

### Probe Execution

No probes declared for this phase. SKIPPED (documentation + mechanical Lua fix; probes not applicable).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| R8 | 06-01 | Druid 猫德逻辑保持 — all catAtk, keepRip, keepRake, keepFF, regularAttack, reshift functions remain unchanged | SATISFIED | Only _castSpell internal call syntax and Druid skill method _castSpell invocation syntax changed; no logic, constant, or function signature changes. Verified via git diff: 4 lines in Player.lua, 53 lines (mechanical s/self:_castSpell/obj._castSpell/) in Druid.lua skill methods. |
| D-01 | 06-01 | All method definitions use dot syntax | SATISFIED | All 5 method definitions (cast, _castSpell, _isInRange, _hasResource, isSpellReady) confirmed as `function obj.methodName(...)` in entity/Player.lua |
| D-02 | 06-01 | _castSpell internal 4 calls use dot syntax (obj.xxx) | SATISFIED | Lines 52, 59, 69, 79 verified: `obj.isSpellReady`, `obj._isInRange`, `obj._hasResource`, `obj.cast` |
| D-03 | 06-01 | Druid skill methods use `obj._castSpell` not `self:_castSpell` | SATISFIED | 53 `obj._castSpell(` matches, 0 `self:_castSpell` matches in Druid.lua |
| D-04 | 06-01 | isSpellReady and cast definitions unchanged; external callers unchanged | SATISFIED | Dot definitions preserved; external callers (cat.lua, utility.lua, bear.lua, Hunter.lua) confirmed unchanged via git diff |
| D-05 | 06-01 | _isInRange and _hasResource definitions unchanged; _hasResource self.mana preserved | SATISFIED | Definitions unchanged; entity/Player.lua:102 `self.mana` confirmed unchanged |
| D-06 | 06-01 | Category F selftest tests (15, isOptional=false) in core/selftest.lua | SATISFIED | 15 tests registered lines 464-568, all `isOptional=false`, all Druid-guarded with pcall |
| D-07 | 06-02 | HUMAN-UAT.md covers Type A/B/C skills across ready/safe/raw modes | SATISFIED | File exists; 4 Type A/B/C section refs each; mode coverage confirmed |

Note: D-01 through D-07 are phase-level decisions defined in 06-CONTEXT.md, not global requirements in REQUIREMENTS.md. The only global requirement is R8. The D-0X tags are included here because PLAN frontmatter lists them under `requirements:`.

### Anti-Patterns Found

No anti-patterns introduced by this phase:

- Zero `TBD`, `FIXME`, `XXX` markers in any modified file (or in the modified sections)
- Pre-existing `TODO` markers in Druid.lua (lines 333, 380, 425) are outside the modified skill method section (lines 25-248) — these are legacy technical debt from prior phases, not introduced by Phase 06
- Zero stub returns (`return nil`, `return {}`, `return []`) in affected code paths
- Zero hardcoded empty data in Phase 06 changes
- Zero `console.log`-only implementations
- Pre-existing `TODO` markers are referenced to future work (wolfheart enchant, bear form separation) — not formally tracked but pre-date this phase

### Human Verification Required

#### 1. Category F Selftest — /mt on Druid Character

**Test:** Log in on a Druid character, run `/mt` in chat.
**Expected:** Summary shows "N passed, 0 failed, M warnings" with zero red "FAIL: F:" messages. All 15 Category F tests pass.
**Why human:** Requires WoW 1.12.1 client with addon loaded and a Druid character.

#### 2. HUMAN-UAT.md Type A/B/C Skill Tests

**Test:** Follow `classes/druid/HUMAN-UAT.md` checklist step-by-step in-game. Execute each skill method (`/run macroTorch.player.claw('ready')`, etc.) across Type A (enemy-target), Type B (self-target), Type C (flexible-target) in all three modes (ready, safe, raw).
**Expected:** No Lua errors in chat. Skills cast correctly when off cooldown and in range. Mode behavior matches specification (ready = cooldown check, safe = range+resource, raw = no checks).
**Why human:** CastSpellByName requires WoW client. Spell readiness, range, and resource checks depend on in-game state. Cannot be verified programmatically.

#### 3. catAtk One-Button Macro Integration Test

**Test:** Bind catAtk to a key. Target a hostile mob. Enter Cat Form. Press the bound key repeatedly during combat.
**Expected:** Skills fire automatically (claw, shred, rake, rip, ferocious_bite as appropriate). No Lua errors. Combo points build up and are consumed correctly. Cat Form skills actually land on target.
**Why human:** Complex in-game combat interaction involving GCD, energy management, combo point tracking, and multiple WoW API calls. Cannot be verified programmatically.

#### 4. External isSpellReady Call Regression

**Test:** Run `/run local r = macroTorch.player.isSpellReady('Claw'); macroTorch.show(tostring(r))`
**Expected:** Shows `true` or `false` (a boolean value). Must not show `nil` or trigger a Lua error.
**Why human:** SpellReady() WoW API requires WoW client to return valid results.

#### 5. Non-Druid Character Regression

**Test:** Log in on a non-Druid character (e.g., Hunter), run `/mt`.
**Expected:** Category F tests should be silently skipped. No red "FAIL: F:" messages. No Lua errors.
**Why human:** Requires WoW client with a non-Druid character to verify the `UnitClass('player') ~= 'Druid'` guard correctly skips tests.

---

_Verified: 2026-06-14_
_Verifier: Claude (gsd-verifier)_