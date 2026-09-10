---
phase: 29-landing
reviewed: 2026-09-10T06:30:00Z
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
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 29: Code Review Report (Second Pass)

**Reviewed:** 2026-09-10T06:30:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Second adversarial pass over the phase-29 unified landing refactor (D-01..D-18), per the user-mandated
focus areas: (1) landing-refactor re-verification, (2) cpDamage regression vs the LAND_INTENT_TTL 2s -> 0.9
change, (3) cast-to-cast interval computation regression, (4) standard phase-diff review of all five
scoped files. Supporting facts were re-verified against the current tree: `LRUStack` (core/periodic.lua:
push evicts oldest at cap, `top` = `elements[len]` accessor, `removeMatch` removes newest match),
`macroTorch.inCombat` set by combat_context.lua:22/33 (PLAYER_REGEN events), `toBoolean`/`tableLen`/
`jsonEncodeScalar` (impl_util.lua), the events.lua dispatch tiers (onSelfDamageLine at 101, RAW tier-1/2
at 139/155-164, UNIT_CASTEVENT bridge at 121-129), and the full git diff of the phase
(`LAND_INTENT_TTL 2->0.9`; `landSources` table removed; `recordCastTable` intent seeding now carries
`intent.ttl`; `finalizeFail` gained the D-04 lower bound `>= 0`; `recordLandEvent` gained the
cast-dimension dedup; `recordLandEventRenewal` added; `maintainLandTables`/`computeLandTable` revived;
register points migrated in Druid.lua/Hunter.lua). No CRITICAL defects are provable — the decision-facing
consumers (`ripLeft`/`rakeLeft`/`pounceLeft` clamping, `isRipPresent`/`isRakePresent` debuff AND)
neutralize the worst ledger corruptions.

**Carried forward from the first pass (all 7 still valid, none dropped):** WR-01 (unconditional green
announce despite dedup drop), WR-02 (stale-cast inference has no epoch guard), WR-03 (stale "2s"
comments), WR-04 (HUMAN-UAT branch (b) describes impossible output), IN-01 (no exact ttl-boundary
fixture), IN-02 (Q-02 fixture overstatement), IN-03 (expired intents never removed). Anchors re-verified
against the current on-disk files; none moved.

**New this pass:** WR-05 (self-hit channel has no target-ownership check — asymmetric with the apply
channel's guid check) and IN-04 (name-keyed storage granularity vs guid ownership granularity).

**User regression question 1 — cpDamage impact of the 2s -> 0.9 window: MINOR (instrumentation-only).**
`pairCpDamageIntent` was not structurally changed this phase (diff-confirmed); only the shared constant
it reads changed. Both the purge (spell_trace_core.lua:223) and pair (234) windows are now 0.9s. Concrete
timing: `castAt` is the pre-cast sample `GetTime()` (Druid.lua cpDamageSample), so the delta to the
damage line's process time is RTT + one frame + client event-batch delay — on healthy CN->EU paths
(~200-500ms RTT) the window holds. Because 0.9 < the 1.0s cat GCD, the design's "cross-cast intersection
is mathematically impossible" argument holds: at most one live intent can be in-window at any time, so
cast chains can never mispair; the only failure mode is a row silently dropped when total latency
exceeds 0.9s (lag spike, client soft-freeze, degraded route). That loses the occasional [cpDamage] row
from the offline stats tool — it never alters combat behavior. D-17 explicitly locks this trade-off, so
this is a documented, minor, edge-case regression; the stale "(2s, D-02)" comment at line 214 makes it
look unintended (WR-03).

**User regression question 2 — cast-to-cast interval computation impact: NONE.** The only live
cast-to-cast delta in the addon is `recordCastTable`'s 0.2s same-spell dedup
(spell_trace_core.lua:116-119) and its `GetTime()` timestamp sourcing — the phase-29 diff touches only
its comment and adds intent seeding beside it; both the 0.2s threshold and the clock are unchanged. The
`[cpBuild]` inter-cast interval k (Druid.lua `cpBuildLogSample` `t = GetTime()`, computed offline by the
phase-28 tooling) is untouched. `recordFailTable`'s cast-to-fail lag print (160-165) is unchanged and
purely diagnostic. The TTL change, the dedup predicate, and the inference fallback do not feed cast
timestamps or intervals.

**Project constraints:** no `#` length operator on tables, no `goto`, no `::label::` in any of the five
files (grep-verified); English comments/commits respected; SM_EXTEND.lua untouched.

## Warnings

### WR-01 (carried, still valid): Self-hit path announces green even when the cast-dimension dedup drops the land

**File:** `core/spell_trace_core.lua:550-554` (dedup predicate at 325-329)

**Issue:** Unchanged since the first pass. `onSelfDamageLine` prints the green `landed` line
unconditionally and only afterwards calls `recordLandEvent`, whose dedup may silently drop the write.
This is asymmetric with `processRawAuraApply` (470-473), which announces only when an intent paired. For
the deliberately dual-channel spells — Rake and Pounce (self-hit line plus aura-apply line, per
Druid.lua:806-818) — when the apply line pairs first (intent consumed, land pushed) and the self-hit
arrives afterwards, the self-hit prints a second green `landed` line for the same cast while the ledger
write was deduped (`lastLand >= lastCast`): two green landings in chat, one entry in the land table. This
is the exact observable layer the HUMAN-UAT Phase-29 section 3 uses to judge correctness ("Rake /
Ferocious Bite 恒绿『landed』"), so the verifier sees confusing double confirmations.

**Fix:** Make the announcement follow the dedup outcome — have `recordLandEvent` return whether it
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

### WR-02 (carried, still valid): Stale-cast inference has no epoch guard — cross-combat / retarget pollution

**File:** `core/spell_trace_core.lua:378-427` (trigger edge 406-408, coverage 412-414, veto 419-421,
push 423)

**Issue:** Re-verified with stronger evidence. `loginContext` and its cast/fail/land tables persist for
the whole login session (combat_context.lua: `onPlayerEnteringWorld` is the only reset; `onCombatExit`
clears only `macroTorch.context`). `maintainLandTables` is gated on `macroTorch.inCombat` (line 367),
which is exactly why a cast whose 0.9s silence window straddles a combat exit survives: the window
never elapses while out of combat, and `computeLandTable` bounds the silence only from below
(`blip <= ttl`). Concrete failure, with the HUMAN-UAT's own fixture: cast Rip on a "Training Dummy" at
t=10; it dies within 0.4s (killshot rotation) before any evidence/fail; combat ends; the next combat on
a same-named dummy records nothing yet — the 0.1s tick finds `lastCast = 10`, `blip` huge, no land, no
in-window fail, and pushes the ancient anchor with a blue `Rip cast on Training Dummy landed: 10
(inferred)` line. Consequences: misleading chat, a ghost land-stack entry, and transient `lastLand`
pollution. Combat decisions stay correct only because `ripLeft` clamps to 0 and `isRipPresent`
requires the real target debuff.

**Fix:** Add an upper bound on the inference window — after the `blip <= ttl` return, treat a cast
older than a grace period (e.g. `blip > ttl * 6`) as abandoned and skip; or clear the per-mob
cast/fail/land spell tables in `onCombatExit`.

### WR-03 (carried, still valid): Stale "2s" comments contradict D-05/D-17 and misstate the live cpDamage window

**File:** `core/spell_trace_core.lua:214` ("`Reuses macroTorch.LAND_INTENT_TTL (2s, D-02).`") and
`core/spell_trace_core.lua:457-461` ("`(<=2s land offset)`")

**Issue:** `LAND_INTENT_TTL` is now 0.9. DESIGN-CONTEXT locked decision 5 explicitly requires the 2s
legacy wording to be updated with the refactor ("其 2s 旧值说明需随重构更新"); the cleanup clause was
deferred across 29-01/29-02/29-03 and has still not been performed (grep over the scoped files finds
only these two stale sites — all other "2s" references correctly describe the hunter sting ttl or
killshot timing). A maintainer reading line 214 believes the cpDamage pairing window is 2s when it is
0.9 — and the real consequence of the 0.9 window (a [cpDamage] sample whose damage line lags the cast
by more than 0.9s is silently purged unpaired, e.g. on >900ms RTT spikes or client freezes) is
documented nowhere at that site. Behavior itself is locked by D-17; only the comments are wrong, and
they actively mislead.

**Fix:** Rewrite both comments to the current constant semantics, e.g. line 214:
`-- Reuses macroTorch.LAND_INTENT_TTL (0.9s default, D-17); samples whose damage line lags the cast by
more than the window are purged unpaired,` and line 459: `-- pending window can pair with our cast intent
(<= 0.9s default land offset); fail`.

### WR-04 (carried, still valid): HUMAN-UAT troubleshooting branch (b) describes output the implemented machinery cannot produce

**File:** `classes/druid/HUMAN-UAT.md:266`

**Issue:** Unchanged. Branch (b) lists "蓝色推断后紧跟红色『was cancelled by ...』" (blue `(inferred)`
line followed by a red cancel line) as an expected fail-wins observation. With the shipped code this
sequence is impossible: `finalizeFail` revokes a land only when the intent is in state `'landed'`
(spell_trace_core.lua:494-520), and an intent becomes `'landed'` only through pairing — the inference
push (`computeLandTable` push at 423) never marks any intent landed, so nothing ties a blue line to any
revocable intent. Additionally, any fail arriving after the inference fired must have
`failTime > cast + ttl` (the inference only fires after `blip > ttl`), which falls outside both the veto
window (420) and `finalizeFail`'s window (499-501). A red cancel can only follow a green paired land.
The verifier reading this branch expects to observe a red line that can never occur and may chase a
ghost.

**Fix:** Rewrite branch (b) as the green-then-red observation:
`b) 绿色 landed 后紧跟红色『was cancelled by ...』：同 cast 的 fail 在窗口内到达，fail-wins 撤销已配对的落
地（蓝色 (inferred) 行按边界设计永不被撤销——fail 必在窗口外到达）`

### WR-05 (new): Self-hit channel has no target-ownership check — asymmetric with the apply channel's guid check

**File:** `core/spell_trace_core.lua:528-555` (pattern captures the target and discards it; write is
keyed on the current target at recordLandEvent:319)

**Issue:** The unified OR evidence core ships three channels that are nominally equivalent, but their
ownership validation is not: `processRawAuraApply` refuses any line whose guid does not match the
current `macroTorch.target.guid` (453-456), while `onSelfDamageLine` accepts every `'Your <skill> hits
<target>.'` line and — via `pairLandIntent` and `recordLandEvent` — reads and writes both keyed on
`macroTorch.target.name`, the *current* target, not the target named in the line. The pattern at
532/534 even captures the real target with `([^%.]+)` and discards it. Concrete failure: cast Rake on
MobA (cast and intent recorded under MobA), the player retargets to MobB within the same GCD (tab
targeting while the ~100ms melee resolution is in flight); the self-hit line "Your Rake hits MobA" then
pairs / announces against MobB ("Rake cast on MobB landed") and writes a Rake land into MobB's stack —
wrong-target ledger entry plus a green line claiming the wrong mob. The apply channel was given the
guid check precisely to prevent this class of misattribution; the self-hit channel (Ferocious Bite,
Rake, Pounce) was not. Decision-facing consumers remain guarded (`isRakePresent`/`isRipPresent`
double-check the real target debuff), so this is a WARNING, not a blocker.

**Fix:** Compare the parsed target with the current target before announcing/recording, mirroring the
apply channel's ownership rejection:

```lua
-- in onSelfDamageLine, capture the target portion:
local _, _, spell, hitTarget = string.find(eventMsg, 'Your (.-) hits ([^%.]+)%.')
-- ... (same for crits)
if not hitTarget or macroTorch.target.name == nil
    or macroTorch.equalsIgnoreCase(hitTarget, macroTorch.target.name) ~= true then
    return
end
```

(If exact-name collision between same-named mobs matters to the verifier, at minimum refuse when the
parsed target differs from the current target name; see IN-04 for the residual that even name
equality cannot close.)

## Info

### IN-01 (carried, still valid): No fixture pins the exact boundary at `delta == ttl` / `failTime == cast + ttl` / `blip == ttl`

**File:** `classes/druid/selftest.lua:1221-1253` (Q-14), `:1151-1219` (Q-13), `:1054-1105` (Q-11)

**Issue:** All three window edges implement inclusive `<=` semantics whose correctness turns on a single
character (`<` vs `<=`). Q-14 drives a mid-window 1.5s delta against ttl 0.9 (expire) and 2 (pair); the
exact `delta == ttl` pair/expire split is never pinned. Q-13 uses +0.5 and -0.1 fail offsets. Q-11
uses a 2.0s-old cast, not `blip == ttl`. These three edges remain the most regression-prone spots.

**Fix:** Add exact-edge assertions (or one three-phase fixture): pair at `castAt + 0.9` must succeed
for a ttl-0.9 intent; `failTime == castAt + ttl` must veto; a cast at `GetTime() - ttl` must stay
silent.

### IN-02 (carried, still valid): Q-02 fixture only rewires the intent's castAt — the castTable entry keeps the live clock

**File:** `classes/druid/selftest.lua:832-838`

**Issue:** The comment claims the seeded `castAt 1000.0` sits "inside the 0.9 default window" — true
for the intent pairing math — but `recordCastTable('Rip')` pushed the real client `GetTime()` into
`castTable`, so `recordLandEvent`'s dedup runs against a live-clock `lastCast` while the land time is
1000.5. Q-02 passes and pins pairing/landing, but the cast-dimension dedup is only actually pinned by
Q-12/Q-15 (which seed `castTable` correctly). The Q-02 comment overstates its coverage.

**Fix:** Extend the comment with one clause: "castTable entries keep the live clock on purpose;
cast-dimension dedup coverage belongs to Q-12/Q-15."

### IN-03 (carried, still valid): Expired intents are state-flipped but never removed — scans accumulate within the 32 cap

**File:** `core/spell_trace_core.lua:190-195`

**Issue:** The `pairLandIntent` purge marks stale intents `'expired'` but leaves the rows in
`stack.elements` until LRU eviction (cap 32). Inferred-landed casts consume nothing, so their intents
stay `'pending'` indefinitely and every later visit rescans them. Bounded and behaviorally inert (the
pair pass filters on `'pending'`), but `pairCpDamageIntent`'s purge (221-226) already demonstrates the
removal idiom that could be mirrored here.

**Fix:** `table.remove(stack.elements, i)` in the purge pass when expiring (or leave as-is and note
the LRU cap as the bound — cosmetic churn only).

### IN-04 (new): Ledger storage is keyed by mob name while ownership checks resolve at guid granularity

**File:** `core/spell_trace_core.lua:110-112, 184-185, 319-320` (name-keyed table nests);
`core/spell_trace_core.lua:453-456` (guid ownership check)

**Issue:** Every ledger (`castTable`/`intentTable`/`failTable`/`landTable`) is nested by
`macroTorch.target.name`, while the apply channel's ownership validation compares guids. Two distinct
mobs sharing one name — the HUMAN-UAT's own "Training Dummy" fixture — collapse into one stack:
a land/intent for dummy A and one for dummy B merge, cross-contaminating dedup (`lastLand >= lastCast`)
and pairing across the two mobs. The guid check validates the *line* but cannot stop the *write* from
landing in the merged stack. This is a pre-existing architectural property (mob-name keying dates to
phase 24), but the unified-OR core leans on the ledger harder than before (dedup predicate + inference
read/write), which is why it is recorded here. Combat decisions stay safe because
`isRipPresent`/`isRakePresent`/`isPouncePresent` double-check the real target aura.

**Fix:** Out of scope for this phase; note as a known residual. If ever addressed, key the per-target
stacks by guid (falling back to name when the guid is unavailable), or clear per-mob stacks on
target-change in combat.

---

_Reviewed: 2026-09-10T06:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

Note: the review-config file list contained `core/spell_trace_core.l.lua` (double-l typo); the actual
file `core/spell_trace_core.lua` was reviewed and is listed in `files_reviewed_list`.