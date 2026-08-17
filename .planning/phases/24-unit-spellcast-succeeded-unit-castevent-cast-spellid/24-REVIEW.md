---
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
reviewed: 2026-08-17T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - core/combat_context.lua
  - core/events.lua
  - core/selftest.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - entity/Player.lua
  - macro_torch.lua
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-08-17
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed 7 source files changed during Phase 24 (name-keyed `tracingSpells` migration from spellId-keyed). The core design change -- switching `tracingSpells` from numeric spellId keys to string spellName keys, with `UNIT_SPELLCAST_SUCCEEDED` as the primary cast-recording event -- is implemented correctly across the event handler dispatch and the `SpellTrace:register` / `setSpellTracing` API.

Three warnings and six informational findings were identified. No critical (blocker) issues: no security vulnerabilities, no guaranteed crashes, no data loss paths. The warnings are all in deprecated code paths (gated behind `SPELL_ID_AUTO_CORRECT = false` by default) or self-test cleanup code, not in the active production path. The informational findings are primarily debug artifacts and defensive programming opportunities.

---

## Warnings

### WR-01: `onCombatExit` asymmetrically gates `inCombat = false` behind context existence

**File:** `core/combat_context.lua:21-26`
**Issue:** `onCombatExit` only sets `macroTorch.inCombat = false` when `macroTorch.context` is truthy, while `onCombatEnter` unconditionally sets `macroTorch.inCombat = true` and lazily initializes context. If an edge case causes `PLAYER_REGEN_ENABLED` to fire without a corresponding prior `PLAYER_REGEN_DISABLED` (e.g., addon reload mid-combat, or the `context` table was cleared by external code), `macroTorch.inCombat` remains `true` indefinitely. This breaks all combat-gated logic (spell tracing, immune tracing, `maintainLandTables`), which all check `macroTorch.inCombat`.

**Fix:**
```lua
function macroTorch.onCombatExit()
    macroTorch.inCombat = false      -- always reset, regardless of context state
    if macroTorch.context then
        macroTorch.context = {}
    end
    macroTorch.show('Exiting combat!')
end
```

---

### WR-02: Self-test L3 cleanup uses wrong key, leaving garbage in `tracingSpells`

**File:** `core/selftest.lua:724`
**Issue:** Category L test 3 registers a temporary spell trace with `name = "__SELFTEST_L3_DUMMY__"` and `spellId = 999998`. After Phase 24, `SpellTrace:register` (with `land = true`) calls `setSpellTracing(name)`, which sets `tracingSpells["__SELFTEST_L3_DUMMY__"] = true`. However, the cleanup line attempts to delete `tracingSpells[999998]` -- a numeric key that does not exist. The actual entry `tracingSpells["__SELFTEST_L3_DUMMY__"]` is never cleaned up, leaving garbage in the production `tracingSpells` table after selftest runs. While functionally benign (the entry is just `true`), it pollutes `tracingSpells` and would fail the Category K test 1 assertion that all keys are strings if selftests were re-run.

**Fix:**
```lua
-- Line 724: change cleanup key from numeric spellId to registration name
macroTorch.tracingSpells["__SELFTEST_L3_DUMMY__"] = nil
```

---

### WR-03: `loadSpellIdMap` migration loop creates numeric keys in name-keyed `tracingSpells`

**File:** `core/spell_trace_immune.lua:126-134`
**Issue:** The migration code inside `loadSpellIdMap` (called only when `SPELL_ID_AUTO_CORRECT` is `true`) iterates `loginContext.spellIdMap` and writes `tracingSpells[correctedId]` / `tracingSpells[staticId]` using numeric spellIds as keys. Since Phase 24 changed `tracingSpells` to be name-keyed (`spellName -> true`), the condition `macroTorch.tracingSpells[staticId]` on line 129 always evaluates to `nil` (falsy), making the migration block a permanent no-op. However, if any name-keyed entry somehow contains a truthy numeric sub-key, or if future code re-populates numeric keys in `tracingSpells`, line 130 would write a numeric key, violating the Phase 24 contract (all keys must be strings) and causing the K1 self-test to fail. The migration logic should either be removed or updated to operate on the name-keyed model.

**Fix:** Since `SPELL_ID_AUTO_CORRECT` is `false` by default and this code path is deprecated, the safest fix is to add a guard that skips migration entirely when `tracingSpells` is name-keyed, or to remove the migration block outright:

```lua
-- Option A: Guard against name-keyed tracingSpells (defensive)
if macroTorch.tracingSpells then
    -- Phase 24+: tracingSpells is name-keyed; spellId migration is a no-op.
    -- Legacy migration preserved for sessions that still use numeric keys.
    local hasNumericKeys = false
    for k in pairs(macroTorch.tracingSpells) do
        if type(k) == "number" then hasNumericKeys = true; break end
    end
    if hasNumericKeys then
        for spellName, correctedId in pairs(macroTorch.loginContext.spellIdMap) do
            -- ... existing migration code ...
        end
    end
end

-- Option B: Remove the loop (preferred — dead code in Phase 24)
-- The entire lines 126-134 migration block is a no-op in the name-keyed model
-- and should be deleted. Retain only the SM_EXTEND binding above it.
```

---

## Info

### IN-01: `PLAYER_TARGET_CHANGED` handler missing nil guard for `macroTorch.player` / `macroTorch.target`

**File:** `core/events.lua:73-81`
**Issue:** The handler accesses `macroTorch.player.isInCombat` and `macroTorch.target.isCanAttack` without nil-guarding `macroTorch.player` or `macroTorch.target`. While these are initialized at file load time (entity/Player.lua:635 and entity/Target.lua) before any events fire in normal operation, a defensive nil guard would protect against edge cases (zone transitions, addon reload timing) and align with the pattern used elsewhere in the codebase (e.g., `recordCastTable` guards `macroTorch.target.isCanAttack`).

**Fix:**
```lua
elseif event == 'PLAYER_TARGET_CHANGED' then
    if macroTorch.player and macroTorch.player.isInCombat
        and macroTorch.target and macroTorch.target.isCanAttack then
        -- ... existing logic ...
    end
end
```

---

### IN-02: Unreachable elseif branch for unregistered events

**File:** `core/events.lua:178-180`
**Issue:** The `eventHandle` function contains an elseif branch for `CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES` and `CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE`, but neither event is registered at the top of the file. This branch will never execute and is dead code. The corresponding events (`CHAT_MSG_COMBAT_SELF_MISSES`, `CHAT_MSG_SPELL_SELF_DAMAGE`) are registered but use a different branch (line 94). These event names appear to be the "creature vs self" variants that are not subscribed.

**Fix:** Remove the dead elseif branch or register the events if monitoring is intended.

---

### IN-03: Production `macroTorch.show()` debug messages visible to users

**File:** `core/combat_context.lua:26,34,80`
**Issue:** Three calls to `macroTorch.show()` ("Exiting combat!", "Entering combat!", "Target change in combat!") produce user-visible chat output during normal gameplay. These are developer-facing debug messages that spam the default chat frame during combat. They should use `macroTorch.log()` (from `interface_debug.lua:103`) instead, which routes to the debug output channel without cluttering the player's chat.

**Fix:**
```lua
macroTorch.log('Exiting combat!')
macroTorch.log('Entering combat!')
macroTorch.log('Target change in combat!')
```

---

### IN-04: DEBUG init trace messages in production code

**Files:**
- `entity/Player.lua:18,21,634,637`
- `macro_torch.lua:23`

**Issue:** Five `DEFAULT_CHAT_FRAME:AddMessage` calls with "[macro-torch] init step N" messages are present in production code. These trace the addon initialization sequence and are visible to users on every login. They should be removed or converted to `macroTorch.log()` calls for production.

**Fix:** Remove the `DEFAULT_CHAT_FRAME:AddMessage` calls entirely, or wrap them in a debug build guard:
```lua
-- Option: Wrap in conditional
if macroTorch.DEBUG_INIT_TRACE then
    DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step N: ...", 0, 1, 0)
end
```

---

### IN-05: Duplicate self-test logic in Category J (J3 and J5)

**File:** `core/selftest.lua:596-600,607-611`
**Issue:** Test J3 ("catLeveling invocation does not error") and test J5 ("catLeveling clickContext has all required fields") both call `macroTorch.catLeveling` via `pcall` and assert `ok`. J5 differs only in its assertion message and `isOptional=true` flag. The duplicate invocation produces no additional coverage -- a single test covering both the invocation and the clickContext fields would suffice and avoid redundant execution.

**Fix:** Merge J5 into J3 by adding the clickContext field assertion to J3:
```lua
macroTorch.SelfTest:register("J: catLeveling invocation does not error (clickContext correctness)", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(macroTorch.catLeveling)
    assert(ok, "catLeveling should not error: " .. tostring(err))
    -- Also verify clickContext fields (merged from J5)
    if macroTorch.clickContext then
        assert(macroTorch.clickContext.spellQueue ~= nil,
            "clickContext missing spellQueue")
    end
end, false)
```

---

### IN-06: Outdated comment in `recordCastTable` about double-recording dedup

**File:** `core/spell_trace_core.lua:136-137`
**Issue:** The comment says the 0.2s dedup "prevents double-recording when both UNIT_CASTEVENT and UNIT_SPELLCAST_SUCCEEDED fire." However, after Phase 24, `UNIT_CASTEVENT` no longer calls `recordCastTable` -- only `UNIT_SPELLCAST_SUCCEEDED` does. The dedup logic still serves a purpose (guarding against multiple fires of the same event), but the comment references an outdated dual-event concern.

**Fix:**
```lua
-- dedup: skip if same spell on same mob within 0.2s
-- prevents double-recording from duplicate UNIT_SPELLCAST_SUCCEEDED firings
```

---

_Reviewed: 2026-08-17T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_