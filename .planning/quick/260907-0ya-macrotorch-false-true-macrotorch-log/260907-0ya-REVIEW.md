---
phase: quick-260907-0ya-macrotorch-false-true-macrotorch-log
reviewed: 2026-09-06T17:29:54Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - macro_torch.lua
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase quick-260907-0ya: Code Review Report

**Reviewed:** 2026-09-06T17:29:54Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the diff introduced by commits `30ef165` and `90ef069` relative to
`9740e7e` (scope: `macro_torch.lua`, `classes/druid/Druid.lua`,
`classes/druid/selftest.lua`). The change implements the opt-in
`macroTorch.cpBuildLog` measurement switch and its Claw/Shred/Rake cast hooks,
plus Category S selftests.

**Verified-correct against plan intent (differential review):**

- **Switch semantics:** `macro_torch.lua:26-28` is the byte-exact nil-guard
  from the plan; macro_torch.lua is first in `build_order.txt`, so the default
  is armed before any macro body can run; the guard re-arms `false` per login.
- **Hook correctness:** in all three hooks (Druid.lua:25-50), the GCD/cp/energy
  sample runs BEFORE `_castSpell` (Druid.lua:332-339) — the commented ordering
  invariant holds, since an issued cast starts the GCD and would falsify a
  post-cast reading.
- **Inert when off (R4):** `macroTorch.cpBuildLog and ...` short-circuits to a
  plain `nil` local when the flag is false — zero API calls, return value
  unchanged (`_castSpell` returns only true/false, so wrapping it in a local
  and `return cast` is behavior-identical).
- **R4 locked files untouched:** `git diff --stat 9740e7e..HEAD` touches only
  the three planned files plus `.planning/` docs. `cat.lua`/`combo.lua`
  unchanged.
- **Lua 5.0 constraints:** T3 token gate passes (no `goto`/`#`/labels added);
  `git diff --check` clean; `bbcheck` prints BALANCED and exits 0 on all three
  files. No 5.1+ syntax. All comments/commit messages are English.
- **S-02 format pin:** `assert(captured == '[cpBuild] Claw t=12.34 cp=3 e=62')`
  exactly matches the `cpBuildLogEvent` concatenation (Lua renders `12.34` as
  `"12.34"`), and S-02 restores `macroTorch.log` before asserting.
- **S-03 CR-01 stubbing is sound:** verified against `core/class.lua:21-34` —
  `_castSpell`/`isActionCooledDown` live on the `macroTorch.Player` prototype,
  not the Druid instance, so the `rawget` snapshots are nil and the
  `rawset(player, key, savedCast)` restore removes the own-key shadows
  (rawset with nil deletes). Restores run before every assert (selftest.lua
  :1039-1042 before :1043-1046).
- **Boot environment for S-03:** `macroTorch.player` is assigned at
  PLAYER_ENTERING_WORLD (`core/combat_context.lua:38`) before the 30-frame-
  deferred `SelfTest:run` (`core/events.lua:58-72`), so `player.claw` resolves
  at test time.
- **Persistence:** `macroTorch.log` (interface_debug.lua:103-115) appends to
  `MACRO_TORCH_LOG.messages` and shows in chat — the R3 requirement is met
  with no new machinery, exactly per the plan.
- **Security:** the log line is built only from code-literal skill names plus
  numbers, then passed to `DEFAULT_CHAT_FRAME:AddMessage` — no injection path,
  no external input, no secrets.

One Warning and three Info findings below.

## Warnings

### WR-01: GCD probe returns nil when Rake is not on an action bar — measurement dies silently with no diagnostic

**File:** `classes/druid/Druid.lua:338` (via `interface_debug.lua:24-31`)

**Issue:** `cpBuildLogSample()` sets `gcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')`. The underlying `macroTorch.isActionCooledDown` scans action slots 1..172 and, if no slot's texture contains the keyword, the loop completes **without any return** — the result is `nil`, not `false`. The gate `if cast and cpLog and cpLog.gcdOk then` (Druid.lua:28) then never fires, so a whole measurement session records exactly zero `[cpBuild]` lines with no warning, no error, and no way to tell "no casts accepted" from "feature silently dead".

**Failure scenario:** the user sets `macroTorch.cpBuildLog = true` and attacks the training dummy for 10 minutes with Rake absent from all action bars (plausible while leveling/pre-20, or when Rake fell off the bar during a bar addon swap). Zero lines land in chat and in `MACRO_TORCH_LOG.messages` despite dozens of accepted Claw/Shred casts. The plan documents this prerequisite only as a parenthetical in `user_setup` — nothing surfaces it at runtime, and since the toggle is a plain field there is no setter hook to validate it either.

**Fix:** emit a one-time diagnostic from `cpBuildLogSample` when the probe yields nil (Lua treats nil as falsy but we can distinguish with an explicit `== nil` check):

```lua
function macroTorch.cpBuildLogSample()
    local gcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
    if gcdOk == nil and not macroTorch._cpBuildLogProbeWarned then
        macroTorch._cpBuildLogProbeWarned = true
        macroTorch.show('[cpBuild] GCD probe failed: put the Rake spell on an action bar, otherwise no casts will be logged', 'yellow')
    end
    return {
        t = GetTime(),
        cp = macroTorch.player.comboPoints,
        e = macroTorch.player.mana,
        gcdOk = gcdOk
    }
end
```

Reset `_cpBuildLogProbeWarned` to nil in the `macro_torch.lua` nil-guard block so it re-warns after a reload.

## Info

### IN-01: S-03's off-phase proves "no output" but not the R4 zero-sampling claim

**File:** `classes/druid/selftest.lua:1035-1037`

**Issue:** The third phase asserts `nOff == 0` (no log line when the switch is off), but nothing observes that `cpBuildLogSample` itself was skipped. The Category S header comment and the plan rationale claim the off-state "short-circuits the sample (R4 behavioral proof)". The `and`-short-circuit is trivially true by inspection of Druid.lua:26, but the test does not instrument it — the claim is asserted in prose, not in code.

**Fix:** in S-03 (or a new S-04), shadow `macroTorch.cpBuildLogSample = function() sampled = sampled + 1 return ... end` during the off-phase and assert `sampled == 0` while also asserting the on-phases incremented it. (If added, restore with raw assignment before the asserts like all other stubs.)

### IN-02: S-01 pins a session default that could become a spurious failure if tests are ever re-run mid-session

**File:** `classes/druid/selftest.lua:991-992`

**Issue:** `Cat S-01` asserts `macroTorch.cpBuildLog == false`. Today this is safe: `SelfTest:run()` is gated by `_selfTestRan` (core/selftest.lua:51-53) and executes once, ~30 frames after PLAYER_ENTERING_WORLD, before any user toggle can occur — and `/mt` is a no-op thereafter. But the assertion encodes an assumption about execution timing: any future re-run path (e.g., a self-test command that bypasses `_selfTestRan`, or a login-bound macro that toggles the switch early) would make a legitimate mid-session state (`cpBuildLog = true`, exactly what the feature is for) report as a test warning.

**Fix:** keep the boot pin but make the assertion tolerant of the feature being in use, e.g. assert `type(macroTorch.cpBuildLog) == 'boolean'` as the minimum invariant, and move the strict `== false` default pin to the `macro_torch.lua` addon-load path where the non-toggle precondition actually holds. Alternatively, leave as-is but add a comment noting the test is valid only for boot-time execution.

### IN-03: 'ready'-mode call sites can produce rows for casts the server rejects — offline analysis should tag issue-time samples, not confirmed lands

**File:** `classes/druid/Druid.lua:25-50` (hooks) with call sites `classes/druid/cat.lua:50/56/411`, `classes/druid/leveling.lua:92/95/208/213`, `classes/druid/combo.lua:398`

**Issue:** Most callers invoke the skills in `'ready'` mode, which skips `_castSpell`'s distance and resource checks (entity/Player.lua:56-71). The gcdOk reading is a pre-cast sample. So a logged line means "cast accepted by the wrapper AND GCD clear at the sampled instant" — in rare same-frame races (target drifts out of range between the rotation's `isNearBy` gate and the cast issue; GCD started by a parallel cast) the server can still reject an issue that was logged. The line format has no outcome field, so such rows are indistinguishable from confirmed lands. This matches the plan's "GCD-ready at the sampled moment" semantics and the rotation's own energy/range gating makes the phantom rows rare — but the offline interval tooling should treat rows as issue-time samples.

**Fix:** document in the offline tooling note (or the comment above `cpBuildLogEvent`) that stratification/filtering by `e` vs the skill's energy cost (45/60/40) can flag suspected-not-accepted rows if precision becomes important. No code change required for the current measurement purpose.

---

_Reviewed: 2026-09-06T17:29:54Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_