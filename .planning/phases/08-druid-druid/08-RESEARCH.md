# Phase 08: 非Druid职业代码结构重构（对齐Druid架构） - Research

**Researched:** 2026-06-15
**Domain:** WoW 1.12.1 addon code architecture refactoring -- Lua OOP class restructuring, skill method encapsulation, file directory reorganization
**Confidence:** HIGH

## Summary

Phase 08 will refactor all 6 non-Druid class files (Hunter, Warrior, Rogue, Mage, Priest, Warlock) to align with the Druid architecture established in Phases 5-7. Each class will get its own subdirectory under `classes/`, a full class definition using `classMetatable` + `FIELD_FUNC_MAP` + `registerPlayerClass`, skill methods with multi-locale support, and `SpellTrace:register` / `SelfTest:register` integration.

These classes' combat logic is **not currently in use** in-game -- this gives maximum freedom to restructure without risk of breaking live functionality. The refactoring is purely architectural alignment and code modernization.

**Primary recommendation:** Execute as a single wave with 6 parallel per-class tasks (one per class directory). Each class task follows the identical Druid-aligned pattern: create subdirectory, split content into skill-definition file + combat-logic file(s), replace `CastSpellByName` with skill methods, add class definition boilerplate, update `build_order.txt`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Class definition (metatable, FIELD_FUNC_MAP) | Classes layer | -- | `classes/<class>/<Class>.lua` -- aligns with `classes/druid/Druid.lua` |
| Skill method definitions | Classes layer | Entity layer (Player base) | Method closures in constructor call `obj._castSpell()` from Player base |
| Combat rotation logic | Classes layer | -- | `classes/<class>/combat.lua` or dimension-specific files |
| Spell trace registration | Classes layer | Core layer | `SpellTrace:register()` in skill-definition file, same as Druid |
| Self test registration | Classes layer | Core layer | `SelfTest:register()` in skill-definition file, same as Druid |
| Polymorphic player init | Core layer | Classes layer | `registerPlayerClass()` in class definition, `initPlayer()` in `core/class.lua` |
| Build order | Build system | -- | `build_order.txt` flat listing; new subdirectory paths replace old flat paths |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `core/class.lua` | current | `classMetatable(cls, fieldMapName)` factory, `registerPlayerClass()`, `initPlayer()` | Phase 1 infrastructure, all classes use it [VERIFIED: codebase] |
| `entity/Player.lua` | current | `_castSpell(localeNames, mode, range, resourceCost, onSelf)`, `_isInRange`, `_hasResource`, `cast`, `isSpellReady` | Phase 5 infrastructure, all skill methods delegate to it [VERIFIED: codebase] |
| `core/spell_trace_core.lua` | current | `SpellTrace:register(name, config)` declarative API | Phase 3 infrastructure [VERIFIED: codebase] |
| `core/selftest.lua` | current | `SelfTest:register(name, fn, isOptional)` framework | Phase 3 infrastructure [VERIFIED: codebase] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `biz_util.lua` | current | `castIfBuffAbsent`, `isSpellCooledDown`, item/equipment utilities | Required for Warlock/Priest/Mage/Warrior buff management that currently uses `castIfBuffAbsent` [VERIFIED: codebase] |
| `macro_torch.lua` | current | Global namespace `macroTorch`, `macroTorch.toBoolean` | Required by all files [VERIFIED: codebase] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CastSpellByName` (current) | `_castSpell` skill methods | Skill methods provide locale support, mode-based readiness checks, and consistent API -- Druid standard [VERIFIED: codebase] |
| Flat single-file (current) | Multi-file subdirectory | Aligns with Druid architecture, better maintainability [CITED: ROADMAP.md Phase 4] |

**Installation:** No external packages needed. This is a pure internal codebase refactoring.

## Package Legitimacy Audit

No external packages are installed in this phase. This is a pure code structure refactoring within the existing Lua codebase.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Current State (non-Druid classes):
  classes/Hunter.lua (205 lines, flat single file)
  classes/Warrior.lua (210 lines, flat single file)
  classes/Rogue.lua (150 lines, flat single file)
  classes/Mage.lua (81 lines, flat single file)
  classes/Priest.lua (111 lines, flat single file)
  classes/Warlock.lua (92 lines, flat single file)

                    v (refactored to)

Target State (aligned with Druid):
  classes/druid/                   [REFERENCE -- already complete]
    Druid.lua     (1310 lines)     Class definition, FIELD_FUNC_MAP, ~40 skill methods, constants, helpers, registerPlayerClass, SpellTrace, SelfTest
    cat.lua       (387 lines)      catAtk + 13 modules (priority-ordered)
    bear.lua      (146 lines)      bearAtk + bear modules
    utility.lua   (89 lines)       druidBuffs, druidStun, druidDefend, druidControl, pokemonLoad

  classes/hunter/                  [NEW]
    Hunter.lua    (~200 lines)     Class definition, HUNTER_FIELD_FUNC_MAP, ~13 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~130 lines)     hunterAtk + combat modules (htOtMod, safe/ready functions)
    utility.lua   (~40 lines)      hunterSting, hunterCtrl

  classes/warrior/                 [NEW]
    Warrior.lua   (~250 lines)     Class definition, WARRIOR_FIELD_FUNC_MAP, ~15 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~300 lines)     wroAtk + all combat functions (melee/ranged/control/defense)
    utility.lua   (~80 lines)      wroBuffs, wroDebuffs, wroCtrl, wroInterrupt, warDefence

  classes/rogue/                   [NEW]
    Rogue.lua     (~200 lines)     Class definition, ROGUE_FIELD_FUNC_MAP, ~12 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~200 lines)     rogueAtk + rogueAtkBack + battle functions + vanish

  classes/mage/                    [NEW]
    Mage.lua      (~180 lines)     Class definition, MAGE_FIELD_FUNC_MAP, ~8 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~80 lines)      mageAtk + mageRangedAtk + mageMeleeAtk
    utility.lua   (~40 lines)      mageBuffs, mageCtrl

  classes/priest/                  [NEW]
    Priest.lua    (~180 lines)     Class definition, PRIEST_FIELD_FUNC_MAP, ~10 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~90 lines)      priestAtk + priestRangedAtk
    utility.lua   (~70 lines)      priestBuffs, priestDebuffs, priestCtrl, priestHeal

  classes/warlock/                 [NEW]
    Warlock.lua   (~180 lines)     Class definition, WARLOCK_FIELD_FUNC_MAP, ~8 skill methods, constants, registerPlayerClass, SpellTrace, SelfTest
    combat.lua    (~80 lines)      wlkAtk + wlkRangedAtk + wlkMeleeAtk
    utility.lua   (~50 lines)      wlkCurses, wlkBuffs, wlkCtrl
```

### Recommended Project Structure

```
classes/
├── druid/                     # [REFERENCE -- complete, no changes]
│   ├── Druid.lua              # Class definition + skill methods + constants + helpers + register + SpellTrace + SelfTest
│   ├── cat.lua                # catAtk + 13 combat modules (priority-ordered)
│   ├── bear.lua               # bearAtk + bear modules
│   └── utility.lua            # druidBuffs, druidStun, druidDefend, druidControl, pokemonLoad
├── hunter/                    # [NEW]
│   ├── Hunter.lua             # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
│   ├── combat.lua             # hunterAtk + combat modules
│   └── utility.lua            # hunterSting, hunterCtrl
├── warrior/                   # [NEW]
│   ├── Warrior.lua            # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
│   ├── combat.lua             # wroAtk + all combat functions
│   └── utility.lua            # wroBuffs, wroDebuffs, wroCtrl, wroInterrupt, warDefence
├── rogue/                     # [NEW]
│   ├── Rogue.lua              # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
│   └── combat.lua             # rogueAtk, rogueAtkBack, rogueSneak, rogueBattle, readyVanish
├── mage/                      # [NEW]
│   ├── Mage.lua               # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
│   ├── combat.lua             # mageAtk + mageRangedAtk + mageMeleeAtk
│   └── utility.lua            # mageBuffs, mageCtrl
├── priest/                    # [NEW]
│   ├── Priest.lua             # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
│   ├── combat.lua             # priestAtk + priestRangedAtk
│   └── utility.lua            # priestBuffs, priestDebuffs, priestCtrl, priestHeal
└── warlock/                   # [NEW]
    ├── Warlock.lua            # Class definition + skill methods + FIELD_FUNC_MAP + register + SpellTrace + SelfTest
    ├── combat.lua             # wlkAtk + wlkRangedAtk + wlkMeleeAtk
    └── utility.lua            # wlkCurses, wlkBuffs, wlkCtrl
```

### Pattern 1: Class Definition File (e.g., `Hunter.lua`)

**What:** The "main" file for each class directory. Contains the class prototype, constructor with skill methods, FIELD_FUNC_MAP, singleton instantiation, registerPlayerClass, SpellTrace:register, and SelfTest:register.

**Structure (must follow this exact order):**
```lua
--[[ License block ]] --
---职业专用 start---
-- 1. Class prototype (inherit from Player)
macroTorch.Hunter = macroTorch.Player:new()

-- 2. Constructor with skill methods
function macroTorch.Hunter:new()
    local obj = {}
    setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only
    function obj.raptor_strike(mode)
        return obj._castSpell({en='Raptor Strike', zh='猛禽一击'}, mode, nil, nil, false)
    end
    function obj.mongoose_bite(mode)
        return obj._castSpell({en='Mongoose Bite', zh='猫鼬撕咬'}, mode, nil, nil, false)
    end
    function obj.arcane_shot(mode)
        return obj._castSpell({en='Arcane Shot', zh='奥术射击'}, mode, nil, nil, false)
    end
    -- ... more skills ...

    -- Type B skills: self target only
    function obj.hunters_mark(mode)
        return obj._castSpell({en="Hunter's Mark", zh='猎人印记'}, mode, nil, nil, true)
    end

    -- Type C skills: flexible target (rare in non-Druid)

    return obj
end

-- 3. FIELD_FUNC_MAP
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props
    -- conditional props (initially empty or with class-specific computed fields)
}

-- 4. Singleton instantiation
macroTorch.hunter = macroTorch.Hunter:new()

-- 5. Polymorphic registration
macroTorch.registerPlayerClass("Hunter", macroTorch.Hunter)

-- 6. Spell trace registration (extract from existing setTraceSpellImmune calls)
macroTorch.SpellTrace:register('Serpent Sting', {
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})

-- 7. Self-test registrations
macroTorch.SelfTest:register("Hunter: HUNTER_FIELD_FUNC_MAP exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.HUNTER_FIELD_FUNC_MAP) == "table", "HUNTER_FIELD_FUNC_MAP not a table")
end, true)

macroTorch.SelfTest:register("Hunter: singleton hunter exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter) == "table", "macroTorch.hunter not a table")
end, true)

macroTorch.SelfTest:register("Hunter: skill method raptor_strike exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.raptor_strike) == "function", "raptor_strike not function")
end, true)
-- ... per skill method ...
```

**When to use:** This is the entry point for each class directory. Always the first file in `build_order.txt` for that class.

### Pattern 2: Combat Logic File (e.g., `combat.lua`)

**What:** Contains the main combat entry function and all combat modules. Replaces raw `CastSpellByName` calls with skill method calls.

**Structure:**
```lua
--[[ License block ]] --
-- Hunter combat rotation functions

-- Main entry point
function macroTorch.hunterAtk()
    local player = macroTorch.player
    local target = macroTorch.target
    local pet = macroTorch.pet
    local clickContext = {}
    -- energy/mana costs
    clickContext.RAPTOR_E = 32
    -- ...
    player.targetEnemy()
    if target.isCanAttack then
        pet.attack()
        macroTorch.htOtMod(clickContext)
        if target.distance < 8 then
            player.startAutoAtk()
            -- Replace: macroTorch.safeMongooseBite(clickContext)
            -- With: player.mongoose_bite('safe')
            if player.mana >= clickContext.MONGOOSE_E then
                player.mongoose_bite()
            end
            -- Replace: macroTorch.safeRaptorStrike(clickContext)
            -- With: player.raptor_strike('safe')
            if player.mana >= clickContext.RAPTOR_E then
                player.raptor_strike()
            end
        else
            -- ranged logic: skill method calls
            player.hunters_mark()
            player.startAutoShoot()
            player.arcane_shot('safe')
            player.multi_shot('safe')
        end
    end
end

-- Module functions (otMod, etc.)
function macroTorch.htOtMod(clickContext)
    -- ... existing logic with player.cast() -> skill methods
end
```

**When to use:** For the combat rotation code, separated from class definition.

### Pattern 3: Utility File (e.g., `utility.lua`)

**What:** Contains buff management, control abilities, stuns, and non-rotation utility functions.

**Structure:**
```lua
--[[ License block ]] --
-- Hunter utility functions

function macroTorch.hunterSting()
    local player = macroTorch.player
    local target = macroTorch.target
    if not target.buffed('Serpent Sting') and not target.isImmune('Serpent Sting') then
        player.serpent_sting('ready')
    end
end

function macroTorch.hunterCtrl()
    if macroTorch.target.distance < 8 then
        macroTorch.player.wing_clip('ready')
    else
        macroTorch.player.concussive_shot('ready')
    end
end
```

**When to use:** For utility functions that are not part of the main combat rotation.

### Anti-Patterns to Avoid

- **Mixing skill definitions with combat logic:** Skill methods go in the ClassDefinition.lua file, combat modules go in combat.lua. Do not intermix -- this is the core separation that Druid establishes. [VERIFIED: codebase]
- **Hardcoding CastSpellByName after refactoring:** All spell casts should use skill methods via `obj._castSpell()`. The only exception is `castIfBuffAbsent` which is a higher-level utility function. [CITED: Phase 5 D-01]
- **Using colon syntax:** All method definitions and calls must use dot syntax (`obj.method()`) per Phase 6 D-01. [VERIFIED: codebase]
- **Skipping registerPlayerClass:** Every class must register in PLAYER_CLASS_REGISTRY for initPlayer() to work correctly. [VERIFIED: codebase]
- **File naming inconsistency:** Use lowercase for files within a class directory (matching Druid's `cat.lua`, `bear.lua`, `utility.lua`). [CITED: CONTEXT.md D-07]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Metatable + __index setup | Manual `setmetatable(obj, {__index = function...})` | `macroTorch.classMetatable(self, "XXX_FIELD_FUNC_MAP")` | Phase 1 factory -- uniform, tested, eliminates ~9 lines of boilerplate per class [VERIFIED: codebase] |
| Spell casting with locale support | `CastSpellByName(spellName)` with hardcoded name | `obj._castSpell({en='...', zh='...'}, mode, range, cost, onSelf)` | Phase 5 infrastructure -- provides locale selection, readiness check, distance check, resource check in one call [VERIFIED: codebase] |
| Spell trace registration | `setSpellTracing` + `setTraceSpellImmune` call pairs | `macroTorch.SpellTrace:register(name, config)` | Phase 3 declarative API -- single call replaces two [VERIFIED: codebase] |
| Self-test case management | Inline checks scattered in code | `macroTorch.SelfTest:register(name, fn, isOptional)` | Phase 3 framework -- pcall isolation, summary output, optional/core distinction [VERIFIED: codebase] |

**Key insight:** The Druid classes/druid/ directory defines a complete, battle-tested structural pattern. The correct approach is to replicate this pattern exactly -- same file organization, same method signatures, same registration calls -- adapting only class-specific content (skill names, constants, combat logic). Do not invent new patterns or deviate from the established structure.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 有明确拆分维度的职业 → 多文件拆分，类比 Druid 的 cat.lua/bear.lua（如战士的姿态、猎人的近战/远程、法师的天赋类型等）。目前看不出明确维度的职业 → 默认 2 文件模式：职业基础逻辑（类定义 + 常量 + FIELD_FUNC_MAP + 技能方法 + 注册）+ 战斗逻辑（主入口 + 模块）。
- **D-02:** 拆分由 planner 逐职业判断，不要求统一文件数。拆分维度的选择应反映该职业在 WoW 1.12.1 中的核心 gameplay 区分（stance/spec/range）。
- **D-03:** 为所有 5 个缺失类定义的职业（Warrior/Mage/Priest/Rogue/Warlock）创建完整的类定义架构，对齐 Druid/Hunter 标准。
- **D-04:** Hunter 已有类定义和 `HUNTER_FIELD_FUNC_MAP`，补齐缺失部分：`registerPlayerClass` + `SpellTrace:register` + `SelfTest:register`。
- **D-05:** 全面对齐 Druid Phase 5-7 建立的模式：`CastSpellByName` → `player.cast()` / `_castSpell` 技能方法，多语言支持，`SpellTrace:register()`，`SelfTest:register()`。
- **D-06:** 技能方法签名遵循 Phase 5 D-06/D-07 的类型分类（Type A 敌方 / Type B 自身 / Type C 灵活），resourceCost 支持数字和函数引用。
- **D-07:** 每个非 Druid 职业建立独立子目录，深度与 `classes/druid/` 一致。原有 `classes/Xxx.lua` 扁平文件删除。

### Claude's Discretion

- 逐职业的文件拆分边界（哪些职业按什么维度拆分、拆几个文件）
- 每个职业的技能方法清单（从现有 CastSpellByName 调用点提取）
- 每个职业的 FIELD_FUNC_MAP 初始内容
- SpellTrace/SelfTest 注册的具体实现
- Hunter 类是否需要从单文件拆分为多文件（当前仅 205 行但已具备类结构）
- 文件内代码组织顺序和注释风格
- 中文技能名的英文翻译（如 Rogue 的 偷窃→Pick Pocket、出血→Hemorrhage 等）

### Deferred Ideas (OUT OF SCOPE)

- **非 Druid 职业战斗逻辑完善**: 当前 Phase 8 仅做架构对齐和代码现代化（结构+API），不完善实际战斗逻辑。
- **Warrior Stance 切换逻辑**: 当前 `wroAtk` 中有 `CastShapeshiftForm(mainStanceIdx)` 调用。未来可参照 Druid isInCatForm/isInBearForm 模式添加语义化 Stance 方法。
- **Hunter/Mage/Priest/Warlock 天赋系统**: 当前代码无天赋检测，未来可参照 Druid Ancient Brutality 模式添加。
- **宠物系统统一**: Hunter/Warlock/Mage 都有宠物相关代码，未来可考虑统一宠物管理接口。

## Per-Class Decomposition Analysis

### Hunter (当前 205 行, 已有类定义)

**拆分建议: 3 文件（Claude's Discretion）**

Hunter 当前已有 `classMetatable` + `HUNTER_FIELD_FUNC_MAP`，但缺少 `registerPlayerClass`、`SpellTrace:register`、`SelfTest:register`。代码有明确的近战/远程拆分维度。

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/hunter/Hunter.lua` | ~200 | 类定义、~13 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register(Serpent Sting)、SelfTest:register |
| `classes/hunter/combat.lua` | ~130 | hunterAtk 主入口 + htOtMod + safe/ready 函数（转为技能方法调用） |
| `classes/hunter/utility.lua` | ~40 | hunterSting、hunterCtrl |

**技能方法清单（从现有调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `raptor_strike` | `player.cast('Raptor Strike')` | `{en='Raptor Strike', zh='猛禽一击'}` | A | nil (近战) | nil |
| `mongoose_bite` | `player.cast('Mongoose Bite')` | `{en='Mongoose Bite', zh='猫鼬撕咬'}` | A | nil | nil |
| `arcane_shot` | `player.cast('Arcane Shot')` | `{en='Arcane Shot', zh='奥术射击'}` | A | nil | nil |
| `multi_shot` | `player.cast('Multi-Shot')` | `{en='Multi-Shot', zh='多重射击'}` | A | nil | nil |
| `disengage` | `player.cast('Disengage')` | `{en='Disengage', zh='逃脱'}` | B | nil | nil |
| `hunters_mark` | `player.cast("Hunter's Mark")` | `{en="Hunter's Mark", zh='猎人印记'}` | A | nil | nil |
| `serpent_sting` | `player.cast('Serpent Sting')` | `{en='Serpent Sting', zh='毒蛇钉刺'}` | A | nil | nil |
| `wing_clip` | `player.cast('Wing Clip')` | `{en='Wing Clip', zh='摔绊'}` | A | nil | nil |
| `concussive_shot` | `player.cast('Concussive Shot')` | `{en='Concussive Shot', zh='震荡射击'}` | A | nil | nil |
| `call_pet` | `obj.callPet()` (已有) | `{en='Call Pet', zh='召唤宠物'}` | B | nil | nil |
| `dismiss_pet` | `obj.callPet()` (已有) | `{en='Dismiss Pet', zh='解散宠物'}` | B | nil | nil |

### Warrior (当前 210 行, 无类定义)

**拆分建议: 3 文件（Claude's Discretion）**

Warrior 有明确的姿态系统（Battle/Defensive/Berserker Stance），但当前代码已按功能维度（近战/远程/AOE/buff/control/defense）组织而非按姿态拆分。由于战斗逻辑目前不使用，按功能拆分更实用。

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/warrior/Warrior.lua` | ~250 | 类定义、~15 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register、SelfTest:register |
| `classes/warrior/combat.lua` | ~300 | wroAtk + wroMeleeAtk + wroRangedAtk + wroAoe + meleeCommonTactics + tmpCharge |
| `classes/warrior/utility.lua` | ~80 | wroBuffs + wroDebuffs + wroCtrl + wroInterrupt + warDefence |

**技能方法清单（从现有 CastSpellByName 调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `throw` | `CastSpellByName('Throw')` | `{en='Throw', zh='投掷'}` | A | nil | nil |
| `taunt` | `CastSpellByName('Taunt')` | `{en='Taunt', zh='嘲讽'}` | A | nil | nil |
| `revenge` | `CastSpellByName('Revenge')` | `{en='Revenge', zh='复仇'}` | A | nil | nil |
| `rend` | 通过 `castIfBuffAbsent` | `{en='Rend', zh='撕裂'}` | A | nil | nil |
| `sunder_armor` | `CastSpellByName('Sunder Armor')` | `{en='Sunder Armor', zh='破甲攻击'}` | A | nil | nil |
| `shield_slam` | `CastSpellByName('Shield Slam')` | `{en='Shield Slam', zh='盾牌猛击'}` | A | nil | nil |
| `demoralizing_shout` | 通过 `castIfBuffAbsent` | `{en='Demoralizing Shout', zh='挫志怒吼'}` | A | nil | nil |
| `thunder_clap` | 通过 `castIfBuffAbsent` | `{en='Thunder Clap', zh='雷霆一击'}` | A | nil | nil |
| `cleave` | `CastSpellByName('Cleave')` | `{en='Cleave', zh='顺劈斩'}` | A | nil | nil |
| `shield_block` | 通过 `castIfBuffAbsent` | `{en='Shield Block', zh='盾牌格挡'}` | B | nil | nil |
| `battle_shout` | 通过 `castIfBuffAbsent` | `{en='Battle Shout', zh='战斗怒吼'}` | B | nil | nil |
| `bloodrage` | `CastSpellByName('Bloodrage')` | `{en='Bloodrage', zh='血性狂暴'}` | B | nil | nil |
| `charge` | `CastSpellByName('Charge')` | `{en='Charge', zh='冲锋'}` | A | nil | nil |
| `hamstring` | `CastSpellByName('Hamstring')` | `{en='Hamstring', zh='断筋'}` | A | nil | nil |
| `shield_bash` | `CastSpellByName('Shield Bash')` | `{en='Shield Bash', zh='盾击'}` | A | nil | nil |
| `disarm` | `CastSpellByName('Disarm')` | `{en='Disarm', zh='缴械'}` | A | nil | nil |
| `shield_wall` | `CastSpellByName('Shield Wall')` | `{en='Shield Wall', zh='盾墙'}` | B | nil | nil |

**特殊处理:**
- `CastShapeshiftForm(mainStanceIdx)` -- 保留原样（姿态切换），不转为技能方法。这是 WoW API 调用而非 spell cast。
- `Battle Stance` / `Defensive Stance` 切换 -- 保留 `CastSpellByName` 或转为 `CastShapeshiftForm` 调用。
- `castIfBuffAbsent` 调用 -- 保留该辅助函数模式（CONTEXT.md specifies: 可先保留该模式，不强制转为技能方法）。

### Rogue (当前 150 行, 无类定义)

**拆分建议: 2 文件（Claude's Discretion）**

Rogue 有潜行/非潜行和正面/背后两个维度，但代码量偏少（150行）。默认 2 文件模式。

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/rogue/Rogue.lua` | ~200 | 类定义、~12 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register、SelfTest:register |
| `classes/rogue/combat.lua` | ~200 | rogueAtk + rogueAtkBack + rogueSneak + rogueSneakBack + rogueBattle + rogueBattleBack + pickPocketBeforeCast + isTargetRogueFaint + restoreIfNeeded + readyVanish + lockNearestEnemyThenCast |

**技能方法清单（从现有 CastSpellByName 调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `pick_pocket` | `CastSpellByName("偷窃")` | `{en='Pick Pocket', zh='偷窃'}` | A | nil | nil |
| `ghostly_strike` | `CastSpellByName('鬼魅攻击')` | `{en='Ghostly Strike', zh='鬼魅攻击'}` | A | nil | nil |
| `hemorrhage` | `CastSpellByName('出血')` | `{en='Hemorrhage', zh='出血'}` | A | nil | nil |
| `sinister_strike` | `CastSpellByName('邪恶攻击')` | `{en='Sinister Strike', zh='邪恶攻击'}` | A | nil | nil |
| `backstab` | `CastSpellByName('背刺')` | `{en='Backstab', zh='背刺'}` | A | nil | nil |
| `vanish` | `CastSpellByName(s)` (消失) | `{en='Vanish', zh='消失'}` | B | nil | nil |
| `preparation` | `CastSpellByName('伺机待发')` | `{en='Preparation', zh='伺机待发'}` | B | nil | nil |

**中文技能名英文翻译确认 [ASSUMED]:**
- 偷窃 → Pick Pocket
- 鬼魅攻击 → Ghostly Strike
- 出血 → Hemorrhage
- 邪恶攻击 → Sinister Strike
- 背刺 → Backstab
- 消失 → Vanish
- 伺机待发 → Preparation

**特殊处理:**
- `pickPocketBeforeCast()` 使用了状态机（`pickPocketState = 0/1`），迁移时保持该逻辑。
- `lockNearestEnemyThenCast()` 是通用辅助函数，保留为全局函数不变。
- Rogue 的 Combo Points 可通过 PLAYER_FIELD_FUNC_MAP 复用（Player 已有 comboPoints 通过 GetComboPoints()）。

### Mage (当前 81 行, 无类定义)

**拆分建议: 3 文件（Claude's Discretion）**

Mage 代码量少（81行），但功能维度清晰：战斗逻辑(buff→atk→range/melee)、buff管理、控制。默认 2+1 模式。

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/mage/Mage.lua` | ~180 | 类定义、~8 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register、SelfTest:register |
| `classes/mage/combat.lua` | ~80 | mageAtk + mageRangedAtk + mageMeleeAtk |
| `classes/mage/utility.lua` | ~40 | mageBuffs + mageCtrl |

**技能方法清单（从现有 CastSpellByName 调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `frostbolt` | `CastSpellByName('Frostbolt')` | `{en='Frostbolt', zh='寒冰箭'}` | A | nil | nil |
| `frost_armor` | 通过 `castIfBuffAbsent` | `{en='Frost Armor', zh='冰甲术'}` | B | nil | nil |
| `arcane_intellect` | 通过 `castIfBuffAbsent` | `{en='Arcane Intellect', zh='奥术智慧'}` | C | nil | nil |

**特殊处理:**
- `castIfBuffAbsent` 调用占多数 -- 保留该模式（CONTEXT.md specifies）。
- 仅 2 处 `CastSpellByName('Frostbolt')` 需要转为技能方法。

### Priest (当前 111 行, 无类定义)

**拆分建议: 3 文件（Claude's Discretion）**

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/priest/Priest.lua` | ~180 | 类定义、~10 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register、SelfTest:register |
| `classes/priest/combat.lua` | ~90 | priestAtk + priestRangedAtk |
| `classes/priest/utility.lua` | ~70 | priestBuffs + priestDebuffs + priestCtrl + priestHeal |

**技能方法清单（从现有 CastSpellByName 调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `holy_fire` | `CastSpellByName('Holy Fire')` | `{en='Holy Fire', zh='神圣之火'}` | A | nil | nil |
| `power_word_fortitude` | 通过 `castIfBuffAbsent` | `{en='Power Word: Fortitude', zh='真言术：韧'}` | C | nil | nil |
| `inner_fire` | 通过 `castIfBuffAbsent` | `{en='Inner Fire', zh='心灵之火'}` | B | nil | nil |
| `shadow_word_pain` | 通过 `castIfBuffAbsent` | `{en='Shadow Word: Pain', zh='暗言术：痛'}` | A | nil | nil |
| `heal` | `CastSpellByName('Heal')` | `{en='Heal', zh='治疗术'}` | C | nil | nil |
| `lesser_heal` | `CastSpellByName('Lesser Heal')` | `{en='Lesser Heal', zh='次级治疗术'}` | C | nil | nil |
| `renew` | 通过 `castIfBuffAbsent` | `{en='Renew', zh='恢复'}` | C | nil | nil |

**特殊处理:**
- `priestHeal()` 中有 3 处 `CastSpellByName`，需要转为技能方法。
- `priestRangedAtk()` 中有 1 处 `CastSpellByName('Holy Fire')`。
- 治疗技能属于 Type C（灵活目标），需要暴露 `onSelf` 参数。

### Warlock (当前 92 行, 无类定义)

**拆分建议: 3 文件（Claude's Discretion）**

| 文件 | 行数 | 内容 |
|------|------|------|
| `classes/warlock/Warlock.lua` | ~180 | 类定义、~8 技能方法、FIELD_FUNC_MAP、registerPlayerClass、SpellTrace:register、SelfTest:register |
| `classes/warlock/combat.lua` | ~80 | wlkAtk + wlkRangedAtk + wlkMeleeAtk |
| `classes/warlock/utility.lua` | ~50 | wlkCurses + wlkBuffs + wlkCtrl |

**技能方法清单（从现有 castIfBuffAbsent 调用点提取）[VERIFIED: codebase]:**

| 方法名 | 当前调用 | 语言映射 | 类型 | 距离 | 消耗 |
|--------|----------|----------|------|------|------|
| `immolate` | 通过 `castIfBuffAbsent` | `{en='Immolate', zh='献祭'}` | A | nil | nil |
| `corruption` | 通过 `castIfBuffAbsent` | `{en='Corruption', zh='腐蚀术'}` | A | nil | nil |
| `curse_of_agony` | 通过 `castIfBuffAbsent` | `{en='Curse of Agony', zh='痛苦诅咒'}` | A | nil | nil |
| `demon_skin` | 通过 `castIfBuffAbsent` | `{en='Demon Skin', zh='恶魔皮肤'}` | B | nil | nil |

**特殊处理:**
- Warlock 当前 0 处 `CastSpellByName`（全部使用 `castIfBuffAbsent`）。技能方法创建后，`castIfBuffAbsent` 调用点可逐步迁移但非强制（CONTEXT.md specifies）。

## Common Pitfalls

### Pitfall 1: Breaking the Metatable Chain

**What goes wrong:** New class constructors set up `classMetatable` incorrectly, causing `self.ref` or inherited methods (like `_castSpell`, `hasBuff`, `isSpellReady`) to return nil.

**Why it happens:** `classMetatable(cls, fieldMapName)` requires `cls` to be the parent class prototype (e.g., `macroTorch.Player`). If a class passes the wrong parent or nil, field resolution breaks.

**How to avoid:** Follow the exact pattern from Druid:
```lua
macroTorch.Xxx = macroTorch.Player:new()  -- Class prototype IS the parent
function macroTorch.Xxx:new()
    local obj = {}
    setmetatable(obj, macroTorch.classMetatable(self, "XXX_FIELD_FUNC_MAP"))
    -- self = macroTorch.Xxx (which IS macroTorch.Player:new())
    -- This gives the correct parent chain: instance -> Xxx -> Player -> Unit
end
```

**Warning signs:** `self.ref` is nil, `_castSpell` fails silently, skill methods throw errors.

### Pitfall 2: Dot vs Colon Syntax Confusion

**What goes wrong:** Using colon syntax (`self:method()`) for method definitions or calls that were defined with dot syntax.

**Why it happens:** Phase 6 (D-01) established pure dot syntax. Colon syntax introduces an implicit `self` parameter that can conflict with the explicit `self` in metatable chains.

**How to avoid:** Always use `obj.method()` for definitions and `obj.method()` for calls (not `self:method()`). This was the Phase 6 fix. [VERIFIED: codebase]

### Pitfall 3: Not Updating build_order.txt

**What goes wrong:** `build.sh` fails with "ERROR: File not found" because old flat paths (`classes/Hunter.lua`) still exist in `build_order.txt` but files have been deleted and replaced with subdirectory paths.

**Why it happens:** `build.sh` is in strict mode (Phase 4). Missing files cause error exit.

**How to avoid:** Update `build_order.txt` simultaneously with file creation/deletion. Remove old flat paths, add new subdirectory paths. The order within each class directory must be: `<Class>.lua` first, then `combat.lua`, then `utility.lua`.

### Pitfall 4: Rogue Chinese Skill Names

**What goes wrong:** Skill methods for Rogue fail because the skill names don't match what the WoW client expects in different locales.

**Why it happens:** Rogue code uses Chinese skill names hardcoded in `CastSpellByName("偷窃")`. The `_castSpell` locale system needs to know the English name for non-Chinese clients.

**How to avoid:** Provide both `en` and `zh` names in the locale table. The `_castSpell` method selects based on `GetLocale()`. English names must match exactly what `CastSpellByName` expects on an English client.

**Warning signs:** Skills silently fail on English client, only work on Chinese client.

### Pitfall 5: FIELD_FUNC_MAP Missing Fields

**What goes wrong:** Combat logic references fields like `player.comboPoints` on a non-Druid class, but the FIELD_FUNC_MAP doesn't have that field defined, causing nil returns.

**Why it happens:** `DRUID_FIELD_FUNC_MAP` has Druid-specific fields (comboPoints, isOoc, isProwling, etc.). Non-Druid classes may not have all these fields.

**How to avoid:** Each class's FIELD_FUNC_MAP should be minimal -- only include fields that class actually uses. Rogue needs `comboPoints` (via `GetComboPoints()`), Warrior/Hunter/Mage/Priest/Warlock do not need it.

## Code Examples

### Complete Class Definition Template (Hunter example)

```lua
--[[ Apache 2.0 License block ]] --
---猎人专用 start---

-- Class prototype inheriting from Player
macroTorch.Hunter = macroTorch.Player:new()

function macroTorch.Hunter:new()
    local obj = {}
    setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))

    -- Type A: enemy target skills
    function obj.raptor_strike(mode)
        return obj._castSpell({ en = 'Raptor Strike', zh = '猛禽一击' }, mode, nil, nil, false)
    end

    function obj.mongoose_bite(mode)
        return obj._castSpell({ en = 'Mongoose Bite', zh = '猫鼬撕咬' }, mode, nil, nil, false)
    end

    function obj.arcane_shot(mode)
        return obj._castSpell({ en = 'Arcane Shot', zh = '奥术射击' }, mode, nil, nil, false)
    end

    function obj.multi_shot(mode)
        return obj._castSpell({ en = 'Multi-Shot', zh = '多重射击' }, mode, nil, nil, false)
    end

    function obj.wing_clip(mode)
        return obj._castSpell({ en = 'Wing Clip', zh = '摔绊' }, mode, nil, nil, false)
    end

    function obj.concussive_shot(mode)
        return obj._castSpell({ en = 'Concussive Shot', zh = '震荡射击' }, mode, nil, nil, false)
    end

    function obj.serpent_sting(mode)
        return obj._castSpell({ en = 'Serpent Sting', zh = '毒蛇钉刺' }, mode, nil, nil, false)
    end

    function obj.hunters_mark(mode)
        return obj._castSpell({ en = "Hunter's Mark", zh = '猎人印记' }, mode, nil, nil, false)
    end

    -- Type B: self target skills
    function obj.disengage(mode)
        return obj._castSpell({ en = 'Disengage', zh = '逃脱' }, mode, nil, nil, true)
    end

    function obj.call_pet(mode)
        if macroTorch.pet.isExist then
            return obj._castSpell({ en = 'Dismiss Pet', zh = '解散宠物' }, mode, nil, nil, true)
        else
            return obj._castSpell({ en = 'Call Pet', zh = '召唤宠物' }, mode, nil, nil, true)
        end
    end

    return obj
end

-- FIELD_FUNC_MAP
macroTorch.HUNTER_FIELD_FUNC_MAP = {
}

-- Singleton
macroTorch.hunter = macroTorch.Hunter:new()

-- Polymorphic registration
macroTorch.registerPlayerClass("Hunter", macroTorch.Hunter)

-- Spell trace (migrated from existing setTraceSpellImmuneByName call)
macroTorch.SpellTrace:register('Serpent Sting', {
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})

-- Self-test registrations
macroTorch.SelfTest:register("Hunter: HUNTER_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.HUNTER_FIELD_FUNC_MAP) == "table", "not a table")
end, true)

macroTorch.SelfTest:register("Hunter: singleton exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter) == "table", "macroTorch.hunter not a table")
end, true)

macroTorch.SelfTest:register("Hunter: registered in PLAYER_CLASS_REGISTRY", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(macroTorch.PLAYER_CLASS_REGISTRY["Hunter"] ~= nil, "Hunter not in registry")
end, true)

macroTorch.SelfTest:register("Hunter: raptor_strike exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.raptor_strike) == "function", "raptor_strike not function")
end, true)
```

### Combat Module Transition (Hunter example)

Before (current code in `classes/Hunter.lua`):
```lua
function macroTorch.safeRaptorStrike(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.RAPTOR_E then
        macroTorch.readyRaptorStrike(clickContext)
    end
end

function macroTorch.readyRaptorStrike(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Raptor Strike') then
        player.cast('Raptor Strike')
    end
end
```

After (in `classes/hunter/combat.lua`):
```lua
-- Old safe/ready wrappers deleted. Call sites use skill methods directly:
-- Old: macroTorch.safeRaptorStrike(clickContext)
-- New: player.raptor_strike('safe')
-- Old: macroTorch.readyRaptorStrike(clickContext)
-- New: player.raptor_strike()
-- Old: player.cast('Raptor Strike')
-- New: player.raptor_strike('ready')
```

### build_order.txt Transition

Before:
```
classes/Hunter.lua
classes/Mage.lua
classes/Priest.lua
classes/Rogue.lua
classes/Warlock.lua
classes/Warrior.lua
```

After:
```
# classes/ — Druid (Phase 4, unchanged)
classes/druid/Druid.lua
classes/druid/cat.lua
classes/druid/bear.lua
classes/druid/utility.lua
# classes/ — Hunter (Phase 8)
classes/hunter/Hunter.lua
classes/hunter/combat.lua
classes/hunter/utility.lua
# classes/ — Warrior (Phase 8)
classes/warrior/Warrior.lua
classes/warrior/combat.lua
classes/warrior/utility.lua
# classes/ — Rogue (Phase 8)
classes/rogue/Rogue.lua
classes/rogue/combat.lua
# classes/ — Mage (Phase 8)
classes/mage/Mage.lua
classes/mage/combat.lua
classes/mage/utility.lua
# classes/ — Priest (Phase 8)
classes/priest/Priest.lua
classes/priest/combat.lua
classes/priest/utility.lua
# classes/ — Warlock (Phase 8)
classes/warlock/Warlock.lua
classes/warlock/combat.lua
classes/warlock/utility.lua
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CastSpellByName('SkillName')` | `obj._castSpell({en='...', zh='...'}, mode, range, cost, onSelf)` | Phase 5 | Multi-locale support, mode-based readiness/resource checks, consistent API |
| `setSpellTracing` + `setTraceSpellImmune` | `SpellTrace:register(name, config)` | Phase 3 | Declarative, single call replaces two |
| Flat single-file class | Multi-file subdirectory (`classes/<class>/`) | Phase 4 (Druid), Phase 8 (all others) | Better organization, aligned structure |
| Manual metatable template | `classMetatable(cls, fieldMapName)` | Phase 1 | 9-line boilerplate reduced to 1 call |
| `self:method()` syntax | `obj.method()` dot syntax | Phase 6 | Correct closure self binding |
| `isFormActive('Cat Form')` | `obj.isInCatForm` | Phase 7 | Semantic field function, more readable |

**Deprecated/outdated:**
- `CastSpellByName` raw calls in class files: Replaced by skill methods
- `safeXxx`/`readyXxx` wrapper functions: Replaced by mode parameter on skill methods
- Flat `classes/Xxx.lua` files: Replaced by `classes/xxx/` directory structure

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Rogue Chinese skill name English translations (偷窃→Pick Pocket, 鬼魅攻击→Ghostly Strike, 出血→Hemorrhage, 邪恶攻击→Sinister Strike, 背刺→Backstab, 消失→Vanish, 伺机待发→Preparation) | Per-Class Decomposition (Rogue) | Skill methods fail on English clients -- planner should add checkpoint for user to verify English names |
| A2 | `castIfBuffAbsent` helper function retains its current behavior after refactoring (it internally calls `CastSpellByName`) | Per-Class Decomposition (Warrior/Priest/Mage/Warlock) | `castIfBuffAbsent` is a utility function in Player.lua that wraps CastSpellByName; keeping it unchanged means it will still work but not provide locale support or mode checks for those specific call paths |
| A3 | The `isStanceActive(idx)` and `isStanceActiveByName(stanceName)` functions in Player.lua are sufficient for Warrior stance detection (no new FIELD_FUNC_MAP fields needed) | Per-Class Decomposition (Warrior) | If stances need lazy computation like Druid forms, planner will need to add WARRIOR_FIELD_FUNC_MAP entries |
| A4 | Each class's combat logic functions can safely be moved to separate files without breaking closure references, since all functions are on the global `macroTorch` namespace | Architecture Patterns | If any function uses local/closure variables from the original file, those variables would be out of scope in the new file -- must verify each file independently |

## Open Questions (RESOLVED)

1. **Rogue 技能英文名准确性** -- RESOLVED: Plan 08-02 Task 3 is a `checkpoint:human-verify` for Rogue locale table. User confirms/corrects during execution.
   - What we know: From CONTEXT.md, we have suggested English names for Rogue skills (Pick Pocket, Ghostly Strike, Hemorrhage, etc.)
   - What's unclear: Whether these exact spell names match what Turtle WoW 1.12.1 English client expects
   - Recommendation: Planner should add `checkpoint:human-verify` for Rogue locale table. User can confirm or correct English names.

2. **Warrior Battle/Defensive Stance CastSpellByName calls** -- RESOLVED: Plan 08-01 Task 3 keeps `CastSpellByName('Battle Stance')` and `CastSpellByName('Defensive Stance')` as-is (stance changes, not spells). Deferred to future phase.
   - What we know: `wroCtrl()` and `wroInterrupt()` have `CastSpellByName('Battle Stance')` and `CastSpellByName('Defensive Stance')` calls -- these are stance changes, not regular spells.
   - What's unclear: Whether stance changes should become skill methods (like Druid's `bear_form`/`cat_form`) or kept as CastSpellByName
   - Recommendation: Keep as CastSpellByName for now -- stance changes are a deferred feature (Phase 8 scope: architecture alignment only).

3. **Rogue Combo Points FIELD_FUNC_MAP** -- RESOLVED: Plan 08-02 Task 1 adds `['comboPoints'] = function(self) return GetComboPoints() or 0 end` to ROGUE_FIELD_FUNC_MAP for consistency with Druid pattern.
   - What we know: Rogue uses combo points like Druid. GetComboPoints() is a WoW API that works for both classes.
   - What's unclear: Whether `comboPoints` should go in ROGUE_FIELD_FUNC_MAP or relied on from PLAYER_FIELD_FUNC_MAP
   - Recommendation: Add to ROGUE_FIELD_FUNC_MAP for consistency with Druid pattern. Function is identical: `function(self) return GetComboPoints() or 0 end`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Lua environment (WoW 1.12.1 embedded) | All runtime behavior | n/a (in-game only) | WoW 1.12.1 | -- |
| `build.sh` | Build verification | Yes | current | -- |
| `build_order.txt` | Build system | Yes | current | -- |
| Git | Version control | Yes | current | -- |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

Note: This phase is a pure code refactoring -- all infrastructure dependencies (`core/class.lua`, `entity/Player.lua`, `core/spell_trace_core.lua`, `core/selftest.lua`) are already in place from Phases 1-7. No new external tools or libraries needed.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | In-game Lua self-test (`macroTorch.SelfTest`) -- no external test framework exists for WoW addons |
| Config file | none -- SelfTest is programmatic |
| Quick run command | `./build.sh` (verify build succeeds, all symbols present) |
| Full suite command | In-game: log in as each class, verify SelfTest output in chat frame |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-08-CLASS-DEF | All 6 non-Druid classes have classMetatable + FIELD_FUNC_MAP + registerPlayerClass | self-test + grep | `grep -c "macroTorch.classMetatable" classes/*/<Class>.lua` >= 6 | Wave 0 |
| REQ-08-SKILL-METHODS | All CastSpellByName calls replaced with skill methods | grep verification | `grep -c "CastSpellByName" classes/hunter/ classes/warrior/ classes/rogue/ classes/mage/ classes/priest/ classes/warlock/` | Wave 0 |
| REQ-08-SPELLTRACE | Each class has SpellTrace:register for applicable skills | self-test | `grep -c "SpellTrace:register" classes/*/<Class>.lua` | Wave 0 |
| REQ-08-SELFTEST | Each class has SelfTest:register entries (class existence, key skills) | self-test (in-game) | In-game: log in, check chat frame | Wave 0 |
| REQ-08-BUILD | build_order.txt updated, build.sh succeeds | build | `./build.sh && echo "Build OK"` | Wave 0 |
| REQ-08-NO-FLAT | Old flat files deleted | file check | `test ! -f classes/Hunter.lua && echo "OK"` | Wave 0 |
| REQ-08-INITPLAYER | All classes in PLAYER_CLASS_REGISTRY | grep | `grep -c "registerPlayerClass" classes/*/<Class>.lua` >= 6 | Wave 0 |

### Sampling Rate

- **Per task commit:** `./build.sh` (smoke test that build succeeds)
- **Per wave merge:** `./build.sh` + grep verification of all requirements
- **Phase gate:** `./build.sh` succeeds, all grep verifications pass, all old files deleted

### Wave 0 Gaps

- Skills that used `castIfBuffAbsent` retain that pattern -- need to verify the helper function is available (it's in `entity/Player.lua` which is already in build_order.txt)
- In-game SelfTest validation requires actual WoW client login -- cannot be scripted
- No external Lua test framework exists for WoW 1.12.1 addons

## Security Domain

This phase has no security-relevant changes. It is a pure code structure refactoring within an existing addon that runs in the WoW 1.12.1 sandbox. No new attack surfaces are introduced.

## Sources

### Primary (HIGH confidence)
- `classes/druid/Druid.lua` (1310 lines) -- reference architecture: class definition, FIELD_FUNC_MAP, ~40 skill methods, registerPlayerClass, SpellTrace:register, SelfTest:register [VERIFIED: codebase]
- `classes/druid/cat.lua` (387 lines) -- reference for combat module file [VERIFIED: codebase]
- `classes/druid/bear.lua` (146 lines) -- reference for form-specific combat file [VERIFIED: codebase]
- `classes/druid/utility.lua` (89 lines) -- reference for utility file [VERIFIED: codebase]
- `core/class.lua` -- classMetatable factory, registerPlayerClass, initPlayer [VERIFIED: codebase]
- `entity/Player.lua` -- _castSpell, _isInRange, _hasResource, cast, isSpellReady, castIfBuffAbsent [VERIFIED: codebase]
- `core/spell_trace_core.lua` -- SpellTrace:register API [VERIFIED: codebase]
- `core/selftest.lua` -- SelfTest:register/run framework [VERIFIED: codebase]
- Existing non-Druid class files: Hunter.lua (205 lines), Warrior.lua (210 lines), Rogue.lua (150 lines), Mage.lua (81 lines), Priest.lua (111 lines), Warlock.lua (92 lines) [VERIFIED: codebase]
- `build_order.txt` -- current build configuration [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- `.planning/codebase/ARCHITECTURE.md` -- system architecture documentation [CITED: codebase analysis]
- `.planning/codebase/CONVENTIONS.md` -- coding conventions [CITED: codebase analysis]
- Phase 5 CONTEXT.md -- _castSpell design, skill method categories (Type A/B/C) [CITED: .planning/phases/05-druid-player-cast-druid/05-CONTEXT.md]
- Phase 6 CONTEXT.md -- dot syntax convention [CITED: .planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md]
- Phase 7 CONTEXT.md -- semantic form-check methods in FIELD_FUNC_MAP [CITED: .planning/phases/07-druid/07-CONTEXT.md]

### Tertiary (LOW confidence)
- Rogue English skill name translations [ASSUMED] -- need user verification on Turtle WoW English client

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all infrastructure (classMetatable, _castSpell, SpellTrace, SelfTest) already exists in codebase and verified
- Architecture: HIGH -- Druid architecture fully established and verified in Phases 4-7; non-Druid files have been read and analyzed
- Pitfalls: HIGH -- based on lessons learned from Phases 5-7 (dot syntax bug, metatable chain, build_order.txt strict mode)
- Per-class skill names: MEDIUM -- most verified from codebase, Rogue Chinese-to-English translations need user confirmation

**Research date:** 2026-06-15
**Valid until:** 2026-07-15 (stable architectural pattern, no external dependency changes expected)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-08-CLASS-DEF | All 6 classes get classMetatable + FIELD_FUNC_MAP + registerPlayerClass | Sections: Architecture Patterns, Per-Class Decomposition Analysis, Code Examples |
| REQ-08-SKILL-METHODS | CastSpellByName -> _castSpell skill methods with locale support | Sections: Per-Class Decomposition Analysis (skill method tables per class), Code Examples |
| REQ-08-SPELLTRACE | SpellTrace:register for applicable skills per class | Sections: Architecture Patterns, Code Examples |
| REQ-08-SELFTEST | SelfTest:register entries for each class | Sections: Architecture Patterns, Code Examples |
| REQ-08-BUILD | build_order.txt updated, old flat files deleted | Sections: build_order.txt Transition, Common Pitfalls |
| REQ-08-NO-FLAT | No flat classes/Xxx.lua files remain | Section: Common Pitfalls (Pitfall 3) |
| REQ-08-INITPLAYER | All classes in PLAYER_CLASS_REGISTRY via registerPlayerClass | Sections: Architecture Patterns, Per-Class Decomposition Analysis |
<!-- gsd:write-continue -->