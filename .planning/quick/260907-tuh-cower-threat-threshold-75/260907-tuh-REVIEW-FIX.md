---
phase: quick-260907-tuh-cower-threat-threshold-75
reviewed: 2026-09-07T14:05:27Z
fixed_at: 2026-09-07T14:31:54Z
review_path: .planning/quick/260907-tuh-cower-threat-threshold-75/260907-tuh-REVIEW.md
iteration: 1
fix_commits:
  - hash: 04c5483d3f3f192202ddd8db8e0494d0a36b4c3d
    finding: WR-01
    message: fix(druid): tonumber guard for user-configurable Cower threat threshold (WR-01, quick 260907-tuh)
  - hash: 2c05c8c9ea4d8f1bb3f0641644af69b57a414499
    finding: WR-02
    message: fix(selftest): reprint config banner on /mt when selftest already ran (WR-02, quick 260907-tuh)
findings_in_scope: 2
findings_fixed:
  - WR-01
  - WR-02
findings_skipped: []
fixed: 2
skipped: 0
status: fixed
---

# Fix Report: quick 260907-tuh (Cower threat threshold / config banner review fixes)

**Fixed at:** 2026-09-07T14:31:54Z
**Source review:** `.planning/quick/260907-tuh-cower-threat-threshold-75/260907-tuh-REVIEW.md` (2026-09-07T14:05:27Z)
**Iteration:** 1

**Summary:**
- Findings in scope: 2 (WR-01, WR-02; IN-01/IN-02 out of scope per fix_scope)
- Fixed: 2
- Skipped: 0

Before fixing, both findings were re-verified against the code at the cited lines and confirmed real (not false positives):
- cat.lua:99 contained the bare `player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD` comparison; the threshold is now a user-writable `/run` global with only a nil-guard default (macro_torch.lua:43-44), so a string override raises "attempt to compare number with string" on Lua 5.0.
- The `/mt` handler (core/selftest.lua:989-996) called `SelfTest:run()` bare, which early-returns once `_selfTestRan` is set by the deferred login run (events.lua:74); `printConfigBanner()` had its only call site at the tail of `run()` (selftest.lua:97), making the banner unreachable mid-session and the tuh acceptance criterion "/run override reflects on next /mt" unsatisfiable.

## Fixed Issues

### WR-01: Type-unsafe /run override of COWER_THREAT_THRESHOLD aborts the click chain in worldboss fights

**Outcome:** fixed
**Files modified:** `classes/druid/cat.lua` (otMod)
**Commit:** 04c5483
**Applied fix:** Coerce the user-settable threshold once at the single consumption site before the comparison:
```lua
    -- Coerce the /run-settable threshold once: Lua 5.0 raises on mixed-type
    -- relational comparison, so a quoted '75' typo must not abort the click.
    -- Numeric strings convert fine; nil/junk makes only the worldboss leg inert.
    local cowerThreshold = tonumber(macroTorch.COWER_THREAT_THRESHOLD)
    if target.isAttackingMe or (target.classification == 'worldboss' and cowerThreshold
            and player.threatPercent >= cowerThreshold) then
        macroTorch.safeCower(clickContext)
    end
```
Accepting the numeric default unchanged, tolerating quoted numeric strings (`'75'` converts), and failing closed (worldboss threat leg inert, no error) for nil/garbage — per the accepted fix design. The `isAttackingMe` leg is unchanged. No hardcoded fallback `or 75` was added (would reintroduce duplicate-default drift that quick 260907-tuh eliminated).

### WR-02: Banner only prints once per session — "/mt reflects the override" criterion unreachable

**Outcome:** fixed
**Files modified:** `core/selftest.lua` (/mt SlashCmdList handler)
**Commit:** 2c05c8c
**Applied fix:** Snapshot `_selfTestRan` before the run() call and reprint the banner when the selftest was skipped:
```lua
    if trimmed == "" then
        -- Snapshot the session flag before run(): when the login selftest has
        -- already run, run() no-ops, so reprint the config banner to reflect
        -- any mid-session /run override. Fresh-session /mt still prints once.
        local alreadyRan = macroTorch._selfTestRan
        macroTorch.SelfTest:run()
        if alreadyRan then
            macroTorch.printConfigBanner()
        end
    else
```
Login-time printing is untouched (exactly-once semantics preserved): fresh session where the login run has not happened → run() executes fully including its own banner; mid-session → run() no-ops and the banner prints once, showing the effective post-`/run` config. `macro_torch.lua` was not modified.

## Verification

Verification ran inside the isolated git worktree (commits were fast-forwarded into `main` after verification; the worktree itself is torn down). Per finding:

- **WR-01 (cat.lua):** tier-1 re-read confirmed the guard landed with correct indentation; whole-file `bbcheck.js` reports **BALANCED**; added lines contain no `#`, no `goto`, no `::` labels; `git diff --check` clean; LF-only endings confirmed via `cat -A`. No Lua interpreter is installed on this machine, so runtime syntax parse was not available; the added lines use only trivial Lua 5.0-safe constructs (`tonumber`, `and` short-circuit).
- **WR-02 (selftest.lua):** tier-1 re-read confirmed handler shape; whole-file `bbcheck.js` was deliberately **not** used as a gate (core/selftest.lua has a pre-existing documented bracket MISMATCH at HEAD from quick 260907-sz4, unchanged by this delta — not touched per instructions). Instead a diff-scoped bracket-balance check on added/replaced lines (comments stripped) reports **net zero** for brackets and for `then`/`end` — the pre-fix mismatch signature is untouched. Added lines contain no `#`, no `goto`, no `::`; `git diff --check` clean; LF-only endings confirmed via `cat -A`.

Both fixes implement the exact design pre-validated by the orchestrator against the code. In-game behavioral confirmation (string threshold tolerated in a worldboss fight; `/mt` reprints the banner reflecting a mid-session override) remains for the verifier phase.

---

_Fixed: 2026-09-07T14:31:54Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_