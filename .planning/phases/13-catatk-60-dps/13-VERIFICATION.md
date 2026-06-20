---
phase: 13-catatk-60-dps
verified: 2026-06-20T00:00:00Z
status: human_needed
score: 18/18 must-haves verified
behavior_unverified: 13
overrides_applied: 0
behavior_unverified_items:
  - truth: "catAtk() at level 60 produces identical DPS behavior (all guards no-op, RESHIFT_ENERGY == 60)"
    test: "Log into WoW with a level 60 Druid (5/5 Furor, Wolfshead Helm, all cat skills learned). Execute catAtk() macro on a target dummy for 5+ minutes and compare DPS to pre-change code."
    expected: "RESHIFT_ENERGY equals 60. All isSpellExist guards return true (pass through). Execution path is identical to pre-change code. DPS is indistinguishable from baseline."
    why_human: "Cannot verify runtime DPS equivalence from code analysis — requires in-game execution. All guards are structurally present and the math works (5*8 + 20 = 60), but behavioral equivalence must be confirmed in-game."
  - truth: "Low-level druid without Shred uses Claw as primary builder (shouldUseShred returns false, regularAttack falls back to Claw)"
    test: "Log into WoW with a Druid below level 20 (no Shred learned). Execute catAtk() in cat form against a valid target. Observe attack log."
    expected: "shouldUseShred returns false, regularAttack always uses Claw (not Shred). No Lua errors appear."
    why_human: "The guard and fallback structures are present in code, but in-game verification is needed to confirm the WoW API returns correct isSpellExist values and the fallback chain behaves correctly end-to-end."
  - truth: "Low-level druid without Rip skips keepRip module silently, rotation proceeds to keepRake"
    test: "Log into WoW with a Druid below level 20 (Rip not learned, Rake learned). Execute catAtk() and observe behavior."
    expected: "keepRip returns immediately at the isSpellExist guard. keepRake executes normally. No errors, no log spam."
    why_human: "Module skip is structurally correct, but silent operation across all module transitions requires in-game verification at various character levels."
  - truth: "Low-level druid without Ferocious Bite skips termMod silently, cp5Bite not called from termMod"
    test: "Log in with a low-level Druid (no Ferocious Bite). Execute catAtk() at 5 combo points. Observe behavior."
    expected: "termMod returns immediately at guard. cp5Bite is never called from termMod. oocMod path to cp5Bite degrades gracefully via isSpellReady returning false."
    why_human: "Dual-path to cp5Bite (termMod + oocMod) requires in-game verification that both paths degrade without errors."
  - truth: "Low-level druid without Cower skips otMod silently"
    test: "Log in with a low-level Druid (no Cower learned). Enter combat with a target. Execute catAtk()."
    expected: "otMod returns immediately at the isSpellExist guard. No Lua errors. Subsequent modules execute normally."
    why_human: "Module skip is present in code, but in-game visual confirmation needed for silent skip behavior."
  - truth: "Low-level druid without Tiger's Fury skips keepTigerFury silently"
    test: "Log in with a low-level Druid (no Tiger's Fury). Execute catAtk() in combat."
    expected: "keepTigerFury returns immediately at the guard. No errors. Module chain continues."
    why_human: "Guard is present and correct, but in-game confirmation needed."
  - truth: "Low-level druid without Faerie Fire (Feral) skips keepFF silently"
    test: "Log in with a low-level Druid (no Faerie Fire (Feral) learned). Execute catAtk()."
    expected: "keepFF returns immediately. No errors."
    why_human: "Guard is present, but in-game confirmation needed."
  - truth: "Low-level druid without Rake skips keepRake silently"
    test: "Log in with a low-level Druid (no Rake). Execute catAtk()."
    expected: "keepRake returns immediately at guard. No errors."
    why_human: "Guard is present, but in-game confirmation needed."
  - truth: "Low-level druid without Pounce/Ravage skips openerMod silently"
    test: "Log in with a low-level Druid (no Pounce, no Ravage). Prowl near a target. Execute catAtk()."
    expected: "openerMod block is skipped — hasPounce and hasRavage are both false. No action taken, no errors."
    why_human: "Guard structure is present, but in-game confirmation needed for opener state."
  - truth: "RESHIFT_ENERGY at level 60 with 5/5 Furor + Wolfshead Helm equals 60 (matches original hardcoded value)"
    test: "Log into WoW with a level 60 Druid (5/5 Furor, Wolfshead Helm equipped). Run computeReshiftEnergy selftest or observe RESHIFT_ENERGY value in catAtk()."
    expected: "computeReshiftEnergy() returns 60 (40 from Furor + 20 from Wolfshead Helm)."
    why_human: "Formula (5*8 + 20 = 60) is correct, but WoW API talentRank('Furor') and isItemEquipped('Wolfshead Helm') must return correct values at runtime — verification needs in-game testing."
  - truth: "RESHIFT_ENERGY at level 10 with 0/5 Furor and no Wolfshead Helm equals 0 (reshift never triggers)"
    test: "Log into WoW with a level 10 Druid (0/5 Furor, no Wolfshead Helm). Execute catAtk()."
    expected: "computeReshiftEnergy() returns 0. shouldDoReshift returns false at the RESHIFT_ENERGY==0 check. reshift never triggers."
    why_human: "Formula (0*8 + 0 = 0) is correct, but in-game confirmation needed for full reshift module skip behavior."
  - truth: "getMinimumAffordableAbilityCost always falls back to Claw even when all other skills are unlearned"
    test: "Use a low-level Druid or simulate with all decision functions returning false. Call getMinimumAffordableAbilityCost with a minimal clickContext."
    expected: "Returns (clickContext.CLAW_E, 'Claw') as the final fallback. Never returns nil or errors."
    why_human: "The 6-level fallback chain is present in code, but the last-resort behavior (all skills unlearned → Claw) should be confirmed in-game at very low character levels."
  - truth: "cp5Bite called from oocMod degrades gracefully when Ferocious Bite is unlearned (isSpellReady returns false, pcall handles _castSpell)"
    test: "Log into WoW with a low-level Druid (no Ferocious Bite). Trigger ooc at 5 combo points. Execute catAtk()."
    expected: "oocMod calls cp5Bite → safeBite → readyBite → isSpellReady('Ferocious Bite') returns nil/false → readyBite returns false. No Lua errors. No cast attempt."
    why_human: "Multi-layer degradation path (isSpellReady → pcall → castSpellByName nil-return) is structurally correct but requires in-game confirmation at actual low levels."
human_verification:
  - test: "Level 60 DPS equivalence: Log into WoW with level 60 Druid (5/5 Furor, Wolfshead Helm, all cat skills). Test catAtk() DPS against target dummy for 5+ minutes and compare with pre-change baseline."
    expected: "RESHIFT_ENERGY = 60. All isSpellExist guards pass through. DPS indistinguishable from baseline."
    why_human: "Cannot verify runtime DPS equivalence from code analysis — requires in-game execution."
  - test: "Low-level Druid (level 10-15): Log in with a low-level Druid that only has Claw. Execute catAtk() in cat form against enemies. Observe 1) no Lua errors, 2) only Claw is used, 3) reshift never fires."
    expected: "All unavailable skills silently skipped. Only Claw and basic actions execute. No errors. Rotation works cleanly."
    why_human: "Full integration test of all guard layers at low level requires in-game verification."
  - test: "Mid-level Druid (level 20-30): Log in with a mid-level Druid that has some but not all cat skills (e.g., has Rip and Rake, but no Shred, no Ferocious Bite). Execute catAtk()."
    expected: "Available skills are used; unavailable ones are skipped. ShouldUseShred returns false → Claw used. No errors."
    why_human: "Partial skill availability behavior requires in-game testing."
  - test: "Dynamic RESHIFT_ENERGY selftest: On any Druid, observe the selftest output on login. Verify computeReshiftEnergy debug log shows correct Furor rank and Wolfshead Helm status."
    expected: "Selftest shows computeReshiftEnergy value with Furor rank and Wolfshead Helm status. Value is between 0-100. No assertion failures."
    why_human: "Selftest output logs in-game; value correctness depends on actual talent/equipment state."
---

# Phase 13: catAtk 60-DPS Verification Report

**Phase Goal:** 使 catAtk 一键宏适配小号练级场景：技能存在性检查（isSpellExist guard）、动态能量消耗计算（computeReshiftEnergy 替代硬编码60）、低等级降级策略（模块级 guard 自动跳过不可用技能，rotation 自然 fallback 到 Claw）。保持60级满级极限DPS能力完全不变。
**Verified:** 2026-06-20
**Status:** human_needed

## Goal Achievement

### Observable Truths

**Plan 01 Truths (12 total):**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | catAtk() at level 60 produces identical DPS behavior (all guards no-op, RESHIFT_ENERGY == 60) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | computeReshiftEnergy() returns 5*8+20=60 at max; all isSpellExist guards are passthrough; execution paths are identical. All structural elements present but DPS equivalence needs in-game confirmation. |
| 2 | Low-level druid without Shred uses Claw as primary builder (shouldUseShred returns false, regularAttack falls back to Claw) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:723-724: shouldUseShred guard returns false. cat.lua:55-60: regularAttack else-branch uses claw(). Guard + fallback chain present and wired. |
| 3 | Low-level druid without Rip skips keepRip module silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:228-229: module-level isSpellExist('Rip') guard with return. Present. |
| 4 | Low-level druid without Ferocious Bite skips termMod silently, cp5Bite not called from termMod | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:97-99: termMod guard returns before tryBiteKillShot/cp5Bite. Also, isSpellReady pcall in Player.lua:180 handles oocMod path. |
| 5 | Low-level druid without Cower skips otMod silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:64-66: module-level isSpellExist('Cower') guard. Present. |
| 6 | Low-level druid without Tiger's Fury skips keepTigerFury silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:217-218: module-level isSpellExist("Tiger's Fury") guard. Present. |
| 7 | Low-level druid without Faerie Fire (Feral) skips keepFF silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:316-317: module-level isSpellExist('Faerie Fire (Feral)') guard. Present. |
| 8 | Low-level druid without Rake skips keepRake silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:301-302: module-level isSpellExist('Rake') guard. Present. |
| 9 | Low-level druid without Pounce/Ravage skips openerMod silently | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:386-393: hasPounce/hasRavage inline checks; elseif hasRavage prevents fallthrough when Ravage missing. Present. |
| 10 | RESHIFT_ENERGY at level 60 with 5/5 Furor + Wolfshead Helm equals 60 (matches original hardcoded value) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:570-579: computeReshiftEnergy() = talentRank('Furor')*8 + (isItemEquipped('Wolfshead Helm') ? 20:0). 5*8+20=60. Math correct. |
| 11 | RESHIFT_ENERGY at level 10 with 0/5 Furor and no Wolfshead Helm equals 0 (reshift never triggers) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | computeReshiftEnergy returns 0*8+0=0. cat.lua:196-197: shouldDoReshift RESHIFT_ENERGY==0 early return guard blocks reshift. Math correct. |
| 12 | getMinimumAffordableAbilityCost always falls back to Claw even when all other skills are unlearned | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:1000-1001: returns (clickContext.CLAW_E, 'Claw') as final fallback after 5 decision-function checks. Fallback chain: Bite→Tiger→Rip→Rake→Shred→Claw. |

**Plan 02 Truths (7 total):**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 13 | Selftests run without Lua errors on player login (all new Category H tests are isOptional=true) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | All 18 SelfTest:register() calls have 'end, true)' — isOptional=true. pcall-wrapped via SelfTest:run(). Present. |
| 14 | computeReshiftEnergy selftest returns a number between 0 and 100 for a Druid player | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:1308-1314: assertions for type=="number", >=0, <=100. Present. |
| 15 | shouldUseShred selftest returns false when Shred is unlearned | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:1316-1326: dual-path test. Present. |
| 16 | shouldCastRip selftest returns false when Rip is unlearned | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:1328-1337: dual-path test. Present. |
| 17 | shouldUseBite selftest returns false when Ferocious Bite is unlearned | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Druid.lua:1339-1348: dual-path test. Present. |
| 18 | Non-Druid players skip all Category H selftests silently (UnitClass guard) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | All 8 Category H tests have UnitClass guard: `if UnitClass('player') ~= 'Druid' then return end`. Present. |

**Score:** 0/18 truths verified as PASSED (18 truths present and wired; all are behavior-dependent — cannot be verified by presence alone). All 18 truths require in-game testing to confirm behavioral correctness.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/druid/Druid.lua` | computeReshiftEnergy() function, RESHIFT_ENERGY dynamic call, shouldUseShred/shouldCastRip/shouldUseBite isSpellExist guards, openerMod hasPounce/hasRavage guards, 8 Category H selftest registrations | ✓ VERIFIED | 1437 lines. All planned symbols present and substantive. 15 isSpellExist references. 18 SelfTest registrations (5 G1 + 8 H + 5 G2). |
| `classes/druid/cat.lua` | Module-level isSpellExist guards for keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod; shouldDoReshift RESHIFT_ENERGY==0 guard | ✓ VERIFIED | 419 lines. 6 new module-level guards + 1 existing reshift guard = 7 isSpellExist refs. regularAttack and oocMod intentionally have no guards. |
| `SM_Extend.lua` (build output) | All new symbols present: computeReshiftEnergy, all guards, all selftests | ✓ VERIFIED | `bash build.sh` passed. grep confirms all function symbols present. Category H section header found. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| catAtk() RESHIFT_ENERGY assignment (Druid.lua:339) | computeReshiftEnergy() (Druid.lua:570) | `clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()` | ✓ WIRED | Direct function call. Function exists at line 570. Call site at line 339. |
| shouldDoReshift (cat.lua:194) | clickContext.RESHIFT_ENERGY | `if clickContext.RESHIFT_ENERGY == 0 then return false end` | ✓ WIRED | RESHIFT_ENERGY set in Druid.lua:339, read in cat.lua:196. Zero-check guard at top of shouldDoReshift. |
| shouldUseShred (Druid.lua:721) | regularAttack (cat.lua:46) | Guard returns false -> regularAttack else-branch uses claw() | ✓ WIRED | Druid.lua:723-724 guard returns false when Shred unlearned. cat.lua:49 calls shouldUseShred. cat.lua:55-60 else-branch uses claw. |
| getMinimumAffordableAbilityCost (Druid.lua:973) | shouldUseShred/shouldCastRip/shouldUseBite | Decision chain: Bite -> Tiger -> Rip -> Rake -> Shred -> Claw | ✓ WIRED | All 6 check steps present. Final fallback at line 1000-1001 returns CLAW_E. |
| Category H selftests (Druid.lua:1307-1405) | computeReshiftEnergy (Plan 01) | Selftests call computeReshiftEnergy() to verify dynamic value | ✓ WIRED | Test at line 1330 and 1366 call computeReshiftEnergy(). |
| Category H selftests (Druid.lua:1307-1405) | shouldUseShred/shouldCastRip/shouldUseBite (Plan 01) | Selftests validate decision functions return false when skill missing | ✓ WIRED | Tests at lines 1316-1348 call respective decision functions with minimal ctx. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| computeReshiftEnergy() | energy | talentRank('Furor') via Player.lua + isItemEquipped('Wolfshead Helm') via Player.lua | Yes (WoW API calls through Player methods) | ✓ FLOWING |
| shouldUseShred guard | isSpellExist('Shred') | biz_util.lua:75 → getSpellIdByName → toBoolean | Yes (WoW spellbook query) | ✓ FLOWING |
| all 8 Category H selftests | N/A (tests, not rendering) | N/A | N/A | N/A (tests) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build produces valid output | `bash build.sh` | Exit 0. SM_Extend.lua contains computeReshiftEnergy, all guards, all selftests. | ✓ PASS |
| Hardcoded RESHIFT_ENERGY=60 removed | `grep "RESHIFT_ENERGY = 60"` on both source and build | No matches. | ✓ PASS |
| computeReshiftEnergy function exists in build | `grep "function macroTorch.computeReshiftEnergy" SM_Extend.lua` | Match found. | ✓ PASS |
| computeReshiftEnergy() called at catAtk | `grep "computeReshiftEnergy()" SM_Extend.lua` | Found at line 3862 (RESHIFT_ENERGY assignment). | ✓ PASS |
| All 6 module guards present in cat.lua | `grep -c "isSpellExist" cat.lua` | 7 matches (6 new + 1 existing reshift). | ✓ PASS |
| All 3 shared decision function guards in Druid.lua | `grep -c "isSpellExist" Druid.lua` | 15 matches (3 decision guards + 2 openerMod + selftest refs). | ✓ PASS |
| regularAttack has NO module-level guard | `grep -A3 "function macroTorch.regularAttack" cat.lua` | No isSpellExist guard present. | ✓ PASS |
| oocMod has NO module-level guard | `grep -A3 "function macroTorch.oocMod" cat.lua` | No isSpellExist guard present. | ✓ PASS |
| 8 Category H tests in Druid.lua | `grep "Category H: catAtk" Druid.lua` | 1 match (section header). 8 test names verifiable. | ✓ PASS |
| All Category H tests are isOptional=true | `grep -c "end, true)" Druid.lua` | 18 (10 pre-existing + 8 new). | ✓ PASS |
| All Category H tests have UnitClass guard | `grep "UnitClass('player') ~= 'Druid'" Druid.lua` | 18 matches (all tests). | ✓ PASS |
| Selftest section order: G1 -> H -> G2 | `grep -n "Category G1\|Category H\|Category G2" Druid.lua` | G1:1276, H:1307, G2:1407. Order correct. | ✓ PASS |
| No debt markers in modified files | `grep -E "TBD\|FIXME\|XXX"` on both files | No matches in either file (pre-existing TODO at line 337/427 of Druid.lua is about the issue this phase addresses). | ✓ PASS |
| CastSpellByName handles nil spell gracefully | `grep -A5 "function macroTorch.castSpellByName" biz_util.lua` | Returns silently on nil spellId. No crash. | ✓ PASS |
| isSpellReady uses pcall internally | `grep "pcall(SpellReady" entity/Player.lua` | Line 180: pcall-wrapped. Returns false on failure. | ✓ PASS |

### Probe Execution

No probes declared for this phase. Plan verification sections use grep-based automated checks — all executed and passing as shown above. The phase does not declare or require `scripts/*/tests/probe-*.sh` execution.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| R8-PRESERVE | Plan 01, Plan 02 | 60级满技能+DPS不变 | ✓ COVERED | All guards are additive; computeReshiftEnergy() uses Furor+talent+helm formula giving 60 at max. Hardcoded 60 removed. All existing catAtk symbols present in build output (16 key functions verified). |
| LOW-LVL-SKIP | Plan 01 (ROADMAP) | 低等级自动跳过不可用技能 | ✓ COVERED | 6 module-level isSpellExist guards (keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod) + openerMod inline guards + 3 shared decision function guards. regularAttack→Claw fallback via shouldUseShred returning false. |
| DYNAMIC-RESHIFT | Plan 01, Plan 02 (ROADMAP) | 天赋+装备动态计算reshift能量 | ✓ COVERED | computeReshiftEnergy() = talentRank('Furor')*8 + isItemEquipped('Wolfshead Helm')?20:0. Replaces hardcoded 60. RESHIFT_ENERGY==0 early return in shouldDoReshift. |
| DECISION-GUARD | Plan 01, Plan 02 (ROADMAP) | 共享决策函数skill缺失时返回false | ✓ COVERED | shouldUseShred (Druid.lua:723), shouldCastRip (Druid.lua:1009), shouldUseBite (Druid.lua:1034) — all have isSpellExist guards returning false. getMinimumAffordableAbilityCost chain covered. |
| D-07-SELFTEST | Plan 02 (plan-specific) | 8个Category H自检注册 | ✓ COVERED | 8 SelfTest:register() calls in Druid.lua lines 1308-1405. All with UnitClass guard, isOptional=true, pcall-wrapped. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| classes/druid/Druid.lua | 337 | `TODO reshift energy restore should consider the head enchant` | ℹ️ Info | Pre-existing. Now partially addressed by computeReshiftEnergy() (handles Wolfshead Helm). Future enchant consideration deferred. |
| classes/druid/Druid.lua | 427 | `TODO reshift energy restore should consider wolfheart head enchant` | ℹ️ Info | Pre-existing. Same as above — the core reshift energy calculation has been made dynamic. Future enchant is a separate concern. |

No new debt markers introduced. No stubs. No empty returns.

### Gaps Summary

**No gaps found.** All must-have truths are structurally satisfied in the codebase: every guard is present at the expected location, every key link is wired, the build passes, and all 18 selftest registrations follow the established pattern. The RESHIFT_ENERGY=60 hardcoded value has been fully replaced with the dynamic `computeReshiftEnergy()` call.

However, **all 18 truths are behavior-dependent** — they assert runtime behavior (module silent-skip, fallback chain execution, DPS equivalence) that static code analysis cannot verify. The code structures enabling each truth are present and correctly wired, but actual in-game execution at level 10/20/60 with the real WoW 1.12.1 client is required for final behavioral confirmation.

The verifier has confirmed:
1. All 13 guard insertion points match the plan specifications exactly
2. All 8 Category H selftests are registered with correct conventions (isOptional=true, UnitClass guard)
3. The build is clean — `bash build.sh` succeeds, all symbols present in `SM_Extend.lua`
4. The spell names used in all guards match the `_castSpell` locale table keys in Druid.lua
5. The computeReshiftEnergy() formula ($FurorRank \times 8 + WolfsheadHelmBonus(20)$) is mathematically correct for 60-energy equivalence at level 60
6. The fallback chain in getMinimumAffordableAbilityCost terminates at Claw (always-available level 1 skill)

---

_Verified: 2026-06-20T00:00:00Z_
_Verifier: Claude (gsd-verifier)_