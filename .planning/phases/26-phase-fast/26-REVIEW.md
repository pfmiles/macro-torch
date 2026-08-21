---
phase: 26-phase-fast
reviewed: 2026-08-22T00:00:00Z
depth: deep
files_reviewed: 4
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/combo.lua
  - classes/druid/cat.lua
  - core/selftest.lua
findings:
  critical: 1
  warning: 1
  info: 4
  total: 6
status: issues_found
---

# Phase 26: Code Review Report

**Reviewed:** 2026-08-22
**Depth:** deep
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Phase 26 fast-battle detection system: the new `macroTorch.isFastBattleNotPvp(clickContext)` judgment (Druid.lua:812-826), six guard insertions across `catAtk` (combo.lua D-03/D-04/D-07) and the cat combat modules (cat.lua D-05/D-06/D-08), and six Category P SelfTest registrations (core/selftest.lua:98-809).

What is correct:

- **Guard composition preserves PvP behavior.** Because the D-01 early-return makes `isFastBattleNotPvp` false for player-controlled targets, all six guards are transparent for PvP: `quickKeepRip` sub-branch (combo.lua:165), `keepRake` ATK-burst block (cat.lua:346), and the opener Pounce path all keep their pre-26 behavior against players. This is the right additive-guard shape.
- **Lazy-cache pattern is consistent** with `isTrivialBattle` (`== nil` sentinel, per-click `clickContext` rebuilt at combo.lua:55 per D-11).
- **D-01 ordering is correct** — the PvP exclusion runs before the cache write, so a player-controlled target can never cache a `true` verdict (P-02 asserts exactly this invariant).
- **Stub/restore discipline in P-03/P-04/P-05/P-06 is sound** — all restores execute outside the pcall body and before the asserts, so a stumbled call cannot leave `macroTorch.target.willDieInSeconds`, `macroTorch.estimatePlayerDPS`, `macroTorch.isRipPresent`, `macroTorch.safeBite`, `macroTorch.readyBite`, or `macroTorch.energyDischargeBeforeBite` poisoned.
- Guard necessity of D-07 and D-08 verified: in fast battles Rake is never applied (D-05) and Rip is never cast (D-04), so without D-07 the CP builder would stall and without D-08 a 5-CP Bite would never fire.

One critical defect was proven: the P-02 self-test writes a plain boolean into `macroTorch.target.isPlayerControlled`, which is a `FIELD_FUNC_MAP` accessor resolved through `__index` — because `classMetatable` defines no `__newindex`, the "restore" leaves a permanent own-key shadow that freezes the field for the rest of the session. One warning covers a decision-economics inconsistency between the new D-04/D-05 gates and the `getNextAbilityCost`/`shouldCastRip`/`shouldUseBite` chain that benchmarks reshift/FF timing against abilities that can no longer fire in fast battles.

## Critical Issues

### CR-01: P-02 self-test permanently shadow-taints `macroTorch.target.isPlayerControlled` (session-wide PvP exclusion corruption)

**File:** `core/selftest.lua:704-721` (stub at 709, restore at 718)

**Issue:** The PvP-exclusion test saves the *computed* value of `macroTorch.target.isPlayerControlled` and restores it as a plain boolean, which leaves a permanent own-key shadow over the functional accessor. Full mechanics chain:

1. `macroTorch.target` is a session-persistent singleton created once at addon init (`entity/Target.lua:105`); it is never recreated in-game.
2. `isPlayerControlled` is NOT a plain field — it is resolved via `classMetatable` `__index` → `macroTorch.UNIT_FIELD_FUNC_MAP['isPlayerControlled'](target)` (`entity/Unit.lua:186-188`), computing `UnitIsPlayer(self.ref) or UnitPlayerControlled(self.ref)` live on every access.
3. `classMetatable` (`core/class.lua:21-33`) defines only `__index`, no `__newindex`. So `macroTorch.target.isPlayerControlled = true` (selftest.lua:709) is a raw table write that creates an own key; from that moment `__index` is never consulted again for that key (a non-nil own key wins).
4. The restore at line 718 writes the *stale computed boolean* back — the own-key shadow remains for the rest of the session, freezing the field at whatever the login-time target was.

`macroTorch.SelfTest:run()` fires automatically on login (`core/events.lua:58-69`), so every session takes this corruption.

Impact when frozen `false` (the common case — no/neutral target at login): every PvP exclusion that reads `target.isPlayerControlled` dies silently for the whole session —
- `isTrivialBattleOrPvp` (Druid.lua:788-791) — PvP tier of the rotation no longer detected via playerControlled;
- `isFightStarted` (Druid.lua:842) — player-controlled arm dead;
- `otMod` exclusion (cat.lua:82) — Cower / threat potion logic may fire against players in PvP;
- `druidMobTagging` (combo.lua:359-383) — mob-tag macro will attack player-controlled targets (wasted abilities, potential guard engagement);
- `dischargeEnergyChangeRelicAndRip` ATK-burst gating (cat.lua:305) and `keepRake` ATK-burst gating (cat.lua:346) — burst consumes on player targets;
- `recordImmune`/`recordDefiniteBleeding` pollution guards (entity/Target.lua:43, 63) — player names recorded into the persistent immune/bleeding tables.

Impact when frozen `true` (rare — a player-controlled target present at self-test time): `isTrivialBattleOrPvp` becomes permanently true, degrading the whole rotation to the quick-battle tier (1-2 CP Rips, no 5-CP Rip on bosses, permanent Builder idol via `computeNormalRelic`), and `otMod` is permanently disabled against bosses.

**Fix:** snapshot the raw own-key state with `rawget` and restore with a raw assignment — restoring `nil` removes the key, re-exposing the functional accessor:

```lua
-- core/selftest.lua, P-02 test body
local rawOrigPvp = rawget(macroTorch.target, 'isPlayerControlled')  -- normally nil: field is function-computed
macroTorch.target.isPlayerControlled = true
pcallRes = pcall(function()
    local ctx = {}
    local verdict = macroTorch.isFastBattleNotPvp(ctx)
    ok = (verdict == false and ctx.isFastBattleNotPvp == nil)
end)
macroTorch.target.isPlayerControlled = rawOrigPvp  -- nil => own key removed => __index accessor restored
assert(pcallRes, "PvP-exclusion test pcall failed")
assert(ok, "PvP target should return false without caching")
```

(If the codebase ever intentionally raw-sets this key elsewhere, the `rawget` form still round-trips correctly; the unconditional `= nil` alternative is also acceptable today since no code currently owns that key.)

## Warnings

### WR-01: `getNextAbilityCost`/`shouldCastRip`/`shouldUseBite` still report Rip/Rake/Bite as the next ability in fast battles, where D-04/D-05/D-08 make them uncastable

**File:** `classes/druid/Druid.lua:950-1037` (consumers: cat.lua:215-244 `shouldDoReshift`, Druid.lua:917-948 `shouldCastFFDuringWaitWindow`); gates: combo.lua:163-172 (D-04), cat.lua:337 (D-05)

**Issue:** The phase gates the *cast sites* (D-04 skips both `keepRip`/`quickKeepRip`; D-05 skips `keepRake`) but leaves the *decision functions* untouched. In a fast battle:

- `isFastBattleNotPvp` true implies `isTrivialBattleOrPvp` true (both arms use the same formula with 8.5 < 25), so `shouldCastRip` takes its trivial branch and returns `true` at 1-2 CP (Druid.lua:1002-1004).
- Consequently `getNextAbilityCost` returns `(30, 'Rip')` at 1-2 CP, and `(40, 'Rake')` at 0 CP via the Rake step (Druid.lua:970-973) — while neither spell can ever be cast in a fast battle. `shouldUseBite`'s quick-battle branch (Druid.lua:1024-1029) additionally reports Bite at CP 3-4, but actual bites at 3-4 CP only fire through `tryBiteKillShot`.
- The two real fast-battle abilities are Shred (60, position-dependent) / Claw (45), with Bite (35) at exactly 5 CP.

`shouldDoReshift` and `shouldCastFFDuringWaitWindow` benchmark waits against these phantom costs (30/40 vs the real 45+), so in fast battles the macro systematically misjudges "energy will be enough in 1.5s" by up to 30 energy — prematurely skipping a profitable reshift, or casting FF into a 1s GCD when the real next ability is not yet affordable. This is a systematic decision-quality regression inside exactly the battles Phase 26 targets.

**Fix:** exclude fast battles from the phantom next-ability steps inside `getNextAbilityCost` only — it is the one consumer shared by the 60-level `catAtk` chain (`shouldDoReshift`, `shouldCastFFDuringWaitWindow`), while `catLeveling` (the phase's deliberate anchor, leveling.lua:140/172) uses `shouldCastRip`/`shouldUseBite` directly and never calls `getNextAbilityCost`. Editing `getNextAbilityCost` therefore preserves the leveling anchor:

```lua
function macroTorch.getNextAbilityCost(clickContext)
    -- fast battles can only fire Bite-at-5CP, Tiger, Shred, Claw — never Rip/Rake (D-04/D-05)
    local fastBattle = macroTorch.isFastBattleNotPvp(clickContext)

    -- 1. Ferocious Bite check (highest priority in Term Mod)
    if macroTorch.shouldUseBite(clickContext) and not fastBattle then
        return clickContext.BITE_E, 'Bite'
    end
    ...
    -- 3. Rip check (debuff maintenance)
    if not fastBattle and macroTorch.shouldCastRip(clickContext) then
        return clickContext.RIP_E, 'Rip'
    end

    -- 4. Rake check (debuff maintenance)
    if not fastBattle and not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
        return clickContext.RAKE_E, 'Rake'
    end
    ...
```

(The fall-through then lands on Shred/Claw, which are the actual castable builders; note `isFastBattleNotPvp` is lazy-cached on the clickContext, so this adds at most one HRPS computation per click.)

## Info

### IN-01: Design comment misstates Rip duration

**File:** `classes/druid/Druid.lua:809-810`

**Issue:** The comment claims "Rake lasts 9s and Rip 12s, both exceeding the threshold". `RIP_BASE_DURATION` is 10 (Druid.lua:853 / 268) and a standard 5-CP Rip lasts 18s (`ripLeft` adds `(cp-1)*2`, Druid.lua:1096-1100); only a 2-CP Rip lasts 12s. The ladder argument still holds (all values exceed 8.5s), but the number is wrong for both the base and the dominant 5-CP case.

**Fix:** Reword to "Rake lasts 9s and Rip at least 10s (18s at 5 CP)".

### IN-02: Stale Category P section header comment

**File:** `core/selftest.lua:694-696`

**Issue:** The header says "Category P — Phase 26 fast-battle judgment (2 tests in this task, 4 more in 26-02-PLAN.md)" but all 6 tests are now registered in this file. Only the trailing counter (line 809) is accurate. A future reader auditing counts against the plan will find the header misleading.

**Fix:** Update line 694 to "Category P — Phase 26 fast-battle judgment (6 tests, 2 from 26-01 + 4 from 26-02)".

### IN-03: P-06 couples to the lazy-cache internals of the function under test

**File:** `core/selftest.lua:789-799`

**Issue:** The cp5Bite regression test does not stub `macroTorch.isFastBattleNotPvp`; instead it pre-seeds `ctx.isFastBattleNotPvp = true` and relies on the REAL function reading the cached clickContext field (Druid.lua:817) and re-checking the real `macroTorch.target.isPlayerControlled` (a value CR-01 freezes, making this test's meaning implicitly order-dependent). If the D-01 guard or the cache mechanism changes, the test changes meaning (or wobbles with the real target state) without failing loudly. The test's intent is to verify cp5Bite's guard composition, not the judgment function.

**Fix:** stub the judgment like the other collaborators, symmetric to the `isRipPresent` stub:

```lua
local origFast = macroTorch.isFastBattleNotPvp
macroTorch.isFastBattleNotPvp = function(clickContext) return true end
...
macroTorch.isFastBattleNotPvp = origFast
```

### IN-04: healthMax arm of `isFastBattleNotPvp` is true for missing/dead targets — latent only

**File:** `classes/druid/Druid.lua:820-823`

**Issue:** `UnitHealthMax('target')` returns 0 for a nonexistent or dead target, so the estimate arm yields `0 <= (mates+1)*dps*8.5` → `true`. Today every call site sits inside catAtk's `target.isCanAttack`-gated else-branch (combo.lua:122-187), so this is latent — but the function is a public judgment on `macroTorch`, and `isTrivialBattle` shares the same shape (pre-existing), so a future caller (or a guard reordering) could silently get `true` fast-battle verdicts with no target.

**Fix:** add a cheap validity precondition at the top of the cache computation, e.g. cache `false` when `not macroTorch.target.isCanAttack`:

```lua
if clickContext.isFastBattleNotPvp == nil then
    if not macroTorch.target.isCanAttack then
        clickContext.isFastBattleNotPvp = false
    else
        local localFastDieTime = 8.5
        clickContext.isFastBattleNotPvp = ...
    end
end
```

---

_Reviewed: 2026-08-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_