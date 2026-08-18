# Phase 25: Hunter 一键宏改造 - Research

**Researched:** 2026-08-18
**Domain:** World of Warcraft 1.12.1 Lua Addon -- Hunter Class One-Button Macro
**Confidence:** HIGH (patterns verified from codebase; skill mechanics from training data need user confirmation)

## Summary

Phase 25 将当前的 Hunter 职业代码从过时测试代码重构为与 Druid 架构完全对齐的一键宏系统。核心策略是"推倒重来"——现有 `classes/hunter/` 下的 3 个文件（Hunter.lua、combat.lua、utility.lua）均为过时测试代码，不受现有结构约束。参考 Druid 的 8 个一键宏（druidAtk/druidAoe/druidHeal/druidDefend/druidControl/druidMobTagging/druidCharge/catAtk/casterAtk），Hunter 需实现 5 个一键宏：hunterAtk（练级输出）、hunterAoe（范围攻击）、hunterDefend（保命）、hunterControl（控制）、hunterMobTagging（抢怪）。

**Hunter 与 Druid 的核心结构差异：**
- Druid 通过"形态"（猫/熊/人）路由攻击逻辑
- Hunter 通过"距离"（远程 ≥8yd / 近战 <8yd）路由攻击逻辑，这是本 phase 最重要的架构抽象

**Primary recommendation:** 完全按照 Druid 的代码组织结构重建 Hunter：Hunter.lua 包含类定义 + ~25 个技能方法 + SpellTrace + SelfTest；combo.lua 包含 5 个一键宏函数，使用 clickContext 单键缓存、模块优先级链、距离路由等模式。

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: 单入口路由** -- `hunterAtk()` 作为统一入口，按目标距离自动路由：`< 8yd` → 近战分支，`≥ 8yd` → 远程分支。
- **D-02: 12 模块优先级链** -- 参照 Druid `catAtk` 的 module-priority chain 模式，使用 `clickContext` 单次缓存表。模块按优先级顺序执行，第一个成功动作 return。
  - 模块清单：生存急救 → 目标选择 → 自动攻击 → 爆发(burstMod/Shift) → 起手技(Aimed Shot Shift) → 钉刺/标记 → 主要输出 → 仇恨管理(otMod/Disengage) → 其他填充
- **D-03: 近战/远程切换阈值 8yd** -- 使用 `target.distance < 8`。不考虑 5-8yd 死区问题。
- **D-04: Auto Shot 每键触发** -- 每次按键都调用 `startAutoShoot()`。
- **D-05: Aimed Shot Shift 手动触发** -- 通过 Shift 修饰键在 burstMod 模块中触发。
- **D-06: 不涉及陷阱** -- 陷阱完全交给 hunterAoe 和 hunterControl，hunterAtk 中不包含陷阱逻辑。
- **D-07: 不涉及守护(Aspect)** -- 用户手动管理。
- **D-08: 不涉及宠物** -- 用户手动控制，hunterAtk 不调用宠物相关逻辑。
- **D-09: ~15 个新技能方法** -- 在现有 10 个方法基础上补充 aimed_shot, scorpid_sting, viper_sting, immolation_trap, explosive_trap, freezing_trap, deterrence, feign_death, mend_pet, revive_pet 等。
- **D-10: Druid 对齐文件结构** -- Hunter.lua（类定义 + 技能方法 + FIELD_FUNC_MAP + SelfTest + SpellTrace）+ combo.lua（5 个一键宏函数）。现有 combat.lua/utility.lua 废弃。
- **D-11: 钉刺 land tracing** -- 为 Serpent Sting 和 Scorpid Sting 注册 SpellTrace（land trace 区分自己的钉刺 vs 其他猎人的）。
- **D-12: Hunter's Mark 不 trace** -- 用户明确不需要。
- **D-13: hunterAoe 距离路由** -- 远程(≥8yd)：Multi-Shot → Volley；近战(<8yd)：Explosive Trap → Immolation Trap。~20 行。
- **D-14: hunterDefend 仅 Deterrence** -- 极简实现，~5 行。不包含 Feign Death/Disengage/Aspect。
- **D-15: hunterControl 距离路由** -- 近战(<8yd)：Wing Clip 或 Freezing Trap；远程(≥8yd)：Concussive Shot 或 Scatter Shot。~30 行。
- **D-16: hunterMobTagging 远程用 Arcane Shot rank 1** -- 最低级奥术射击（瞬发、最低法力消耗、30码射程）。
- **D-17: hunterMobTagging 近战用 Wing Clip** -- 摔绊（瞬发近战直伤 + 减速）。
- **D-18: PvP 过滤** -- 选到玩家目标时自动 ClearTarget()，参照 druidMobTagging 的二次确认模式。
- **D-19: 自动衔接输出** -- tag 成功后（target.isAttackingMe）自动调用 hunterAtk()。
- **D-20: SelfTest 参照 Druid 级别** -- 基础设施测试 + 全部技能方法存在性测试(~25) + 一键宏函数存在性测试(5)。全部使用 `isOptional=true` + `UnitClass('player') ~= 'Hunter'` guard。

### Claude's Discretion
- 12 个模块的具体命名、优先级顺序和实现细节
- `clickContext` 缓存字段的具体设计
- 技能方法的 `mode` 参数行为（'ready' vs 'safe' vs 'raw'）
- Aimed Shot Shift 触发在 burstMod 中的具体检查条件
- hunterAoe/hunterControl 中具体的优先级链和回退逻辑
- hunterMobTagging 中目标有效性检查的细粒度守卫条件
- SelfTest 测试用例的具体 assert 措辞
- combo.lua 中的注释风格和模块分隔（遵循 Druid combo.lua 模式）

### Deferred Ideas (OUT OF SCOPE)
- Aspect 守护自动切换
- 宠物深度管理（自动 Mend Pet/Revive Pet/Call Pet）
- Feign Death 集成（不属于减伤技能）
- Intimidation（BM 天赋昏迷）
- Viper Sting 自动使用
- 练级版 hunterAtk（参照 catLeveling）
</user_constraints>

<phase_requirements>
## Phase Requirements (Tentative -- no formal REQ-IDs in REQUIREMENTS.md)

This phase does not yet have formal REQ-IDs. The planner should create internal requirement IDs. The following requirements are implied by CONTEXT.md and the phase description:

| Implied ID | Description | Research Support |
|------------|-------------|------------------|
| H-01 | `classes/hunter/Hunter.lua` 完全重写为 Druid 对齐结构 | Section 3 (Druid Architecture Patterns) |
| H-02 | 新增 ~15 个技能方法，总计 ~25 个 skill methods | Section 1 (Skill Name Map) |
| H-03 | `classes/hunter/combo.lua` 新建，包含 5 个一键宏 | Section 3.4 (Combo Macro Pattern) |
| H-04 | hunterAtk 12-模块优先级链 + 距离路由 | Section 5.1 |
| H-05 | hunterAoe 距离路由（远程 Multi-Shot→Volley, 近战 Explosive→Immolation Trap） | Section 5.2 |
| H-06 | hunterDefend 极简 Deterrence 检查 | Section 5.3 |
| H-07 | hunterControl 距离路由（远程 Concussive/Scatter, 近战 Wing Clip/Freezing Trap） | Section 5.4 |
| H-08 | hunterMobTagging 距离路由 + PvP 过滤 + 自动衔接 | Section 5.5 |
| H-09 | Serpent Sting + Scorpid Sting SpellTrace 注册 (land trace) | Section 3.3 |
| H-10 | SelfTest: 基础设施 + ~25 技能 + 5 宏函数, isOptional=true | Section 3.5 |
| H-11 | `classes/hunter/combat.lua` + `classes/hunter/utility.lua` 废弃/删除 | Section 4 |
| H-12 | `build_order.txt` 添加 `classes/hunter/combo.lua` | Section 4 |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 技能释放 (_castSpell) | Player (entity/) | Hunter class (classes/) | Player 提供底层 _castSpell；Hunter 方法封装 locale 双表 |
| 距离路由 (≥8yd vs <8yd) | combo.lua (macro/classes) | — | 纯决策逻辑，无状态依赖 |
| Auto Shot 管理 | Player (entity/) | combo.lua | Player 提供 startAutoShoot/stopAutoShoot；combo 决定何时调用 |
| 钉刺 Land Trace | SpellTrace (core/) | Hunter 类注册 | SpellTrace 提供通用框架；Hunter 注册具体 spell |
| 目标选择 (targetEnemy) | Player (entity/) | combo.lua | Player 提供实现；combo 决定调用时机 |
| PvP 过滤 | combo.lua | — | 纯决策：check target.isPlayerControlled → ClearTarget() |
| 仇恨管理 (Disengage) | combo.lua | — | 参照 Druid otMod 模式，检查 threatPercent/isAttackingMe |
| Auto 攻击启动 | Player (entity/) | combo.lua | Player 提供 startAutoAtk/startAutoShoot |

---

## 1. Skill Name Map (en/zh Locale Pairs)

### 1.1 Confirmed Skills (existing in codebase -- VERIFIED)

These spell name pairs are confirmed from the existing `classes/hunter/Hunter.lua` lines 25-69:

| # | Skill Method | English Name | Chinese Name | Source |
|---|-------------|-------------|-------------|--------|
| 1 | `raptor_strike` | Raptor Strike | 猛禽一击 | [VERIFIED: classes/hunter/Hunter.lua:26-28] |
| 2 | `mongoose_bite` | Mongoose Bite | 猫鼬撕咬 | [VERIFIED: classes/hunter/Hunter.lua:29-31] |
| 3 | `arcane_shot` | Arcane Shot | 奥术射击 | [VERIFIED: classes/hunter/Hunter.lua:33-35] |
| 4 | `multi_shot` | Multi-Shot | 多重射击 | [VERIFIED: classes/hunter/Hunter.lua:37-39] |
| 5 | `hunters_mark` | Hunter's Mark | 猎人印记 | [VERIFIED: classes/hunter/Hunter.lua:41-43] |
| 6 | `serpent_sting` | Serpent Sting | 毒蛇钉刺 | [VERIFIED: classes/hunter/Hunter.lua:45-47] |
| 7 | `wing_clip` | Wing Clip | 摔绊 | [VERIFIED: classes/hunter/Hunter.lua:49-51] |
| 8 | `concussive_shot` | Concussive Shot | 震荡射击 | [VERIFIED: classes/hunter/Hunter.lua:53-55] |
| 9 | `disengage` | Disengage | 逃脱 | [VERIFIED: classes/hunter/Hunter.lua:58-60] |
| 10 | `call_pet` | Call Pet / Dismiss Pet | 召唤宠物 / 解散宠物 | [VERIFIED: classes/hunter/Hunter.lua:63-69] |

### 1.2 New Skills to Add (training data -- ASSUMED)

These names come from training data and are NOT yet verified against an authoritative source. User confirmation required before planning begins.

| # | Skill Method | English Name (ASSUMED) | Chinese Name (ASSUMED) | Type | Resource | Key Mechanics (ASSUMED) |
|---|-------------|----------------------|----------------------|------|----------|------------------------|
| 11 | `aimed_shot` | Aimed Shot | 瞄准射击 | A (enemy target) | Mana | 3s cast, 8-35yd, resets Auto Shot timer, 6s CD (Marksmanship talent) [ASSUMED] |
| 12 | `scorpid_sting` | Scorpid Sting | 毒蝎钉刺 | A (enemy target) | Mana | Instant, 8-35yd, reduces target's Strength and Agility [ASSUMED] |
| 13 | `viper_sting` | Viper Sting | 蝰蛇钉刺 | A (enemy target) | Mana | Instant, 8-35yd, drains mana [ASSUMED] |
| 14 | `scatter_shot` | Scatter Shot | 驱散射击 | A (enemy target) | Mana | Instant, 15yd range(?), 30s CD, confuses 4s, requires 21pt Marksmanship [ASSUMED] |
| 15 | `volley` | Volley | 乱射 | B (self -- channeled AoE) | Mana | Channeled 6s, 8-35yd, AoE damage [ASSUMED] |
| 16 | `immolation_trap` | Immolation Trap | 献祭陷阱 | B (self -- placed) | Mana | Instant, 15s CD? Fire DoT when triggered [ASSUMED] |
| 17 | `explosive_trap` | Explosive Trap | 爆炸陷阱 | B (self -- placed) | Mana | Instant, 15s CD? Fire AoE when triggered [ASSUMED] |
| 18 | `freezing_trap` | Freezing Trap | 冰冻陷阱 | B (self -- placed) | Mana | Instant, 30s CD? Freezes first enemy to approach for 20s [ASSUMED] |
| 19 | `frost_trap` | Frost Trap | 冰霜陷阱 | B (self -- placed) | Mana | Instant, 15s CD? Slows enemies in area [ASSUMED] |
| 20 | `deterrence` | Deterrence | 威慑 | B (self target) | None | Instant, 5min CD, 10s duration, +25% dodge +25% parry [ASSUMED] |
| 21 | `feign_death` | Feign Death | 假死 | B (self target) | None | Instant, 30s CD, drops all threat [ASSUMED] |
| 22 | `mend_pet` | Mend Pet | 治疗宠物 | B (pet target) | Mana | HoT on pet [ASSUMED] |
| 23 | `revive_pet` | Revive Pet | 复活宠物 | B (self target) | Mana | 10s cast, revives dead pet [ASSUMED] |
| 24 | `aspect_of_the_hawk` | Aspect of the Hawk | 雄鹰守护 | B (self target) | None | +ranged attack power [ASSUMED] |
| 25 | `aspect_of_the_monkey` | Aspect of the Monkey | 灵猴守护 | B (self target) | None | +dodge chance [ASSUMED] |
| 26 | `aspect_of_the_cheetah` | Aspect of the Cheetah | 猎豹守护 | B (self target) | None | +movement speed, dazed if hit [ASSUMED] |
| 27 | `rapid_fire` | Rapid Fire | 急速射击 | B (self target) | None | 5min CD, +40% ranged attack speed for 15s (Marksmanship talent) [ASSUMED] |

**Note on Auto Shot:** Auto Shot is NOT a castable spell. It is managed via `player.startAutoShoot()` / `player.stopAutoShoot()` (entity/Player.lua:231-241), which uses `macroTorch.findAutoShootActionSlot()`. No `_castSpell` wrapper needed. [VERIFIED: entity/Player.lua:231-241]

### 1.3 Skill Type Classification

Following Druid pattern (Druid.lua:24-254), skills classify as:

| Type | onSelf | Description | Hunter Examples |
|------|--------|-------------|-----------------|
| Type A | `false` | Enemy target only | Arcane Shot, Multi-Shot, Aimed Shot, Serpent/Scorpid/Viper Sting, Hunter's Mark, Concussive Shot, Scatter Shot, Raptor Strike, Mongoose Bite, Wing Clip |
| Type B | `true` | Self target only | Disengage, Deterrence, Feign Death, Revive Pet, Mend Pet, Aspect spells, Traps (placed), Volley (channeled on ground), Call Pet |
| Type B (pet) | N/A (pet.attack()) | Pet commands | Pet attack/mode -- NOT _castSpell |

---

## 2. Druid Architecture Patterns (Hunter Must Replicate)

### 2.1 Class Definition + Skill Method Pattern

[VERIFIED: classes/druid/Druid.lua:17-23, 25-38]

```lua
macroTorch.Druid = macroTorch.Player:new()

function macroTorch.Druid:new()
    local obj = {}
    setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))

    -- Type A skills: enemy target only (onSelf=false)
    function obj.claw(mode, rank)
        return obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
    end

    -- Type B skills: self target only (onSelf=true)
    function obj.bear_form(mode, rank)
        return obj._castSpell({ en = 'Bear Form', zh = '熊形态' }, mode, nil, nil, true, rank)
    end
    return obj
end
```

**Key observations for Hunter:**
- `_castSpell(localeNames, mode, range, resourceCost, onSelf, rank)` 签名:
  - `localeNames`: `{en='...', zh='...'}`
  - `mode`: nil = 'safe' (full checks), 'ready' = readiness-only, 'raw' = no checks [VERIFIED: entity/Player.lua:34-88]
  - `range`: nil = melee (no range check), number = max range in yards
  - `resourceCost`: nil = skip check, number = fixed cost, function = computed cost
  - `onSelf`: true = cast on self
  - `rank`: nil = highest, number = specific rank (1 = rank 1 for hunterMobTagging)
- Most Hunter skills have NO resource cost tracking (mana is not numerically modeled like energy/rage)
  - Exception: None for Hunter. `resourceCost` can be nil for all mana-using skills.
  - `range` matters: `8` for melee (Raptor Strike/Mongoose Bite check distance < 8), `30` for shots, nil for traps/self-buffs

### 2.2 FIELD_FUNC_MAP Pattern

[VERIFIED: classes/druid/Druid.lua: uses macroTorch.classMetatable; classes/hunter/Hunter.lua:75-78]

```lua
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props (add hunter-specific computed properties here)
    -- conditional props (lazy-computed via metatable)
}
```

Hunter currently has NO entries in HUNTER_FIELD_FUNC_MAP. This is fine for this phase -- no Hunter-specific computed properties are needed beyond what Player.lua already provides (distance, health, mana, isInCombat, targetEnemy, startAutoAtk, startAutoShoot, etc.)

### 2.3 SpellTrace Registration Pattern

[VERIFIED: classes/druid/Druid.lua:680-700]

```lua
-- spell trace + immune registration via SpellTrace:register() API
macroTorch.SpellTrace:register('Serpent Sting', {
    spellName = 'Serpent Sting', land = true,
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})
macroTorch.SpellTrace:register('Scorpid Sting', {
    spellName = 'Scorpid Sting', land = true,
    immune = true, debuffTexture = 'INV_Misc_QuestionMark'  -- TODO: verify texture
})
```

**SpellTrace:register() API signature** [VERIFIED: core/spell_trace_core.lua:49-66]:
- `name`: registration key
- `config.spellName`: must match name (guard invariant check at line 59-62)
- `config.land` (boolean): when true, calls `setSpellTracing(name)` → enables land event tracking
- `config.immune` (boolean): when true, calls `setTraceSpellImmune(name, debuffTexture)` → enables immune detection
- `config.debuffTexture` (string): debuff icon texture for immune tracing

**Hunter SpellTrace Task:**
- Existing Serpent Sting registration [VERIFIED: classes/hunter/Hunter.lua:84-86]: has `immune=true` and `debuffTexture='Ability_Hunter_SniperShot'` but MISSING `land=true` and `spellName` field
- Need to add `land=true` and `spellName='Serpent Sting'` per D-11
- Need to add NEW registration for `Scorpid Sting` with `land=true` per D-11
- CONTEXT.md explicitly says "Hunter's Mark 不 trace" (D-12) -- no need

### 2.4 Combo Macro Pattern (combo.lua Structure)

[VERIFIED: classes/druid/combo.lua:3-457]

**Key structural patterns for Hunter:**

**A) Entry routing (druidAtk → per-form sub-macro):**
```lua
function macroTorch.druidAtk()
    if macroTorch.player.isInCatForm then
        macroTorch.catAtk()
    elseif macroTorch.player.isInBearForm then
        macroTorch.bearAtk()
    else
        macroTorch.casterAtk()
    end
end
```

Hunter equivalent:
```lua
function macroTorch.hunterAtk()
    if macroTorch.target.distance < 8 then
        macroTorch.hunterAtkMelee()
    else
        macroTorch.hunterAtkRanged()
    end
end
```

**B) Simple combo macro (druidAoe -- ~20 lines):**
```lua
function macroTorch.druidAoe()
    if macroTorch.player.isInBearForm then
        macroTorch.bearAoe()
    elseif macroTorch.player.isInCatForm then
        return
    elseif macroTorch.isSpellExist('Hurricane', 'spell')
            and macroTorch.player.humanFormMana >= 880 then
        macroTorch.player.hurricane('ready')
    end
end
```

**C) Control macro with target selection (druidControl -- ~30 lines):**
```lua
function macroTorch.druidControl()
    local target = macroTorch.target
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then return end
    end
    -- ...form cancellation... then control logic
end
```

**D) MobTagging with PvP guard (druidMobTagging -- ~70 lines):**
```lua
function macroTorch.druidMobTagging()
    -- ...caster/melee branches...
    if target.isCanAttack and target.isPlayerControlled then
        ClearTarget()
    end
    -- ...tag logic...then:
    if target.isAttackingMe then
        macroTorch.druidAtk()
    end
end
```

**E) Module priority chain (catAtk -- ~130 lines):**
```lua
function macroTorch.catAtk()
    local clickContext = {}
    -- ...cache setup...
    -- 0. recoverNormalRelic
    -- 1. combatUrgentHPRestore
    -- 2. targetEnemy
    -- 3. startAutoAtk
    -- 4. burstMod(clickContext)
    -- 5. openerMod
    -- 6. oocMod
    -- 7. termMod
    -- 8. otMod
    -- 9. keepTigerFury
    -- 10. debuffMod (keepRip, keepRake, keepFF)
    -- 11. regularAttack
    -- 12. reshiftMod
end
```

**F) isFightStarted caching pattern** [VERIFIED: classes/druid/Druid.lua:817-827]:
```lua
function macroTorch.isFightStarted(clickContext)
    if clickContext.isFightStarted == nil then
        clickContext.isFightStarted = (not clickContext.prowling and
            (macroTorch.player.isInCombat
                or macroTorch.target.isPlayerControlled
                or (macroTorch.target.isHostile and macroTorch.target.isInCombat)))
            or (clickContext.prowling and macroTorch.target.isAttackingMe)
    end
    return clickContext.isFightStarted
end
```

Hunter needs a similar `isFightStarted` but without prowling (Hunters don't prowl). The check can be simpler: `player.isInCombat or (target.isHostile and target.isInCombat)` or the existing `macroTorch.isFightStarted` can be reused as-is since it already defines this pattern and a Hunter without prowling will just take the first branch.

### 2.5 SelfTest Registration Pattern

[VERIFIED: classes/druid/Druid.lua:91-156, classes/hunter/Hunter.lua:88-156]

```lua
-- Infrastructure tests
macroTorch.SelfTest:register("Hunter: HUNTER_FIELD_FUNC_MAP is table", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.HUNTER_FIELD_FUNC_MAP) == "table", "HUNTER_FIELD_FUNC_MAP is not a table")
end, true)

-- Skill method existence tests
macroTorch.SelfTest:register("Hunter: skill method raptor_strike exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunter.raptor_strike) == "function", "raptor_strike is not a function")
end, true)
```

**Pattern rules:**
- `macroTorch.SelfTest:register(name, fn, isOptional)` API [VERIFIED: core/selftest.lua]
- Test function name format: `"ClassName: description"`
- Guard: `if UnitClass('player') ~= 'ClassName' then return end` at function start
- `isOptional = true` for all class-specific tests
- Infrastructure tests: FIELD_FUNC_MAP, singleton, PLAYER_CLASS_REGISTRY (3 tests) [VERIFIED: Hunter.lua:92-105]
- Skill existence tests: one per skill method (~25 tests)
- Combo function existence tests: one per macro function (5 tests: hunterAtk, hunterAoe, hunterDefend, hunterControl, hunterMobTagging) [VERIFIED: combo.lua:414-457]

---

## 3. Existing Hunter Code Analysis

### 3.1 Current State Assessment

[VERIFIED by reading classes/hunter/Hunter.lua, classes/hunter/combat.lua, classes/hunter/utility.lua]

**Hunter.lua (156 lines):**
- Class definition: ✓ `macroTorch.Hunter = macroTorch.Player:new()` with `classMetatable` [line 17-22]
- 10 skill methods: raptor_strike, mongoose_bite, arcane_shot, multi_shot, hunters_mark, serpent_sting, wing_clip, concussive_shot, disengage, call_pet [lines 25-69]
- FIELD_FUNC_MAP: empty table (correct for now) [lines 75-78]
- singleton: `macroTorch.hunter = macroTorch.Hunter:new()` [line 80]
- registerPlayerClass: ✓ [line 81]
- SpellTrace: Serpent Sting with `immune=true, debuffTexture='Ability_Hunter_SniperShot'` -- MISSING `land=true` [lines 84-86]
- SelfTest: infrastructure (3) + skill methods (10) = 13 tests with isOptional=true [lines 88-156]

**combat.lua (74 lines):**
- `macroTorch.hunterAtk()`: basic prototype with distance routing (<8yd melee / >=8yd ranged) [lines 18-51]
- `macroTorch.htOtMod()`: otMod prototype using Disengage + Invulnerability Potion [lines 53-74]
- Uses `clickContext` but only for energy costs (RAPTOR_E, MONGOOSE_E, etc.)
- Calls `pet.attack()`, `player.startAutoShoot()`, `player.hunters_mark('ready')`, etc.
- **Problems:** pet management (violates D-08), uses old energy cost model, no module chain

**utility.lua (32 lines):**
- `macroTorch.hunterSting()`: checks if target lacks Serpent Sting debuff, then casts [lines 18-24]
- `macroTorch.hunterCtrl()`: distance routing for Wing Clip/Concussive Shot [lines 26-32]

### 3.2 What to Keep vs Replace

| Component | Action | Rationale |
|-----------|--------|-----------|
| Hunter.lua class definition framework | KEEP skeleton, rewrite skill methods | classMetatable + singleton + registerPlayerClass are correct |
| Existing 10 skill methods | KEEP names/locale tables, may refine | Locale tables verified |
| HUNTER_FIELD_FUNC_MAP | KEEP (empty) | No Hunter-specific computed properties needed |
| Serpent Sting SpellTrace | MODIFY: add `land=true` and `spellName` | Per D-11 |
| All SelfTest registrations | REWRITE: expand from 13 to ~33 tests | Add ~15 skill tests + 5 combo function tests |
| combat.lua | DELETE / ABANDON | Complete rewrite as combo.lua |
| utility.lua | DELETE / ABANDON | Logic distributed into combo.lua |

### 3.3 Files to Create / Modify / Delete

| File | Action | New Size (est.) |
|------|--------|-----------------|
| `classes/hunter/Hunter.lua` | Complete rewrite | ~350 lines |
| `classes/hunter/combo.lua` | CREATE | ~350 lines |
| `classes/hunter/combat.lua` | DELETE (or empty stub) | — |
| `classes/hunter/utility.lua` | DELETE (or empty stub) | — |
| `build_order.txt` | EDIT: add `classes/hunter/combo.lua` after `classes/hunter/Hunter.lua` | +1 line |

**build_order.txt update** [VERIFIED: build_order.txt:37-39]:
```
classes/hunter/Hunter.lua
classes/hunter/combo.lua       # ADD this line
# Remove these lines:
# classes/hunter/combat.lua    # REMOVE
# classes/hunter/utility.lua   # REMOVE
```

---

## 4. Technical Verification Results

### 4.1 Auto Shot Infrastructure

[VERIFIED: entity/Player.lua:231-241]

```lua
function obj.startAutoShoot()
    if not obj.isAutoShooting then
        UseAction(macroTorch.findAutoShootActionSlot())
    end
end
function obj.stopAutoShoot()
    if obj.isAutoShooting then
        UseAction(macroTorch.findAutoShootActionSlot())
    end
end
```

`isAutoShooting` is computed via FIELD_FUNC_MAP [VERIFIED: entity/Player.lua:616-617]:
```lua
['isAutoShooting'] = function(self)
    return (IsAutoRepeatAction(macroTorch.findAutoShootActionSlot()) == 1)
end
```

`findAutoShootActionSlot()` caches result in `macroTorch.context.autoShootSlot` [VERIFIED: biz_util.lua:119-138].

**Call pattern for hunterAtk:**
```lua
player.startAutoShoot()  -- Called every keystroke per D-04
```

### 4.2 isFightStarted for Hunter

The existing `macroTorch.isFightStarted(clickContext)` [VERIFIED: classes/druid/Druid.lua:817-827] works for Hunter without modification. Since Hunter has no `prowling` state, `clickContext.prowling` will always be nil/false, causing the first branch:
```lua
(not clickContext.prowling and (player.isInCombat or target.isPlayerControlled or (target.isHostile and target.isInCombat)))
```

This is correct Hunter behavior. No need to redefine.

### 4.3 targetEnemy Implementation

[VERIFIED: entity/Player.lua:205-214]

```lua
function obj.targetEnemy()
    if not macroTorch.target.isCanAttack then
        if macroTorch.target.isFriendly and macroTorch.targettarget.isCanAttack then
            AssistUnit('target')
        else
            ClearTarget()
            TargetNearestEnemy()
        end
    end
end
```

### 4.4 isAttackingMe / isCanAttack / isPlayerControlled

[VERIFIED: entity/Unit.lua:186-209]

- `isCanAttack`: `UnitExists(t) and not UnitIsDead(t) and UnitCanAttack('player', t)`
- `isPlayerControlled`: `UnitIsPlayer(self.ref) or UnitPlayerControlled(self.ref)`
- `isAttackingMe`: `isCanAttack and UnitName("player") == UnitName(t .. "target")`

These are used extensively in hunterMobTagging for PvP filtering and tag confirmation.

### 4.5 Casting Mode Parameter Behaviors

[VERIFIED: entity/Player.lua:34-88 -- _castSpell implementation]

| mode | Readiness check | Range check | Resource check |
|------|----------------|-------------|----------------|
| nil (default) | ✓ | ✓ | ✓ |
| 'ready' | ✓ | ✗ | ✗ |
| 'raw' | ✗ | ✗ | ✗ |

For Hunter skills:
- `nil` (default/safe): use for most skills -- ensures spell is ready and target is in range
- `'ready'`: use when you only care if spell is cooled down (e.g., checking if Aimed Shot CD is up)
- `'raw'`: use when you want to bypass ALL checks (e.g., force-casting a buff)

### 4.6 Hunter Skill Mechanics (ASSUMED from training data)

These mechanics are NOT verified against official sources and need user confirmation:

| Mechanic | Detail | Impact on Implementation |
|----------|--------|--------------------------|
| Auto Shot + Arcane Shot | Arcane Shot is instant, does NOT reset Auto Shot timer | Can safely call arcane_shot() every cycle |
| Auto Shot + Multi-Shot | Multi-Shot is instant(?), may slightly clip Auto Shot | Call multi_shot() between auto shots |
| Auto Shot + Aimed Shot | Aimed Shot 3s cast RESETS Auto Shot timer | Why D-05 puts Aimed Shot on Shift (manual, not auto) |
| Wing Clip | Instant melee, deals damage + 50% slow for 10s | Prefer over Raptor Strike for hunterMobTagging |
| Arcane Shot R1 | Instant, 30yd range, lowest mana cost | Ideal for hunterMobTagging ranged |
| Concussive Shot | Instant(?), 20% slow for 4s, no CD(?) | Primary ranged control |
| Scatter Shot | Instant, 15yd(?) range, 30s CD, 4s confuse, requires 21pt Marksmanship | Secondary ranged control, talent-gated |
| Concussive & Scatter | NOT shared CD, independent cooldowns | Can use both in hunterControl |
| Deterrence | Instant, 5min CD, 10s duration, +25% dodge + ~25% parry | hunterDefend checks isSpellReady('Deterrence') |
| Traps | Instant cast, placed at feet, triggered by proximity, 15-30s CD | hunterAoe/hunterControl can place traps anytime |
| Volley | Channeled 6s, AoE damage over area | Must not be interrupted by other actions |
| Feign Death | Instant, 30s CD, drops ALL aggro | User considers NOT defensive; kept as skill method only |
| Hunter Dead Zone | 5-8yd: neither melee nor ranged work in vanilla | Per D-03: ignored, <8yd = melee |
| Pet Basics | pet.attack() starts pet attacking | User manages pet manually per D-08, but pet.attack() available in entity/Pet.lua:28-30 |

---

## 5. Implementation Guidance

### 5.1 hunterAtk -- 12-Module Priority Chain with Distance Routing

This is the most complex function (~200-250 lines). Pattern reference: catAtk (combo.lua:49-181).

**Proposed module order and structure:**

```lua
function macroTorch.hunterAtk()
    if macroTorch.target.distance < 8 then
        return macroTorch.hunterAtkMelee()
    else
        return macroTorch.hunterAtkRanged()
    end
end

function macroTorch.hunterAtkRanged()
    local clickContext = {}
    -- cache: isInCombat, isFightStarted, etc.
    -- 1. combatUrgentHPRestore (reuse macroTorch.combatUrgentHPRestore or inline HP check)
    -- 2. targetEnemy
    -- 3. startAutoShoot (every keystroke per D-04)
    -- 4. burstMod (Shift trigger: trinkets, Rapid Fire, Aimed Shot per D-05)
    -- 5. openerMod (Hunter's Mark → if not already marked)
    -- 6. stingMod (Serpent Sting → Scorpid Sting -- check buff debuff textures)
    -- 7. coreDPSMod (Arcane Shot → Multi-Shot, with isSpellExist guards)
    -- 8. rangeManagementMod (Disengage if target in dead zone/too close)
    -- Items past here: otMod, cleanup, end-of-cycle fillers
end

function macroTorch.hunterAtkMelee()
    local clickContext = {}
    -- 1. combatUrgentHPRestore
    -- 2. targetEnemy
    -- 3. startAutoAtk (melee auto-attack, reuse existing Player.startAutoAtk)
    -- 4. burstMod
    -- 5. coreMeleeMod (Raptor Strike → Mongoose Bite)
    -- 6. otMod
end
```

**clickContext fields for ranged:**
```lua
clickContext = {
    isFightStarted,
    playerUrgentHPThreshold = 15,
    isInCombat,
    isTargetDummy,
    -- No energy/rage tracking needed (Hunter uses mana, not modeled numerically)
}
```

**Key verification:**
- The `isFightStarted(clickContext)` check gates modules 3-12
- `targetEnemy()` should be called BEFORE startAutoShoot (you need a target to shoot at)
- `startAutoShoot()` should be called EVERY keystroke (D-04) after target selection
- `burstMod()` pattern: check `IsShiftKeyDown()`, then sequence through trinkets/items/Aimed Shot

### 5.2 hunterAoe -- ~20 Lines

```lua
function macroTorch.hunterAoe()
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not macroTorch.target.isCanAttack then return end
    end

    if macroTorch.target.distance < 8 then
        -- Melee AoE: traps (placed at feet, AoE when triggered)
        if macroTorch.isSpellExist('Explosive Trap', 'spell')
                and macroTorch.player.isSpellReady('Explosive Trap') then
            macroTorch.player.explosive_trap('ready')
        elseif macroTorch.isSpellExist('Immolation Trap', 'spell')
                and macroTorch.player.isSpellReady('Immolation Trap') then
            macroTorch.player.immolation_trap('ready')
        end
    else
        -- Ranged AoE
        macroTorch.player.startAutoShoot()
        if macroTorch.isSpellExist('Multi-Shot', 'spell') then
            macroTorch.player.multi_shot('ready')
        end
        if macroTorch.isSpellExist('Volley', 'spell')
                and macroTorch.player.isSpellReady('Volley') then
            macroTorch.player.volley('ready')
        end
    end
end
```

### 5.3 hunterDefend -- ~5 Lines

```lua
function macroTorch.hunterDefend()
    if macroTorch.isSpellExist('Deterrence', 'spell')
            and macroTorch.player.isSpellReady('Deterrence') then
        macroTorch.player.deterrence('ready')
    end
end
```

Per D-14: only Deterrence. Reversible design -- future extensions add more checks before Deterrence.

### 5.4 hunterControl -- ~30 Lines

```lua
function macroTorch.hunterControl()
    local target = macroTorch.target
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then return end
    end

    if target.distance < 8 then
        -- Melee control: Wing Clip (immediate damage + slow) or Freezing Trap
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            macroTorch.player.wing_clip('ready')
        end
        if macroTorch.isSpellExist('Freezing Trap', 'spell')
                and macroTorch.player.isSpellReady('Freezing Trap') then
            macroTorch.player.freezing_trap('ready')
        end
    else
        -- Ranged control: Concussive Shot (slow) or Scatter Shot (confuse, talent-gated)
        if macroTorch.isSpellExist('Concussive Shot', 'spell') then
            macroTorch.player.concussive_shot('ready')
        end
        if macroTorch.isSpellExist('Scatter Shot', 'spell') then
            macroTorch.player.scatter_shot('ready')
        end
    end
end
```

### 5.5 hunterMobTagging -- ~60 Lines

```lua
function macroTorch.hunterMobTagging()
    local player = macroTorch.player
    local target = macroTorch.target

    -- PvP filter per D-18
    if not target.isCanAttack or target.isPlayerControlled then
        player.targetEnemy()
        if target.isCanAttack and target.isPlayerControlled then
            ClearTarget()
        end
        return
    end

    if target.distance < 8 then
        -- Melee tag: Wing Clip (D-17)
        if macroTorch.isSpellExist('Wing Clip', 'spell') then
            player.wing_clip('ready')
        end
        -- Fallback: start melee auto attack
        player.startAutoAtk()
    else
        -- Ranged tag: Arcane Shot rank 1 (D-16)
        player.startAutoShoot()
        if macroTorch.isSpellExist('Arcane Shot', 'spell') then
            player.arcane_shot('ready', 1)  -- rank 1, lowest mana
        end
    end

    -- Auto-chain to hunterAtk if tag confirmed (D-19)
    if target.isAttackingMe then
        macroTorch.hunterAtk()
    end
end
```

---

## 6. Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto Shoot start/stop | Don't write new CastSpellByName("Auto Shot") | `player.startAutoShoot()` / `player.stopAutoShoot()` | Already implemented with cached action slot lookup [VERIFIED: entity/Player.lua:231-241] |
| Spell target range check | Don't write custom distance math | `_castSpell(mode, range)` where range = 30 for shots, nil for melee | Built-in `_isInRange(range)` in _castSpell flow [VERIFIED: entity/Player.lua:94-102] |
| Spell readiness + CD check | Don't write custom cooldown tracking | `_castSpell(mode)` with mode=nil/'ready' | Built-in `isSpellReady()` + GCD check [VERIFIED: entity/Player.lua:42-57] |
| Sting land tracking | Don't write custom cast monitoring | `SpellTrace:register(name, {land=true, ...})` | Declarative API, existing framework [VERIFIED: core/spell_trace_core.lua:49-66] |
| Target selection | Don't write custom Tab-target logic | `player.targetEnemy()` | Handles AssistUnit fallback, PvP/PvE [VERIFIED: entity/Player.lua:205-214] |
| Sting debuff detection | Don't write custom buff scanning | `target.buffed('Serpent Sting', 'Ability_Hunter_SniperShot')` | Unit buff texture matching |

---

## 7. Common Pitfalls

### Pitfall 1: Missing `spellName` in SpellTrace:register
**What goes wrong:** SpellTrace:register with `land=true` but without `spellName` field → land trace silently fails because failTable is keyed by chat-parsed spell name, and the registration name key must match.
**Why it happens:** The existing Serpent Sting registration (Hunter.lua:84-86) uses the old-style `{immune=true, debuffTexture='...'}` without `land=true` and without `spellName`. When adding `land=true`, must also add `spellName='Serpent Sting'`.
**How to avoid:** Follow Druid pattern exactly: `SpellTrace:register('SpellName', {spellName='SpellName', land=true, immune=true, debuffTexture='...'})`.
**Warning signs:** Land events not firing for Serpent Sting after Phase 25 deploy.

### Pitfall 2: Auto Shot Called Before Target Selection
**What goes wrong:** `startAutoShoot()` called when `not target.isCanAttack` → no target to shoot at, auto shot may start but fire into nothing.
**How to avoid:** Ensure targetEnemy() module (module 2) runs BEFORE startAutoShoot module (module 3). Follow catAtk order: 1.urgent restore → 2.targetEnemy → 3.startAutoAtk.

### Pitfall 3: Aimed Shot Automatically Firing During Auto Shot
**What goes wrong:** Including Aimed Shot in auto-rotation → 3s cast resets Auto Shot timer → significant DPS loss.
**How to avoid:** Aimed Shot ONLY in burstMod (Shift-gated, D-05). Never in coreDPSMod.

### Pitfall 4: Traps in hunterAtk Module Chain
**What goes wrong:** Adding trap logic to hunterAtk → traps placed incorrectly during movement, wasted mana, poor positioning.
**How to avoid:** D-06 explicitly says no traps in hunterAtk. Traps only in hunterAoe (damage traps) and hunterControl (Freezing Trap).

### Pitfall 5: Calling Pet Functions in hunterAtk
**What goes wrong:** Old combat.lua calls `pet.attack()` in hunterAtk → violates D-08 (no pet management).
**How to avoid:** Strip ALL pet logic from hunterAtk and child functions. Pet management is user's responsibility.

### Pitfall 6: build_order.txt Not Updated
**What goes wrong:** combo.lua created but not added to build_order.txt → functions not available in SM_Extend.lua build.
**How to avoid:** Add `classes/hunter/combo.lua` line immediately after `classes/hunter/Hunter.lua` in build_order.txt. Confirm with `grep` before building.

---

## 8. Code Examples (Patterns from Druid Reference)

### 8.1 Skill Method Definition (Type A -- enemy target)

[VERIFIED: classes/druid/Druid.lua:25-27]
```lua
function obj.claw(mode, rank)
    return obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
end
```
Hunter equivalent (no resource cost, with range):
```lua
function obj.arcane_shot(mode, rank)
    return obj._castSpell({ en = 'Arcane Shot', zh = '奥术射击' }, mode, 30, nil, false, rank)
end
```

### 8.2 Skill Method Definition (Type B -- self target)

[VERIFIED: classes/druid/Druid.lua:128-129]
```lua
function obj.bear_form(mode, rank)
    return obj._castSpell({ en = 'Bear Form', zh = '熊形态' }, mode, nil, nil, true, rank)
end
```
Hunter equivalent (trap, self-placed):
```lua
function obj.immolation_trap(mode, rank)
    return obj._castSpell({ en = 'Immolation Trap', zh = '献祭陷阱' }, mode, nil, nil, true, rank)
end
```

### 8.3 SpellTrace Registration Pattern

[VERIFIED: classes/druid/Druid.lua:681-684]
```lua
macroTorch.SpellTrace:register('Pounce', {
    spellName = 'Pounce', land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
```
Hunter equivalent:
```lua
macroTorch.SpellTrace:register('Serpent Sting', {
    spellName = 'Serpent Sting', land = true,
    immune = true, debuffTexture = 'Ability_Hunter_SniperShot'
})
macroTorch.SpellTrace:register('Scorpid Sting', {
    spellName = 'Scorpid Sting', land = true,
    immune = true, debuffTexture = 'INV_Misc_QuestionMark'  -- TODO: verify exact texture
})
```

### 8.4 Combo Macro SelfTest Registration

[VERIFIED: classes/druid/combo.lua:414-457]
```lua
macroTorch.SelfTest:register("Hunter: combo methods -- hunterAtk exists", function()
    if UnitClass('player') ~= 'Hunter' then return end
    assert(type(macroTorch.hunterAtk) == "function", "hunterAtk not a function")
end, true)
```

### 8.5 burstMod with Shift Key Check

[VERIFIED: classes/druid/cat.lua:2-44]
```lua
function macroTorch.burstMod(clickContext)
    if IsShiftKeyDown() then
        if not macroTorch.context.burstFlags then
            macroTorch.context.burstFlags = {}
        end
    end
    if macroTorch.context.burstFlags then
        local flags = macroTorch.context.burstFlags
        -- burst items/abilities here, each setting a flag and returning
        if not flags.aimedShot then
            if macroTorch.isSpellExist('Aimed Shot', 'spell') then
                macroTorch.player.aimed_shot('ready')
            end
            flags.aimedShot = true
            return
        end
        -- ... trinkets ...
    end
end
```

---

## 9. Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase involves only Lua code within the existing addon -- no new tools, services, runtimes, or CLI utilities beyond what Phase 24 already uses.

---

## 10. Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (custom Lua test framework in core/selftest.lua) |
| Config file | none -- logic is inline registration at file bottom |
| Quick run command | Login to WoW, observe chat frame for `[macro-torch] Self-test: X passed, Y failed` |
| Full suite command | Same -- SelfTest runs on every PLAYER_ENTERING_WORLD |

### Phase Requirements → Test Map

| Implied ID | Behavior | Test Type | SelfTest Name | File Exists? |
|------------|----------|-----------|---------------|-------------|
| H-02 | All 25 skill methods exist on hunter singleton | unit | `"Hunter: skill method {name} exists"` (x25) | ✅ 10 exist, 15 to add |
| H-03 | All 5 combo functions exist as global functions | unit | `"Hunter: combo methods -- hunter{Aoe/Defend/Control/MobTagging} exists"` (x5) | ❌ Wave 0 |
| H-01 | HUNTER_FIELD_FUNC_MAP is a table | unit | `"Hunter: HUNTER_FIELD_FUNC_MAP is table"` | ✅ exists |
| H-01 | macroTorch.hunter singleton exists | unit | `"Hunter: singleton hunter exists"` | ✅ exists |
| H-01 | Hunter registered in PLAYER_CLASS_REGISTRY | unit | `"Hunter: registered in PLAYER_CLASS_REGISTRY"` | ✅ exists |
| H-09 | Serpent Sting + Scorpid Sting SpellTrace registered | manual | N/A (SpellTrace not covered by SelfTest) | ❌ Manual verification |

### Wave 0 Gaps
- [ ] `classes/hunter/combo.lua` -- CREATE (0 lines → ~350 lines)
- [ ] `classes/hunter/Hunter.lua` -- REWRITE (add 15 new skill methods + update SpellTrace + expand SelfTest)
- [ ] Combo function SelfTest registrations (5 tests) -- ADD to combo.lua (following Druid pattern at combo.lua:414-457)
- [ ] New skill method SelfTest registrations (~15 tests) -- ADD to Hunter.lua

*(Existing infrastructure tests for HUNTER_FIELD_FUNC_MAP, singleton, and PLAYER_CLASS_REGISTRY are already in place.)*

---

## 11. Security Domain

`security_enforcement` is NOT explicitly set to `false` in config.json → enabled by default.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | WoW Client handles authentication |
| V3 Session Management | no | WoW Client manages sessions |
| V4 Access Control | no | WoW Client enforces spell availability |
| V5 Input Validation | yes | All spell names passed via `_castSpell` locale table selectors -- no user-supplied strings |
| V6 Cryptography | no | No cryptographic operations |
| V7 Error Handling/Logging | no | Addon-level, no sensitive data |

### Known Threat Patterns for WoW Lua Addon

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Targeting incorrect unit (PvP flag) | Information Disclosure / Repudiation | PvP filter per D-18: check `target.isPlayerControlled` before hostile actions |
| Spell name locale mismatch | Denial of Service | All skill names use dual-locale tables `{en, zh}`, validated by SelfTest |
| Race condition in clickContext | Elevation of Privilege | clickContext is local per-keystroke, no shared mutable state |
| SpellTrace key mismatch | Information Disclosure | `spellName` guard invariant check [VERIFIED: core/spell_trace_core.lua:59-62] |

---

## 12. Skill Deubff Textures Reference

For SpellTrace and `buffed()` checks, the following textures (ASSUMED, need user verification):

| Spell | Texture | Used For |
|-------|---------|----------|
| Serpent Sting | `Ability_Hunter_SniperShot` | SpellTrace immune detection [VERIFIED: Hunter.lua:85] |
| Hunter's Mark | `Ability_Hunter_SniperShot` (same as Serpent Sting? verify) | `buffed('Hunters Mark', texture)` check |
| Scorpid Sting | `Spell_Nature_Curse` or similar (ASSUMED) | SpellTrace land detection per D-11 |

---

## 13. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Aimed Shot = 'Aimed Shot' / '瞄准射击' -- English/Chinese locale names | 1.2 | Wrong spell name → _castSpell fails on zhCN locale |
| A2 | Scorpid Sting = 'Scorpid Sting' / '毒蝎钉刺' | 1.2 | Wrong name → Serpent Sting debuff check fails |
| A3 | Viper Sting = 'Viper Sting' / '蝰蛇钉刺' | 1.2 | Wrong name → spell method unusable |
| A4 | Scatter Shot = 'Scatter Shot' / '驱散射击' | 1.2 | Wrong name → hunterControl ranged fails |
| A5 | Volley = 'Volley' / '乱射' | 1.2 | Wrong name → hunterAoe Volley path broken |
| A6 | Immolation Trap = 'Immolation Trap' / '献祭陷阱' | 1.2 | Wrong name → hunterAoe melee fails |
| A7 | Explosive Trap = 'Explosive Trap' / '爆炸陷阱' | 1.2 | Wrong name → hunterAoe melee fails |
| A8 | Freezing Trap = 'Freezing Trap' / '冰冻陷阱' | 1.2 | Wrong name → hunterControl melee fails |
| A9 | Frost Trap = 'Frost Trap' / '冰霜陷阱' | 1.2 | Wrong name → skill method unusable |
| A10 | Deterrence = 'Deterrence' / '威慑' | 1.2 | Wrong name → hunterDefend completely broken |
| A11 | Feign Death = 'Feign Death' / '假死' | 1.2 | Wrong name → skill method unusable (low risk per D-14) |
| A12 | Mend Pet = 'Mend Pet' / '治疗宠物' | 1.2 | Wrong name → skill method unusable (low risk per D-08) |
| A13 | Revive Pet = 'Revive Pet' / '复活宠物' | 1.2 | Wrong name → skill method unusable (low risk per D-08) |
| A14 | Aspect of the Hawk/Monkey/Cheetah locale names | 1.2 | Wrong names → skill methods unusable (low risk per D-07) |
| A15 | Rapid Fire = 'Rapid Fire' / '急速射击' | 1.2 | Wrong name → burstMod Rapid Fire path broken |
| A16 | Arcane Shot rank 1 is instant, 30yd, low mana -- mechanics | 4.6 | Wrong mechanics → hunterMobTagging ranged suboptimal |
| A17 | Wing Clip is instant melee with damage + 50% slow -- mechanics | 4.6 | Wrong mechanics → hunterMobTagging melee fails to tag |
| A18 | Multi-Shot is instant and does NOT reset Auto Shot -- mechanics | 4.6 | Wrong mechanics → DPS rotation suboptimal |
| A19 | Concussive Shot and Scatter Shot do NOT share a cooldown | 4.6 | Wrong → hunterControl could use both simultaneously |
| A20 | Scorpid Sting debuff texture (for SpellTrace immune detection) | 12 | Wrong texture → immune detection broken for Scorpid Sting |
| A21 | Hunter's Mark debuff texture (for `buffed()` check in openerMod) | 12 | Wrong texture → openerMod repeatedly casts Hunter's Mark |
| A22 | Deterrence is on a 5-minute cooldown | 4.6 | Wrong CD → hunterDefend check logic wrong |
| A23 | Scatter Shot requires 21pt Marksmanship talent (talent-gated) | 4.6 | Wrong → `isSpellExist('Scatter Shot')` guard important |
| A24 | Volley is channeled, 6s duration | 4.6 | Wrong → Volley in hunterAoe may need special handling to avoid interrupt |
| A25 | Trap spells are instant cast but may have a short arming time | 4.6 | Wrong → traps may not be available for immediate AoE |

**If this table is empty:** False -- 25 assumptions need user confirmation.

---

## 14. Open Questions

1. **Scorpid Sting debuff texture**
   - What we know: Serpent Sting uses `Ability_Hunter_SniperShot` (VERIFIED). Scorpid Sting texture unknown.
   - What's unclear: Exact texture for `buffed('Scorpid Sting', texture)` and SpellTrace immune detection.
   - Recommendation: User confirms in-game or planner uses a placeholder texture and flags for verification.

2. **Hunter's Mark debuff texture for `buffed()` check**
   - What we know: Hunter's Mark is NOT spell-traced (D-12). But for `buffed()` check in openerMod, need texture.
   - What's unclear: Whether Hunter's Mark uses `Ability_Hunter_SniperShot` (same as Serpent Sting) or a different texture.
   - Recommendation: User confirms texture. If same as Serpent Sting, `buffed()` check may be ambiguous -- need to distinguish Hunter's Mark from Serpent Sting.

3. **Scatter Shot availability without Marksmanship talents**
   - What we know: Training data says 21pt Marksmanship requirement.
   - What's unclear: Confirm with user about their talent build. If no Marksmanship, Scatter Shot guard (`isSpellExist`) will handle it gracefully.
   - Recommendation: Code with `isSpellExist('Scatter Shot', 'spell')` guard -- handles talent-gating automatically.

4. **Volley minimum range**
   - What we know: Volley is channeled AoE, placed at target location.
   - What's unclear: Does Volley have a minimum range in 1.12? If <8yd minimum, can't use at melee range.
   - Recommendation: Volley only called in ranged branch of hunterAoe (≥8yd), so minimum range concern is moot.

5. **Trap shared cooldown**
   - What we know: Training data suggests traps may share a cooldown category.
   - What's unclear: If you place Freezing Trap, does it prevent placing Explosive Trap immediately?
   - Recommendation: Use `isSpellReady()` checks on each trap call -- CD handling is transparent.

6. **hunterAtk melee branch: Raptor Strike vs Mongoose Bite priority**
   - What we know: Raptor Strike is the primary melee attack (weapon damage + bonus); Mongoose Bite is reactive (only usable after dodge).
   - What's unclear: Should coreMeleeMod try Raptor Strike first, then Mongoose Bite? Or is Mongoose Bite conditional-only?
   - Recommendation: Raptor Strike first (always available), Mongoose Bite as conditional fallback. Check `isSpellReady` handles Mongoose Bite's conditional availability.

---

## 15. Sources

### Primary (HIGH confidence -- from codebase verification)
- [VERIFIED: classes/druid/combo.lua:1-457] -- Complete Druid combo macro patterns (druidAtk, catAtk, casterAtk, druidAoe, druidHeal, druidDefend, druidControl, druidCharge, druidMobTagging)
- [VERIFIED: classes/druid/Druid.lua:1-1453] -- Druid class definition, ~40 skill methods, FIELD_FUNC_MAP, isFightStarted, combatUrgentHPRestore, SpellTrace registrations, SelfTest
- [VERIFIED: classes/druid/cat.lua:1-100] -- burstMod, otMod, regularAttack patterns
- [VERIFIED: classes/hunter/Hunter.lua:1-156] -- Existing Hunter class definition, 10 skill methods with verified locale tables, SpellTrace, SelfTest
- [VERIFIED: classes/hunter/combat.lua:1-74] -- Existing (deprecated) hunterAtk and htOtMod prototypes
- [VERIFIED: classes/hunter/utility.lua:1-32] -- Existing (deprecated) hunterSting and hunterCtrl prototypes
- [VERIFIED: entity/Player.lua:34-88] -- _castSpell implementation with locale/mode/range/resourceCost/onSelf/rank parameters
- [VERIFIED: entity/Player.lua:205-214] -- targetEnemy implementation
- [VERIFIED: entity/Player.lua:231-241] -- startAutoShoot/stopAutoShoot implementation
- [VERIFIED: entity/Player.lua:616-617] -- isAutoShooting computed field
- [VERIFIED: entity/Unit.lua:186-224] -- isCanAttack, isPlayerControlled, isAttackingMe, isNearBy definitions
- [VERIFIED: core/spell_trace_core.lua:41-66] -- SpellTrace:register API signature and config fields {spellName, land, immune, debuffTexture}
- [VERIFIED: core/selftest.lua] -- SelfTest:register API (name, fn, isOptional)
- [VERIFIED: build_order.txt:37-39] -- Current Hunter entries in build order
- [VERIFIED: biz_util.lua:119-138] -- findAutoShootActionSlot implementation

### Secondary (MEDIUM confidence -- impl patterns documented but specific new spell names need verification)
- Hunter Skill Names: English and Chinese names for non-verified spells are [ASSUMED] -- see Assumptions Log A1-A15
- Hunter Mechanics (dead zone, Auto Shot reset, trap CDs, etc.): [ASSUMED] from training data -- see Assumptions Log A16-A25
- Deubff Textures: Scorpid Sting texture [ASSUMED], Hunter's Mark texture [ASSUMED] -- see Assumptions Log A20-A21

### Tertiary (LOW confidence)
- Web searches did not return verifiable results (gaming sites blocked automated fetching)
- All training-data-derived claims tagged [ASSUMED] in this document

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH -- No external packages; pure Lua/WoW addon code following existing patterns
- Architecture: HIGH -- Druid architecture patterns directly verified from 5 source files totaling ~2000 lines
- Skill Names: MEDIUM -- 10 verified from codebase, 17 assumed from training data
- Mechanics: LOW -- All Hunter-specific mechanics (Auto Shot reset, trap CDs, Wing Clip behavior) from training data, not officially verified
- Pitfalls: HIGH -- Based on Druid code patterns and explicitly stated CONTEXT.md decisions

**Research date:** 2026-08-18
**Valid until:** 2026-09-01 (stable domain, but user should verify assumed skill names before planning)

**Key Risk:** The 25 [ASSUMED] claims in Section 13 represent the largest risk to this phase. The planner MUST address these -- either by having the user confirm skill names/mechanics, or by adding verification tasks to the plan (e.g., "verify Scorpid Sting Chinese name in-game").