---
phase: 12-range-check-mode-refactor
reviewed: 2026-06-18T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - entity/Player.lua
  - entity/Target.lua
  - entity/Unit.lua
  - classes/druid/Druid.lua
  - classes/druid/combo.lua
  - classes/druid/bear.lua
  - classes/druid/cat.lua
  - classes/hunter/combat.lua
  - classes/hunter/Hunter.lua
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-06-18
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the `_castSpell` mode-handling change that makes nil mode equivalent to 'safe' mode (triggering range and resource checks), where previously nil mode skipped both. Traced every call chain across Druid, Hunter, and the underlying entity framework to verify call-site compatibility.

**Result: No blockers found. All call sites are compatible with the new semantics.** The change is a correctness improvement -- it adds safety-net validation (range + resource checks) at the `_castSpell` layer that was previously bypassed when callers used nil/default mode. The two issues found are informational only.

Key call chains verified:
- **`casterAtk()` -> `wrath(nil)`**: range=30 check fires. Target validated beforehand via `target.isCanAttack`. Correct.
- **`druidHeal()` -> `healing_touch(nil, false)` etc.**: onSelf=false, range=40 check fires. Target set via `TargetUnit(lowestUnit)` before call. Correct.
- **`druidControl()` -> `entangling_roots(nil)`**: range=30 check fires. Target validated. Correct.
- **`regularAttack()` -> `shred()/claw()`**: range=nil (skipped), resource check fires. Energy validated. Correct.
- **`bearRegularAttack()` -> `maul()/ferocious_bite()`**: range=nil (skipped), rage check fires. Correct (previously bypassed).
- **`hunterAtk()` -> various skills**: All hunter skills have range=nil, resourceCost=nil. No new checks triggered. Correct.

### Design verification

| Concern | Verified? | Result |
|---------|-----------|--------|
| nil/0 range handled by `_isInRange` | Yes | nil range short-circuits condition; 0 range returns true in guard |
| `_isInRange` uses correct target | Yes | Uses `macroTorch.target` global singleton (correct target after `TargetUnit`) |
| `_hasResource` uses correct mana pool | Yes | `self.mana` resolves through chain to `UnitMana("player")` |
| `self.ref` resolves correctly for subclasses | Yes | Prototype chain: Druid→Player→Unit("player")→{ref="player"} |
| onSelf=true bypasses range check | Yes | `not onSelf` short-circuits condition at line 59 |
| 'raw' mode bypasses all checks | Yes | Explicitly skipped at lines 51 and 58 |

### Graceful degradation

When `UnitXP` is unavailable (standard WoW 1.12.1 without SuperWoW), `distance` returns 0, and all range checks pass. No spells are blocked by range validation on vanilla clients.

## Info

### IN-01: Redundant energy pre-checks in cat form callers now validated in `_castSpell`

**File:** `classes/druid/cat.lua:47-61`, `classes/druid/cat.lua:309-319`, `classes/druid/cat.lua:336-346`
**Issue:** Several cat form callers (`regularAttack`, `safeRake`, `safeBite`) perform their own energy/gcd/nearby checks BEFORE calling skill methods, which now ALSO perform internal resource validation via the nil=safe mode behavior. The double-validation is harmless but creates a disconnect -- if the pre-check threshold changes, the internal check won't match unless both are updated together.

For example, `safeBite` checks `player.mana >= clickContext.BITE_E` (line 337) and `isNearBy` (line 340) before calling `ferocious_bite('ready')`. But `readyBite` also calls `ferocious_bite('ready')` which uses 'ready' mode (no resource check). Meanwhile, `bearRegularAttack` calls `ferocious_bite()` with nil mode, which now triggers `_hasResource(35)`. So the same spell method has different validation depending on the caller -- some callers pre-check, some rely on internal checks.

**Fix:** This is a consistency observation, not a bug. If `_castSpell` is now the canonical validation point, consider removing redundant pre-validation in the safeX wrappers to simplify. Otherwise, no action needed.

### IN-02: Hunter spells have nil range and nil resourceCost -- missing range validation for ranged abilities

**File:** `classes/hunter/Hunter.lua:26-54`
**Issue:** All Hunter offensive skills (`raptor_strike`, `mongoose_bite`, `arcane_shot`, `multi_shot`) are defined with `range=nil` and `resourceCost=nil`. This means the new nil=safe mode triggers NO additional checks for these skills -- range validation is skipped because `range` is nil (falsy), and resource validation is skipped because `resourceCost` is nil.

While this is technically compatible with the change (no regression), several Hunter skills actually have distinct range requirements (e.g., Arcane Shot = 35 yards, Multi-Shot = 35 yards). These are not modeled in the `_castSpell` wrapper, so the range validation added to nil mode has no effect for Hunter.

**Fix:** This is a pre-existing design gap, not introduced by the mode refactor. Consider adding proper `range` and `resourceCost` parameters to Hunter skill definitions in a future change. For now, no action required.

---

_Reviewed: 2026-06-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_