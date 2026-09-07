---
phase: quick-260907-tuh-cower-threat-threshold-75
reviewed: 2026-09-07T14:05:27Z
depth: standard
diff_base: 6660b28
files_reviewed: 3
files_reviewed_list:
  - macro_torch.lua
  - core/selftest.lua
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Review Report: quick 260907-sz4 + quick 260907-tuh (config registry/banner + Cower threat threshold)

**Reviewed:** 2026-09-07T14:05:27Z
**Depth:** standard
**Files Reviewed:** 3 (macro_torch.lua, core/selftest.lua, classes/druid/Druid.lua)
**Status:** issues_found

## Summary

Reviewed the delta `6660b28..HEAD` covering two quick tasks: the `macroTorch.CONFIG_OPTIONS` registry + `printConfigBanner()` (260907-sz4) and the user-configurable `COWER_THREAT_THRESHOLD` nil-guard + registry entry replacing the hardcoded Druid.lua:909 assignment (260907-tuh).

The delta is structurally clean: the plan's own FINAL GATE chain was re-run independently and passes (`bbcheck.js` reports BALANCED for both modified files, zero forbidden Lua 5.0 tokens in added lines — no `#`/goto/`::`, `git diff --check` clean, LF-only endings verified via `cat -A`). Load-order analysis confirms no hazard: `build_order.txt` puts `macro_torch.lua` first, so the nil-guard executes before every consumer; cat.lua:99 consumes the threshold only at click time. Symbol confinement holds: exactly 3 source files reference `COWER_THREAT_THRESHOLD` (macro_torch.lua, cat.lua, Druid.lua comment). `tostring(opt.default)` renders the number default 75 as "75" correctly, and the `_selfTestRan` gate guarantees no double-print on a single addon load.

Two functional gaps survive: (1) the new `/run`-settable knob is consumed by an unvalidated numeric comparison, so a natural typo (`= '75'` or `= nil`) produces a runtime error that aborts the combat click chain exactly in worldboss fights; (2) the banner is reachable once per session only, so the tuh plan's own success criterion "/run override to 80 reflects on the next /mt" is unreachable — a mid-session /mt prints nothing. Details below.

## Warnings

### WR-01: Type-unsafe `/run` override of COWER_THREAT_THRESHOLD aborts the click chain in worldboss fights

**File:** `classes/druid/cat.lua:99` (consumer, unchanged — newly exposed) ; `macro_torch.lua:43-45,74` (knob introduced by this delta)

**Issue:** The tuh delta removes the only guaranteed-type assignment (unconditional `macroTorch.COWER_THREAT_THRESHOLD = 75` in Druid.lua:909) and replaces it with a user-writable global. The sole consumer, `macroTorch.otMod` at cat.lua:99, performs `player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD` with no coercion. Lua 5.0 does not coerce in relational comparisons: an override of `'75'` (quoted — a natural typo; the banner itself advertises `=80`, and habits die hard) raises `attempt to compare number with string`; `= nil` raises `attempt to compare number with nil`. The error fires exactly in the scenario the knob targets — worldboss fight, boss not currently attacking the player, grouped/raided (`target.classification == 'worldboss'`, `isAttackingMe` falsy). `otMod` is invoked without pcall at `classes/druid/combo.lua:162` inside the click dispatch chain, so the error propagates and aborts the remainder of that macro click — every click, for the rest of the fight, until `/reload`. This failure mode was impossible before the delta (hardcoded 75). The banner cannot reveal the bad value: at login it prints the valid default, and it never reprints mid-session (see WR-02).

**Impact:** One mistyped `/run` silently breaks all worldboss combat clicks with runtime errors; user cannot inspect the offending global mid-session to self-diagnose.

**Fix:** Coerce/documented-fallback at the single consumption site:
```lua
-- classes/druid/cat.lua near line 99
local cowerThresh = tonumber(macroTorch.COWER_THREAT_THRESHOLD)
if target.isAttackingMe or (target.classification == 'worldboss' and cowerThresh
        and player.threatPercent >= cowerThresh) then
    macroTorch.safeCower(clickContext)
end
```
`tonumber` accepts the numeric default unchanged, tolerates a quoted `'75'`, and treats nil/other junk as falsy (branch degrades to "not attacking me" instead of erroring). This also preserves the tuh design constraint that nil-guards remain the only load-time assignments in macro_torch.lua.

### WR-02: Banner only prints once per session — the plan's "/mt reflects the override" criterion is unreachable

**File:** `core/selftest.lua:51-53` (gate), `core/selftest.lua:97` (only banner call site), `core/selftest.lua:989-996` (/mt handler)

**Issue:** `printConfigBanner()` has exactly one call site: the tail of `SelfTest:run()`, which early-returns once `_selfTestRan` is set. The login-deferred path (core/events.lua:63-76, `PLAYER_ENTERING_WORLD` + 30-frame delay) runs first in every session and sets the flag after printing the banner with the defaults. A later `/mt` reaches `Selftest:run()` which returns immediately at selftest.lua:51-53 — the user gets no selftest output and no config banner. The tuh plan's own success criterion 5 ("/run override to 80 reflects on the next /mt") therefore cannot happen, and the tuning loop the delta advertises (override -> confirm) has no way to display the post-login effective config. This is a functional gap in the new capability, not merely a style issue: the only feedback surface for user-misconfigured options (see WR-01) is unreachable.

**Impact:** Users cannot verify any mid-session `/run` config change; the plan's stated acceptance criterion fails.

**Fix:** In the `/mt` handler, print the banner when the selftest itself was skipped, keeping exactly-once printing in all orderings:
```lua
if trimmed == "" then
    local alreadyRan = macroTorch._selfTestRan
    macroTorch.SelfTest:run()
    if alreadyRan then
        macroTorch.printConfigBanner()
    end
end
```
(Fresh session: `alreadyRan` is nil, full selftest + banner run once, later deferred login run is gated by the flag. Mid-session: `run()` no-ops for both callers, then the banner prints once, freshly. No double-print in either ordering.)

## Info

### IN-01: Registry survey comment now stale — says "exactly these two entries", registry holds three

**File:** `macro_torch.lua:51-52`

**Issue:** The sz4 comment block claims "A complete survey of user-tunable globals yields exactly these two entries", but the tuh commits in this same delta appended the third entry (`COWER_THREAT_THRESHOLD`) without updating the comment. The comment now contradicts the code it describes in the same hunk.

**Fix:** Update to "yields exactly these three entries".

### IN-02: Banner loop has no guard against non-string future entry fields

**File:** `macro_torch.lua:88-90`

**Issue:** The pcall only shields `opt.get`. `opt.name`, `opt.default`, `opt.desc`, `opt.cmd` are concatenated bare; a future registry entry with a missing or non-string field would raise mid-loop and kill the banner. Current three entries are all string/number literals, so no live defect — this is latent robustness debt for the documented extension path ("a future option is surfaced by appending one registry entry").

**Fix:** Either wrap the loop body in `pcall` per entry, or `tostring()` every concatenated field (`tostring(opt.desc)` etc.).

## Notes (verifications requested in review scope)

- **Load-order hazard (cat.lua:99): none.** `build_order.txt` lists `macro_torch.lua` first; the nil-guard at macro_torch.lua:43-45 executes before every consumer. cat.lua:99 (otMod) reads the value only at click time. Selftest Category F/J invocations that reach the cower code path short-circuit before the worldboss branch (no target at login → `classification == 'worldboss'` false). The `or` short-circuit at cat.lua:99 means `isAttackingMe == true` never evaluates the threshold.
- **Druid.lua:909 pointer comment: correct.** Repo-wide grep (`*.lua`, SM_Extend.lua excluded) shows the symbol referenced by exactly macro_torch.lua (guard + registry), cat.lua:99 (read), and Druid.lua:909 (comment). No assignment or early-load reader remains in Druid.lua or elsewhere.
- **Guard placement vs `_cpBuildLogProbeWarned` reset: order-independent.** All four statements run at macro_torch.lua load time, no interactions, no shadowing.
- **`tostring(opt.default)` with numeric 75:** renders "75" correctly (Lua 5.0 `tostring` on numbers).
- **Double-print on login-reload path vs /mt:** the `_selfTestRan` gate guarantees at most one banner per addon load; a `/reload` legitimately prints a fresh banner (per-session semantics, accepted design). The flip side (banner unreachable mid-session) is WR-02.
- **Mechanical gates (re-run independently):** `bbcheck.js` BALANCED for macro_torch.lua and classes/druid/Druid.lua; no `#`/goto/`::` in any added line; `git diff --check` clean; LF-only line endings confirmed via `cat -A`; added comments all English.
- **Config typo in the review request:** the `files` list contained `macro_torch.l.lua`; the actual file reviewed is `macro_torch.lua` (listed correctly in `files_reviewed_list` above).

---

_Reviewed: 2026-09-07T14:05:27Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_