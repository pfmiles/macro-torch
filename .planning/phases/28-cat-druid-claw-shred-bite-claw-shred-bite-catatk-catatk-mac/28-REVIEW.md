---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
reviewed: 2026-09-08T16:30:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/HUMAN-UAT.md
  - classes/druid/selftest.lua
  - core/combat_context.lua
  - core/events.lua
  - core/spell_trace_core.lua
  - .gitignore
  - impl_util.lua
  - macro_torch.lua
  - tools/cpdamage.lua
findings:
  critical: 0
  warning: 1
  info: 4
  total: 5
status: issues_found
---

# Phase 28: Code Review Report (Re-run after fixes)

**Reviewed:** 2026-09-08
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found (1 warning, 4 info; no critical)

## Summary

This is the re-run of the phase-28 review after the fix iteration (commits 58735b4, c94af69). Both prior in-scope findings were verified as fixed in the working tree and are not re-opened:

- **Prior WR-01 (accessor shadowing in R6 selftests) — verified fixed.** `classes/druid/selftest.lua:393-401` (R6-01), `421-429` (R6-02), `451-459` (R6-03) now use the CR-01 discipline: `rawget` snapshot, own-key shadow, `pcall` around `shouldUseShred`, `rawset` restore BEFORE any assert. `rawset(player, 'isBehindAttackJustFailed', nil)` correctly removes the shadow and re-exposes the `PLAYER_FIELD_FUNC_MAP` `__index` accessor.
- **Prior WR-02 (stale-intent spell mislabeling) — verified fixed.** `core/spell_trace_core.lua:269-297`: `onCpDamageLine` captures the spell name and whitelists Claw/Shred/Ferocious Bite BEFORE pairing; `pairCpDamageIntent(guid, now, want)` puts the spell gate inside the match condition (line 251), so a guid match with a spell mismatch consumes nothing and leaves the intent pending. The Cat U-07 selftest extends the dodge scenario with a Rake line (`selftest.lua:1267-1274`) and pins the invariant (`remainingAfterRake == 1`, zero emissions). Registration count `SelfTest:register("Cat U-0` == 9 preserved.

The one new warning (WR-01 below) is a disabled-state inertness violation found by applying the special-focus mandate to the cast wrappers; the info items carry the two still-unfixed prior info findings plus two documentation items.

## Special Focus: Disabled-State Inertness Verification (cpDamageLog = false)

The production default is `macroTorch.cpDamageLog = false` (nil-guard at `macro_torch.lua:61-63`). This section states the evidence per hook point.

1. **`cpDamageSample` (Druid.lua:379-418)** — PASS with a caller-side caveat. The flag check is the first statement (`Druid.lua:380-382`), ahead of the Training Dummy gate, the batch lookup, the GCD probe (whose only mutation is the one-time `_cpDamageProbeWarned`), the bleed-count snapshot, and the table allocation at 405-417. When off, exactly one boolean test runs; no allocation, no GetTime, no counter mutation. **Caveat:** Lua evaluates call arguments before entering the function, so the caller-side argument expressions in `claw()`/`shred()` still execute when off — that is WR-01, the one finding below.
2. **`cpBuildLogSample`** — PASS. Call sites use `macroTorch.cpBuildLog and macroTorch.cpBuildLogSample() or nil` (Druid.lua:26, 39, 52), short-circuiting the call entirely when off.
3. **`cpDamageCast` (Druid.lua:425-436)** — PASS. Reachable only through `cast and cpDmg and cpDmg.gcdOk`; `cpDmg` is nil when the flag is off, so the function is never entered in the disabled state. Its internal guards (loginContext, guid, lazy stack allocation) run only in the enabled state.
4. **Emission path (`cpDamageEvent`, spell_trace_core.lua:301-314)** — PASS. `cpDamageEvent` has no flag gate of its own, but a grep of all production call sites shows the only caller is `onCpDamageLine` (gated at line 270); the U-03 selftest call runs against a stubbed `macroTorch.log`. The `macroTorch.log` trim loop is bounded by the sanitized `LOG_MAX_SIZE` (`interface_debug.lua:118-119`); its cost profile is unchanged by phase 28.
5. **RAW capture hook (events.lua:189-191)** — PASS. The flag is the FIRST operand of the `and` chain, ahead of the channel comparison, so when off there is no `GetTime()`, no string work, and zero allocation per RAW_COMBATLOG event. The event itself is only registered under SuperWoW (`events.lua:48-51`).
6. **`onCpDamageLine` (spell_trace_core.lua:269-270)** — PASS. Internal flag gate first; none of the two `string.find` patterns runs when off. This is the double gate with hook 5.
7. **`pairCpDamageIntent`** — PASS. Unreachable from production code when the flag is off (only callers: gated `onCpDamageLine` and selftests).

**Per-frame/per-event state mutation while off:** none. The single unconditional phase-28 write is `macroTorch.context._cpDamageBatch = GetTime()` in `onCombatEnter` (`core/combat_context.lua:39`): one `GetTime()` plus one table store per combat ENTER (once per fight), not per frame or per event. Identified, quantified (negligible), and justified — the stamp is required for a mid-combat toggle-on to produce entries, and `onCombatExit`'s `context = {}` rebuild already clears it.

**Verdict:** the disabled state is inert at every hook point except the caller-side argument evaluation documented as WR-01.

## Warnings

### WR-01: claw()/shred() eagerly evaluate the energy-cost functions on every cast even when cpDamageLog is false — the disabled state is not free

**File:** `classes/druid/Druid.lua:27` and `40`
**Issue:** `local cpDmg = macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E())` evaluates `macroTorch.computeClaw_E()` as a function argument BEFORE `cpDamageSample` is called, so the flag gate inside `cpDamageSample` (line 380) can never suppress it. The same pattern repeats for shred (`computeShred_E()` at line 40). At the review baseline (`9287c3f^`), `claw()` passed `macroTorch.computeClaw_E` as a function reference, and `_castSpell` dereferences `resourceCost` only in the `mode ~= 'ready' and mode ~= 'raw'` branch (`entity/Player.lua` `_castSpell`), so the catAtk path `player.claw('ready')` (`combo.lua:398`) never evaluated it at all. The phase-28 instrumentation therefore added new per-cast work that runs with the switch OFF.

Quantified cost per call while disabled:
- `computeClaw_E()` = `isItemEquipped('Idol of Ferocity')` → `getEquippedItemSlot` (`biz_util.lua:344-352`, a 1..18 loop issuing `GetInventoryItemLink` per slot) + `talentRank('Ferocity')` → `getTalentRank` (`biz_util.lua:305-318`, a full GetNumTalentTabs × GetNumTalents scan of `GetTalentInfo` ≈ 50 WoW API calls).
- `computeShred_E()` = one more full `getTalentRank('Improved Shred')` scan.
So roughly 70-120 WoW API calls per accepted cast, once per GCD, that did not exist before phase 28 when the switch is off. In catAtk, `clickContext.CLAW_E`/`SHRED_E` are already computed per click (`combo.lua:59-60`), so this is a duplicate scan of the same deterministic value; for manual `/run macroTorch.player.claw('ready')` calls (the HUMAN-UAT protocol) it is entirely new cost. Logical output is unchanged (both functions are pure), so this violates the ZERO-performance-impact mandate but not ZERO-logical.

**Fix:** mirror the cpBuildLog short-circuit idiom already used two lines above, so the whole expression (including argument evaluation) is suppressed when off:

```lua
local cpDmg = macroTorch.cpDamageLog and
    macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E()) or nil
-- shred:
local cpDmg = macroTorch.cpDamageLog and
    macroTorch.cpDamageSample('shred', macroTorch.computeShred_E()) or nil
```

`ferocious_bite` (line 68) already passes the literal 35 and needs no change.

## Info

### IN-01 (carried, unfixed): avgDmg and avgRaw are the same formula — two always-identical report columns

**File:** `tools/cpdamage.lua:760-770` (rendered at 1017-1032)
**Issue:** `finalize(b)` sets `avgDmg = b.sumDmg / b.n` and `avgRaw = b.sumDmg / b.n`, so `printClawShredTable` prints two columns ("avg dmg" and "single-cast avg") that can never differ. This mirrors the locked D-18 wording (spec-level redundancy), and the decision layer reads only `avgEff` plus the OOC `avgDmg`.
**Fix:** Drop one column, or give `avgRaw` distinct semantics via a plan/context tweak.

### IN-02 (carried, unfixed): `load_chunk` is assigned but the sandbox branches test `loadstring` directly

**File:** `tools/cpdamage.lua:205` (guard at 208-210, branches at 213 and 224)
**Issue:** `local load_chunk = loadstring or load` only backs the existence guard; the branch conditions test `loadstring ~= nil`, so the variable carries no load-bearing logic and invites drift between the guard and the branches.
**Fix:** Branch on `load_chunk` inside `loadBlockSandboxed` (with `load_chunk == load` as the 5.2+ discriminator), or delete the variable and guard with `if not loadstring and not load then`.

### IN-03: HUMAN-UAT troubleshooting omits the Training-Dummy-name localization as a zero-sample cause

**File:** `classes/druid/HUMAN-UAT.md:218-222` (gate at `classes/druid/Druid.lua:383`)
**Issue:** The D-05 dummy gate hard-codes the English substring `'Training Dummy'`. On a localized client (e.g. zhCN 训练假人) the gate never matches, so the phase-28 chain silently collects zero entries — a cause distinct from the documented A3 hits/crits-sentence localization (which section 6 already lists). The gate itself is the locked verbatim D-05 expression and should not be changed without a plan/context decision; the gap is the missing troubleshooting step.
**Fix:** Add a fourth step to the section-6 troubleshooting chain (① .toc ② switch ③ GCD probe → ④ verify the dummy name matches `'Training Dummy'` in the client locale), noting that non-English clients need the gate localized in a follow-up decision.

### IN-04: workflow file list carries a typo for the offline analyzer path

**File:** review scope (workflow config), real file `tools/cpdamage.lua`
**Issue:** The `files:` config for this review listed `tools/cpdamamage.lua` (double "ama"), which does not exist in the repository (only `tools/cpdamage.lua`). Downstream consumers keying on the config list would look for a nonexistent file.
**Fix:** Correct the config to `tools/cpdamage.lua`; `files_reviewed_list` above already records the real path reviewed.

---

_Reviewed: 2026-09-08T16:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_