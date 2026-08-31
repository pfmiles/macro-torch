---
phase: quick-260831-24c
fixed_at: 2026-08-31T02:59:44Z
review_path: .planning/quick/260831-24c-target-clear-macrotorch-target-clear-imm/260831-24c-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Code Review Fix Report: quick task 260831-24c (target clear())

**Fixed at:** 2026-08-31T02:59:44Z
**Source review:** `.planning/quick/260831-24c-target-clear-macrotorch-target-clear-imm/260831-24c-REVIEW.md`
**Iteration:** 1
**Fix scope:** critical_warning — WR-01 and WR-02 in scope; IN-01 and IN-02 excluded (Info level, no `--all`)

**Summary:**

- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Verification Environment

`workflow.use_worktrees` is `true`, so all edits, self-verification, and commits ran inside an isolated review-fix worktree (`.claude/worktrees/rf-260831-24c-10987-1788145088`, temp branch `gsd-reviewfix/260831-24c-10987`, based on `main` @ 7860251). The two fix commits were then fast-forwarded onto `main` during the transactional cleanup tail. bbcheck/baseline numbers below were reproduced inside that worktree; the bbcheck MISMATCH on `core/selftest.lua` is a documented pre-existing checker limitation (identical verdict on the unmodified pre-fix baseline), not a regression.

## Fixed Issues

### WR-01: Category R tests leak six result variables into session globals

**Orchestrator verdict:** CONFIRMED REAL — grep-verified that no `local` declaration for `immLeft`/`defLeft`/`otherImm`/`otherDef`/`msgCount`/`survivor` exists anywhere in `core/selftest.lua`; bare assignments inside the two pcall closures create session-permanent `_G` globals under WoW 1.12's Lua 5.0 (no strict-globals mode). Deviates from the plan's mandate (selftest.lua comment "capture results into locals") and from the P-category `local ok, pcallRes` pattern.

**File:** `core/selftest.lua`

**Change (before → after):**

- R-01 (function registered at line 910): bare closure assignments `immLeft = ...`, `defLeft = ...`, `otherImm = ...`, `otherDef = ...`, `msgCount = ...` (lines 931-935) had no enclosing declaration. Added at line 929, immediately above `local pcallRes = pcall(...)` (mirroring P-category style):

```lua
    local immLeft, defLeft, otherImm, otherDef, msgCount
    local pcallRes = pcall(function()
```

The closure now assigns upvalues of this local; assertions at 943-946 keep reading them. No other change.

- R-02 (function registered at line 949): same fix for `survivor`/`msgCount`. Added at line 963, immediately above its `local pcallRes = pcall(...)`:

```lua
    local survivor, msgCount
    local pcallRes = pcall(function()
```

**Commit:** `aeae393` — `fix(selftest): declare capture locals in Category R tests to stop _G pollution (WR-01)`

**Self-verify results:**

- `git diff --check`: clean (LF preserved).
- bbcheck on `core/selftest.lua`: MISMATCH — reproduced identically on the unmodified main-checkout baseline, so pre-existing checker limitation, not a regression. Changed hunks are two single `local` declaration lines, bracket-balanced by inspection.
- grep verification: every occurrence of the six names in the file now has an enclosing `local` declaration in the same test function (R-01 declares at line 929, assignment lines 932-936, assert lines 944-947; R-02 declares at line 963, assignment lines 966-967, assert lines 974-975). No bare `_G` assignment remains.
- `git diff --stat`: `core/selftest.lua | 2 ++` — exactly the two added declaration lines, nothing else.
- Lua 5.0 compliance: touched lines use only `local` multiple-assignment, no `#`, no `goto`.

### WR-02: clear() indexes spell-level values without a type guard

**Orchestrator verdict:** CONFIRMED REAL — both scrub loops index `mobTable[name]` with no type check; a truthy non-table spell-level entry (hand-edited/corrupted `SM_EXTEND` saved variable, a plausible real-world corruption for persisted data) makes the macro throw mid-wipe, leaving a partial clear and no aggregate confirmation — the escape hatch fails exactly in the corruption scenario a user reaches for it.

**File:** `entity/Target.lua`

**Change (before → after):** one guard per loop, consistent with the siblings' defensive `and`-chain style; `type()` is Lua 5.0-safe and behavior is identical for all legitimately-written data (writers always store tables).

- Line 92, immune scrub loop:

```lua
-            if mobTable[name] then
+            if type(mobTable) == 'table' and mobTable[name] then
```

- Line 98, definiteBleeding scrub loop: same replacement.

**Commit:** `42311ab` — `fix(target): type-guard spell-level entries in clear() scrub loops (WR-02)`

**Self-verify results:**

- `git diff --check`: clean.
- bbcheck on `entity/Target.lua`: BALANCED.
- grep verification: `type(mobTable) == 'table'` appears exactly twice (lines 92 and 98) and nowhere else — no unintended change.
- `git diff --stat`: `entity/Target.lua | 4 ++--` — exactly the two guard lines, no other hunks. Siblings and the commented-out `willDieInSeconds` block untouched.

## Out of Scope (fix_scope = critical_warning, Info findings excluded)

### IN-01: The "nothing removed" branch of clear() is untested

Not implemented — Info level, outside fix scope. **Recommendation (one-liner):** inside R-01's pcall, after capturing `msgCount`, call `target.clear()` a second time and assert `macroTorch.tableLen(shown) == 1`; two added lines, existing declarations suffice.

### IN-02: R-01 registered isOptional=true

No fix required (accepted contract per the plan and house precedent: Categories M/P/Q are all `isOptional=true`). If future `clear()` regressions should hard-fail the selftest, flip R-01's third register argument to `false` — note this would break house convention.

## Commit Summary

| Commit | Message |
|--------|---------|
| `aeae393` | fix(selftest): declare capture locals in Category R tests to stop _G pollution (WR-01) |
| `42311ab` | fix(target): type-guard spell-level entries in clear() scrub loops (WR-02) |

---

_Fixed: 2026-08-31T02:59:44Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_