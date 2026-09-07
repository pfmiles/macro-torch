---
phase: quick-260907-tuh-cower-threat-threshold-75
plan: 01
status: complete
subsystem: addon-config
tags: [wow-1.12, lua, config-options, worldboss, cower, nil-guard]
requires:
  - phase: quick-260907-sz4
    provides: "macroTorch.CONFIG_OPTIONS registry + printConfigBanner generic ipairs renderer"
provides:
  - "Third nil-guarded config option macroTorch.COWER_THREAT_THRESHOLD (default 75) re-armed on every login"
  - "Third CONFIG_OPTIONS registry entry surfacing the threshold on the login banner with its /run setter"
  - "Druid.lua:909 hardcoded assignment replaced by single-source-of-truth pointer comment"
affects: [cat.lua worldboss Cower decision, in-game /run tuning]
actuals:
  tokens: 271
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: ["nil-guard default + CONFIG_OPTIONS registry entry + /run per-session override (matches cpBuildLog/rawdiag2Enabled)"]
key-files:
  created: []
  modified:
    - macro_torch.lua
    - classes/druid/Druid.lua
key-decisions:
  - "Druid.lua:909 pointer comment includes the symbol name (macroTorch.COWER_THREAT_THRESHOLD) so the FINAL gate's 3-file symbol-confinement scan passes; plan's prescribed comment text omitted the symbol and made the gate unsatisfiable (Rule 1 auto-fix, see Deviations)"
  - "G2/FINAL diff assertions re-anchored from worktree-vs-HEAD to the pre-task baseline 033834e because per-task commits empty the worktree diff; gate semantics and expected counts unchanged"
requirements-completed: [QUICK-260907-TUH]
duration: 8min
completed: 2026-09-07
---

# Quick 260907-tuh: Cower worldboss threat threshold user-configurable (default 75)

**Cower's hardcoded 75% threat threshold moved from Druid.lua:909 into a nil-guarded CONFIG_OPTIONS entry in macro_torch.lua — banner-visible, /run-tunable per session, with druid/cat combat path untouched**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-09-07T13:40:00Z
- **Completed:** 2026-09-07T13:48:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `macro_torch.lua` gains the third nil-guard block: `macroTorch.COWER_THREAT_THRESHOLD = 75` re-armed on every login; a `/run macroTorch.COWER_THREAT_THRESHOLD=80` override lasts for the session only (no SavedVariables persistence, identical semantics to cpBuildLog/rawdiag2Enabled). Strictly additive: 16 insertions, 0 deletions, no existing line touched.
- Third `CONFIG_OPTIONS` registry entry (name/default=75/desc/cmd/get appended at position 3, declaration order cpBuildLog -> rawdiag2Enabled -> COWER) — the untouched generic `printConfigBanner` ipairs loop prints it with current value, `tostring(default)`, and setter command.
- `classes/druid/Druid.lua:909` assignment replaced by one pointer comment — zero functional references to the symbol remain in the file; the nil-guard is the single numeric default writer. Sibling constants and every other line byte-identical.
- Combat-path consumer `classes/druid/cat.lua:99` byte-identical (verified zero diff); reads the namespace global each otMod pass, so overrides take effect without any combat-path edit.
- Behavior at defaults unchanged: threshold still 75 without an override.

## Task Commits

Each task was committed atomically:

1. **Task 1: macro_torch.lua nil-guard + registry entry** - `9ad9529` (feat, 16 insertions)
2. **Task 2: Druid.lua:909 assignment -> pointer comment** - `1a8bb19` (feat, 1/1; amended once mid-task to include the symbol name, see deviation)

## Files Created/Modified

- `macro_torch.lua` - third nil-guard block + third CONFIG_OPTIONS entry (additive)
- `classes/druid/Druid.lua` - line 909: assignment replaced with pointer comment

## Verification (all gates pass)

- **G1 THRESHOLD OPTION OK** (pre-commit, worktree-vs-HEAD as planned): bbcheck BALANCED; exactly 1 nil-guard line and exactly 1 `= 75` assignment; each third-entry literal exactly once; exactly 3 registry `name = 'macroTorch.*'` entries; COWER at position 3.
- **G2 DRUID OK** (re-anchored to baseline 033834e): bbcheck BALANCED; 0 old-assignment literals; 0 functional numeric references; pointer comment exactly once; exactly 1 deleted + 1 added line; cat.lua zero diff.
- **FINAL GATE OK** (re-anchored to 033834e): bbcheck BALANCED for both files; exactly 1 deleted line repo-wide; zero forbidden Lua 5.0 tokens (`#`/goto/`::`) in added lines; `git diff --check` clean; LF OK (no CR); cat.lua zero diff; symbol confined to exactly 3 files (macro_torch.lua, Druid.lua, cat.lua — SM_Extend.lua excluded).
- `git status --porcelain` clean after both commits; SM_Extend.lua untouched (regenerated only on the user's game machine per user_setup).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan-internal inconsistency] Pointer comment now names the symbol**

- **Found during:** FINAL gate (after Task 2 commit)
- **Issue:** The plan's prescribed Druid.lua:909 comment text (`-- Cower worldboss threat threshold: nil-guarded default lives in macro_torch.lua ...`) does not contain the substring `COWER_THREAT_THRESHOLD`, so the FINAL gate's symbol-confinement scan (`grep ... | wc -l` = 3) could only ever match 2 files (macro_torch.lua + cat.lua). This contradicts the plan's own grounding fact: "After this task the set is macro_torch.lua + Druid.lua + cat.lua (exactly 3 files)." The gate was unsatisfiable with the exact literal text.
- **Fix:** Minimal insertion — the comment now reads `-- Cower worldboss threat threshold (macroTorch.COWER_THREAT_THRESHOLD): nil-guarded default lives in macro_torch.lua (quick 260907-tuh); user-configurable via /run - do not re-assign here`. Still a pointer comment: no numeric literal, no assignment pattern, single-line replacement, ASCII-only, token-gate clean. Task 2 commit amended so the atomic commit carries the final line.
- **Files modified:** classes/druid/Druid.lua
- **Verification:** G2 + FINAL re-run pass; symbol scan now finds exactly the 3 expected files.
- **Committed in:** `1a8bb19` (amended Task 2 commit)

### Gate mechanics (not a code deviation)

The plan's G2/FINAL chains compute diffs against worktree-vs-HEAD. Because the workflow commits each task atomically, a post-commit re-run sees an empty (or partial) diff. Both gates were re-run with their diff assertions anchored to the pre-task baseline `033834e` — identical checks, identical expected counts, semantics preserved. The first G2 run (pre-commit) passed against HEAD exactly as written.

---

**Total deviations:** 1 auto-fixed (Rule 1, plan-internal gate/logic inconsistency)
**Impact on plan:** The fix reconciles the plan's `must_haves` truth #2 (pointer comment in Druid.lua) with its own FINAL gate; no scope creep, no behavior change.

## Issues Encountered

- FINAL gate initially failed with only the bbcheck output: diff-based assertions were empty because both tasks were already committed (see Gate mechanics above). Resolved by baseline anchoring, not by weakening any check.

## User Setup Required (per plan user_setup, runs on the game machine)

1. Run build.sh on the Windows+Cygwin machine to regenerate SM_Extend.lua into the AddOns dirs (do NOT rebuild it in this repo).
2. Log in — after selftest diagnostics the config banner prints all three entries; the new one shows current=75 default=75 plus its `/run macroTorch.COWER_THREAT_THRESHOLD=80` setter line.
3. `/run macroTorch.COWER_THREAT_THRESHOLD=80` then `/mt` — banner shows 80 for the threshold entry.
4. Counterexample: `/reload` re-arms 75 (per-session semantics, identical to cpBuildLog/rawdiag2Enabled).

## Self-Check: PASSED

- FOUND: macro_torch.lua (guard block at lines 37-45, registry entry at lines 70-76)
- FOUND: classes/druid/Druid.lua:909 (pointer comment)
- FOUND: commit 9ad9529, commit 1a8bb19

---

*Phase: quick-260907-tuh-cower-threat-threshold-75*
*Completed: 2026-09-07*