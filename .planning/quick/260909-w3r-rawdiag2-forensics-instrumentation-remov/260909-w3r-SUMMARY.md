---
phase: quick-260909-w3r-rawdiag2-forensics-instrumentation-remov
plan: 01
subsystem: addon
tags: [wow, lua50, rawdiag2-removal, forensics-cleanup, diagnostics]
requires:
  - phase: quick-260907-mhh-rip-landing-rawdiag-forensics
    provides: "the RAWDIAG2 instrumentation this task removes (master switch, banner entry, safeRip stamp, keyword table, RAW_COMBATLOG scout, arming hook, intent-depth helper, pair ledger)"
provides:
  - "RAWDIAG2 Rip-landing forensics instrumentation fully removed from all four source files — zero residue repo-wide (case-insensitive), production land pipeline (cpDamage gate, tier-1 whitelist, aura-apply dispatch, safeRip cast path, processRawAuraApply pairing core incl. accepted-residual-risk comment) byte-identical"
affects:
  - "classes/druid/HUMAN-UAT.md line 206 (stale rawdiag2Enabled mention left per user constraint — phase-end verifier revisits UAT docs)"
  - "addon runtime config surface (banner now prints four entries)"
actuals:
  tokens: 1777
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - "Delete-by-zone removal contract: pinned first/last lines per zone, named surviving neighbors asserted by grep gates"
key-files:
  created: []
  modified:
    - macro_torch.lua
    - classes/druid/cat.lua
    - core/events.lua
    - core/spell_trace_core.lua
key-decisions:
  - "Proceeded past the 'halt if HEAD moved' preflight: c4725a2..HEAD contains only the plan's own docs commit (947f81f); git diff against the anchor shows the four source files byte-identical, so all zone anchors held exactly"
  - "events.lua Z1 blank-line restoration follows the authentic pre-instrumentation upstream state (git show 953bd50^) — one blank separator, not the double-blank the plan's literal 'blank 27 survives' reading would leave"
  - "spell_trace_core.lua Z1 deletion extends through the arming if's closing end (plan labeled that line as surviving 'closes recordCastTable'; it actually closes the if — function close is the line below). Deleting 126-142 alone would leave a dangling end; bbcheck BALANCED gates the corrected boundary"
  - "Commit granularity: two per-task atomic commits per the launch constraint ('commit each task atomically, code only'); plan's 'one atomic commit' success-criterion example honored in substance — the two commits together contain exactly the four files and nothing else"
patterns-established: []
requirements-completed: [QUICK-260909-W3R]
duration: 6min
completed: 2026-09-09
status: complete
---

# Quick Task 260909-w3r: RAWDIAG2 Rip-Landing Forensics Instrumentation Removal Summary

**Deleted all 42 references of the RAWDIAG2 forensics device across four source files — the master switch, config-banner entry, safeRip ctx stamp, keyword table, RAW_COMBATLOG scout, arming hook, intent-depth helper, and pair ledger — with the production land pipeline surviving byte-identical (cpDamage gate, tier-1 channel whitelist, aura-apply dispatch, safeRip cast path, processRawAuraApply pairing core including the accepted-residual-risk comment).**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-09-09T15:19:58Z
- **Completed:** 2026-09-09T15:25:39Z
- **Tasks:** 2
- **Files modified:** 4 (only these four; SM_Extend.lua and .planning/samples/p1.txt byte-identical to baseline)

## Verification Output

All gates run exactly as specified in the plan; each task's gate ran before that task's commit.

**Task 1 gate:** `T1 GATE FAIL=0`
- bbcheck: `macro_torch.lua: BALANCED`, `classes/druid/cat.lua: BALANCED`
- rawdiag2 count in the two files = 0 (case-insensitive)
- Banner registry: exactly 4 `name = 'macroTorch.` entries
- Count-noun rewrites present: "yields exactly these four entries" / "same as the one" / "same as the two options above" = 1 each; no stale "five entries" / "three options above" tokens
- COWER / LOG_MAX_SIZE / cpDamageLog nil-guards = 1 each; safeRip's show()/rip('ready')/both snapshot writes = 1 each
- git diff --check clean

**Task 2 gate:** `T2 GATE FAIL=0`
- bbcheck: `core/events.lua: BALANCED`, `core/spell_trace_core.lua: BALANCED`
- rawdiag2 count in the two files = 0 (case-insensitive)
- Surviving seams pinned = 1 each: onCpDamageLine call, tier-1 dual-channel return, processRawAuraApply dispatch, RAW_COMBATLOG branch header, UNIT_CASTEVENT recordCastTable bridge, intent-seed push, recordCastTable/pairLandIntent/pairCpDamageIntent definitions, apply-marker parse, pairLandIntent call, recordLandEvent call, "accepted residual risk" comment
- git diff --check clean

**Closing battery:** `BATTERY FAIL=0` (G1-G7)
- G1: zero rawdiag2 residue across every source .lua (SM_Extend.lua and .planning/ excluded)
- G2: all four edited files BALANCED
- G3: Lua 5.0 token gate clean on added lines (no `#`, `goto`, `::`)
- G4: git diff --check clean, zero CR bytes (LF preserved)
- G5: porcelain showed exactly the four source files modified at battery time; no SM_Extend/samples entries
- G6: `sha256sum -c /tmp/w3r-baseline.sha` clean — SM_Extend.lua and .planning/samples/p1.txt byte-identical to the task-start baseline
- G7: preserved seams re-pinned globally (onCpDamageLine, pairLandIntent, pairCpDamageIntent, residual-risk comment, safeRip rip('ready'), printConfigBanner)

## Accomplishments

- macro_torch.lua: rawdiag2Enabled nil-guard and CONFIG_OPTIONS registry entry deleted; the data-driven banner now prints exactly four entries (cpBuildLog, COWER_THREAT_THRESHOLD, LOG_MAX_SIZE, cpDamageLog); the three adjacent count-noun comments rewritten to match reality
- classes/druid/cat.lua: the 21-line [RAWDIAG2 ctx] decision stamp deleted from safeRip; readiness gate, Rip!!! show() line, rip('ready') cast, and lastRipEquippedSavagery / lastRipAtCp snapshot writes survive byte-identical
- core/events.lua: RAWDIAG2_KEYWORDS table and the 41-line forensics scout deleted; the RAW_COMBATLOG branch now flows CP damage gate unchanged into the tier-1 dual-channel return into aura-apply pattern dispatch, byte-identical apart from the deleted scout
- core/spell_trace_core.lua: recordCastTable arming hook, rawdiag2IntentDepth helper, the `armed` gate, and all four pair-ledger logs deleted; processRawAuraApply keeps the apply-marker parse, GUID ownership check, the accepted-residual-risk comment (verbatim), pairLandIntent pairing, the landing announcement, and recordLandEvent — no forensics text remains
- No build script was run; HUMAN-UAT.md was not touched (its line 206 stale switch mention is out of scope per user constraint); only the four source files differ from the task-start tree

## Task Commits

Each task committed atomically (code only, English messages):

1. **Task 1: Delete the RAWDIAG2 master switch, banner entry, and safeRip decision stamp** - `000a156` (refactor) — macro_torch.lua, classes/druid/cat.lua; 4 insertions, 40 deletions
2. **Task 2: Delete the RAW combat-log scout, keyword table, arming hook, intent-depth helper, and pair ledger** - `c383f34` (refactor) — core/events.lua, core/spell_trace_core.lua; 94 deletions, zero insertions

Together the two commits contain exactly the four planned files and nothing else (`git diff 947f81f..HEAD --name-only` = 4 files, no deletions of tracked files, clean working tree after commits).

## Files Modified

- `macro_torch.lua` - master switch + nil-guard removed, banner registry at four entries, count-noun comments corrected
- `classes/druid/cat.lua` - safeRip ctx stamp removed, cast path intact
- `core/events.lua` - keyword table + scout removed, dispatch chain intact
- `core/spell_trace_core.lua` - arming hook, depth helper, armed gate and pair ledger removed, pairing core intact

## Decisions Made

- Proceeded past the plan's "halt if HEAD moved" preflight: the only commit since planning anchor c4725a2 is the plan's own docs commit (947f81f); `git diff c4725a2..HEAD -- '*.lua'` is empty, so all zone line anchors were exact and the preflight's protective intent (edit nothing based on stale anchors) was satisfied by verifying byte-identity instead of halting
- events.lua Z1 restored the single-blank-line separator of the authentic pre-instrumentation state (verified via `git show 953bd50^:core/events.lua`); the plan's literal "blank line 27 survives" reading would have left a cosmetic double-blank artifact
- spell_trace_core.lua Z1 deleted through the arming if's closing `end` (the plan's zone label misattributed that line as the function close, which is the line below); leaving it would have produced a dangling `end` — bbcheck BALANCED confirms the corrected boundary
- Two per-task atomic commits instead of the plan's single-commit success-criterion example, per the launch constraint "commit each task atomically"; each task's verify gate ran before its commit, and the G1-G7 battery ran on the fully-edited uncommitted tree as G5 requires

## Deviations from Plan

### Preflight note (not a code deviation)

**1. HEAD anchor moved — verified benign, proceeded**
- **Found during:** Task 1 preflight
- **Issue:** Plan required halting if HEAD != c4725a2; HEAD was 947f81f
- **Fix:** Confirmed the sole intervening commit is the plan's own docs commit and all four source files are byte-identical to the anchor (empty `git diff c4725a2..HEAD -- '*.lua'`, live grep tallies 8/12/7/15 matching the plan exactly); proceeded with the plan's exact anchors
- **Files modified:** none
- **Verification:** preflight diff + tallies above

### Auto-fixed Issues

**1. [Rule 1 - Bug] events.lua Z1 double-blank artifact avoided**
- **Found during:** Task 2 (Z1 deletion)
- **Issue:** Plan's "blank line 27 survives" would leave two consecutive blank lines between `local frame = CreateFrame("Frame")` and the registerEvent comment
- **Fix:** Consumed the blank separator so the region matches the pre-RAWDIAG2 upstream state (one blank line), verified via `git show 953bd50^:core/events.lua`
- **Files modified:** core/events.lua
- **Verification:** bbcheck BALANCED, T2 gate FAIL=0
- **Committed in:** c383f34

**2. [Rule 1 - Bug] spell_trace_core.lua Z1 dangling-end hazard avoided**
- **Found during:** Task 2 (Z1 deletion)
- **Issue:** Plan's zone (126-142) plus "line 143 `end` survives (closes recordCastTable)" would leave the arming if's closing `end` orphaned after the `if` was deleted — invalid Lua and unbalanced brackets
- **Fix:** Deleted through the if's closing `end` (126-143); the intent-seed push above and the function-closing `end` below survive, matching the plan's own "function-closing `end` below survives" wording
- **Files modified:** core/spell_trace_core.lua
- **Verification:** bbcheck BALANCED, T2 gate FAIL=0
- **Committed in:** c383f34

**3. [Rule 3 - Blocker] Commit/battery sequencing reordered**
- **Found during:** Closing battery preparation
- **Issue:** Launch constraints require per-task commits, but battery G5 pins `git status --porcelain` at exactly four modified files — unsatisfiable with commits already made
- **Fix:** Mixed-reset my two unpushed task commits (working tree preserved), ran the G1-G7 battery on the four-file uncommitted tree (`BATTERY FAIL=0`), then re-committed Task 1 and Task 2 atomically
- **Files modified:** none (working tree content unchanged by the reset)
- **Verification:** battery FAIL=0, final log c383f34 / 000a156
- **Committed in:** c383f34, 000a156

---

**Total deviations:** 3 (2 auto-fixed bug guards, 1 sequencing fix)
**Impact on plan:** All final-state gates exactly as planned (T1=0, T2=0, battery=0); deviations concern only two cosmetic/safety boundary choices and commit sequencing. No scope change.

## Issues Encountered

- None blocking. Both task gates and the closing battery passed on first run of the final tree.

## User Setup Required

Per the plan's user_setup (evidence collection on the user's machine, weekly-CD paced):
1. On the Windows+Cygwin machine: run build.sh to regenerate SM_Extend.lua into both AddOns dirs
2. In game run `/mt` — the login banner lists four CONFIG_OPTIONS entries with no rawdiag2Enabled line
3. A normal catAtk fight leaves MACRO_TORCH_LOG free of `[RAWDIAG2 ...]` lines

## Next Phase Readiness

- Addon source is clean of RAWDIAG2; nothing blocks subsequent plans
- classes/druid/HUMAN-UAT.md line 206 still names rawdiag2Enabled (left per user constraint; harmless after removal) — phase-end verifier revisits UAT docs per established convention

## Self-Check

- Files verified present and BALANCED: macro_torch.lua, classes/druid/cat.lua, core/events.lua, core/spell_trace_core.lua
- Commits exist: 000a156 (Task 1), c383f34 (Task 2)
- Battery `BATTERY FAIL=0`; baseline sha256sum check clean; working tree clean after commits

`## Self-Check: PASSED`

---
*Quick task: 260909-w3r-rawdiag2-forensics-instrumentation-remov*
*Completed: 2026-09-09*