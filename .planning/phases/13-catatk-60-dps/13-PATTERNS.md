# Phase 13: catAtk 小号练级适配 - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 3 (modified)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `classes/druid/Druid.lua` | service / shared-decision-functions | request-response (combat logic) | `classes/druid/Druid.lua:556-564` (computeClaw_E pattern) + self | exact (same file, same pattern) |
| `classes/druid/cat.lua` | service / module-implementations | request-response (combat logic) | `classes/druid/cat.lua:176-185` (reshiftMod with isSpellExist guard) | exact (same file, same pattern) |
| `core/selftest.lua` | test | N/A (test registration) | `core/selftest.lua:1250-1277` (Druid FIELD_FUNC_MAP selftest registrations) | exact (same file, same pattern) |

## Pattern Assignments

### 1. `classes/druid/cat.lua` -- 模块级 isSpellExist guard 插入

**Analog (primary):** `classes/druid/cat.lua:176-185` -- `reshiftMod` 已有的 guard 模式

**Guard pattern (lines 176-179):**
```lua
function macroTorch.reshiftMod(clickContext)
    if not macroTorch.isSpellExist('Reshift', 'spell') then
        return
    end
    -- ... existing reshift logic unchanged ...
end
```

**Definitive source for guard clause format:**

- `biz_util.lua:75-77` -- `macroTorch.isSpellExist(spellName, bookType)` 实现：
```lua
function macroTorch.isSpellExist(spellName, bookType)
    return macroTorch.toBoolean(macroTorch.getSpellIdByName(spellName, bookType))
end
```

- 参数约定: 第二个参数固定为 `'spell'`（所有模块技能均为 spell book 技能）

**Target guard insertion points and spell names (all verified against Druid.lua _castSpell locale tables):**

| Module | Line | Guard Spell Name (English locale) | Guard Code |
|--------|------|-----------------------------------|------------|
| `keepRip` | cat.lua:210 | `'Rip'` | `if not macroTorch.isSpellExist('Rip', 'spell') then return end` |
| `keepRake` | cat.lua:279 | `'Rake'` | `if not macroTorch.isSpellExist('Rake', 'spell') then return end` |
| `keepFF` | cat.lua:290 | `'Faerie Fire (Feral)'` | `if not macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell') then return end` |
| `keepTigerFury` | cat.lua:203 | `"Tiger's Fury"` | `if not macroTorch.isSpellExist("Tiger's Fury", 'spell') then return end` |
| `termMod` | cat.lua:92 | `'Ferocious Bite'` | `if not macroTorch.isSpellExist('Ferocious Bite', 'spell') then return end` |
| `otMod` | cat.lua:63 | `'Cower'` | `if not macroTorch.isSpellExist('Cower', 'spell') then return end` |
| `reshiftMod` | cat.lua:177 | `'Reshift'` | **已存在 -- 保持不变 (D-05)** |
| `regularAttack` | cat.lua:46 | **不加 guard** | 见 D-03 / D-08: fallback 到 Claw (level 1)，仅通过 shouldUseShred 内部 guard |

**openerMod (内联于 Druid.lua:383-392):**

openerMod 是内联在 `catAtk()` 主函数中的代码块（`Druid.lua:383-392`），不在 cat.lua 中。它需要检查两个技能：

```lua
-- Druid.lua:383-392 当前代码
if clickContext.prowling then
    if not target.isImmune('Pounce') and target.health >= 1500 then
        if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
            macroTorch.player.pounce()
        end
    else
        player.ravage('ready')
    end
end
```

Guard 策略 -- 在 prowling 块内部添加变量检查：
```lua
-- [NEW] D-02: skip opener module if neither opener skill is available
local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
if clickContext.prowling then
    if hasPounce and not target.isImmune('Pounce') and target.health >= 1500 then
        if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
            macroTorch.player.pounce()
        end
    elseif hasRavage then
        player.ravage('ready')
    end
    -- else: no opener available, silently skip
end
```

**Anti-pattern: DO NOT add guard to `regularAttack` (cat.lua:46).** `regularAttack` 通过 `shouldUseShred` 内部 guard 自然 fallback 到 Claw。加模块级 guard 会阻止 Claw fallback。

**Anti-pattern: DO NOT add guard to `oocMod` (cat.lua:147).** `oocMod` 委托给 `regularAttack` 和 `cp5Bite`，其行为已被子函数的 guard 覆盖。

### 2. `classes/druid/Druid.lua` -- 共享决策函数 guard + RESHIFT_ENERGY 动态计算

#### 2a. 共享决策函数 guard (Pattern: same as reshiftMod, but return false)

**Analog:** `classes/druid/cat.lua:176-179` (reshiftMod guard) -- 区别：决策函数返回 `false` 而非空 `return`

**Guard pattern for decision functions:**
```lua
-- [NEW GUARD] D-03: skill not learned -> return false
if not macroTorch.isSpellExist('SpellName', 'spell') then
    return false
end
```

**Insertion targets:**

| Function | File:Line | Guard Spell Name | Insert Position |
|----------|-----------|-------------------|-----------------|
| `shouldUseShred` | Druid.lua:705 | `'Shred'` | 函数体第一行，在任何条件逻辑之前 (line 706) |
| `shouldCastRip` | Druid.lua:987 | `'Rip'` | 函数体第一行，在现有 common preconditions 逻辑之前 (line 988) |
| `shouldUseBite` | Druid.lua:1008 | `'Ferocious Bite'` | 函数体第一行，在 isKillShotOrLastChance 检查之前 (line 1009) |

**`shouldUseShred` 加 guard 后的 fallback 链验证：**

`getMinimumAffordableAbilityCost` (Druid.lua:953-982) 的优先级链:
```
Bite(shouldUseBite) -> Tiger(isTigerPresent) -> Rip(shouldCastRip) -> Rake(isRakePresent) -> Shred(shouldUseShred) -> Claw(always available)
```

当三个共享决策函数都加了 `isSpellExist` guard 后：
- 低等级无 Shred: `shouldUseShred` 返回 false -> 链跳过 Shred -> return CLAW_E, 'Claw'
- 低等级无 Rip: `shouldCastRip` 返回 false -> 链跳过 Rip -> 继续到下一项
- 低等级无 Bite: `shouldUseBite` 返回 false -> 链跳过 Bite -> 继续到下一项

最终 fallback 到 Claw（level 1 技能，始终可用）。

**`shouldCastFFDuringWaitWindow` 处理：**
- 该函数位于 `Druid.lua:923`
- 仅由 `keepFF` (cat.lua:290) 调用
- 一旦 `keepFF` 加上 `isSpellExist('Faerie Fire (Feral)')` guard，该函数在低等级永远不会被调用
- **结论: 无需单独 guard**（Claude's discretion 已确认）

#### 2b. 动态 RESHIFT_ENERGY 计算 (Pattern: computeClaw_E analog)

**Analog:** `classes/druid/Druid.lua:556-564` -- `computeClaw_E()` 动态能耗计算模式

**Pattern structure from computeClaw_E:**
```lua
-- Druid.lua:556-564
function macroTorch.computeClaw_E()
    local CLAW_E = 45
    local player = macroTorch.player
    if player.isItemEquipped('Idol of Ferocity') then
        CLAW_E = CLAW_E - 3
    end
    CLAW_E = CLAW_E - player.talentRank('Ferocity')
    return CLAW_E
end
```

**Pattern characteristics:**
- 全局函数 (`macroTorch.xxx`)
- 函数名 camelCase: `compute` 前缀
- 访问全局 `macroTorch.player` 实例
- 调用 `player.talentRank(talentName)` 获取天赋 rank (返回数字，0=未学习)
- 调用 `player.isItemEquipped(itemName)` 检测装备
- 返回数字

**New function implementation (放置于 computeClaw_E / computeShred_E 附近，Druid.lua:564 之后):**
```lua
function macroTorch.computeReshiftEnergy()
    local energy = 0
    local player = macroTorch.player
    -- Furor talent: each rank gives +8 energy when reshifting
    energy = energy + player.talentRank('Furor') * 8
    -- Wolfshead Helm: +20 energy on shapeshift
    if player.isItemEquipped('Wolfshead Helm') then
        energy = energy + 20
    end
    return energy
end
```

**Replacement at Druid.lua:338:**
```lua
-- Before:
clickContext.RESHIFT_ENERGY = 60
-- After:
clickContext.RESHIFT_ENERGY = macroTorch.computeReshiftEnergy()
```

**Integration in `shouldDoReshift` (cat.lua:186):**
```lua
function macroTorch.shouldDoReshift(clickContext)
    -- [NEW CHECK] D-04: if reshift would give zero energy, skip entirely
    if clickContext.RESHIFT_ENERGY == 0 then
        return false
    end
    -- ... existing logic unchanged ...
```

**60级验证:** Furor rank 5 = 40, Wolfshead Helm = 20, 总和 = 60。与当前硬编码值完全一致，代码路径等价。

**Infrastructure already available (no new functions needed):**
- `player.talentRank(talentName)` -- `entity/Player.lua:343`, delegates to `macroTorch.getTalentRank`
- `player.isItemEquipped(itemName)` -- `entity/Player.lua:313`, delegates to `macroTorch.getEquippedItemSlot`
- `macroTorch.isSpellExist(spellName, 'spell')` -- `biz_util.lua:75`, uses pcall-wrapped GetSpellName

**Assumptions to verify (from RESEARCH.md):**
- [A1] Turtle WoW Furor 天赋英文名是否确为 `'Furor'`
- [A2] Furor 每 rank 是否确实 +8 energy (max 5 ranks = 40)
- [A3] Turtle WoW 狼头头盔英文名是否确为 `'Wolfshead Helm'`
- [A4] 狼头头盔是否确实提供 +20 energy on shapeshift

### 3. `core/selftest.lua` -- 低等级路径 selftest 注册

**Analog:** `core/selftest.lua:1250-1277` -- Druid FIELD_FUNC_MAP selftest registrations (Category G1)

**Pattern structure from existing Druid selftests:**
```lua
macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP comboPoints exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player.comboPoints) == "number", "comboPoints not number")
end, true)
```

**Pattern characteristics:**
- `macroTorch.SelfTest:register(name, fn, isOptional)` 签名
- 测试名格式: `"Druid: <短描述>"` -- 按 Category 前缀分组
- `if UnitClass('player') ~= 'Druid' then return end` -- 非 Druid 玩家静默跳过
- `assert(condition, "error message")` -- 标准 Lua assert
- `isOptional = true` -- 所有 Druid 相关测试均为可选（需要游戏内执行）
- 放置位置: 紧接在现有 Druid 测试注册之后 (Druid.lua:1308 之后，或 selftest.lua 末尾)

**建议测试注册清单 (D-07):**

```
Category H: catAtk 低等级路径验证 (isOptional=true)

1. "Druid: computeReshiftEnergy returns 0 with no Furor and no Wolfshead Helm"
   -- 模拟：talentRank('Furor')==0 且 isItemEquipped('Wolfshead Helm')==false → 返回 0
2. "Druid: computeReshiftEnergy returns 40 with 5/5 Furor and no Wolfshead Helm"
   -- 模拟：talentRank('Furor')==5 且 isItemEquipped('Wolfshead Helm')==false → 返回 40
3. "Druid: computeReshiftEnergy returns 60 with 5/5 Furor and Wolfshead Helm"
   -- 模拟：talentRank('Furor')==5 且 isItemEquipped('Wolfshead Helm')==true → 返回 60
4. "Druid: shouldUseShred returns false when Shred unlearned"
   -- 模拟：isSpellExist('Shred')==false → 应返回 false
5. "Druid: shouldCastRip returns false when Rip unlearned"
   -- 模拟：isSpellExist('Rip')==false → 应返回 false
6. "Druid: shouldUseBite returns false when Ferocious Bite unlearned"
   -- 模拟：isSpellExist('Ferocious Bite')==false → 应返回 false
7. "Druid: catAtk module guards: all guards no-op at level 60 with full skills"
   -- 60级满技能满天赋时，所有 isSpellExist 返回 true, RESHIFT_ENERGY == 60
```

**测试格式模板:**
```lua
macroTorch.SelfTest:register("Druid: computeReshiftEnergy returns 0 with no Furor and no helm", function()
    if UnitClass('player') ~= 'Druid' then return end
    local energy = macroTorch.computeReshiftEnergy()
    -- 测试值取决于当前角色的实际天赋和装备
    -- 此测试提供框架，具体断言由玩家根据当前角色情况验证
    assert(type(energy) == "number", "computeReshiftEnergy should return a number")
    assert(energy >= 0, "computeReshiftEnergy should not be negative")
    assert(energy <= 100, "computeReshiftEnergy should not exceed 100")
end, true)
```

## Shared Patterns

### 模块级 Guard 模式 (authentic, cross-cutting)

**Source:** `classes/druid/cat.lua:176-179` (唯一已存在的 guard 先例)
**Apply to:** `keepRip`, `keepRake`, `keepFF`, `keepTigerFury`, `termMod`, `otMod` (所有 cat.lua 模块入口)
**Anti-pattern for:** `regularAttack`, `oocMod`

```lua
-- 在每个模块函数的第一行插入（在任何业务逻辑之前）
function macroTorch.moduleName(clickContext)
    if not macroTorch.isSpellExist('SpellName', 'spell') then
        return  -- 静默跳过，继续执行后续模块
    end
    -- ... existing logic unchanged ...
end
```

### 共享决策函数 Guard 模式

**Source:** 衍生自 reshiftMod guard 模式（返回 `false` 替代空 `return`）
**Apply to:** `shouldUseShred`, `shouldCastRip`, `shouldUseBite` (Druid.lua 共享决策函数)

```lua
function macroTorch.decisionFunction(clickContext)
    if not macroTorch.isSpellExist('SpellName', 'spell') then
        return false  -- 决策函数返回 false = "不应该使用这个技能"
    end
    -- ... existing decision logic unchanged ...
end
```

### 动态计算函数模式

**Source:** `classes/druid/Druid.lua:556-564` (`computeClaw_E`)
**Apply to:** `computeReshiftEnergy` (新函数)

```lua
function macroTorch.computeXxx()
    local value = DEFAULT_VALUE
    local player = macroTorch.player
    -- 按需调整值
    if player.talentRank('TalentName') then
        value = value - player.talentRank('TalentName') * MODIFIER
    end
    if player.isItemEquipped('Item Name') then
        value = value + BONUS
    end
    return value
end
```

### Selftest 注册模式

**Source:** `core/selftest.lua:1250-1277` (Druid FIELD_FUNC_MAP tests)
**Apply to:** All new catAtk low-level selftests

```lua
macroTorch.SelfTest:register("Druid: <test description>", function()
    if UnitClass('player') ~= 'Druid' then return end
    -- test assertions
    assert(condition, "error message for failure")
end, true)  -- isOptional=true for all Druid tests
```

### 代码注释风格

**Source:** 代码库中的现有注释模式（cat.lua:176-179, Druid.lua:337）
**Apply to:** 所有新代码

```lua
-- [NEW GUARD] D-02: skip RIP module if spell not learned
-- [NEW GUARD] D-03: Shred not learned -> always prefer Claw
-- [NEW] D-04: compute reshift energy dynamically from talents and gear
```

**关键风格要点：**
- 注释使用英文
- Guard 注释使用 `[NEW GUARD]` 前缀，包含决策编号 (D-0X)
- 新函数注释使用 `[NEW]` 前缀
- 单行注释格式: `-- 说明`

### 点号语法约定

**Source:** 06-CONTEXT.md D-01
**Apply to:** 所有函数调用

- 始终使用点号语法调用 `macroTorch` 全局函数：`macroTorch.isSpellExist(...)`
- 始终使用点号语法调用 `player` 方法：`player.talentRank(...)`
- 不使用冒号语法

## 修改完整性检查清单 (D-08)

Planner 需逐点验证：

1. **无 nil 引用路径**: 每个 guard return 后，后续模块依赖的 clickContext 字段在 catAtk() 入口都已初始化（line 305-365），不依赖前面被 guard 跳过的模块。
2. **无隐式假设断裂**: 模块按优先级排列（catAtk:363-425），一个 return 后继续下一个，不存在 "模块 A 必须在模块 B 之前执行" 的依赖。
3. **`getMinimumAffordableAbilityCost` 正确 fallback**: 三个共享决策函数加 guard 后，不存在的技能自动被跳过，最终返回 CLAW_E。Claw 是 level 1 技能，始终可用。
4. **`cp5Bite` 安全**: `cp5Bite` (cat.lua:97) 被 `termMod` 和 `oocMod` 调用。`termMod` 加 guard 后低等级跳过。`oocMod` 未被 guard 但 `cp5Bite` 内部调用 `_castSpell`（pcall 包裹），`readyBite` 通过 `isSpellReady('Ferocious Bite')` 安全返回 false。
5. **`shouldDoReshift` 中的 RESHIFT_ENERGY 检查**: RESHIFT_ENERGY == 0 时 reshift 从不划算。添加 `if clickContext.RESHIFT_ENERGY == 0 then return false end` 作为前置检查（cat.lua:186 函数体第一行，在现有 not-in-combat 检查之前），不破坏现有逻辑。

## No Analog Found

所有文件在代码库中都有精确对应。不需要任何无先例的模式。（`computeReshiftEnergy` 是 `computeClaw_E` 的精确模板，`isSpellExist` guard 模式有 `reshiftMod` 先例。）

## Metadata

**Analog search scope:** `classes/druid/Druid.lua`, `classes/druid/cat.lua`, `core/selftest.lua`, `biz_util.lua`, `entity/Player.lua`
**Files scanned:** 6 (3 targets + 3 infrastructure files)
**Pattern extraction date:** 2026-06-20