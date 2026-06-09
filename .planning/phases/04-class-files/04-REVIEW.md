---
phase: 04-class-files
reviewed: 2026-06-09T00:00:00Z
depth: standard
files_reviewed: 32
files_reviewed_list:
  - .gitignore
  - build.sh
  - build_order.txt
  - classes/Hunter.lua
  - classes/Mage.lua
  - classes/Priest.lua
  - classes/Rogue.lua
  - classes/Warlock.lua
  - classes/Warrior.lua
  - classes/druid/Druid.lua
  - classes/druid/bear.lua
  - classes/druid/cat.lua
  - classes/druid/utility.lua
  - core/class.lua
  - core/combat_context.lua
  - core/events.lua
  - core/periodic.lua
  - core/selftest.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - docs/REFACTOR_PLAN.md
  - docs/architecture.md
  - entity/Group.lua
  - entity/Pet.lua
  - entity/PetTarget.lua
  - entity/Player.lua
  - entity/Raid.lua
  - entity/Target.lua
  - entity/TargetPet.lua
  - entity/TargetTarget.lua
  - entity/Unit.lua
findings:
  critical: 2
  warning: 3
  info: 5
  total: 10
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-06-09
**Depth:** standard
**Files Reviewed:** 32
**Status:** issues_found

## Summary

Phase 04 (class-files) split the monolithic `SM_Extend_Druid.lua` and migrated all class files into the `classes/` directory hierarchy. The restructuring is structurally sound -- the build system is declarative, the entity layer uses the unified `classMetatable` factory, and the Druid class properly registers via `registerPlayerClass`.

However, the review identified **2 critical issues** and **3 warnings** that should be addressed before shipping. The two critical issues are: (1) an uninitialized global variable `n` in `Rogue.lua` that causes state leakage across macro invocations, and (2) a bash-vs-sh incompatibility in `build.sh` that will fail on systems where `/bin/sh` is not bash. Additionally, `Hunter.lua` retains a hand-written metatable pattern (inconsistent with the rest of the codebase), and `Druid.lua` has two dead-code `not not` double negations.

---

## Critical Issues

### CR-01: Uninitialized global variable `n` in pickPocketBeforeCast

**File:** `classes/Rogue.lua:32-44`
**Issue:** The `pickPocketBeforeCast` function reads and writes a global variable `n` without any local or namespace-scoped initialization. This is a classic Lua global leak -- the variable persists across function calls and even across macro execution contexts, meaning its value from a previous invocation can silently affect the next. Specifically, if `n` is somehow already `1` (from any prior code path), the function will skip the pickpocket step entirely and go straight to casting the spell. This also means the first call after login may find `n == nil`, which evaluates to `true` for `n ~= 1`, but future calls that left `n = 0` will also go through pickpocket. The state is unpredictable.

**Fix:**
```lua
function macroTorch.pickPocketBeforeCast(spell)
    local t = 'target'
    local n = macroTorch.pickPocketState or 0
    if UnitIsPlayer(t) or not string.find(UnitCreatureType(t), '人型生物') then
        CastSpellByName(spell)
    else
        if n ~= 1 then
            CastSpellByName("偷窃")
            macroTorch.pickPocketState = 1
        else
            CastSpellByName(spell)
            macroTorch.pickPocketState = 0
        end
    end
end
```

### CR-02: build.sh uses bash-specific `[[ ]]` syntax with `#!/bin/sh`

**File:** `build.sh:31`
**Issue:** The shebang is `#!/bin/sh`, but line 31 uses `[[ "$OSTYPE" == "cygwin" ]]`, which is a bash-ism not supported by POSIX `/bin/sh` on systems where `sh` is not bash (e.g., Debian/Ubuntu with dash). This will cause a syntax error on those systems when the Cygwin branch is reached, producing:
```
build.sh: 31: [[: not found
```
Under POSIX `sh`, `[[` is interpreted as a command named `[[`, which does not exist.

**Fix:** Replace with POSIX-compatible `[ ]`:
```sh
if [ "$OSTYPE" = "cygwin" ]; then
    cp $target /cygdrive/d/games/TurtleWoW/Interface/AddOns/SuperMacro/
fi
```

---

## Warnings

### WR-01: Hunter.lua still uses hand-written metatable (inconsistent with classMetatable factory)

**File:** `classes/Hunter.lua:34-47`
**Issue:** All other entity and class files use the unified `macroTorch.classMetatable(cls, fieldMapName)` factory, declared in `core/class.lua` per D-01. `Hunter.lua` retains a 13-line hand-written metatable with a self-documented TODO comment (`TODO(Phase-N): migrate to macroTorch.classMetatable`). This is inconsistent and creates a code path that does not benefit from the nil-guard (`cls` can be nil) added by `classMetatable` factory per D-12/D-13. If `self` (the parent class) is ever nil, the hand-written `self[k]` lookup will error, while the factory would silently return nil.

**Fix:**
```lua
-- Replace lines 34-47 with:
setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))
```

### WR-02: Dead nil-check in computeNormalRelic -- macroTorch.player is always initialized

**File:** `classes/druid/Druid.lua:265-267`
**Issue:** The code at lines 265-267 checks `if not macroTorch.player then return 'Idol of Savagery' end`. However, `macroTorch.player` is always assigned at the end of `entity/Player.lua` (line 518: `macroTorch.player = macroTorch.Player:new()`), and `initPlayer()` in `core/combat_context.lua:38` reassigns it on every `PLAYER_ENTERING_WORLD` event. This guard can never trigger in normal operation. If it ever did trigger (e.g., a catastrophic startup failure), the function returning a default value while silently skipping the intended computation is masking a much larger problem that should be surfaced.

**Fix:** Remove the dead nil-check to keep logic paths clear:
```lua
function macroTorch.computeNormalRelic(clickContext)
    if not macroTorch.player.isInCombat then
        -- out of combat logic ...
```

Or, if defense-in-depth is preferred, use an early return that also logs a warning:
```lua
if not macroTorch.player then
    macroTorch.show("[macro-torch] computeNormalRelic: player is nil", "red")
    return 'Idol of Savagery'
end
```

### WR-03: `reapLine` parameter accepted but unused in Mage.lua ranged/melee functions

**File:** `classes/Mage.lua:18-26` (`mageRangedAtk`), `classes/Mage.lua:29-37` (`mageMeleeAtk`)
**Issue:** Both `mageRangedAtk(reapLine)` and `mageMeleeAtk(reapLine)` accept a `reapLine` parameter that is never referenced in the function body. This is dead parameter plumbing -- the caller (`mageAtk`) passes `reapLine` through three levels of calls, but only `wlkCurses` in `Warlock.lua` actually uses it. The Mage functions are "forward-compatible" stubs, but the unused parameter creates a misleading API surface.

**Fix:** Either use the parameter or rename it to `_reapLine` (Lua convention for intentionally unused parameters):
```lua
function macroTorch.mageRangedAtk(_reapLine)
```

---

## Info

### IN-01: Double negation `not not` is logically redundant

**File:** `classes/druid/Druid.lua:851`, `classes/druid/Druid.lua:939`
**Issue:** Both lines use the pattern `if not not macroTorch.loginContext.tigerTimer then` and `if not not macroTorch.context.ffTimer then`. In Lua, `not not x` is equivalent to `x` when used in a boolean context (like an `if` condition). The double negation converts any value to a boolean: `not x` inverts truthiness, `not not x` re-inverts it. Since the result is already used in an `if` conditional (which already treats any non-nil/non-false value as truthy), the `not not` is functionally a no-op.

**Fix:**
```lua
-- Line 851: change to:
if macroTorch.loginContext.tigerTimer then
-- Line 939: change to:
if macroTorch.context.ffTimer then
```

### IN-02: Redundant `s` local variable in readyVanish()

**File:** `classes/Rogue.lua:141-146`
**Issue:** The function `readyVanish()` at line 141 declares `local s = '消失'` but uses `s` only once in `CastSpellByName(s)` at line 143. This local variable doesn't improve readability and adds unnecessary indirection.

**Fix:** Either inline the string or keep as-is per coding style preference (low severity).

### IN-03: Commented-out event registrations in events.lua

**File:** `core/events.lua:23, 34-36, 44`
**Issue:** Lines 23, 34-36, and 44 contain commented-out `frame:RegisterEvent(...)` calls for `PLAYER_LOGIN`, `PLAYER_DEAD`, `CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS`, `CHAT_MSG_SPELL_AURA_GONE_SELF`, and `RAW_COMBATLOG`. While these are likely reserved for future implementation, commented-out code accumulates over time and creates confusion about intent.

**Fix:** Add a brief comment explaining why each is commented out (e.g., `-- PLAYER_LOGIN: not needed, PLAYER_ENTERING_WORLD is sufficient`) or remove them if definitively not needed.

### IN-04: Single `=` assignment in Rogue.lua (non-standard Lua idiom)

**File:** `classes/Rogue.lua:22`
**Issue:** The `for` loop iterator uses `for i, v in ipairs(rogueFaintDebuffs) do` but `i` is never used in the loop body. This is a minor code quality issue.

**Fix:** Use `_` for the unused loop variable:
```lua
for _, v in ipairs(rogueFaintDebuffs) do
```

### IN-05: Architecture doc path inconsistency with build_order.txt for Druid.lua

**File:** `docs/architecture.md:40-42`
**Issue:** The architecture document lists the build order as `classes/Druid.lua` (capital D), but the actual `build_order.txt` and filesystem use `classes/druid/Druid.lua` (lowercase 'd' directory). This doesn't affect functionality (build_order.txt is the source of truth and correctly references the actual file), but the documentation is misleading for new contributors.

**Fix:** Update lines 40-42 of `architecture.md` to use the correct lowercase path:
```
→ classes/druid/Druid.lua → classes/druid/cat.lua → classes/druid/bear.lua → classes/druid/utility.lua
```

---

_Reviewed: 2026-06-09T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_