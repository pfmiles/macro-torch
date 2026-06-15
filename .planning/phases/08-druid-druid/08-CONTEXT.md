# Phase 8: 非Druid职业代码结构重构（对齐Druid架构） - Context

**Gathered:** 2026-06-15
**Status:** Ready for planning

<domain>
## Phase Boundary

将现有的 6 个非 Druid 职业文件（Hunter/Mage/Priest/Rogue/Warlock/Warrior）重构为与 Druid 一致的架构和目录结构：
- 每个职业独立子目录（如 `classes/hunter/`）
- 完整的类定义（`classMetatable` + `XXX_FIELD_FUNC_MAP` + `registerPlayerClass`）
- 技能方法对象 + 多语言支持 + `SpellTrace:register` + `SelfTest:register`
- 按职业维度拆分为多文件（有明确维度的类比 Druid cat/bear，无明确维度的默认 2 文件）

这些职业的战斗逻辑目前实际未在游戏中使用，可大胆重构无需担心破坏业务逻辑。
</domain>

<decisions>
## Implementation Decisions

### 文件拆分粒度
- **D-01:** 有明确拆分维度的职业 → 多文件拆分，类比 Druid 的 cat.lua/bear.lua（如战士的姿态、猎人的近战/远程、法师的天赋类型等）。目前看不出明确维度的职业 → 默认 2 文件模式：职业基础逻辑（类定义 + 常量 + FIELD_FUNC_MAP + 技能方法 + 注册）+ 战斗逻辑（主入口 + 模块）。
- **D-02:** 拆分由 planner 逐职业判断，不要求统一文件数。拆分维度的选择应反映该职业在 WoW 1.12.1 中的核心 gameplay 区分（stance/spec/range）。

### 类定义补齐
- **D-03:** 为所有 5 个缺失类定义的职业（Warrior/Mage/Priest/Rogue/Warlock）创建完整的类定义架构，对齐 Druid/Hunter 标准：
  - `macroTorch.Xxx = macroTorch.Player:new()`
  - `Xxx:new()` 构造函数 + `macroTorch.classMetatable(self, "XXX_FIELD_FUNC_MAP")`
  - `XXX_FIELD_FUNC_MAP` 全局注册表（即使初始为空表）
  - 单例实例化（`macroTorch.xxx = macroTorch.Xxx:new()`）
  - `macroTorch.registerPlayerClass("Xxx", ...)` 多态注册
- **D-04:** Hunter 已有类定义和 `HUNTER_FIELD_FUNC_MAP`，补齐缺失部分：`registerPlayerClass` + `SpellTrace:register` + `SelfTest:register`。

### 代码现代化程度
- **D-05:** 全面对齐 Druid Phase 5-7 建立的模式：
  - 将 `CastSpellByName('技能名')` 替换为 `player.cast()` 调用（通过 `_castSpell` 基础设施）
  - 为每个职业创建技能方法（如 `warrior.sunder_armor(mode)`），内联多语言支持 `{en='...', zh='...'}`
  - 使用 `SpellTrace:register()` 声明式注册 spell trace
  - 使用 `SelfTest:register()` 注册职业特定自检
- **D-06:** 技能方法签名遵循 Phase 5 D-06/D-07 的类型分类（Type A 敌方 / Type B 自身 / Type C 灵活），resourceCost 支持数字和函数引用。

### 目录结构
- **D-07:** 每个非 Druid 职业建立独立子目录，深度与 `classes/druid/` 一致：
  - `classes/hunter/`、`classes/warrior/`、`classes/mage/`、`classes/priest/`、`classes/rogue/`、`classes/warlock/`
  - 目录内文件命名使用小写（如 `combat.lua`、`utility.lua`），与 `classes/druid/` 的 cat.lua/bear.lua/utility.lua 风格一致
  - 原有的 `classes/Xxx.lua` 扁平文件删除

### Claude's Discretion
- 逐职业的文件拆分边界（哪些职业按什么维度拆分、拆几个文件）
- 每个职业的技能方法清单（从现有 CastSpellByName 调用点提取）
- 每个职业的 FIELD_FUNC_MAP 初始内容
- SpellTrace/SelfTest 注册的具体实现
- Hunter 类是否需要从单文件拆分为多文件（当前仅 205 行但已具备类结构）
- 文件内代码组织顺序和注释风格
- 中文技能名的英文翻译（如 Rogue 的 偷窃→Pick Pocket、出血→Hemorrhage 等）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 8 目标："对照当前druid相关的代码架构及目录组织结构，将现有的其它职业的代码也重构为同样的架构及目录结构"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束；R1 (统一 Metatable 工厂) 为非 Druid 类定义提供基础设施

### 先前 Phase 决策（Druid 参考模式）
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` — D-05/D-06/D-07: `_castSpell` 架构、技能方法签名分类（Type A/B/C）、mode 参数（nil/raw/safe）
- `.planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md` — D-01: 纯点号语法约定（`obj.method()` 而非 `self:method()`）
- `.planning/phases/07-druid/07-CONTEXT.md` — D-01: 语义化方法定义在 FIELD_FUNC_MAP 中作为懒计算属性

### 参考架构（Druid 目标形态）
- `classes/druid/Druid.lua` (1310 行) — 类定义 + DRUID_FIELD_FUNC_MAP + ~40 技能方法 + 能量常量 + 共享辅助函数 + registerPlayerClass + SpellTrace:register + SelfTest:register
- `classes/druid/cat.lua` (387 行) — catAtk + 13 个模块（按优先级排列）
- `classes/druid/bear.lua` (146 行) — bearAtk + 熊形态模块
- `classes/druid/utility.lua` (89 行) — druidBuffs/druidStun/druidDefend/druidControl/pokemonLoad

### 关键基础设施
- `core/class.lua` — `classMetatable(cls, fieldMapName)` 工厂 + `initPlayer()` + `registerPlayerClass()` + `PLAYER_CLASS_REGISTRY`
- `entity/Player.lua` — `_castSpell(localeNames, mode, range, resourceCost, onSelf)` + `_isInRange` + `_hasResource` + `isSpellReady` + `cast`
- `core/spell_trace_core.lua` — `SpellTrace:register(name, config)` 声明式 API（Phase 3 D-06）
- `core/selftest.lua` — `SelfTest:register(name, fn, isOptional)` + `SelfTest:run()`

### 构建系统
- `build_order.txt` — 当前包含 `classes/Hunter.lua` 等 6 个扁平路径，重构后需更新为子目录路径
- `build.sh` — 严格模式（Phase 4 收尾），文件不存在时报错退出

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — OOP metatable 继承链、FIELD_FUNC_MAP 懒计算属性机制
- `.planning/codebase/CONVENTIONS.md` — 点号语法约定、全局函数命名、safe/ready 双模式
</canonical_refs>

<code_context>
## Existing Code Insights

### 当前非 Druid 职业状态

| 职业 | 文件 | 行数 | 类定义 | FIELD_FUNC_MAP | CastSpellByName | 技能方法 | registerPlayerClass |
|------|------|------|--------|----------------|-----------------|----------|---------------------|
| Hunter | classes/Hunter.lua | 205 | ✅ classMetatable | ✅ (空壳) | 0 处 | ❌ | ❌ |
| Warrior | classes/Warrior.lua | 210 | ❌ 裸函数 | ❌ | 14 处 | ❌ | ❌ |
| Rogue | classes/Rogue.lua | 150 | ❌ 裸函数 | ❌ | 12 处 | ❌ | ❌ |
| Priest | classes/Priest.lua | 111 | ❌ 裸函数 | ❌ | 3 处 | ❌ | ❌ |
| Warlock | classes/Warlock.lua | 92 | ❌ 裸函数 | ❌ | 0 处 (用 castIfBuffAbsent) | ❌ | ❌ |
| Mage | classes/Mage.lua | 81 | ❌ 裸函数 | ❌ | 2 处 | ❌ | ❌ |

### 非 Druid 职业现有维度

- **Warrior**: 姿态系统（Battle/Defensive/Berserker Stance）+ 近战/远程 + 单体/AOE + 控制/保命
- **Hunter**: 近战/远程切换 + 宠物管理 + Serpent Sting + OT 管理
- **Rogue**: 潜行/非潜行 + 正面/背后 + 偷窃 + 消失
- **Mage**: 近战/远程 + Buff + 控制（空壳）
- **Priest**: 远程 + Buff/Debuff + 治疗 + 控制（空壳）
- **Warlock**: 诅咒 + 近战/远程 + Buff + 宠物 + 控制（空壳）

### Reusable Assets
- **`macroTorch.classMetatable(cls, fieldMapName)`** (`core/class.lua`): 所有新类定义使用的统一 metatable 工厂
- **`macroTorch.registerPlayerClass(className, constructor)`** (`core/class.lua`): 惰性注册表，initPlayer 查表用
- **`player._castSpell(localeNames, mode, range, resourceCost, onSelf)`** (`entity/Player.lua`): 技能方法底层基础设施，支持 locale 选名 + ready/safe/raw 三模式
- **`SpellTrace:register(name, config)`** (`core/spell_trace_core.lua`): 声明式 spell trace 注册
- **`SelfTest:register(name, fn, isOptional)`** (`core/selftest.lua`): 自检框架
- **`player.cast(spellName, onSelf)`** (`entity/Player.lua`): 点号语法释放技能
- **`player.isSpellReady(spellName)`** (`entity/Player.lua`): 点号语法冷却检查

### Established Patterns
- **Druid 技能方法模式**: `function obj.claw(mode)` → 内联 `{en='Claw', zh='爪击'}` → 调用 `obj._castSpell(...)`
- **点号语法**: 方法定义和调用全代码库使用点号（Phase 6 D-01）
- **构造器内方法定义**: 技能方法定义在 `Xxx:new()` 构造函数内部的 `function obj.xxx()` 闭包中
- **FIELD_FUNC_MAP 懒计算属性**: `XXX_FIELD_FUNC_MAP["property"] = function(target) ... end`
- **单例模式**: 每个职业文件末尾 `macroTorch.xxx = macroTorch.Xxx:new()`

### Integration Points
- `core/class.lua` — `PLAYER_CLASS_REGISTRY` 表，新职业通过 `registerPlayerClass` 注册
- `build_order.txt` — 需将所有 `classes/Xxx.lua` 扁平路径替换为子目录路径
- `core/events.lua` — `initPlayer()` 调用，新职业注册后自动生效
- `entity/Player.lua` — `_castSpell` / `_isInRange` / `_hasResource` 基类方法，所有新技能方法依赖这些

### 特殊注意事项
- **Rogue 中文技能名**: `偷窃`(Pick Pocket), `鬼魅攻击`(Ghostly Strike), `出血`(Hemorrhage), `邪恶攻击`(Sinister Strike), `背刺`(Backstab), `消失`(Vanish), `伺机待发`(Preparation) — 需提供英文名以支持 locale 表
- **Warrior 中文名**: 技能名在代码中使用英文，无需特殊处理
- **castIfBuffAbsent**: Warlock/Mage/Priest 使用 `macroTorch.castIfBuffAbsent()` 辅助函数而非 CastSpellByName，迁移时需保留该模式或转为技能方法 + buff 检查
</code_context>

<specifics>
## Specific Ideas

- 所有非 Druid 职业都已有 Singleton 实例：`macroTorch.hunter`、`macroTorch.warrior`（无）、`macroTorch.rogue`（无）等。重构后为每个职业创建正式单例并通过 `initPlayer()` 接入。
- 技能方法迁移时，直接使用现有 `_castSpell` 基础设施。不需要为每个职业重复实现 `_isInRange` / `_hasResource`。
- 对于 `castIfBuffAbsent()` 调用点（Warlock/Priest/Mage），可先保留该模式，不强制转为技能方法。未来可按需迁移。
- SpellTrace 注册只对需要追踪 land/fail/immune 的技能有意义。非 Druid 职业当前逻辑未实际使用，可按 Druid 模式预留注册框架，技能列表从 `player.cast()` 调用点提取。
- SelfTest 注册应覆盖：类存在性、FIELD_FUNC_MAP 完整性、关键技能方法存在性。
- build_order.txt 更新是本次重构的硬依赖 — 所有文件路径变更必须同步更新构建配置。
</specifics>

<deferred>
## Deferred Ideas

- **非 Druid 职业战斗逻辑完善**: 当前 Phase 8 仅做架构对齐和代码现代化（结构+API），不完善实际战斗逻辑。各职业的详细战斗 rotation 实现属于各自的未来 Phase。
- **Warrior Stance 切换逻辑**: 当前 `wroAtk` 中有 `CastShapeshiftForm(mainStanceIdx)` 调用。未来可参照 Druid isInCatForm/isInBearForm 模式添加语义化 Stance 方法。
- **Hunter/Mage/Priest/Warlock 天赋系统**: 当前代码无天赋检测，未来可参照 Druid Ancient Brutality 模式添加天赋 rank 检测和动态消耗计算。
- **宠物系统统一**: Hunter/Warlock/Mage 都有宠物相关代码（PetAttack/PetDefensiveMode），未来可考虑统一宠物管理接口。

None — 讨论保持在 Phase 8 范围内（架构对齐 + API 现代化）。
</deferred>

---

*Phase: 08-非Druid职业代码结构重构（对齐Druid架构）*
*Context gathered: 2026-06-15*