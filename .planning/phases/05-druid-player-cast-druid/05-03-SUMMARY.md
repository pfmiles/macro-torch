---
phase: 05-druid-player-cast-druid
plan: 03
subsystem: druid-combat
tags: [druid, spell-refactor, cat-form, call-site-migration]
requires: [05-02]
provides: [typed-skill-method-calls-in-cat-And-druid]
affects: [classes/druid/cat.lua, classes/druid/Druid.lua]
tech-stack:
  added: []
  patterns:
    - "Mode-based skill method calls (nil='ready', 'safe'=energy+distance, 'raw'=no checks)"
    - "Snapshot side effects preserved in caller context before skill method invocation"
key-files:
  created: []
  modified:
    - classes/druid/cat.lua
    - classes/druid/Druid.lua
decisions:
  - "Deleted 5 wrapper functions: safeShred, readyShred, safeClaw, readyClaw, safePounce"
  - "Kept safeRake/safeRip/safeTigerFury/safeBite/safeCower/readyCower for their side effects and external preconditions"
  - "Used 'raw' mode for kill shot (Ferocious Bite) and safeFF (Faerie Fire) to avoid double-checking with external gates"
  - "safePounce caller in Druid.lua catAtk inlined with isGcdOk+isNearBy checks + player.pounce('safe')"
metrics:
  duration_seconds: 380
  completed_date: "2026-06-13"
---

# Phase 05 Plan 03: Druid Cat Form Call-Site Migration Summary

**One-liner:** Replaced all 5 remaining `player.cast()` calls in cat.lua and Druid.lua with typed skill method calls, deleted 5 safe/ready wrapper functions, and preserved all snapshot side effects -- zero `player.cast()` calls remain in both files.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Replace regularAttack with mode-based calls and delete safeShred/readyShred/safeClaw/readyClaw | `04d520d` | `classes/druid/cat.lua` |
| 2 | Replace player.cast calls in Bite/Pounce/Cower/Reshift and delete safePounce | `6bc107e` | `classes/druid/cat.lua` |
| 3 | Replace safeRake/safeRip player.cast calls AND inline safePounce in Druid.lua catAtk caller | `a0b8931` | `classes/druid/cat.lua`, `classes/druid/Druid.lua` |
| 4 | Replace player.cast('Berserk') in cat.lua burstMod AND player.cast('Faerie Fire (Feral)') in Druid.lua safeFF | `3443258` | `classes/druid/cat.lua`, `classes/druid/Druid.lua` |

## Verification Results

### Overall Verification (Post-Task-4)

| Check | Expected | Actual |
|-------|----------|--------|
| `player.cast(` in cat.lua | 0 | 0 |
| `player.cast(` in Druid.lua | 0 | 0 |
| Key skill method calls in cat.lua | >= 8 | 11 |
| `lastRakeEquippedSavagery` in cat.lua | >= 1 | 1 |
| `lastRipEquippedSavagery` in cat.lua | >= 1 | 1 |
| `tigerTimer` in cat.lua | >= 1 | 1 |
| `safePounce` in both files | 0 | 0 |
| `player.pounce(` in Druid.lua | >= 1 | 1 |
| `player.ravage(` in Druid.lua | >= 1 | 1 |
| `player.berserk(` in cat.lua | >= 1 | 1 |
| `player.faerie_fire_feral(` in Druid.lua | >= 1 | 1 |
| `ffTimer = GetTime()` in Druid.lua | >= 1 | 1 |
| `./build.sh` exit code | 0 | 0 |
| SM_Extend.lua cat functions present | yes | yes |

### Call-Site Replacement Summary

**cat.lua (5 call sites replaced):**
| Call Site | Old | New | Mode | Side Effects Preserved |
|-----------|-----|-----|------|----------------------|
| burstMod | `player.cast('Berserk')` | `player.berserk()` | nil (ready) | none |
| regularAttack | safeShred/readyShred | `player.shred()` / `player.shred('safe')` | nil/safe | none |
| regularAttack | safeClaw/readyClaw | `player.claw()` / `player.claw('safe')` | nil/safe | none |
| readyBite | `player.cast('Ferocious Bite')` | `player.ferocious_bite('ready')` | ready | none (external GCD+proximity) |
| tryBiteKillShot | `player.cast('Ferocious Bite')` | `player.ferocious_bite('raw')` | raw | none (kill shot urgency) |
| readyReshift | `player.cast('Reshift')` | `player.reshift('ready')` | ready | none |
| readyCower | `player.cast('Cower')` | `player.cower('ready')` | ready | none |
| safeTigerFury | `player.cast("Tiger's Fury")` | `player.tiger_fury('ready')` | ready | tigerTimer |
| safeRake | `player.cast('Rake')` | `player.rake('ready')` | ready | lastRakeEquippedSavagery |
| safeRip | `player.cast('Rip')` | `player.rip('ready')` | ready | lastRipEquippedSavagery, lastRipAtCp |

**Druid.lua (2 call sites replaced):**
| Call Site | Old | New | Mode | Side Effects Preserved |
|-----------|-----|-----|------|----------------------|
| catAtk opener | `player.cast('Ravage')` | `player.ravage()` | nil (ready) | none |
| catAtk opener | `macroTorch.safePounce(clickContext)` | `player.pounce('safe')` + inline isGcdOk/isNearBy | safe | none |
| safeFF | `player.cast('Faerie Fire (Feral)')` | `player.faerie_fire_feral('raw')` | raw | ffTimer, external isSpellReady+isGcdOk |

### Functions Deleted (5 total)
- `macroTorch.safeShred` (cat.lua)
- `macroTorch.readyShred` (cat.lua)
- `macroTorch.safeClaw` (cat.lua)
- `macroTorch.readyClaw` (cat.lua)
- `macroTorch.safePounce` (cat.lua)

### Functions Kept (with internal replacements)
- `macroTorch.safeRake` -- snapshot side effects + GCD check preserved, uses `player.rake('ready')`
- `macroTorch.safeRip` -- snapshot side effects + GCD check preserved, uses `player.rip('ready')`
- `macroTorch.safeBite` -- energy gate only, delegates to readyBite
- `macroTorch.readyBite` -- GCD+proximity checks preserved, uses `player.ferocious_bite('ready')`
- `macroTorch.safeTigerFury` -- timer side effect preserved, uses `player.tiger_fury('ready')`
- `macroTorch.readyCower` -- debug show() preserved, uses `player.cower('ready')`
- `macroTorch.safeCower` -- GCD+energy checks preserved, delegates to readyCower
- `macroTorch.safeFF` (Druid.lua) -- isSpellReady+isGcdOk+ffTimer preserved, uses `player.faerie_fire_feral('raw')`

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- no hardcoded empty values, placeholder text, or unwired components were introduced.

## Threat Flags

None -- no new attack surface introduced. All changes are pure call-site replacements within existing functions.

## Self-Check: PASSED

- All modified files exist: `classes/druid/cat.lua`, `classes/druid/Druid.lua`
- All 4 commits verified in git log
- SM_Extend.lua produced by build.sh exists and contains updated functions
- All grep assertions pass per verification table