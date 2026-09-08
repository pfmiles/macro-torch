---
phase: quick-260909-2kd-rawdiag2-forensics-scout-150-150-24-fade
plan: 01
subsystem: diagnostics
tags: [rawdiag2, forensics, rip, combat-log, lua]

# Dependency graph
requires:
  - phase: quick-260907-mhh
    provides: RAWDIAG2 Rip-landing forensics scout (armed by Rip cast record in core/spell_trace_core.lua, dumped in core/events.lua RAW_COMBATLOG branch)
  - phase: quick-260907-vve
    provides: macroTorch.LOG_MAX_SIZE rotating-buffer cap (user-raised to 2000 per session — the volume sink that makes the uncapped 60s window safe)
provides:
  - RAWDIAG2 scout whose ONLY disarm condition is the 60s time window; the 150-line acquisition cap is deleted, the _rawdiag2Lines counter survives as a dump statistic
affects: [quick-260907-mhh, rawdiag2-forensics, macro-torch-log]

# Actuals (#2632) — plan carried no `estimate`; recorded for calibration consistency anyway.
actuals:
  tokens: 236    # chars/4 over the realized two-file diff (944 chars both sides)
  tasks: 2       # tasks completed
  commits: 2     # per-task atomic commits (plan example suggested 1 combined)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Forensics instrumentation honesty: diagnostic comments and log literals state the true window contract (60s only); removed limits are referenced as 'line-count cap' without the dead digits so grep-based cap-token gates stay clean"

key-files:
  created: []
  modified:
    - core/events.lua
    - core/spell_trace_core.lua

key-decisions:
  - "Code edits follow the plan's verbatim replacement spec exactly (EDIT A 3->5 comment lines, EDIT B 4-line elseif deletion); the plan's T1 numstat expectation of 7 5 was off by the shared first comment line and was reconciled to the realized 6 removed / 4 added (see Deviations)"
  - "Committed per task atomically (two commits, one file each) instead of the plan example's single combined commit, per the executor's per-task atomic-commit constraint"

patterns-established:
  - "Cap-describer in comments refers to the removed limit as 'line-count cap' so the '150' token never reappears in grep gates"

requirements-completed:
  - QUICK-260909-2KD

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "RAWDIAG2 scout in core/events.lua disarms only on the 60s time window; the 150-line elseif branch is deleted, the dump body is the only else, the header comment states the 60s-only contract, and both counters survive as dump statistics"
    requirement: "QUICK-260909-2KD"
    verification:
      - kind: other
        ref: "T1 automated verify gate — node bbcheck.js core/events.lua (BALANCED) + 8 content sub-checks (1 disarm assignment, 1 dump-stat line, 60s gate line, both counter increments, new comment fragment, zero '150' tokens, diff token gate, git diff --check)"
        status: pass
    human_judgment: true
    rationale: "The static gates pass on this host, but the decisive proof — the scout staying armed for the FULL 60s window in live combat with 'fades' noise observed and exactly one '[RAWDIAG2] scout disarmed after 60s window' line — can only be observed in game on the user's Windows+Cygwin machine (weekly-CD paced evidence per user_setup). This host cannot run WoW 1.12/SuperWoW."
  - id: D2
    description: "RAWDIAG2 arming log literal in core/spell_trace_core.lua states '60s window' (no line cap); arming comment block and pair-ledger comment stay cap-free and untouched"
    requirement: "QUICK-260909-2KD"
    verification:
      - kind: other
        ref: "T2 automated verify gate — node bbcheck.js core/spell_trace_core.lua (BALANCED) + new literal grep + zero '150' tokens + numstat 1 1 + diff token gate + git diff --check"
        status: pass
    human_judgment: true
    rationale: "Same in-game dependency as D1: the arming line is only emitted by a live in-combat Rip cast on the user's machine (next CD forensics session)."
  - id: D3
    description: "Combined sterility: working tree clean, exactly the two allowed source files changed across the two commits, SM_Extend.lua untouched, whole-diff Lua 5.0 token gate and cap-token gate clean"
    verification:
      - kind: other
        ref: "git status --porcelain (clean), git diff --name-only HEAD~2..HEAD (2 files), cap-token grep (CLEAR), whole-diff token gate (OK), git diff --check (CLEAN)"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-09-09
status: complete
---

# Quick Task 260909-2kd: RAWDIAG2 Scout Drops the 150-Line Cap — 60s Window Only

**RAWDIAG2 forensics scout disarms only on its 60s time window: the 150-line acquisition cap branch is deleted from core/events.lua (dump body becomes the else of the time gate), the scout header comment is rewritten to the 60s-only contract, and the arming log literal in core/spell_trace_core.lua now states a plain 60s window — both _rawdiag2 counters survive as dump statistics.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-09-08T17:57Z
- **Completed:** 2026-09-08T18:05Z
- **Tasks:** 2
- **Files modified:** 2 (core/events.lua, core/spell_trace_core.lua)

## Accomplishments

- The melee-scrum 'fades' noise that blew the 150-line cap in ~24s on the live machine can no longer close the evidence window early — 60s is now the ONLY disarm condition (exactly one `_rawdiag2Active = false` assignment remains in core/events.lua, the time-gate one).
- `_rawdiag2Lines` survives as a pure statistic: it still increments on every dumped line and feeds the disarm line's `dumped: N lines` stat and the `line=` label; `_rawdiag2Samples` still gates the first-20 unconditional dump. Nothing is gated on either counter anymore.
- Honest instrumentation text: the scout header comment and the arming log literal both describe a 60s window with no line cap; the token '150' appears nowhere in either file (the removed cap is referenced as "line-count cap").
- Sterile scope: SM_Extend.lua untouched and not rebuilt (per established quick-task convention — the user rebuilds on Windows+Cygwin); the pair ledger, ctx stamp, keyword filter, sample gate, tier-1 whitelist and every production branch are byte-identical.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove the 150-line disarm branch from core/events.lua and rewrite the header comment to 60s-only** - `dfd7bd7` (refactor)
2. **Task 2: Update the RAWDIAG2 arming log literal in core/spell_trace_core.lua to '60s window'** - `139250b` (refactor)

_Note: the plan example suggested one combined commit; per-task atomic commits follow the executor's atomic-commit constraint — see Deviations._

## Files Modified

- `core/events.lua` - deleted the `elseif (scoutCtx._rawdiag2Lines or 0) >= 150 then` disarm branch (4 lines) so the dump body is the only else of the 60s gate; rewrote the scout header disarm sentence (2 cap lines replaced by 4 cap-free lines: "only — quick 260909-2kd removed the former line-count cap, which melee-scrum 'fades' noise could trip inside the window and end the sample early")
- `core/spell_trace_core.lua` - arming log literal changed from `'[RAWDIAG2] scout armed by Rip cast record, 60s / 150-line window'` to `'[RAWDIAG2] scout armed by Rip cast record, 60s window'` (1 line)

## Verification Output (automated gates run per task)

**T1 gate (core/events.lua):** every content sub-check passed — bbcheck `core/events.lua: BALANCED`; exactly 1 disarm assignment; exactly 1 disarm dump-stat line (`tostring(scoutCtx._rawdiag2Lines or 0) .. ' lines'`); 60s time-gate line PRESENT; `_rawdiag2Lines` increment PRESENT; `_rawdiag2Samples` increment PRESENT; new comment fragment `former line-count cap, which melee-scrum` PRESENT; zero '150' tokens (CLEAR); diff +lines carry no `#`/goto/`::` (token gate OK); `git diff --check` clean. The only sub-check that did not hold as written was the numstat expectation (see Deviations — plan arithmetic slip; realized diff is exactly the plan's verbatim spec).

**T2 gate (core/spell_trace_core.lua):** FULL PASS as written — `core/spell_trace_core.lua: BALANCED`, new `'60s window'` literal PRESENT, zero '150' tokens, numstat exactly `1 1`, token gate OK, `git diff --check` clean → `T2 GATE OK`.

**Combined plan-level gates:** `git status --porcelain` clean after both commits; `git diff --name-only HEAD~2..HEAD` = exactly core/events.lua + core/spell_trace_core.lua (SM_Extend.lua count: 0); cap-token gate `CAP TOKEN CLEAR`; whole-diff token gate `TOKEN GATE OK`; `git diff --check` clean; no whole-file deletions.

## Decisions Made

- Followed the plan's verbatim replacement strings exactly for both edits; the plan's own numstat arithmetic for T1 was corrected at verification time (documented below) rather than warping the code to force a wrong number.
- Two per-task atomic commits (one file each) instead of the plan example's single combined commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking check] T1 gate numstat expectation `7 5` is a planner arithmetic slip — realized diff is 6 removed / 4 added**
- **Found during:** Task 1 (verify gate run, pre-commit)
- **Issue:** The plan's EDIT A says "replace 3 lines with 5 lines" and expects the whole-task numstat to be `7 5` (7 removed / 5 added: 3+4 removed, 5+0 added). But the first line of the old and new comment blocks is byte-identical (`-- active on the target (multi-cat)? The scout auto-disarms after a 60s window`), so git keeps it as context: the comment edit realizes as 2 removed / 4 added, and the whole task as 6 removed / 4 added (`git diff --numstat` prints `4 6` — first column is added, second deleted; also note the plan's parenthetical "(7 removed / 5 added)" would correspond to numstat `5 7`, so its expectation is internally inconsistent both ways).
- **Fix:** Verified the realized diff against the plan's verbatim replacement spec line-by-line — it matches exactly (2 cap comment lines removed, 4 cap-free comment lines added with the em-dash intact; 4 elseif lines removed; `else` kept; LF preserved). Since every content-anchored sub-check of T1 passed and the plan's explicit quoted strings are authoritative, committed the verbatim-spec result as-is. No code was altered to force the stale number.
- **Files modified:** core/events.lua
- **Verification:** per-sub-check T1 table above (8/8 content checks pass); full diff reviewed with `cat -A` (LF, em-dash bytes correct)
- **Committed in:** dfd7bd7 (Task 1 commit)

**2. [Execution-constraint] Atomic commit granularity: 2 commits instead of the plan's example 1**
- **Found during:** commit step
- **Issue:** Plan success criteria give "one atomic conventional commit... e.g. refactor(druid):..." as an example; the executor constraint mandates per-task atomic commits.
- **Fix:** Committed Task 1 (dfd7bd7, core/events.lua only) and Task 2 (139250b, core/spell_trace_core.lua only) separately. Union of files = exactly the two allowed files, so sterility is preserved.
- **Verification:** `git log --oneline -3` + `git diff --name-only HEAD~2..HEAD`
- **Committed in:** dfd7bd7, 139250b

---

**Total deviations:** 2 (1 blocking-check correction with zero code impact, 1 commit-count granularity)
**Impact on plan:** None on shipped content — the code is byte-for-byte the plan's quoted replacement spec; only the verification arithmetic and commit grouping changed.

## Issues Encountered

- None beyond the two documented deviations.

## User Setup Required

None on this host beyond what is already staged in the plan's `user_setup` (user-side, weekly-CD paced):

1. Run `build.sh` on Windows+Cygwin to regenerate SM_Extend.lua into both AddOns dirs (this repo's SM_Extend.lua is NOT rebuilt here, per convention).
2. Next CD forensics session: `/run macroTorch.rawdiag2Enabled=true` and cast an in-combat Rip — the scout must now stay armed for the FULL 60s window regardless of dumped line count, emitting exactly one `[RAWDIAG2] scout disarmed after 60s window` line with the dumped count.
3. MACRO_TORCH_LOG (macroTorch.LOG_MAX_SIZE) is already raised to 2000 in game so the larger dump fits.

## Next Phase Readiness

- No follow-up code work defined; the remaining evidence gathering is the scheduled in-game validation above.

---

*Phase: quick-260909-2kd-rawdiag2-forensics-scout-150-150-24-fade*
*Completed: 2026-09-09*