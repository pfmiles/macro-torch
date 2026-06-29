---
phase: quick
plan: 260629-w2b-fix-spellid-correction-locale-key-mismat
subsystem: spell_trace
tags:
  - bugfix
  - spellId
  - locale
  - tracing
requires: []
provides:
  - spellId-correction-stability
affects:
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - entity/Player.lua
tech-stack:
  added: []
  patterns:
    - nil-guard-consistency
key-files:
  created: []
  modified:
    - entity/Player.lua
    - core/spell_trace_immune.lua
    - core/spell_trace_core.lua
decisions:
  - "Use localeNames.en for current_casting_spell bridge to ensure English key consistency with resolveSpellId queries"
  - "Migrate tracingSpells keys during loadSpellIdMap to bridge the static-to-corrected ID gap across sessions"
  - "Add nil guard to computeLandTable matching the existing pattern in recordCastTable and recordFailTable"
metrics:
  duration: ~5 min
  completed_date: 2026-06-29
status: complete
---

# Quick Task: Fix 3 spellId Correction Bugs

**One-liner:** Fix locale-dependent key mismatch in spellIdMap, cross-session tracingSpells migration, and computeLandTable nil guard consistency.

## Tasks Completed

### Task 1: Fix locale-dependent key in current_casting_spell bridge (entity/Player.lua:83)

**Problem:** `_castSpell` set `current_casting_spell = spellName` where `spellName` is locale-dependent (e.g. `'斜掠'` on zhCN). The correction code in `events.lua` would store the Chinese name as the key in `spellIdMap`, but `resolveSpellId` always queries with the English name from `config.spellName`. This caused the Chinese key to never be found by English queries.

**Fix:** Changed line 83 from `macroTorch.current_casting_spell = spellName` to `macroTorch.current_casting_spell = localeNames.en`. The bridge variable now always carries the English name, matching how `resolveSpellId` queries.

### Task 2: Cross-session tracingSpells stale keys migration (core/spell_trace_immune.lua:119-131)

**Problem:** `SpellTrace:register` runs at script load time (before `loginContext` exists), so it always uses static IDs from `SPELL_NAME_TO_ID`. After the first session corrects a spellId (e.g., Rake: 1822 -> 20789) and persists it to `SM_EXTEND`, the next session loads the correction via `loadSpellIdMap()` into `loginContext.spellIdMap`, but no one migrates the `tracingSpells` keys. Result: `tracingSpells[1822] = 'Rake'` while `UNIT_CASTEVENT` reports `spellId=20789` -- lookup fails and all casts are silently lost.

**Fix:** After binding `loginContext.spellIdMap` in `loadSpellIdMap()`, iterate over all corrections. For each corrected spell whose static ID differs from the persisted ID and has an entry in `tracingSpells` at the static key, migrate the entry to the corrected key and delete the stale static key.

### Task 3: computeLandTable missing loginContext nil guard (core/spell_trace_core.lua:150-152)

**Problem:** `recordCastTable` and `recordFailTable` both have nil guards on `macroTorch.loginContext`, but `computeLandTable` did not. While `maintainLandTables` gates on `inCombat` (and combat can't start before `PLAYER_ENTERING_WORLD`), this inconsistency was a maintenance risk.

**Fix:** Added `if not macroTorch.loginContext then return end` guard, matching the pattern in `recordCastTable` and `recordFailTable`.

## Verification

- `./build.sh` completed successfully with no syntax errors
- Changes are limited to the exact 3 lines/passages specified
- No behavioral change to existing code paths -- only bug fixes and defensive guards

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
