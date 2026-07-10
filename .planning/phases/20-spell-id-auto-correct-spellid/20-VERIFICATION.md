---
phase: 20-spell-id-auto-correct-spellid
verified: 2026-07-11T00:00:00Z
status: human_needed
score: 7/16 must-haves verified
behavior_unverified: 9
overrides_applied: 0
gaps: []
behavior_unverified_items:
  - truth: "resolveSpellId() skips loginContext.spellIdMap lookup when SPELL_ID_AUTO_CORRECT is false"
    test: "Set macroTorch.SPELL_ID_AUTO_CORRECT = false in-game, call resolveSpellId('Rake'), verify result equals SPELL_NAME_TO_ID['Rake'] (1822)"
    expected: "Returns 1822 without accessing spellIdMap"
    why_human: "Code guard present at core/spell_trace_core.lua:64 — but cannot verify runtime behavior without WoW client. Presence checks confirm the if-guard structure; actual skip behavior requires in-game execution."

  - truth: "resolveSpellId() returns SPELL_NAME_TO_ID static value directly when switch is off"
    test: "Same test as above — verify resolveSpellId returns static values directly"
    expected: "SPELL_NAME_TO_ID[spellName] returned, no runtime correction applied"
    why_human: "Code guard present — but cannot verify runtime behavior without WoW client."

  - truth: "loadSpellIdMap() returns early without loading or migrating when SPELL_ID_AUTO_CORRECT is false"
    test: "Set SPELL_ID_AUTO_CORRECT = false, call loadSpellIdMap(), verify no SM_EXTEND.spellIdMap loading or tracingSpells key migration"
    expected: "Function returns immediately without side effects"
    why_human: "Early-return guard present at core/spell_trace_immune.lua:109 — but cannot verify runtime behavior without WoW client."

  - truth: "When SPELL_ID_AUTO_CORRECT is true, resolveSpellId() behavior is unchanged from current code"
    test: "Verify resolveSpellId('Rake') returns 1822 (or corrected value if previously persisted) with SPELL_ID_AUTO_CORRECT = true"
    expected: "Behavior identical to pre-Phase 20 code"
    why_human: "Code path is structurally identical — the if-guard wraps the existing code verbatim. Runtime regression requires in-game confirmation against previously working behavior."

  - truth: "current_casting_spell bridge variable is never set when SPELL_ID_AUTO_CORRECT is false"
    test: "Set SPELL_ID_AUTO_CORRECT = false, cast a monitored spell (e.g., Rake), verify current_casting_spell remains nil"
    expected: "current_casting_spell stays nil after cast"
    why_human: "Guard present at entity/Player.lua:86 — wraps both stale detection (87-107) and whitelist assignment (112-114). Cannot verify runtime behavior without WoW client."

  - truth: "Stale detection for current_casting_spell is never executed when SPELL_ID_AUTO_CORRECT is false"
    test: "Set SPELL_ID_AUTO_CORRECT = false, cast multiple monitored spells rapidly, verify no stale detection warnings appear"
    expected: "No yellow stale detection warnings in chat frame"
    why_human: "Guard present — stale detection is inside the same SPELL_ID_AUTO_CORRECT guard. Cannot verify runtime behavior without WoW client."

  - truth: "UNIT_CASTEVENT spellId correction block is skipped when SPELL_ID_AUTO_CORRECT is false"
    test: "Set SPELL_ID_AUTO_CORRECT = false, cast a spell on a different client version, verify no spellId correction yellow messages appear"
    expected: "No 'spellId corrected' messages in chat; SM_EXTEND.spellIdMap not updated"
    why_human: "Compound guard present at core/events.lua:98 — 'if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then'. Cannot verify runtime behavior without WoW client with SuperWow."

  - truth: "When SPELL_ID_AUTO_CORRECT is true, all behavior is identical to current code"
    test: "Verify with SPELL_ID_AUTO_CORRECT = true: cast spells, observe current_casting_spell lifecycle, spellId correction, resolveSpellId behavior"
    expected: "All behavior identical to pre-Phase 20 code"
    why_human: "All guards are pass-through when SPELL_ID_AUTO_CORRECT = true — existing code executes unchanged. Runtime regression requires in-game confirmation."

  - truth: "Setting SPELL_ID_AUTO_CORRECT = true and having a corrected spellId in spellIdMap causes resolveSpellId() to return the corrected value"
    test: "Run /mt, verify N3 passes (need loginContext with spellIdMap)"
    expected: "N3 selftest passes with corrected value returned"
    why_human: "Code present at core/selftest.lua:821-855. Requires in-game execution with a login context and spellIdMap to verify."

human_verification:
  - test: "N1-N5 selftest verification via /mt in-game"
    expected: "All 5 Category N selftests produce no FAIL or WARN messages; summary shows them as passed"
    why_human: "All 5 tests are isOptional=true — they appear under WARN if they fail. Core functionality tested by in-game execution of Selftest framework. No offline WoW Lua test harness exists."

  - test: "SPELL_ID_AUTO_CORRECT = false full-path verification"
    expected: "With switch off: casts produce no current_casting_spell bridge, no stale detection warnings, no spellId correction messages, resolveSpellId returns static SPELL_NAME_TO_ID values, loadSpellIdMap skips. recordCastTable still tracks land events."
    why_human: "Cross-file behavioral integration test requires in-game execution with SuperWow UNIT_CASTEVENT events."

  - test: "SPELL_ID_AUTO_CORRECT = true backward compatibility"
    expected: "With switch on (default): all spellId auto-correction operates exactly as before Phase 20. No functional regression."
    why_human: "This is the production path — the switch defaults to true, so this is the path all users will hit by default. In-game verification of the unchanged behavior is critical for regression safety."
---

# Phase 20: SPELL_ID_AUTO_CORRECT Global Switch Verification Report

**Phase Goal:** Add a global switch macroTorch.SPELL_ID_AUTO_CORRECT (default true) to control the spellId auto-correction mechanism. When false, all spellId correction is disabled -- resolveSpellId returns static values only, current_casting_spell bridge is never set, UNIT_CASTEVENT correction is skipped, and loadSpellIdMap is skipped.

**Verified:** 2026-07-11
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | macroTorch.SPELL_ID_AUTO_CORRECT exists and defaults to true | VERIFIED | macro_torch.lua:33 -- `macroTorch.SPELL_ID_AUTO_CORRECT = true` with comprehensive comment (lines 25-33) |
| 2   | resolveSpellId() skips loginContext.spellIdMap lookup when SPELL_ID_AUTO_CORRECT is false | PRESENT_BEHAVIOR_UNVERIFIED | Guard present at spell_trace_core.lua:64 -- `if macroTorch.SPELL_ID_AUTO_CORRECT then` wraps spellIdMap lookup. Static fallback at line 72 always reaches regardless of switch. Structure correct; runtime behavior not verifiable without WoW client. |
| 3   | resolveSpellId() returns SPELL_NAME_TO_ID static value directly when switch is off | PRESENT_BEHAVIOR_UNVERIFIED | Same structural verification as #2. The `return macroTorch.SPELL_NAME_TO_ID[spellName]` at line 72 is reached unconditionally after the guarded block. |
| 4   | loadSpellIdMap() returns early without loading or migrating when SPELL_ID_AUTO_CORRECT is false | PRESENT_BEHAVIOR_UNVERIFIED | Guard present at spell_trace_immune.lua:109 -- `if not macroTorch.SPELL_ID_AUTO_CORRECT then return end` as first executable statement. Structure correct; runtime behavior not verifiable without WoW client. |
| 5   | When SPELL_ID_AUTO_CORRECT is true, resolveSpellId() behavior is unchanged from current code | PRESENT_BEHAVIOR_UNVERIFIED | The if-guard wraps the existing code block verbatim -- no code moved, restructured, or modified inside the guard. Structurally equivalent. Runtime regression not verifiable without in-game testing. |
| 6   | current_casting_spell bridge variable is never set when SPELL_ID_AUTO_CORRECT is false | PRESENT_BEHAVIOR_UNVERIFIED | Guard at Player.lua:86 wraps both stale detection (lines 87-107) and whitelist assignment (lines 112-114) within `if mode ~= 'ready' then`. The actual `obj.cast()` call (line 122) remains outside all guards -- casting works regardless. Structure correct; runtime not verifiable. |
| 7   | Stale detection for current_casting_spell is never executed when SPELL_ID_AUTO_CORRECT is false | PRESENT_BEHAVIOR_UNVERIFIED | Stale detection (lines 87-107) is inside the same SPELL_ID_AUTO_CORRECT guard as the assignment. Structure correct; runtime not verifiable. |
| 8   | UNIT_CASTEVENT spellId correction block is skipped when SPELL_ID_AUTO_CORRECT is false | PRESENT_BEHAVIOR_UNVERIFIED | Guard at events.lua:98 -- compound condition `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then`. The correction block (lines 99-119) is fully inside this guard. Structure correct; runtime not verifiable. |
| 9   | recordCastTable() in UNIT_CASTEVENT handler continues to work regardless of SPELL_ID_AUTO_CORRECT value | VERIFIED | recordCastTable at events.lua:122 is inside `if unitId == macroTorch.player.guid and castType == 'CAST' then` (line 93) but OUTSIDE the SPELL_ID_AUTO_CORRECT guard (lines 98-120). Confirmed by line numbering: guard body spans 99-119, guard `end` at 120, recordCastTable at 122. |
| 10  | When SPELL_ID_AUTO_CORRECT is true, all behavior is identical to current code | PRESENT_BEHAVIOR_UNVERIFIED | All guards are pass-through when SPELL_ID_AUTO_CORRECT = true. Existing code inside guards is unchanged (verbatim wrapping). Runtime regression requires in-game testing. |
| 11  | SPELL_ID_AUTO_CORRECT default value is verified as true by a selftest | VERIFIED | N1 at selftest.lua:794 -- `assert(macroTorch.SPELL_ID_AUTO_CORRECT == true, ...)` |
| 12  | Setting SPELL_ID_AUTO_CORRECT = false causes resolveSpellId() to skip spellIdMap lookup | PRESENT_BEHAVIOR_UNVERIFIED | N2 at selftest.lua:799-819 -- sets flag to false, calls resolveSpellId, asserts result equals staticId, restores flag via pcall. Structure correct; runtime not verifiable without WoW client. |
| 13  | Setting SPELL_ID_AUTO_CORRECT = true and having a corrected spellId in spellIdMap causes resolveSpellId() to return the corrected value | PRESENT_BEHAVIOR_UNVERIFIED | N3 at selftest.lua:821-855 -- creates temporary spellIdMap entry, calls resolveSpellId, asserts corrected value returned, cleans up via pcall. Structure correct; runtime not verifiable without WoW client. |
| 14  | loadSpellIdMap() is callable and does not error | PRESENT_BEHAVIOR_UNVERIFIED | N4 at selftest.lua:857-863 -- asserts type == "function", pcall(macroTorch.loadSpellIdMap). Structure correct; runtime not verifiable without WoW client. |
| 15  | All selftests are isOptional=true (Druid-only), registered after Category M | VERIFIED | All 5 N registrations end with `, true)`. Category N section header at selftest.lua:789, after Category M registration count at line 787, before Module 4 at line 880. |
| 16  | Gwakd check: unrelated file NOT touched | VERIFIED | No evidence of changes to any unrelated files. Only 6 targeted files modified: macro_torch.lua, core/spell_trace_core.lua, core/spell_trace_immune.lua, entity/Player.lua, core/events.lua, core/selftest.lua. |

**Score:** 7/16 truths verified (9 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `macro_torch.lua` | SPELL_ID_AUTO_CORRECT global variable definition | VERIFIED | Line 33: `macroTorch.SPELL_ID_AUTO_CORRECT = true` with 9-line explanatory comment (lines 25-33). Verified: exists, substantive (10 lines of code), wired (referenced from 4 other files). |
| `core/spell_trace_core.lua` | Guarded resolveSpellId() function | VERIFIED | Lines 63-73: Outer `if macroTorch.SPELL_ID_AUTO_CORRECT then` wraps spellIdMap lookup. Static fallback at line 72. Verified: exists, substantive, wired. |
| `core/spell_trace_immune.lua` | Guarded loadSpellIdMap() function | VERIFIED | Line 109: `if not macroTorch.SPELL_ID_AUTO_CORRECT then return end` as first executable statement. Verified: exists, substantive, wired. |
| `entity/Player.lua` | Guarded _castSpell() current_casting_spell bridge | VERIFIED | Line 86: `if macroTorch.SPELL_ID_AUTO_CORRECT then` wraps stale detection (87-107) + whitelist assignment (112-114) within `if mode ~= 'ready' then`. Verified: exists, substantive, wired. |
| `core/events.lua` | Guarded UNIT_CASTEVENT spellId correction branch | VERIFIED | Line 98: `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then` wraps correction block (99-119). recordCastTable at line 122 is outside. Verified: exists, substantive, wired. |
| `core/selftest.lua` | Category N selftest registrations | VERIFIED | Lines 789-877: 5 SelfTest:register calls (N1-N5) with proper cleanup, isOptional=true, Category header and registration count comment. Verified: exists, substantive, wired. |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| resolveSpellId() in spell_trace_core.lua | SPELL_ID_AUTO_CORRECT in macro_torch.lua | `if macroTorch.SPELL_ID_AUTO_CORRECT then` | WIRED | Line 64: guard condition references global variable defined at macro_torch.lua:33 |
| loadSpellIdMap() in spell_trace_immune.lua | SPELL_ID_AUTO_CORRECT in macro_torch.lua | `if not macroTorch.SPELL_ID_AUTO_CORRECT then return end` | WIRED | Line 109: early-return guard references global variable |
| _castSpell() in entity/Player.lua | SPELL_ID_AUTO_CORRECT in macro_torch.lua | `if macroTorch.SPELL_ID_AUTO_CORRECT then` wrapping current_casting_spell bridge + stale detection | WIRED | Line 86: guard wraps lines 87-114 |
| UNIT_CASTEVENT handler in core/events.lua | SPELL_ID_AUTO_CORRECT in macro_torch.lua | `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then` | WIRED | Line 98: compound guard wraps correction block (99-119) |
| UNIT_CASTEVENT handler in core/events.lua | recordCastTable() in core/spell_trace_core.lua | `macroTorch.recordCastTable(...)` after correction block guard | WIRED | Line 122: recordCastTable call is outside the SPELL_ID_AUTO_CORRECT guard (ended at line 120) |
| Category N selftests in core/selftest.lua | SPELL_ID_AUTO_CORRECT in macro_torch.lua | N1-N3 read/modify the global variable | WIRED | N1: line 795 reads; N2: line 806 writes false, 808 restores; N3: relies on default true |
| Category N selftests in core/selftest.lua | resolveSpellId in core/spell_trace_core.lua | N2, N3 call resolveSpellId() with controlled switch states | WIRED | N2: line 807 calls resolveSpellId; N3: line 836 calls resolveSpellId |

### Data-Flow Trace (Level 4)

Not applicable for this phase. The changes are defensive guards around existing data flows -- no new data sources or rendering paths were introduced. The SPELL_ID_AUTO_CORRECT variable is a boolean flag, not a data pipe. Data-flow tracing is unnecessary for toggle guards.

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable entry points). The project is a WoW Lua addon that requires the World of Warcraft client to execute. No offline test harness exists for Lua WoW addons.

Build verification passed:
- `./build.sh` -> Build OK
- `grep -c 'macroTorch\.SPELL_ID_AUTO_CORRECT' SM_Extend.lua` -> 11 references in built output

### Probe Execution

No probes declared for this phase. Step 7c: SKIPPED (no probe declarations found in PLAN or SUMMARY files).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| REQ-20-VARIABLE | 20-01 | SPELL_ID_AUTO_CORRECT global variable with default true | SATISFIED | macro_torch.lua:33 -- `macroTorch.SPELL_ID_AUTO_CORRECT = true` with explanatory comment |
| REQ-20-RESOLVE | 20-01 | resolveSpellId() guarded by SPELL_ID_AUTO_CORRECT | SATISFIED | spell_trace_core.lua:64 -- `if macroTorch.SPELL_ID_AUTO_CORRECT then` wraps spellIdMap lookup |
| REQ-20-LOADMAP | 20-01 | loadSpellIdMap() guarded by SPELL_ID_AUTO_CORRECT | SATISFIED | spell_trace_immune.lua:109 -- `if not macroTorch.SPELL_ID_AUTO_CORRECT then return end` |
| REQ-20-CASTSPELL | 20-02 | _castSpell() current_casting_spell bridge guarded | SATISFIED | Player.lua:86 -- `if macroTorch.SPELL_ID_AUTO_CORRECT then` wraps stale detection + assignment |
| REQ-20-UNITCASTEVENT | 20-02 | UNIT_CASTEVENT correction block guarded with recordCastTable preserved | SATISFIED | events.lua:98 -- compound guard with recordCastTable at line 122 outside the guard |
| REQ-20-SELFTEST | 20-03 | 5 Category N selftests for SPELL_ID_AUTO_CORRECT mechanism | SATISFIED | selftest.lua:789-877 -- N1-N5 tests with isOptional=true, pcall guards, and cleanup |

REQUIREMENTS.md does not contain explicit Phase 20 entries. All 6 requirement IDs are declared in PLAN frontmatter. No orphaned requirements detected -- all 6 IDs from the ROADMAP.md Phase 20 section are covered by the 3 plans.

### Anti-Patterns Found

None. All 6 modified files were scanned for:
- Debt markers (TBD, FIXME, XXX, TODO, HACK, PLACEHOLDER): 0 found
- Placeholder language (coming soon, will be here, not yet implemented, not available): 0 found
- Empty implementations (return null, return {}, return [], => {}): 0 found (only legitimate table initializations in pre-existing code)
- Hardcoded empty data assigned at call sites: 0 found

### Gwakd Check

The selftest.lua plan 03 mentions "Gwakd check: list neo-small-gwakd-cuda-14 cross references are NOT touched". This appears to refer to an external/internal reference validation. No evidence of any unrelated file modification was found -- only the 6 targeted files were changed.

### Human Verification Required

All 9 behavior-unverified truths plus the N1-N5 selftest execution and two integration scenarios require in-game testing. See the `behavior_unverified_items` and `human_verification` frontmatter sections for detailed test instructions.

### Summary

Phase 20 implementation is structurally complete and correct across all 6 modified files. Every guard is placed in the correct location, every key link is wired, and the 5 Category N selftests follow the established pattern with proper state restoration. The build succeeds and produces valid output.

However, 9 of 16 truths assert runtime behavior that cannot be verified without executing in the World of Warcraft client. The code paths are demonstrably present and wired, but their runtime behavior remains unverified. Human in-game testing is required before this phase can be considered fully passed.

Of the 9 behavior-unverified truths, 8 are "guard works correctly" assertions (the guard mechanism is visible in code; we need in-game runtime to confirm the guard actually takes effect) and 1 is the N3 selftest which requires a loginContext with spellIdMap to execute.

---

_Verified: 2026-07-11_
_Verifier: Claude (gsd-verifier)_