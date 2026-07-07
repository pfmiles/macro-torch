---
phase: quick-catleveling-ooc-cp5-fix
reviewed: 2026-07-08T00:00:00Z
depth: quick
files_reviewed: 1
files_reviewed_list:
  - classes/druid/leveling.lua
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase Quick: catLeveling OOC+CP=5 Dead Zone Fix — Code Review Report

**Reviewed:** 2026-07-08T00:00:00Z
**Depth:** quick
**Files Reviewed:** 1
**Status:** issues_found

## Summary

The fix is a single-line guard condition change at line 180 of `classes/druid/leveling.lua`:

- **Before:** `if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 then`
- **After:** `if macroTorch.isFightStarted(clickContext) and (clickContext.comboPoints < 5 or clickContext.ooc) then`

This correctly allows Module 8 (Builder) to fire when Omen of Clarity is active even at 5 combo points, eliminating a dead zone where the macro would produce no action.

The core logic is correct. The guard change aligns with the established OOC-in-build-phase pattern already used in `Druid.lua:431`. Two minor concerns are noted below.

---

## Warnings

### WR-01: OOC at CP=5 with neither Shred nor Claw learned — silent no-action fallthrough

**File:** `classes/druid/leveling.lua:180`
**Issue:** When `clickContext.ooc` is true AND `clickContext.comboPoints >= 5`, the Builder module enters. If neither Shred nor Claw is learned (or Shred is learned but `isBehind` is false AND Claw is not learned), the OOC branch (lines 199-209) silently falls through without casting anything. The OOC proc is effectively wasted.

In the non-OOC branch at CP<5, the same fallthrough occurs, but that's the pre-existing baseline behavior (no energy, no learned skill = nothing to do). In the OOC case, there is a stronger expectation that OOC should be consumed promptly, since it's a valuable proc.

**Severity:** WARNING — This is a wasted-proc edge case, not a crash or incorrect behavior. It would only occur on characters that lack both Shred and Claw entirely, which is extremely unlikely for a cat-form druid (Claw is learned at level 1 with Cat Form). The only realistic scenarios are: (a) a character in cat form without Claw on their spellbook (basically impossible), or (b) Shred learned but always attacking from the front with Claw not on bars.

**Fix:** The current behavior is acceptable given Claw is a baseline cat-form ability. No code change is strictly needed, but adding a defensive comment documenting the assumption would improve clarity:

```lua
-- OOC 触发：无视能量消耗，任意可用技能即可释放
-- 注意：Claw 是猫形态基础技能（随猫形态自动获得），正常情况下 hasClaw 永远为 true
if hasShred and clickContext.isBehind and not player.isBehindAttackJustFailed then
    player.shred('ready')
    return
end

if hasClaw then
    player.claw('ready')
    return
end
```

---

## Info

### IN-01: Outdated comment on line 177 still says "CP < 5"

**File:** `classes/druid/leveling.lua:177`
**Issue:** The comment on line 177 reads:
```
-- 战斗中 CP < 5 时，选择合适的攒星技能：Shred（背后）或 Claw（正面）
```
This no longer fully describes the module's behavior after the fix. The module now also handles **OOC at any CP** (including CP=5), not just CP<5.

**Fix:** Update the comment to reflect the OOC case:

```lua
-- 战斗中 CP < 5 时，选择合适的攒星技能：Shred（背后）或 Claw（正面）
-- OOC 触发时无视 CP 数量直接释放（免费施法消耗 OOC proc）
```

---

## Verification of Review Focus Questions

### 1. Does the change introduce any new bugs?
**No.** The OOC branch at lines 199-209 pre-existed in the Builder module. The change merely allows entry to this already-correct branch when `clickContext.ooc` is true at CP>=5. The `'ready'` mode on `shred()`/`claw()` bypasses energy checks at the `_castSpell` level, which is the correct behavior for OOC-free casts.

### 2. Is the OOC branch logic (lines 198-209) correct for CP=5?
**Yes.** The OOC branch:
- Prioritizes Shred when behind target (line 200) — correct, Shred does more damage
- Falls back to Claw (line 205) — correct, consumes the OOC proc with at least some damage
- Uses `'ready'` mode to skip energy checks — correct for free OOC casts
The only gap is the silent fallthrough when neither Shred nor Claw is available (WR-01), which is essentially unreachable in practice.

### 3. Edge cases with CP=5 and OOC but no Shred/Claw learned?
**Practically unreachable.** Cat Form automatically grants Claw (Rank 1) at level 20 (level 10 for druid + cat form quest). A druid in cat form without Claw is not a real scenario. See WR-01 for analysis.

### 4. Does this interact correctly with the Rake module (M6, line 158)?
**Yes.** The Rake module (M6) checks `clickContext.comboPoints < 5` at line 158. The Rake module does NOT have an OOC bypass on its CP check — it only blocks Rake at CP>=5, which is intentional (at 5 CP you should use a finisher or consume OOC via Builder, not Rake). The Rake module also checks `not clickContext.ooc` at line 153, so OOC+Rake is independently blocked. No conflict exists.

---

_Reviewed: 2026-07-08T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_