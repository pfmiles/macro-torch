---
phase: quick-260910-ilu-catatk-ff-code-1-shouldcastffduringwaitw
plan: 01
subsystem: addon
tags: [wow, lua50, catatk, principles-doc, kill-shot, ff-fill]
requires:
  - phase: quick-260823-gg8-planning-catatk-core-principles-md-phase
    provides: "the catAtk-core-principles.md document this task revises (Phase 26 speed-battle content added, and the file deliberately untracked in the same commit so the .gitignore entry takes effect)"
provides:
  - "kill-shot / last-chance phase (rule 9) now short-circuits shouldCastFFDuringWaitWindow's base exclusion chain in Druid.lua — FF wait-window fill pauses during kill phase, non-kill paths unchanged"
  - "catAtk-core-principles.md revised at 9 adjudicated anchors (A3/A4/A5/A6/B1/B3/B4 + two essence-listing removals: appendix B definition-location column and appendix D SelfTest ID table), 值 column and all semantic constants byte-identical, 30 code fences preserved"
affects:
  - "classes/druid/Druid.lua (shouldCastFFDuringWaitWindow base exclusion block, +1 comment line + amortized kill-shot condition)"
  - ".planning/catAtk-core-principles.md (untracked on-disk working document — see key-decisions)"
actuals:
  tokens: 5700
  tasks: 3
  commits: 1
tech-stack:
  added: []
  patterns:
    - "Reconstructed-baseline verification: gitignored doc has no git HEAD copy, so the pre-edit baseline was rebuilt by reverse-applying the 9 byte-exact edits, then diffed/token-counted against the edited file"
key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - .planning/catAtk-core-principles.md
key-decisions:
  - "Doc edits left uncommitted on disk: .planning/catAtk-core-principles.md is gitignored (.gitignore:34) and was deliberately untracked by the user in commit 84af982 ('chore: untrack ... so .gitignore entry takes effect'); force-staging gitignored .planning content is prohibited (regression #3678), so the plan's Task 2 commit step was replaced by on-disk-only delivery"
  - "Verification baseline adapted: plan's 'git show HEAD:.planning/catAtk-core-principles.md' batteries are unusable for an untracked file; pre-edit baseline reconstructed via reverse-edits and all checks (value-column diff, constant counts, fence count, 9 anchor greps, removal greps) re-anchored to /tmp/ilu-baseline.md and passed"
  - "Pre-existing stale build artifact SM_Extend.lua (gitignored, mtime 2026-09-09 predating this task) removed per plan constraint 4 (must be absent at task end; regenerable by build.sh)"
status: complete
---

# Quick Task 260910-ilu: catAtk 原则文档对照裁决执行 + 斩杀期精灵之火门

## One-Liner

`shouldCastFFDuringWaitWindow` gains the rule-9 kill-shot exclusion (kills-shot phase pauses FF fill), and catAtk-core-principles.md receives all 9 adjudicated anchor revisions (A3-A6, B1/B3/B4 + two essence-listing removals) with the constants 值 column byte-identical.

## Tasks Executed

### Task 1: Druid.lua kill-shot FF gate (code) — committed

- Added one-line English comment `-- Kill-shot phase pauses all debuff maintenance, including FF fill (rule 9)` after the preserved `-- 基础排除条件` line.
- Appended `or macroTorch.isKillShotOrLastChance(clickContext)` to the base exclusion chain (before `then`). Non-kill paths unchanged; short-circuit fires before `computeErps`.
- Lua 5.0 compliance: no `#`, `goto`, `::`; single hunk; `git diff --check` clean; LF preserved.
- Commit: `a810f6e` `fix(catAtk): exclude kill-shot phase from FF wait-window fill`
  - Actual stat 3 insertions / 1 deletion (1 comment + condition split into 2 lines) — the plan's "2 insertions(+)" note was net arithmetic; content matches the target block verbatim, single hunk, no other files.

### Task 2: principles doc 9 anchored revisions (doc) — applied on disk, not committed (see Deviations)

All 9 anchors applied byte-exactly:

| Anchor | Edit |
|--------|------|
| A3 | Rule 2 pseudocode: `AND 有效回能净收益为正（扣除被抹除的猛虎补打）` line inserted |
| A4 | Rule 8 pseudocode: `AND erps > 0` line inserted |
| A5 | Rule 4 cp5Bite gate condition: `isImmuneRip OR isRipPresent OR 速战（规则5）` |
| B4 | Rule 7 ending: 猛虎之怒独立 GCD 机制注记 appended |
| B3 | Rule 10 注意段 rewritten: 组队/团队激活 + 非世界boss 畏缩 + 世界boss 阈值触发 |
| B1 | Rule 12 交换策略 two lines: worldboss 限定 (割裂前/割裂后) |
| A6 | Rule 14 auto-ATK paragraph: 扫击/割裂 generalized, AP 快照通用 |
| 精华化移除 1 | Appendix B: 定义位置 column dropped (12 constant rows, 值 column byte-identical) |
| 精华化移除 2 | Appendix D SelfTest table → single sentence `行为级测试断言随代码演进，本文档不维护测试 ID 清单。` |

### Task 3: closing battery — passed (adapted, see Deviations)

- Working tree: only the orchestrator-owned untracked `260910-ilu-*` plan dir (`??`); no residue from either task.
- Commit scope: `git diff HEAD~1 --stat` = exactly `classes/druid/Druid.lua`; commit subject matches the mandated `fix(catAtk):` prefix.
- Code terminal: exclusion block shows the four-condition OR + `then` with the single English comment line.
- Doc terminal: 9 hunk markers via reconstructed baseline (`diff -u` count = 9, within plan's 8-10); all added lines are Chinese body / `AND` pseudocode / code identifiers.

## Verification Evidence

- Task 1: porcelain only `M classes/druid/Druid.lua`; hunk count 1; no `#` in added lines; no `goto|::`; `git diff --check` clean; block visual = target form; `SM_Extend.lua` absent; `.planning/samples/` untouched.
- Task 2: LF clean (no CR; footer `*最后更新：2026-08-23*  ` trailing-space hard-break is pre-existing and protected — untouched); appendix B 值 column diff empty against reconstructed baseline; constants OK (`8.5s 25s 75% 15% 2.3s 9s 10s 2s` counts equal); fence count 30; all 9 greps hit; `定义位置`=0, `R[0-9]+-[0-9]+`=0, `P-01`=0; 原则→代码可追溯矩阵 table and footer byte-unchanged.

## Deviations from Plan

### Auto-fixed / Adapted Issues

**1. [Adaptation] Doc commit skipped — file is gitignored and user-untracked**
- **Found during:** Task 2 commit step
- **Issue:** Plan instructed `git add .planning/catAtk-core-principles.md && git commit -m "docs(catAtk): ..."`, but the file is not in git HEAD. It was deliberately untracked by the user in commit `84af982` (2026-08-23, quick task 260823-gg8) so the `.gitignore:34` entry takes effect.
- **Fix:** Applied all 9 revisions to the on-disk working document (task goal achieved) and did NOT commit. Force-staging gitignored `.planning/` content (`git add -f`) is prohibited per regression #3678; adding the file would also reverse the user's explicit untrack decision.
- **Files:** `.planning/catAtk-core-principles.md` (working tree only)

**2. [Adaptation] Verification baseline reconstructed (no git HEAD copy)**
- **Found during:** Task 2 verification
- **Issue:** Plan's batteries (`git show HEAD:.planning/catAtk-core-principles.md | ...`) fail with "path exists on disk but not in HEAD" because the doc is untracked.
- **Fix:** Rebuilt the pre-edit baseline at `/tmp/ilu-baseline.md` by reverse-applying the 9 byte-exact edit pairs (each asserted to apply exactly once), then ran every check (value column, constants, fence count, removals) against that baseline plus a byte-exact match of Appendix B against the plan's specified new table. All passed.
- **Files:** none in-repo (temp files under /tmp)

**3. [Rule 3 - Cleanup] Stale build artifact removed**
- **Found during:** Task 1 verification (`test ! -e SM_Extend.lua` failed)
- **Issue:** `SM_Extend.lua` existed on disk (mtime 2026-09-09 01:08, predating this task — leftover from a previous phase's build battery). Gitignored, untracked; plan constraint 4 requires it absent at task end. No build script was run by this task.
- **Fix:** `rm -f SM_Extend.lua` (plain delete; not `git rm`, not `git clean`, no tracked files affected).
- **Files:** `SM_Extend.lua` (deleted, gitignored)

**4. [Note] Commit stat arithmetic** — plan predicted "2 insertions(+)"; the correct diff is 3 insertions / 1 deletion (comment +1, condition split -1/+2). Functional content matches the target block verbatim; single hunk confirmed.

## Known Stubs

None — the doc sentence "行为级测试断言随代码演进" is a deliberate essence-style statement per the adjudication (not a placeholder); no code stubs introduced.

## Threat Flags

None.