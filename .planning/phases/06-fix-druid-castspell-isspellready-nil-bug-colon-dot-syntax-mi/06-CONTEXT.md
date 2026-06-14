# Phase 6: Fix Druid _castSpell isSpellReady nil bug - Context

**Gathered:** 2026-06-14
**Status:** Ready for planning

<domain>
## Phase Boundary

修复 `entity/Player.lua` 中 `_castSpell` 内部冒号/点号调用不匹配导致的 nil bug。问题根源：`_castSpell` 使用冒号语法调用 4 个点号定义的内部方法（`isSpellReady`、`_isInRange`、`_hasResource`、`cast`），导致参数错位，所有 Druid 技能方法静默失败（`isSpellReady(nil)` 永远返回 false）。

同时修复 `classes/druid/Druid.lua` 中 46 个技能方法对 `_castSpell` 的冒号调用（改为点号），保持全代码库点号调用约定一致。

**影响范围**：2 个文件，约 50 行改动（均为冒号→点号的机械替换），零逻辑变更。
</domain>

<decisions>
## Implementation Decisions

### 修复策略（纯点号）
- **D-01:** 保持所有方法定义使用点号语法（`function obj.method(params)`），不改为冒号。项目使用 metatable `__index` 链 + 闭包上值实现继承链，点号是完全正确且一致的 Lua OOP 模式。
- **D-02:** `entity/Player.lua` 中 `_castSpell` 内部 4 处调用从冒号改为点号，使用闭包 `obj` 引用：
  - `self:isSpellReady(spellName)` → `obj.isSpellReady(spellName)`
  - `self:_isInRange(range)` → `obj._isInRange(range)`
  - `self:_hasResource(cost)` → `obj._hasResource(cost)`
  - `self:cast(spellName, false)` → `obj.cast(spellName, false)`
- **D-03:** `classes/druid/Druid.lua` 中全部 ~46 个技能方法从 `self:_castSpell(...)` 改为 `obj._castSpell(...)`。`obj` 通过 metatable 链正确解析到 Player 原型上的 `_castSpell`。

### 公开方法处理
- **D-04:** `isSpellReady` 和 `cast` 保持点号定义不变。外部 28+ 处点号调用（Hunter、cat.lua、utility.lua）无需修改。

### 私有方法处理
- **D-05:** `_isInRange` 和 `_hasResource` 保持点号定义不变。它们仅被 `_castSpell` 内部调用，修复调用端即可。

### 回归验证
- **D-06:** 在 `core/selftest.lua` 中添加 Category F 测试（~15个），验证 metatable 链完整性：Druid 实例通过 `_castSpell` 能正确访问 `isSpellReady`/`_isInRange`/`_hasResource`/`cast`。
- **D-07:** 创建 `HUMAN-UAT.md` 手动测试清单，覆盖 Type A（敌方）、Type B（自身）、Type C（灵活）三种技能类型，验证三种 mode（ready/safe/raw）在游戏内行为正确。

### Claude's Discretion
- Selftest 测试用例的具体实现细节（在已有框架下注册测试，使用 pcall 包裹）
- HUMAN-UAT.md 的具体测试步骤和格式
- Druid.lua 技能方法中 `obj._castSpell(...)` 替换 `self:_castSpell(...)` 的具体执行方式（机械替换，可用 grep/sed 辅助）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 6 目标和 Phase 5 依赖
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### Phase 5 决策
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` — D-01 到 D-08：`_castSpell`/`_isInRange`/`_hasResource` 的设计、技能方法签名分类、Druid 技能清单

### 关键源文件
- `entity/Player.lua:40-103` — `_castSpell`（第40行）、`_isInRange`（第87行）、`_hasResource`（第101行）当前定义
- `entity/Player.lua:174-176` — `isSpellReady` 定义
- `entity/Player.lua:29-31` — `cast` 定义
- `classes/druid/Druid.lua:19-150+` — Druid:new() 构造函数，46 个技能方法定义
- `classes/druid/cat.lua` — 7 处 `macroTorch.player.isSpellReady()` 外部调用
- `classes/druid/utility.lua` — 4 处 `macroTorch.player.isSpellReady()` 外部调用
- `classes/Hunter.lua` — 11 处 `player.cast()` + 6 处 `player.isSpellReady()` 外部调用（点号，无需修改）

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — OOP metatable 继承链、classMetatable __index 解析顺序
- `.planning/codebase/CONVENTIONS.md` — 点号定义惯例、函数设计模式
</canonical_refs>

<code_context>
## Existing Code Insights

### Bug 根因

```lua
-- entity/Player.lua (inside function macroTorch.Player:new())
-- self (closure upvalue) = macroTorch.Player (类原型, 不是实例!)

function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)  -- 点号定义
    ...
    if not self:isSpellReady(spellName) then  -- 冒号调用！传入2个参数, 函数只收1个
        -- Lua: macroTorch.Player.isSpellReady(macroTorch.Player, spellName)
        -- isSpellReady(spellName): spellName = macroTorch.Player (表!), 真实名称丢失
        -- SpellReady(table) → nil → toBoolean(nil) → false
```

Druid 端同样参数错位：
```lua
-- classes/druid/Druid.lua
function obj.claw(mode)
    return self:_castSpell({en='Claw', zh='爪击'}, mode, ...)
    -- self = macroTorch.Druid (闭包上值)
    -- _castSpell 是点号定义 → localeNames = macroTorch.Druid, mode = {en='Claw',...}, 全部偏移
```

### Reusable Assets
- **`classMetatable` 工厂** (`core/class.lua`): `__index` 按 FIELD_FUNC_MAP → cls → parent 顺序解析，保证 `obj._castSpell` 通过 Druid 实例能正确找到 Player 原型上的方法
- **`SelfTest` 框架** (`core/selftest.lua`): 已有 74+ 注册测试，pcall 包裹，按 category 组织

### Integration Points
- `entity/Player.lua`: `_castSpell` 内部 4 处调用行（52, 59, 69, 79）
- `classes/druid/Druid.lua`: 46 个技能方法 `self:_castSpell` → `obj._castSpell`
- `core/selftest.lua`: 新增 Category F 测试
- `classes/Hunter.lua`: 无需修改（点号调用，一直正确）

### Build System
- `build_order.txt` 和 `build.sh`: 无需变更（文件路径不变）
</code_context>

<specifics>
## Specific Ideas

- 纯点号修复：改动全是 `self:xxx()` → `obj.xxx()` 的机械替换，不引入任何新逻辑
- `_castSpell` 定义保持点号：`function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)` — 签名不变
- Druid 的 `obj` (= Druid 实例) 通过 `classMetatable.__index` → `macroTorch.Druid` → `macroTorch.Player` 找到 `_castSpell`
- `_castSpell` 内部使用闭包 `obj` (= Player 原型) 找到 `isSpellReady`/`_isInRange`/`_hasResource`/`cast`
- `_hasResource` 的 `self.mana` 通过闭包 `self` (= Player 原型, ref="player") 正确计算，无需修改
</specifics>

<deferred>
## Deferred Ideas

- **冒号语法迁移**: 讨论过将所有方法改为冒号定义以匹配"正统" Lua OOP 风格。用户明确倾向点号，因为 metatable `__index` 链 + 闭包上值模式已足够。未来如果引入非单例子类（如 Focus），再考虑冒号迁移。
- **`_hasResource` 实例 self**: 讨论过将 `_hasResource` 改为使用实例 self 而非闭包 self。点号修复方案下行为不变（`self.mana` 通过 Player 原型 ref="player" 正确），无需修改。

None — 讨论保持在 Phase 6 范围内。
</deferred>

---

*Phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi*
*Context gathered: 2026-06-14*