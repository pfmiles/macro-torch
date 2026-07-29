---
phase: 21-catAtk-maintainability
reviewed: 2026-07-29T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - classes/druid/combo.lua
  - classes/druid/cat.lua
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-07-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed three new Lua files implementing the Druid class macro-torch module: `combo.lua` (routing layer and the central `catAtk` combat loop), `cat.lua` (cat form combat sub-modules for burst, term, OoC, reshift, debuff maintenance, and attack power), and `Druid.lua` (class definition, energy cost computation, relic management, event tracking, level-adaptive threshold tables, and extensive self-test suite). The code is a World of Warcraft Lua macro bot for feral cat druid DPS optimization.

Overall the implementation is well-structured with good separation of concerns: routing in `combo.lua`, combat modules in `cat.lua`, and class infrastructure in `Druid.lua`. The Phase 21 maintainability improvements (D-01 through D-07 guards, `isPseudoInfiniteEnergy` centralization, `computeReshiftEnergy` dynamization) are correctly applied. Self-tests are comprehensive and cover the guard layer.

No critical defects found. Three warnings and three informational items are reported below.

---

## Warnings

### WR-01: `burstMod` early return on missing Berserk blocks all subsequent burst items

**File:** `classes/druid/cat.lua:16-23`
**Issue:** When the `IsShiftKeyDown()` burst sequence is primed but the player has not learned Berserk, the `return end` on line 17 exits `burstMod` entirely without setting `flags.berserk = true`. On subsequent clicks, `not flags.berserk` is still truthy, and the same early return repeats. This means **Juju Flurry and Attack Power burst items are permanently unreachable** for any character that lacks Berserk.

The burst sequence is designed to process one item per click (berserk, then juju flurry, then atk power). When berserk is unavailable, the sequence should skip forward instead of stalling forever.

**Fix:**
```lua
        -- berserk
        if not flags.berserk then
            if macroTorch.isSpellExist('Berserk', 'spell') and not clickContext.berserk then
                player.berserk('ready')
            end
            flags.berserk = true
            return
        end
```
This moves the return inside the successful-cast branch. When Berserk is not learned, the flag is still marked processed (allowing fallthrough to juju flurry on the next click) without attempting a cast that would fail.

### WR-02: `macroTorch.inCombat` reference in `isFightStarted` appears to be a dead check

**File:** `classes/druid/Druid.lua:766`
**Issue:** Inside `isFightStarted`, the condition includes `macroTorch.inCombat` as an alternative to `macroTorch.player.isInCombat`:

```lua
clickContext.isFightStarted = (not clickContext.prowling and
        (macroTorch.player.isInCombat
                or macroTorch.inCombat          -- <-- line 766
                or macroTorch.target.isPlayerControlled
                or (macroTorch.target.isHostile and macroTorch.target.isInCombat)
        ))
```

`macroTorch.inCombat` is a property on the global `macroTorch` table. It is not assigned anywhere in the three reviewed files, nor does it appear in any setter pattern. If it is never populated by another module, it evaluates to `nil` (falsy in Lua), making this a no-op comparison that adds confusion without functional benefit.

If this is intentionally wired to an external event tracker, that dependency is undocumented. Either the property needs a documented setter, or the redundant check should be removed.

**Fix:** Either:
1. Remove the `or macroTorch.inCombat` clause if unused.
2. Document where `macroTorch.inCombat` is set (e.g., in an event handler) if it is intentional.

### WR-03: Savagery idol snapshot flags set before spell cast confirmation in `safeRake` and `safeRip`

**File:** `classes/druid/cat.lua:353` and `classes/druid/cat.lua:367`
**Issue:** Both `safeRake` and `safeRip` set the Savagery idol snapshot tracking flags on `macroTorch.loginContext` **before** the actual spell cast, not after confirming the spell landed:

```lua
-- safeRake (line 353)
macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
macroTorch.player.rake('ready')      -- cast happens AFTER the flag is set

-- safeRip (line 367)
macroTorch.loginContext.lastRipEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
macroTorch.player.rip('ready')       -- cast happens AFTER the flag is set
```

These flags feed into `computeRake_Erps()` (Druid.lua:586-589) and `computeRip_Erps()` (Druid.lua:603-605), which apply a 10% tick interval reduction based on the flag. If the cast fails (e.g., target moves out of range between the GCD check and the cast, or the spell is interrupted), the ERPS bonus is incorrectly applied despite no actual Rake/Rip being applied. The flag is then never corrected because it is only updated on subsequent successful casts.

The correct snapshot semantics (documented in the ERPS functions as "snapshot mechanic") require that the equipment state be recorded at the time the spell **lands**, not when it is attempted.

**Fix:** Move the snapshot assignment into the `SpellTrace:register` land-event callbacks (or wrap the cast-and-set into a pattern that only sets on confirmed success):

```lua
-- Option A: only set after confirmed successful cast
function macroTorch.safeRake(clickContext)
    if macroTorch.player.isSpellReady('Rake') and macroTorch.isGcdOk(clickContext) and macroTorch.player.mana >= clickContext.RAKE_E and macroTorch.isNearBy(clickContext) then
        local success = macroTorch.player.rake('ready')
        if success then
            macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        end
        return success
    end
    return false
end
```

Note: Check whether `player.rake('ready')` returns a boolean success indicator. If it always returns true when the GCD/energy checks pass, this fix alone may not be sufficient and the land-event callback approach would be more robust.

---

## Info

### IN-01: Misspelled function name `isTrinket2CooledDown`

**File:** `classes/druid/cat.lua:412`
**Issue:** The function name `isTrinket2CooledDown` contains a misspelling: "CooledDown" should be "Cooldown" (one 'e', no extra 'D'). While the name is used consistently and causes no functional bug, it is a quality issue that may confuse future maintainers.

**Fix:** Rename to `isTrinket2Cooldown()` across all call sites (requires verifying the function definition in the base class).

### IN-02: `selectFerocityOrEmeraldRot` fallback returns a relic the player may not possess

**File:** `classes/druid/Druid.lua:421`
**Issue:** When neither `Idol of Ferocity` nor `Idol of the Emerald Rot` exists in the player's inventory or equipped state, the fallback returns `'Idol of Ferocity'`. While `recoverNormalRelic` (Druid.lua:432) correctly guards against equipping non-existent items (via `player.hasItem(relicName)` returning false), the return value semantically represents "the relic you should use" rather than "the relic you have." This mismatch in intent vs. reality could confuse downstream consumers of `computeNormalRelic()`.

**Fix:** Consider returning `nil` when no appropriate relic is available, and handle `nil` in `recoverNormalRelic` with an explicit early return:

```lua
function macroTorch.recoverNormalRelic(clickContext, relicName)
    if not relicName then return end                    -- explicit nil guard
    if not macroTorch.target.isCanAttack then return end
    ...
```

### IN-03: Inconsistent `talentRank` null-guard pattern in `computeTiger_Duration`

**File:** `classes/druid/Druid.lua:573`
**Issue:** `computeTiger_Duration` multiplies `talentRank('Blood Frenzy')` by 6 without an explicit zero/null guard:

```lua
tiger_duration = tiger_duration + macroTorch.player.talentRank('Blood Frenzy') * 6
```

Other functions using `talentRank` in the same file follow an explicit guard pattern:

```lua
-- computeRake_Erps (line 578-579)
local ancientBrutalityRank = macroTorch.player.talentRank('Ancient Brutality')
if ancientBrutalityRank == 0 then
    return 0
end

-- computeRip_Erps (line 595-597) — same pattern
-- computePounce_Erps (line 612-613) — same pattern
```

While `talentRank` is expected to return 0 (not nil) for untaken talents, the inconsistency in guard style reduces maintainability. If the talent API ever changes to return nil for untaken talents, `computeTiger_Duration` would throw a Lua error (`attempt to perform arithmetic on a nil value`).

**Fix:** Add an explicit zero guard for consistency:

```lua
function macroTorch.computeTiger_Duration()
    local tiger_duration = 6
    local bloodFrenzyRank = macroTorch.player.talentRank('Blood Frenzy')
    if bloodFrenzyRank and bloodFrenzyRank > 0 then
        tiger_duration = tiger_duration + bloodFrenzyRank * 6
    end
    return tiger_duration
end
```

---

_Reviewed: 2026-07-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_