---
phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi
plan: 01
subsystem: api
tags: [lua, wow-addon, metatable, colon-dot-syntax, _castSpell, isSpellReady, Druid, selftest]

# Dependency graph
requires:
  - phase: 05-druid-player-cast-druid
    provides: "_castSpell/_isInRange/_hasResource method design with dot syntax definitions"
provides:
  - Fixed _castSpell internal calls using correct dot syntax (obj.isSpellReady, obj._isInRange, obj._hasResource, obj.cast)
  - Fixed all 53 Druid skill methods using obj._castSpell dot syntax instead of self:_castSpell
  - 15 Category F selftest tests verifying metatable chain integrity for _castSpell resolution
affects: [any future Druid spell-casting work, any future class file using _castSpell pattern]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Closure-based OOP: dot syntax (obj.method(args)) must be used when calling methods defined with dot syntax inside constructor closures. Colon syntax (self:method(args)) desugars to self.method(self, args), inserting the closure upvalue self (class prototype table) as an extra first argument, shifting all intended parameters by one position."

key-files:
  created: []
  modified:
    - entity/Player.lua
    - classes/druid/Druid.lua
    - core/selftest.lua

key-decisions:
  - "Fix only call sites, not method definitions — definitions were correct, calls were wrong"
  - "Use obj upvalue for internal calls within _castSpell, preserving self.mana in _hasResource for mana computation via Player prototype ref"
  - "All 15 Category F tests use UnitClass('player') ~= 'Druid' guard to safely skip on non-Druid characters"

patterns-established:
  - "Category F selftest: metatable chain integrity pattern — verify that methods resolve through classMetatable __index chain (FIELD_FUNC_MAP -> cls -> parent) without parameter misalignment"

requirements-completed: [R8, D-01, D-02, D-03, D-04, D-05, D-06]

# Metrics
duration: 5min
completed: 2026-06-14
---

# Phase 06 Plan 01: Colon/Dot Syntax Mismatch Fix Summary

**Fix 4 `self:xxx()` calls in `_castSpell` and 53 `self:_castSpell()` calls in Druid skill methods — all Druid spell casting silently failed because colon syntax injected class prototype as extra first argument**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-14T14:36:00Z
- **Completed:** 2026-06-14T14:41:01Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- entity/Player.lua: 4 internal `self:xxx()` calls in `_castSpell` replaced with `obj.xxx()` — fixes parameter misalignment where `self:isSpellReady(spellName)` passed class prototype as first argument, making `SpellReady(table)` always return nil
- classes/druid/Druid.lua: 53 `self:_castSpell(...)` calls replaced with `obj._castSpell(...)` — fixes parameter shift where Druid class prototype was passed as localeNames argument
- core/selftest.lua: 15 Category F tests added verifying metatable chain resolution and skill method invocation integrity

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix _castSpell internal calls — self:xxx() to obj.xxx()** - `968c2e1` (fix)
2. **Task 2: Fix Druid skill methods — self:_castSpell to obj._castSpell** - `7668163` (fix)
3. **Task 3: Add Category F selftest tests** - `cc67f09` (test)

## Files Created/Modified
- `entity/Player.lua` - 4 lines changed (lines 52, 59, 69, 79): `self:isSpellReady` -> `obj.isSpellReady`, `self:_isInRange` -> `obj._isInRange`, `self:_hasResource` -> `obj._hasResource`, `self:cast` -> `obj.cast`
- `classes/druid/Druid.lua` - 53 lines changed (lines 26-239): all `self:_castSpell(` -> `obj._castSpell(`
- `core/selftest.lua` - 113 lines added: Category F section with 15 new test registrations

## Decisions Made
- All method definitions (`_castSpell`, `_isInRange`, `_hasResource`, `isSpellReady`, `cast`) remain in dot syntax unchanged — only call sites were fixed
- `_hasResource` line 102 `self.mana` left unchanged — the `self` upvalue in that context correctly resolves to `macroTorch.Player` with `ref="player"`, and `self.mana` computes correctly via the Unit prototype
- External callers (cat.lua, utility.lua, bear.lua, Hunter.lua) required zero changes — all already use dot syntax correctly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all three tasks were straightforward mechanical replacements with verification passing on first attempt.

## User Setup Required

None - no external service configuration required. In-game verification via `/mt` command will run Category F tests.

## Next Phase Readiness
- All Druid skill methods now correctly route through `_castSpell` with proper parameter alignment
- Category F selftest provides automated in-game verification of metatable chain integrity
- Future class files (if any) should follow the `obj._castSpell(...)` dot syntax pattern established here

---
*Phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi*
*Completed: 2026-06-14*