---
phase: 29-landing
reviewed: 2026-09-10T03:32:55Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/HUMAN-UAT.md
  - classes/druid/selftest.lua
  - classes/hunter/Hunter.lua
  - core/spell_trace_core.lua
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-09-10T03:32:55Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the phase-29 unified landing refactor at standard depth with adversarial focus on the requested
dimensions: dedup predicate and window arithmetic (off-by-one / boundary inclusivity at exactly
`blip == ttl` and `failTime == cast + ttl`), Lua nil/table edge cases (the `landIntentTtls[spell] or
LAND_INTENT_TTL` fallback, refresh/purge invariants in `pairLandIntent`), event-order races, and selftest
fixture faithfulness. Cross-file tracing covered `LRUStack` (`core/periodic.lua` — `top` is a metatable
accessor returning `elements[len]`, `removeMatch` removes the newest match, confirming Q-05/Q-12/Q-15
size/top assertions), the periodic task scheduler, `combat_context.lua` lifecycle, `events.lua` tier
dispatch, and build-order file loading.

**Verified correct (no findings raised):**

- **Dedup predicate arithmetic.** `recordLandEvent` (spell_trace_core.lua:325-329) `lastLand >= lastCast`
  fires only when both exist; `peekLandEvent(...) or 0` yields `0 >= lastCast == false` for real clocks,
  so the no-land and no-cast paths push freely (Q-07, Q-10, Q-16 fixtures rely on exactly this).
- **Boundary inclusivity in code.** `blip <= ttl` keeps the silent window open at exact equality and the
  inference fires strictly after ttl (fires one tick later at most; tick is 0.1s — design noise). The
  D-04 fail veto upper bound `(lastFail[1] - lastCast) <= ttl` and `finalizeFail`'s
  `0 <= failTime - castAt <= intent.ttl` are inclusive at both edges. `pairLandIntent` purge (`> ttl`) vs
  pair (`<= ttl`) agree at equality: an intent at exactly ttl pairs instead of expiring — consistent
  with the D-05 "one parameter, three reads" contract.
- **intent.ttl threading (D-08/D-10).** Seeding (`ttl = landIntentTtls[spell] or LAND_INTENT_TTL`),
  pairLandIntent purge and pair, and finalizeFail's window all read `intent.ttl or LAND_INTENT_TTL`;
  hunter stings seed 2, druid bleeds 0.9. Q-14 pins the split behavior.
- **Fail-wins machinery (D-06).** `finalizeFail` consumes pending/landed intents in-window, revokes the
  paired land via `removeMatch`, and `pairLandIntent` never pairs a failed intent, so cast → fail → apply
  and cast → apply → fail orderings both resolve fail-first (Q-05/Q-06 pin it).
- **Fixture CR-01 discipline.** Q-02..Q-16 snapshot/restore globals, run framework calls under pcall,
  and run asserts only after restoration; Q-04/Q-13/Q-15 correctly read `.top` and `.elements` of the
  seeded LRUStacks.
- **Registration loading.** Q-01 asserts `Serpent Sting`/`Scorpid Sting` tracing/ttl state although
  Hunter.lua loads after druid/selftest.lua in build_order.txt — safe because `SelfTest:register` defers
  the bodies and the assertions run at `/mt` time, after all registrations executed.

**Accepted design residuals (explicitly locked; not re-opened):** multi-cat mispairing inside the
intent window (spell_trace_core.lua:457-461 comment), hunter-ballistic anchor bias (D-18), post-ttl fail
boundary, and cpDamage's 0.9s window (D-17).

**Key concerns (below):** a duplicated/misleading green announcement on Rake/Pounce dual-channel casts;
an unguarded stale-cast inference path across retargeting and combats; stale "2s" documentation that
contradicts the locked D-05 cleanup clause; and a HUMAN-UAT troubleshooting branch describing
output the implemented machinery cannot produce. No CRITICAL defects were provable: the decision-facing
consumers (`ripLeft`/`rakeLeft`/`pounceLeft` with clamp, `isRipPresent` debuff AND) neutralize the
worst ledger corruptions.

## Warnings

### WR-01: Self-hit path announces green even when the cast-dimension dedup drops the land

**File:** `core/spell_trace_core.lua:542-554` (announce at 550-553, dedup at 325-329)

**Issue:** `onSelfDamageLine` prints the green `landed` line unconditionally and only afterwards calls
`recordLandEvent`, whose dedup may silently drop the write. This is asymmetric with
`processRawAuraApply` (462-473), which announces only when an intent paired. For the two deliberately
dual-channel spells — Rake and Pounce (self-hit line plus aura-apply line, per
Druid.lua:806-818) — when the apply line pairs first (intent consumed, land pushed) and the self-hit
arrives afterwards, the self-hit prints a second green `landed` line for the same cast while the ledger
write was deduped (`lastLand >= lastCast`). The chat then shows two landings where the land table holds
one, and a green line can be printed for a cast whose write never entered the table. This is the exact
observable layer the HUMAN-UAT Phase-29 section uses to judge correctness ("Rake / Ferocious Bite 恒绿
『landed』"), so a player verifying the phase sees confusing double confirmations.

**Fix:** Make the announcement follow the dedup outcome — e.g., have `recordLandEvent` return whether it
pushed, and gate the announce on the return:

```lua
-- in onSelfDamageLine:
local pushed = macroTorch.recordLandEvent(spell, now)
if pushed and macroTorch.loginContext and macroTorch.target.isCanAttack then
    macroTorch.show(spell .. ' cast on ' .. macroTorch.target.name .. ' landed: ' .. now, 'green')
end
```
(or move the green line inside `recordLandEvent` after the dedup `return`; apply the same to the
announce-before-write in `processRawAuraApply` 470-472, which has the same theoretical ordering gap).

### WR-02: Stale-cast inference has no epoch guard — cross-combat / retarget pollution

**File:** `core/spell_trace_core.lua:396-427` (trigger edge 406-407, push 423)

**Issue:** `computeLandTable` bounds the silent window only from below (`blip <= ttl`). `loginContext`
and its cast/fail/land tables persist for the whole login session (`combat_context.lua:42-45`), and
`onCombatExit` (combat_context.lua:21-27) clears only `macroTorch.context`, not the spell tables. So a
cast that produced no evidence and whose window never elapsed while it was targeted survives
indefinitely. Concrete failure: cast Rip on MobA at t=10; the mob dies or the player retargets within
0.9s (window never closes while targeted); in a later combat the player retargets a mob with the same
name → the 0.1s `maintainLandTables` tick finds `lastCast = 10`, `blip = 50+ > ttl`, `lastLand = 0 < 10`,
no in-window fail → pushes the ancient anchor 10 and emits a blue
`Rip cast on MobA landed: 10 (inferred)` line for a bygone cast. Consequences: misleading chat, a
meaningless land-stack entry, and a `lastLand` that can transiently shadow dedup decisions for the
current combat. Combat decisions are protected only because `ripLeft` clamps to 0 and `isRipPresent`
requires the target debuff.

**Fix:** Add an upper bound on the inference window — e.g., after the `blip <= ttl` return, treat a cast
older than a grace period (say `blip > ttl + 5` or `ttl * 6`) as abandoned and skip it; or clear the
per-mob cast/fail/land spell tables in `onCombatExit` (one clear hook keeps tables fresh per combat).

### WR-03: Stale "2s" comments contradict D-05/D-17 and misstate the live cpDamage window

**File:** `core/spell_trace_core.lua:214` ("`Reuses macroTorch.LAND_INTENT_TTL (2s, D-02).`") and
`core/spell_trace_core.lua:459` ("`(<=2s land offset)`")

**Issue:** `LAND_INTENT_TTL` is now 0.9. DESIGN-CONTEXT locked decision 5 explicitly requires the 2s
legacy wording to be updated with the refactor ("其 2s 旧值说明需随重构更新"); 29-01/29-02 deferred it
("留给 29-02 的注释清理条款处理") and 29-03's closing battery did not clean them. A maintainer reading
line 214 believes the cpDamage pairing window is 2s when it is 0.9 — and the actual consequence of the
0.9 window for the phase-28 feature (damage samples whose landing lags the cast by more than 0.9s are
silently purged, e.g. on >0.9s-RTT connections) is documented nowhere at that site. D-17 locks the
behavior; only the comments are wrong and they actively mislead.

**Fix:** Rewrite both comments to the current constant semantics, e.g. line 214:
`-- Reuses macroTorch.LAND_INTENT_TTL (0.9s default, D-17); samples whose damage line lags the cast by
more than the window are purged unpaired,` and line 459: `-- pending window can pair with our cast intent
(<= 0.9s default land offset); fail`.

### WR-04: HUMAN-UAT troubleshooting branch (b) describes output the implemented machinery cannot produce

**File:** `classes/druid/HUMAN-UAT.md:266`

**Issue:** Branch (b) lists "蓝色推断后紧跟红色『was cancelled by ...』" (blue `(inferred)` line followed
by a red cancel line) as an expected fail-wins observation. With the shipped code this sequence is
impossible: `finalizeFail` revokes a land only when the intent is in state `'landed'`
(spell_trace_core.lua:502), and an intent becomes `'landed'` only through pairing — the inference push
(`computeLandTable` push at 423) never marks any intent landed, so nothing ties a blue line to any
revocable intent. Additionally, any fail arriving after the inference fired must have
`failTime > cast + ttl` (the inference only fires after `blip > ttl`), which falls outside both the veto
window (420) and `finalizeFail`'s window (501). A red cancel can only follow a green paired land. The
verifier reading this branch expects to observe a red line that can never occur and may chase a ghost.

**Fix:** Rewrite branch (b) as the green-then-red observation:
`b) 绿色 landed 后紧跟红色『was cancelled by ...』：同 cast 的 fail 在窗口内到达，fail-wins 撤销已配对的落
地（蓝色 (inferred) 行按边界设计永不被撤销——fail 必在窗口外到达）`

## Info

### IN-01: No fixture pins the exact boundary at `delta == ttl` / `failTime == cast + ttl` / `blip == ttl`

**File:** `classes/druid/selftest.lua:1221-1253` (Q-14), `:1151-1219` (Q-13), `:1054-1105` (Q-11)

**Issue:** All three window edges implement inclusive `<=` semantics whose correctness turns on a single
character (`<` vs `<=`). Q-14's title/comment claims "ttl 双边界" but drives a mid-window 1.5s delta
against ttl 0.9 (expire) and 2 (pair) — the exact `delta == ttl` pair/expire split is never pinned;
Q-13's veto phases use +0.5 and -0.1 offsets, not `failTime == cast + ttl`; Q-11 uses a 2.0s old cast,
not `blip == ttl`. Given the phase's own emphasis on boundary correctness, these three edges are the
most regression-prone spots and remain unpinned.

**Fix:** Add exact-edge assertions (or one three-phase fixture): pair at `castAt + 0.9` must succeed for
a ttl-0.9 intent; `failTime == castAt + ttl` must veto; and a cast at `GetTime() - ttl` must stay silent.

### IN-02: Q-02 fixture only rewires the intent's castAt — the castTable entry keeps the live clock

**File:** `classes/druid/selftest.lua:836-838`

**Issue:** The comment claims the seeded `castAt 1000.0` sits "inside the 0.9 default window" relative
to the 1000.5 apply — true for the intent pairing math — but `recordCastTable('Rip')` pushed the real
client `GetTime()` into `castTable`, so `recordLandEvent`'s dedup runs against a `lastCast` on the live
clock while the land time is 1000.5. Q-02 passes and pins pairing/landing, but the cast-dimension dedup
is only actually pinned by Q-12/Q-15 (which seed `castTable` correctly). The Q-02 comment overstates its
coverage.

**Fix:** Extend the Q-02 comment with one clause, e.g. "castTable entries keep the live clock on
purpose; cast-dimension dedup coverage belongs to Q-12/Q-15."

### IN-03: Expired intents are state-flipped but never removed — scans accumulate within the 32 cap

**File:** `core/spell_trace_core.lua:190-195`

**Issue:** The pairLandIntent purge marks stale intents `'expired'` but leaves the rows in
`stack.elements` until LRU eviction (cap 32). Inferred-landed casts consume nothing, so their intents
stay `'pending'` indefinitely and every later `pairLandIntent` visit rescans them. Bounded and
behaviorally inert (the pair pass filters on `'pending'`), but `pairCpDamageIntent`'s purge already
demonstrates the removal idiom (lines 221-226) that could be mirrored here.

**Fix:** `table.remove(stack.elements, i)` in the purge pass when expiring (or leave as-is and note the
LRU cap as the bound — cosmetic churn only).

---

_Reviewed: 2026-09-10T03:32:55Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

Note: the review-config file list contained `core/spell_trace_core.l.lua` (double-l typo); the actual
file `core/spell_trace_core.lua` was reviewed and is listed in `files_reviewed_list`.