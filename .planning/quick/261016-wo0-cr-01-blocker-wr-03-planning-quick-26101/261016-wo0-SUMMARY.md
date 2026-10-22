---quick_id: 261016-wo0
slug: cr-01-blocker-wr-03
phase: quick-261016-wo0
plan: 261016-wo0
status: complete
subsystem: entity/Player.lua (pokemon load/restore pipeline)
tags: [quick, code-review-fix, cr-01, wr-03, load-lock]
requires: []
provides: [load-lock-entry-exists, dead-code-removal]
tech-stack:
  added: []
  patterns: [entry-existence-lock, no-shared-table-second-writer]
key-files:
  created:
    - .planning/quick/261016-wo0-cr-01-blocker-wr-03-planning-quick-26101/261016-wo0-SUMMARY.md
  modified:
    - entity/Player.lua
decisions:
  - "CR-01 (BLOCKER): global lock predicate tightened from two-clause (entry exists AND unused marker) to entry-exists-lock (if loadingTable.useableItem then) — user ruling 2026-10-16 option A, source .planning/quick/261016-code-review-recent/review-REVIEW.md"
  - "WR-03: dead code obj.loadUseableItem deleted whole — removed the second standard that wrote the shared global macroTorch.itemLoadingTable bypassing the verified pipeline"
  - "WR-01 (pending terminal dead loop) intentionally unchanged this ruling; pendingEquip count 8 unchanged as witness; kept for a later decision"
metrics:
  duration: ""
  completed: 2026-10-16
commits: 1
plan_head_before: 0f1f0a0b6261106214859a40d434c4f3085bfd5e
plan_head_after: 6c0e24f0431f1b1f3485f974db594466febe77b8
actuals:
  tokens: 787
  tasks: 2
  commits: 1
---

# Quick 261016-wo0: CR-01 Load Lock Fix + WR-03 Dead Code Removal

**One-liner:** Global load lock predicate tightened to entry-exists-lock (closes the used-but-unrestored window hole that let a same-slot reload destroy the mainHandItem two-hander restore state) and zero-call dead code `obj.loadUseableItem` removed — single file `entity/Player.lua`, single commit `6c0e24f`.

## Results

### CR-01 fixed (BLOCKER)

- **What changed:** The global lock predicate at the entry of `loadUseableItemToSlot` was tightened from the two-clause test `loadingTable.useableItem and loadingTable.useableItemUsed == false` to the single clause `if loadingTable.useableItem then` — **entry existence alone is the lock**. The lock comment (3 lines) was rewritten to the new semantics: entries are only written after a verified load, so any entry carrying a `useableItem` — used or not — is a live load; it blocks new loads until the restore arm clears the entry. Pending entries (no `useableItem`) are unaffected: the resume-arm pre-scan runs before the lock and handles them first.
- **Vulnerability mechanism (one line):** In the used-but-not-restored window (`useableItemUsed == true`, restore not yet pressed) the old predicate did not block; a same-slot reload then overwrote the entry with a fresh table literal (swap path), destroying the `mainHandItem`/`swappingItem` restore state (main hand 16 left empty, two-hander stranded in the bag, into combat).
- **External behavior change — exactly one:** pressing the load key in the used-but-not-restored window is now refused with `A usable item is already loaded: ...`. Everything else — load/restore semantics, release press, CD-skip restore-on-same-press, resume arm — byte-unchanged (restore-arm body md5 freeze proves it).
- **Unlock path:** the restore arm's success branches clear the entry (`macroTorch.itemLoadingTable[swappingSlot] = nil`, three sites, all existing) — clearing the table is the only unlock.

### WR-03 closed (dead code removal)

- `obj.loadUseableItem` (lines 345-374 incl. its single-line comment and trailing empty line) deleted whole. It had zero call sites and was a second standard for writing the shared global `macroTorch.itemLoadingTable`, bypassing the verified pipeline (`equipItemToSlotVerified` / `unequipToBagVerified`).
- Full-repo grep (excl. `SM_Extend.lua` and `.planning`): zero references. Live pipeline intact: `function obj.loadUseableItemToSlot(` = 1, its call `obj.loadUseableItemToSlot(orderedTable)` = 1.

### WR-01 intentionally unchanged (retained)

- Review WR-01 (pending terminal dead loop in the resume arm) is out of scope per the user ruling (2026-10-16 option A). Witness: `pendingEquip` occurrence count remains 8 — unchanged. Kept for a later decision.

## Gates (all green)

- md5 anchors pre-edit: delete zone `d811fbb2d9710227e78a8da330c43940`, lock zone `78765bb05e7d0f3267bc3ca8b3afa0df`.
- Restore-arm body byte freeze: text-anchored re-computation (24-space combat-guard line through the line before the 20-space `return`, span 60) md5 = `81258c7e5bd319bc24055525652a8a7d` — matches the vbt frozen value despite the -30 line shift. The editor-level cleanup below left it untouched.
- Lock uniqueness: new predicate `if loadingTable.useableItem then` = 1, old two-clause predicate = 0, release check `useableItemUsed == false` = 1, refusal prompt `A usable item is already loaded: ` = 1.
- Comment semantics: old wording `an unused useableItem` = 0, new wording (`is a live load; it blocks new loads until the restore arm clears the entry`) = 1.
- Counts: `useableItemUsed = false` = 4, `= true` = 2, `pendingEquip` = 8, `wc -l` = 961.
- Syntax: lua-5.0.3 `loadfile` green (authoritative Lua 5.0 compliance) + 5.1.5/5.4.7 corroboration; `bbcheck.js` = BALANCED; CRLF = 0; added lines contain no `#`/`goto`/`::`.
- Diff hygiene: exactly 1 file, exactly 2 hunks, `git diff --check` clean.
- Delivery: exactly 1 commit, message verbatim `fix(261016-wo0): tighten load lock (CR-01) and drop dead loadUseableItem (WR-03)`, base `0f1f0a0b6261106214859a40d434c4f3085bfd5e`, `SM_Extend.lua`/`docs/`/`core/selftest.lua` zero diff, porcelain exactly the quick dir line.

## Commit

- `6c0e24f0431f1b1f3485f974db594466febe77b8` — `fix(261016-wo0): tighten load lock (CR-01) and drop dead loadUseableItem (WR-03)` (only `entity/Player.lua`)

## Deviations from Plan

**1. [Edit-application repair] Delete-zone separator line corrected during execution**
- **Found during:** Task 1, after the two contract Edits
- **Issue:** The executor's delete Edit consumed lines 345-373 plus line 373's newline but left the trailing contract empty line (374) behind as a stray `    ` 4-space separator next to the pre-existing blank line 344 — two separator lines where the contract requires exactly one.
- **Fix:** One surgical Edit removed the stray line, leaving exactly one empty line between `talentRank`'s `end` and the retained `-- Load the next useable item` comment. No other byte touched.
- **Verification:** Post-fix the full pre-commit gate ran ALL GREEN — `wc -l` = 961, 2 hunks, `git diff --check` clean, restore-arm md5 freeze `81258c7e5bd319bc24055525652a8a7d` re-verified. Final file state is byte-identical to the planned contract result.

## In-game UAT (user-side unrun-verify)

Consistent with the 261016-vbt / 261016-20c precedent, in-game verification is user-side (not part of the automated gates): on Windows+Cygwin, rebuild `SM_Extend.lua` (user `./build.sh` — the stale WR-02 artifact regenerates with the rebuild), then at the training dummy:

1. Load any pokemon, use it (release press), and before the restore press press the load key again: expect the refusal prompt `A usable item is already loaded: ...` and no overwrite load.
2. After the restore arm succeeds (original equipment back), press load again: expect normal load accepted (clearing the table is the unlock).
3. WR-03 has no observable behavior — the deleted function had zero callers.
4. WR-01 (pending terminal loop) unchanged this ruling, for later decision.

## Self-Check: PASSED

- `entity/Player.lua` exists, commit `6c0e24f` is ancestor of HEAD, SUMMARY keywords (`status: complete`, `CR-01`, `WR-03`, `81258c7e5bd319bc24055525652a8a7d`) present, Task 2 gate green.