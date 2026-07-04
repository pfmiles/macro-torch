---
phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
plan: 02
subsystem: testing
tags: [lua, wow-addon, _spellIdMonitored, whitelist, selftest, current_casting_spell, spellid-correction, stale-detection]

# Dependency graph
requires:
  - phase: 18-01
    provides: "_spellIdMonitored whitelist table initialization and SpellTrace:register auto-population, current_casting_spell lifecycle variable"
provides:
  - "Whitelist-guarded current_casting_spell assignment in _castSpell — only whitelisted spells trigger spellId correction monitoring"
  - "Stale detection: macroTorch.log warning when current_casting_spell was not cleared by UNIT_CASTEVENT before next cast"
  - "5 Category L selftests verifying _spellIdMonitored table, 4 Druid entries, monitorSpellId flag behavior, and D-05 legacy compatibility"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_castSpell whitelist guard: nil-safe _spellIdMonitored[localeNames.en] lookup before setting current_casting_spell"
    - "Stale detection: pre-overwrite warning via macroTorch.log(message, 'yellow') when previous current_casting_spell was uncleared"
    - "Selftest cleanup pattern for temporary SpellTrace:register entries (L3/L4 tests remove test entries after assertions)"

key-files:
  created: []
  modified:
    - entity/Player.lua
    - core/selftest.lua

key-decisions:
  - "Whitelist guard uses nil-safe short-circuit: macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] — degrades gracefully to no-pollution if whitelist never initialized"
  - "Stale detection runs BEFORE whitelist guard: even non-whitelisted spells get a warning if current_casting_spell was left dirty, catching event-loss bugs"
  - "Stale detection uses macroTorch.log() with 'yellow' color — persistent to SavedVariables for post-session analysis via /mt log"
  - "Category L selftests validate infrastructure-level _spellIdMonitored table; no UnitClass guard needed since the table exists for all classes (even if empty for non-Druid)"
  - "L5 (FF Feral exclusion) marked optional (isOptional=true) because it depends on a Druid.lua registration — non-Druid logins skip it harmlessly"

patterns-established:
  - "Whitelist guard pattern: if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then set current_casting_spell"
  - "Stale detection pattern: pre-set nil check + log warning before overwriting shared state variable"
  - "Temporary registration selftest cleanup: remove test entries from tracingSpells/_spellIdMonitored after assertions in L3/L4"

requirements-completed:
  - REQ-18-D04
  - REQ-18-D05

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Whitelist guard in _castSpell limits current_casting_spell to monitored spells only"
    requirement: REQ-18-D04
    verification:
      - kind: unit
        ref: "grep '_spellIdMonitored and macroTorch._spellIdMonitored' SM_Extend.lua"
        status: pass
    human_judgment: false
  - id: D2
    description: "Stale detection warns via macroTorch.log when current_casting_spell was not cleared"
    requirement: REQ-18-D04
    verification:
      - kind: unit
        ref: "grep 'current_casting_spell was not cleared' SM_Extend.lua"
        status: pass
    human_judgment: false
  - id: D3
    description: "5 Category L selftests validate _spellIdMonitored whitelist behavior"
    requirement: REQ-18-D05
    verification:
      - kind: unit
        ref: "core/selftest.lua Category L section — 5 SelfTest:register calls"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-04
status: complete
---

# Phase 18 Plan 02: _castSpell whitelist guard with stale detection and 5 Category L selftests

**Replaces unconditional current_casting_spell assignment with nil-safe _spellIdMonitored whitelist lookup; adds stale detection warning for event-loss scenarios; validates whitelist with 5 new selftests**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-04T10:10:18Z
- **Completed:** 2026-07-04T10:14:47Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Replaced unconditional `current_casting_spell = localeNames.en` (Phase 17 bridge) with whitelist guard: `if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then` — only whitelisted spells trigger the spellId correction path in events.lua
- Added stale detection: before overwriting `current_casting_spell`, checks if previous value was uncleared (UNIT_CASTEVENT event loss) and logs a persistent warning via `macroTorch.log(message, 'yellow')`
- Added 5 Category L selftests (4 core + 1 optional) validating _spellIdMonitored table existence, 4 Druid land-tracing entries, monitorSpellId flag behavior (exclude when false, include when true), and D-05 legacy config.spellId path exclusion
- Zero config changes to Druid.lua — the 4 land-tracing spell registrations from Phase 17 automatically populate the whitelist via SpellTrace:register's auto-registration logic
- All existing Category K selftests preserved unchanged; build.sh succeeds with all Phase 18 symbols present and old unconditional bridge removed

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace unconditional current_casting_spell with whitelist guard + stale detection** - `2c650b9` (feat)
2. **Task 2: Add Category L whitelist verification selftests (5 tests)** - `6a8d1bf` (test)
3. **Task 3: Build verification** — verification-only, no source changes committed

## Files Created/Modified
- `entity/Player.lua` — Replaced 3-line unconditional bridge (Phase 17 lines 82-84) with stale detection + whitelist guard block (~19 lines). All changes in `_castSpell` internal method; `CastSpellByName` and `obj.cast` calls unchanged.
- `core/selftest.lua` — Added Category L section (72 lines) with 5 SelfTest:register calls between Category K (line 668) and Module 4 /mt SLASH command (line 670). All Category K tests (lines 614-668) preserved intact.

## Decisions Made
- Nil-safety: `macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en]` uses Lua short-circuit to gracefully degrade if whitelist never initialized (never sets current_casting_spell — zero pollution)
- Stale detection order: runs BEFORE whitelist guard, so even non-monitored spells get a warning if current_casting_spell was left dirty by a previous cast
- Log persistence: uses `macroTorch.log()` (not `macroTorch.show()`) for stale warnings — messages persist to SavedVariables for post-session analysis
- Selftest L5 (FF Feral exclusion) is optional (`isOptional=true`) because it depends on Druid.lua registration; non-Druid logins skip it harmlessly
- L3/L4 selftest cleanup: temporary test registrations are removed from tracingSpells/whitelist after assertions to prevent selftest side effects

## Deviations from Plan

None — plan executed exactly as written. All code matches the exact specification in Task 1's `<action>` blocks. All 5 selftests match the descriptions in Task 2's `<action>` specification.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. The whitelist is automatically populated by existing Druid.lua SpellTrace:register calls from Phase 17. No manual whitelist management needed.

## Known Stubs

None.

## Next Phase Readiness
- Phase 18 infrastructure complete: _spellIdMonitored whitelist (Plan 01) + whitelist guard + stale detection (Plan 02) + 10 selftests across Categories K and L
- events.lua's spellId correction logic (line 3735-3759) requires zero changes — it naturally only fires for whitelisted spells since current_casting_spell is only set for whitelisted spells
- Ready for in-game validation of the complete Phase 18 spellId correction pipeline

---
*Phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin*
*Completed: 2026-07-04*