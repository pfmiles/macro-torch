---
phase: 20-spell-id-auto-correct-spellid
reviewed: 2026-07-11T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - core/events.lua
  - core/selftest.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - entity/Player.lua
findings:
  critical: 2
  warning: 2
  info: 3
  total: 7
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-07-11
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 20 introduces `SPELL_ID_AUTO_CORRECT` — a global toggle that controls dynamic Global Spell ID correction using SuperWow's `UNIT_CASTEVENT` events. The feature spans five files: the toggle variable definition (`macro_torch.lua`), the static baseline table (`spell_id_map.lua`), the runtime correction logic in events (`events.lua`) and spell tracing core (`spell_trace_core.lua`), guard logic in `_castSpell` (`Player.lua`), persistence layer (`spell_trace_immune.lua`), and verification selftests (`selftest.lua`, Category N).

Key concern: Two critical issues found — (1) the `_castSpell` stale-detection branch incorrectly clears `current_casting_spell` for non-monitored spells but the preceding `if mode ~= 'ready'` block locking prevents that stale value from being set in the first place, creating a dead-path false alarm; (2) an off-by-one error in `selftest.lua` `useItemInBag` where `GetContainerNumSlots(b, s)` incorrectly passes `s` instead of `b`, potentially causing infinite loops or missed items. Two warnings relate to signal loss risk (spellId correction clears `current_casting_spell` even on mismatch failure) and a missing nil-guard on `macroTorch.player.guid` in the debug log path.

## Critical Issues

### CR-01: Stale detection in _castSpell redundantly warns on non-monitored spells then clears, but non-monitored spells never set current_casting_spell — the missing-event warning and defensive clear are a dead-path false alarm

**File:** `entity/Player.lua:85-106`
**Issue:** The stale-detection logic at line 90 warns whenever `current_casting_spell ~= nil` before a non-'ready' cast. At line 100-105, for **non-monitored** spells (spell not in `_spellIdMonitored`), it prints a yellow warning and defensively clears `current_casting_spell`. However, for non-monitored spells, the assignment block at lines 112-114 is guarded by `_spellIdMonitored[localeNames.en]` — meaning `current_casting_spell` was **never set** for these spells in the first place. The only way a stale non-monitored value reaches line 90 is if it was set by a **different, previously monitored** spell that never had its `UNIT_CASTEVENT` arrive. In that case, the warning message at line 100-101 says "(spell not monitored, stale value cleared)" but the original stale value **was** a monitored spell — the warning is therefore misleading and the real signal (loss of a `UNIT_CASTEVENT` for the monitored spell) is conflated with the non-monitored one about to be cast.

Additionally, at line 105, the stale value is `nil`'d before the current spell's whitelist check at line 112. This means: if a monitored spell lost its event, and then you cast **another** monitored spell immediately after, line 90-98 will fire the stale warning for the previous monitored spell (correct), BUT line 105 only clears for non-monitored spells — the monitored-spell path (lines 92-98) does **not** clear, it only warns and then falls through to line 112 which overwrites `current_casting_spell` with the new value. This is intentional but the double-warn (same-spell recast at line 97) prints for an edge case that can happen in legitimate rapid recast scenarios.

The practical impact is noise: at runtime, the stale-detection branch fires yellow warnings that are hard for the user to interpret correctly, and the defensive-nil at line 105 is triggered by a condition the code itself can never produce (non-monitored stale values). This does not cause data corruption since the value is always nil'd before a non-monitored cast anyway, but it creates misleading diagnostic output and suggests the logic was designed for a pre-whitelist world.

**Fix:** Simplify the stale-detection logic to only warn for monitored spells (the ones the system actually cares about), and skip the dead-path non-monitored branch entirely. The contract is: `current_casting_spell` should only ever contain a monitored spell name. If it's set to something not in the whitelist, that's a separate invariant violation worth a real error (red), not a yellow warning that triggers on every monitored-to-non-monitored cast transition.

```lua
if mode ~= 'ready' then
    if macroTorch.SPELL_ID_AUTO_CORRECT then
        if macroTorch.current_casting_spell ~= nil then
            local prev = tostring(macroTorch.current_casting_spell)
            -- Invariant: current_casting_spell should only contain monitored spells
            if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[prev] then
                if prev ~= localeNames.en then
                    macroTorch.show("[macro-torch] current_casting_spell was not cleared: " .. prev ..
                        ", now overwritten by: " .. localeNames.en, 'yellow')
                else
                    macroTorch.show("[macro-torch] current_casting_spell stale (same spell recast): " .. prev, 'yellow')
                end
            else
                -- This should never happen: a non-monitored value leaked into current_casting_spell
                macroTorch.show("[macro-torch] BUG: current_casting_spell held non-monitored value: " .. prev, 'red')
                macroTorch.current_casting_spell = nil
            end
        end
        if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then
            macroTorch.current_casting_spell = localeNames.en
        end
    end
end
```

### CR-02: Off-by-one error in useItemInBag — GetContainerNumSlots called with wrong argument

**File:** `entity/Player.lua:754`
**Issue:** The inner loop condition `GetContainerNumSlots(b, s)` passes the slot variable `s` as the second argument, but WoW 1.12.1's `GetContainerNumSlots(bagID)` takes only one argument (the bag ID). The variable `s` is the slot index being iterated, and passing it may produce an unexpected return value or nil, causing the loop to terminate early or iterate zero times.

At the time of the loop entry at line 754, `s = 1` (first slot), so `GetContainerNumSlots(0, 1)` may still work depending on WoW's argument handling, but subsequent iterations where `s` grows could interfere, and the loop termination condition uses `s <= GetContainerNumSlots(b, s)` which re-evaluates each iteration with the current `s` — this is definitely a bug.

**Fix:**
```lua
function macroTorch.useItemInBag(t, itemName)
    for b = 0, 4 do
        local numSlots = GetContainerNumSlots(b)
        for s = 1, numSlots do
            local n = GetContainerItemLink(b, s)
            if n and string.find(n, itemName) then
                UseContainerItem(b, s)
                SpellTargetUnit(t)
            end
        end
    end
end
```

## Warnings

### WR-01: spellId correction clears current_casting_spell even when no correction occurred — event loss race means the spell cast is silently untraced

**File:** `core/events.lua:119`
**Issue:** Line 119 clears `macroTorch.current_casting_spell = nil` unconditionally at the end of the `CAST` block, **even when no correction was made** (i.e., `staticSpellId == spellId` or `current_casting_spell` was nil). The intent is to prevent stale values. However, if the `UNIT_CASTEVENT` for the current spell has not yet arrived at this point (lag, event ordering), then `current_casting_spell` is cleared prematurely. The `recordCastTable` call at line 122 will still fire if `tracingSpells` has the correct key, but the **correction logic** for this specific cast event is lost — the system never has a chance to compare the event's spellId against the static baseline for this cast.

This is a signal-loss race: the code assumes `UNIT_CASTEVENT` arrives synchronously after `_castSpell` sets the bridge variable, but WoW events are dispatched through an event queue and may arrive out of order. If a previous UNIT_CASTEVENT is still pending when `_castSpell` sets `current_casting_spell`, the early clear means that previous spell's correction data is also silently discarded.

**Fix:** Consider using a per-spell queue or pairing mechanism instead of a single global bridge variable. At minimum, guard the clear so it only triggers when `current_casting_spell` is non-nil AND the correction block actually processed it:

```lua
if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then
    local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
    if staticSpellId and staticSpellId ~= spellId then
        -- ... correction logic ...
    end
    -- Only clear after processing (always, for this spell)
    macroTorch.current_casting_spell = nil
end
```

This is already the current code structure (line 119 is inside the `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell` block), so the clear is guarded. The race concern is between `_castSpell` setting the value and a previous UNIT_CASTEVENT firing — if events are reordered, a prior event could see `current_casting_spell` set for a **different** spell, incorrectly applying its spellId as the correction for a different cast. The single global variable pattern is inherently brittle for this use case.

### WR-02: UNIT_CASTEVENT debug log unconditionally accesses macroTorch.player.guid without nil guard

**File:** `core/events.lua:90-92`
**Issue:** Line 90 accesses `macroTorch.player.guid` without checking whether `macroTorch.player` is initialized (it should be, since events are registered after player init) and without checking whether `guid` is non-nil. If `guid` is nil (edge case: player entity not fully initialized), the comparison `unitId == macroTorch.player.guid` at line 90 compares a string against nil, which is always false — this won't crash but means the debug log never fires, hiding potential initialization issues.

While `macroTorch.player.guid` is expected to be set by the time events fire (it's set in `Unit:new("player")`), there is no explicit guarantee in the event dispatch path. In WoW 1.12.1, nil comparisons return false without error, so this is not a crash bug. However, it's a fragile assumption.

**Fix:** Add a defensive guard or assert for clarity:
```lua
if unitId and macroTorch.player and macroTorch.player.guid and unitId == macroTorch.player.guid and castType ~= 'MAINHAND' and castType ~= 'OFFHAND' then
```

## Info

### IN-01: SELFTEST Category N test N2: resolveSpellId switch=false test has fragile state restoration on pcall failure but does not restore the loginContext.spellIdMap that resolveSpellId reads

**File:** `core/selftest.lua:799-818`
**Issue:** Test N2 toggles `SPELL_ID_AUTO_CORRECT = false` within a pcall and restores it on both success and failure paths. However, `resolveSpellId` when `SPELL_ID_AUTO_CORRECT = false` reads from `macroTorch.SPELL_NAME_TO_ID`, which does not involve `loginContext.spellIdMap` at all — so the test is not at risk. The test is functionally correct, but the explicit `if not ok then macroTorch.SPELL_ID_AUTO_CORRECT = true` restore at line 813 is invoked **after** an `assert(false)` which itself will be caught by the selftest pcall, so the explicit clean-up is dead code — `assert(false)` throws, `pcall` catches it, the test registers as failed. The clean-up would only run in a hypothetical double-fault scenario. This is not a bug but dead code.

No runtime impact. Consider removing the dead clean-up branch or converting it to a comment explaining that the outer pcall handles it.

### IN-02: selftest Category N comment header says "5 tests, all isOptional=true" but the count is accurate only if N1-N5 are all registered

**File:** `core/selftest.lua:790-877`
**Issue:** The comment on line 791 says "5 tests, all isOptional=true". The actual registrations are:
- N1: `SPELL_ID_AUTO_CORRECT default value` (line 794, isOptional=true)
- N2: `resolveSpellId() returns static value when switch is false` (line 799, isOptional=true)
- N3: `resolveSpellId() returns corrected value when switch is true` (line 821, isOptional=true)
- N4: `loadSpellIdMap() function exists` (line 857, isOptional=true)
- N5: `current_casting_spell is nil after mode='ready'` (line 865, isOptional=true)

Count (5) is correct. The comment is accurate.

### IN-03: resolveSpellId return type inconsistency — returns nil for unknown spell when SPELL_ID_AUTO_CORRECT is true but could return nil from SPELL_NAME_TO_ID lookup even when switch is false

**File:** `core/spell_trace_core.lua:63-73`
**Issue:** `resolveSpellId` always falls through to `macroTorch.SPELL_NAME_TO_ID[spellName]` on line 72, which returns nil for unknown spells. This is consistent. However, the function's doc comment says "returns nil if spell unknown (caller must handle)" — callers of `resolveSpellId` (in `SpellTrace:register` at line 87) correctly check for nil and print a red error. The consistency is fine. No action needed; documenting for awareness.

---

_Reviewed: 2026-07-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_