# Phase 16: catLeveling 练级版一键宏 - Research

**Researched:** 2026-06-22
**Domain:** WoW 1.12.1 Lua addon -- Druid Cat Form leveling combat rotation (one-button macro)
**Confidence:** HIGH

## Summary

Phase 16 implements a standalone `catLeveling()` leveling rotation function in `classes/druid/leveling.lua`, designed for low-level druid cat-form combat. It does NOT modify the existing `catAtk()` function (which stays as the level-60 server-first-DPS rotation). The function provides three core capabilities: opener choice (Pounce vs Ravage based on combat duration prediction), mid-fight cycle (Tiger's Fury buff, Rip/Rake bleed maintenance, Faerie Fire weaving, combo point builders), and kill-shot judgment (reusing `isKillShotOrLastChance` from catAtk).

The existing code skeleton in `leveling.lua` provides form/gating checks, prowling opener logic, OOC handling, and a `<24` level branch. All shared decision functions are already level-adaptive and `isSpellExist`-guarded (from Phase 13), meaning catLeveling can reuse them directly without reimplementing level-specific branching. The `druidAtk` routing in `combo.lua:162-165` already dispatches `level < 60` to `catLeveling()`.

**Primary recommendation:** Refactor the existing `leveling.lua` skeleton into a priority-ordered module chain (TF -> Rip -> Rake -> FF -> Shred/Claw -> Bite -> Reshift) that reuses all shared decision functions from `Druid.lua` and implements its own simplified `clickContext` (~12 fields, no relic/ERPS fields). Each module starts with `isSpellExist` guard -- no explicit `if level < N` branching needed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Opener selection (Pounce/Ravage) | API/Backend | -- | Pure logic evaluating combat context against shared predicates |
| Tiger's Fury buff maintenance | API/Backend | -- | Buff application on self, time-tracked via loginContext.tigerTimer |
| Rip/Rake bleed maintenance | API/Backend | -- | Debuff monitoring via spell trace land events + texture checks |
| Faerie Fire weaving | API/Backend | -- | GCD-cost-free filler during energy recovery windows |
| Combo point building (Shred/Claw) | API/Backend | -- | Energy-based decision via shouldUseShred |
| Kill-shot judgment (Bite) | API/Backend | -- | Reuses isKillShotOrLastChance + shouldUseBite unchanged |
| Reshift | API/Backend | -- | Low-level auto-no-op via computeReshiftEnergy returning 0 |
| Spell existence gating | API/Backend | -- | Existing isSpellExist infrastructure from biz_util.lua |

All capabilities execute in API/Backend tier -- WoW addon code runs as a Lua script within the WoW client process, responding to macro key presses. There is no browser, frontend server, CDN, or external database tier.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** catLeveling is completely independent from catAtk. Builds its own simplified clickContext (~12 fields, no ERPS/relic fields). Inlines simplified debuff/buff maintenance and attack cycle. Only reuses pure decision functions: `shouldUseShred`, `shouldCastRip`, `shouldUseBite`, `isKillShotOrLastChance`, `isTrivialBattleOrPvp`, `getOpenerHealthThreshold`, `computeClaw_E`/`computeShred_E`/`computeRake_E`/`computeTiger_E` energy cost functions. Does NOT call catAtk's keep-type modules (keepRip/keepRake/keepTigerFury/keepFF/regularAttack).
- **D-02:** Strict priority order aligned with catAtk: Tiger's Fury -> Rip -> Rake -> Faerie Fire (feral) weaving -> Shred/Claw builder. Buff/debuff maintenance takes priority over damage output. TF must be applied before Rip/Rake.
- **D-03:** Reshift module is kept but auto-skips at low levels (`computeReshiftEnergy` returns 0 -> `shouldDoReshift` first-line guard returns false).
- **D-04:** OOC (Omen of Clarity) requires no independent module -- handled inline in regularAttack via `clickContext.ooc` checking `'ready'` mode for free casts. OOC with combo points can directly `ferocious_bite('ready')`.
- **D-05:** Kill shot takes priority over everything. `isKillShotOrLastChance` -> true means any CP directly `ferocious_bite('raw')` (skip energy check). Non-kill-shot -> call `shouldUseBite` (quick battle CP>=3 / normal 5cp+Rip active).
- **D-06:** CP cap is always 5, regardless of level. No "low level CP cap < 5" situation exists.
- **D-07:** Kill shot is the ultimate goal, higher priority than Rip activation. When kill-shot is available, kill-shot directly, no waiting for Rip.
- **D-08:** catLeveling completely removes all idol/relic logic. No calls to `computeNormalRelic`, `recoverNormalRelic`, `dischargeEnergyChangeRelicAndRip`, or any idol-related functions. All WoW Classic feral druid idols are 55-60 endgame drops -- none exist during leveling.

### Claude's Discretion

- Simplified clickContext field list (approximately 12 fields)
- Inline implementations for keepTigerFury/Rip/Rake/FF/regularAttack modules
- Whether to keep the FF "waiting window" pattern (zero-cost, returns immediately when conditions not met)
- Selftest specific case count and coverage scope
- How to refactor the existing `<24` branch in leveling.lua (preserve vs. convert to generic module structure)
- Whether catLeveling accepts `rough` parameter (to match catAtk signature)

### Deferred Ideas (OUT OF SCOPE)

- **healthManaSaver leveling version:** Potion/healing logic deferred to future phases
- **rushMod/burstMod leveling version:** Low level may lack burst skills; level 60 already routed to catAtk
- **Cower/OT management:** Solo leveling does not need threat management
- **Other class leveling versions:** Warrior/Rogue etc. low-level macros belong to their own future phases
- **catLeveling rough mode:** Future rough parameter support can add `rough` to signature and pass through

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-16-01 | catLeveling opener: Ravage vs Pounce based on combat duration prediction | Reuses `isTrivialBattleOrPvp(clickContext)` + `getOpenerHealthThreshold()`. Both are level-adaptive (Phase 14). Existing skeleton already implements: non-trivial + Pounce available + non-immune -> Pounce; otherwise -> Ravage. |
| REQ-16-02 | catLeveling mid-cycle: Tiger's Fury, Rip, Rake, Faerie Fire (feral), Shred/Claw | All shared decision functions (`shouldUseShred`, `shouldCastRip`, `isTigerPresent`, etc.) are level-adaptive and `isSpellExist`-guarded. catLeveling inlines its own simplified keep functions (no relic logic, no energy discharge, no AP burst). |
| REQ-16-03 | catLeveling kill-shot: reuse `isKillShotOrLastChance` + `shouldUseBite` | Both functions are level-adaptive (Phase 14). Kill-shot triggers `ferocious_bite('raw')` regardless of CP count (D-05/D-07). |
| REQ-16-04 | All skill casts gated by `isSpellExist` | Infrastructure exists in `biz_util.lua:75`. Pattern established in Phase 13. Every module starts with `if not macroTorch.isSpellExist(...) then return end`. |
| REQ-16-05 | Shared decision function reuse (no code duplication) | All 9 shared decision functions in Druid.lua are confirmed level-adaptive + isSpellExist-guarded. No new implementations needed. |
| REQ-16-06 | catLeveling selftest | Follow existing pattern in `core/selftest.lua`. Register tests for: catLeveling function existence, key shared function guards, leveling-specific clickContext structure. |
| REQ-16-07 | No modification to catAtk | catAtk in `combo.lua:29-158` is read-only. catLeveling is a completely separate function in `leveling.lua`. |

## Standard Stack

This phase uses no external packages, npm libraries, or third-party tools. It is pure WoW 1.12.1 Lua scripting within the macro-torch addon codebase.

### Core Infrastructure (Existing)

| Component | Location | Purpose | Research Confidence |
|-----------|----------|---------|---------------------|
| `macroTorch.isSpellExist(spellName, bookType)` | `biz_util.lua:75` | Spell existence check via spellbook scan | [VERIFIED: codebase] -- confirmed in source, used by Phase 13 |
| `macroTorch.player.*` skill methods | `classes/druid/Druid.lua:25-59` | `claw()`, `shred()`, `rip()`, `rake()`, `ferocious_bite()`, `pounce()`, `ravage()`, `faerie_fire_feral()`, `tigers_fury()` | [VERIFIED: codebase] -- all locale-aware, accept mode/rank |
| `macroTorch.SelfTest:register(name, fn, isOptional)` | `core/selftest.lua:34` | Self-test registration framework | [VERIFIED: codebase] -- used by Phase 13/14/15 |
| `macroTorch.computeClaw_E/Shred_E/Rake_E/Tiger_E()` | `Druid.lua:427-551` | Dynamic energy cost calculation | [VERIFIED: codebase] -- talent-aware, relic-aware (Ferocity Idol) |
| `macroTorch.computeReshiftEnergy()` | `Druid.lua:437` | Furor + Wolfshead Helm energy | [VERIFIED: codebase] -- returns 0 when no talents/items |

### Shared Decision Functions (Reused Unchanged)

| Function | Location | catLeveling Usage |
|----------|----------|-------------------|
| `shouldUseShred(clickContext)` | `Druid.lua:662` | Builder module: Shred vs Claw decision |
| `shouldCastRip(clickContext)` | `Druid.lua:887` | Rip module: when to apply Rip |
| `shouldUseBite(clickContext)` | `Druid.lua:912` | Term module: when to Bite |
| `isKillShotOrLastChance(clickContext)` | `Druid.lua:764` | Term module: kill-shot priority check |
| `isTrivialBattleOrPvp(clickContext)` | `Druid.lua:714` | Opener: Ravage vs Pounce choice |
| `getOpenerHealthThreshold()` | `Druid.lua:496` | Opener: Pounce health threshold |
| `computeErps(clickContext)` | `Druid.lua:783` | TF/Rip/Rake modules: energy recovery rate |
| `isFightStarted(clickContext)` | `Druid.lua:743` | Auto-attack, regularAttack guards |
| `isTigerPresent(clickContext)` | `Druid.lua:957` | TF module: whether TF buff is active |
| `isRipPresent(clickContext)` | `Druid.lua:980` | Rip module: whether Rip bleed is active |
| `isRakePresent(clickContext)` | `Druid.lua:1015` | Rake module: whether Rake bleed is active |
| `isNearBy(clickContext)` | `Druid.lua:946` | Melee range check (all attack modules) |
| `isGcdOk(clickContext)` | `Druid.lua:1099` | GCD check (all cast modules) |
| `tigerLeft(clickContext)` | `Druid.lua:966` | TF module: TF remaining duration |
| `ripLeft(clickContext)` | `Druid.lua:989` | Rip module: Rip remaining duration |
| `shouldDoReshift(clickContext)` | `Druid.lua:195` | Reshift module: reshift decision |

All shared functions are level-adaptive (Phase 14) and `isSpellExist`-guarded (Phase 13). No new implementations are needed. [VERIFIED: codebase]

### Don't Reuse (catAtk-only modules)

These catAtk modules contain deep coupling with relic dance, energy discharge/overflow, and AP burst logic, and are NOT reused:

| catAtk Module | Why Not Reused |
|---------------|----------------|
| `keepRip(clickContext)` | Calls `dischargeEnergyChangeRelicAndRip` which contains relic swap + energy overflow logic |
| `keepRake(clickContext)` | Calls `atkPowerBurst` and `safeRake` which checks relic-equipped state |
| `keepFF(clickContext)` | Calls `shouldCastFFDuringWaitWindow` which calls `getMinimumAffordableAbilityCost` (bound to relic-influenced costs) and `safeFF` |
| `keepTigerFury(clickContext)` | Calls `safeTigerFury` which is safe but the keep wrapper adds distance gating (copy pattern, not call) |
| `regularAttack(clickContext)` | Simple enough to inline directly |
| `termMod(clickContext)` | Calls `tryBiteKillShot` + `cp5Bite` which has energy discharge + relic-dependent flow |
| `oocMod(clickContext)` | Calls `tryBiteKillShot` + `cp5Bite` chain |
| `reshiftMod(clickContext)` | Calls `shouldDoReshift` + `readyReshift`; reshift guard exists at D-03 |

### ClickContext Fields (catLeveling Simplified)

Based on D-01, catLeveling builds its own clickContext with approximately these fields:

```lua
-- Energy costs (reuse macroTorch.compute* functions)
POUNCE_E = 50          -- constant
CLAW_E                  -- macroTorch.computeClaw_E()
SHRED_E                 -- macroTorch.computeShred_E()
RAKE_E                  -- macroTorch.computeRake_E()
BITE_E = 35             -- constant
RIP_E = 30              -- constant
TIGER_E                 -- macroTorch.computeTiger_E()
-- Timer-related
TIGER_DURATION          -- macroTorch.computeTiger_Duration()
FF_DURATION = 40        -- constant
-- State snapshots
prowling                -- player.isProwling
comboPoints             -- player.comboPoints
ooc                     -- player.isOoc
isBehind                -- player.isBehindTarget
rough                   -- macroTorch.toBoolean(rough) if parameter accepted
-- Immune flags
isImmuneRake            -- target.isImmune('Rake')
isImmuneRip             -- target.isImmune('Rip')
-- Reshift
RESHIFT_ENERGY          -- macroTorch.computeReshiftEnergy()
```

Fields NOT included (vs catAtk): `berserk`, `hasEssenceOfTheRed`, `normalRelic`, `PLAYER_URGENT_HP_THRESHOLD`, `AUTO_TICK_ERPS`, `TIGER_ERPS`, `RAKE_ERPS`, `RIP_ERPS`, `POUNCE_ERPS`, `BERSERK_ERPS`, `COWER_E`, `POUNCE_DURATION`, `RESHIFT_E_DIFF_THRESHOLD`, `isTargetDummy`, `isInCatForm`.

ERPS fields are not precomputed in clickContext -- `computeErps` already uses `clickContext.TIGER_ERPS` etc. which would be nil. The solution: catLeveling either (a) pre-populates simplified ERPS fields without relic contributions, or (b) inlines erps calculation. Given D-01 says "no ERPS/relic fields," the safest path is to set all ERPS contribution fields to 0 (no Ancient Brutality at low levels anyway, and no Pounce bleeds during mid-cycle) and let `computeErps` handle it. Actually, `computeErps` references `clickContext.AUTO_TICK_ERPS`, `clickContext.TIGER_ERPS`, `clickContext.RAKE_ERPS`, `clickContext.RIP_ERPS`, `clickContext.POUNCE_ERPS`, `clickContext.BERSERK_ERPS`, and `clickContext.hasEssenceOfTheRed`. To reuse `computeErps` unchanged, catLeveling must provide these fields:

```lua
clickContext.AUTO_TICK_ERPS = 20 / 2      -- base energy regen (always 20 per 2s)
clickContext.TIGER_ERPS = 10 / 3          -- TF gives 10 energy over 3s
clickContext.RAKE_ERPS = 0                -- no Ancient Brutality at low levels (practically)
clickContext.RIP_ERPS = 0                 -- no Ancient Brutality at low levels (practically)
clickContext.POUNCE_ERPS = 0              -- Pounce bleed resolved during opener only
clickContext.BERSERK_ERPS = 0             -- no Berserk during leveling
clickContext.hasEssenceOfTheRed = false   -- endgame buff only
```

This is a Claude's Discretion item: the exact ERPS field population strategy. [ASSUMED]

## Architecture Patterns

### System Architecture Diagram

```
Key Press (one-button macro)
    |
    v
druidAtk(rough)  [combo.lua:160]
    |
    |  level < 60?
    v
catLeveling()    [leveling.lua]
    |
    |-- Guard: isInCatForm? ----------------> return
    |-- Guard: isCanAttack? ---> targetEnemy() -> return
    |
    |-- 1. Prowling Opener -----------------> pounce() or ravage() -> return
    |       |-- isTrivialBattleOrPvp(clickContext)?
    |       |-- getOpenerHealthThreshold()?
    |       |-- isSpellExist('Pounce')? isSpellExist('Ravage')?
    |
    |-- 2. Start Auto Attack (in combat) ---> startAutoAtk()
    |
    |-- 3. Kill Shot Priority --------------> isKillShotOrLastChance? -> ferocious_bite('raw') -> return
    |       |-- (D-05/D-07: kill shot trumps all)
    |
    |-- 4. Tiger's Fury --------------------> isSpellExist guard -> isTigerPresent? -> tigers_fury()
    |
    |-- 5. Rip (bleed maintenance) ---------> isSpellExist guard -> shouldCastRip? -> rip()
    |
    |-- 6. Rake (bleed maintenance) --------> isSpellExist guard -> isRakePresent? -> rake()
    |
    |-- 7. Faerie Fire (weaving) -----------> isSpellExist guard -> energyWaitWindow? -> faerie_fire_feral('raw')
    |
    |-- 8. Bite (finisher) -----------------> isSpellExist guard -> shouldUseBite? -> ferocious_bite()
    |       |-- OOC + CP>0: ferocious_bite('ready')
    |       |-- Otherwise: energy check then ferocious_bite('ready')
    |
    |-- 9. Builder (Shred/Claw) ------------> isFightStarted? CP<5? -> shouldUseShred? -> shred() or claw()
    |       |-- OOC: 'ready' mode (free cast)
    |       |-- Normal: default mode (energy+distance check)
    |
    |-- 10. Reshift ------------------------> isSpellExist guard -> shouldDoReshift? -> reshift()
            |-- computeReshiftEnergy()==0 -> auto-skip (D-03)

Each module: first success -> return (one action per key press)
```

### Module Priority Order (Final)

```
1. Form/target guards (already in skeleton)
2. Prowling opener (Pounce/Ravage)
3. Auto-attack start
4. Kill-shot Bite (trumps everything -- D-05/D-07)
5. Tiger's Fury maintain
6. Rip maintain
7. Rake maintain
8. Faerie Fire weave (during wait windows)
9. Bite finisher (shouldUseBite)
10. Builder (Shred/Claw via shouldUseShred)
11. Reshift (auto-no-op at low levels, D-03)
```

Key difference from catAtk: kill-shot is extracted to top-level priority (step 4) rather than buried within termMod -> tryBiteKillShot. This reflects D-07 ("kill shot is the ultimate goal, higher priority than Rip").

### Pattern: One-Action-Per-Press

Every module returns after its first successful action. The WoW macro system calls this function on each key press. Consecutive actions do not chain within a single call. [VERIFIED: codebase]

```lua
function macroTorch.catLeveling(rough)
    -- guard layer
    if not player.isInCatForm then return end
    if not target.isCanAttack then player.targetEnemy(); return end
    
    -- build simplified clickContext (one per key press, cached within)
    local clickContext = {}
    -- ... populate fields ...
    
    -- opener
    if clickContext.prowling then
        -- ... Pounce or Ravage ...
        return  -- ONE action per press
    end
    
    -- auto-attack
    if player.isInCombat then player.startAutoAtk() end
    
    -- kill shot (D-05/D-07: highest priority)
    if macroTorch.isKillShotOrLastChance(clickContext) and clickContext.comboPoints > 0 then
        if macroTorch.isSpellExist('Ferocious Bite', 'spell') then
            player.ferocious_bite('raw')
            return
        end
    end
    
    -- TF module
    if macroTorch.isSpellExist("Tiger's Fury", 'spell') then
        -- ... inline keepTigerFury ...
        return
    end
    
    -- ... continued ...
end
```

### Pattern: isSpellExist Module Guard

Every module starts with an `isSpellExist` guard. This replaces explicit `if level < N` branching -- skills that haven't been learned yet are automatically skipped. [VERIFIED: codebase -- Phase 13 pattern]

```lua
-- Rip module
if macroTorch.isSpellExist('Rip', 'spell') then
    if macroTorch.shouldCastRip(clickContext) then
        player.rip()
        return
    end
end
```

### Pattern: clickContext Single-Execution Cache

Fields that require computation are cached on first access within a single key-press execution. `computeErps`, `isTigerPresent`, `isRipPresent`, `isRakePresent`, `isNearBy`, `isGcdOk`, `tigerLeft`, `ripLeft` all use this pattern. [VERIFIED: codebase]

```lua
function macroTorch.isTigerPresent(clickContext)
    if clickContext.isTigerPresent == nil then
        clickContext.isTigerPresent = macroTorch.toBoolean(
            macroTorch.player.hasBuff('Ability_Mount_JungleTiger') and
            macroTorch.tigerLeft(clickContext) > 0)
    end
    return clickContext.isTigerPresent
end
```

### Anti-Patterns to Avoid

- **Calling catAtk keep modules directly:** They contain relic/energy-discharge logic not applicable to leveling. Always inline simplified versions. [VERIFIED: codebase analysis]
- **Explicit level branching:** The Phase 13 pattern of `isSpellExist` guards eliminates the need for `if level < N` blocks. If a skill hasn't been learned, the guard returns and the next module in the priority chain executes. [VERIFIED: codebase -- Phase 13]
- **Hardcoding energy costs:** Use `macroTorch.computeClaw_E()` etc. which adapt to talents (Ferocity). Even though relics are absent, talent-based cost reduction still applies. [VERIFIED: codebase]
- **Using `#` length operator:** WoW 1.12.1 Lua does NOT support `#`. Use `macroTorch.tableLen(tbl)` or `table.insert(tbl, val)`. [VERIFIED: codebase -- CLAUDE.md]
- **Calling `macroTorch.player.mana` for energy:** In cat form, `player.mana` returns energy (WoW API quirk). This is correct and used throughout the codebase. However, `computeReshiftEnergy` returning 0 is the correct guard for low levels.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spell existence check | Custom spellbook scan | `macroTorch.isSpellExist(spellName, bookType)` in `biz_util.lua:75` | Already handles all book types, locale-independent name matching |
| Shred vs Claw decision | Custom builder logic | `macroTorch.shouldUseShred(clickContext)` in `Druid.lua:662` | Level-adaptive, considers bleed count, energy rate, position, OOC |
| Kill-shot judgment | Custom health threshold | `macroTorch.isKillShotOrLastChance(clickContext)` in `Druid.lua:764` | Phase 14: HRPS-based + level-adaptive fallback, battle-tested |
| Rip timing | Custom bleed evaluation | `macroTorch.shouldCastRip(clickContext)` in `Druid.lua:887` | Handles quick/normal battle distinction, CP requirements, immune checks |
| Bite timing | Custom finisher logic | `macroTorch.shouldUseBite(clickContext)` in `Druid.lua:912` | Level-adaptive, handles kill-shot + quick + normal battle modes |
| Energy recovery rate | Custom ERPS calculation | `macroTorch.computeErps(clickContext)` in `Druid.lua:783` | Aggregates TF, bleed, berserk, Essence of Red contributions |
| Combat duration prediction | Custom DPS estimate | `macroTorch.isTrivialBattleOrPvp(clickContext)` in `Druid.lua:714` | Phase 14: level-adaptive DPS table, isTrivialBattle with willDieInSeconds |
| Buff/debuff presence check | Raw texture scan | `macroTorch.isTigerPresent()`, `isRipPresent()`, `isRakePresent()` in `Druid.lua` | Accurate timer-based tracking (WoW API duration is unreliable) |
| Melee range check | Raw distance comparison | `macroTorch.isNearBy(clickContext)` in `Druid.lua:946` | Cached per clickContext, handles edge cases |
| GCD check | Raw cooldown scan | `macroTorch.isGcdOk(clickContext)` in `Druid.lua:1099` | Uses Ability_Druid_Rake icon as GCD proxy (standard WoW 1.12 pattern) |

**Key insight:** Every complex decision in catAtk already has a level-adaptive, isSpellExist-guarded shared function. catLeveling's value is in the simplified orchestration (different priority order, no relic logic), not in reimplementing individual decision functions.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Lua runtime | Build validation (optional) | Yes | 5.4.7 | Not required -- WoW client provides Lua 5.0 |
| Bash | Build script | Yes | 3.2.57 | Core build dependency |
| Node.js | GSD tools | Yes | v22.17.0 | Not needed for addon functionality |

**No missing dependencies.** This phase is pure Lua code with no external tool requirements beyond what's already available.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (custom WoW addon test framework) |
| Config file | none -- inline registrations in `core/selftest.lua` |
| Quick run command | In-game only: login as Druid, observe `[macro-torch] Self-test:` chat output |
| Full suite command | Same as quick run -- all tests execute on PLAYER_ENTERING_WORLD |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-16-04 | isSpellExist guards on all skill casts | unit | Register selftest with minimal clickContext, verify guard returns before cast | Wave 0 (new) |
| REQ-16-01 | Opener via isTrivialBattleOrPvp | unit | Register selftest verifying opener flow uses shared decision functions | Wave 0 (new) |
| REQ-16-05 | Shared function reuse (no duplicated implementation) | unit | Verify all should* functions are NOT redefined in leveling.lua | Wave 0 (new) |
| REQ-16-06 | catLeveling function exists and is callable | unit | `macroTorch.SelfTest:register("catLeveling exists", ...)` | Wave 0 (new) |
| REQ-16-03 | Kill-shot reuses isKillShotOrLastChance | unit | Register selftest verifying kill-shot path calls shared function | Wave 0 (new) |
| REQ-16-02 | Mid-cycle module priority ordering | manual | In-game testing across level ranges | Manual only |
| REQ-16-07 | catAtk unchanged | unit | Verify catAtk function body is identical to pre-phase version | Wave 0 (new) |

### Wave 0 Gaps

- [ ] `core/selftest.lua` -- new catLeveling test registrations (5+ tests)
- [ ] Selftest for `catLeveling` function existence with Druid class guard
- [ ] Selftest for isSpellExist guard behavior at module entry points
- [ ] Selftest verifying shared functions are not locally redefined in leveling.lua

*(Existing selftest infrastructure covers the framework itself; gaps are only the new catLeveling-specific registrations.)*

## Security Domain

**Security enforcement is not applicable.** This is a WoW addon -- all code runs within the WoW Lua sandbox with no network access, no file system access beyond SavedVariables, and no authentication/authorization concerns. The WoW client's built-in sandbox provides all necessary isolation.

Skipping ASVS categorization and threat patterns as not applicable to this domain.

## Common Pitfalls

### Pitfall 1: energy field name confusion (player.mana vs UnitMana)

**What goes wrong:** `macroTorch.player.mana` returns cat-form energy in WoW 1.12.1, not actual mana. Using `UnitMana('player')` returns human-form mana. Confusing the two leads to incorrect energy calculations.

**Why it happens:** WoW API quirk -- in shapeshifted forms, the UnitMana function returns the current resource pool. The codebase has a `humanFormMana` field that correctly returns caster-form mana.

**How to avoid:** Always use `macroTorch.player.mana` for cat-form energy checks within catLeveling. Use `macroTorch.player.humanFormMana` if you need caster-form mana (e.g., for reshift evaluation).

**Warning signs:** Energy values appearing as hundreds or thousands instead of 0-100 range.

### Pitfall 2: OOC double meaning

**What goes wrong:** "ooc" means both "Out of Combat" (energy regen state) and "Omen of Clarity" (proc for free cast). Functions handle these differently.

**Why it happens:** Historical naming in the codebase. CLAUDE.md documents this ambiguity.

**How to avoid:** In catLeveling context, `clickContext.ooc` always means Omen of Clarity proc. Out-of-combat state is determined via `player.isInCombat` / `macroTorch.inCombat`. Never use "ooc" as a variable name for out-of-combat state.

**Warning signs:** Code checking `ooc` outside of spell-casting decision paths.

### Pitfall 3: WoW API buff/debuff duration unreliability

**What goes wrong:** `UnitDebuff` and `UnitBuff` API in WoW 1.12.1 return inaccurate remaining durations for many effects.

**Why it happens:** Known WoW 1.12.1 client bug. The addon implements custom timer tracking (`tigerLeft`, `ripLeft`, `rakeLeft`) as workaround.

**How to avoid:** Never rely on WoW API for debuff/buff duration in catLeveling. Use the existing `isTigerPresent`, `isRipPresent`, `isRakePresent` functions which use texture presence + custom timer tracks. For catLeveling's own spell casts, record cast time in `macroTorch.loginContext` (for TF) and rely on spell trace land events (for Rip/Rake -- already tracked by SpellTrace).

**Warning signs:** Using raw `UnitDebuff` or `UnitBuff` calls instead of the tracked wrapper functions.

### Pitfall 4: Reshift energy at low levels

**What goes wrong:** If `computeReshiftEnergy()` is called without the clickContext having the right prerequisite fields, or if the reshift decision logic assumes energy > 0.

**Why it happens:** `shouldDoReshift` checks `clickContext.RESHIFT_ENERGY == 0` as its first guard (Druid.lua:197). But if RESHIFT_ENERGY is not set in clickContext, this check fails silently.

**How to avoid:** Always set `clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()` in catLeveling's clickContext initialization, just like catAtk does. At low levels (no Furor talents, no Wolfshead Helm), this returns 0 and `shouldDoReshift` auto-skips.

**Warning signs:** Reshift triggering when it shouldn't at low levels; nil field access errors.

### Pitfall 5: computeErps dependencies on clickContext fields

**What goes wrong:** `computeErps` reads `clickContext.AUTO_TICK_ERPS`, `clickContext.TIGER_ERPS`, `clickContext.RAKE_ERPS`, `clickContext.RIP_ERPS`, `clickContext.POUNCE_ERPS`, `clickContext.BERSERK_ERPS`, and `clickContext.hasEssenceOfTheRed`. If these are nil, arithmetic operations produce nil errors.

**Why it happens:** catAtk's clickContext pre-populates all these fields. catLeveling's simplified clickContext must either (a) pre-populate them or (b) inlines a simplified erps calculation.

**How to avoid:** Pre-populate the ERPS contribution fields in catLeveling's clickContext with appropriate defaults:
- `AUTO_TICK_ERPS = 20 / 2` (always active)
- All others = 0 (TF/Rake/Rip ERPS tracked via is*Present in computeErps, Pounce/Berserk/Essence not relevant for leveling)

**Warning signs:** "attempt to perform arithmetic on a nil value" errors in computeErps.

## Code Examples

### catLeveling Simplified clickContext

```lua
-- Source: analysis of catAtk clickContext in combo.lua:29-86, simplified per D-01
local clickContext = {}

-- Energy costs (dynamic -- talent-aware, no relic influence at low levels)
clickContext.POUNCE_E = 50
clickContext.CLAW_E = macroTorch.computeClaw_E()
clickContext.SHRED_E = macroTorch.computeShred_E()
clickContext.RAKE_E = macroTorch.computeRake_E()
clickContext.BITE_E = 35
clickContext.RIP_E = 30
clickContext.TIGER_E = macroTorch.computeTiger_E()

-- Timer-related
clickContext.TIGER_DURATION = macroTorch.computeTiger_Duration()
clickContext.FF_DURATION = 40

-- ERPS fields (required by computeErps)
clickContext.AUTO_TICK_ERPS = 20 / 2
clickContext.TIGER_ERPS = 10 / 3
clickContext.RAKE_ERPS = 0     -- no Ancient Brutality typically
clickContext.RIP_ERPS = 0      -- no Ancient Brutality typically
clickContext.POUNCE_ERPS = 0   -- Pounce bleed resolved in opener phase
clickContext.BERSERK_ERPS = 0  -- no Berserk during leveling
clickContext.hasEssenceOfTheRed = false

-- State snapshots (single-execution cache)
clickContext.prowling = macroTorch.player.isProwling
clickContext.comboPoints = macroTorch.player.comboPoints
clickContext.ooc = macroTorch.player.isOoc
clickContext.isBehind = macroTorch.target.isCanAttack and macroTorch.player.isBehindTarget

-- Immune flags
clickContext.isImmuneRake = macroTorch.target.isImmune('Rake')
clickContext.isImmuneRip = macroTorch.target.isImmune('Rip')

-- Reshift energy
clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()
```

### Opener Module (Pounce/Ravage)

```lua
-- Source: existing leveling.lua skeleton (lines 35-45), enhanced with D-05 logic
if clickContext.prowling then
    local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
    local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
    -- Non-trivial battle + Pounce available + not immune + health above threshold -> Pounce
    if hasPounce and not target.isImmune('Pounce')
            and target.health >= macroTorch.getOpenerHealthThreshold()
            and not macroTorch.isTrivialBattleOrPvp(clickContext) then
        player.pounce()
        return
    elseif hasRavage then
        -- Trivial battle OR Pounce unavailable -> Ravage
        player.ravage('ready')
        return
    end
end
```

### Kill-Shot Priority Module

```lua
-- Source: D-05/D-07 -- kill shot trumps all other modules
if macroTorch.isKillShotOrLastChance(clickContext) then
    if macroTorch.isSpellExist('Ferocious Bite', 'spell') and clickContext.comboPoints > 0 then
        player.ferocious_bite('raw')
        return
    else
        -- No CP but target is killable: build CP with regular attack
        if macroTorch.isSpellExist('Claw', 'spell') then
            player.claw('ready')
            return
        end
    end
end
```

### Tiger's Fury Module (Inlined)

```lua
-- Source: D-02 priority order, pattern from cat.lua:216-226 (keepTigerFury)
if macroTorch.isSpellExist("Tiger's Fury", 'spell') then
    if not macroTorch.isTigerPresent(clickContext) and target.distance <= 20 then
        if macroTorch.tigerSelfGCD(clickContext) == 0
                and macroTorch.player.mana >= clickContext.TIGER_E then
            player.tiger_fury('ready')
            macroTorch.loginContext.tigerTimer = GetTime()
            return
        end
    end
end
```

### FF Weaving Module (Inlined)

```lua
-- Source: D-02 -- FF weaving during energy recovery windows
-- Simplified: no shouldCastFFDuringWaitWindow (which requires getMinimumAffordableAbilityCost)
-- Instead: cast FF when energy is low and we'd be waiting anyway
if macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell') then
    if not clickContext.ooc
            and not macroTorch.target.isImmune('Faerie Fire (Feral)')
            and not macroTorch.shouldDoReshift(clickContext)
            and macroTorch.player.isSpellReady('Faerie Fire (Feral)')
            and macroTorch.isGcdOk(clickContext) then
        -- Cast FF when: non-ooc, non-immune, not about to reshift, spell ready, GCD ok
        -- FF costs 0 energy, only costs 1s GCD -- good filler during energy recovery
        local erps = macroTorch.computeErps(clickContext)
        local energyIn1s = erps * 1.0
        if macroTorch.player.mana + energyIn1s < clickContext.CLAW_E then
            -- Not enough energy for Claw within 1s -- use FF as filler
            player.faerie_fire_feral('raw')
            macroTorch.context.ffTimer = GetTime()
            return
        end
    end
end
```

### Builder Module (Shred/Claw)

```lua
-- Source: D-02/D-04 -- simplified regularAttack, no energy discharge
if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 then
    if macroTorch.shouldUseShred(clickContext) then
        if macroTorch.isSpellExist('Shred', 'spell') then
            if clickContext.ooc then
                player.shred('ready')
            else
                player.shred()
            end
            return
        end
    else
        if macroTorch.isSpellExist('Claw', 'spell') then
            if clickContext.ooc then
                player.claw('ready')
            else
                player.claw()
            end
            return
        end
    end
end
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ERPS contribution fields (TIGER_ERPS, RAKE_ERPS, RIP_ERPS, etc.) must be pre-populated in clickContext for computeErps to work | ClickContext Fields | LOW -- computeErps will error with nil arithmetic; fix is trivial (add the fields) |
| A2 | FF weaving can use a simplified energy-based condition instead of `shouldCastFFDuringWaitWindow` which depends on `getMinimumAffordableAbilityCost` | FF Weaving Module | LOW -- if simplified check performs poorly, can add `getMinimumAffordableAbilityCost` back (it only references clickContext energy costs) |
| A3 | catLeveling does not accept `rough` parameter (current skeleton has none). druidAtk routing line may need adjustment or catLeveling can accept and ignore `rough` | Function Signature | LOW -- either approach is a one-line change in combo.lua:165 |
| A4 | Ancient Brutality talent is typically not available during leveling (requires level 30+ and deep Feral tree), so RAKE_ERPS/RIP_ERPS defaulting to 0 is safe | ERPS Fields | MEDIUM -- if a player specs Ancient Brutality at level 30+, these fields should be non-zero. The computeErps function will undercount energy regen. Fix: dynamically compute RAKE_ERPS/RIP_ERPS via macroTorch.computeRake_Erps()/computeRip_Erps() |
| A5 | Existing `<24` skeleton branch should be removed in favor of generic isSpellExist-guarded modules | Skeleton Refactoring | LOW -- the `<24` branch only handles Claw+Rip which are both covered by generic modules with isSpellExist guards |

## Open Questions

1. **Should catLeveling accept a `rough` parameter?**
   - What we know: catAtk accepts `rough` for pvp/quick-mode override. druidAtk passes `rough` to catAtk but NOT to catLeveling (line 165: `macroTorch.catLeveling()` with no argument).
   - What's unclear: Whether the user wants catLeveling to support a rough mode for leveling PvP scenarios.
   - Recommendation: Add `rough` parameter to catLeveling signature and use it to set `clickContext.rough`. If not needed, the parameter is simply ignored. This matches catAtk's signature for consistency and makes the druidAtk routing change trivial (`macroTorch.catLeveling(rough)`).

2. **Should FF weaving use the full `shouldCastFFDuringWaitWindow` or a simplified version?**
   - What we know: `shouldCastFFDuringWaitWindow` calls `getMinimumAffordableAbilityCost` which evaluates Bite/Tiger/Rip/Rake/Shred/Claw costs in order. This function only needs clickContext energy cost fields (all available).
   - What's unclear: Whether the complexity is justified for leveling where FF triggers OOC procs less frequently.
   - Recommendation: Use `shouldCastFFDuringWaitWindow` directly -- it's already written and debugged, and the cost of calling it is zero (pure Lua computation). The D-02 specification allows this under Claude's discretion ("zero-cost, returns when conditions not met").

3. **Should the existing `<24` skeleton code be preserved as a comment or deleted entirely?**
   - What we know: The `<24` branch handles Claw+Rip which the new generic modules cover via isSpellExist guards.
   - What's unclear: Whether there's value in keeping the code as reference.
   - Recommendation: Delete the `<24` branch. The generic module structure with isSpellExist guards is clearer and covers all levels uniformly. The git history preserves the old code.

## Sources

### Primary (HIGH confidence)
- `classes/druid/leveling.lua` -- Existing catLeveling skeleton (77 lines) [VERIFIED: codebase]
- `classes/druid/combo.lua` -- catAtk full implementation (291 lines) + druidAtk routing [VERIFIED: codebase]
- `classes/druid/cat.lua` -- catAtk 13 module implementations (417 lines) [VERIFIED: codebase]
- `classes/druid/Druid.lua` -- All 16+ shared decision functions, energy calculations, buff/debuff tracking [VERIFIED: codebase]
- `biz_util.lua:75-77` -- isSpellExist infrastructure [VERIFIED: codebase]
- `core/selftest.lua` -- SelfTest framework and existing test registrations [VERIFIED: codebase]
- `build_order.txt` -- leveling.lua already listed at line 32 [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- `.planning/phases/13-catatk-60-dps/13-CONTEXT.md` -- isSpellExist guard pattern, Phase 13 decisions [CITED: planning docs]
- `.planning/phases/14-istrivialbattle-iskillshotorlastchance-60-dps-b/14-CONTEXT.md` -- Level-adaptive DPS estimation, kill-shot threshold design [CITED: planning docs]
- `.planning/phases/15-catatk-druid-combo-lua/15-CONTEXT.md` -- catAtk migration to combo.lua global function [CITED: planning docs]
- `.planning/codebase/ARCHITECTURE.md` -- System architecture, metatable chain, clickContext caching pattern [CITED: codebase analysis]
- `.planning/codebase/CONVENTIONS.md` -- Naming conventions, function style, global function pattern [CITED: codebase analysis]

### Tertiary (LOW confidence)
- None -- all claims are verified against codebase or cited from planning documents.

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH -- no external dependencies; all reusable code confirmed in codebase
- Architecture: HIGH -- module priority order, clickContext caching, isSpellExist guard, one-action-per-press patterns all verified in existing code
- Pitfalls: HIGH -- energy/mana confusion, OOC ambiguity, WoW API duration unreliability all documented in existing code and CLAUDE.md
- Shared Functions: HIGH -- all 16 functions referenced in CONTEXT.md confirmed to exist in Druid.lua with level-adaptive + isSpellExist guards

**Research date:** 2026-06-22
**Valid until:** 2026-07-22 (codebase is stable; shared functions unlikely to change)

**Package legitimacy audit:** NOT APPLICABLE -- Phase 16 installs no external packages. All dependencies are internal to the macro-torch codebase.