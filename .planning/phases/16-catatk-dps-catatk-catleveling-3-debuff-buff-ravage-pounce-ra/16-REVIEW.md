---
phase: 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
reviewed: 2026-06-23T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/leveling.lua
  - core/selftest.lua
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-06-23T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed `classes/druid/leveling.lua` (211 lines, the new `catLeveling()` one-button leveling macro) and `core/selftest.lua` (Category J additions, ~40 lines). The previous review's CR-01 (`tigers_fury` typo) was already fixed in commit `08bfd51` — this review covers the post-fix state.

**1 critical issue** found: a missing `POUNCE_DURATION` field on the `clickContext` that `leveling.lua` constructs. While not directly causing a crash in the current control flow, it creates a brittle contract violation. If any shared function invoked on this clickContext ever calls `isPouncePresent()` or `pounceLeft()`, the nil `POUNCE_DURATION` will produce incorrect (but non-crashing) boolean results due to Lua's handling of `nil - number`. The fix is a one-line addition.

**5 warnings** covering test registration misclassifications (`isOptional` on core tests), fragile SelfTest invocation patterns, and a nil-guarded Tiger Fury timer that silently fails when `loginContext` is absent.

**3 info items** covering comment clarity, code duplication, and a FF tracking gap.

## Critical Issues

### CR-01: `POUNCE_DURATION` missing from clickContext — silent brittleness in shared function contracts

**File:** `classes/druid/leveling.lua:36-61`
**Issue:** The `clickContext` created by `catLeveling()` never sets `clickContext.POUNCE_DURATION`. Several shared decision functions in `Druid.lua` that are transitively reachable from the `leveling.lua` call chain reference `clickContext.POUNCE_DURATION`:

- **Direct reachable path:** `shouldUseShred()` (Druid.lua:674) calls `isPouncePresent(clickContext)`, which calls `pounceLeft(clickContext)` (Druid.lua:1082-1096), which evaluates:
  ```lua
  local pounceLeft = clickContext.POUNCE_DURATION - (GetTime() - lastLandedPounceTime)
  ```
  With `POUNCE_DURATION = nil`, `nil - number` evaluates to `nil` (no crash, Lua silently produces nil), then `if pounceLeft < 0` is falsy (nil is not `< 0`), leaving `pounceLeft` as nil. This nil propagates through `isPouncePresent` → `toBoolean(nil)` → `false`. The result is silently wrong but non-crashing — `isPouncePresent` always reports false.

- **Is `shouldUseShred` actually called from `leveling.lua`?** No — `leveling.lua` uses its own inline Shred-vs-Claw logic and never calls `shouldUseShred` directly. However, the shared functions `shouldCastRip`, `shouldUseBite`, and `isKillShotOrLastChance` are called and they do not reach `isPouncePresent`. The `isTrivialBattleOrPvp` call on line 73 reaches `isTrivialBattle` which does not call `isPouncePresent`.

**Why this is still Critical:** The root issue is a contract violation. The `clickContext` is passed to shared functions in `Druid.lua` that are designed to operate on a fully-populated context (as set up by `combo.lua` line 52 `clickContext.POUNCE_DURATION = 18`). This is "works by accident" territory — the current control flow happens to avoid the nil path, but any future code change (including adding Pounce bleed tracking to a shared function) will silently produce incorrect behavior with no error to alert the developer.

Additionally, `pounceLeft()` accessing `clickContext.POUNCE_DURATION` would compute `nil - number = nil`, and setting `clickContext.pounceLeft = nil` — this is not a nil dereference crash but it pollutes the context with invalid state that could confuse other functions.

**Fix:**
```lua
-- Add after line 44 in leveling.lua (after clickContext.RIP_E = 30):
clickContext.POUNCE_DURATION = 18
```

## Warnings

### WR-01: Tiger Fury timer uses guarded `loginContext` access that silently fails

**File:** `classes/druid/leveling.lua:111-113`
**Issue:**
```lua
if macroTorch.loginContext then
    macroTorch.loginContext.tigerTimer = GetTime()
end
```
When `macroTorch.loginContext` is nil (first run, or uninitialized), the timer is silently skipped. This means `isTigerPresent()` and `tigerLeft()` in Druid.lua will never report Tiger's Fury as present from `catLeveling()`, because `tigerLeft()` checks `macroTorch.loginContext.tigerTimer` on line 970. The Tiger's Fury spell will still cast, but the addon will think the buff is never active, potentially causing repeated unnecessary TF casts.

Compare with `cat.lua:379` (`safeTigerFury()`), which unconditionally sets `macroTorch.loginContext.tigerTimer = GetTime()` — no nil guard. If `loginContext` were nil, `catAtk` would crash while `catLeveling` silently fails. Neither is ideal; the correct approach is to initialize `loginContext` when absent.

**Fix:**
```lua
-- Replace lines 111-113 with:
if not macroTorch.loginContext then
    macroTorch.loginContext = {}
end
macroTorch.loginContext.tigerTimer = GetTime()
```

### WR-02: SelfTest "J: catLeveling function exists" incorrectly marked as optional

**File:** `core/selftest.lua:577-581`
**Issue:** The test verifying `macroTorch.catLeveling` exists is registered with `isOptional=true`:
```lua
macroTorch.SelfTest:register("J: catLeveling function exists and is callable", function()
    ...
end, true)  -- isOptional=true
```
If `leveling.lua` fails to load or a build error omits it, calling `catLeveling()` would crash. Core function existence is a mandatory constraint, not optional. Within the same Category J, test J2 ("shared decision functions") and J4 ("catAtk remains unmodified") correctly use `isOptional=false`. This inconsistency means a missing `catLeveling` function would produce a yellow warning instead of a red error.

**Fix:**
```lua
end, false)  -- was true; core function existence must be enforced
```

### WR-03: SelfTest "J: catLeveling invocation does not error" marked as optional, diminishing regression protection

**File:** `core/selftest.lua:593-597`
**Issue:** The runtime invocation test is `isOptional=true`. If `catLeveling()` throws for any reason (nil dereference, method not found, WoW API issue), the failure is downgraded to a yellow warning. Given that `catLeveling()` is a user-facing one-button macro function, its crash-free execution should be a hard constraint. The `isOptional` flag is intended for external module dependencies (SuperWoW, UnitXP), not for internal core logic verification.

The test already has a `UnitClass('player') ~= 'Druid'` guard, so it only runs for Druid players. Within that scope, it should be a core test.

**Fix:**
```lua
end, false)  -- was true; runtime correctness of user-facing macro is mandatory
```

### WR-04: SelfTest "J: catLeveling has no ERPS/reshift dependency" validates the wrong property

**File:** `core/selftest.lua:604-610`
**Issue:** The test name claims to verify that `catLeveling` has no ERPS/reshift dependency, but it actually only checks:
1. That `macroTorch.computeErps` is a function (trivially true — defined in Druid.lua)
2. That `catLeveling()` does not crash via pcall (duplicate of WR-03/J3)

It does NOT verify that `catLeveling()` never calls `computeErps` or reshift-related code. The test assertion `assert(type(macroTorch.computeErps) == "function", ...)` is entirely irrelevant to the test name — `computeErps` always exists because it is defined in Druid.lua for `catAtk`. The pcall invocation is a duplicate of the previous test.

**Fix:** Either merge the pcall coverage into a single test, or rename to reflect what is actually being verified:
```lua
macroTorch.SelfTest:register("J: catLeveling is callable with full clickContext (no crash)", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(macroTorch.catLeveling)
    assert(ok, "catLeveling should not error: " .. tostring(err))
end, false)
```
If a separate ERPS/reshift dependency check is desired, it would need to inspect the `catLeveling` source code (via `string.dump` + pattern matching, or a precomputed manifest), not runtime pcall.

### WR-05: `clickContext.rough` is nil instead of explicit `false`

**File:** `classes/druid/leveling.lua:36`
**Issue:** The `clickContext` never sets the `rough` field. Two shared functions check it:
- `shouldCastRip()` (Druid.lua:902): `macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough`
- `shouldUseBite()` (Druid.lua:924): `macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough`

In Lua, `nil or false` evaluates to `false`, so the behavior is correct. However, this relies on Lua's truthiness semantics for nil. If any future code does an explicit `== false` check, it would fail. The `catAtk()` version receives `rough` as an explicit function parameter and propagates it into clickContext. For clarity and robustness, `leveling.lua` should explicitly set `clickContext.rough = false`.

**Fix:** Add after line 36:
```lua
clickContext.rough = false  -- leveling mode: always normal battle behavior
```

## Info

### IN-01: Comment at line 132 could be clearer about CP < 5 guard direction

**File:** `classes/druid/leveling.lua:131-132`
**Issue:** The Chinese comment on lines 131-132 says "5星时不再打 Rake（优先消耗连击点）" (don't Rake at 5 CP, prioritize consuming CP), while the code guard on line 138 is `clickContext.comboPoints < 5`. The code is correct (only Rake when below 5 CP), but the comment describes the negative condition (when NOT to Rake) while the code is a positive check. This is a clarity issue, not a bug.

**Fix:**
```lua
-- 维持 Rake 流血 debuff，仅在连击点 < 5 时施放（5星时优先消耗连击点）
```

### IN-02: Duplicate `hasShred`/`hasClaw` declarations in Builder module OOC/non-OOC branches

**File:** `classes/druid/leveling.lua:177-209`
**Issue:** Lines 180-181 declare `hasShred` and `hasClaw` inside the non-OOC block, and lines 197-198 declare them again inside the OOC block with identical values. Both blocks call `macroTorch.isSpellExist()`, which is a relatively expensive API call that could be done once. While not a correctness issue, the duplication increases maintenance risk — if the spell check logic changes, both blocks must be updated.

**Fix:** Hoist the declarations before the `if`:
```lua
if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 then
    local hasShred = macroTorch.isSpellExist('Shred', 'spell')
    local hasClaw = macroTorch.isSpellExist('Claw', 'spell')
    if not clickContext.ooc then
        if hasShred and clickContext.isBehind ...
```

### IN-03: FF cast via leveling.lua does not set `macroTorch.context.ffTimer`

**File:** `classes/druid/leveling.lua:153`
**Issue:** When `leveling.lua` casts Faerie Fire (Feral) via `player.faerie_fire_feral('raw')`, it does not set `macroTorch.context.ffTimer = GetTime()`. Compare with `cat.lua:1115` (`safeFF()`), which does set `macroTorch.context.ffTimer = GetTime()` after casting FF. Without this timer, `ffLeft()` in Druid.lua (line 1052-1063) will return 0, meaning `isFFPresent()` will always report false. This prevents `shouldUseShred` from using the FF debuff presence to adjust the Shred vs Claw decision. However, since `leveling.lua` does not call `shouldUseShred` (it uses its own inline logic), this gap is not currently exploitable. Future code that depends on FF tracking from `catLeveling` context would be affected.

**Fix:** Add after line 153 (`player.faerie_fire_feral('raw')`):
```lua
if not macroTorch.context then macroTorch.context = {} end
macroTorch.context.ffTimer = GetTime()
```

---

_Reviewed: 2026-06-23T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_