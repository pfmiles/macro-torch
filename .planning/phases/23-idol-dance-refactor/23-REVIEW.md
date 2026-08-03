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
  warning: 6
  info: 5
  total: 11
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

### WR-01: Cat O-01 and Cat O-02 selftests fail when player is out of combat

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both O-01 ("fast combat" test) and O-02 ("PvP target" test) assert that `computeNormalRelic` returns a non-Savagery idol. However, `computeNormalRelic` evaluates the non-combat branch (line 368: `if not macroTorch.player.isInCombat`) *before* the `isTrivialBattleOrPvp` branch (line 372). When the player is not in combat, the function returns `'Idol of Savagery'` at line 369, causing the assertions to fail.

Contrast with Cat O-03 (line 696) and Cat O-04 (line 706), which correctly guard their combat-state assumptions with `if not macroTorch.player.isInCombat then return end`, and Cat O-06 (line 718) which uses the inverse guard.

**Fix:** Add combat-state guards:

```lua
macroTorch.SelfTest:register("Cat O-01: fast combat returns Fero/Rot (Gap 1 fix) -- per D-01", function()
    if not macroTorch.player.isInCombat then return end  -- ADD THIS
    local ctx = { isTrivialBattle = true, isImmuneRip = false }
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for fast combat, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)

macroTorch.SelfTest:register("Cat O-02: PvP target returns Fero/Rot (Gap 1 fix) -- per D-01", function()
    if not macroTorch.player.isInCombat then return end  -- ADD THIS
    local ctx = { isTrivialBattle = true, isImmuneRip = false }
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for PvP target, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

### WR-02: Cat O-01 and Cat O-02 are functionally identical -- O-02 does not exercise PvP-specific path

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both tests create the identical context `{ isTrivialBattle = true, isImmuneRip = false }` and make the identical assertion. Cat O-02 is labeled "PvP target" but does not exercise the PvP-specific path (`macroTorch.target.isPlayerControlled`) in `isTrivialBattleOrPvp` (Druid.lua:738). It merely duplicates Cat O-01, which tests the `isTrivialBattle` path. The `isTrivialBattleOrPvp` function is an OR of two independent predicates -- having two tests is warranted, but they must exercise different code paths.

**Fix:** Either remove Cat O-02 as redundant, or modify it to test the PvP-specific code path:

```lua
macroTorch.SelfTest:register("Cat O-02: PvP target returns Fero/Rot (Gap 1 fix) -- per D-01", function()
    if not macroTorch.player.isInCombat then return end
    if not macroTorch.target.isPlayerControlled then return end  -- only test on actual PvP target
    local ctx = { isTrivialBattle = false, isImmuneRip = false }
    -- isTrivialBattleOrPvp returns true via target.isPlayerControlled path
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for PvP target, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

### WR-03: `getNextAbilityCost` missing D-03 `isSpellExist` guards for Tiger's Fury and Rake

**File:** `classes/druid/Druid.lua:889, 899`
**Issue:** The function `getNextAbilityCost` checks for Tiger's Fury presence (line 889) and Rake absence (line 899) without first verifying these spells are learned via `isSpellExist`. Compare with `shouldUseBite` (line 942), `shouldCastRip` (line 917), and `shouldUseShred` (line 687), which all include D-03 guards. A druid who has not trained Tiger's Fury or Rake could receive misleading energy-cost predictions from `getNextAbilityCost`, which feeds into `shouldDoReshift` and `shouldCastFFDuringWaitWindow` in `cat.lua`.

**Fix:** Add `isSpellExist` guards:

```lua
-- Line 889: Replace
    if not macroTorch.isTigerPresent(clickContext) then
-- With:
    if macroTorch.isSpellExist("Tiger's Fury", 'spell') and not macroTorch.isTigerPresent(clickContext) then

-- Line 899: Replace
    if not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
-- With:
    if macroTorch.isSpellExist('Rake', 'spell') and not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
```

### WR-04: Cat O-07 is a weak existence-check -- does not validate `recoverNormalRelic` behavior

**File:** `classes/druid/selftest.lua:726-731`
**Issue:** The test labeled "Distance >= 20 bypass present (Gap 4 fix) -- per D-03" only checks that `recoverNormalRelic` is a function and that `target.distance` is not nil. It never calls `recoverNormalRelic` or validates that the distance >= 20 early-return path actually produces correct behavior. The test name implies behavioral validation but only performs type/API-existence checks. The SUMMARY.md (line 71-72) explicitly notes this requires in-game WoW client verification -- the test name should reflect that it is a smoke test.

**Fix:** Rename the test to accurately reflect its scope:

```lua
macroTorch.SelfTest:register("Cat O-07: recoverNormalRelic function and target.distance API exist (Gap 4 smoke test) -- per D-03", function()
    assert(type(macroTorch.recoverNormalRelic) == 'function',
        "recoverNormalRelic should be a function")
    assert(macroTorch.target.distance ~= nil,
        "target.distance API not available on this client")
end, true)
```

### WR-05: DESIGN.md misalignment -- `ripAppliedTargets` state tracking not implemented (Gap 3 unfixed)

**File:** `classes/druid/Druid.lua:362-385`
**Issue:** The DESIGN.md (lines 59-91) specified a two-file implementation plan:

1. **Druid.lua**: Rewrite `computeNormalRelic()` to check `macroTorch.context.ripAppliedTargets[macroTorch.target.guid]` -- once Rip was ever applied to a target, lock to Builder idol even after Rip expires (Gap 3 fix)
2. **cat.lua**: Add state recording in `safeRip()`: `macroTorch.context.ripAppliedTargets[macroTorch.target.guid] = true`

The actual implementation uses `macroTorch.isRipPresent(clickContext)` (line 380) instead. This means:
- While Rip is present on the target: Builder idol is returned (correct, same as design)
- When Rip expires (without being refreshed by Bite): `isRipPresent()` returns false, `computeNormalRelic` falls through to the Savagery fallback at line 384 -- this is the Gap 3 bug the DESIGN.md intended to fix

The SUMMARY.md (line 49) is transparent about which requirements were completed (GAP1, GAP2, GAP4 -- not GAP3). However, the DESIGN.md's "Implementation Plan" section remains the authoritative specification, and the deviation is not documented in a way that future maintainers can discover without cross-referencing the SUMMARY. The function comments in `computeNormalRelic` (lines 356-361) describe the flat-branch logic but do not mention the `ripAppliedTargets` approach or explain why it was not used.

**Fix:** Add a comment in `computeNormalRelic` explicitly documenting the Gap 3 limitation:

```lua
-- 计算normal relic（接下来的战斗默认穿戴的relic）
-- 逻辑：
-- 1. 不在战斗时：免疫rip用fero/emerald_rot，不免疫用savagery
-- 2. 在战斗时：
--    - 快速战斗/PvP：保持原逻辑不变
--    - 普通战斗：如果rip已存在且目标不免疫rip，则使用fero/emerald_rot以便快速打出claw或造成更多伤害；否则用savagery
-- NOTE: Gap 3 (Rip到期后误切回Savagery) 未在此版本修复。
--       当Rip到期且未被Bite刷新时，isRipPresent()返回false，本函数会返回Savagery，
--       触发不必要的圣物切换GCD。ripAppliedTargets方案（DESIGN.md）待后续版本实现。
```

### WR-06: `recoverNormalRelic` modified despite DESIGN.md listing it as unchanged

**File:** `classes/druid/Druid.lua:421-441`
**Issue:** The DESIGN.md section "不改动的部分" (line 107-111) explicitly lists `recoverNormalRelic()` as unchanged: "能量检查、形态守卫、hasItem 守卫均正确，不动." The actual implementation added a distance bypass (lines 433-436) to `recoverNormalRelic`. The SUMMARY.md documents this as Gap 4 (REQ-23-GAP4), but the DESIGN.md never included Gap 4 in its gap analysis. This means the DESIGN.md is out of sync with the implementation in two ways: (1) it says `recoverNormalRelic` is unchanged, and (2) it has no Gap 4 description.

**Fix:** The DESIGN.md should be updated to reflect the distance bypass as a design change, or the SUMMARY.md should explicitly note that Gap 4 was added post-design as a scope expansion. Add a comment on the distance bypass noting it was a post-design addition:

```lua
    -- Distance bypass: running time covers relic GCD, skip energy check per D-03/D-04
    -- NOTE: Added post-DESIGN as Gap 4 fix. The DESIGN.md lists recoverNormalRelic as unchanged;
    -- this is the one modification.
    if macroTorch.target.distance >= 20 then
        macroTorch.player.ensureRelicEquipped(relicName)
        return
    end
```

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