---
phase: quick-260907-vve-add-macrotorch-log-max-size-global-confi
plan: 01
status: complete
subsystem: addon-config
tags: [wow-1.12, lua, config-options, persistence-log, nil-guard, trim-cap]
requires:
  - phase: quick-260907-tuh
    provides: "nil-guard + CONFIG_OPTIONS registry entry + /run per-session override pattern (third option COWER_THREAT_THRESHOLD)"
  - phase: quick-260907-sz4
    provides: "macroTorch.CONFIG_OPTIONS registry + printConfigBanner generic ipairs renderer (fourth entry renders with zero banner edits)"
provides:
  - "Fourth nil-guarded config option macroTorch.LOG_MAX_SIZE (default 500) re-armed on every login; /run override lives for the session only"
  - "Sanitized trim-limit read in macroTorch.log (tonumber + floor + clamp to >= 1 + 500 fallback) — the cap can never hang on any /run value"
  - "Fourth CONFIG_OPTIONS registry entry (position 4) surfacing the cap on the login banner with its /run setter"
  - "Optional Cat T-01 selftest asserting the real global defaults to 500 (Cat S-01 style)"
affects: [macroTorch.log persistence buffer cap, in-game /run tuning, selftest Category T]
actuals:
  tokens: 563
  tasks: 3
  commits: 3
tech-stack:
  added: []
  patterns: ["nil-guard default + CONFIG_OPTIONS registry entry + /run per-session override (matches cpBuildLog/rawdiag2Enabled/COWER_THREAT_THRESHOLD)", "sanitized consumer read: tonumber + clamp, one local for the raw value and one for the bound"]
key-files:
  created: []
  modified:
    - macro_torch.lua
    - interface_debug.lua
    - classes/druid/selftest.lua
key-decisions:
  - "Trim loop compares tableLen against the sanitized local `limit`, never against the raw MACRO_TORCH_LOG.maxSize field — the saved schema field now has zero readers outside the two init guards (D-02/D-03)"
  - "Comment wording follows the stock-truthiness note: 0 and negatives reach the clamp (become 1); only nil/non-numeric tonumber results fall back to 500 — no comment claims zero falls back to 500 (plan's load-bearing STOCK-TRUTHINESS NOTE)"
  - "G3/FINAL diff assertions re-anchored from worktree-vs-HEAD to the pre-task baseline dace121 because per-task atomic commits empty the worktree diff; gate semantics and expected counts unchanged (same precedent as quick 260907-tuh)"
requirements-completed: [QUICK-260907-VVE]
duration: 5min
completed: 2026-09-07
---

# Quick 260907-vve: macroTorch.log persistence buffer cap user-configurable (macroTorch.LOG_MAX_SIZE, default 500)

**The macroTorch.log 500-entry trim cap is now a nil-guarded, banner-visible, /run-tunable per-session global — fourth CONFIG_OPTIONS entry rendered by the untouched banner, sanitized consumer that can never hang, maxSize SavedVariables schema untouched, and one optional default-value selftest**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-09-07T15:12:00Z
- **Completed:** 2026-09-07T15:17:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `macro_torch.lua` gains the fourth nil-guard block: `macroTorch.LOG_MAX_SIZE = 500` re-armed on every login; `/run macroTorch.LOG_MAX_SIZE=1000` lasts for the session only (no SavedVariables persistence, identical semantics to cpBuildLog/rawdiag2Enabled/COWER_THREAT_THRESHOLD). This guard is the ONLY functional LOG_MAX_SIZE assignment in the repo (G1-pinned).
- Fourth `CONFIG_OPTIONS` registry entry at position 4 (declaration order cpBuildLog -> rawdiag2Enabled -> COWER_THREAT_THRESHOLD -> LOG_MAX_SIZE) — the untouched generic `printConfigBanner` prints current value, `default = 500`, and the `/run macroTorch.LOG_MAX_SIZE=1000` setter with zero banner-code edits.
- Stale registry count comment fixed on macro_torch.lua:52 — "yields exactly these four entries" (one-word change, the only edited existing line in the file).
- `interface_debug.lua` trim loop now reads the sanitized locals — `local n = tonumber(macroTorch.LOG_MAX_SIZE)`, `local limit = n and math.max(1, math.floor(n)) or 500`, `while macroTorch.tableLen(messages) >= limit do` — so a 0/negative/string/table override can never produce a mixed-type compare or an unbounded trim loop. `MACRO_TORCH_LOG.maxSize` remains ONLY in the two init guards (SavedVariables schema field, zero readers, D-03 honored); `function macroTorch.log(a, color)` signature and show-then-append behavior byte-identical; all four caller files (core/events.lua, core/spell_trace_core.lua, classes/druid/Druid.lua, classes/druid/cat.lua) zero diff.
- `classes/druid/selftest.lua` gains optional Cat T-01: asserts the real global `macroTorch.LOG_MAX_SIZE == 500` at selftest time (Cat S-01 style, read-only, no stubs, isOptional=true) — strictly additive, zero deleted lines in the file, rides the existing /mt invocation.
- Behavior at defaults unchanged: cap still 500, trimmed identically, banner grows from three to four entries.

## Task Commits

Each task was committed atomically (code only; docs committed by the orchestrator in Step 8):

1. **Task 1: macro_torch.lua — nil-guard + registry entry + count fix** - `097dfab` (feat, 18 insertions / 1 deletion)
2. **Task 2: interface_debug.lua — sanitized trim limit + comment syncs** - `16b4693` (feat, 10 insertions / 1 deletion)
3. **Task 3: classes/druid/selftest.lua — Cat T-01 default-value selftest** - `cb0fcd3` (feat, 11 insertions, strictly additive)

## Files Created/Modified

- `macro_torch.lua` - fourth nil-guard block (default 500) between the COWER guard and the probe comment; fourth CONFIG_OPTIONS entry; count word fixed (two -> four). Only edited existing line: line 52.
- `interface_debug.lua` - three-line English sync comment after the Chinese persistence-buffer comment; two locked sanitizer locals + new while condition replacing the old trim line. Only edited existing line: old line 111.
- `classes/druid/selftest.lua` - Category T block (9 lines + blank + count comment) between the Category S count comment and the closing `end`; zero deleted lines.

## Decisions Made

- Trim bound is a local sanitized number derived per call from the global — the SavedVariables-fresh trim loop always reflects a mid-session /run override on the very next log() call.
- Comment wording follows the plan's stock-truthiness note exactly (0 is truthy on stock Lua 5.0, so 0/negatives clamp to 1; only tonumber -> nil reaches the 500 fallback); no comment claims zero falls back to 500.
- The locked guard expression `local limit = n and math.max(1, math.floor(n)) or 500` implemented verbatim per D-02.

## Deviations from Plan

### Gate mechanics (no code deviations)

All three tasks landed byte-exactly as prescribed; two of the plan's verification chains needed mechanical re-anchoring, identical checks, no weakening:

1. **G3's position grep needed an end-of-options separator on this host.** The plan's `grep -nF '-- Category T: ...'` operand starts with `--`, which this machine's `grep` wrapper (Claude Code shell wrapper delegating to ugrep 7.5.0) parses as options and aborts with "ugrep: invalid option". Re-run with `grep -nF -- '-- Category T: ...'` — same pattern, same expected line numbers, same assertion (T header after the Category S count comment, `T_L=1085 > S_L=1084`). No file content changed.
2. **FINAL gate deletion count reformulated to enforce the plan's own invariant.** The plan's `git diff -U0 | grep -cE '^-[^-]'` expects 2, but one of the two deleted lines is itself a Lua comment (`-- survey ... yields exactly these two entries ...`, the count-word line), whose diff line renders as `--- survey ...` and is excluded by `^-[^-]` exactly like the `--- a/file` headers — the literal chain can only ever count 1. The plan's authoritative prose invariant is "exactly two replaced lines repo-wide" (macro_torch.lua:52 and interface_debug.lua:111). Enforced equivalently via `git diff --numstat` deletion-column sum = 2 (18/1 + 10/1 + 11/0), plus per-file verification: G1 already asserts only the new count wording remains, G2 already asserts zero `MACRO_TORCH_LOG.maxSize do` references. No code change.
3. **FINAL gate diff anchored to the pre-task baseline `dace121`.** Because each task commits atomically, a worktree-vs-HEAD `git diff` is empty post-commit; the aggregate FINAL assertions run against `dace121..HEAD` over exactly the three planned files (same precedent as quick 260907-tuh). G1 and G2 ran pre-commit against the freshly edited working tree exactly as written.

**Total deviations:** 0 code deviations (plan text implemented verbatim); 3 verification-chain mechanical re-anchorings (checks, not deliverables)
**Impact on plan:** None — all six gate assertions (G1/G2/G3/FINAL) pass with their planned semantics and expected counts.

## Verification (all gates pass)

- **G1 LOG_MAX OPTION OK** (pre-commit, exact chain): bbcheck BALANCED; exactly 1 nil-guard line; exactly 1 functional `macroTorch.LOG_MAX_SIZE = 500` assignment; the fourth-entry name/default/cmd/get literals exactly once each; exactly 4 registry `name = 'macroTorch.*'` entries; count comment says four with no two/three variant; LOG entry line number > COWER entry line number (position 4).
- **G2 CONSUMER OK** (pre-commit, exact chain): bbcheck BALANCED; exactly 2 `maxSize = 500` lines (both init guards); zero old trim-condition references; exactly 1 `>= limit do`; both locked locals exactly once; signature unchanged; LOG_MAX_SIZE on exactly 3 lines; all four caller files zero diff.
- **G3 SELFTEST OK** (pre-commit, ugrep-safe separator): bbcheck BALANCED; test name once; exactly 1 functional assert; count comment once; T header after S count comment; zero deleted lines in the diff.
- **FINAL GATE OK** (post-commit, anchored to dace121): bbcheck BALANCED for all three files; exactly 2 true deleted lines (numstat); zero forbidden Lua 5.0 tokens (`#`/`goto`/`::`) in added lines; `git diff --check` clean; LF OK (no CR); LOG_MAX_SIZE confined to exactly `classes/druid/selftest.lua`, `interface_debug.lua`, `macro_torch.lua`; SM_Extend.lua untouched (`git status --porcelain` empty for it).
- Working tree clean after all commits (only the untracked quick-docs directory, left for the orchestrator's Step 8).

## Issues Encountered

- FINAL gate first run failed silently after the bbcheck lines: the literal `^-[^-]` deletion count returned 1 instead of 2 (see Gate mechanics #2). Diagnosed by isolating each chain link, then enforced via the numstat equivalent. No code issue was ever present.

## User Setup Required (per plan user_setup, runs on the game machine)

1. Run build.sh on the Windows+Cygwin machine to regenerate SM_Extend.lua into the AddOns dirs (established quick-task convention — never rebuild it in this repo).
2. Log in — after the selftest diagnostics the config banner prints all four entries, the new one showing `macroTorch.LOG_MAX_SIZE = 500 (default: 500)` plus its setter line `/run macroTorch.LOG_MAX_SIZE=1000`.
3. Run `/run macroTorch.LOG_MAX_SIZE=1000` then `/mt` — the banner reprints (WR-02 fix, commit 2c05c8c) with 1000.
4. Confirm the counterexample: `/reload` re-arms 500 (per-session semantics identical to cpBuildLog/rawdiag2Enabled/COWER_THREAT_THRESHOLD).
5. OPTIONAL flood probe of the cap: `/run for i=1,520 do macroTorch.log('pad '..i) end` then inspect `macroTorch.tableLen(MACRO_TORCH_LOG.messages)` — expect exactly 500.
6. OPTIONAL edge probe: `/run macroTorch.LOG_MAX_SIZE=0` then a small flood — expect the kept count to be 1 (stock Lua 5.0 truthiness: 0 is truthy, so the clamp — not the 500 fallback — handles it).

## Self-Check: PASSED

- FOUND: macro_torch.lua (guard block lines 46-55, registry entry lines 87-93, count fix line 62)
- FOUND: interface_debug.lua (sync comment lines 18-20, sanitizer lines 114-119)
- FOUND: classes/druid/selftest.lua (Category T block lines 1085-1093, count comment line 1095, wrapper `end` line 1096)
- FOUND: commit 097dfab, commit 16b4693, commit cb0fcd3

---
*Phase: quick-260907-vve-add-macrotorch-log-max-size-global-confi*
*Completed: 2026-09-07*