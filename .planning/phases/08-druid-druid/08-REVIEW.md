---
phase: 08-druid-druid
reviewed: 2026-06-15T14:15:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - classes/hunter/Hunter.lua
  - classes/hunter/combat.lua
  - classes/hunter/utility.lua
  - classes/warrior/Warrior.lua
  - classes/warrior/combat.lua
  - classes/warrior/utility.lua
  - classes/rogue/Rogue.lua
  - classes/rogue/combat.lua
  - classes/mage/Mage.lua
  - classes/mage/combat.lua
  - classes/priest/Priest.lua
  - classes/priest/combat.lua
  - classes/priest/utility.lua
  - classes/warlock/Warlock.lua
  - classes/warlock/combat.lua
  - build_order.txt
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: fixed
fixed_date: 2026-06-15T14:30:00Z
fixes_applied:
  - CR-01: Priest heal/lesser_heal now pass onSelf=true when target falls back to self
  - WR-01: Hunter call_pet added nil guard for macroTorch.pet
  - WR-02: Priest priestAtk dead if/else branches removed (both occurrences)
  - WR-03: Mage arcane_intellect changed to Type C (accepts onSelf parameter)
fixes_skipped:
  - WR-04: rogueSneak/rogueSneakBack — intentional semantic markers for different combat modes (front vs back)
  - WR-05: readyVanish preparation check — pre-existing behavior, not introduced in Phase 8
  - IN-01..04: Info level — not in fix scope (--all not specified)
---

# Phase 8: Code Review Report

**Reviewed:** 2026-06-15T14:15:00Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Reviewed 15 new Lua source files and 1 modified build config (build_order.txt) from the Phase 8 refactoring of 6 non-Druid class files. The refactoring successfully introduces the Druid-aligned architecture: classMetatable + FIELD_FUNC_MAP + registerPlayerClass for all 6 classes, _castSpell skill methods with locale tables, SpellTrace:register (where applicable), and SelfTest:register entries. Architecture decisions are sound and consistent.

1 critical issue was found (Priest heal targeting), 5 warnings (logic errors and edge case risks), and 4 informational items (code duplication, dead code, unexplained divergence from the Druid reference). No security vulnerabilities were found.

## Critical Issues

### CR-01: Priest heal/lesser_heal called without onSelf parameter when target is self

**File:** `classes/priest/utility.lua:53-55`
**Issue:** When `priestHeal()` determines the target is not a valid friendly, it falls back to `p` (self). However, calls to `player.heal()` and `player.lesser_heal()` omit the `onSelf` parameter, which defaults to nil/falsy in `_castSpell`. When onSelf is falsy, `_castSpell` executes `obj.cast(spellName, false)` -- casting on the current target, not on self. This means when the current target exists but is unfriendly (or dead), the heal/lesser_heal/priestHeal logic correctly selects self as the beneficiary, but the spell still incorrectly targets the (unfriendly) current target instead of self.

The `renew` Type C skill method is also affected: `macroTorch.castIfBuffAbsent(t, 'Renew', 'Spell_Holy_Renew')` uses `CastSpellByName` directly (not the `renew` skill method), so it does not have this problem. But `heal()` and `lesser_heal()` do use skill methods that delegate to `_castSpell`, making the onSelf parameter critical for correctness.

Type C skills in Priest.lua (`heal`, `lesser_heal`, `renew`, `power_word_fortitude`) expose `onSelf` as a parameter but `priestHeal` never passes it, defaulting to nil/falsy which means "cast on current target, not self".

**Fix:**
When the fallback target is self (`t = p`), pass `onSelf = true` to the heal calls:

```lua
function macroTorch.priestHeal()
    local p = 'player'
    local t = 'target'
    local player = macroTorch.player
    local onSelf = false
    if not macroTorch.isTargetValidFriendly(t) then
        t = p
        onSelf = true
    end
    if macroTorch.getUnitHealthLost(t) > 440 then
        player.heal(nil, onSelf)
    elseif macroTorch.getUnitHealthLost(t) > 140 then
        player.lesser_heal(nil, onSelf)
    else
        macroTorch.castIfBuffAbsent(t, 'Renew', 'Spell_Holy_Renew')
    end
end
```

## Warnings

### WR-01: Hunter call_pet crashes if macroTorch.pet.isExist is nil

**File:** `classes/hunter/Hunter.lua:64`
**Issue:** The `call_pet` method checks `macroTorch.pet.isExist` without nil-guard. If this field is nil (e.g., during early load before Pet init completes), the condition evaluates to falsy (which happens to be correct -- nil is falsy so the else branch runs and casts Call Pet). However, if `macroTorch.pet` itself is nil (unlikely but possible in edge cases), the dereference `macroTorch.pet.isExist` will throw a Lua error and crash the macro.

The Druid reference implementation does not have a similar vulnerability because Druid form skills don't depend on external state.

**Fix:**
Add a nil guard for safety:

```lua
function obj.call_pet(mode)
    if macroTorch.pet and macroTorch.pet.isExist then
        return obj._castSpell({ en = 'Dismiss Pet', zh = '解散宠物' }, mode, nil, nil, true)
    else
        return obj._castSpell({ en = 'Call Pet', zh = '召唤宠物' }, mode, nil, nil, true)
    end
end
```

### WR-02: Priest priestAtk dead branch -- both if/else call same function

**File:** `classes/priest/combat.lua:47-51`
**Issue:** The `CheckInteractDistance(t, 3)` check has an if/else branch where both branches call `macroTorch.priestRangedAtk()` identically:

```lua
if CheckInteractDistance(t, 3) then
    macroTorch.priestRangedAtk()
else
    macroTorch.priestRangedAtk()
end
```

This pattern appears twice in the function (lines 47-51 for the direct target path, lines 64-68 for the nearest-enemy fallback). This is a dead branch -- neither path deviates. If this was intentional (Priest has no melee ability), the if/else should be removed to reduce cognitive load and code size. If a melee ability was intended, it is missing from the implementation.

The logic was likely carried over from other class templates (Warrior/Mage/Warlock use different functions for melee vs ranged), but Priest only has ranged attacks and the melee branch was never populated.

**Fix:**
Either remove the dead if/else and call `macroTorch.priestRangedAtk()` directly, or add a melee variant if planned. For now the simplest fix:

```lua
-- Remove the if/else and just call directly:
macroTorch.priestRangedAtk()
```

### WR-03: Mage arcane_intellect defined as Type A (onSelf=false) but used in castIfBuffAbsent context

**File:** `classes/mage/Mage.lua:35-37`
**Issue:** The `arcane_intellect` skill method is defined as Type A (`onSelf=false`), meaning it casts on the current target. However, `mageBuffs()` in combat.lua line 50 calls `macroTorch.castIfBuffAbsent(t, 'Arcane Intellect', ...)` where `t` defaults to self when no friendly target is selected. The skill method `arcane_intellect` exists for future migration but is never called in current code -- `castIfBuffAbsent` uses `CastSpellByName` directly. If future code migrates this `castIfBuffAbsent` to use `player.arcane_intellect()`, it will fail to self-cast because `onSelf` is hardcoded to `false`.

By comparison, Druid's Type C skills (healing_touch, regrowth, etc.) expose onSelf as a parameter. Mage's `arcane_intellect` should follow the same Type C pattern if it is expected to be used both on self and on friendly targets.

**Fix:**
Change `arcane_intellect` to Type C (expose onSelf parameter):

```lua
-- Type C: flexible target
function obj.arcane_intellect(mode, onSelf)
    return obj._castSpell({ en = 'Arcane Intellect', zh = '奥术智慧' }, mode, nil, nil, onSelf)
end
```

### WR-04: Rogue rogueSneak and rogueSneakBack are identical duplicates

**File:** `classes/rogue/combat.lua:52-54` and `classes/rogue/combat.lua:98-100`
**Issue:** Both `rogueSneak(startSp)` and `rogueSneakBack(startSp)` have the exact same body:

```lua
function macroTorch.rogueSneak(startSp)
    macroTorch.pickPocketBeforeCast(startSp)
end

function macroTorch.rogueSneakBack(startSp)
    macroTorch.pickPocketBeforeCast(startSp)
end
```

This is code duplication that suggests `rogueSneakBack` was intended to have different opener logic (presumably for backstab openers like Ambush or Garrote), but both functions currently do the same thing. If both are intended to be identical, `rogueSneakBack` is redundant. If they should differ, the "Back" variant is missing its distinct logic.

**Fix:**
If intended as identical, consolidate into a single function. If they should differ, document the future intent or add distinct opener logic for back attacks (e.g., Ambush/Garrote).

### WR-05: Rogue readyVanish calls preparation then vanish unconditionally -- preparation resets vanish cooldown but the sequence has a logic gap

**File:** `classes/rogue/combat.lua:147-156`
**Issue:** The `readyVanish` function checks if vanish is on cooldown (`macroTorch.isActionCooledDown('Ability_Vanish')`), and if so, calls `preparation()` then `vanish()`. However, `preparation` resets cooldowns -- which means `isActionCooledDown('Ability_Vanish')` would return true AFTER preparation. But the code calls `player.vanish()` regardless of whether `preparation` was successfully cast (e.g., if preparation was not ready or failed). If preparation fails to cast (not ready, silenced, no energy), `vanish()` is still called which will fail since it's on cooldown.

Additionally, the `else` branch calls `player.vanish()` directly -- this is correct but there is no check for `isActionCooledDown('Ability_Preparation')` before calling it, so if preparation is also on cooldown, this branch could attempt to use preparation when it's unavailable.

**Fix:**
Check preparation availability before attempting it:

```lua
function macroTorch.readyVanish()
    if not macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
        local player = macroTorch.player
        if macroTorch.isActionCooledDown('Ability_Vanish') then
            if macroTorch.isActionCooledDown('Ability_Preparation') then
                player.preparation()
            end
            player.vanish()
        else
            player.vanish()
        end
    end
end
```

Note: Even with this fix, there is still a timing issue -- `preparation()` and `vanish()` are called in the same click frame, and `isActionCooledDown` might not update immediately after `preparation` casts. This is an inherent limitation of the single-click execution model but worth noting.

## Info

### IN-01: Hunter HUNTER_FIELD_FUNC_MAP has typo in comment "conditinal"

**File:** `classes/hunter/Hunter.lua:77`
**Issue:** Comment says "conditinal props" instead of "conditional props". Same typo exists in `classes/warrior/Warrior.lua:100`, `classes/mage/Mage.lua:45`. The Druid reference at `classes/druid/Druid.lua:439` uses the correct spelling "conditinal props". The typo is consistent across all 6 new classes.

**Fix:** Correct to "conditional". Low priority -- cosmetic only.

### IN-02: Warrior Slam comment is not a Shield Slam reference

**File:** `classes/warrior/combat.lua:78`
**Issue:** The commented-out line `---CastSpellByName('Slam')` references "Slam", which is a Berserker Stance ability (not Shield Slam). The skill method `shield_slam` created in Warrior.lua is for the Protection-requiring "Shield Slam" ability. If this comment was intended as a placeholder for shield_slam, the wrong spell name is used. If it's about the separate "Slam" ability, no skill method has been created for it.

**Fix:** Either create a `slam` skill method for the Berserker Stance "Slam" ability, or update the comment to clarify the intent.

### IN-03: Warlock wlkRangedAtk/wlkMeleeAtk both disable startAutoAtk and use startAutoShoot

**File:** `classes/warlock/combat.lua:35,47`
**Issue:** Both `wlkRangedAtk` and `wlkMeleeAtk` have `--startAutoAtk()` commented out and both call `macroTorch.startAutoShoot()`. This means melee-range warlock also uses auto-shoot (wand) rather than melee auto-attack. While this is a valid design choice for a caster, it makes the `wlkMeleeAtk` function name misleading since it doesn't actually enable melee auto-attack.

**Fix:** If Warlock is never intended to melee attack, rename `wlkMeleeAtk` or add a comment explaining why both paths use ranged behavior. Alternatively, uncomment `startAutoAtk()` for melee range with a wanding fallback.

### IN-04: Mage mageCtrl is an empty function

**File:** `classes/mage/combat.lua:83-84`
**Issue:** `macroTorch.mageCtrl()` has an empty body. While this is a stub for future control logic and is consistent with the Warlock `wlkCtrl` stub, it creates dead code that does nothing when called.

**Fix:** Add a comment explaining that it's reserved for future Polymorph/Frost Nova/etc. control logic, or remove the function until it's implemented.

---

_Reviewed: 2026-06-15T14:15:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_