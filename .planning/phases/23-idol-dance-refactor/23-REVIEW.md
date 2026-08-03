---
phase: 23-idol-dance-refactor
reviewed: 2026-08-03T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 1
  info: 9
  total: 10
  fixed: 2
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-08-03T12:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed two files in the Phase 23 idol-dance refactor scope:
- `classes/druid/Druid.lua` -- contains `computeNormalRelic` rewrite (flat 5-branch chain), `selectFerocityOrEmeraldRot` helper, and `recoverNormalRelic` distance bypass
- `classes/druid/selftest.lua` -- contains 7 new Category O SelfTest registrations (O-01 through O-07)

The implementation successfully fixes two of the three gaps identified in the design document:
- **Gap 1** (fast combat/PvP wrongly using Savagery): Fixed via branch ordering
- **Gap 2** (immune Rip targets wrongly using Savagery): Fixed via dedicated branch
- **Gap 4** (distance bypass for recoverNormalRelic): Added as new functionality

However, the implementation omits the DESIGN.md's primary proposed feature: the `ripAppliedTargets` state-tracking map that would fix **Gap 3** (Rip expiry causing unnecessary Savagery reswitching). The current `computeNormalRelic` uses `isRipPresent()` instead, which behaves identically to the pre-existing code for the Gap 3 scenario. This is acknowledged in the SUMMARY.md (Gap 3 not listed among completed requirements), but the deviation from the DESIGN.md's "Implementation Plan" section is not explicitly called out.

Additionally, 4 of the 7 new self-tests have quality issues: two (O-01, O-02) lack combat-state guards making them fragile out of combat, two (O-01 and O-02) are functionally identical despite different labels, and one (O-07) tests function existence rather than behavior. The prior review's WR-03 (missing D-03 guards in `getNextAbilityCost`) also remains unfixed.

## Warnings

### WR-01: Cat O-01 and Cat O-02 selftests fail when player is out of combat ✅ FIXED

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both O-01 ("fast combat" test) and O-02 ("PvP target" test) assert that `computeNormalRelic` returns a non-Savagery idol. However, `computeNormalRelic` evaluates the non-combat branch (line 368: `if not macroTorch.player.isInCombat`) *before* the `isTrivialBattleOrPvp` branch (line 372). When the player is not in combat, the function returns `'Idol of Savagery'` at line 369, causing the assertions to fail.

Contrast with Cat O-03 (line 696) and Cat O-04 (line 706), which correctly guard their combat-state assumptions with `if not macroTorch.player.isInCombat then return end`, and Cat O-06 (line 718) which uses the inverse guard.

**Outcome:** Fixed. Added `if not macroTorch.player.isInCombat then return end` guard to O-01. O-02 guard handled together with WR-02 fix.

### WR-02: Cat O-01 and Cat O-02 are functionally identical -- O-02 does not exercise PvP-specific path ✅ FIXED

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both tests create the identical context `{ isTrivialBattle = true, isImmuneRip = false }` and make the identical assertion. Cat O-02 is labeled "PvP target" but does not exercise the PvP-specific path (`macroTorch.target.isPlayerControlled`) in `isTrivialBattleOrPvp` (Druid.lua:738). It merely duplicates Cat O-01, which tests the `isTrivialBattle` path. The `isTrivialBattleOrPvp` function is an OR of two independent predicates -- having two tests is warranted, but they must exercise different code paths.

**Outcome:** Fixed. Modified O-02 to use `isTrivialBattle = false` context with `if not macroTorch.target.isPlayerControlled then return end` guard, exercising the PvP-specific OR branch in `isTrivialBattleOrPvp`. Also added combat-state guard (WR-01 fix).

### WR-03: ~~`getNextAbilityCost` missing D-03 `isSpellExist` guards~~ → **DOWNGRADED to Info** (pre-existing, not Phase 23 regression)

**Severity Adjustment:** This function was NOT modified in Phase 23. The inconsistency (Tiger's Fury and Rake lack inline `isSpellExist` guards that Bite/Rip/Shred have inside their helper functions) pre-dates this phase. The reviewing agent flagged it as a general code quality observation, not a Phase 23 bug. See IN-03 in Info section.

### WR-04: ~~Cat O-07 is a weak existence-check~~ → **DOWNGRADED to Info** (intentional smoke test)

**Severity Adjustment:** The SUMMARY.md (line 71-72) explicitly documents that O-07 is a structure-level smoke test: "Distance bypass requires in-game WoW client to verify end-to-end; O-07 is a structure-level smoke test." The test correctly validates that the function and API exist, which is a meaningful quality gate (catches renamed functions or missing API on older clients). The test name could be more precise, but the limitation is intentional and documented. See IN-04 in Info section.

### WR-05: DESIGN.md misalignment -- `ripAppliedTargets` state tracking not implemented (Gap 3 unfixed)

**File:** `classes/druid/Druid.lua:362-385`
**Status:** ⚠️ Confirmed — known scope gap (intentionally deferred to future phase)

**Issue:** The DESIGN.md (lines 59-91) specified a two-file implementation plan:

1. **Druid.lua**: Rewrite `computeNormalRelic()` to check `macroTorch.context.ripAppliedTargets[macroTorch.target.guid]`
2. **cat.lua**: Add state recording in `safeRip()`: `macroTorch.context.ripAppliedTargets[macroTorch.target.guid] = true`

The actual implementation uses `macroTorch.isRipPresent(clickContext)` (line 380). This means when Rip expires without being refreshed by Bite, `isRipPresent()` returns false and `computeNormalRelic` falls through to Savagery — the Gap 3 bug persists. **However**, SUMMARY.md explicitly lists only REQ-23-GAP1/2/4 as completed; Gap 3 was intentionally scoped out of this plan. Marked as **known scope gap**, not implementation error. Future phase should implement the `ripAppliedTargets` approach from DESIGN.md.

### WR-06: ~~`recoverNormalRelic` modified despite DESIGN.md listing it as unchanged~~ → **DOWNGRADED to Info** (code correct, doc incomplete)

**Severity Adjustment:** The DESIGN.md was written before Gap 4 (distance bypass) was identified. The SUMMARY.md documents Gap 4 as an additional scope item (REQ-23-GAP4). The code change is correct — the DESIGN.md simply needs updating to reflect the actual scope. This is a documentation gap, not a code defect. See IN-05 in Info section.

## Info

### IN-01: Redundant multiplication by 1 in `shouldUseShred`

**File:** `classes/druid/Druid.lua:715`
**Issue:** `local energyIn1s = erps * 1` -- multiplying by 1 has no effect. The variable name `energyIn1s` already conveys the semantic meaning (energy in 1 second). The `* 1` is a no-op that adds visual noise.

**Fix:** Replace with `local energyIn1s = erps`.

### IN-02: `selectFerocityOrEmeraldRot` returns relic name when player owns neither

**File:** `classes/druid/Druid.lua:418`
**Issue:** When the player owns neither `Idol of Ferocity` nor `Idol of the Emerald Rot`, the function returns `'Idol of Ferocity'` as a default. The caller `recoverNormalRelic` guards against this with `hasItem()` at line 429, so no incorrect equip occurs. However, `computeNormalRelic` stores this result in `clickContext.normalRelic` (combo.lua:103) regardless of ownership -- the "normal relic" becomes a relic the player does not own. This is semantically misleading and relies on downstream callers to perform ownership checks.

**Fix:** Add a comment noting the caller's responsibility:

```lua
    -- 两个都不存在，默认返回Ferocity（兼容原逻辑）
    -- NOTE: 调用方（recoverNormalRelic）必须自行检查 hasItem，避免尝试装备不存在的神像
    return IDOL_FEROCITY
```

### IN-03: Core principles document (Rule 13) not updated for distance bypass behavior

**File:** `.planning/catAtk-core-principles.md:372`
**Issue:** The core principles document (ADR-001), Rule 13 / Appendix D, states that `recoverNormalRelic` "never triggers" during infinite energy scenarios. With the new distance bypass (Druid.lua:433-436), `recoverNormalRelic` now triggers during infinite energy when the player is 20+ yards from the target (e.g., running back after knockback during Essence of the Red). While this is behaviorally correct (D-03/D-04 design: "running time covers relic GCD"), the principles document contradicts the code. ADR-001 serves as the authoritative reference for future maintainers and should accurately reflect system behavior.

**Fix:** Update the principles document Appendix D, Rule 13 row for `recoverNormalRelic`:

```
- `recoverNormalRelic` (`Druid.lua`) — `energy + erps * 2.5 > 100`永远成立，所以圣物永不换回
+ `recoverNormalRelic` (`Druid.lua`) — `energy + erps * 2.5 > 100`永远成立，所以圣物永不换回
+   例外: 距离 >= 20码时，跑步时间覆盖圣物GCD，距离绕过机制会触发换回(D-03/D-04)
```

### IN-04: Missing test: non-combat + immune Rip target path untested

**File:** `classes/druid/selftest.lua:667-732`
**Issue:** The `computeNormalRelic` function has 5 branches. The Category O tests cover branches 3 (O-01), 4 (O-03), 5 (O-04), and 6/O-05 (fallback). Branch 1 (non-combat + immune Rip -> Fero/Rot, line 364-366) and branch 2 (non-combat + non-immune -> Savagery, line 368-369) are only partially tested: O-06 tests the non-immune path but no test covers the non-combat + immune path. The D-02 preservation of this branch is verified only through code inspection.

**Fix:** Add a test for the non-combat immune path:

```lua
macroTorch.SelfTest:register("Cat O-08: Non-combat immune Rip returns Fero/Rot (D-02 preserved) -- per D-01", function()
    if macroTorch.player.isInCombat then return end
    if not macroTorch.target.isImmune('Rip') then return end  -- only test on immune targets
    local ctx = { isImmuneRip = true }
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for non-combat immune Rip, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

### IN-06: getNextAbilityCost missing D-03 isSpellExist guards (pre-existing, from WR-03 downgrade)

**File:** `classes/druid/Druid.lua:889, 899`
**Note:** This finding was downgraded from Warning to Info because the `getNextAbilityCost` function was NOT modified in Phase 23. The inconsistency pre-dates this phase. Bite/Rip/Shred are protected by `isSpellExist` guards inside their respective helper functions (`shouldUseBite`, `shouldCastRip`, `shouldUseShred`), but Tiger's Fury and Rake checks are inline without guards. Affects energy prediction accuracy for low-level druids who haven't trained these spells.

### IN-07: Cat O-07 is a smoke test by design (from WR-04 downgrade)

**File:** `classes/druid/selftest.lua:726-731`
**Note:** This finding was downgraded from Warning to Info because the SUMMARY.md explicitly documents O-07 as a structure-level smoke test. The distance bypass requires in-game WoW client verification. The test correctly validates function existence and API availability — a meaningful quality gate for catching renamed functions or missing APIs on older clients.

### IN-05: DESIGN.md potential update needed -- recoverNormalRelic listed as unchanged but was modified

**File:** `.planning/phases/23-idol-dance-refactor/23-DESIGN.md:111`
**Issue:** The DESIGN.md table "不改动的部分" lists `recoverNormalRelic()` as unchanged. Since the implementation added the distance bypass (Gap 4), the DESIGN.md is now stale for this entry. If the DESIGN.md is intended to remain the authoritative reference for future idol-dance work, it should reflect the actual scope of changes. This is related to WR-06 but categorized as Info because it does not affect runtime behavior.

**Fix:** Update the DESIGN.md table entry for `recoverNormalRelic()`:

```
- | `recoverNormalRelic()` | 能量检查、形态守卫、hasItem 守卫均正确，不动 |
+ | `recoverNormalRelic()` | 能量检查、形态守卫、hasItem 守卫均保留；新增距离绕过(Gap 4)：>=20码时跳过能量检查 |
```

---

## Design Alignment Analysis

The following verification points from the DESIGN.md (lines 154-164) were checked against the implementation:

| # | Verification Point | Status | Notes |
|---|-------------------|--------|-------|
| 1 | Non-combat, non-immune -> Savagery | PASS | Line 368-369; O-06 confirms |
| 2 | Enter combat, first Rip -> Savagery already on | PASS | Pre-switch preserved per D-02 |
| 3 | After Rip lands -> safe window back to Builder idol | PASS | recoverNormalRelic unchanged except distance bypass |
| 4 | Rip present -> locked to Builder idol | PARTIAL | Works while Rip present; Gap 3 (expiry) not fixed |
| 5 | Rip expires -> stays Builder idol | FAIL | Not implemented; isRipPresent-based check returns Savagery on expiry |
| 6 | Switch target in combat -> independent state | UNTESTED | Depends on Gap 3; no multi-target test |
| 7 | Exit/re-enter combat -> state reset | PASS | context = {} on combat exit |
| 8 | Fast combat/PvP -> always Builder idol | PASS | Gap 1 fix; O-01/O-02 cover |
| 9 | Immune Rip -> always Builder idol | PASS | Gap 2 fix; O-03 covers |
| 10 | High energy regen -> stays Savagery (0 swaps) | CHANGED | Distance bypass may trigger 1 swap at 20+ yd per D-03/D-04 |

Verification points 5 and 6 failed due to Gap 3 not being implemented. Verification point 10 changed from "0 swaps -> 0-1 swaps" due to the distance bypass addition.

---

## Principles Conformance Analysis

The two most relevant core principles (from `.planning/catAtk-core-principles.md`) were checked:

### Rule 12: Relic Swap GCD Cost Awareness

The implementation is **conformant**. The flat-branch `computeNormalRelic` correctly avoids relic swaps that waste GCD:
- Gap 1 fix: fast combat/PvP never switches to Savagery (1.5s GCD saved)
- Gap 2 fix: immune Rip targets never switch to Savagery (1.5s GCD saved)
- The distance bypass in `recoverNormalRelic` exploits unavoidable running time to perform relic swaps "for free" -- consistent with the principle that swaps should only occur during otherwise-wasted GCDs

### Rule 13: Infinite Energy Simplification

The implementation is **partially conformant** with a documented exception. The distance bypass in `recoverNormalRelic` (line 433-436) fires before the energy check (line 437). During infinite energy (Essence of the Red), when the player is 20+ yards from target, the relic will be swapped back to Builder idol -- contradicting the strict statement in the principles doc that "relic recovery never triggers." The D-03/D-04 design decision justifies this: running time covers the relic GCD, making the swap effectively free even during infinite energy. However, the principles document (Appendix D) should be updated to reflect this exception (see IN-03).

---

*Reviewed: 2026-08-03T12:00:00Z*
*Reviewer: Claude (gsd-code-reviewer)*
*Depth: standard*