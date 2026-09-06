---
phase: quick-260907-0ya-macrotorch-false-true-macrotorch-log
fixed_at: 2026-09-06T17:46:23Z
review_path: .planning/quick/260907-0ya-macrotorch-false-true-macrotorch-log/260907-0ya-REVIEW.md
iteration: 1
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase quick-260907-0ya: Code Review Fix Report

**Fixed at:** 2026-09-06T17:46:23Z
**Source review:** `.planning/quick/260907-0ya-macrotorch-false-true-macrotorch-log/260907-0ya-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope (`fix_scope=critical_warning`): 1 (WR-01)
- Fixed: 1
- Skipped: 0
- Out of scope (Info-level, listed for visibility only): IN-01, IN-02, IN-03

## Verification Before Fix (locked instruction: confirm or reject each finding)

WR-01 was confirmed as a **true defect on the real code**, not a false positive. The
full chain was reconstructed and a concrete failure scenario established before any
edit:

1. `classes/druid/Druid.lua:337` (pre-fix) read `gcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')`.
2. `entity/Player.lua:186-188` delegates that call to `macroTorch.isActionCooledDown`.
3. `interface_debug.lua:24-31` returns `GetActionCooldown(z) == 0` only inside the
   keyword-match branch; when no slot matches, the `for z = 1, 172` loop completes
   **without any return** — the caller receives `nil`, not `false`.
4. The hook gate `if cast and cpLog and cpLog.gcdOk then` (`Druid.lua:28`, unchanged)
   treats `nil` as falsy, so a session with Rake absent from every action bar records
   exactly zero `[cpBuild]` lines with no runtime diagnostic, indistinguishable from
   "no casts accepted". This matches the review's failure scenario exactly.

No in-scope finding was judged a false positive, and no opportunistic changes were
made beyond WR-01.

## Fixed Issues

### WR-01: GCD probe returns nil when Rake is not on an action bar — measurement dies silently with no diagnostic

**Files modified:** `classes/druid/Druid.lua`, `macro_torch.lua`, `classes/druid/selftest.lua`
**Commit:** `4fd31a3`
**Applied fix:**
- `macroTorch.cpBuildLogSample` now binds `local gcdOk = ...` and emits a one-time
  diagnostic via `macroTorch.show('[cpBuild] GCD probe failed: put the Rake spell on an action bar, otherwise no casts will be logged', 'yellow')`
  when the probe yields `nil`, guarded by `macroTorch._cpBuildLogProbeWarned` so it
  fires once per session instead of once per cast.
- `macro_torch.lua` resets `macroTorch._cpBuildLogProbeWarned = nil` in the addon-load
  path, so a UI reload surfaces a fresh warning instead of inheriting a stale flag.
- Chose `macroTorch.show` (chat-only) over `macroTorch.log` deliberately: the warning
  never lands in `MACRO_TORCH_LOG.messages`, keeping the measurement buffer parse-clean
  for offline interval tooling (R3 requirement untouched).
- Added selftest S-04 (`cpBuildLogSample warns once when the GCD probe yields nil`):
  stubs `player.isActionCooledDown` to return `nil` (own-key shadow, rawget snapshot /
  rawset restore, same CR-01 discipline as S-03), calls the sample twice, asserts the
  warning fired exactly once, `gcdOk` stayed `nil` in both samples, and the `[cpBuild]`
  tag is present. Restores happen before all asserts. Category S count comments
  updated 3 → 4.

**Guarantees preserved:**
- "off = zero extra API work": `cpBuildLogSample` remains reachable only through the
  `macroTorch.cpBuildLog and ...` short-circuits (`Druid.lua:26/35/44` unchanged); all
  added code runs inside the sample, on-switch only. The load-time flag reset is one
  table write with no WoW API call.
- Rotation files `classes/druid/cat.lua` and `classes/druid/combo.lua` untouched —
  the commit touches only the three files listed above.
- Lua 5.0: no `#` length operator, no `goto`, no labels added; the 4-argument
  `string.find(s, p, init, true)` plain-text form is 5.0-compatible.

## Skipped Issues

None — the single in-scope finding was confirmed and fixed.

## Out-of-Scope Findings (`fix_scope=critical_warning` excludes Info)

Not modified, reported per the fix-scope boundary:

- **IN-01** (`classes/druid/selftest.lua:1035-1037`): S-03 proves "no output when off"
  but does not instrument the sample-skip itself.
- **IN-02** (`classes/druid/selftest.lua:991-992`): S-01 pins the boot-time default
  `cpBuildLog == false` and could spurious-warn on a future mid-session re-run.
- **IN-03** (`classes/druid/Druid.lua:25-50` hooks): `[cpBuild]` rows are issue-time
  samples, not confirmed lands; documentation-only suggestion for offline tooling.

## Verification

All gates ran in the **main working checkout** — the run directive for this sequential
fixer explicitly places commits on `main` directly ("no worktree branch check
applies"), so no isolated worktree was created despite `workflow.use_worktrees=true`.
Edits, gate runs, and commit `4fd31a3` all happened in the main checkout on `main`.

- `bbcheck.js` (repo's bracket-balance syntax gate): **BALANCED, exit 0** on all three
  modified files (`macro_torch.lua`, `classes/druid/Druid.lua`, `classes/druid/selftest.lua`).
- T3 Lua 5.0 token gate over the diff (`goto` / `#` / `::`): **OK** — none added.
- `git diff --check`: **clean** (LF preserved).
- `git status --porcelain` after commit: clean; only the three source files were in the
  commit; `SM_Extend.lua` not rebuilt.
- No Lua interpreter exists on this host, so bbcheck + token gate are the repo's
  established headless syntax proxies (per PLAN.md). In-game `/mt` (which runs
  S-01..S-04) remains the human follow-up to exercise the new S-04.
- Note: the implementation-phase T2 gate expectation "exactly 3 `"Cat S-0` registrations /
  `Category S adds 3 tests`" is intentionally superseded (now 4) by this fix's added
  selftest coverage.

---

_Fixed: 2026-09-06T17:46:23Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_