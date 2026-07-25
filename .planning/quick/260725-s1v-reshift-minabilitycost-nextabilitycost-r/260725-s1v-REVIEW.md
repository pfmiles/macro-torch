---
phase: quick-s1v
reviewed: 2026-07-25T00:00:00Z
depth: quick
files_reviewed: 3
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
  - biz_util.lua
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Quick Review: Reshift — getMinimumAffordableAbilityCost → getNextAbilityCost Rename

**Reviewed:** 2026-07-25  
**Depth:** quick (pattern-matching + targeted logic analysis)  
**Files Reviewed:** 3  
**Status:** issues_found (2 warnings, 1 info — zero critical)

## Summary

Reviewed the three changed files from commit c371482: the `getMinimumAffordableAbilityCost` → `getNextAbilityCost` rename across `Druid.lua` and `cat.lua`, the new "earning" log field in `readyReshift`, and the `isKeywordInEquippedItemTooltip` function in `biz_util.lua`.

**Rename correctness:** ✅ All call sites have been updated. Zero residual references to the old name (`minimumAffordable` / `getMinimumAffordableAbilityCost`) exist in the codebase. The `SM_Extend.lua` generated file also reflects the rename (verified).

**No critical issues found.** Two warnings and one informational note below.

## Warnings

### WR-01: `getNextAbilityCost` called in `shouldCastFFDuringWaitWindow` discards second return value

**File:** `classes/druid/Druid.lua:849`
**Issue:** At line 849, `shouldCastFFDuringWaitWindow` calls `getNextAbilityCost(clickContext)` and assigns only the first return value to `minAbilityCost`. This is correct for current usage (only the cost number is needed for comparison), but it creates a latent coupling: if a future maintainer adds a caller that needs the move name, they may not realize `getNextAbilityCost` returns two values in this context.

**Fix:** The pattern is acceptable as-is since the discarded value is intentional, but consider adding a comment to clarify intent:

```lua
-- getNextAbilityCost returns (cost, moveName); we only need cost here
local minAbilityCost = macroTorch.getNextAbilityCost(clickContext)
```

### WR-02: `earning` debug calculation in `readyReshift` may produce negative values

**File:** `classes/druid/cat.lua:333`
**Issue:** The expression `clickContext.RESHIFT_ENERGY - macroTorch.player.mana - clickContext.TIGER_E` can produce negative numbers when the player's current energy is high relative to the reshift energy gain (e.g., if reshifting at 40 energy, Furor rank 3 gives 24, minus Tiger_E = -46). While this is only a debug log and won't crash Lua, negative "earning" values in the log could mislead players reviewing combat output.

**Fix:** If the intent is to show actual net energy gain, consider clamping to zero or using separate terms:

```lua
', earning = ' .. tostring(math.max(0, clickContext.RESHIFT_ENERGY - macroTorch.player.mana - clickContext.TIGER_E))
```

Or alternatively, split into raw gain and cost to avoid ambiguity:

```lua
', reshiftGain = ' .. tostring(clickContext.RESHIFT_ENERGY) ..
', tigerCost = ' .. tostring(clickContext.TIGER_E)
```

## Info

### IN-01: `isKeywordInEquippedItemTooltip` creates a temporary GameTooltip frame on every call

**File:** `biz_util.lua:369-371`
**Issue:** The function creates a new `GameTooltip` frame (`frameName = "MacroTorchTooltipScan"`) with every call via `CreateFrame`. Since `computeReshiftEnergy()` calls this function every reshift evaluation cycle, this creates unnecessary frame allocation overhead in the WoW UI system. The frame is hidden but not destroyed/reused, creating a new frame object each call.

**Fix:** Create the tooltip once and reuse it (lazy-init pattern):

```lua
function macroTorch.isKeywordInEquippedItemTooltip(slot, keyword)
    if not macroTorch._tooltipScanFrame then
        macroTorch._tooltipScanFrame = CreateFrame("GameTooltip", "MacroTorchTooltipScan", UIParent, "GameTooltipTemplate")
        macroTorch._tooltipScanFrame:SetOwner(UIParent, "ANCHOR_NONE")
    end
    local tooltip = macroTorch._tooltipScanFrame
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", slot)
    -- ... rest of function unchanged ...
    tooltip:Hide()
    return found
end
```

This is an **informational** note only — the current code works correctly and performance impact is minimal for a macro addon. But frame allocation in a game loop is a minor code smell worth addressing as a cleanup.

---

_Reviewed: 2026-07-25_  
_Reviewer: AI reviewer (gsd-code-review)_  
_Depth: quick_