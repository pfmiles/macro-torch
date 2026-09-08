---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
fixed_at: 2026-09-09T01:05:48+08:00
review_path: .planning/phases/28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac/28-REVIEW.md
iteration: 1
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report (re-run review)

**Fixed at:** 2026-09-09T01:05:48+08:00
**Source review:** `.planning/phases/28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac/28-REVIEW.md` (re-run after fixes 58735b4, c94af69; this report supersedes the previous 28-REVIEW-FIX.md iteration)
**Iteration:** 1 (fix_scope = critical_warning)

**Summary:**
- Findings in scope: 1 (WR-01; no critical findings)
- Fixed: 1
- Skipped: 0
- Info findings (IN-01..IN-04): out of fix scope (fix_scope excludes Info), listed below with verified status

## Verification Verdicts (per-finding)

### WR-01: `claw()`/`shred()` eagerly evaluate the energy-cost functions on every cast even when `cpDamageLog` is false

**Verdict: CONFIRMED**

Concrete code evidence (all line numbers from the working tree at commit `b91f09f`, which matches the reviewed state):

1. **Eager argument evaluation is real.** `classes/druid/Druid.lua:27` reads
   `local cpDmg = macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E())`
   and `:40` is the shred analog. Lua evaluates call arguments before entering
   the callee, and the switch gate is the first statement INSIDE
   `cpDamageSample` (`Druid.lua:380-382`: `if not macroTorch.cpDamageLog then return nil end`),
   so the gate cannot suppress the argument expression. The reviewer's core
   mechanism claim is correct.
2. **The cost chain is real and uncached.** `computeClaw_E()` (`Druid.lua:582-590`)
   calls `player.isItemEquipped('Idol of Ferocity')`
   (`entity/Player.lua:311-312` -> `macroTorch.getEquippedItemSlot`,
   `biz_util.lua:344-352`, a `for slot = 1, 18` loop issuing
   `GetInventoryItemLink("player", slot)` per slot) plus
   `player.talentRank('Ferocity')` (`entity/Player.lua:341-342` ->
   `macroTorch.getTalentRank`, `biz_util.lua:305-318`, a full
   `GetNumTalentTabs()` x `GetNumTalents(tabIndex)` scan of `GetTalentInfo`,
   roughly 50-60 WoW API calls). `computeShred_E()` (`Druid.lua:723-726`) adds
   one more full talent scan (`getTalentRank('Improved Shred')`). No caching
   anywhere in this chain (in contrast to `hasWolfsheartEnchant`, which caches
   but is not on this path). Per-cast cost while disabled is ~70-90 WoW API
   calls — the reviewer's "roughly 70-120" estimate is the right magnitude.
3. **The cost is NEW in phase 28.** Commit `a602cc0` (feat(28-01)) shows
   `+ local cpDmg = macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E())`
   added to `obj.claw`; before that, `claw()` passed only the function
   REFERENCE into `_castSpell`.
4. **The production path never needed the eager value.** `_castSpell`
   (`entity/Player.lua:38-85`) dereferences `resourceCost` only inside
   `if mode ~= 'ready' and mode ~= 'raw'` (lines 56-71). The catAtk path calls
   `player.claw('ready')` (`classes/druid/combo.lua:398`), so the function
   reference is never invoked there; the energy is precomputed once per click
   at `combo.lua:59-60` (`clickContext.CLAW_E = macroTorch.computeClaw_E()`,
   same for SHRED_E). The eager call is therefore a duplicate scan of a
   deterministic, already-computed value that also runs in the OFF state.
5. **The OFF state is the production default.** `macro_torch.lua:61-63`
   nil-guards `macroTorch.cpDamageLog = false`. So this cost runs with the
   switch OFF once per GCD-cast — violating the disabled-state inertness
   contract stated in the review's Special Focus section. The review's own
   hook-point evidence (caller-side caveat, REVIEW.md line 45) flags exactly
   this.

**Regression-safety assessment of the fix (checked before applying):**
- Only three production callers of `cpDamageSample` exist
  (`Druid.lua:27` claw, `:40` shred, `:68` bite-with-literal-35). No other
  consumer relies on the call being unconditional.
- `cpDamageSample` mutates nothing when the flag is off (the function returns
  at `:381` before the `_cpDamageProbeWarned` write, allocations, or
  `GetTime()`); skipping the call entirely when off is state-identical.
- With the flag ON, the guarded form evaluates the call identically
  (`true and <call> or nil` -> `<call>`), and the sample-before-cast ordering
  (GCD probe must run before `_castSpell`) is preserved: the guarded line
  stays at the same position before `_castSpell`.
- The guard mirrors the established in-file idiom at
  `Druid.lua:26/39/52` (`macroTorch.cpBuildLog and ... or nil`), which is
  Lua 5.0-safe (plain `and`/`or` chain; no `#` length op, no goto).

### IN-01 (carried, out of scope): `avgDmg` and `avgRaw` are the same formula

**Verdict: CONFIRMED** — `tools/cpdamage.lua:761-769`: `avgDmg = b.sumDmg / b.n`
and `avgRaw = b.sumDmg / b.n`; the two columns can never differ. Info tier —
not fixed (out of fix scope).

### IN-02 (carried, out of scope): `load_chunk` assigned but branches test `loadstring` directly

**Verdict: CONFIRMED** — `tools/cpdamage.lua:204-224`: `local load_chunk = loadstring or load`
backs only the existence guard; both branches test `loadstring ~= nil`. Works
correctly today; a maintainability drift risk. Info tier — not fixed (out of fix scope).

### IN-03 (out of scope): HUMAN-UAT troubleshooting omits the Training-Dummy-name localization as a zero-sample cause

**Verdict: CONFIRMED** — `classes/druid/HUMAN-UAT.md` section 6 lists exactly
three steps for zero `[cpDamage]` rows (① .toc ② switch ③ GCD probe) and no
dummy-name step; the gate at `classes/druid/Druid.lua:383` hard-codes the
English substring `'Training Dummy'`, which a localized client would never
match. Info tier — not fixed (out of fix scope); note the reviewer states the
gate itself is locked D-05 wording and should not change without a
plan/context decision, which this fixer respects.

### IN-04 (out of scope): workflow file list typo `tools/cpdamamage.lua`

**Verdict: CONFIRMED (occurrence corroborated, no in-tree fix target)** — the
review's `files:` config listed `tools/cpdamamage.lua`, which does not exist in
the repo. A repo-wide grep finds the misspelling only inside the historical
generation-corruption log (`28-03-SUMMARY.md:154`, which records that
corruptions including `cpdamamage` were repaired before commit) and in
REVIEW.md itself; the review invocation config carrying the typo lives outside
the working tree, so there is no in-tree artifact to correct. Info tier — not
fixed (out of fix scope).

## Fixed Issues

### WR-01: `claw()`/`shred()` eagerly evaluate the energy-cost functions on every cast even when `cpDamageLog` is false

**Files modified:** `classes/druid/Druid.lua`
**Commit:** `8610100`
**Applied fix:** Mirrored the `cpBuildLog` short-circuit idiom so the entire
expression — including the argument evaluation — is skipped when the switch is
off:

- `Druid.lua:27` (claw):
  `local cpDmg = macroTorch.cpDamageLog and macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E()) or nil`
- `Druid.lua:40` (shred): same pattern with `computeShred_E()`.

`ferocious_bite` (`:68`) was left unchanged — it passes the literal `35` and
eagerly evaluates nothing (matches the reviewer's guidance). The 2-line diff
is the complete change (`git show 8610100`).

## Skipped Issues

None — the only in-scope finding (WR-01) was fixed.

## Verification Notes

- **Where verification ran:** all verification (Tier 1: re-read + grep of the
  affected functions; commit diff inspection) ran in the isolated fix worktree
  `.claude/worktrees/rf-28-...` on branch `gsd-reviewfix/28-156014`, later
  fast-forwarded onto the user's branch. (See cleanup-tail note.)
- **Tier 2 syntax check:** not runnable — no Lua interpreter/compiler (`lua`,
  `luac`, `luajit`) is installed on this machine. Per the 3-tier policy this
  fell back to Tier 1 structural verification: the guarded expression uses only
  `and`/`or` binary operators and is line-for-line the same idiom already
  proven in-file at `Druid.lua:26/39/52` (pre-existing, load-bearing code); no
  Lua 5.0-forbidden constructs were introduced. Selftest suite was not run
  (verifier phase handles it).
- **Commit discipline:** one atomic commit for the one in-scope finding
  (`8610100`), listing the single modified file. This REVIEW-FIX.md is NOT
  committed by the fixer (orchestrator handles it).

---

_Fixed: 2026-09-09T01:05:48+08:00_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1 (re-run review; supersedes the prior fix report for the previous review iteration)_