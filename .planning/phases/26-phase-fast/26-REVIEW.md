---
phase: 26-phase-fast
reviewed: 2026-08-22T00:00:00Z
depth: deep
files_reviewed: 4
files_reviewed_list:
  - classes/druid/cat.lua
  - classes/druid/combo.lua
  - classes/druid/Druid.lua
  - core/selftest.lua
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 26: Code Review Report (Deep Re-review)

**Reviewed:** 2026-08-22
**Depth:** deep
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This is a deep-depth re-review of Phase 26 source files. An earlier standard-depth review confirmed all 6 original findings (CR-01, WR-01, IN-01 through IN-04) are fixed with zero new issues. This review adds cross-file call chain analysis, import/module dependency graph checks, and edge-case enumeration across the 3 Druid module files (Druid.lua -> combo.lua -> cat.lua).

**Result: 5 specific deep-analysis areas checked. Three areas pass clean. Two areas reveal quality findings (1 warning, 2 info). No critical issues.**

---

## Structural Findings (fallow)

No structural findings provided for this phase.

---

## Deep Analysis: Five Specific Areas

### 1. `isFastBattleNotPvp` lazy-cache lifecycle across all 6 call sites

**Verdict: NO ISSUES.**

All six call sites receive the same `clickContext` table created fresh each frame at `catAtk()` line 55 (`local clickContext = {}`). The function at Druid.lua:812-832 caches its result on `clickContext.isFastBattleNotPvp`.

**Call sites traced (all six):**

| Site | File | Line | Context |
|------|------|------|---------|
| 1 | combo.lua | 139 | Pounce opener guard (D-03) |
| 2 | combo.lua | 164 | Rip section guard (D-04) |
| 3 | combo.lua | 180 | regularAttack bleed guard (D-07) |
| 4 | cat.lua | 117 | cp5Bite fast-battle bite trigger (D-08) |
| 5 | cat.lua | 163 | energyDischargeBeforeBite Rake fallback (D-06) |
| 6 | cat.lua | 337 | keepRake fast-battle guard (D-05) |
| * | Druid.lua | 958 | getNextAbilityCost internal (not a guard, a heuristic) |

**Cache correctness verification:**

- **No double-evaluation:** Cache guard at line 817 (`if clickContext.isFastBattleNotPvp == nil then`) ensures first call computes, all subsequent calls reuse within the same frame.
- **No stale-cache across frames:** `clickContext` is recreated each frame at `catAtk:55` (`local clickContext = {}`).
- **No stale-cache within frame from PvP exclusion:** The PvP check at line 814 (`if macroTorch.target.isPlayerControlled then return false end`) executes BEFORE the cache guard (line 817), so PvP targets never cache. Within a single frame, the target doesn't change, so this is correct.
- **No stale-cache within frame from isCanAttack guard (IN-04):** The guard at line 820 (`if not macroTorch.target.isCanAttack then clickContext.isFastBattleNotPvp = false`) caches `false` before the health computation, preventing `true` for non-targets within the same frame.
- **Call order within catAtk:** The first call typically reaches site 1 (Pounce opener, combo.lua:139) or site 4 (termMod -> cp5Bite, cat.lua:117). Once cached, all subsequent sites reuse. This is correct — the answer cannot change within one frame.

---

### 2. `getNextAbilityCost` fastBattle guard interaction with `shouldDoReshift` and `shouldCastFFDuringWaitWindow`

**Verdict: NO ISSUES.**

**Trace of the decision chain:**

```
catAtk (combo.lua:49)
  -> reshiftMod (cat.lua:198)
    -> shouldDoReshift (cat.lua:215)
      -> getNextAbilityCost (Druid.lua:956)
        -> isFastBattleNotPvp (Druid.lua:812)
  -> keepFF (cat.lua:351)
    -> shouldCastFFDuringWaitWindow (Druid.lua:923)
      -> shouldDoReshift (cat.lua:215)    -- [first guard, line 927]
      -> getNextAbilityCost (Druid.lua:956) -- [energy benchmark, line 934]
```

**Fast-battle guard interaction analysis:**

In `getNextAbilityCost` (Druid.lua:956-991), the `local fastBattle` flag gates three phantom branches:

- **Bite (line 962):** `if macroTorch.shouldUseBite(clickContext) and not fastBattle then` — Bite cost (35) is excluded. Correct: in fast battles, `cp5Bite` handles bite decisions directly, not through cost heuristics.
- **Rip (line 975):** `if not fastBattle and macroTorch.shouldCastRip(clickContext) then` — Rip cost (30) is excluded. Correct: D-04 prevents Rip in fast battles.
- **Rake (line 980):** `if not fastBattle and not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then` — Rake cost (37-40) is excluded. Correct: D-05 prevents Rake in fast battles.

Fallthrough to Shred/Claw (lines 985-990) is un-gated, ensuring a real builder cost is always returned.

**RESHIFT_ENERGY == 0 interaction (cat.lua:217-219):**

When `RESHIFT_ENERGY == 0` (no Furor talent, no Wolfshead Helm), `shouldDoReshift` returns `false` immediately. This is a single-value return (no `nextMove`/`nextAbilityCost`). All three callers (`reshiftMod`, `otMod`, `shouldCastFFDuringWaitWindow`) only consume the boolean when it's false, and `nextMove`/`nextAbilityCost` (nil) are never used. This is safe in Lua — extra return values default to nil.

**Timing benchmark correctness:**

With phantom abilities excluded in fast battles, `getNextAbilityCost` returns Shred (60 energy, if behind) or Claw (45 energy). These are the actual builder costs the rotation needs. The reshift economics (`projectedEnergy < nextAbilityCost`) and FF waiting window (`waitSeconds >= 1.0`) benchmark against real costs. No mis-timing.

---

### 3. P-02 `rawget`/nil-restore pattern correctness — confirming `classMetatable.__index` re-exposure

**Verdict: CORRECT. No issues.**

The metatable chain for `macroTorch.target` is:

```
target_instance own-keys (empty)
  -> classMetatable.__index (core/class.lua:23-33)
    -> TARGET_FIELD_FUNC_MAP[k]  (Target.lua:110-111, empty table)
    -> macroTorch.Target[k]
      -> Target metatable.__index
        -> UNIT_FIELD_FUNC_MAP[k]  (Unit.lua:101-199)
          -> function(self) ... end  (Unit.lua:186-188 for isPlayerControlled)
        -> macroTorch.Unit[k]
```

**P-02 test analysis (selftest.lua:704-722):**

```
Line 706: rawget(macroTorch.target, 'isPlayerControlled')  --> nil
           (own-key is nil; value is resolved via __index chain)
Line 710: macroTorch.target.isPlayerControlled = true
           (writes own-key, SHADOWS the __index chain)
Line 719: macroTorch.target.isPlayerControlled = rawOrigPvp (= nil)
           (assigns nil -> Lua DELETES own-key -> __index chain resumes)
```

**Why this works:**

- `rawget` bypasses metatables and reads only own-keys. In normal operation, `macroTorch.target` has no own-key `isPlayerControlled`. `rawget` returns nil.
- Restoring with nil (`= rawOrigPvp` where `rawOrigPvp` is nil) is Lua's idiomatic way to delete a table key. After the assignment, `rawget(macroTorch.target, 'isPlayerControlled')` returns nil again, and `macroTorch.target.isPlayerControlled` falls through to the `__index` chain.
- The comment at line 707 documents this precisely: "normally nil: the field is function-computed via __index, so the raw snapshot reads the own-key state only."
- The restore comment at line 720 documents the consequence: "normally assigns nil, deleting the own-key so the __index accessor is live again; a stale boolean would shadow PvP detection for the whole session (CR-01)."

**Edge case analysis:**

The only theoretical risk is if some other test registered before P-02 writes a plain boolean to `macroTorch.target.isPlayerControlled`, causing `rawOrigPvp` to capture a non-nil value. In that case, the restore would reinstate the stale boolean rather than nil. However:

1. No other test in the current suite does this (verified by grep across all test registrations).
2. P-01 (function existence check, line 698) is purely read-only.
3. All other P-tests (P-03 through P-06) are registered AFTER P-02 and stub different functions.

The rawget/nil-restore pattern is correct for the current code and follows the documented fix for CR-01.

---

### 4. Cross-module data flow: `clickContext` propagation from combo.lua:55 through all guard sites

**Verdict: MINOR ISSUE found (see IN-05 below).**

**Flow trace:**

```
catAtk (combo.lua:49)
  [55] local clickContext = {}                         -- fresh table each frame
  [58-109] populate: POUNCE_E..isPseudoInfiniteEnergy  -- all fields set here
  
  Passes clickContext to:
    [111] recoverNormalRelic  (Druid.lua)
    [130] burstMod            (cat.lua)
    [139] isFastBattleNotPvp  (Druid.lua) -- Pounce guard
    [154] oocMod              (cat.lua)
    [157] termMod             (cat.lua)
    [159] otMod               (cat.lua)
    [161] keepTigerFury       (cat.lua)
    [164] isFastBattleNotPvp  (Druid.lua) -- Rip guard
    [167] quickKeepRip        (cat.lua)
    [170] keepRip             (cat.lua)
    [174] keepRake            (cat.lua)
    [176] keepFF              (cat.lua)
    [180] isFastBattleNotPvp  (Druid.lua) -- regularAttack guard
    [181] regularAttack       (cat.lua)
    [186] reshiftMod          (cat.lua)
```

**Field initialization completeness:**

All `clickContext` fields consumed by downstream functions are initialized at lines 58-109, with one exception:

| Field | Set? | Consumed by | Effect of nil |
|-------|------|-------------|---------------|
| CLAW_E | yes (line 59) | cp5Bite, energyDischargeBeforeBite | crash if nil |
| SHRED_E | yes (line 60) | cp5Bite, energyDischargeBeforeBite | crash if nil |
| BITE_E | yes (line 62) | cp5Bite, energyDischargeBeforeBite | crash if nil |
| RAKE_E | yes (line 61) | energyDischargeBeforeBite | crash if nil |
| TIGER_E | yes (line 64) | safeTigerFury, readyReshift | crash if nil |
| RIP_E | yes (line 63) | dischargeEnergyChangeRelicAndRip | crash if nil |
| COWER_E | yes (line 65) | safeCower | crash if nil |
| RESHIFT_ENERGY | yes (line 83) | shouldDoReshift, readyReshift | crash if nil |
| POUNCE_DURATION | yes (line 70) | pounceLeft | crash if nil |
| TIGER_DURATION | yes (line 68) | tigerLeft | crash if nil |
| FF_DURATION | yes (line 69) | ffLeft | crash if nil |
| prowling | yes (line 90) | multiple sites | comparison works |
| berserk | yes (line 91) | burstMod, computeErps | comparison works |
| comboPoints | yes (line 92) | multiple sites | comparison works |
| ooc | yes (line 93) | multiple sites | comparison works |
| isBehind | yes (line 95) | cp5Bite, shouldUseShred | comparison works |
| isImmuneRake | yes (line 99) | keepRake, shouldUseShred | comparison works |
| isImmuneRip | yes (line 100) | cp5Bite, shouldCastRip, shouldUseBite | comparison works |
| isPseudoInfiniteEnergy | yes (line 109) | multiple sites | comparison works |
| isTargetDummy | yes (line 105) | otMod, keepRake | comparison works |
| **isInBearForm** | **no** | burstMod (line 25), atkPowerBurst (lines 444, 449) | **relies on nil == falsy** |

See IN-05 below for details on the `isInBearForm` gap.

---

### 5. Interaction between IN-04 `isCanAttack` precondition and `isTrivialBattle`

**Verdict: WARNING. `isTrivialBattle` has the same vulnerability class as IN-04 but no guard.**

**Formula comparison:**

Both functions share the same health-estimate arm:

```lua
-- isFastBattleNotPvp (Druid.lua:825-828, WITH IN-04 guard)
clickContext.isFastBattleNotPvp = macroTorch.target.willDieInSeconds(localFastDieTime) or
    macroTorch.target.healthMax <=
        (macroTorch.player.mateNearMyTargetCount + 1) *
        macroTorch.estimatePlayerDPS() * localFastDieTime

-- isTrivialBattle (Druid.lua:798-801, NO guard)
clickContext.isTrivialBattle = macroTorch.target.willDieInSeconds(trivialDieTime) or
    macroTorch.target.healthMax <=
        (macroTorch.player.mateNearMyTargetCount + 1) *
        macroTorch.estimatePlayerDPS() * trivialDieTime
```

When the target is dead or nonexistent, `UnitHealthMax` returns 0, making the health-estimate arm:
```
0 <= (mateCount + 1) * DPS * 25    --> ALWAYS true
```

For `isFastBattleNotPvp`, IN-04 added this guard (Druid.lua:820-821):
```lua
if not macroTorch.target.isCanAttack then
    clickContext.isFastBattleNotPvp = false
else
    -- health computation
end
```

`isTrivialBattle` has no equivalent guard. The `willDieInSeconds` arm may independently short-circuit to true or false for a dead target (depending on `currentHRPS()`), but the health-estimate arm is unconditionally true.

**Impact analysis:**

| Caller | Called via | Pre-guarded? | Impact |
|--------|-----------|-------------|--------|
| `computeNormalRelic` (Druid.lua:377) | `isTrivialBattleOrPvp` | No (called at combo.lua:103, BEFORE isCanAttack check at line 122) | Wrong `normalRelic` computed; mitigated by `recoverNormalRelic`'s own isCanAttack guard (Druid.lua:435-436) |
| `shouldUseShred` (Druid.lua:772) | `isTrivialBattleOrPvp` | Yes (called from regularAttack inside combat block) | Not reachable |
| `shouldCastRip` (Druid.lua:1011) | `isTrivialBattleOrPvp` | Yes (called from keepRip inside combat block) | Not reachable |
| `shouldUseBite` (Druid.lua:1033) | `isTrivialBattleOrPvp` | Yes (called from getNextAbilityCost inside combat block) | Not reachable |
| `dischargeEnergyChangeRelicAndRip` (Druid.lua:268) | `isTrivialBattleOrPvp` via `shouldEquipSavagery` | Yes (called from keepRip inside combat block) | Not reachable |

The only unguarded call path is through `computeNormalRelic` (combo.lua:103). Its impact is bounded:

1. `isTrivialBattle` returns `true` for dead/missing target
2. `isTrivialBattleOrPvp` returns `true`
3. `computeNormalRelic` returns Builder idol (Ferocity/Emerald Rot) instead of Savagery
4. `recoverNormalRelic` at line 112 checks `isCanAttack` (Druid.lua:435) and returns early — no relic swap
5. `catAtk` at line 122 checks `isCanAttack` and calls `targetEnemy()` — no combat actions

**But:** `isTrivialBattle` is a public function on `macroTorch`. Future callers may not have the same implicit protection. This is the same class of latent defect that IN-04 fixed. See WR-02 below for the recommended fix.

---

## Findings

### WR-02: `isTrivialBattle` lacks `isCanAttack` guard — same vulnerability as fixed IN-04

**File:** `classes/druid/Druid.lua:794-805`
**Issue:** `isTrivialBattle` shares the same healthMax-estimate formula as `isFastBattleNotPvp` but has no `isCanAttack` precondition. When the target is dead or nonexistent, `UnitHealthMax` returns 0, making the health-estimate arm unconditionally true. IN-04 added an identical guard to `isFastBattleNotPvp` (Druid.lua:820-821), but the sister function was not updated.

Currently, the only unguarded call path is through `computeNormalRelic` (combo.lua:103), whose impact is bounded by `recoverNormalRelic`'s own `isCanAttack` guard at Druid.lua:435. However, `isTrivialBattle` is a public function on `macroTorch` — future callers could be affected.

**Fix:**
```lua
function macroTorch.isTrivialBattle(clickContext)
    if clickContext.isTrivialBattle == nil then
        -- WR-02: guard against dead/missing target (same class as IN-04 fix)
        if not macroTorch.target.isCanAttack then
            clickContext.isTrivialBattle = false
        else
            local trivialDieTime = 25
            clickContext.isTrivialBattle = macroTorch.target.willDieInSeconds(trivialDieTime) or
                    macroTorch.target.healthMax <=
                            (macroTorch.player.mateNearMyTargetCount + 1) *
                            macroTorch.estimatePlayerDPS() * trivialDieTime
        end
    end
    return clickContext.isTrivialBattle
end
```

This mirrors the IN-04 fix at Druid.lua:820-821 exactly and prevents the function from returning `true` for dead or nonexistent targets.

---

### IN-05: `clickContext.isInBearForm` never initialized in `catAtk` — implicit nil reliance

**File:** `classes/druid/combo.lua:55-109` (initialization block), `classes/druid/cat.lua:25,444,449` (consumption sites)

**Issue:** `burstMod` (cat.lua:25) and `atkPowerBurst` (cat.lua:444, 449) check `not clickContext.isInBearForm` to guard against using Juju Flurry, Juju Power, and Mighty Rage Potion in bear form. However, `catAtk` never populates this field on `clickContext`. Bear form code (`bear.lua:102`) does set it for its own path, confirming the field is part of the `burstMod`/`atkPowerBurst` contract.

Currently, this is not a bug because `catAtk` has an outer `isInCatForm` guard at combo.lua:50, and `isInBearForm` resolves to nil (falsy), making `not nil == true` — items are correctly allowed in cat form. But the field's nil status is accidental rather than intentional, creating a latent risk if `burstMod` is ever called from a code path where nil interpretation is ambiguous.

**Fix:** Add to `catAtk`'s clickContext initialization (after combo.lua:97):
```lua
clickContext.isInBearForm = player.isInBearForm
```

This mirrors what `bear.lua:102` already does and makes the field's value explicit, removing reliance on nil coercion.

---

### IN-06: `cp5Bite` called twice in ooc+5CP execution path — double-attempt per frame

**File:** `classes/druid/cat.lua:111,185` (call sites), `classes/druid/combo.lua:154,157` (invocation order)

**Issue:** When `clickContext.ooc` is true and `clickContext.comboPoints >= 5`, `cp5Bite` is called twice in the same frame:
1. `oocMod` (combo.lua:154) calls `cp5Bite` at cat.lua:185
2. `termMod` (combo.lua:157) calls `cp5Bite` at cat.lua:111

`clickContext.comboPoints` is a snapshot set at combo.lua:92 and is NOT live-updated after a successful cast. So the second call to `cp5Bite` sees `comboPoints == 5` regardless of whether the first call already consumed combo points.

Additionally, `clickContext.isGcdOk` is cached (Druid.lua:1212-1217) before any cast and reused by the second call, so GCD guards appear satisfied even though the first cast started the GCD.

In practice, the second cast attempt fails silently:
- `isSpellReady('Ferocious Bite')` returns false (on GCD or no combo points)
- Or the WoW engine ignores the duplicate `CastSpellByName`

This is a pre-existing code smell (not introduced by Phase 26), but the D-08 change now exposes it in the fast-battle path too (since `isFastBattleNotPvp` triggers `cp5Bite` when previously only `isImmuneRip`/`isRipPresent` did).

**Fix:** Add an early-return guard in `termMod` when OoC has already handled bite, or move the `oocMod` bite logic into `cp5Bite` exclusively:

```lua
-- Option A: skip termMod when ooc already consumed the opportunity
function macroTorch.termMod(clickContext)
    if not macroTorch.isSpellExist('Ferocious Bite', 'spell') then return end
    -- If OoC module dispatched a bite, termMod has nothing left to do
    if clickContext.ooc then return end
    macroTorch.tryBiteKillShot(clickContext)
    macroTorch.cp5Bite(clickContext)
end
```

Or, Option B: remove `cp5Bite` from `oocMod` and rely on `termMod` to handle all bite decisions uniformly. Either approach eliminates the double-attempt.

---

## Area-to-Finding Map

| Deep Analysis Area | Result |
|---|---|
| 1. `isFastBattleNotPvp` lazy-cache lifecycle | CLEAN — no double-evaluation or stale-cache edges |
| 2. `getNextAbilityCost` fastBattle guard interaction | CLEAN — reshift/FF timing benchmarks correct |
| 3. P-02 `rawget`/nil-restore pattern | CLEAN — metatable __index chain correctly re-exposed |
| 4. Cross-module `clickContext` propagation | MINOR — IN-05: `isInBearForm` never initialized |
| 5. `isTrivialBattle` vs IN-04 `isCanAttack` guard | WARNING — WR-02: same vulnerability, no guard |

---

_Reviewed: 2026-08-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_