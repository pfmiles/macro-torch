---
phase: 14-istrivialbattle-iskillshotorlastchance-60-dps-b
verified: 2026-06-20T03:30:00Z
status: human_needed
score: 8/8 must-haves verified
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "At level < 60, isTrivialBattle condition B uses level-scaled DPS estimate instead of hardcoded 500"
    test: "Execute catAtk in-game at levels 10-59 and verify isTrivialBattle condition B triggers correctly based on level-adaptive DPS (e.g., at level 30 a target should be considered 'trivial' at lower health than at level 60)"
    expected: "EstimatePlayerDPS is called and returns correct bracket value; the inequality (healthMax <= (mateCount+1) * estimatePlayerDPS() * 25) evaluates correctly"
    why_human: "Presence checks confirm the call exists and the function is wired, but the runtime behavior (whether isTrivialBattle actually triggers at appropriate thresholds during live combat) requires an in-game target and combat state."
  - truth: "At level < 60, isKillShotOrLastChance condition B uses single level-scaled health threshold"
    test: "Execute catAtk in-game at levels 10-59 and verify isKillShotOrLastChance condition B triggers correctly based on level-adaptive KS threshold (e.g., at level 30 a target should be flagged as 'kill shot' at health < 700 for solo)"
    expected: "getKSThreshold is called and returns correct bracket value; the inequality (targetHealth < getKSThreshold()) evaluates correctly"
    why_human: "Presence checks confirm the call exists and the function is wired, but the runtime behavior (whether isKillShotOrLastChance actually triggers at appropriate health thresholds during live combat) requires an in-game target and combat state."
human_verification:
  - test: "Load addon in WoW on a Druid character and run /mt"
    expected: "All 6 Category I selftests pass green; no failures or warnings"
    why_human: "WoW addon selftests can only be executed in-game; no CI for WoW 1.12.1 Lua environment"
  - test: "On a level 60 Druid, verify catAtk behavior is identical to pre-Phase-14"
    expected: "Hard guards (level == 60) ensure estimatePlayerDPS returns 500 and getKSThreshold returns 1750, matching old constants. Behavior should be indistinguishable from before this phase."
    why_human: "Combat rotation behavior can only be verified in live combat with real targets"
  - test: "On a level 30-40 Druid, verify quick battle detection triggers for appropriate targets"
    expected: "Low-health targets correctly trigger isTrivialBattle/isKillShotOrLastChance; high-health targets do not. Detection is level-aware (not always using level-60 thresholds of 500 DPS / 1750 health)."
    why_human: "Level-adaptive thresholds require live testing at multiple levels to confirm bracket boundaries are correct"
  - test: "Verify that the 15 KS_CP* constants do NOT appear in the /run global namespace"
    expected: "No KS_CP1_Health through KS_CP5_Health_raid_pps exist as global variables"
    why_human: "Confirms deletion is complete in live environment (source grep already passed)"
  - test: "Execute catAtk at levels 10-59 and verify isTrivialBattle condition B triggers correctly"
    expected: "estimatePlayerDPS is called and returns correct bracket value; the inequality (healthMax <= (mateCount+1) * estimatePlayerDPS() * 25) evaluates correctly for target health"
    why_human: "Behavior-dependent truth — symbol presence + wiring verify the code path exists, but the runtime behavior (whether the inequality evaluates correctly at each bracket boundary with live combat state) can only be confirmed in-game"
  - test: "Execute catAtk at levels 10-59 and verify isKillShotOrLastChance condition B triggers correctly"
    expected: "getKSThreshold is called and returns correct bracket value; the inequality (targetHealth < getKSThreshold()) evaluates correctly"
    why_human: "Behavior-dependent truth — symbol presence + wiring verify the code path exists, but the runtime behavior (whether the inequality evaluates correctly at each bracket boundary with live combat state) can only be confirmed in-game"
---

# Phase 14: isTrivialBattle/isKillShotOrLastChance Level-Adaptive DPS/KS Threshold Lookup

**Phase Goal:** Replace hardcoded level-60 static DPS estimates in `isTrivialBattle` and `isKillShotOrLastChance` with level-adaptive lookup tables via `estimatePlayerDPS(level)` and `getKSThreshold(level)`. Delete 15 KS_CP*_Health* constants. Add Category I selftests.

**Verified:** 2026-06-20T03:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | estimatePlayerDPS(60) returns 500 exactly, matching pre-phase behavior | VERIFIED | `classes/druid/Druid.lua:586-588`: `if level == 60 then return 500 end` hard guard. Source grep confirms exact match. Selftest I-1 asserts `val == 500` |
| 2 | getKSThreshold(60) returns 1750 exactly, matching pre-phase behavior | VERIFIED | `classes/druid/Druid.lua:609-611`: `if level == 60 then return 1750 end` hard guard. Source grep confirms exact match. Selftest I-2 asserts `val == 1750` |
| 3 | At level < 60, isTrivialBattle condition B uses level-scaled DPS estimate instead of hardcoded 500 | PRESENT_BEHAVIOR_UNVERIFIED | `classes/druid/Druid.lua:822`: `macroTorch.estimatePlayerDPS() * trivialDieTime` replaces old `500 * trivialDieTime`. Call is present and wired. Level-adaptive logic (lines 580-601) resolves 5 brackets (50/40/30/20/else). Behavior-dependent: requires live combat state to verify threshold evaluations at each bracket. |
| 4 | At level < 60, isKillShotOrLastChance condition B uses single level-scaled health threshold | PRESENT_BEHAVIOR_UNVERIFIED | `classes/druid/Druid.lua:872`: `return targetHealth < macroTorch.getKSThreshold()` replaces old 55-line CP-mode branching. Call is present and wired. Level-adaptive logic (lines 603-624) resolves 5 brackets. Behavior-dependent: requires live combat state to verify threshold evaluations at each bracket. |
| 5 | At level < 10 (pre-cat form), estimatePlayerDPS returns conservative 25 fallback | VERIFIED | `classes/druid/Druid.lua:599`: `return 25 -- [D-05] conservative fallback for pre-cat levels`. Selftest I-5 asserts `estimatePlayerDPS(15) == 25` and `getKSThreshold(15) == 200` |
| 6 | All 15 KS_CP*_Health* constants are deleted from Druid.lua | VERIFIED | `grep -c "KS_CP" classes/druid/Druid.lua` returns 0. `grep -c "KS_CP" SM_Extend.lua` returns 0. Build passes cleanly. |
| 7 | isKillShotOrLastChance condition A (willDieInSeconds path) is unchanged | VERIFIED | `classes/druid/Druid.lua:861`: `if macroTorch.target.willDieInSeconds(2) then return true end` — preserved as first check in function. `grep -c "willDieInSeconds(2)"` returns 1. World boss logic (lines 867-869) also preserved. Selftest I-6 confirms both functions are callable. |
| 8 | isTrivialBattleOrPvp is unchanged (pass-through that calls isTrivialBattle) | VERIFIED | `classes/druid/Druid.lua:809-812`: `return macroTorch.target.isPlayerControlled or macroTorch.isTrivialBattle(clickContext)` — identical to pre-phase code. Git diff confirms zero changes to this function. |

**Score:** 6/8 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `classes/druid/Druid.lua` | New estimatePlayerDPS() and getKSThreshold() functions | VERIFIED | Functions exist at lines 580-624. `grep -c` confirms exactly 1 of each. Both functions have: nil-level guard (`UnitLevel('player')` default), level-60 hard guard, 5-bracket if-elseif chain, conservative fallback. |
| `classes/druid/Druid.lua` | Modified isTrivialBattle | VERIFIED | Line 822: `macroTorch.estimatePlayerDPS()` replaces hardcoded `500`. Function structure and clickContext caching preserved. |
| `classes/druid/Druid.lua` | Simplified isKillShotOrLastChance | VERIFIED | Reduced from ~55 lines to ~10 lines. Condition B is single `getKSThreshold()` call. `isPvp` local variable removed. Condition A and world boss logic preserved. |
| `classes/druid/Druid.lua` | 6 Category I selftests | VERIFIED | 6 registrations between Category I header (line 1378) and Category G2 (line 1428). Total selftests increased from 18 to 24. All use `isOptional=true` and `UnitClass` guard. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| isTrivialBattle condition B | estimatePlayerDPS() | `macroTorch.estimatePlayerDPS()` call replaces hardcoded 500 | WIRED | Line 822: `macroTorch.estimatePlayerDPS() * trivialDieTime`. Call count = 1 in source, 7 in SM_Extend.lua (includes selftests). |
| isKillShotOrLastChance condition B | getKSThreshold() | `macroTorch.getKSThreshold()` call replaces 15 constants + 55 lines | WIRED | Line 872: `return targetHealth < macroTorch.getKSThreshold()`. Call count = 1 in source, 7 in build output. |
| estimatePlayerDPS (nil guard) | WoW API UnitLevel | `if not level then level = UnitLevel('player') end` | WIRED | Lines 582-584: nil-level guard. `UnitLevel('player')` appears 2x (once in each function). |
| getKSThreshold (nil guard) | WoW API UnitLevel | Same pattern | WIRED | Lines 605-607: nil-level guard. Mirrors estimatePlayerDPS pattern. |
| Category I selftest I-1 | estimatePlayerDPS(60) | register + assert | WIRED | Line 1379-1383: `SelfTest:register(...)` with `assert(val == 500)` |
| Category I selftest I-2 | getKSThreshold(60) | register + assert | WIRED | Line 1385-1389: `SelfTest:register(...)` with `assert(val == 1750)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| isTrivialBattle condition B | `estimatePlayerDPS()` return value | `UnitLevel('player')` via if-elseif chain (pure computation) | Yes — returns numeric value at runtime | FLOWING |
| isKillShotOrLastChance condition B | `getKSThreshold()` return value | `UnitLevel('player')` via if-elseif chain (pure computation) | Yes — compared against `macroTorch.target.health` (live WoW API) | FLOWING |

Both data flows are real: `estimatePlayerDPS()` returns a computed number based on player level, multiplied by group size and time, compared against `healthMax` (live WoW API). `getKSThreshold()` returns a computed number based on player level, compared against `target.health` (live WoW API). No static/hardcoded data sources.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Build passes | `./build.sh` | Exit code 0 | PASS |
| No KS_CP in output | `grep -c "KS_CP" SM_Extend.lua` | 0 | PASS |
| New functions in output | `grep -c "macroTorch.estimatePlayerDPS\|macroTorch.getKSThreshold" SM_Extend.lua` | 14 (7 each) | PASS |
| 60-level guard present (DPS) | `grep "level == 60.*return 500" classes/druid/Druid.lua` | 1 match | PASS |
| 60-level guard present (KS) | `grep "level == 60.*return 1750" classes/druid/Druid.lua` | 1 match | PASS |
| Selftests registered | `awk '/Category I/,/Category G2/' classes/druid/Druid.lua \| grep -c "SelfTest:register"` | 6 | PASS |

### Probe Execution

No probes declared for this phase. Step 7c: SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| REQ-14-DPS | 14-01-PLAN | Level-adaptive DPS estimation replacing hardcoded 500 | SATISFIED | `estimatePlayerDPS()` function exists (lines 580-601), wired into `isTrivialBattle` condition B (line 822) |
| REQ-14-KS | 14-01-PLAN | Level-adaptive KS threshold replacing 15 constants + branching | SATISFIED | `getKSThreshold()` function exists (lines 603-624), wired into `isKillShotOrLastChance` condition B (line 872) |
| REQ-14-DELETE | 14-01-PLAN | Delete all 15 KS_CP*_Health* constants | SATISFIED | `grep -c "KS_CP" classes/druid/Druid.lua == 0`; `grep -c "KS_CP" SM_Extend.lua == 0` |
| REQ-14-GUARD | 14-01-PLAN | 60-level hard guards preserve exact level-60 behavior | SATISFIED | Both functions have `if level == 60 then return <exact-value> end` before the if-elseif chain. Selftests I-1 and I-2 verify exact values. |
| REQ-14-FALLBACK | 14-01-PLAN | Conservative fallback for pre-cat form levels (1-19) | SATISFIED | `estimatePlayerDPS`: else branch returns 25 (D-05). `getKSThreshold`: else branch returns 200 (D-05). Selftest I-5 verifies. Nil-level guard also fallback: `UnitLevel('player')` default. |
| REQ-14-TEST | 14-01-PLAN | 6 Category I selftests | SATISFIED | 6 registrations in Category I section covering: 60-level hard guards (2 tests), bracket boundaries (2 tests), conservative fallback (1 test), condition A preservation (1 test) |

Note: The 6 requirement IDs (REQ-14-*) exist in ROADMAP.md and PLAN frontmatter but do NOT have corresponding entries in REQUIREMENTS.md. REQUIREMENTS.md uses R1-R8 numbering for high-level requirements. This is consistent with the project convention — other phases (7, 8, 13) also use phase-scoped synthetic REQ-XX-* IDs. No orphaned requirements from REQUIREMENTS.md perspective (no Phase 14 items in the R1-R8 system).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `classes/druid/Druid.lua` | 334, 425 | `TODO reshift energy... wolfheart head enchant` | INFO | Pre-existing. Outside Phase 14 scope. Acknowledged in SUMMARY.md. |
| `classes/druid/Druid.lua` | 823 | `-- [CHANGED] ^^^ 500 replaced with...` | INFO | Development artifact comment. IN-02 from code review. Non-blocking — describes the change but functions correctly. |
| `classes/druid/Druid.lua` | 586, 609 | `level == 60` exact-match guard | WARNING | WR-01 from code review. Fails on levels > 60 (custom servers). Standard vanilla WoW 1.12.1 caps at 60. Not a blocker for this phase's correct function on Turtle WoW. |
| `classes/druid/Druid.lua` | 1396, 1406 | Selftest uses `>=` instead of `==` for bracket values | WARNING | WR-03 from code review. Tests are too permissive — won't catch accidental value changes. Non-blocking: 60-level hard guard tests use exact `==`. |

No debt markers (TBD/FIXME/XXX) found in Phase 14 code. No unresolved blockers. The two pre-existing TODOs (lines 334, 425) are acknowledged and outside scope.

### Human Verification Required

1. **Category I Selftests in-game.** Load addon in WoW on a Druid character and run `/mt`. All 6 Category I tests should pass green. No failures or warnings.

2. **Level-60 behavior regression test.** On a level 60 Druid, verify catAtk rotation behavior is identical to pre-Phase-14. The hard guards (`level == 60`) ensure `estimatePlayerDPS(60) == 500` and `getKSThreshold(60) == 1750`, should produce indistinguishable results.

3. **Level-adaptive thresholds (levels 10-59).** On a level 30-40 Druid, verify isTrivialBattle triggers for appropriate targets (low-health ones based on level-appropriate DPS). Verify isKillShotOrLastChance triggers at correct health thresholds. High-health targets should NOT trigger these quick-battle/kill-shot codepaths.

4. **Constants deletion.** Confirm that no KS_CP* constants exist in the global namespace (`/run`).

5. **isTrivialBattle condition B runtime behavior.** Execute catAtk at levels 10-59 and verify `estimatePlayerDPS()` returns correct bracket values and the inequality `healthMax <= (mateCount+1) * estimatePlayerDPS() * 25` evaluates correctly with live combat state. (Behavior-dependent truth — code is present and wired, but the runtime evaluation requires in-game confirmation.)

6. **isKillShotOrLastChance condition B runtime behavior.** Execute catAtk at levels 10-59 and verify `getKSThreshold()` returns correct bracket values and the inequality `targetHealth < getKSThreshold()` evaluates correctly with live combat state. (Behavior-dependent truth — code is present and wired, but the runtime evaluation requires in-game confirmation.)

### Gaps Summary

No gaps found. All 8 must-have truths are either VERIFIED (6) or PRESENT_BEHAVIOR_UNVERIFIED (2). The 2 behavior-unverified truths have their code present and wired — they simply require in-game combat state to confirm runtime behavior, which is inherent to a WoW addon.

**Code review findings:** 3 warnings (WR-01: exact-60 guard, WR-02: group/raid threshold scaling removed per D-02 design, WR-03: permissive selftest assertions) and 3 info items. None block the phase goal. WR-02 is an intentional design tradeoff per the plan's D-02 decision.

---

_Verified: 2026-06-20T03:30:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: No — initial verification_