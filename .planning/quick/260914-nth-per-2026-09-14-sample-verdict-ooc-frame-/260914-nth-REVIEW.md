---
phase: quick-260914-nth
reviewed: 2026-09-14T09:46:12Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase quick-260914-nth: Code Review Report

**Reviewed:** 2026-09-14T09:46:12Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed commit `c1f4e67` (scope: `classes/druid/Druid.lua` +8/-1, `classes/druid/selftest.lua` +52/-3). The core change — branch 3 of `shouldUseShred` flipping 3+ bleed free frames (ooc OR pseudo-infinite) to Shred behind, while paid frames keep Claw — is implemented correctly and consistently:

- The new and-chain at Druid.lua:1023 is byte-identical to branch 2 (line 1015) and uses the same `infiniteEnergy` local defined at line 989 (no new mismatch).
- Paid frames short-circuit `(false or false) and ...` to `false`, byte-same as the old `return false`.
- The cast path (`regularAttack`, cat.lua:45-61) consumes ooc identically for Shred as for Claw (`shred('ready')` on ooc, line 49-53) — a path already exercised at 0/1/2 bleeds, now extended to 3+.
- The R6-05 rewrite follows the CR-01 discipline exactly (rawget snapshot, own-key shadow, pcall, then rawset + kill-shot stub restore BEFORE all asserts — selftest.lua:512-523). R6-05b's no-shadow comment is accurate: the and-chain short-circuits before the `isBehindAttackJustFailed` accessor.
- The folded SHRED_E pin trace is deterministic: kill-shot stubbed false, trivial arm killed by `isImmuneRip=true`, cp5 arm killed by `comboPoints=1`, `isFastBattleNotPvp=false` preset; getNextAbilityCost resolves step 5 → `ctx.SHRED_E`. Verified against all helper bodies (Druid.lua:1205-1240, 1270-1295, 1058-1078, 1034-1051).
- `shouldDoReshift` (cat.lua:252-281) is genuinely unaffected on 3+ bleed free frames: ooc excluded at cat.lua:258 before `getNextAbilityCost` is reached, and on infinite frames the higher cost only hardens `math.ceil(projectedEnergy) < nextAbilityCost`.
- All other `getNextAbilityCost`/`shouldUseShred` consumers (R2/R8 test ctxs, Druid.lua:1684 selftest, combo.lua rotation + `leveling.lua` inlines its own logic per its header comment) have ≤2-bleed or paid-frame contexts; the only `isPouncePresent = true` ctxs repo-wide are the new R6-05/R6-05b. No existing test expectation changes.
- Lua 5.0 compliance, LF endings, English-only comments verified (no `#`/`goto`/`::` in added lines).

Two warnings remain: the plan's claim of a zero net effect on `shouldCastFFDuringWaitWindow` rests on an inverted inequality argument (there is a narrow but real, unadmitted, client-unverified behavior delta on Essence frames at exactly 0 energy), and branch 3's return value can now be `nil` instead of `false` on frames where both flags are undefined.

## Warnings

### WR-01: Zero-delta energy argument is inverted for `shouldCastFFDuringWaitWindow`; a narrow FF-fill delta exists and is unverified

**File:** `classes/druid/Druid.lua:1190` (condition `currentEnergy < minAbilityCost`; also PLAN.md line 65 and SUMMARY.md "能量估算影响论证" section)
**Issue:** The plan claims "SHRED_E 更贵只会使该条件更不可能成立" for the FF consumer. That is directionally inverted: a HIGHER `minAbilityCost` makes `currentEnergy < minAbilityCost` MORE likely, not less. Working through the full gate set (`projectedEnergy >= minAbilityCost and currentEnergy < minAbilityCost and waitSeconds >= 1.0`, Druid.lua:1185-1199), the FF trigger on a non-ooc infinite frame requires `currentEnergy <= minAbilityCost - erps`. Since `isPseudoInfiniteEnergy` is defined as `erps >= SHRED_E` (combo.lua:108, i.e. erps ≥ 60), pre-change (min = CLAW_E = 45) the trigger bound was ≤ -15 — unreachable; post-change (min = SHRED_E = 60) the bound is ≤ 0, i.e. FF fill now fires on frames with `currentEnergy == 0` and erps exactly 60 (naked Essence: AUTO_TICK 10 + 50, no Tiger/Berserk; Tiger's +10/3 already pushes erps past the bound). Example frame: Essence active, 3+ bleeds, behind, mana 0 → before: waitSeconds = 45/60 = 0.75 → no FF; after: 60/60 = 1.0 → FF cast that previously did not happen. So the "差 ≈ 0 / never triggers" claim is false for one consumer, and the delta is unrun/unverified on client (acknowledged as "Unrun Verification" only for R6-05/R6-05b, not for this rotate-level effect). The gameplay impact is likely neutral-to-positive (FF fills an otherwise-idle GCD and does not consume energy), but the documented reasoning is faulty and would mislead later tuning of the FF/reshift economics.
**Fix:** (1) Correct the reasoning in PLAN/SUMMARY docs: for `shouldCastFFDuringWaitWindow`, a higher `minAbilityCost` widens the `current < min` clause — the net-zero claim holds only via the `waitSeconds >= 1.0` gate, and the delta region is the razor-thin `currentEnergy == 0 and erps == 60` case. (2) Either pin this edge with a selftest (a 3-bleed infinite ctx with `player.mana` 0 and erps 60, asserting the intended FF verdict either way) or explicitly record the delta as accepted (like T-260914-nth-03's accept disposition, but with the correct directionality). (3) Until client-verified, do not cite "never triggers" for the FF consumer.

### WR-02: Branch 3 now returns `nil` instead of `false` when both `ooc` and `isPseudoInfiniteEnergy` are undefined

**File:** `classes/druid/Druid.lua:1023`
**Issue:** `return (clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not ...` evaluates to `nil` when `clickContext.ooc` is falsy AND `clickContext.isPseudoInfiniteEnergy` is nil, because `false or nil` is `nil` and `nil and ...` is `nil`. The previous branch 3 returned a strict boolean `false` for every 3+ bleed paid frame. All three current consumers (`regularAttack` cat.lua:48, `getNextAbilityCost` step 5 Druid.lua:1234, both `if`-tests) treat nil as falsy and today every production clickContext is fully built (combo.lua:108 sets `isPseudoInfiniteEnergy`), and the existing strict `== false` selftests (R6-04/R6-05b) preset both fields — so no current misbehavior. However the return-type contract of the only branch that previously guaranteed a boolean is weakened, mirroring the pre-existing branch 2 shape; any future strict-equality consumer (e.g., a new `shouldUseShred(ctx) == false` self-test with a hand-built ctx missing `isPseudoInfiniteEnergy`) would silently get nil and a confusing failure.
**Fix:** Force a boolean: `return ((clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed) == true` (and optionally align branch 2 at line 1015 the same way), or normalize `local infiniteEnergy = clickContext.isPseudoInfiniteEnergy == true` at line 989. Cheap, restores the strict boolean contract on all three branches, and keeps the pinned and-chain count intact when applied with the `== true` suffix (note: GATE 1's literal grep for the bare and-chain at Druid.lua would need its `-F` needle adjusted if branch 3 alone is changed; keeping the bare expression and appending `or false` is an alternative that leaves both grep needles intact minus truncation — either is acceptable, pick one and re-pin the matching count).

## Info

### IN-01: Branches 2 and 3 of `shouldUseShred` are now semantically identical — mergeable

**File:** `classes/druid/Druid.lua:1013-1024`
**Issue:** After this change the `elseif bleedCount == 2` branch and the `else` branch return the same expression. The 2-bleed distinction no longer carries any decision weight; the decision tree could collapse to `if bleedCount <= 1 then ... else return <chain> end`. Keeping both is harmless and preserves the historical branch narrative (the sample-verdict comment sits on branch 3), so this is a simplification opportunity, not a defect.
**Fix:** Optional refactor: delete the `elseif bleedCount == 2` line and merge, moving the sample-verdict comment to the merged else. If left as-is for diff-minimality, a one-line comment on branch 2 noting "same chain as 3+ bleeds" would help future readers.

### IN-02: Asymmetric free-frame combinations untested at 3+ bleeds

**File:** `classes/druid/selftest.lua:484-552`
**Issue:** R6-05 sets `ooc = true` AND `isPseudoInfiniteEnergy = true` simultaneously; R6-05b sets both false. The two asymmetric membership cases — pure OoC (`ooc=true, isPseudoInfiniteEnergy=false`) and pure infinite (`ooc=false, isPseudoInfiniteEnergy=true`) — are not asserted at 3+ bleeds. Risk is low because the new chain is byte-identical to branch 2, whose asymmetric cases are covered by R6-03 (pure ooc, 2 bleeds) and R6-02 (pure infinite, 0 bleeds, even with `ooc` key entirely absent), but the 3-bleed branch's own border coverage would be more robust with one extra paid/free diagonal case.
**Fix:** Optional: add R6-05c asserting `shouldUseShred(ctx) == true` for `ooc=true, isPseudoInfiniteEnergy=false, 3 bleeds, behind` (or infinite-only variant). Cheap and directly pins the exact branch taken at the bleed-count boundary.

---

_Reviewed: 2026-09-14T09:46:12Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_