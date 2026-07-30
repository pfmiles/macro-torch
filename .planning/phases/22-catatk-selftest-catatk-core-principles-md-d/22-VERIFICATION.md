---
phase: 22-catatk-selftest-catatk-core-principles-md-d
verified: 2026-07-31T00:00:00Z
status: human_needed
score: 16/16 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 22: catAtk 质量保障 — SelfTest 回归测试 + 原则文档补充 Verification Report

**Phase Goal:** 基于 `catAtk-core-principles.md` 的 14 条设计原则，为 `catAtk()` 及其子模块建立 ~38 个 SelfTest 回归测试用例（Batch 1: ~10 pure function tests + Batch 2: ~28 conditional decision tests），附带修正 `catAtk-core-principles.md` 附录 D Rule 13 命名不一致（`isInfiniteEnergy` → `isPseudoInfiniteEnergy`）。所有测试在游戏客户端内通过 `/mt` 执行，利用 `clickContext` 预设值绕过游戏状态依赖。零行为变更，纯质量基础设施。

**Verified:** 2026-07-31
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SelfTest:register calls exist for PF-01 through PF-07 pure-function tests | VERIFIED | 7 registrations at lines 23-89: PF-01 through PF-07 covering computeReshiftEnergy, estimatePlayerDPS, computeErps |
| 2 | SelfTest:register calls exist for R9-01 through R9-03 kill-shot threshold tests | VERIFIED | 3 registrations at lines 93-106: R9-01 through R9-03 covering getKSThreshold |
| 3 | SelfTest:register calls exist for all R2-01 through R2-07 reshift decision tests | VERIFIED | 7 registrations at lines 114-212: R2-01 through R2-07 covering shouldDoReshift |
| 4 | SelfTest:register calls exist for all R4-01 through R4-04 and R5-01 through R5-04 bleed primacy tests | VERIFIED | 8 registrations at lines 216-324: R4-01\~04, R5-01\~04 covering shouldCastRip |
| 5 | SelfTest:register calls exist for all R6-01 through R6-06 builder choice tests | VERIFIED | 6 registrations at lines 328-418: R6-01\~06 covering shouldUseShred |
| 6 | SelfTest:register calls exist for all R7-01 through R7-06 bite decision tests | VERIFIED | 6 registrations at lines 422-482: R7-01\~06 covering shouldUseBite |
| 7 | SelfTest:register calls exist for all R8-01 through R8-06 FF fill tests | VERIFIED | 6 registrations at lines 486-581: R8-01\~06 covering shouldCastFFDuringWaitWindow |
| 8 | All Batch 1 tests use UnitClass('player') == 'Druid' guard with isOptional=true | VERIFIED | Single guard at line 19 wraps all 43 tests; all 43 use `, true)` as third arg (= isOptional); zero `isOptional = false` |
| 9 | computeReshiftEnergy tests (PF-01\~03) use conditional skip when Furor==0 and no Wolfsheart | VERIFIED | PF-01 guard: `Furor ~= 0 or has Wolfsheart then return` (correct inverted Pattern C); PF-02: `Furor ~= 5 or no Wolfsheart`; PF-03: `Furor ~= 3 or has Wolfsheart` |
| 10 | catAtk-core-principles.md Appendix D Rule 13 reads isPseudoInfiniteEnergy (not isInfiniteEnergy) | VERIFIED | Line 458: `isPseudoInfiniteEnergy`; grep `isInfiniteEnergy` returns 0 matches |
| 11 | build_order.txt contains classes/druid/selftest.lua after classes/druid/combo.lua | VERIFIED | Line 33 after combo.lua (line 32), before diagnostics comment (line 34) |
| 12 | Game-dependent tests use conditional skip guards (Pattern C from CONTEXT.md) | VERIFIED | R2-02\~07, R4-01\~04, R5-01\~04, R7-01\~02, R8-02\~06 all have `player.isInCombat` or `isKillShotOrLastChance` or `isImmune` skip guards |
| 13 | All tests follow "Principle R\<n\>-\<nn\>: description" naming per D-03 | VERIFIED | All 43 tests match `Principle (PF|R\d)-\d\d` pattern |
| 14 | selftest.lua contains Batch 1 + Batch 2 tests, ordered by rule number 2->4->5->6->7->8 | VERIFIED | Batch 1 (PF-01\~07, R9-01\~03) → Batch 2 (R2-01\~07 → R4-01\~04 → R5-01\~04 → R6-01\~06 → R7-01\~06 → R8-01\~06) — confirmed by line-number grep |
| 15 | Zero behavior changes to existing functions | VERIFIED | `git diff e9d40be..HEAD --name-only` filtered: only `selftest.lua`, `build_order.txt`, and `.planning/` docs modified; zero production source files touched |
| 16 | Build succeeds: `./build.sh` produces valid SM_Extend.lua | VERIFIED | `./build.sh` exit code 0; no errors |

**Score:** 16/16 truths verified (all presence-based; no behavior-dependent truths at the must-have level)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/druid/selftest.lua` | Batch 1 (~10) + Batch 2 (~28) = ~38 SelfTest registrations, 250+ lines | VERIFIED | 584 lines, 43 registrations (exceeds ~38 estimate; see Note below). Apache 2.0 license header present. Both "End of Batch 1" and "End of Batch 2" markers. Single Druid guard block. |
| `build_order.txt` | selftest.lua inserted after combo.lua | VERIFIED | Line 33, after combo.lua (line 32), before diagnostics comment (line 34). 57 lines total (was 56, +1 correct). |
| `.planning/catAtk-core-principles.md` | Appendix D Rule 13: `isPseudoInfiniteEnergy` | VERIFIED | Line 458: `isPseudoInfiniteEnergy`; old `isInfiniteEnergy` zero matches. Also added SelfTest coverage table (lines 461-473). |

**Note on test count:** SUMMARY.md states ~38 originally estimated; actual delivered count is 43 (exceeds the estimate). This is because the Batch 2 task actions explicitly defined 33 tests (R2: 7, R4+5: 8, R6: 6, R7: 6, R8: 6), plus Batch 1's 10 (PF: 7 + R9: 3). The phase goal stated "~38" which was a floor estimate — 43 exceeds it.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `build_order.txt` | `classes/druid/selftest.lua` | build_order entry after `classes/druid/combo.lua` | WIRED | Line 33 after line 32; `./build.sh` succeeds |
| `classes/druid/selftest.lua` | `classes/druid/Druid.lua` (decision functions) | `macroTorch.shouldDoReshift\|shouldCastRip\|shouldUseBite\|shouldUseShred\|shouldCastFFDuringWaitWindow` | WIRED | 36 references found in selftest.lua |
| `classes/druid/selftest.lua` | `classes/druid/combo.lua` (energy fields) | `AUTO_TICK_ERPS\|CLAW_E\|SHRED_E\|BITE_E\|RIP_E\|RAKE_E\|TIGER_E` | WIRED | 42 references found in selftest.lua |
| `classes/druid/selftest.lua` | `classes/druid/Druid.lua` (pure functions) | `macroTorch.computeReshiftEnergy\|estimatePlayerDPS\|computeErps\|getKSThreshold` | WIRED | 24 references found in selftest.lua |
| `classes/druid/selftest.lua` | `classes/druid/Druid.lua` (helper functions) | `macroTorch.isKillShotOrLastChance\|getNextAbilityCost\|isTigerPresent` etc. | WIRED | 20 references found in selftest.lua |

### Data-Flow Trace (Level 4)

N/A — selftest.lua is a test file that constructs its own data (clickContext presets). No upstream data sources to trace. All test data is self-contained within the test functions.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build integrity | `./build.sh` | Exit 0, SM_Extend.lua generated | PASS |
| Lua syntax validity | `./build.sh` produces no Lua errors | No errors | PASS |
| In-game /mt execution | Cannot run outside WoW client | N/A | SKIP — requires human |

**Step 7b summary:** Only build-time checks are runnable. All 43 tests require WoW client execution. Behavioral verification is deferred to human testing.

### Probe Execution

No probes declared for this phase. The phase is a test-file creation phase with no migration scripts.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PF-01 | 22-02 SUMMARY | computeReshiftEnergy — 0 Furor + no Wolfsheart → 0 | SATISFIED | selftest.lua:23-27 |
| PF-02 | 22-02 SUMMARY | computeReshiftEnergy — Furor 5 + Wolfsheart → 60 | SATISFIED | selftest.lua:29-33 |
| PF-03 | 22-02 SUMMARY | computeReshiftEnergy — Furor 3 + no Wolfsheart → 24 | SATISFIED | selftest.lua:35-39 |
| PF-04 | 22-02 SUMMARY | estimatePlayerDPS(60) → 500 | SATISFIED | selftest.lua:41-44 |
| PF-05 | 22-02 SUMMARY | estimatePlayerDPS(40) → 200 | SATISFIED | selftest.lua:46-49 |
| PF-06 | 22-02 SUMMARY | computeErps no buffs → 10 | SATISFIED | selftest.lua:51-68 |
| PF-07 | 22-02 SUMMARY | computeErps +Tiger +Rake → 10+3.33+15 | SATISFIED | selftest.lua:70-89 |
| R2-01 | 22-02 SUMMARY | reshift energy 0 → false | SATISFIED | selftest.lua:114-117 |
| R2-02 | 22-02 SUMMARY | not in combat → false | SATISFIED | selftest.lua:119-124 |
| R2-03 | 22-02 SUMMARY | prowling → false | SATISFIED | selftest.lua:126-131 |
| R2-04 | 22-02 SUMMARY | OoC active → false | SATISFIED | selftest.lua:133-138 |
| R2-05 | 22-02 SUMMARY | kill shot phase → false | SATISFIED | selftest.lua:140-146 |
| R2-06 | 22-02 SUMMARY | 1.5s recovery sufficient → false | SATISFIED | selftest.lua:148-179 |
| R2-07 | 22-02 SUMMARY | 1.5s recovery insufficient → true | SATISFIED | selftest.lua:181-212 |
| R4-01 | 22-02 SUMMARY | 5CP + no Rip + normal → true | SATISFIED | selftest.lua:216-229 |
| R4-02 | 22-02 SUMMARY | 5CP + Rip present → false | SATISFIED | selftest.lua:231-242 |
| R4-03 | 22-02 SUMMARY | 5CP + immune Rip → false | SATISFIED | selftest.lua:244-255 |
| R4-04 | 22-02 SUMMARY | KillShot phase → false | SATISFIED | selftest.lua:257-268 |
| R5-01 | 22-02 SUMMARY | trivial 1CP no Rip → true | SATISFIED | selftest.lua:270-282 |
| R5-02 | 22-02 SUMMARY | trivial 2CP no Rip → true | SATISFIED | selftest.lua:284-296 |
| R5-03 | 22-02 SUMMARY | trivial 3CP → false (Bite) | SATISFIED | selftest.lua:298-310 |
| R5-04 | 22-02 SUMMARY | normal 3CP → false (need 5CP) | SATISFIED | selftest.lua:312-324 |
| R6-01 | 22-02 SUMMARY | 0 bleeds OoC behind → Shred | SATISFIED | selftest.lua:328-341 |
| R6-02 | 22-02 SUMMARY | 0 bleeds infinite behind → Shred | SATISFIED | selftest.lua:343-354 |
| R6-03 | 22-02 SUMMARY | 2 bleeds OoC behind → Shred | SATISFIED | selftest.lua:356-368 |
| R6-04 | 22-02 SUMMARY | 2 bleeds no OoC no infinite → Claw | SATISFIED | selftest.lua:370-380 |
| R6-05 | 22-02 SUMMARY | 3+ bleeds always Claw | SATISFIED | selftest.lua:382-393 |
| R6-06 | 22-02 SUMMARY | Rip absent normal → Claw | SATISFIED | selftest.lua:395-418 |
| R7-01 | 22-02 SUMMARY | KillShot + CP → true | SATISFIED | selftest.lua:422-427 |
| R7-02 | 22-02 SUMMARY | KillShot + 0 CP → false | SATISFIED | selftest.lua:429-434 |
| R7-03 | 22-02 SUMMARY | 5CP + Rip present + normal → true | SATISFIED | selftest.lua:436-447 |
| R7-04 | 22-02 SUMMARY | 5CP + immune Rip → true | SATISFIED | selftest.lua:449-458 |
| R7-05 | 22-02 SUMMARY | trivial 3CP no Rip → true | SATISFIED | selftest.lua:460-470 |
| R7-06 | 22-02 SUMMARY | trivial 2CP no Rip → false | SATISFIED | selftest.lua:472-482 |
| R8-01 | 22-02 SUMMARY | OoC active → false | SATISFIED | selftest.lua:486-490 |
| R8-02 | 22-02 SUMMARY | immune FF → false | SATISFIED | selftest.lua:492-497 |
| R8-03 | 22-02 SUMMARY | reshift pending → false | SATISFIED | selftest.lua:499-505 |
| R8-04 | 22-02 SUMMARY | energy sufficient → false | SATISFIED | selftest.lua:507-517 |
| R8-05 | 22-02 SUMMARY | wait < 1s → false | SATISFIED | selftest.lua:519-549 |
| R8-06 | 22-02 SUMMARY | wait >= 1s → true | SATISFIED | selftest.lua:551-581 |
| R9-01 | 22-02 SUMMARY | getKSThreshold(60) → 1750 | SATISFIED | selftest.lua:93-96 |
| R9-02 | 22-02 SUMMARY | getKSThreshold(50) → 725 | SATISFIED | selftest.lua:98-101 |
| R9-03 | 22-02 SUMMARY | getKSThreshold(15) → 100 | SATISFIED | selftest.lua:103-106 |

**ORPHANED requirements check:** REQUIREMENTS.md has no Phase 22 entries. No orphaned requirements detected.

### Anti-Patterns Found

None.

| Scan | Result |
|------|--------|
| Debt markers (TBD, FIXME, XXX) | 0 matches |
| Cleanup comments (TODO, HACK, PLACEHOLDER) | 0 matches |
| Empty implementations (return nil/{}] / => {}) | 0 matches |
| Placeholder text | 0 matches |
| Stub patterns (hardcoded empty data) | 0 detected — all 43 tests have concrete assertions with expected values |

### Minor Observations (Non-Blocking)

1. **Indentation inconsistency:** Batch 1 tests (lines 23-108) use 2-space indentation; Batch 2 tests (lines 110-583) use tab indentation. Both are consistent within their respective sections but differ across batches. This is cosmetic only — Lua is whitespace-insensitive.

2. **End-of-Batch-1 marker simplified:** Plan 22-01 specified `-- End of Batch 1 -- Batch 2 tests go below (added in plan 22-02)` but delivered `-- End of Batch 1` (line 108). The Batch 2 expansion comment is absent. This is a minor fidelity issue but does not affect correctness — Batch 2 tests were correctly appended after this marker.

3. **R6-05:R6-06 naming discrepancy:** R6-05 "3+ bleeds always Claw" and R6-06 "Rip absent → Claw for faster CP" are labeled as separate test IDs in the SUMMARY but the plan describes R6-06 as distinct. Verified correct: both exist with distinct assertions (lines 382-393 and 395-418).

### Human Verification Required

All 43 tests require in-game execution via `/mt` on a Druid character. The build (`./build.sh`) validates Lua syntax only. The following items must be verified by a human with a WoW Druid login:

#### 1. In-Game Test Execution

**Test:** Log in with a Druid character, type `/mt` in chat to run the SelfTest suite.
**Expected:** All 43 Principle PF-xx / Rxx-xx tests appear in chat output. Tests that cannot assert due to unmet preconditions should silently skip (Pattern C guards). No Lua errors.
**Why human:** Cannot execute WoW API-dependent Lua code outside the game client.

#### 2. PF-01~03 Conditional Skip Verification

**Test:** Log in with multiple Druid specs (different Furor talent ranks, with/without Wolfsheart equipped). Run `/mt`.
**Expected:** PF-01 runs (asserts `== 0`) only when Furor=0 and no Wolfsheart. PF-02 runs (asserts `== 60`) only when Furor=5 and Wolfsheart equipped. PF-03 runs (asserts `== 24`) only when Furor=3 and no Wolfsheart. All three silently skip when preconditions not met.
**Why human:** Talent and equipment state cannot be simulated outside WoW.

#### 3. R2-06/R2-07 Complementarity

**Test:** Enter combat on a Druid with RESHIFT_ENERGY > 0. Run `/mt` at different energy levels.
**Expected:** Exactly ONE of R2-06 or R2-07 asserts per run, depending on current `player.mana`. If projected 1.5s energy >= next ability cost → R2-06 asserts false (no reshift). If < → R2-07 asserts true (reshift). The other silently skips. Across multiple runs at varying energy levels, both tests should eventually assert.
**Why human:** `player.mana` is a live game-state value that changes during combat.

#### 4. R8-05/R8-06 Complementarity

**Test:** In combat with a Druid, run `/mt` at different energy levels.
**Expected:** Exactly ONE of R8-05 or R8-06 asserts per run. If wait time < 1s → R8-05 asserts false (no FF fill). If wait time >= 1s → R8-06 asserts true (FF fill). The other silently skips.
**Why human:** Same as R2-06/R2-07 — depends on live `player.mana`.

#### 5. Build Order Integrity

**Test:** In-game with a Druid, verify that `selftest.lua` is loaded after `combo.lua` (and thus after all catAtk functions are defined).
**Expected:** No "attempt to call nil" errors for `macroTorch.shouldDoReshift`, `macroTorch.computeErps`, etc. All 43 tests run without reference errors.
**Why human:** Load order validation requires in-game execution.

#### 6. Documentation Naming Fix (D-09)

**Test:** Review `.planning/catAtk-core-principles.md` Appendix D Rule 13.
**Expected:** Rule 13 reads `isPseudoInfiniteEnergy` — matching the Phase 21 rename. No occurrence of the old name `isInfiniteEnergy`.
**Why human:** Automated check confirms this is already correct (grepped: 1 match isPseudoInfiniteEnergy, 0 matches isInfiniteEnergy). This item is included for completeness but is already verified.

### Gaps Summary

No gaps found. All 16 must-have truths are verified on codebase presence. The 43 SelfTest registrations exist, are wired to the correct functions, follow the Principle naming convention, use isOptional=true, are guarded by a single Druid class check, and are correctly ordered by rule number. Build integrity (`./build.sh`) succeeds. Zero behavior changes to existing production code. The documentation fix (isInfiniteEnergy → isPseudoInfiniteEnergy) and build_order.txt insertion are correct.

Human verification is required for in-game `/mt` execution, which is inherent to WoW addon testing and cannot be automated in this environment.

---

_Verified: 2026-07-31T00:00:00Z_
_Verifier: Claude (gsd-verifier)_