---
phase: 14-istrivialbattle-iskillshotorlastchance-60-dps-b
reviewed: 2026-06-20T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-06-20
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed Phase 14 changes to `classes/druid/Druid.lua`: two new functions (`estimatePlayerDPS`, `getKSThreshold`), modifications to `isTrivialBattle` and `isKillShotOrLastChance`, deletion of 15 `KS_CP*_Health*` constants, and 6 Category I selftest registrations.

**Key observations:**
- The 60-level hard guards correctly preserve level-60 behavior (500 DPS, 1750 KS threshold).
- All 15 `KS_CP*_Health*` constants are fully deleted; no references remain anywhere in the codebase.
- Build passes cleanly (`./build.sh` exits 0).
- The `isKillShotOrLastChance` simplification from ~55 lines to ~10 lines is correct per the design documents (D-02).
- Three warnings identified: exact-60-only guard could fail on custom servers with levels > 60, group/raid KS threshold scaling is removed (condition B becomes more aggressive in group PvE), and selftest assertions are too permissive (`>=` instead of `==`).
- Three info items: redundant nil check in selftest, development artifact comment, and slightly misleading comment phrasing.

No critical/blocker issues found. The implementation faithfully executes the Phase 14 plan.

## Warnings

### WR-01: `level == 60` exact-match guard fails if player level exceeds 60

**File:** `classes/druid/Druid.lua:586, 609`
**Issue:** Both `estimatePlayerDPS` and `getKSThreshold` use an exact equality check `if level == 60 then return <60-value> end`. If a custom server or future expansion allows player levels above 60, or if `UnitLevel('player')` ever returns a value > 60 (e.g., 61 in certain Turtle WoW custom content), the guard is bypassed and the function falls through to the `level >= 50` bracket, returning a lower value (350 DPS / 1450 KS threshold) instead of the intended level-60 maximum (500 DPS / 1750 KS threshold).

This is primarily a defense-in-depth concern. On a standard vanilla WoW 1.12.1 server, `UnitLevel('player')` returns at most 60 for players. However, `>= 60` would be a safer guard that matches the intent: "at max level and beyond, use the max-level value."

**Fix:**
```lua
-- estimatePlayerDPS
if level >= 60 then  -- safer than level == 60
    return 500
end

-- getKSThreshold
if level >= 60 then  -- safer than level == 60
    return 1750
end
```

### WR-02: `isKillShotOrLastChance` condition B removes group/raid threshold scaling

**File:** `classes/druid/Druid.lua:859-873`
**Issue:** The old `isKillShotOrLastChance` condition B used CP-aware thresholds that scaled by group size and raid size. For example, at level 60 with 5 CP in a 5-man group, the threshold was ~2250-3000 health (depending on nearby mates), vs. 1750 solo. The new code uses a single `getKSThreshold(60) = 1750` for ALL scenarios (solo, group, raid, PvP).

This means condition B triggers much more aggressively (earlier) in group PvE: a target at 2000 health in a group would now be flagged as a "kill shot" by the new code, whereas the old code correctly recognized that 2000 health is NOT a kill shot when 5 people are DPSing.

**Mitigating factors:**
- Condition A (`willDieInSeconds(2)` via HRPS) is the PRIMARY path and remains unchanged. In group scenarios with sufficient HRPS data, condition A will make the correct call.
- Condition B is the FALLBACK path, used only when HRPS data is insufficient (e.g., just switched target).

**Impact:** When a player in a group/raid switches to a new target and HRPS data hasn't accumulated yet, the addon may prematurely use Ferocious Bite (thinking it's a kill shot) when the target still has significant health. This wastes combo points in group content. The old code handled this correctly via group-scaled thresholds.

This is a known design tradeoff per D-02 ("Single KS health threshold lookup, no CP granularity"). The plan states this simplification is intentional. However, it represents a real behavioral regression for group dungeon play that should be documented and possibly revisited if users report issues.

**Fix (if regression is deemed unacceptable):**
Add an optional group-size multiplier to the call site within `isKillShotOrLastChance`:
```lua
-- Condition B with group-aware scaling
local threshold = macroTorch.getKSThreshold()
if macroTorch.player.isInGroup and not fightWorldBoss then
    local mateCount = macroTorch.player.mateNearMyTargetCount
    threshold = threshold * (1 + mateCount * 0.4)  -- scale up with group size
end
return targetHealth < threshold
```

### WR-03: Selftest bracket boundary assertions are too permissive (>= instead of ==)

**File:** `classes/druid/Druid.lua:1391-1409`
**Issue:** The selftests for bracket boundary values use `>=` assertions instead of exact `==` assertions:

- Test I-3 (estimatePlayerDPS boundaries): `v40 >= 200`, `v50 >= 350` -- would pass even if the function returns 999 for level 40 or 50.
- Test I-4 (getKSThreshold boundaries): `v40 >= 1050`, `v50 >= 1450` -- same issue.
- v30 in both tests is only validated for `type == "number"`, not for its actual value (should be 120 and 700 respectively).

These tests will not catch accidental bracket value changes. The 60-level hard guard tests (I-1, I-2) use exact `==` assertions and are correctly strict.

**Fix:**
```lua
-- Test I-3
assert(v30 == 120, "estimatePlayerDPS(30) should return 120, got: " .. tostring(v30))
assert(v40 == 200, "estimatePlayerDPS(40) should return 200, got: " .. tostring(v40))
assert(v50 == 350, "estimatePlayerDPS(50) should return 350, got: " .. tostring(v50))

-- Test I-4
assert(v30 == 700, "getKSThreshold(30) should return 700, got: " .. tostring(v30))
assert(v40 == 1050, "getKSThreshold(40) should return 1050, got: " .. tostring(v40))
assert(v50 == 1450, "getKSThreshold(50) should return 1450, got: " .. tostring(v50))
```

## Info

### IN-01: Redundant nil check in selftest assertions

**File:** `classes/druid/Druid.lua:1396, 1406`
**Issue:** The assertions `type(v30) == "number" and v30 ~= nil` contain a redundant check. In Lua, if `type(v30) == "number"` is true, then `v30` is a number and therefore not nil -- the `~= nil` check is always true and adds no value. The same pattern appears in both boundary tests.

**Fix:** Remove the redundant `and v30 ~= nil` from both assertions:
```lua
assert(type(v30) == "number", "estimatePlayerDPS(30) should return a number, got: " .. tostring(v30))
```

### IN-02: Development artifact comment in `isTrivialBattle`

**File:** `classes/druid/Druid.lua:823`
**Issue:** The comment `-- [CHANGED] ^^^ 500 replaced with estimatePlayerDPS() call` is a development/transition artifact. It describes what changed rather than what the code does or why. Similar to `-- [NEW]` / `-- [D-04]` annotations used elsewhere, this could be cleaned up to a stable descriptive comment.

**Fix:** Replace with a stable comment:
```lua
-- [D-01] Per-player DPS estimate from level-adaptive lookup, replaces old hardcoded 500
```

### IN-03: `isTrivialBattle` comment could clarify per-person semantics

**File:** `classes/druid/Druid.lua:818`
**Issue:** The comment `-- if the target's max health is less than we attack 25s worth of DPS` is accurate for the solo case but doesn't explain the `(mateNearMyTargetCount + 1)` multiplier which accounts for nearby group members. The old comment (before this phase) mentioned "each person" which conveyed the group-scaling intent. The current comment omits this detail.

**Fix:** Suggest clarifying:
```lua
-- if the target's max health is less than all nearby attackers' combined DPS over 25s
```

---

_Reviewed: 2026-06-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_