---
phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
reviewed: 2026-07-04T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - core/selftest.lua
  - core/spell_trace_core.lua
  - entity/Player.lua
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-07-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 18 introduces `_spellIdMonitored` whitelist infrastructure — an auto-populated set table that controls which spells' `current_casting_spell` bridge variable gets set in `_castSpell`. The implementation in `spell_trace_core.lua` and `entity/Player.lua` is sound from a logic perspective: whitelist auto-population defaults to `config.land`, stale detection warns before overwrite, and the nil-safe whitelist guard short-circuits cleanly.

However, the Category L selftest L4 has a critical assertion mismatch — the test checks `_spellIdMonitored[testName]` but `SpellTrace:register` writes `_spellIdMonitored[config.spellName]` (which is `"Rake"`, not the dummy test name). This test will always fail at runtime. Additionally, the stale detection log message is misleading when the overwrite is blocked by the whitelist guard, and the `reloadui` persistence behavior on `_spellIdMonitored` is a long-term concern.

## Critical Issues

### CR-01: Category L selftest L4 assertion targets wrong whitelist key

**File:** `core/selftest.lua:717-723`
**Issue:** The L4 test `"L: monitorSpellId=true includes even with land=false"` registers via `SpellTrace:register` with `name = "__SELFTEST_L4_DUMMY__"` and `config.spellName = "Rake"`. The whitelist write in `SpellTrace:register` (spell_trace_core.lua:98) uses `config.spellName` as the key: `macroTorch._spellIdMonitored[config.spellName] = true` — writing to `_spellIdMonitored["Rake"]`. But the assertion on selftest.lua:723 checks `macroTorch._spellIdMonitored[testName]`, i.e. `_spellIdMonitored["__SELFTEST_L4_DUMMY__"]`, which will be `nil` because that key was never written.

Furthermore, the cleanup on line 726 (`macroTorch._spellIdMonitored[testName] = nil`) is a no-op, and the test leaks a write to `_spellIdMonitored["Rake"] = true` — harmless in this specific case since the real Druid registration already set it, but conceptually incorrect.

This test is a `core` (non-optional) test with `isOptional=false`, meaning selftest will report a red FAIL every time, making Phase 18 appear broken.

**Fix:** Two options:
1. Change the test to use `config.spellName` directly for the assertion and cleanup, and accept overwriting the real `"Rake"` entry (safe since it's `true` either way).
2. Rethink the test design to use a unique `config.spellName` (e.g., `"__SELFTEST_L4_UNIQUE__"`) and avoid collision with real entries entirely.

Option 2 is cleaner:
```lua
macroTorch.SelfTest:register("L: monitorSpellId=true includes even with land=false", function()
    local testName = "__SELFTEST_L4_DUMMY__"
    local testSpellName = "__SELFTEST_L4_SPELL__"
    macroTorch.SpellTrace:register(testName, {
        spellName = testSpellName,
        land = false,
        monitorSpellId = true
    })
    assert(macroTorch._spellIdMonitored[testSpellName] == true,
        "monitorSpellId=true should add spellName to whitelist, but not found for: " .. testSpellName)
    -- Cleanup
    macroTorch._spellIdMonitored[testSpellName] = nil
end, false)
```

Note: The assertion should check `_spellIdMonitored[config.spellName]` (i.e. `testSpellName`), not `_spellIdMonitored[name]` (i.e. `testName`), because the whitelist is keyed by `config.spellName`.

## Warnings

### WR-01: Stale detection log message is misleading for non-whitelisted spells

**File:** `entity/Player.lua:89-93`
**Issue:** The stale detection warning message says `"now overwritten by: " .. localeNames.en`, but for non-whitelisted spells (where `_spellIdMonitored[localeNames.en]` is falsy), the code does NOT actually overwrite `current_casting_spell` — it remains stale. This happens because the stale check is BEFORE the whitelist guard but the log message unconditionally claims an overwrite. A sequence of non-whitelisted spell casts after event loss will produce repeated stale warnings with a misleading "overwrote" claim, and the stale value never clears.

**Fix:** Move the "now overwritten by" clause into a conditional, or rephrase the warning to reflect the actual behavior:
```lua
if macroTorch.current_casting_spell ~= nil then
    if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then
        macroTorch.log("[macro-torch] current_casting_spell was not cleared: " ..
            tostring(macroTorch.current_casting_spell) ..
            ", now overwritten by: " .. localeNames.en, 'yellow')
    else
        macroTorch.log("[macro-torch] current_casting_spell was not cleared: " ..
            tostring(macroTorch.current_casting_spell) ..
            " (spell not monitored, stale value persists)", 'yellow')
    end
end
```

### WR-02: `_spellIdMonitored` persists stale entries across `/console reloadui`

**File:** `core/spell_trace_core.lua:21-22`
**Issue:** The initialization guard `if not macroTorch._spellIdMonitored then macroTorch._spellIdMonitored = {} end` only creates the table; on WoW's `/console reloadui`, global variables persist. If a spell trace registration is removed from `Druid.lua` between reloads, the old whitelist entry from the prior load cycle remains. This could cause stale `current_casting_spell` assignments for spells no longer being traced.

**Fix:** Either (a) reset `macroTorch._spellIdMonitored = {}` unconditionally at module load time, or (b) accept the persistence and document that `reloadui` is required after removing registrations. Option (a) is simpler and more robust:
```lua
macroTorch._spellIdMonitored = {}
```
Since `SpellTrace:register` always re-populates the table at parse time (Druid.lua runs after spell_trace_core.lua), resetting is safe.

## Info

### IN-01: L3 selftest cleanup logic is a silent no-op but harmless

**File:** `core/selftest.lua:706-710`
**Issue:** The L3 test cleanup code attempts to remove a `tracingSpells` entry, but `setSpellTracing` has an `if not` guard that prevents overwriting existing entries. Since the real Druid registration for Rake already set `tracingSpells[1822] = "Rake"`, the test's `setSpellTracing(1822, "__SELFTEST_L3_DUMMY__")` is a no-op, and the cleanup check `tracingSpells[1822] == testName` is never true. The cleanup code is dead code in practice, and the comment "Cleanup: remove test entry from tracingSpells if SpellTrace:register added one" is misleading — SpellTrace:register did NOT add one.

**Fix:** Replace the dead cleanup with a comment noting that `setSpellTracing`'s guard prevents collision, so no cleanup is needed:
```lua
-- No cleanup needed: setSpellTracing's if-not guard prevents overwriting
-- the real Rake entry that Druid.lua already registered.
```

### IN-02: Unnecessary nil guards on runtime-only code paths

**File:** `entity/Player.lua:98`
**Issue:** The `_castSpell` function checks `macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en]`. The `macroTorch._spellIdMonitored` nil guard is defensive against a scenario where `_castSpell` is called before `spell_trace_core.lua` loads. However, `_castSpell` can only be called at runtime via user button presses, which always happen after all modules are loaded. The guard is harmless but adds a branch that can never be taken in practice. The guard is retained as defensive coding per D-02 plan, but it is dead code for the `nil` path.

**Fix:** No action required if the defensive coding is intentional per plan D-02. If cleanliness is preferred, simplify to `if macroTorch._spellIdMonitored[localeNames.en]` since the table is guaranteed initialized before any runtime `_castSpell` call.

### IN-03: Stale detection fires "overwrote" with identical value when same spell is recast

**File:** `entity/Player.lua:89-93`
**Issue:** When a whitelisted spell (e.g. "Rake") is cast, its UNIT_CASTEVENT is lost, and the same spell is cast again, the stale warning says `"current_casting_spell was not cleared: Rake, now overwritten by: Rake"`. The word "overwritten" with an identical value is noisy and confusing. This is minor but worth noting alongside WR-01.

**Fix:** Add a same-value check to skip the log or produce a terser message:
```lua
if macroTorch.current_casting_spell ~= nil then
    if macroTorch.current_casting_spell ~= localeNames.en then
        macroTorch.log(...) -- stale different spell
    else
        macroTorch.log("[macro-torch] current_casting_spell stale (same spell): " .. localeNames.en, 'yellow')
    end
end
```

---

_Reviewed: 2026-07-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_