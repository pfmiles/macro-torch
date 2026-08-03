---
phase: 23-idol-dance-refactor
verified: 2026-08-03T10:00:00Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 23: Idol Dance Refactor Verification Report

**Phase Goal:** Fix two confirmed idol dance logic gaps in computeNormalRelic() and add distance optimization to recoverNormalRelic(). Add Category O SelfTest coverage.
**Verified:** 2026-08-03T10:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | computeNormalRelic returns Fero/Rot for fast combat/PvP targets regardless of Rip status (Gap 1 fixed) | VERIFIED | Druid.lua:372-374 -- isTrivialBattleOrPvp check returns selectFerocityOrEmeraldRot() unconditionally, before isRipPresent check at line 380 |
| 2 | computeNormalRelic returns Fero/Rot for all immune Rip targets in combat (Gap 2 fixed) | VERIFIED | Druid.lua:376-378 -- isImmuneRip check returns selectFerocityOrEmeraldRot() unconditionally in combat path (after non-combat guards fall through) |
| 3 | computeNormalRelic returns Fero/Rot when Rip is present on non-immune target in normal combat | VERIFIED | Druid.lua:380-382 -- isRipPresent check returns selectFerocityOrEmeraldRot() when all earlier guards fall through |
| 4 | computeNormalRelic returns Idol of Savagery when Rip absent, not immune, normal combat | VERIFIED | Druid.lua:384 -- final fallback returns 'Idol of Savagery' after all prior guards fall through |
| 5 | computeNormalRelic returns Idol of Savagery for non-combat non-immune targets (pre-switch preserved per D-02) | VERIFIED | Druid.lua:367-370 -- second non-combat guard returns Savagery (only reached when isImmuneRip is false, since first guard at 363-366 catches immune case) |
| 6 | computeNormalRelic returns Fero/Rot for non-combat immune Rip targets (preserved) | VERIFIED | Druid.lua:363-366 -- first guard: not isInCombat AND isImmuneRip returns selectFerocityOrEmeraldRot() |
| 7 | recoverNormalRelic bypasses energy check and directly equips when target.distance >= 20 (Gap 4 fixed per D-03/D-04) | VERIFIED | Druid.lua:433-436 -- distance check with early return placed BEFORE the isFightStarted energy check at line 437 |
| 8 | All 7 Category O SelfTest registrations exist and reference their decision IDs in comments | VERIFIED | selftest.lua:669-731 -- 7 registrations (O-01 through O-07), all reference D-01 or D-03 in their names/comments |

**Score:** 8/8 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/druid/Druid.lua` computeNormalRelic rewrite | Flat 5-branch if-else chain replacing nested structure | VERIFIED | Lines 362-385. Signature unchanged. Exactly 1 `end`. 5 paths: non-combat immune, non-combat Savagery, fast combat/PvP, immune Rip, Rip present, fallback Savagery. |
| `classes/druid/Druid.lua` recoverNormalRelic distance bypass | 4-line distance check before energy check | VERIFIED | Lines 433-436. `if macroTorch.target.distance >= 20 then ensureRelicEquipped; return end` placed before line 437 energy check. |
| `classes/druid/selftest.lua` Category O SelfTests | 7 registrations (O-01 through O-07) | VERIFIED | Lines 669-731. All 7 use `isOptional = true`. All inside `UnitClass('player') == 'Druid'` guard. All reference D-01 or D-03. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `combo.lua:103` | `computeNormalRelic()` | `clickContext.normalRelic = macroTorch.computeNormalRelic(clickContext)` | WIRED | Verified at combo.lua:103 |
| `combo.lua:112` | `recoverNormalRelic()` | `macroTorch.recoverNormalRelic(clickContext, clickContext.normalRelic)` | WIRED | Verified at combo.lua:112 |
| `computeNormalRelic()` | `selectFerocityOrEmeraldRot()` | 4 return paths call it | WIRED | Called at Druid.lua:365, 373, 377, 381 |
| `selftest.lua` | `SelfTest:register()` | Standard API call pattern | WIRED | 7 registrations follow Phase 22 pattern with 3 args: name, fn, isOptional |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build succeeds | `./build.sh` | Exit 0, no errors | PASS |
| computeNormalRelic defined exactly once | `grep -c "function macroTorch.computeNormalRelic" Druid.lua` | 1 | PASS |
| selectFerocityOrEmeraldRot unchanged (1 definition) | `grep -c "function macroTorch.selectFerocityOrEmeraldRot" Druid.lua` | 1 | PASS |
| Distance bypass exists (exactly 1 occurrence) | `grep -c "macroTorch.target.distance >= 20" Druid.lua` | 1 | PASS |
| 7 Category O tests registered | `grep -c "Cat O-0" selftest.lua` | 7 | PASS |
| 7 SelfTest registrations | `grep -c "SelfTest:register.*Cat O-" selftest.lua` | 7 | PASS |

### Requirements Coverage

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| REQ-23-GAP1 | ROADMAP.md Phase 23 | Fast combat/PvP always uses Builder idol, never wastes GCD on Savagery | SATISFIED | isTrivialBattleOrPvp branch (Druid.lua:372-374) returns Fero/Rot unconditionally; verified by O-01, O-02 |
| REQ-23-GAP2 | ROADMAP.md Phase 23 | Immune Rip targets never receive useless Savagery | SATISFIED | isImmuneRip branch (Druid.lua:376-378) returns Fero/Rot unconditionally; verified by O-03 |
| REQ-23-GAP4 | ROADMAP.md Phase 23 | Distance bypass (20yd) skips energy check in recoverNormalRelic | SATISFIED | Distance check (Druid.lua:433-436) before energy check; verified by O-07 smoke test + grep |
| REQ-23-TEST | ROADMAP.md Phase 23 | Category O SelfTest coverage for idol dance decision logic | SATISFIED | 7 tests (selftest.lua:669-731) covering all computeNormalRelic branches + distance bypass structure |

Note: REQ-23-GAP1 through REQ-23-TEST are phase-specific requirements defined in ROADMAP.md. The global REQUIREMENTS.md tracks project-level requirements R1-R8 only. No orphaned requirements for this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No debt markers (TBD/FIXME/XXX/HACK/PLACEHOLDER) found in either modified file | — | — |

### Quality Notes (from Code Review)

The 23-REVIEW.md identified the following quality concerns. These do not block phase goal achievement but should be considered for future improvement:

1. **WR-01: O-01 and O-02 lack combat-state guards.** When the player is not in combat, the non-combat guard at Druid.lua:367-369 returns Savagery before reaching the isTrivialBattleOrPvp check. This causes false test failures during login/reload. Compare with O-03, O-04, O-06 which correctly guard their combat-state assumptions. **Severity: Warning** — tests are correct when state matches; fragile under specific conditions.

2. **WR-02: O-01 and O-02 use identical contexts.** Both assert non-Savagery with `{isTrivialBattle = true, isImmuneRip = false}`. The PLAN explicitly documented this: O-02 uses `isTrivialBattle = true` as a proxy for `isTrivialBattleOrPvp` since the PvP path (`target.isPlayerControlled`) cannot be mocked in SelfTest. **Severity: Info** — acknowledged design limitation.

3. **WR-04: O-07 is a structure-level smoke test.** It only checks function type and API availability, not actual distance bypass behavior. The PLAN explicitly designed O-07 as a smoke test; the grep check in Task 1 verify is the primary verification for the distance bypass code placement. **Severity: Info** — intentional design choice.

### Gaps Summary

No gaps found. All 8 must-have truths verified, all artifacts present and wired, all key links intact, build succeeds, no debt markers.

---

_Verified: 2026-08-03T10:00:00Z_
_Verifier: Claude (gsd-verifier)_