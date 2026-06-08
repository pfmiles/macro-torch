---
phase: 03-spell-trace
reviewed: 2026-06-08T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - SM_Extend_Druid.lua
  - build_order.txt
  - core/events.lua
  - core/selftest.lua
  - core/spell_trace_core.lua
findings:
  critical: 0
  warning: 6
  info: 4
  total: 10
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-06-08
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed 5 files spanning the SpellTrace declarative API, self-test framework, event dispatch, and the Druid class file that uses `SpellTrace:register()`. The code uses established metatable OOP patterns and follows the project's build-order concatenation strategy. No security vulnerabilities or data-loss risks were found. Six warnings and four informational items were identified, primarily centered on: nil-reference risks in unconditional context access, a debuff-time fallthrough bug in `ripLeft`/`rakeLeft`, an unresolved global variable in self-test assertions, stale tick-interval computation, missing `nil` guard in a config-driven API, and an unsafe `events.lua` guard variable. None are critical for correctness, but several could cause runtime issues under specific combat scenarios.

## Warnings

### WR-01: `events.lua:42` references `SUPERWOW_STRING` without `nil` guard

**File:** `core/events.lua:42`
**Issue:** The line `if SUPERWOW_STRING then` is not wrapped in a `nil`-guard. In Lua, reading an undefined global raises an error (`attempt to index a nil value`). If the SuperWoW addon is not installed, this line will halt `eventHandle` execution, preventing all subsequent WoW event handling (combat enter/exit, target change, error messages, etc.) for the entire session.

This is distinct from similar usage in `entity/Unit.lua:104`, where the caller likely has different execution context. In `events.lua`, the `SUPERWOW_STRING` check gates additional event registrations; failing hard here means the entire event handler is poisoned.

**Fix:**
```lua
-- Replace line 42:
if SUPERWOW_STRING then

-- with:
if SUPERWOW_STRING ~= nil then
```

Alternatively, wrap the entire registration block in a `pcall` or declare `SUPERWOW_STRING = SUPERWOW_STRING` at the top of the file to catch the nil read.

### WR-02: Self-test `CLAW_E` / `SHRED_E` / `RAKE_E` reference bare globals that do not exist

**File:** `SM_Extend_Druid.lua:1817-1827`
**Issue:** The self-test registrations for category F3 reference bare `CLAW_E`, `SHRED_E`, and `RAKE_E` as globals. These variables are never defined as bare globals in the codebase. They exist as local variables within `computeClaw_E()`, `computeShred_E()`, `computeRake_E()` and as fields on `clickContext` and `macroTorch`. The bare global references will resolve to `nil`, causing the assertions to fail on every execution of the self-test — making these three core (non-optional) tests **permanently broken**. Since `isOptional=false`, they will report as red FAIL output every login/reload.

Even if the intent was to read `macroTorch.CLAW_E`, that field is only initialized when `showEnergyUsageSet()` is explicitly called, not during construction or self-test. A safer assertion would call `computeClaw_E()` directly or reference `clickContext` after initializing one.

**Fix:**
```lua
-- Instead of:
macroTorch.SelfTest:register("Druid: CLAW_E in range", function()
    assert(CLAW_E >= 40 and CLAW_E <= 50, "CLAW_E = " .. tostring(CLAW_E))
end, false)

-- Use:
macroTorch.SelfTest:register("Druid: CLAW_E in range", function()
    local e = macroTorch.computeClaw_E()
    assert(e >= 40 and e <= 50, "CLAW_E = " .. tostring(e))
end, false)
```

Apply the same pattern to `SHRED_E` (line 1821-1823) and `RAKE_E` (line 1825-1827).

### WR-03: `computeRake_Erps()` (and `computeRip_Erps()`) use stale tick intervals on delayed `macroTorch.context` lookup

**File:** `SM_Extend_Druid.lua:433-448, 450-465`
**Issue:** `computeRake_Erps()` and `computeRip_Erps()` check `macroTorch.context.lastRakeEquippedSavagery` (and `lastRipEquippedSavagery`) to determine if the tick interval should be shortened by 10%. However, these snapshot flags are stored in `macroTorch.context` (the combat-scoped context), not in `macroTorch.loginContext`. The `macroTorch.context` table is reset to `{}` on `onCombatExit()` (see `core/combat_context.lua:24`). This means that if the player casts Rake/Rip with Savagery equipped, equips a different idol during combat, and then combat ends and starts again (e.g., between trash pulls), the snapshot flags are lost prematurely. The `lastXxxEquippedSavagery` fields should be stored in `macroTorch.loginContext` (session-scoped) rather than `macroTorch.context` (combat-scoped), because the WoW client retains the debuff tick rate determined at cast time regardless of combat transitions.

**Fix:** Move the write sites (in `safeRake` and `safeRip`) and read sites in `computeRake_Erps()`/`computeRip_Erps()` to use `macroTorch.loginContext` instead of `macroTorch.context`:

```lua
-- In safeRake (line 1312):
macroTorch.loginContext.lastRakeEquippedSavagery = ...

-- In safeRip (line 1327):
macroTorch.loginContext.lastRipEquippedSavagery = ...

-- In computeRake_Erps (line 443):
if macroTorch.loginContext and macroTorch.loginContext.lastRakeEquippedSavagery then
```

### WR-04: `ripLeft()` and `rakeLeft()` read `macroTorch.context.lastRipAtCp` / `lastRipEquippedSavagery` unconditionally — nil fallthrough produces zero duration

**File:** `SM_Extend_Druid.lua:1158-1181, 1192-1210`
**Issue:** In `ripLeft()` at line 1166, `macroTorch.context.lastRipAtCp` is read without a `nil` guard. If the field was never set (e.g., Rip was applied manually or in a prior combat where context was reset), `nil` is passed to arithmetic. In Lua, `nil + (nil - 1) * 2` evaluates to... actually `nil` in arithmetic produces an error. However, since `macroTorch.context` is always a table (initialized at combat enter), and `lastRipAtCp` may be unset, reading it yields `nil`. The expression `macroTorch.RIP_BASE_DURATION + (nil - 1) * 2` will error with "attempt to perform arithmetic on a nil value". This would only trigger if a Rip land event exists (via `peekLandEvent('Rip')`) but `lastRipAtCp` was never set — an inconsistent state that occurs when `recordCastTable('Rip')` is called via Bite renewal logic (line 526) rather than via `safeRip()` (which sets `lastRipAtCp` at line 1329).

Similarly, `rakeLeft()` at line 1199 reads `macroTorch.context.lastRakeEquippedSavagery` without `nil` guard. This is less likely to fail because `safeRake()` always sets it (line 1312), but set to `false` when Savagery is NOT equipped, so it works as intended. However, if `recordCastTable('Rake')` is called without `safeRake()` first setting the flag, the same nil-arithmetic error occurs.

**Fix:**
```lua
-- In ripLeft(), line 1165-1168:
local ripDur = macroTorch.RIP_BASE_DURATION
local cp = macroTorch.context.lastRipAtCp
if cp then
    ripDur = ripDur + (cp - 1) * 2
end
```

### WR-05: `SpellTrace:register()` does not validate `config.spellId` when `config.land` is `true`

**File:** `core/spell_trace_core.lua:58-66`
**Issue:** The `SpellTrace:register()` API passes `config.spellId` directly to `macroTorch.setSpellTracing()` when `config.land` is `true`, with no validation that `spellId` is a non-nil number. If a caller passes `{land = true}` without a `spellId`, `setSpellTracing(nil, name)` is called, which stores `macroTorch.tracingSpells[nil] = name`. Later, in the `UNIT_CASTEVENT` handler (`events.lua:90`), the check `macroTorch.tracingSpells[spellId]` would fail to match `nil`, but the `nil` key persists in the tracing table as dead data. More importantly, if `spellId` is not provided, the spell trace silently fails — no runtime error, but no useful behavior either, making it a hidden configuration bug.

Looking at the Druid registration (line 481-484), Pounce uses `spellId = 9827`, Rake uses `9904`, Rip uses `9896`, and FB uses `31018` — all properly specified. But the API contract does not enforce this, and the silent failure is hard to debug.

**Fix:**
```lua
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        if not config.spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId", 'red')
            return
        end
        macroTorch.setSpellTracing(config.spellId, name)
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

### WR-06: `computeNormalRelic()` accesses `macroTorch.player` before `macroTorch.player` is guaranteed to exist

**File:** `SM_Extend_Druid.lua:308-334`
**Issue:** `computeNormalRelic()` is called from `catAtk()` at line 156, which is called after `macroTorch.player` is assigned. So during normal gameplay this is fine. However, the function is defined as a global (`macroTorch.computeNormalRelic`) that accesses `macroTorch.player.isInCombat` on line 309 without checking if `macroTorch.player` is nil. If any other code path or plugin calls this function before player initialization (unlikely but possible), it will error.

**Fix:** Add a nil-guard at the top of `computeNormalRelic()`:
```lua
function macroTorch.computeNormalRelic(clickContext)
    if not macroTorch.player then
        return 'Idol of Savagery'
    end
    -- ... rest of function
```

## Info

### IN-01: Self-test registrations in `SM_Extend_Druid.lua` duplicate the `clickContext` pattern unnecessarily

**File:** `SM_Extend_Druid.lua:1499, 1511, 1620, 1630`
**Issue:** Functions `druidBuffs()`, `druidStun()`, `druidControl()`, and `bearAoe()` all create a `local clickContext = {}` that is either never used (`druidBuffs`, `druidControl`) or only used to pass to `isNearBy()` which lazily initializes the cache field on first access. The empty table allocation is wasteful and misleading — it suggests the function uses click-based caching when it does not.

**Fix:** Remove the unused `clickContext` in `druidBuffs()` (line 1499) and `druidControl()` (line 1620). For `druidStun()` and `bearAoe()`, the `clickContext` is used solely for the `isNearBy` cache — either inline the distance check or accept the empty allocation as a benign caching holder.

### IN-02: `SHIFT key` burst mechanism has a logic gap — flags are set but never consumed if shift is released mid-tick

**File:** `SM_Extend_Druid.lua:257-299`
**Issue:** The `burstMod()` function checks `IsShiftKeyDown()` to set `macroTorch.context.burstFlags`, then processes flags one at a time per call. If the shift key is held, flags are set. But `flags.berserk = true` is assigned on line 275 **even if the Berserk cast failed or player didn't have it**. The flag tracking assumes each ability activation succeeds (the function returns immediately after setting the flag). If a cast silently fails (e.g., spell not learned, player in wrong form), the flag is still set, and subsequent `burstMod` calls will enter an infinite "try the next flag" cycle every invocation until all flags are set and cleared.

The reset guard at line 296-298 (`if flags.berserk and flags.jujuFlurry and flags.atkPowerBurst`) only resets when ALL flags are true, but if any individual cast fails, the system skips to the next flag, and eventually all become true even though some failed.

**Fix:** Consider tracking whether each cast actually succeeded (via return value or cooldown check), rather than blindly setting flags.

### IN-03: Unused `SUPERWOW_STRING` conditional branch comments in `events.lua` should be cleaned up

**File:** `core/events.lua:34, 35, 36, 44, 113`
**Issue:** Lines 34 (`PLAYER_DEAD`), 35-36 (`CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS`, `CHAT_MSG_SPELL_AURA_GONE_SELF`), and 44 (`RAW_COMBATLOG`) have commented-out `RegisterEvent` calls. The corresponding event handlers in `eventHandle()` (lines 77-81, 95-101, 113-114) are also present. If these events are no longer needed, removing both the registration and handler branches would reduce code size. If they are planned for future use, a comment explaining when they'll be re-enabled is preferable.

### IN-04: `build_order.txt` lists Phase 4 migration files that do not exist yet

**File:** `build_order.txt:35-44`
**Issue:** The `classes/Druid.lua`, `classes/Druid/cat.lua`, etc. entries are listed in the build order but the files do not exist. The build script concatenates files by reading entries from `build_order.txt`; if these files are missing, the build will fail. This is a future-phase risk — if any developer or CI runs the build before Phase 4 is complete, the build breaks.

**Fix:** Either comment out the Phase 4 entries until the files are created, or add a check in `build.sh` to skip non-existent files with a warning rather than failing.

---

_Reviewed: 2026-06-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_