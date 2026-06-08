---
phase: 02-events-system
reviewed: 2026-06-08T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - core/combat_context.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - core/events.lua
  - build_order.txt
findings:
  critical: 0
  warning: 5
  info: 6
  total: 11
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-06-08T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 02 extracted `battle_event_queue.lua` (deleted) into 4 independent `core/` modules: `combat_context.lua` (3 combat state functions), `spell_trace_core.lua` (17 spell trace functions), `spell_trace_immune.lua` (3 immune tracking functions), and `events.lua` (event frame + 14 registrations + `eventHandle` dispatch). The extraction is faithful to the original code — all modified `eventHandle` branches (`onCombatExit`, `onCombatEnter`, `onPlayerEnteringWorld`) produce identical runtime behavior. Build order satisfies all inter-file dependencies.

No critical or blocker issues found. Five warnings and six informational items were identified: dead code in a guard clause, a missing nil-guard on `macroTorch.context` in the UI_ERROR_MESSAGE handler, a target-identity race in the immune-tracing callbacks, a questionable file reference in `build_order.txt`, hardcoded magic numbers, inconsistent return styles, commented-out debug code, and a nil-guard gap in `computeLandTable`.

## Warnings

### WR-01: Dead code in `computeLandTable` guard — unreachable `not lastCast` check

**File:** `core/spell_trace_core.lua:119-122`
**Issue:** Line 119 assigns `local lastCast = macroTorch.peekCastEvent(spell) or 0`, guaranteeing `lastCast` is always a number (time value) or explicitly `0`. The guard on line 122 then tests `if not lastCast or lastCast == 0 or blip <= 0.02 or blip > 0.9 then`. Since `lastCast` can never be nil or false (the `or 0` fallback eliminates both), the `not lastCast` sub-condition is dead code — it can never be true. This is a logic-quality issue (not a behavioral bug) because `lastCast == 0` already covers the nil-fallback case.

**Fix:** Remove the redundant `not lastCast` condition:
```lua
-- Line 122, change:
if not lastCast or lastCast == 0 or blip <= 0.02 or blip > 0.9 then
-- to:
if lastCast == 0 or blip <= 0.02 or blip > 0.9 then
```

### WR-02: Unconditional `macroTorch.context` dereference in UI_ERROR_MESSAGE handler

**File:** `core/events.lua:108-110`
**Issue:** The `UI_ERROR_MESSAGE` handler at lines 108-110 writes `macroTorch.context.behindAttackFailedTime = GetTime()` without first checking if `macroTorch.context` is non-nil. If a UI error fires outside of combat — e.g., during addon load, a bag-is-full error, or a targeting error — the context table will be nil, causing a Lua runtime error: `attempt to index field 'context' (a nil value)`. While WoW silently swallows Lua errors in event handlers, the error would prevent all remaining `elseif` branches in `eventHandle` from executing for that frame tick, potentially dropping other events.

**Fix:** Add a nil-guard around the context access:
```lua
if (tostring(arg1) == 'You must be behind your target') then
    if macroTorch.context then
        macroTorch.context.behindAttackFailedTime = GetTime()
    end
end
```

### WR-03: Target identity race in immune-tracing callbacks — `macroTorch.target` may have changed

**File:** `core/spell_trace_immune.lua:35,43,47`
**Issue:** The callback closures passed to `consumeFailEvent` (line 30) and `consumeLandEvent` (line 41) reference `macroTorch.target.isPlayerControlled`. The consume functions access data keyed by `macroTorch.target.name` at the time the consume runs, but between when the spell event was recorded (seconds ago) and when the periodic task processes it (every 0.1s), the player may have tab-targeted a different unit. In that case, `macroTorch.target` now points to a different entity than the one the event was originally recorded for, and the `isPlayerControlled` check may return a wrong result.

This is a pre-existing condition from the original `battle_event_queue.lua`, not introduced by the extraction. However, the modular split isolates these callbacks more prominently, making the race visible.

**Fix:** Either:
1. Store the mob name inside the consume callback and look up `isPlayerControlled` against it via a targeted API call, or
2. Document this as a known race window (acceptable for PvE content where targeting changes are rare mid-combat).

### WR-04: Missing nil-guard on `context` in `loadImmuneTable` and `loadDefiniteBleedingTable`

**File:** `core/spell_trace_immune.lua:73,91`
**Issue:** Both `loadImmuneTable()` (line 73) and `loadDefiniteBleedingTable()` (line 91) access `macroTorch.context.immuneTable` and `macroTorch.context.definiteBleedingTable` without verifying that `macroTorch.context` itself is non-nil. These functions are called from `entity/Target.lua` methods (`isImmune`, `recordImmune`, `removeImmune`, `recordDefiniteBleeding`, `isDefiniteBleeding`) and from `spellsImmuneTracing` (which guards via `macroTorch.inCombat`). If any caller invokes these functions while context is nil (e.g., `isImmune` called during UI rendering from a macro that checks immunity outside combat), a Lua error will be thrown.

**Fix:** Add a nil-guard at the top of each function:
```lua
function macroTorch.loadImmuneTable()
    if not macroTorch.context then return end
    -- ... rest unchanged
end

function macroTorch.loadDefiniteBleedingTable()
    if not macroTorch.context then return end
    -- ... rest unchanged
end
```

### WR-05: `biz_util.lua` referenced in build_order.txt but existence unconfirmed

**File:** `build_order.txt:3`
**Issue:** Line 3 references `biz_util.lua` as the third file in the build order. The file was not part of the review scope and its existence could not be verified. If absent, the build script would produce an incomplete or broken output. If it is a planned future file that does not yet exist, it should not be in the active build order.

**Fix:** Verify `biz_util.lua` exists. If it is not yet created, either add a `#` comment prefix to defer it (matching the convention used for future files on lines 19-25 and 34-44), or remove the line until the file is implemented.

## Info

### IN-01: Empty `PLAYER_LOGIN` event handler with commented-out registration

**File:** `core/events.lua:23,48-49`
**Issue:** The `PLAYER_LOGIN` event registration is commented out on line 23 (`-- frame:RegisterEvent("PLAYER_LOGIN")`), but the handler branch at lines 48-49 is still present and contains only a comment `-- on player login`. This is dead code that could confuse future maintainers into uncommenting the registration expecting initialization logic that does not exist.

**Fix:** Either remove the dead handler branch (lines 48-49), or replace the comment with a clear note explaining why the handler is reserved but registration is disabled.

### IN-02: Magic numbers for timing thresholds across spell_trace modules

**File:** `core/spell_trace_core.lua:122,133` and `core/spell_trace_immune.lua:31,43`
**Issue:** Multiple timing thresholds are hardcoded as numeric literals:
- `spell_trace_core.lua:122` — `0.02` and `0.9` (land computation window)
- `spell_trace_core.lua:133` — `0.05` (fail-to-cast proximity threshold)
- `spell_trace_immune.lua:31` — `0.4` (stale fail event cutoff)
- `spell_trace_immune.lua:43` — `0.6` (land-to-debuff-check window)

Only `DEBUFF_LAND_LAG` (0.2) is defined as a named constant. The rest are inlined, making tuning error-prone.

**Fix:** Define named constants:
```lua
-- spell_trace_core.lua
macroTorch.MIN_BLIP = 0.02
macroTorch.MAX_BLIP = 0.9
macroTorch.FAIL_PROXIMITY = 0.05

-- spell_trace_immune.lua
macroTorch.FAIL_STALE_CUTOFF = 0.4
macroTorch.LAND_CHECK_WINDOW = 0.6
```

### IN-03: Inconsistent return style — bare `return` vs explicit `return nil`

**File:** `core/spell_trace_core.lua:161-186`
**Issue:** The three `peek` functions mix bare `return` (implicit nil) and explicit `return nil` for the same logical condition within the same function:
- `peekCastEvent`: bare `return` at line 162, `return nil` at line 166
- `peekFailEvent`: bare `return` at line 172, `return nil` at line 176
- `peekLandEvent`: bare `return` at line 182, `return nil` at line 186

While functionally identical in Lua, the inconsistency suggests copy-paste drift.

**Fix:** Normalize to either bare `return` or explicit `return nil` throughout.

### IN-04: Repeated `local` declarations in `CheckDodgeParryBlockResist` shadow prior bindings

**File:** `core/spell_trace_core.lua:217-246`
**Issue:** The function uses 6 sequential regex matches against `eventMsg`, each redeclaring `local _, _, spell, mob = string.find(...)`. After the first `local` declaration, the subsequent five `local` keywords are unnecessary — they re-declare `spell` and `mob` bindings within the same function scope. While valid Lua, this is semantically misleading and creates unnecessary shadowing.

**Fix:** Remove the `local` keyword from lines 222, 228, 234, 240, 246, changing them to bare assignment:
```lua
_, _, spell, mob = string.find(eventMsg, "Your (.-) was dodged by (.-)%.")
```

### IN-05: `computeLandTable` lacks nil-guard for `macroTorch.loginContext`

**File:** `core/spell_trace_core.lua:104-139`
**Issue:** `recordCastTable`, `recordFailTable`, and the `consume*`/`peek*` functions all guard against `macroTorch.loginContext` being nil. However, `computeLandTable` writes to `macroTorch.loginContext.landTable` on line 134 (via `push`) without first checking that `loginContext` exists. While `maintainLandTables` (the caller) checks `macroTorch.inCombat`, and `loginContext` is initialized during `onPlayerEnteringWorld`, there is a window between addon load and the first `PLAYER_ENTERING_WORLD` event where the periodic OnUpdate task could fire and call `computeLandTable` with a nil `loginContext`.

**Fix:** Add a guard at the top of `computeLandTable`:
```lua
function macroTorch.computeLandTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then
        return
    end
    -- ... rest unchanged
end
```

### IN-06: Comment typo — "evnet" instead of "event"

**File:** `core/spell_trace_core.lua:126`
**Issue:** The comment reads `-- already processed for this cast evnet`. "evnet" should be "event".

**Fix:** Correct to `-- already processed for this cast event`.

---

_Reviewed: 2026-06-08T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_