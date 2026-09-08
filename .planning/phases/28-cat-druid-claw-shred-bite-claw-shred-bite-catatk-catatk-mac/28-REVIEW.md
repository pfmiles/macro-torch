---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
reviewed: 2026-09-08T14:20:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/HUMAN-UAT.md
  - classes/druid/selftest.lua
  - core/combat_context.lua
  - core/events.lua
  - core/spell_trace_core.lua
  - impl_util.lua
  - macro_torch.lua
  - tools/cpdamage.lua
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-09-08
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found (2 warnings, 2 info; no critical)

## Summary

Phase 28 delivers the claw/shred/bite damage-instrumentation chain: in-game sampling + intent pairing + fixed 11-field `[cpDamage]` JSON emission, and a standalone offline analyzer (`tools/cpdamage.lua`) with sandboxed SavedVariables extraction, strict JSON decode, bucket/regression stats, decision lines, and a self-contained 33-assertion selftest. The wiring holds up well under adversarial review; the notable verified positives are listed first, then four findings.

**Verified positives (evidence-driven, not just inspected):**

1. **Cross-version claim empirically confirmed.** I downloaded and compiled Lua 5.0.3, 5.1.5 and 5.4.7 in the sandbox and ran the actual tool. `--selftest` passes on all three (`selftest: ALL 33 PASSED`, exit 0), and the real analysis mode (`lua tools/cpdamamage.lua <sv-file> --json-out ...`) produces identical bucket/regression output on all three versions. The `arg`-table layout difference across interpreter generations (a known trap) turns out to be a non-issue here: empirically `arg[0]` = script name and `arg[1]` = first CLI argument on 5.0, 5.1 and 5.4 alike, so `main(arg)` reads the right values everywhere.
2. **Threat-model caps implemented as planned** (`tools/cpdamage.lua`): 32MB file cap (`MAX_FILE_BYTES`, readAll:51-65), 50k entry cap (`MAX_ENTRIES`, parseEntries:688-695), pcall-wrapped compile/execute/decode, and the exact-`[cpDamage] `-prefix + decode-success dual gate — all present.
3. **GCD-probe nil discipline holds.** `interface_debug.lua:27-36` `isActionCooledDown` returns nil (not false) when the Rake texture is absent from all 172 slots; `cpBuildLogSample`/`cpDamageSample` warn once per login and refuse to fabricate GCD-ready rows (`Druid.lua:349-364, 379-418`), with per-login re-arm in `macro_torch.lua:67-71`. Selftest S-04 pins this.
4. **`LOG_MAX_SIZE` clamp is real** (`interface_debug.lua:118-121`): `math.max(1, math.floor(n))` with 500 fallback — the trim loop can never hang on a 0/negative override, matching the `macro_torch.lua:51-55` comment.
5. **No-SuperWoW degradation is coherent**: `entity/Unit.lua:103-110` makes `guid` nil without SuperWoW, `cpDamageCast` (Druid.lua:426-431) then plants nothing, and the RAW stream (the only cpDamage feed) does not exist either.
6. **The Training Dummy gate is verbatim** `combo.lua:104-106`'s `isTargetDummy` expression (D-05), and `LRUStack.push` (periodic.lua:31-36) evicts the oldest element when full, so the 8-slot `cpDamageIntents` stack stays bounded.
7. Category U selftests (9 tests) follow the CR-01 stub discipline (snapshot → shadow → capture → restore-before-assert), including the subtle `rawget/rawset` pairing for metatable-backed methods.

Remaining findings below; none of them blocks the data-collection loop, but WR-02 corrupts the very dataset the tuning decisions are built on and WR-01 silently degrades live combat behavior for every druid.

## Warnings

### WR-01: Selftests permanently shadow `isBehindAttackJustFailed` on the live player, disabling the behind-fail suppression for the whole session

**File:** `classes/druid/selftest.lua:387` (also 409, 432)
**Issue:** R6-01, R6-02 and R6-03 each run `macroTorch.player.isBehindAttackJustFailed = false` unconditionally. That key is not a plain field — it is a FIELD_FUNC_MAP accessor (`entity/Player.lua:598-601`, computed from `macroTorch.context.behindAttackFailedTime` with a 0.5s window). The metatable produced by `macroTorch.classMetatable` (`core/class.lua:21-33`) defines only `__index` (no `__newindex`), and Lua only consults `__index` when the raw key is absent — so the assignment writes a raw instance field on the session singleton that **shadows the accessor permanently**. Nothing restores it: the deferred post-login `SelfTest:run()` (events.lua:63-76) runs once after `onPlayerEnteringWorld()`, which is the last point at which the player object would be rebuilt, so every druid session auto-runs these tests about 30 frames after login and pins the value to `false` for the remainder of play (or until a reload). Consequences: `shouldUseShred` (Druid.lua:883, 889, 900, 903) and `leveling.lua:194, 207` never see `isBehindAttackJustFailed`, so immediately after a "You must be behind your target" failure the macro retries front-position Shred instead of suppressing for the 0.5s window — UI error spam plus slightly-worse builder decisions in real combat.

This is pre-existing behavior of the R6 batch (Phase 22 era), but the file is in this phase's change set and the pollution affects live gameplay state, not just test reliability.

**Fix:** Apply the same snapshot/restore discipline the Q/U batches use, or avoid touching the accessor entirely:

```lua
macroTorch.SelfTest:register("Principle R6-01: 0 bleeds OoC behind — use Shred", function()
    local saved = rawget(macroTorch.player, 'isBehindAttackJustFailed')
    macroTorch.player.isBehindAttackJustFailed = false
    local ok, res = pcall(function()
        -- ... existing ctx setup and assert logic (assert moved inside pcall) ...
    end)
    rawset(macroTorch.player, 'isBehindAttackJustFailed', saved) -- nil removes the shadow
    assert(ok and res, "R6-01 failed")
end, true)
```

Better still: since the accessor only reads `macroTorch.context.behindAttackFailedTime`, have the three tests write `macroTorch.context.behindAttackFailedTime = nil` inside a saved/restored `macroTorch.context` instead of assigning the player field at all.

### WR-02: `onCpDamageLine` discards the parsed spell name — a stale intent can be consumed by a different skill's damage line, mislabeling [cpDamage] entries

**File:** `core/spell_trace_core.lua:263-280` (pairing at 228-251)
**Issue:** Both patterns capture only `guid` and `dmgStr`; the spell name sitting on the line is parsed and thrown away. `pairCpDamageIntent` matches on GUID + 2s window only, justified by the "exactly one intent per cast frame" comment (225-227) — but that invariant covers only sampled skills. Any `Your <spell> hits/crits <guid>` line on the RAW self-damage channel can consume a still-pending intent from a different skill. The concrete, rotation-reachable leak is **Rake**: `obj.rake` (Druid.lua:51-58) does not call `cpDamageSample` (per the D-06 range lock), yet Rake always produces "Your Rake hits/crits" lines, which arrive on `CHAT_MSG_SPELL_SELF_DAMAGE` — the exact channel gated at `events.lua:189-191`. Sequence: Claw or Bite is dodged (intent stays pending, by design U-07), catAtk then refreshes Rake within the 2s window, the Rake hits line pairs with the stale Claw/Bite intent (newest-intent rule), and the entry is emitted as `{"spell":"claw"|"bite","dmg":<rake damage>}`. The analyzer (`validateEntry`) accepts it — it only rejects unknown spell tokens, not mismatches, and the GUID genuinely matches the dummy. Result: mislabeled rows silently pollute the claw/shred efficiency tiers and the 5cp bite regression, i.e., the exact numbers the D-21 decision lines turn into tuning advice.

**Fix:** Capture the spell name and gate the pair on it (whitelist + token match):

```lua
local _, _, spellName, guid, dmgStr =
    string.find(eventMsg, '^Your (.-) hits (0x[0-9A-Fa-f]+) for (%d+)%.')
local crit = false
if not guid then
    _, _, spellName, guid, dmgStr =
        string.find(eventMsg, '^Your (.-) crits (0x[0-9A-Fa-f]+) for (%d+)%.')
    crit = true
end
if not guid then return end
local want
if spellName == 'Claw' then want = 'claw'
elseif spellName == 'Shred' then want = 'shred'
elseif spellName == 'Ferocious Bite' then want = 'bite' end
if not want then return end  -- drop Rake / any unsampled skill's line
local sample = macroTorch.pairCpDamageIntent(guid, now)
if not sample or sample.spell ~= want then
    return  -- mismatch: leave the intent pending for its own line
end
```

The `sample.spell ~= want` arm also protects the future case where unsampled casts get instrumented. A mismatch must NOT consume the intent — dropping only the line keeps U-07's semantics intuitive.

## Info

### IN-01: `avgDmg` and `avgRaw` are the same formula, so the report prints two always-identical columns

**File:** `tools/cpdamage.lua:760-770` (rendered at 1017-1032)
**Issue:** `finalize(b)` returns `avgDmg = b.sumDmg / b.n` and `avgRaw = b.sumDmg / b.n` — numerically identical for every bucket, so `printClawShredTable` shows two columns ("avg dmg" and "single-cast avg") that can never differ. This mirrors the locked 28-RESEARCH D-18 wording (both defined as `sumDmg / n`), so it is spec-level redundancy rather than an implementation slip, but readers of the report will look for a difference that does not exist and the decision layer (D-21) uses only `avgEff` and the OOC `avgDmg`, never `avgRaw`.

**Fix:** Either drop one column from the table, or give `avgRaw` a distinct semantics (e.g., the per-tier mean rescaled to a fixed 45-energy claw baseline) — decide in a plan/context tweak and re-lock the U-03-style contract if the JSON archive carries it.

### IN-02: `load_chunk` is assigned but the sandbox branches test `loadstring` directly

**File:** `tools/cpdamage.lua:205`
**Issue:** `local load_chunk = loadstring or load` only backs the existence guard at 208-210; the actual branch conditions at 213 and 224 test `loadstring ~= nil`, so the variable carries no load-bearing logic and invites a future drift where the guard and the branches disagree.

**Fix:** Either branch on `load_chunk` inside `loadBlockSandboxed` (with `load_chunk == load` as the 5.2+ discriminator), or delete the variable and guard with `if not loadstring and not load then`.

---

_Reviewed: 2026-09-08T14:20:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_