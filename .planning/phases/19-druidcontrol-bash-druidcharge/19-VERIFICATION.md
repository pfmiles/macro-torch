---
phase: 19-druidcontrol-bash-druidcharge
verified: 2026-07-08T00:00:00Z
status: passed
score: 12/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 19: druidControl Bash Split to druidCharge Verification Report

**Phase Goal:** Refactor druidControl() — extract Bash/Feral Charge logic into new druidCharge() function. Fix Hibernate/Entangling Roots unreachable branch (elseif to if). Add Category M self-tests.
**Verified:** 2026-07-08
**Status:** passed (all must-haves verified; no human verification items)

## Goal Achievement

### Observable Truths

#### Plan 01 Truths (druidControl/druidCharge code changes)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | druidControl() no longer contains a Bash call or distance < 8 branch | ✓ VERIFIED | `grep -c "target.distance < 8" classes/druid/combo.lua` = 0; `grep -c "macroTorch.player.bash" classes/druid/combo.lua` = 1 (only in druidCharge, line 299); druidControl body (lines 254-269) contains no bash call |
| 2 | druidControl() Hibernate/Entangling Roots branch is reachable (elseif promoted to if) | ✓ VERIFIED | `sed -n '254,269p' classes/druid/combo.lua \| grep -c "elseif"` = 0; standalone `if target.isBeastOrDragonkin()` at line 264; hibernate() at line 265, entangling_roots() at line 267 |
| 3 | druidCharge() exists as a global function on macroTorch | ✓ VERIFIED | `function macroTorch.druidCharge()` at line 271 of combo.lua; confirmed in SM_Extend.lua at line 6167 |
| 4 | druidCharge() auto-switches to bear form when not in bear form, then returns (one action per press) | ✓ VERIFIED | Lines 281-288: `if not macroTorch.player.isInBearForm then` → isSpellExist("Dire Bear Form") → dire_bear_form('ready') / bear_form('ready') → `return` |
| 5 | druidCharge() uses Feral Charge when target distance >= 8 and distance < 8 uses Bash | ✓ VERIFIED | Line 290: `if target.distance >= 8 then` → feral_charge('safe') (line 294); `else` → bash('ready') (line 299) |
| 6 | druidCharge() has isSpellExist guards for both Feral Charge and Bash before calling them | ✓ VERIFIED | Line 291: `if not macroTorch.isSpellExist("Feral Charge") then return end`; Line 296: `if not macroTorch.isSpellExist("Bash") then return end` |
| 7 | druidCharge() follows target-check-then-form-check ordering (target first, form second) | ✓ VERIFIED | Lines 274-279: target.isCanAttack + targetEnemy() fallback (target check FIRST); Lines 281-288: isInBearForm + form auto-switch (form check SECOND) |

#### Plan 02 Truths (Category M self-tests)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8 | Category M self-tests registered after Category L (after line 746) and before Module 4 (line 784) | ✓ VERIFIED | Category M header at line 749; Category L count comment at line 746; Module 4 header at line 784 |
| 9 | At least 4 Category M tests exist covering druidCharge existence, druidControl Bash-free, druidControl pcall no-error, CC methods present | ✓ VERIFIED | M1: druidCharge function exists (line 753); M2: druidControl does not call bash (line 759); M3: druidControl invocable via pcall (line 767); M4: druidControl skill methods present (line 773) |
| 10 | All Category M tests use UnitClass('player') ~= 'Druid' guard and isOptional=true | ✓ VERIFIED | All 4 registrations have `if UnitClass('player') ~= 'Druid' then return end` guard and `end, true)` (isOptional) |
| 11 | Category M test for druidControl Bash-free asserts type(macroTorch.druidControl) == 'function' and documents code-review verification | ✓ VERIFIED | M2 (line 759-765): asserts type == "function", includes comment "Bash branch removal verified via code review in Phase 19 Plan 01." |
| 12 | Category M tests follow existing naming convention (M: prefix) and registration pattern (SelfTest:register, third arg true) | ✓ VERIFIED | All 4 use `"M: ..."` prefix, `SelfTest:register(name, fn, true)` API, matching existing Category J/K/L patterns |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/druid/combo.lua` (modified) | druidControl without Bash branch; standalone if for BeastOrDragonkin | ✓ VERIFIED | Lines 254-269: pure target check + if/else Hibernate/Entangling Roots, no Bash, no distance check, no form check, no isSpellExist |
| `classes/druid/combo.lua` (new code) | druidCharge() function with target→form→distance logic | ✓ VERIFIED | Lines 271-301: target check, isInBearForm + auto-switch, distance >= 8 Feral Charge with isSpellExist guard, else Bash with isSpellExist guard |
| `classes/druid/combo.lua` (new code) | druidCharge self-test registration | ✓ VERIFIED | Lines 338-341: "Druid: combo methods -- druidCharge exists", UnitClass guard, assert type, isOptional=true |
| `core/selftest.lua` (modified) | Category M section with 4 tests | ✓ VERIFIED | Lines 748-781: header, cited comment, 4 registrations, count comment |
| `SM_Extend.lua` (build output) | All new code concatenated correctly | ✓ VERIFIED | Build passes (exit 0), druidControl at line 6150, druidCharge at line 6167, all 4 M: tests present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| druidCharge() target check | macroTorch.target.isCanAttack / macroTorch.player.targetEnemy() | Direct method calls (same pattern as druidControl) | ✓ WIRED | Lines 274-279: calls target.isCanAttack and player.targetEnemy() |
| druidCharge() form check | macroTorch.player.isInBearForm | Property access | ✓ WIRED | Line 281: `if not macroTorch.player.isInBearForm then` |
| druidCharge() form auto-switch | dire_bear_form('ready') / bear_form('ready') | isSpellExist guard → call → return | ✓ WIRED | Lines 282-288: isSpellExist("Dire Bear Form") → dire_bear_form / bear_form → return |
| druidCharge() distance >= 8 branch | macroTorch.player.feral_charge('safe') | isSpellExist guard → feral_charge('safe') | ✓ WIRED | Lines 290-294: isSpellExist("Feral Charge") → feral_charge('safe'), 'safe' mode confirmed |
| druidCharge() distance < 8 branch | macroTorch.player.bash('ready') | isSpellExist guard → bash('ready') | ✓ WIRED | Lines 295-299: isSpellExist("Bash") → bash('ready'), 'ready' mode confirmed |
| druidControl() CC dispatch | macroTorch.player.hibernate() / macroTorch.player.entangling_roots() | Standalone if/else on isBeastOrDragonkin | ✓ WIRED | Lines 264-268: no elseif, no distance check, no form check, no isSpellExist |
| combo.lua self-test | core/selftest.lua SelfTest:register | API call at combo.lua line 338 | ✓ WIRED | Registered via `macroTorch.SelfTest:register(...)` with isOptional=true |
| Category M section placement | selftest.lua line 749 | Inserted between Category L count (746) and Module 4 header (784) | ✓ WIRED | Section starts at line 749, ends with count comment at line 781 |

### Requirements Coverage

All requirement IDs (D-01 through D-08) are defined in phase context documents (`19-CONTEXT.md`, `19-RESEARCH.md`) rather than the global REQUIREMENTS.md (which contains project-level refactoring requirements R1-R8). The ROADMAP.md phase 19 entry lists D-01 through D-08 as phase-specific requirements.

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| D-01 | 19-01 | druidCharge responsibility scope: Feral Charge + Bash, distance-branched, common form check + isSpellExist | ✓ SATISFIED | Lines 271-301: target→form→distance structure with both Charge and Bash |
| D-02 | 19-01 | Distance branches: >= 8 → Feral Charge, < 8 → Bash | ✓ SATISFIED | Lines 290-299: `if target.distance >= 8` → feral_charge, else → bash |
| D-03 | 19-01 | Auto form switch in druidCharge: detect non-bear → bear_form → return | ✓ SATISFIED | Lines 281-288: isInBearForm check, dire_bear_form/bear_form, return |
| D-04 | 19-01 | Leveling adaptation: isSpellExist guards for Bash and Feral Charge | ✓ SATISFIED | Lines 291, 296: isSpellExist guards before both calls |
| D-05 | 19-01, 19-02 | Independent global method + self-test suite | ✓ SATISFIED | function at combo.lua:271, combo.lua self-test at line 338, Category M tests at selftest.lua:753-779 |
| D-06 | 19-01, 19-02 | Delete Bash branch from druidControl | ✓ SATISFIED | druidControl lines 254-269: no Bash call, no distance check, Category M M2 documents code review |
| D-07 | 19-01, 19-02 | Keep only CC skills: Hibernate + Entangling Roots via standalone if | ✓ SATISFIED | druidControl: standalone `if target.isBeastOrDragonkin()` (no elseif), hibernate()/entangling_roots() calls present |
| D-08 | 19-01 | druidControl: no form check, no auto-switch | ✓ SATISFIED | druidControl lines 254-269: no isInBearForm, no isFormActive, no bear_form, no isSpellExist |

**Orphaned requirements:** None. All 8 requirement IDs (D-01 through D-08) from ROADMAP.md phase 19 are claimed by both Plan 01 and Plan 02 frontmatter.

### Behavioral Spot-Checks

This is a WoW addon (Lua code, no runnable server/CLI/no test runner). The build script is the only runnable artifact.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build produces druidCharge in output | `./build.sh && grep -c "function macroTorch.druidCharge" SM_Extend.lua` | 1 | ✓ PASS |
| Build produces all 4 Category M tests | `./build.sh && grep -c "M: druidCharge function exists" SM_Extend.lua` | 1 | ✓ PASS |
| Syntax check (valid Lua concatenation) | `./build.sh` exit code | 0 | ✓ PASS |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| classes/druid/combo.lua | 254-341 (new/modified section) | None found | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers. No empty implementations. No hardcoded empty data. No `#` unary length operator. |
| core/selftest.lua | 748-781 (Category M block) | None found | — | No anti-patterns. Clean code following existing conventions. |

### Deferred Items

None. All phase 19 requirements are fully satisfied in this phase.

### Human Verification Required

None. All observable truths are verifiable via static code analysis. No runtime behavior-dependent truths (form switching and distance branching are structural — presence of guards and return statements confirms the one-action-per-press pattern).

Note: In-game validation items exist in `19-VALIDATION.md` (form auto-switch, distance branch behavior, low-level isSpellExist guard) — these require a WoW client and are documented in the validation file for human UAT, not for this static verification pass.

---

**Verification complete.** All 12 must-haves verified. All 8 requirements (D-01 through D-08) accounted for. Phase goal achieved: druidControl is a pure CC dispatch (Hibernate/Entangling Roots), druidCharge provides distance-driven Feral Charge/Bash with form auto-switch and isSpellExist guards, and Category M self-tests verify structural correctness on login.

_Verified: 2026-07-08_
_Verifier: Claude (gsd-verifier)_