# Phase 13: catAtk 小号练级适配 - Research

**Researched:** 2026-06-20
**Domain:** WoW 1.12.1 (Turtle WoW) Lua addon — Druid cat form DPS rotation adaptation for low-level leveling
**Confidence:** HIGH

## Summary

Phase 13 adapts the `catAtk()` one-button macro for low-level Druid characters (levels 10-50) through three core changes: (1) `isSpellExist` guard clauses on all cat form skill modules, (2) dynamic `RESHIFT_ENERGY` computation based on Furor talent ranks and Wolfshead Helm equipment, and (3) natural fallback degradation through shared decision function guards. The critical constraint is that level 60 max-DPS behavior remains completely unchanged — all guards evaluate to no-op at level 60 with full skills and talents.

The phase is purely additive (guard insertions) with one value replacement (hardcoded 60 -> dynamic computation). It introduces zero new code paths. At level 60 with all skills learned and full Furor, the guards never trigger and `RESHIFT_ENERGY` computes to exactly 60 (matching the current hardcoded value), making the execution path byte-for-byte equivalent to the pre-change code.

**Primary recommendation:** Insert `isSpellExist` guards at module entry points and in shared decision functions, replace the hardcoded `RESHIFT_ENERGY = 60` with a dynamic `computeReshiftEnergy()` function, and add selftests verifying both the low-level skip paths and the level-60 equivalence. No structural refactoring needed — this is a targeted guard-layer insertion.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 统一使用模块级 `isSpellExist` guard 模式。每个 catAtk 模块入口检查该模块依赖的核心技能是否存在，不存在则 `return`（静默跳过，继续执行后续模块）。与现有 `reshiftMod`（`cat.lua:177`）模式完全一致。
- **D-02:** 以下模块需加 `isSpellExist` guard:
  - `keepRip` -> Rip
  - `keepRake` -> Rake
  - `keepFF` -> Faerie Fire (Feral)
  - `keepTigerFury` -> Tiger's Fury
  - `termMod` -> Ferocious Bite
  - `openerMod` -> Pounce / Ravage
  - `otMod` -> Cower
  - `regularAttack` -> 通过 `shouldUseShred` 内部 guard 自然降级到 Claw
- **D-03:** `shouldUseShred`、`shouldCastRip`、`shouldUseBite` 等共享决策函数内部也加 `isSpellExist` guard。不存在技能的决策函数直接返回 false，调用链自然 fallback 到 Claw。
- **D-04:** `RESHIFT_ENERGY` 从硬编码 `60`（`Druid.lua:338`）改为动态计算：`Furor天赋rank * 8 + (狼头头盔存在 ? 20 : 0)`。低等级无 Furor 且无狼头时 RESHIFT_ENERGY = 0，`shouldDoReshift` 自动判断"不划算"而不触发 reshift。
- **D-05:** `reshiftMod` 入口的 `isSpellExist('Reshift')` guard 保持不变（`cat.lua:177`），低等级干净跳过整个模块。
- **D-06:** 不做等级感知的 CP 阈值调整。现有 `isTrivialBattleOrPvp` 由战斗时长预判驱动，与角色等级无关。
- **D-07:** 在 `core/selftest.lua` 中添加 catAtk 低等级路径 selftest：技能存在时的正常执行路径验证、技能不存在时各模块正确跳过验证、共享决策函数在技能不存在时返回 false 验证、`RESHIFT_ENERGY` 动态计算正确性验证。
- **D-08:** Planner 需逐点审查所有 guard 插入点，确保无 nil 引用路径、无隐式假设断裂、`getMinimumAffordableAbilityCost` 在技能大量缺失时能正确 fallback 到 Claw。

### Claude's Discretion

- 各模块具体 `isSpellExist` 检查的技能名称（对应 locale 表）
- `RESHIFT_ENERGY` 动态计算函数的具体实现位置（内联 vs 独立函数）
- Selftest 的具体用例数量和覆盖范围
- `shouldCastFFDuringWaitWindow` 是否需要 guard（被 `shouldUseShred` 间接调用）
- Guard 插入的具体代码行位置和格式

### Deferred Ideas (OUT OF SCOPE)

- 低等级专属 rotation 优化
- 能量 tick 计算调整
- 非 Druid 职业练级适配

## Phase Requirements

No specific REQ-IDs assigned yet. This phase primarily serves the implicit constraint of R8 (Druid 猫德逻辑保持) — the level 60 max-DPS path must remain unchanged.

| Implicit Requirement | Description | Research Support |
|---------------------|-------------|------------------|
| R8-PRESERVE | Level 60 catAtk DPS behavior unchanged | All guards are no-op at level 60; RESHIFT_ENERGY computes to exactly 60 |
| LOW-LVL-SKIP | Low-level characters skip unavailable skill modules | `isSpellExist` guard pattern at module entries |
| DYNAMIC-RESHIFT | RESHIFT_ENERGY adapts to talent/gear | `computeReshiftEnergy()` replaces hardcoded 60 |
| DECISION-GUARD | Shared decision functions handle missing skills | `shouldUseShred/shouldCastRip/shouldUseBite` guard fallback |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Skill existence checking | API / Backend (biz_util.lua) | — | `isSpellExist` calls `GetSpellName` via pcall — a WoW API interaction |
| Module dispatch guard | Combat Logic (cat.lua) | — | Module entry points are in the combat logic layer |
| Shared decision guards | Combat Logic (Druid.lua) | — | `shouldUseShred`/`shouldCastRip`/`shouldUseBite` are combat decision functions |
| Dynamic reshift energy | Combat Logic (Druid.lua) | Entity (Player.lua) | Computes from talent ranks and equipped items — Player entity provides the primitives |
| Selftest validation | Test Infrastructure (selftest.lua) | — | Registers new test cases in the existing SelfTest framework |

## Standard Stack

This phase is a pure Lua code change within the existing addon — no external libraries or packages are installed. All infrastructure already exists in the codebase:

### Core (Already Present)
| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| WoW 1.12.1 Lua API | 1.12.1 | Runtime environment | Target platform, cannot change |
| macroTorch.isSpellExist | existing (biz_util.lua:75) | Skill existence check | Already used by reshiftMod and bearReshiftMod |
| macroTorch.SelfTest | existing (core/selftest.lua) | Test framework | Already used by all Druid self-tests |
| player.talentRank | existing (entity/Player.lua:343) | Talent rank query | Already used by computeClaw_E, computeShred_E, etc. |
| player.isItemEquipped | existing (entity/Player.lua:313) | Equipment check | Already used by computeClaw_E, etc. |

### Supporting (Already Present)
| Library/Tool | Version | Purpose | When to Use |
|-------------|---------|---------|-------------|
| build.sh | existing | Build system | Concatenates Lua files in build_order.txt order |
| gsd-tools classify-confidence | existing (project tool) | Confidence classification | For research verification |

**No new packages to install.** This phase modifies 3 existing files (`Druid.lua`, `cat.lua`, `selftest.lua`) with guard insertions and one value replacement.

## Package Legitimacy Audit

No external packages are installed in this phase. This section is intentionally empty.

**Packages removed due to SLOP verdict:** none
**Packages flagged as suspicious SUS:** none

## Architecture Patterns

### System Architecture Diagram

```
Key Press (E key)
       |
       v
  catAtk() entry
       |
       |--[isInCatForm guard]--> return (no action if not in cat form)
       |
       v
  clickContext construction
  (energy costs, durations, ERPS values computed dynamically)
       |
       |--[NEW] RESHIFT_ENERGY = computeReshiftEnergy()  (was: hardcoded 60)
       |
       v
  Module dispatch (sequential, no dependencies between modules)
       |
       |--> idolRecover          [no change — hasItem guard already exists]
       |--> healthManaSaver      [no change]
       |--> targetEnemy          [no change]
       |--> keepAutoAttack       [no change]
       |--> rushMod              [no change]
       |--> openerMod            [NEW: isSpellExist guard — Pounce/Ravage]
       |--> oocMod               [no change — delegates to regularAttack]
       |--> termMod              [NEW: isSpellExist guard — Ferocious Bite]
       |--> otMod                [NEW: isSpellExist guard — Cower]
       |--> keepTigerFury        [NEW: isSpellExist guard — Tiger's Fury]
       |--> debuffMod
       |      |--> keepRip       [NEW: isSpellExist guard — Rip]
       |      |--> keepRake      [NEW: isSpellExist guard — Rake]
       |      |--> keepFF        [NEW: isSpellExist guard — Faerie Fire (Feral)]
       |--> regularAttack        [no module guard — falls through to shouldUseShred]
       |      |--> shouldUseShred [NEW: isSpellExist guard — Shred -> returns false -> Claw]
       |--> reshiftMod           [existing guard kept — isSpellExist('Reshift')]
              |--> shouldDoReshift
                     |--[NEW] RESHIFT_ENERGY == 0 --> return false (skip reshift)
                     |--> getMinimumAffordableAbilityCost
                            |--> shouldUseBite     [NEW: isSpellExist guard — FB]
                            |--> isTigerPresent    [NEW: implicit via keepTigerFury guard]
                            |--> shouldCastRip     [NEW: isSpellExist guard — Rip]
                            |--> isRakePresent     [NEW: implicit via keepRake guard]
                            |--> shouldUseShred    [NEW: guard already applied]
                            |--> fallback to Claw  [always available, level 1 skill]

Legend:
  [no change]  = existing logic, untouched
  [NEW: ...]   = new guard insertion point
  [existing guard kept] = pre-existing isSpellExist, preserved as-is
```

**Data flow through the guard layer:**
1. Each module checks `isSpellExist` for its core skill
2. If skill missing -> `return` (silent skip, next module proceeds)
3. If skill present -> normal execution (identical to pre-change behavior)
4. Shared decision functions in `getMinimumAffordableAbilityCost` chain: each checks its skill, returns false if missing, chain falls through to Claw (level 1 skill, always available)

### Recommended Project Structure

No structural changes. Files remain in current locations:

```
classes/druid/
├── Druid.lua        # catAtk() entry + shared decision functions + RESHIFT_ENERGY
├── cat.lua          # Module implementations + module-level guards
├── bear.lua         # (untouched)
├── utility.lua      # (untouched)
└── combo.lua        # (untouched)
core/
└── selftest.lua     # New low-level selftest registrations
```

### Pattern 1: Module-Level isSpellExist Guard

**What:** Insert `if not macroTorch.isSpellExist(spellName, 'spell') then return end` at the top of each module function entry, before any business logic.

**When to use:** For every catAtk module that depends on a specific skill being learned. Use for `keepRip`, `keepRake`, `keepFF`, `keepTigerFury`, `termMod`, `openerMod`, `otMod`.

**Reference implementation (reshiftMod, cat.lua:177):**
```lua
-- Source: classes/druid/cat.lua:176-185
function macroTorch.reshiftMod(clickContext)
    if not macroTorch.isSpellExist('Reshift', 'spell') then
        return
    end
    -- ... existing reshift logic unchanged ...
end
```

**Applied to keepRip (example):**
```lua
-- Source: adaptation of reshiftMod pattern, classes/druid/cat.lua:210
function macroTorch.keepRip(clickContext)
    -- [NEW GUARD] D-02: skip entire Rip module if spell not learned
    if not macroTorch.isSpellExist('Rip', 'spell') then
        return
    end
    -- Use shared logic to check if Rip should be cast
    if not macroTorch.shouldCastRip(clickContext) then
        return
    end
    -- ... existing Rip logic unchanged ...
end
```

### Pattern 2: Shared Decision Function Guard

**What:** Insert `if not macroTorch.isSpellExist(spellName, 'spell') then return false end` at the top of shared decision functions, before any conditional logic.

**When to use:** For `shouldUseShred`, `shouldCastRip`, `shouldUseBite`. These are called from multiple places (`regularAttack`, `getMinimumAffordableAbilityCost`, `keepRip`, `termMod`, etc.) — one guard covers all call sites.

**shouldUseShred example:**
```lua
-- Source: adaptation of module guard pattern, classes/druid/Druid.lua:705
function macroTorch.shouldUseShred(clickContext)
    -- [NEW GUARD] D-03: Shred not learned -> always prefer Claw
    if not macroTorch.isSpellExist('Shred', 'spell') then
        return false
    end
    -- ... existing bleed count logic unchanged ...
end
```

### Pattern 3: Dynamic RESHIFT_ENERGY Computation

**What:** Replace `clickContext.RESHIFT_ENERGY = 60` with a function call `clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()`.

**When to use:** At `Druid.lua:338` — the single point where RESHIFT_ENERGY is set in clickContext.

**Implementation (Claude's discretion: as independent function in Druid.lua):**
```lua
-- Source: derived from computeClaw_E pattern (Druid.lua:556-564)
-- Place near computeClaw_E / computeShred_E group in Druid.lua
function macroTorch.computeReshiftEnergy()
    local energy = 0
    local player = macroTorch.player
    -- Furor talent: each rank gives +8 energy when reshifting
    -- [ASSUMED] Turtle WoW Furor talent matches vanilla WoW values
    energy = energy + player.talentRank('Furor') * 8
    -- Wolfshead Helm: +20 energy on shapeshift
    -- [ASSUMED] Turtle WoW Wolfshead Helm matches vanilla WoW equip effect
    if player.isItemEquipped('Wolfshead Helm') then
        energy = energy + 20
    end
    return energy
end
```

**Integration into catAtk() (Druid.lua:338):**
```lua
-- Before:
clickContext.RESHIFT_ENERGY = 60
-- After:
clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()
```

**Integration into shouldDoReshift (cat.lua:186):**
```lua
-- [NEW CHECK] D-04: If reshift would give zero energy, skip entirely
-- This naturally occurs at low levels without Furor or Wolfshead Helm
if clickContext.RESHIFT_ENERGY == 0 then
    return false
end
```

### Anti-Patterns to Avoid

- **Do NOT add guard to `regularAttack` directly:** `regularAttack` delegates to `shouldUseShred` which will have its own guard. Adding a module-level guard to `regularAttack` would prevent fallback to Claw for characters who have Claw but not Shred. Claw is learned at level 1 and should always be available.
- **Do NOT guard `oocMod` with isSpellExist:** `oocMod` delegates to `regularAttack` and `cp5Bite` — its behavior is already covered by the guards on those sub-functions.
- **Do NOT guard `keepFF`'s shouldCastFFDuringWaitWindow separately:** This function is called only from `keepFF` which has its own guard. The `getMinimumAffordableAbilityCost` chain inside `shouldCastFFDuringWaitWindow` benefits from the shared decision function guards (D-03).
- **Do NOT add talents/glyphs dependency:** Talent-dependent energy costs are already dynamic via `talentRank()`. Only skill existence (learned/not learned) is the new concern.
- **Do NOT change the RESHIFT_ENERGY usage in `shouldDoReshift`:** The existing comparison logic (`projectedEnergy < minAbilityCost`) is correct. Only add the early-return when `RESHIFT_ENERGY == 0` as an optimization (reshift yields zero energy = never worth the GCD cost).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Skill existence check | Custom spellbook iteration | `macroTorch.isSpellExist(name, bookType)` | Already exists at biz_util.lua:75; uses pcall-wrapped GetSpellName iteration |
| Talent rank query | Custom talent tab scanning | `player.talentRank(talentName)` | Already exists at Player.lua:343; delegates to `macroTorch.getTalentRank` |
| Equipment detection | Custom slot scanning | `player.isItemEquipped(itemName)` | Already exists at Player.lua:313; delegates to `macroTorch.getEquippedItemSlot` |
| Guard clause pattern | New guard abstraction | `if not condition then return end` | Existing reshiftMod/bearReshiftMod pattern; no wrapper needed |

**Key insight:** All infrastructure for this phase already exists. The phase adds guard clauses using existing primitives — no new utility functions or abstractions are needed beyond `computeReshiftEnergy()`.

## Runtime State Inventory

This phase is NOT a rename/refactor/migration phase. It is a logic enhancement (adding guard clauses). Runtime state is not affected — the phase modifies only Lua source files. No database migrations, no service config changes, no OS-registered state updates.

**All categories: None** — Verified by examining phase scope: guard insertions and one value replacement in 3 Lua source files, no runtime state affected.

## Common Pitfalls

### Pitfall 1: Guard breaks the module chain

**What goes wrong:** A module's `return` on skill miss causes subsequent modules to also be skipped, or the module's internal state is left in a bad state for the next invocation.

**Why it happens:** If modules had hidden dependencies (e.g., module A sets clickContext state that module B reads), a guard-induced skip of module A would leave that state uninitialized.

**How to avoid:** The catAtk module chain is already designed with zero inter-module dependencies — each module reads only clickContext (set once at the top of catAtk) and player/target state. The existing `reshiftMod` guard already proves this pattern works. No module after a skipped module depends on state set by the skipped module.

**Warning signs:** A module reads a clickContext field that is only set inside a guarded module above it. Verify by searching for clickContext field writes in each guarded module and reads in subsequent modules.

### Pitfall 2: shouldUseShred guard prevents Claw fallback

**What goes wrong:** The `shouldUseShred` guard returns false when Shred is unavailable, which causes `regularAttack` to fall through to Claw — this is correct. But if `regularAttack` had a separate guard that also returns early, characters without Claw would have no attack at all.

**Why it happens:** Over-guarding — adding a guard at both the decision function AND the module level when only one is needed.

**How to avoid:** Guard at the decision function level only (`shouldUseShred`). Do NOT add a module guard on `regularAttack`. Claw is available from level 1 and should always be reachable.

**Warning signs:** `regularAttack` has an `isSpellExist` guard that also checks Claw.

### Pitfall 3: RESHIFT_ENERGY calculation uses wrong Furor talent name

**What goes wrong:** `player.talentRank('Furor')` returns 0 because the talent name string doesn't match the actual name in Turtle WoW's localization. The dynamic value silently becomes 0, disabling reshift even at level 60.

**Why it happens:** Talent names are locale-dependent and may differ between vanilla WoW, Turtle WoW, and classic WoW. The `getTalentRank` function (`biz_util.lua:293`) iterates `GetTalentInfo` and matches by exact string comparison.

**How to avoid:** The CONTEXT.md spec already notes: "planner 需确认 Turtle WoW 中该天赋的准确英文名". The planner must verify the exact talent name string. If the name differs from 'Furor', the code must use the correct string.

**Warning signs:** At level 60 with full Furor talent, `computeReshiftEnergy()` returns 0 instead of 40 (or 60 with Wolfshead Helm).

### Pitfall 4: No guard on cp5Bite/oocMod causes nil reference on missing Bite

**What goes wrong:** `oocMod` (cat.lua:147) calls `cp5Bite` when combo points reach 5, and `cp5Bite` (cat.lua:97) calls `player.ferocious_bite('raw')`. If Ferocious Bite is not learned, `_castSpell` handles this gracefully via pcall, but the energy pre-checks still execute pointlessly.

**Why it happens:** The guard is on `termMod`, but `cp5Bite` is also called from `oocMod`.

**How to avoid:** `_castSpell` already uses pcall internally. The `player.isSpellReady('Ferocious Bite')` check in `readyBite` will return false. The system degrades gracefully without a guard on `cp5Bite`. Adding a guard to `cp5Bite` is defensive but unnecessary — the existing pcall chain handles it.

**Warning signs:** Lua errors in `cp5Bite` when Ferocious Bite is n

## Code Examples

### Complete Guard Insertion Map

```
Module / Function        | File        | Line  | Guard Spell             | Guard Type
-------------------------|-------------|-------|-------------------------|------------
reshiftMod               | cat.lua     | 177   | 'Reshift'              | EXISTING — keep
openerMod                | cat.lua     | N/A   | 'Pounce' (primary)     | NEW — module level
                         |             |       | 'Ravage' (secondary)   | check both
termMod -> cp5Bite       | cat.lua     | 92    | 'Ferocious Bite'       | NEW — module level
otMod                    | cat.lua     | 63    | 'Cower'                | NEW — module level
keepTigerFury            | cat.lua     | 203   | "Tiger's Fury"         | NEW — module level
keepRip                  | cat.lua     | 210   | 'Rip'                  | NEW — module level
keepRake                 | cat.lua     | 279   | 'Rake'                 | NEW — module level
keepFF                   | cat.lua     | 290   | 'Faerie Fire (Feral)'  | NEW — module level
shouldUseShred           | Druid.lua   | 705   | 'Shred'                | NEW — decision fn
shouldCastRip            | Druid.lua   | 987   | 'Rip'                  | NEW — decision fn
shouldUseBite            | Druid.lua   | 1008  | 'Ferocious Bite'       | NEW — decision fn
RESHIFT_ENERGY           | Druid.lua   | 338   | N/A (dynamic compute)  | REPLACE — value -> fn
```

**Spell names match the English locale strings used in `_castSpell` definitions** (Druid.lua:25-203). All verified against the existing codebase.

### shouldCastFFDuringWaitWindow Guard Decision

`shouldCastFFDuringWaitWindow` (Druid.lua:923) is called only from `keepFF` (cat.lua:290-294). Since `keepFF` now has an `isSpellExist('Faerie Fire (Feral)')` guard, `shouldCastFFDuringWaitWindow` is never reached when FF is unavailable. Additionally, `shouldCastFFDuringWaitWindow` already checks `macroTorch.target.isImmune('Faerie Fire (Feral)')` as its first substantive condition.

**Recommendation:** No separate guard needed on `shouldCastFFDuringWaitWindow` — covered by `keepFF`'s module guard. (Claude's discretion, confirmed by analysis.)

### openerMod Guard Strategy

The `openerMod` (currently inline in catAtk at Druid.lua:383-392, not extracted to cat.lua) checks two skills:

```lua
-- Druid.lua:383-392 (inline in catAtk)
if clickContext.prowling then
    if not target.isImmune('Pounce') and target.health >= 1500 then
        -- ... use Pounce ...
    else
        player.ravage('ready')  -- fallback: Ravage
    end
end
```

**Guard strategy:** Add check before the prowling block:
```lua
-- [NEW GUARD] D-02: skip opener module if neither opener skill is available
local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
if clickContext.prowling then
    if hasPounce and not target.isImmune('Pounce') and target.health >= 1500 then
        -- ... Pounce ...
    elseif hasRavage then
        player.ravage('ready')
    end
    -- else: no opener available, silently skip
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded RESHIFT_ENERGY = 60 | Dynamic `computeReshiftEnergy()` | Phase 13 | Low-level chars without Furor/Wolfshead correctly skip reshift |
| No skill checks in modules | `isSpellExist` guard at module entry | Phase 13 | Low-level chars skip unavailable skills, 60 behavior unchanged |
| No guard in decision functions | `isSpellExist` guard returns false | Phase 13 | `getMinimumAffordableAbilityCost` chain naturally falls back to Claw |

**Deprecated/outdated:**
- `RESHIFT_ENERGY = 60` hardcoded value — replaced by dynamic computation. The value 60 is only correct for a max-level character with 5/5 Furor and Wolfshead Helm equipped.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Turtle WoW Furor talent name is exactly "Furor" in English locale | Architecture Patterns / Common Pitfalls | `talentRank('Furor')` returns 0, reshift energy stays at 0, reshift never triggers |
| A2 | Turtle WoW Furor talent provides +8 energy per rank (max 5 ranks = 40) | Architecture Patterns | Incorrect energy computation, reshift yields wrong amount |
| A3 | Turtle WoW Wolfshead Helm item name is exactly "Wolfshead Helm" | Architecture Patterns | `isItemEquipped('Wolfshead Helm')` returns false at level 60 |
| A4 | Turtle WoW Wolfshead Helm provides +20 energy on shapeshift | Architecture Patterns | Reshift energy short by 20 at level 60 |
| A5 | Claw is a level 1 skill available to all druids | Architecture Patterns | If Claw requires a specific level, the fallback chain could break for very low level characters |
| A6 | `isSpellExist` spell name parameters match the English locale spell names used in Druid.lua `_castSpell` definitions | Code Examples | Guards never trigger, broken low-level behavior |

**Note:** All assumptions marked [ASSUMED] are based on established vanilla WoW 1.12.1 mechanics from training knowledge, cross-referenced against the codebase's own documentation and existing implementation patterns. The CONTEXT.md file independently confirms the Furor and Wolfshead Helm values. The risk is low but planner should verify with user if any Turtle WoW modifications affect these values.

## Open Questions

1. **Furor talent exact name in Turtle WoW**
   - What we know: Vanilla WoW 1.12.1 uses "Furor" for the Druid Restoration talent that grants energy/rage on shapeshift. The codebase uses talent names like 'Ferocity', 'Blood Frenzy', 'Improved Shred', 'Ancient Brutality' for other talents.
   - What's unclear: Whether Turtle WoW modified the talent name or mechanics.
   - Recommendation: Plannner should verify with user or test in-game. If the name differs, update the string in `computeReshiftEnergy()`.

2. **Wolfshead Helm exact item name in Turtle WoW**
   - What we know: Vanilla WoW uses "Wolfshead Helm" (item ID 8345). The item provides +20 energy when shapeshifting.
   - What's unclear: Whether Turtle WoW changed the item name or the bonus behavior.
   - Recommendation: Planner should verify the item name string. The `isItemEquipped` function matches by substring comparison in `getEquippedItemLink`, so partial matches may work, but exact match is safer.

3. **Is RESHIFT_ENERGY currently used anywhere besides being set?**
   - What we know: Grep search shows `RESHIFT_ENERGY` is only set at `Druid.lua:338` and never read anywhere in the codebase. The `shouldDoReshift` function uses `projectedEnergy < minAbilityCost` comparison without referencing `RESHIFT_ENERGY`.
   - What's unclear: Whether the user intends for `RESHIFT_ENERGY` to be incorporated into `shouldDoReshift` decision logic, or if setting it dynamically is purely for informational purposes.
   - Recommendation: Per D-04, add an early return `if clickContext.RESHIFT_ENERGY == 0 then return false end` at the top of `shouldDoReshift`. This is the simplest interpretation of "shouldDoReshift 自动判断不划算" and preserves the existing logic for non-zero values.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | build.sh | yes | 3.2.57 | — |
| node | gsd-tools | yes | 22.17.0 | — |
| lua | (optional: syntax checking) | yes | 5.4.7 | Not required for build |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

*Note: This phase only modifies 3 Lua source files. Build verification uses the existing `build.sh` script. WoW 1.12.1 runtime testing requires an in-game environment, which is outside the scope of automated CI.*

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (custom, built-in) |
| Config file | none — SelfTest registrations are code-inline |
| Quick run command | N/A (in-game: login triggers SelfTest:run() on PLAYER_ENTERING_WORLD) |
| Full suite command | N/A (same as quick run — all tests run on login) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOW-LVL-SKIP | Low-level chars skip Rip/Rake/FF/TF/FB/Cower modules | unit (selftest) | N/A (in-game) | Wave 0 |
| DECISION-GUARD | shouldUseShred returns false when Shred unlearned | unit (selftest) | N/A (in-game) | Wave 0 |
| DECISION-GUARD | shouldCastRip returns false when Rip unlearned | unit (selftest) | N/A (in-game) | Wave 0 |
| DECISION-GUARD | shouldUseBite returns false when FB unlearned | unit (selftest) | N/A (in-game) | Wave 0 |
| DYNAMIC-RESHIFT | computeReshiftEnergy returns 0 when no Furor + no helm | unit (selftest) | N/A (in-game) | Wave 0 |
| R8-PRESERVE | Full level 60 setup: all guards pass through, RESHIFT_ENERGY == 60 | unit (selftest) | N/A (in-game) | Wave 0 |

### Sampling Rate
- **Per task commit:** `./build.sh` (verify SM_Extend.lua generation succeeds)
- **Per wave merge:** `./build.sh` + manual in-game test
- **Phase gate:** All selftests pass + manual level 60 verification

### Wave 0 Gaps
- [ ] `core/selftest.lua` — needs new test registrations for catAtk low-level paths
- [ ] No existing test for RESHIFT_ENERGY behavior
- [ ] No existing test for module guard behavior in catAtk context

*Note: All selftests are `isOptional = true` (matching existing Druid tests), since they require in-game execution. They are not runnable in CI.*

## Security Domain

Security enforcement is not explicitly disabled in config. However, this phase involves only Lua guard clause insertions — no user input handling, no authentication, no network communication, no cryptography. The following assessment is provided for completeness.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | N/A |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | no | All WoW API inputs are handled by existing pcall wrappers |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for WoW Lua Addon

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Lua error crash from nil dereference | Denial of Service | Guard clauses prevent execution paths that would access non-existent skills |
| Infinite loop in spellbook iteration | Denial of Service | `isSpellExist` uses bounded while-true with break condition |

## Sources

### Primary (HIGH confidence)
- **Codebase source files** — `classes/druid/Druid.lua` (1308 lines), `classes/druid/cat.lua` (390 lines), `biz_util.lua`, `entity/Player.lua`, `core/selftest.lua` — all directly read and analyzed for existing patterns, function signatures, and integration points.
- **13-CONTEXT.md** — User decisions D-01 through D-08 with precise specifications for guard placement, RESHIFT_ENERGY computation, and test strategy.

### Secondary (MEDIUM confidence)
- **Codebase .claude/CLAUDE.md** — Project architecture documentation confirming metatable chain, module execution model, and implementation principles.
- **Prior phase context documents** — Phase 5, 6, 7, and 10 CONTEXT.md files confirming architectural patterns used throughout the Druid implementation.

### Tertiary (LOW confidence)
- **WebSearch for Furor/Wolfshead Helm details** — Web searches for Turtle WoW-specific talent/item mechanics returned empty results (wowhead.com/fandom.com blocked automated access). Values used are from training knowledge of vanilla WoW 1.12.1, cross-referenced against CONTEXT.md's own documentation of these mechanics.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all infrastructure already exists in the codebase, verified by direct code reading
- Architecture: HIGH — guard pattern already established by reshiftMod, module structure documented in CLAUDE.md and prior phases
- Pitfalls: MEDIUM — potential issues with talent name strings and item name strings flagged for user verification

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (30 days — WoW 1.12.1 API is stable, but talent/item name verification with user may surface updates)