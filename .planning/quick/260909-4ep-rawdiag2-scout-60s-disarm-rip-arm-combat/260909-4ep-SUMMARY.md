---
phase: quick-260909-4ep-rawdiag2-scout-rip-arm-combat
plan: 01
subsystem: diagnostics
tags: [rawdiag2, forensics, rip, combat-log, lua]

# Dependency graph
requires:
  - phase: quick-260907-mhh
    provides: RAWDIAG2 Rip-landing forensics scout (armed by Rip cast record in core/spell_trace_core.lua, dumped in core/events.lua RAW_COMBATLOG branch)
  - phase: quick-260909-2kd
    provides: 150-line acquisition cap already removed (139250b/dfd7bd7); rests the arm window on the surviving 60s timed disarm that this quick removes
  - phase: quick-260907-vve
    provides: macroTorch.LOG_MAX_SIZE rotating-buffer cap (user-raised to 2000 per session — the volume sink that makes a full-fight armed dump safe now that the timed bound is gone)

provides:
  - RAWDIAG2 scout with per-combat arming: arms on the fight's in-combat Rip cast and stays armed until combat exit wipes macroTorch.context — no timed disarm branch survives, so refresh-apply and second-cat tick evidence streams for the whole fight
affects: [quick-260907-mhh, 260909-2kd, macro-torch-log, rawdiag2-forensics]

# Actuals (#2632) — plan estimate: tokens 30000, tasks 3, confidence low
actuals:
  tokens: 1092   # chars/4 over the realized two-file diff (4368 chars both sides of added+removed line content)
  tasks: 3       # tasks completed
  commits: 2     # per-task atomic commits (plan success-criteria example suggested 1 combined)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Instrumentation honesty under deletion: the arming log literal is the segment marker ('until combat exit' — one armed line per fight now that no disarm line exists), and comments state the real contract so grep-based contract gates stay greppable"

key-files:
  created: []
  modified:
    - core/events.lua
    - core/spell_trace_core.lua

key-decisions:
  - "Code edits follow the plan's verbatim replacement spec exactly (EDIT A 3->6 header lines, EDIT B 5-line disarm-branch deletion, EDIT C 23-line capture dedent + orphan-end removal; spell_trace EDIT A 3->5 comment lines, EDIT B arming literal). The plan's T1 parenthetical (32 removed / 29 added) is git-alignment-naive: the 23-line dedent realizes as 22 remove/add pairs because the 12-space 'end' closing the capture body pairs with the old orphan 'end' as context — actual numstat 27 added / 30 removed, difference 3 (the value the gate asserts) holds, so no code was altered to force numbers"
  - "Committed per task atomically (two commits, one file each) instead of the plan example's single combined commit, per the executor's per-task atomic-commit constraint and the established 260909-2kd precedent; the union of files across the two commits is exactly the two allowed files"

patterns-established:
  - "Contract descriptors in comments refer to arming as 'until combat exit' and to refresh as coming from Ferocious Bite (not a Rip recast) so the timed-window wording never reappears in grep gates"

requirements-completed:
  - QUICK-260909-4EP

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "RAWDIAG2 scout in core/events.lua loses the fixed sixty-second arm window entirely: no GetTime-elapsed compare, no _rawdiag2Active = false assignment, no disarm log statement, no else; the capture body runs directly under the if scoutActive guard; counters (_rawdiag2Lines/_rawdiag2Samples) and the arming timestamp survive"
    requirement: "QUICK-260909-4EP"
    verification:
      - kind: other
        ref: "T1 automated verify gate — node bbcheck.js core/events.lua (BALANCED) + zero '> 60' / '60s' / 'scout disarmed after' / '_rawdiag2Active = false' / GetTime-elapsed + 1 scoutActive guard + both counters + region gate (no 6-0 digits beyond provenance tag, no else) + serialization-first body + numstat difference 3 + Lua 5.0 token gate + git diff --check"
        status: pass
    human_judgment: true
    rationale: "The static gates pass on this host, but the decisive proof — the scout staying armed for the whole fight with no '[RAWDIAG2] scout disarmed' line at all, one '[RAWDIAG2] scout armed by Rip cast record, until combat exit' segment per fight, refresh-apply and second-cat tick lines streaming for the whole fight — can only be observed in game on the user's Windows+Cygwin machine (weekly-CD paced evidence per user_setup). This host cannot run WoW 1.12/SuperWoW."
  - id: D2
    description: "RAWDIAG2 arming literal in core/spell_trace_core.lua reads 'until combat exit'; arming comment block states the per-fight capture contract with zero '60s' wording; the four arming assignments stay byte-identical; pair-ledger comment untouched"
    requirement: "QUICK-260909-4EP"
    verification:
      - kind: other
        ref: "T2 automated verify gate — node bbcheck.js core/spell_trace_core.lua (BALANCED) + new literal grep + comment block 120-145 contains 'until combat exit' + zero '60s' in file + one each of _rawdiag2Active=true/_rawdiag2Lines/_rawdiag2Samples/_rawdiag2Start + numstat added-minus-removed 2 + Lua 5.0 token gate + git diff --check"
        status: pass
    human_judgment: true
    rationale: "Same in-game dependency as D1: the arming line is only emitted by a live in-combat Rip cast on the user's machine (next CD forensics session)."
  - id: D3
    description: "Combined sterility: both bbcheck runs BALANCED, combined added lines carry no #/goto/:: and no CJK, git diff --check clean, no CR bytes (LF preserved), SM_Extend.lua byte-identical to HEAD, only the two allowed Lua files changed, no stale '150' token"
    verification:
      - kind: other
        ref: "Battery automated verify gate — node bbcheck.js on both files + whole-diff Lua 5.0 token gate + git diff --check + CRLF scan + CJK scan + git diff --quiet HEAD -- SM_Extend.lua + git diff --name-only HEAD -- '*.lua' file allow-list + '150' grep"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-09-09
status: complete
---

# Quick Task 260909-4ep: RAWDIAG2 Scout Drops the 60s Timed Disarm — Arming Runs Until Combat Exit

Replaced the forensics scout's fixed sixty-second arm window with per-combat arming: the scout
arms on the fight's in-combat Rip cast and stays armed until combat exit. The player rotation
casts Rip only once per fight (Ferocious Bite refreshes), so the old timed disarm expired
mid-fight in long combats and silently muted the refresh-apply lines and second-cat tick
evidence — the exact evidence quick 260907-mhh built the scout to capture. `macroTorch.context`
being wiped on leaving combat (combat_context.lua reset) is now the scout's only disarm path.

## Tasks Completed

| Task | Name | Commit | Verify |
|------|------|--------|--------|
| 1 | Delete the timed-disarm branch from the RAWDIAG2 scout (core/events.lua) | 95eb3a3 | `core/events.lua: BALANCED` → `T1 GATE OK` (exit 0) |
| 2 | Update arming literal + comment block to the until-combat-exit contract (core/spell_trace_core.lua) | 69a0954 | `core/spell_trace_core.lua: BALANCED` → `T2 GATE OK` (exit 0) |
| 3 | Closing battery over the combined uncommitted diff (no file edits) | — (gate ran pre-commit on the combined diff) | `core/events.lua: BALANCED`, `core/spell_trace_core.lua: BALANCED` → `BATTERY OK` (exit 0) |

All three automated verify gates were run before committing (Task 3's battery measured the
combined uncommitted diff for real content) and every gate exited 0 with its required echo.

## Verification Output

**T1 gate (core/events.lua)** — `T1 GATE OK`:
- bbcheck: `core/events.lua: BALANCED`
- zero occurrences of `> 60`, `60s`, `scout disarmed after`, `_rawdiag2Active = false`,
  `GetTime() - (scoutCtx._rawdiag2Start`; exactly 1 `if scoutActive then`; both counter names present
- region gate (scout block, provenance excluded): zero '6'+'0' digit lines, zero `else`
- `-- serialize every event arg` follows `local scoutCtx = macroTorch.context` directly
- numstat removed-minus-added = 3 (realized 30 removed / 27 added — see Deviations); no `#`/goto/`::` in added lines; `git diff --check` clean

**T2 gate (core/spell_trace_core.lua)** — `T2 GATE OK`:
- bbcheck: `core/spell_trace_core.lua: BALANCED`
- arming literal reads `[RAWDIAG2] scout armed by Rip cast record, until combat exit`
- comment block lines 120-145 carries the until-combat-exit contract; zero `60s` tokens in the whole file
- exactly one `_rawdiag2Active = true`, one `_rawdiag2Lines`, one `_rawdiag2Samples`, one `_rawdiag2Start`
- numstat added-minus-removed = 2 (6 added / 4 removed); token gate + `git diff --check` clean

**Battery (both files)** — `BATTERY OK`:
- bbcheck `BALANCED` on both; combined added lines carry no `#`/goto/`::` and no CJK
- `git diff --check` clean; no CR byte in either file (LF preserved)
- `SM_Extend.lua` byte-identical to HEAD (never touched, never rebuilt — no build script was run anywhere in this plan)
- only `core/events.lua` and `core/spell_trace_core.lua` appear in the Lua file diff; no stale `150` token

## Deviations from Plan

None blocking. Two documentation-grade notes:

1. **T1 numstat parenthetical is git-alignment-naive (30 removed / 27 added, not 32 / 29)**
   The plan's EDIT A/B/C were realized byte-verbatim, but git's diff alignment pairs the dedent
   block's 12-space `end` (closing `if interesting`) with the old orphan `end` as context, so the
   23-line dedent realizes as 22 remove/add pairs. Actual numstat is 27 added / 30 removed; the
   gate-asserted difference of 3 holds exactly, and T1 echoed `T1 GATE OK`. Same class of variance
   as 260909-2kd deviation #1 — no code was altered to force numbers.
2. **Commit granularity: 2 per-task commits instead of the plan example's single combined commit**
   The executor constraint mandates per-task atomic commits; precedent 260909-2kd did the same.
   Commits: 95eb3a3 (core/events.lua only), 69a0954 (core/spell_trace_core.lua only). The union of
   files is exactly the two allowed files, so sterility is preserved.

## Issues Encountered

None.

## User Setup Required

None on this host beyond what is staged in the plan's `user_setup` (user-side, weekly-CD paced):

1. Run `build.sh` on Windows+Cygwin to regenerate SM_Extend.lua into both AddOns dirs (this repo's
   SM_Extend.lua is NOT rebuilt here, per established quick-task convention).
2. Next CD forensics session: `/run macroTorch.rawdiag2Enabled=true` and cast an in-combat Rip —
   the scout must now stay armed until combat exit, emitting no `[RAWDIAG2] scout disarmed` line at
   all; each fight is marked by one `[RAWDIAG2] scout armed by Rip cast record, until combat exit`
   line, and refresh-apply lines plus second-cat ticks keep streaming for the whole fight into
   MACRO_TORCH_LOG (LOG_MAX_SIZE 2000 raised in game).

## Next Phase Readiness

- No follow-up code work defined; the remaining evidence gathering is the scheduled in-game
  validation above.