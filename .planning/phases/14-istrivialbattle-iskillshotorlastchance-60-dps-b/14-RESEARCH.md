# Phase 14: isTrivialBattle / isKillShotOrLastChance 等级自适应 - Research

**Researched:** 2026-06-20
**Domain:** World of Warcraft 1.12.1 (Turtle WoW) cat druid leveling DPS estimation and kill shot threshold scaling
**Confidence:** MEDIUM

## Summary

Phase 14 replaces hardcoded level-60 static DPS estimate (`500`) and 15 per-CP kill-shot health constants with level-adaptive lookup tables. The core challenge is deriving reasonable DPS and health threshold values for level brackets 10-59 while preserving the level-60 behavior exactly.

The level-60 baselines are verified directly from the codebase (`Druid.lua:769-777` for `500` DPS, `Druid.lua:807-811` for `KS_CP5_Health = 1750`). For lower brackets, values are derived from WoW 1.12 cat druid mechanics: energy regeneration rate (10 erps base), skill rank availability (Claw unlocks at level 20, Shred at level 22, Ferocious Bite at level 32), weapon damage scaling, and observed leveling DPS patterns from classic WoW.

**Primary recommendation:** Use a simple if-elseif chain lookup (matching the existing `computeClaw_E` pattern in `Druid.lua:558-566`) with a 5-bracket table covering `20-29/30-39/40-49/50-59/60`, and a 60-level hard guard returning level-60 baseline values directly. Pre-cat (levels 1-19) returns conservative fallback values.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Level-DPS lookup table (not AP formula). Energy system is the primary DPS bottleneck for cat druid; AP alone cannot accurately model this.
- **D-02:** Single KS health threshold lookup (no CP granularity). `isKillShotOrLastChance` condition B simplified to `targetHealth < getKSThreshold(playerLevel)`.
- **D-03:** Delete all 15 `macroTorch.KS_CP*_Health*` module-level constants (`Druid.lua:807-823`).
- **D-04:** New independent functions `estimatePlayerDPS(level)` and `getKSThreshold(level)` in `classes/druid/Druid.lua`, following Phase 13 `computeReshiftEnergy` pattern. 60-level hard guard: `if level == 60 then return 500 end` ensures zero-risk for max level.
- **D-05:** Conservative fallback when level data is insufficient: `isTrivialBattle` returns `false` (no quick battle mode), `isKillShotOrLastChance` condition B falls through to condition A only (willDieInSeconds path).
- **D-06:** ~6 Category I selftests in `core/selftest.lua`: 60-level DPS=500 verification, 60-level KS threshold=1750 verification, low-level DPS bracket boundary verification, low-level KS threshold bracket verification, condition A (willDieInSeconds) unchanged verification, conservative fallback verification.

### Claude's Discretion

- Level bracket granularity (10-level brackets adopted: 1-19 pre-cat, 20-29, 30-39, 40-49, 50-59, 60)
- Exact DPS and KS threshold values per bracket
- Lookup table implementation style (if-elseif chain adopted, consistent with `computeClaw_E` pattern)
- Whether to retain solo/group/raid scaling in `getKSThreshold` (NOT retained at function level; scaling if needed is inlined at call site within `isKillShotOrLastChance`)
- Selftest case count and boundary coverage

### Deferred Ideas (OUT OF SCOPE)

- Other classes (Warrior/Rogue) DPS estimation -- future phases
- AP-aware hybrid DPS estimation -- future improvement if equipment variance proves significant
- group/raid multiplier in `getKSThreshold` -- kept simple per D-02, can add coefficient later

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-14-DPS | `estimatePlayerDPS(level)` per-bracket lookup | Level-adaptive DPS table with 5 brackets; 60-level hard guard returns 500 [VERIFIED: codebase `Druid.lua:775`] |
| REQ-14-KS | `getKSThreshold(level)` single health threshold | Level-adaptive KS threshold table; 60-level returns 1750 [VERIFIED: codebase `Druid.lua:811`] |
| REQ-14-DELETE | Delete 15 `KS_CP*_Health*` constants from `Druid.lua:807-823` | Constants serve only level-60 use case; replaced by `getKSThreshold(level)` |
| REQ-14-GUARD | 60-level hard guard preserves max-level behavior | `if level == 60 then return 旧值 end` at top of each new function |
| REQ-14-FALLBACK | Conservative fallback for unknown levels | Silent return of `false` / fall through to `willDieInSeconds` only |
| REQ-14-TEST | ~6 Category I selftests | Pattern documented, test registration at `Druid.lua:~1290-1388` in Category H section |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Level-DPS lookup | Business Logic (Druid.lua) | -- | Pure data lookup, no API calls needed; belongs with other `compute*` functions |
| KS health threshold lookup | Business Logic (Druid.lua) | -- | Same as above; follows `computeReshiftEnergy` precedent |
| isTrivialBattle modification | Business Logic (Druid.lua) | -- | Replace `500` constant with `estimatePlayerDPS(level)` call |
| isKillShotOrLastChance simplification | Business Logic (Druid.lua) | -- | Replace 55-line CP-mode branching with single `getKSThreshold` call |
| Selftest registration | Selftest (selftest.lua) | -- | Follows existing `SelfTest:register()` pattern at end of Druid.lua |
| willDieInSeconds / currentHRPS | Entity (Target.lua) | -- | Condition A remains unchanged; no modification needed |

## Standard Stack

### Core

No external dependencies. This phase modifies only existing Lua files within the project.

### Existing Infrastructure (Reused)

| Component | File | Purpose |
|-----------|------|---------|
| `UnitLevel('player')` | WoW 1.12 API | Native Blizzard API; returns player level; no addon dependency |
| `macroTorch.SelfTest:register(name, fn, isOptional)` | `core/selftest.lua` | Existing self-test framework; Phase 13 established Category H pattern |
| `macroTorch.target.willDieInSeconds(s)` | `entity/Target.lua:86-98` | Condition A hit (HRPS-based); remains primary KS path, unchanged |
| `macroTorch.currentHRPS()` | `entity/Target.lua:132-158` | Linear regression HRPS computation; unchanged |

### New Functions (Phase 14)

| Function | Location | Purpose |
|----------|----------|---------|
| `macroTorch.estimatePlayerDPS(level)` | `classes/druid/Druid.lua` | Returns cat druid DPS estimate for given player level |
| `macroTorch.getKSThreshold(level)` | `classes/druid/Druid.lua` | Returns single kill shot health threshold for given player level |

**Installation:** No packages to install. This is a Lua code modification only.

## Package Legitimacy Audit

No external packages are installed. This phase modifies existing Lua source files only. Audit skipped.

## Architecture Patterns

### System Architecture Diagram

```
isTrivialBattle(clickContext)                    isKillShotOrLastChance(clickContext)
         |                                                    |
         v                                                    v
   [clickContext cache check]                         [Condition A]
         |                                          willDieInSeconds(2)
    [NOT cached]                                         |
         |                                          [Returns: bool]
         v                                                    |
   [Condition A]                                     [If false: Condition B]
   willDieInSeconds(25)                                      |
         |                                                    v
    [If true: done]                                  [Condition B]
         |                                          targetHealth < getKSThreshold(level)
    [If false: Condition B]                                  |
         |                                          [Returns: bool]
         v
   [Condition B]
   healthMax <= (mates+1) * estimatePlayerDPS(level) * 25
         |
   [cache & return: bool]

estimatePlayerDPS(level):                       getKSThreshold(level):
    level == 60? -> return 500 [guard]              level == 60? -> return 1750 [guard]
    level >= 50? -> return 350                      level >= 50? -> return 1450
    level >= 40? -> return 200                      level >= 40? -> return 1050
    level >= 30? -> return 120                      level >= 30? -> return 700
    level >= 20? -> return 60                       level >= 20? -> return 400
    else        -> return 25 (conservative)         else        -> return 200 (conservative)
```

### Recommended Project Structure

No new files created. All changes within existing files:

```
classes/druid/Druid.lua    # +estimatePlayerDPS, +getKSThreshold, ~isTrivialBattle, ~isKillShotOrLastChance, -15x KS_CP* constants
core/selftest.lua           # (unchanged; new tests registered via SelfTest:register in Druid.lua)
```

### Pattern 1: if-elseif Chain Lookup (computeClaw_E Precedent)

**What:** Simple descending if-elseif chain to map level to a constant value. This avoids Lua table overhead and is consistent with existing codebase style.

**When to use:** Small lookup tables (<= 10 items) where simplicity and readability outweigh data structure elegance.

**Example:**
```lua
-- Source: Druid.lua:558-566 (existing computeClaw_E pattern adaptation)
function macroTorch.estimatePlayerDPS(level)
    if not level then
        level = UnitLevel('player')
    end
    -- [D-04] 60-level hard guard: preserve level-60 behavior exactly
    if level == 60 then
        return 500  -- [VERIFIED: codebase Druid.lua:775 — current hardcoded value]
    end
    -- [D-01] Level-DPS lookup table for cat druid leveling brackets
    if level >= 50 then
        return 350  -- [ASSUMED]
    elseif level >= 40 then
        return 200  -- [ASSUMED]
    elseif level >= 30 then
        return 120  -- [ASSUMED]
    elseif level >= 20 then
        return 60   -- [ASSUMED]
    else
        -- Pre-cat form (level 1-19): cat form unlocks at level 20 in 1.12
        return 25   -- [ASSUMED] caster-level DPS for pre-cat druids
    end
end
```

### Pattern 2: 60-Level Hard Guard (computeReshiftEnergy Precedent)

**What:** A guard clause at the top of each new function that returns the old hardcoded value when `level == 60`, ensuring zero behavioral change for max-level characters.

**When to use:** Any function that replaces a previously hardcoded level-60 value with level-adaptive logic.

**Why:** Phase 13 established this pattern with `isSpellExist` guards. The 60-level guard is the contract: "at level 60, everything works exactly as before." This is the highest-value execution path since max-level raiding/PvP is where the addon is most actively used.

### Pattern 3: clickContext Caching (Existing isTrivialBattle Pattern)

**What:** `isTrivialBattle` already uses the pattern `if clickContext.X == nil then compute; cache end`. This pattern is preserved and should not be changed.

**When evaluating whether to add caching to `isKillShotOrLastChance`:** The condition B path (fallback) is called in two high-frequency locations (`shouldCastRip:1003` and `shouldUseBite:1025`) within a single `catAtk()` execution. Without caching, `getKSThreshold(UnitLevel('player'))` would be called at most twice per click -- which is negligible since `UnitLevel()` is a trivial API call and `getKSThreshold` is a 5-branch if-elseif chain (O(1)). However, `willDieInSeconds(2)` (condition A) involves iterating HRPS vector data, and caching that result is already handled by the short-circuit return behavior (condition A returns early; condition B is only evaluated once per function call when condition A is false). No additional caching needed.

**Recommendation:** Do NOT add clickContext caching to `isKillShotOrLastChance`. The function's condition B does at most 2 calls per `catAtk()` execution and the overhead of adding another cache field to clickContext is not justified.

### Anti-Patterns to Avoid

- **Complex table-based lookup with metatables:** Over-engineering for a 5-item lookup. The existing codebase uses simple if-elseif chains for similar small lookup tables (see `computeClaw_E`, `computeShred_E`).
- **AP formula estimation:** Rejected by D-01. Energy system is the primary cat druid DPS bottleneck; AP alone does not model this accurately. At low levels especially, energy starvation dominates DPS.
- **Copying the old CP-mode branching structure into the new function:** The whole point of D-02 is simplification. Do not recreate the 15-constant x 3-mode x 5-CP branching in `getKSThreshold`.
- **Modifying `isTrivialBattleOrPvp`:** This function only does `OR` combination. It calls `isTrivialBattle`, which gets updated automatically through the DPS lookup. No changes needed here.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Level-DPS estimation formula | Custom Lua damage calculation engine | Simple lookup table (if-elseif chain) | D-01 explicitly requires lookup table; energy system + skill ranks + weapon damage make formula too complex and fragile |
| KS threshold formula | CP x AP x rank formula | Single lookup table scaling from verified level-60 baseline | D-02 simplifies to single threshold; the relationship between level and kill-shot damage is approximately linear in cat druid due to energy constraints |
| Generic utility table library | Custom `Map` or `Dict` implementation | if-elseif chain | Lua table overhead is unnecessary for 5 items; if-elseif chain is idiomatic in this codebase |

**Key insight:** The DPS estimation is inherently approximate and conservative -- it does not need high precision. The purpose of `isTrivialBattle` condition B is to detect when "this target's health pool is so small that we should skip complex rotation optimization." Even being off by 20-30% still produces the correct binary decision for the vast majority of leveling encounters. The fallback (D-05: `isTrivialBattle` returns `false`) is safe -- it means the addon falls back to normal rotation logic, which works correctly but sub-optimally for trivial fights.

## Common Pitfalls

### Pitfall 1: Breaking level-60 behavior

**What goes wrong:** The lookup table assigns a different DPS value at level 60 than the current hardcoded `500`.
**Why it happens:** Off-by-one in bracket boundaries, or rounding differences in derived thresholds.
**How to avoid:** The 60-level hard guard (`if level == 60 then return 500 end`) at the top of `estimatePlayerDPS` makes this impossible. Even if the bracket logic below contains an error, level 60 returns the exact old value.
**Warning signs:** Selftest failure on "60-level DPS=500 verification" test.

### Pitfall 2: # unary operator on Lua 5.0 (WoW 1.12)

**What goes wrong:** Using `#` to get array length in a table used for lookup.
**Why it happens:** WoW 1.12.1 embeds Lua that does not support `#`.
**How to avoid:** Use if-elseif chain instead of table lookup. If a table were used, access it by key (e.g., `DPS_BRACKET[levelBracket]`), not iterating with `#`.
**Warning signs:** Lua error in WoW macro; `#` is a syntax error in WoW's Lua environment. Already flagged in CLAUDE.md.

### Pitfall 3: Not handling nil level parameter

**What goes wrong:** Calling `estimatePlayerDPS(nil)` or `getKSThreshold(nil)` causes a crash.
**Why it happens:** Caller may forget to pass `UnitLevel('player')` explicitly.
**How to avoid:** Add guard at top of each function: `if not level then level = UnitLevel('player') end`. This mirrors the pattern used in WoW API functions that accept optional unit tokens.
**Warning signs:** Lua error when WoW API returns nil for UnitLevel in edge cases (e.g., during loading screens).

### Pitfall 4: Silent numeric drift from bracket boundaries

**What goes wrong:** At level 49 vs level 50, the DPS estimate jumps from 200 to 350 (a 75% increase), which is physically unrealistic for a single level gain.
**Why it happens:** Discrete bracket boundaries create step functions -- this is inherent to any lookup table approach.
**How to avoid:** This is acceptable. The lookup table is conservative (values are intentionally lower than theoretical max DPS at each bracket), so the jump at bracket boundaries means the addon gets more aggressive at the right thresholds. The alternative (smooth interpolation) adds complexity without meaningful benefit for a binary classification problem.
**Warning signs:** Not a bug, but worth documenting. Selftests should verify bracket boundary behavior explicitly.

### Pitfall 5: Forgetting to delete KS_CP* constants

**What goes wrong:** 15 stale constants remain in the global namespace after `isKillShotOrLastChance` stops using them.
**Why it happens:** Deleting the usage sites but forgetting to remove the constant definitions.
**How to avoid:** Explicit verification step in the plan: `grep -c "KS_CP" classes/druid/Druid.lua` should return 0 after the change.
**Warning signs:** Stale constants cause no runtime error (they are just dead code), but violate D-03 and create maintenance confusion.

## Code Examples

### estimatePlayerDPS -- Full Implementation

```lua
-- Source: Derived from Druid.lua:558-566 computeClaw_E pattern + CONTEXT.md D-01, D-04, D-05
-- Estimates cat druid DPS based on player level for isTrivialBattle condition B
function macroTorch.estimatePlayerDPS(level)
    if not level then
        level = UnitLevel('player')
    end
    -- [D-04] 60-level hard guard: preserve level-60 behavior exactly
    if level == 60 then
        return 500  -- [VERIFIED: codebase Druid.lua:775]
    end
    -- [D-01] Level-DPS lookup table
    -- Values are conservative estimates for cat druid in leveling gear.
    -- Key factors: energy regen (10 erps base), skill rank availability, weapon damage.
    if level >= 50 then
        return 350  -- [ASSUMED] Claw rank 5 + Bite rank 4-5, 10+ erps with talents
    elseif level >= 40 then
        return 200  -- [ASSUMED] Claw rank 4 + Bite rank 3, level 40 mount gear
    elseif level >= 30 then
        return 120  -- [ASSUMED] Claw rank 3 + Bite rank 2, Shred available
    elseif level >= 20 then
        return 60   -- [ASSUMED] Claw rank 1-2, cat form just unlocked
    else
        return 25   -- [ASSUMED] [D-05] conservative fallback for pre-cat levels
    end
end
```

### getKSThreshold -- Full Implementation

```lua
-- Source: Derived from Druid.lua:807-811 KS_CP5_Health + CONTEXT.md D-02, D-04, D-05
-- Returns kill shot health threshold for the given player level.
-- This is the single threshold for condition B of isKillShotOrLastChance.
-- At level 60, returns 1750 to match old KS_CP5_Health solo value.
function macroTorch.getKSThreshold(level)
    if not level then
        level = UnitLevel('player')
    end
    -- [D-04] 60-level hard guard: preserve level-60 behavior exactly
    if level == 60 then
        return 1750  -- [VERIFIED: codebase Druid.lua:811 — macroTorch.KS_CP5_Health]
    end
    -- [D-02] Single KS health threshold lookup table
    -- Conservative estimates: ~2 seconds of solo DPS + one Bite worth of damage
    if level >= 50 then
        return 1450  -- [ASSUMED] Bite rank 5 + white hits in ~2 GCD window
    elseif level >= 40 then
        return 1050  -- [ASSUMED] Bite rank 4 + white hits
    elseif level >= 30 then
        return 700   -- [ASSUMED] Bite rank 2-3 + white hits
    elseif level >= 20 then
        return 400   -- [ASSUMED] Bite rank 1 or Claw spam damage
    else
        return 200   -- [ASSUMED] [D-05] conservative: ~2 GCD of pre-cat damage
    end
end
```

### isTrivialBattle -- Modified Condition B

```lua
-- Source: Druid.lua:769-778 modification
function macroTorch.isTrivialBattle(clickContext)
    if clickContext.isTrivialBattle == nil then
        local trivialDieTime = 25
        -- if the target's max health is less than we attack 25s worth of DPS
        clickContext.isTrivialBattle = macroTorch.target.willDieInSeconds(trivialDieTime) or
                macroTorch.target.healthMax <=
                        (macroTorch.player.mateNearMyTargetCount + 1) *
                        macroTorch.estimatePlayerDPS() * trivialDieTime
        -- [CHANGED] ^^^ 500 replaced with estimatePlayerDPS() call
    end
    return clickContext.isTrivialBattle
end
```

### isKillShotOrLastChance -- Simplified Condition B

```lua
-- Source: Druid.lua:830-885 simplification per D-02, D-03
function macroTorch.isKillShotOrLastChance(clickContext)
    -- [Condition A] Primary path: HRPS-based prediction (highest accuracy)
    if macroTorch.target.willDieInSeconds(2) then
        return true
    end
    -- [Condition B] Fallback: level-adaptive health threshold
    -- Only used when HRPS data is insufficient (e.g., just switched target)
    local targetHealth = macroTorch.target.health
    local fightWorldBoss = macroTorch.target.classification == 'worldboss'
    if macroTorch.player.isInGroup and fightWorldBoss then
        return clickContext.comboPoints >= 3 and macroTorch.target.healthPercent <= 2
    end
    -- [NEW D-02] Simplified: single threshold lookup replaces 15 constants + 55 lines of CP-mode branching
    return targetHealth < macroTorch.getKSThreshold()
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded 500 DPS per person | `estimatePlayerDPS(level)` lookup table | Phase 14 | Accurate for leveling; zero-change for level 60 |
| 15 `KS_CP*_Health*` constants + CP-mode branching | Single `getKSThreshold(level)` call | Phase 14 | 55 lines reduced to 1; deleted 15 constants |
| Kill shot = CP x mode matrix | Kill shot = `targetHealth < threshold` | Phase 14 | Simpler, correct threshold; condition A (HRPS) remains primary path |

**Deprecated/outdated:**
- `macroTorch.KS_CP*_Health*` (15 constants at `Druid.lua:807-823`): Replaced by `getKSThreshold(level)`. These were always level-60 estimates anyway; the CP granularity added false precision since Bite damage variance is wider than the CP increments.
- Group/raid scaling within `isKillShotOrLastChance`: While the current code scales thresholds by group size, this scaling was always approximate (the `nearMateNum` interpolation is linear interpolation between solo and 5-man values, which is a rough heuristic). D-02 simplifies this away -- at low levels where group play is less common, the single threshold is adequate. If group scaling is needed in the future, a simple multiplier coefficient can be added in the call site without restoring 15 constants.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Level 50-59 cat druid in leveling gear does ~350 DPS | Standard Stack / estimatePlayerDPS | `isTrivialBattle` condition B may be too sensitive (false positive) or not sensitive enough (false negative) for players in very poor or very good gear at level 50-59. Conservative fallback (return false) means worst case is missed optimization, not incorrect rotation. |
| A2 | Level 40-49 cat druid DPS is ~200 | Standard Stack / estimatePlayerDPS | Same as A1 but for 40-49 bracket. Risk is lower because mid-level content is more forgiving. |
| A3 | Level 30-39 cat druid DPS is ~120 | Standard Stack / estimatePlayerDPS | Before level 40, solo play dominates (no mounts, fewer group activities). Lower DPS estimate means `isTrivialBattle` triggers more conservatively, which matches the leveling experience. |
| A4 | Level 20-29 cat druid DPS is ~60 | Standard Stack / estimatePlayerDPS | Cat form unlocks at level 20; limited skill ranks. 60 DPS is conservative for a freshly-unlocked form. |
| A5 | Pre-cat (1-19) DPS is ~25 | Standard Stack / estimatePlayerDPS | Balance druid in caster form before cat unlock. Very low risk -- `isTrivialBattle` almost never triggers before level 20, which is correct since druids don't have cat form rotation to optimize. |
| A6 | KS threshold at level 50-59 is 1450 | Standard Stack / getKSThreshold | Derived as ~83% of level-60 threshold (1750 * 50/60 = 1458). If too low, `isKillShotOrLastChance` condition B won't trigger when it should -- but condition A (HRPS) is the primary path and will catch actual kill shots. |
| A7 | KS thresholds scale approximately linearly with level | Standard Stack / getKSThreshold | Non-linear scaling (e.g., weapon damage jumps at certain level ranges) could mean thresholds are systematically too low or high in some brackets. Impact is limited because condition A is the primary path. |
| A8 | No clickContext caching needed for isKillShotOrLastChance | Architecture / Pattern 3 | At most 2 calls per click execution; caching would add complexity without meaningful performance gain. Risk of being wrong: negligible performance impact. |
| A9 | Single KS threshold (no group/raid/cp granularity) is adequate | Architecture / isKillShotOrLastChance | If a player runs low-level group content frequently, the single threshold may be too conservative (condition B won't trigger for group kills). Condition A (HRPS) compensates for this. |

## Open Questions

1. **Actual DPS values at each level bracket from in-game measurement**
   - What we know: Level 60 value is 500 from existing code. Bracket values are estimated from game mechanic knowledge (skill ranks, energy regen, weapon damage progression).
   - What's unclear: Exact observed DPS for a typical cat druid at levels 25, 35, 45, 55.
   - Recommendation: These are conservative estimates (likely 10-20% below peak DPS). The planner should include a note that values can be tuned after in-game testing. Since the fallback (conservative = don't trigger quick battle/kill shot mode) is safe, users will not notice incorrect estimates -- they will just get standard rotation behavior which is correct but sub-optimal for trivial fights.

2. **Whether World Boss logic needs level adaptation**
   - What we know: The world boss check (`classification == 'worldboss'`) is currently excluded from the CP-mode branching and uses its own 2% health threshold.
   - What's unclear: Whether a level 40 player fighting a level 60 world boss should use the same 2% threshold.
   - Recommendation: Leave the world boss check as-is. World bosses are a level-60 activity in practice; the 2% health threshold combined with `comboPoints >= 3` check is already conservative and level-agnostic (uses health percentage, not absolute health).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WoW 1.12.1 API `UnitLevel('player')` | `estimatePlayerDPS`, `getKSThreshold` | By definition (phase runs in WoW client) | -- | N/A -- this is a WoW addon, the API is guaranteed available |
| Lua 5.0 runtime | All code | By definition | 5.0 (WoW embedded) | N/A |
| Node.js (build only) | `build.sh` | ✓ | v22.17.0 | Any Node.js >= 14 |

**Missing dependencies with no fallback:** None
**Missing dependencies with fallback:** None

Step 2.6: AUDIT COMPLETE (no external tooling dependencies beyond WoW client runtime)

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (in-house) -- `core/selftest.lua` |
| Config file | none -- tests registered inline via `SelfTest:register()` |
| Quick run command | `SelfTest:run()` in-game (triggered automatically on `PLAYER_ENTERING_WORLD`) |
| Full suite command | `SelfTest:run()` (all tests run in single pass; no subset selection) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-14-DPS-60 | `estimatePlayerDPS(60)` returns 500 | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-DPS-BRACKET | `estimatePlayerDPS(35)` returns value within valid range | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-DPS-FALLBACK | `estimatePlayerDPS(15)` returns conservative value (25) | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-KS-60 | `getKSThreshold(60)` returns 1750 | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-KS-BRACKET | `getKSThreshold(35)` returns value within valid range | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-KS-FALLBACK | `getKSThreshold(15)` returns conservative value (200) | Selftest (Category I) | Registered in Druid.lua via `SelfTest:register` | Wave 0 |
| REQ-14-GUARD | Any function with level=60 returns old hardcoded value exactly | Selftest (Category I) | Covered by REQ-14-DPS-60 and REQ-14-KS-60 tests | Wave 0 |
| REQ-14-DELETE | `KS_CP` constants no longer exist | Manual grep verification | `grep -c "KS_CP" classes/druid/Druid.lua` should return 0 | Plan task |
| REQ-14-CONDITION-A | `willDieInSeconds(2)` path unchanged in `isKillShotOrLastChance` | Selftest (Category I) | Verify function still calls `willDieInSeconds(2)` as first check | Wave 0 |

### Sampling Rate

- **Per task commit:** Not applicable (tests are in-game only; no CI for WoW addon)
- **Per wave merge:** Run `build.sh` + load addon in WoW + observe `SelfTest:run()` output
- **Phase gate:** All Category I tests green in-game

### Wave 0 Gaps

- [ ] `classes/druid/Druid.lua` -- register ~6 Category I selftest items for `estimatePlayerDPS` and `getKSThreshold`
- [ ] Selftest registration follows existing Category H pattern (`Druid.lua:1290-1388`): `SelfTest:register(name, fn, true)` with `isOptional=true`

## Security Domain

Security enforcement is enabled (default in config.json). However, this phase has no security-relevant changes:
- No user input processing
- No network access
- No persistent data storage
- No authentication or authorization changes
- Pure calculation logic modifications within existing Lua code

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | -- |
| V3 Session Management | no | -- |
| V4 Access Control | no | -- |
| V5 Input Validation | yes (minimal) | `not level` guard → default to `UnitLevel('player')`; implicit type check via comparison operators |
| V6 Cryptography | no | -- |

### Known Threat Patterns for WoW 1.12 Lua Addon

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| WoW API misuse (calling API during loading screen) | Denial of Service | `UnitLevel('player')` returns nil during loading; guarded by `if not level then` pattern |
| Infinite loop in lookup function | Denial of Service | if-elseif chain has finite branches; no loops, no recursion |

## Sources

### Primary (HIGH confidence)

- `classes/druid/Druid.lua:769-777` -- `isTrivialBattle()` current implementation with hardcoded `500` DPS [VERIFIED: codebase]
- `classes/druid/Druid.lua:807-823` -- 15 `KS_CP*_Health*` constant definitions [VERIFIED: codebase]
- `classes/druid/Druid.lua:830-885` -- `isKillShotOrLastChance()` current implementation with CP-mode branching [VERIFIED: codebase]
- `classes/druid/Druid.lua:558-566` -- `computeClaw_E()` if-elseif pattern for lookup tables [VERIFIED: codebase]
- `classes/druid/Druid.lua:568-578` -- `computeReshiftEnergy()` Phase 13 precedent for new function pattern [VERIFIED: codebase]
- `classes/druid/Druid.lua:1290-1388` -- Category H selftest registration pattern [VERIFIED: codebase]
- `entity/Target.lua:86-98` -- `willDieInSeconds(s)` condition A implementation [VERIFIED: codebase]
- `entity/Target.lua:132-158` -- `currentHRPS()` linear regression implementation [VERIFIED: codebase]
- `.planning/phases/14-.../14-CONTEXT.md` -- Phase decisions D-01 through D-06 [CITED: project docs]

### Secondary (MEDIUM confidence)

- `.planning/phases/13-catatk-60-dps/13-CONTEXT.md` -- Phase 13 `computeReshiftEnergy` precedent and `isSpellExist` guard patterns [CITED: project docs]
- `.planning/codebase/CONVENTIONS.md` -- Naming conventions and codebase patterns [CITED: project docs]
- WoW 1.12.1 API documentation: `UnitLevel()` function reference [CITED: `.claude-reference/Functions.md`]
- Classic WoW druid energy mechanics: 10 erps base energy regen in cat form, Furor talent adds 10 energy per rank on reshift [ASSUMED: training knowledge; consistent with codebase `computeReshiftEnergy`]

### Tertiary (LOW confidence)

- Web search for cat druid DPS by level bracket: No results returned (empty responses from WebSearch for all 6 queries) [LOW: websearch classify-confidence]
- Specific DPS values for brackets 20-29, 30-39, 40-49, 50-59: Derived from training knowledge of WoW 1.12 cat druid leveling mechanics (skill rank unlock levels, energy regen, weapon damage scaling) [ASSUMED]
- KS health threshold values for non-60 brackets: Derived by linear scaling from level-60 baseline with conservative rounding [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all infrastructure exists in-codebase; no external dependencies
- Architecture: HIGH -- follows established patterns (`computeClaw_E`, `computeReshiftEnergy`, `isSpellExist` guards); integration points clearly mapped
- DPS/KS bracket values: LOW -- exact per-bracket values cannot be independently verified; all are tagged `[ASSUMED]` and derived from training knowledge
- Pitfalls: HIGH -- informed by codebase conventions (CLAUDE.md `#` operator warning), Phase 13 guard pattern, and WoW Lua runtime constraints

**Research date:** 2026-06-20
**Valid until:** 2026-08-20 (assuming no WoW API changes for Turtle WoW)

**Why the DPS values are reasonable:** The lookup table serves a binary classification purpose ("is this a trivial fight?" / "is this a kill shot?"), not a simulation purpose. Conservative values that underestimate DPS are safe -- they cause the addon to fall back to normal rotation logic, which is always correct even if not optimal. The planner should note that `[ASSUMED]` bracket DPS values are starting points that can be tuned based on in-game testing feedback.