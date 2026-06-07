# macro-torch 重构路线图

## 概览

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4
(基础设施)   (事件拆分)   (自检+配置)  (职业重组)
    ↓           ↓           ↓           ↓
  R1,R2,R6,R7  R3,R6       R4,R5       R5,R6,R8
```

每个 Phase 内 task 可独立验证，Phase 完成后整体验证。

---

## Phase 1: 基础设施 — classMetatable 工厂 + Entity 层迁移

**覆盖需求**: R1 (统一 Metatable), R2 (多态初始化), R6 (entity/ 目录), R7 (构建系统)

**目标**: 建立 core/ 基础设施，将所有实体类统一到 classMetatable 工厂，消除多态 hack，同步建立声明式构建系统。

**Plans:** 2/6 plans executed
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — classMetatable 工厂 + initPlayer/registerPlayerClass (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — 删除多态 hack + Druid 注册 + initPlayer 接入 (Wave 2)
- [ ] 01-03-PLAN.md — LRUStack 迁移 + periodic task 系统 + 独立 OnUpdate Frame + 清理 (Wave 2)
- [x] 01-04-PLAN.md — Unit/Player/Target → entity/ 迁移 + metatable 替换 (Wave 2)
- [ ] 01-05-PLAN.md — Pet/TargetTarget/TargetPet/PetTarget/Group/Raid → entity/ 迁移 (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-06-PLAN.md — build_order.txt + build.sh 声明式构建系统 (Wave 3)

### 1.1 core/class.lua

#### T1.1.1 — 创建 `core/class.lua`，实现 `classMetatable` 工厂

- 实现 `macroTorch.classMetatable(cls, fieldMapName)` 工厂函数
- 不改变现有 metatable 链语义：`instance → FIELD_FUNC_MAP → class → parent FIELD_FUNC_MAP → ...`
- 通过字符串名查找 fieldMap（`macroTorch[fieldMapName]`），支持跨文件注册

**验证**: `grep "function macroTorch.classMetatable" core/class.lua` 有结果

#### T1.1.2 — 实现 `initPlayer()` 多态工厂 + `registerPlayerClass()` 注册表

- 实现 `macroTorch.registerPlayerClass(className, constructor)` — 惰性注册表
- 实现 `macroTorch.initPlayer()` — 根据 `UnitClass('player')` 查表，返回正确类型实例
- 查表失败时 fallback 到 `macroTorch.Player:new()`
- 保留 `Player.lua` 末尾 `macroTorch.player = macroTorch.Player:new()` 作为默认初始化

**验证**: `grep "function macroTorch.initPlayer\|function macroTorch.registerPlayerClass" core/class.lua` 各有结果

### 1.2 core/periodic.lua

#### T1.2.1 — 从 `event_stack.lua` 迁移 `LRUStack` + `ES_FIELD_FUNC_MAP`

- 将 `macroTorch.LRUStack` 完整代码迁入 `core/periodic.lua`
- 迁移 `macroTorch.ES_FIELD_FUNC_MAP`
- 用 `classMetatable(nil)` 替换 LRUStack 手写 metatable（验证工厂对无父类场景的支持）

**验证**: `grep "function macroTorch.LRUStack:new" core/periodic.lua` 有结果

#### T1.2.2 — 迁移 `registerPeriodicTask` / `removePeriodicTask` / `setRepeat`

- 从 `battle_event_queue.lua` 迁移三个 period task 管理函数
- 保持函数签名和全局命名不变

**验证**: `grep "function macroTorch.registerPeriodicTask\|function macroTorch.removePeriodicTask\|function macroTorch.setRepeat" core/periodic.lua` 均有结果

#### T1.2.3 — 迁移 `onPeriodicUpdate` + 独立 OnUpdate Frame

- 从 `battle_event_queue.lua` 迁移 `macroTorch.onPeriodicUpdate()`
- 创建独立的 `local frame = CreateFrame("Frame")`（与 events.lua 的 frame 独立）
- 迁移 `frame.lastUpdate` / `frame.leastUpdateInterval` 及 `frame:SetScript("OnUpdate", ...)`

**验证**: `grep "function macroTorch.onPeriodicUpdate\|CreateFrame.*Frame\|SetScript.*OnUpdate" core/periodic.lua` 均有结果

#### T1.2.4 — 清理：删除 `event_stack.lua`，清理 `battle_event_queue.lua`

- 删除 `event_stack.lua`（内容已全量迁入 periodic.lua）
- 从 `battle_event_queue.lua` 删除已迁移的 3 个 period task 函数 + `onPeriodicUpdate` + OnUpdate frame 代码

**验证**: `test ! -f event_stack.lua`；`grep "registerPeriodicTask\|setRepeat\|onPeriodicUpdate\|frame:SetScript.*OnUpdate" battle_event_queue.lua` 无结果

### 1.3 Entity 层 metatable 替换 + 文件移动

#### T1.3.1 — 改造 `Unit.lua` → `entity/Unit.lua` ✅

- 文件移动到 `entity/Unit.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "UNIT_FIELD_FUNC_MAP")`
- `UNIT_FIELD_FUNC_MAP` 保持在 `Unit.lua` 中，作为全局变量 `macroTorch.UNIT_FIELD_FUNC_MAP`

**验证**: `grep "macroTorch.classMetatable" entity/Unit.lua` 有结果；`grep "setmetatable(obj, {" entity/Unit.lua` 无结果

#### T1.3.2 — 改造 `Player.lua` → `entity/Player.lua` ✅

- 文件移动到 `entity/Player.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP")`
- `PLAYER_FIELD_FUNC_MAP` 保持全局注册

**验证**: `grep "macroTorch.classMetatable" entity/Player.lua` 有结果；`grep "setmetatable(obj, {" entity/Player.lua` 无结果

#### T1.3.3 — 改造 `Target.lua` → `entity/Target.lua` ✅

- 文件移动到 `entity/Target.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "TARGET_FIELD_FUNC_MAP")`

**验证**: `grep "macroTorch.classMetatable" entity/Target.lua` 有结果；`grep "setmetatable(obj, {" entity/Target.lua` 无结果

#### T1.3.4 — 改造 `Pet.lua` → `entity/Pet.lua`

- 文件移动到 `entity/Pet.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "PET_FIELD_FUNC_MAP")`

**验证**: `grep "macroTorch.classMetatable" entity/Pet.lua` 有结果；`grep "setmetatable(obj, {" entity/Pet.lua` 无结果

#### T1.3.5 — 改造 `TargetTarget.lua` → `entity/TargetTarget.lua`

- 文件移动到 `entity/TargetTarget.lua`
- `new()` 中 `setmetatable(obj, self)` + `self.__index = self` 替换为 `macroTorch.classMetatable(self, "TARGETTARGET_FIELD_FUNC_MAP")`

**验证**: `grep "macroTorch.classMetatable" entity/TargetTarget.lua` 有结果；`grep "setmetatable(obj, self)" entity/TargetTarget.lua` 无结果

#### T1.3.6 — 批量移动无 metatable 的 Entity 文件

- `TargetPet.lua` → `entity/TargetPet.lua`
- `PetTarget.lua` → `entity/PetTarget.lua`
- `Group.lua` → `entity/Group.lua`（空壳）
- `Raid.lua` → `entity/Raid.lua`（空壳）

**验证**: 4 个文件均存在于 `entity/` 目录下

### 1.4 移除多态 hack

#### T1.4.1 — 删除 `battle_event_queue.lua` 中的 Druid 替换逻辑

- 删除 `macroTorch.player = macroTorch.druid` 的动态替换代码（battle_event_queue.lua:76-78）

**验证**: `grep "macroTorch.player = macroTorch.druid" battle_event_queue.lua` 无结果

#### T1.4.2 — 在 `PLAYER_ENTERING_WORLD` 中接入 `initPlayer()`

- `battle_event_queue.lua` 的 `PLAYER_ENTERING_WORLD` 事件处理中，调用 `macroTorch.player = macroTorch.initPlayer()`
- Druid 登录时 `macroTorch.player` 为 Druid 实例，其他职业为 Player 实例

**验证**: `grep "macroTorch.initPlayer" battle_event_queue.lua` 有结果

### 1.5 声明式构建系统

#### T1.5.1 — 创建 `build_order.txt`

- 一行一个文件路径，空行和 `#` 注释忽略
- 包含完整的文件列表（含 Phase 2-4 将创建的文件），按依赖顺序排列
- 顺序：`macro_torch.lua` → `impl_util.lua` → `biz_util.lua` → `core/` → `entity/` → `texture_map.lua` → `interface_debug.lua` → `SM_Extend_*.lua`（按 class）

**验证**: `wc -l build_order.txt` > 20；`grep -c "^core/\|^entity/\|^classes/" build_order.txt` ≥ 15

#### T1.5.2 — 重写 `build.sh`（容错模式）

- 读取 `build_order.txt` 按序拼接
- 对不存在的文件静默跳过（`[ -f "$line" ] && cat`）
- 保留 Cygwin 拷贝逻辑
- 删除旧的硬编码文件列表

**验证**: `./build.sh && echo "Build OK"` 成功

### Phase 1 汇总验证

```bash

# metatable 模板不再出现在 entity/ 中

grep -c "setmetatable(obj, {" entity/*.lua  # 期望: 0

# classMetatable 使用次数 ≥ 6（含 LRUStack）

grep -c "macroTorch.classMetatable" entity/*.lua core/periodic.lua  # 期望: ≥6

# initPlayer + registerPlayerClass 存在

grep "function macroTorch.initPlayer\|function macroTorch.registerPlayerClass" core/class.lua

# 旧的替换逻辑已删除

grep "macroTorch.player = macroTorch.druid" battle_event_queue.lua  # 期望: 无结果

# event_stack.lua 已删除

test ! -f event_stack.lua

# 构建成功

./build.sh && echo "Build OK"

# 产物中关键符号存在

grep "function macroTorch.classMetatable\|function macroTorch.initPlayer\|function macroTorch.registerPeriodicTask" SM_Extend.lua
```

---

## Phase 2: 事件系统模块化拆分

**覆盖需求**: R3 (战斗事件系统模块化), R6 (core/ 目录)

**目标**: 将 `battle_event_queue.lua` 剩余内容按职责拆分到 `core/events.lua`、`core/combat_context.lua`、`core/spell_trace.lua`。

> **Frame 分离说明**: 原 `battle_event_queue.lua` 中一个 frame 同时承载 OnUpdate 和 OnEvent。Phase 1 已将 OnUpdate 迁入 `periodic.lua`，Phase 2 为 events 创建独立的 OnEvent frame，两者无共享状态。

### 2.1 core/events.lua

#### T2.1.1 — 创建 `core/events.lua`，建立独立 OnEvent Frame

- 创建 `local frame = CreateFrame("Frame")`（独立于 periodic.lua）
- 注册 14 个事件：`PLAYER_ENTERING_WORLD`, `PLAYER_TARGET_CHANGED`, `SPELLCAST_START`, `SPELLCAST_STOP`, `SPELLCAST_FAILED`, `SPELLCAST_SUCCESS`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `UNIT_CASTEVENT`, `CHAT_MSG_COMBAT_SELF_MISSES`, `CHAT_MSG_SPELL_SELF_DAMAGE`, `UNIT_HEALTH`, `UNIT_MANA`, `UNIT_RAGE`
- 设置 `frame:SetScript("OnEvent", macroTorch.eventHandle)`

**验证**: `grep "CreateFrame.*Frame\|RegisterEvent\|SetScript.*OnEvent" core/events.lua` 均有结果

#### T2.1.2 — 迁移 `eventHandle()` 函数

- 从 `battle_event_queue.lua` 迁移 `macroTorch.eventHandle()` 函数
- 保留事件 dispatch 逻辑：`PLAYER_REGEN_ENABLED/DISABLED` → combat_context 函数调用；`UNIT_CASTEVENT` / `CHAT_MSG_*` → spell_trace 函数调用

**验证**: `grep "function macroTorch.eventHandle" core/events.lua` 有结果

#### T2.1.3 — `PLAYER_ENTERING_WORLD` 自检钩子

- `PLAYER_ENTERING_WORLD` 处理中预留 `macroTorch.SelfTest:run()` 调用（Phase 3 实现）
- 保留 `macroTorch.player = macroTorch.initPlayer()` 调用（Phase 1 已接入）

**验证**: `grep "SelfTest:run\|initPlayer" core/events.lua` 有结果

### 2.2 core/combat_context.lua

#### T2.2.1 — 创建 `core/combat_context.lua`，迁移战斗进出逻辑

- 迁移 `PLAYER_REGEN_ENABLED` 处理：`macroTorch.inCombat = false; macroTorch.context = {}`
- 迁移 `PLAYER_REGEN_DISABLED` 处理：`macroTorch.context = {}; macroTorch.inCombat = true`

**验证**: `grep "macroTorch.inCombat\|macroTorch.context" core/combat_context.lua` 有结果

#### T2.2.2 — 迁移 `loadImmuneTable` / `loadDefiniteBleedingTable`

- 从 `battle_event_queue.lua` 迁移两个初始化函数
- 保持函数签名不变

**验证**: `grep "function macroTorch.loadImmuneTable\|function macroTorch.loadDefiniteBleedingTable" core/combat_context.lua` 均有结果

### 2.3 core/spell_trace.lua

#### T2.3.1 — 创建 `core/spell_trace.lua`，迁移 trace 基础设施

- 迁移 `macroTorch.DEBUFF_LAND_LAG` 常量
- 迁移 `macroTorch.tracingSpells` / `macroTorch.traceSpellImmunes` 初始化
- 迁移 `setSpellTracing` / `setSpellTracingByName`
- 迁移 `setTraceSpellImmune` / `setTraceSpellImmuneByName`

**验证**: `grep "function macroTorch.setSpellTracing\|function macroTorch.setTraceSpellImmune\|DEBUFF_LAND_LAG" core/spell_trace.lua` 均有结果

#### T2.3.2 — 迁移 cast / fail / land table 管理函数

- 迁移 `recordCastTable` / `recordFailTable` / `computeLandTable`
- 迁移 `maintainLandTables` 及其 `registerPeriodicTask` 调用
- 迁移 `consumeLandEvent` / `consumeFailEvent`
- 迁移 `peekCastEvent` / `peekFailEvent` / `peekLandEvent`
- 迁移 `landTableAnyMatch` / `landTableAllMatch`

**验证**: `grep "function macroTorch.recordCastTable\|function macroTorch.maintainLandTables\|function macroTorch.landTableAnyMatch" core/spell_trace.lua` 均有结果

#### T2.3.3 — 迁移 immune tracing + dodge/parry 检测

- 迁移 `spellsImmuneTracing` 及其 `registerPeriodicTask` 调用
- 迁移 `CheckDodgeParryBlockResist`

**验证**: `grep "function macroTorch.spellsImmuneTracing\|function macroTorch.CheckDodgeParryBlockResist" core/spell_trace.lua` 均有结果

### 2.4 清理

#### T2.4.1 — 删除 `battle_event_queue.lua` 中已迁移代码

- 删除所有已迁入 `core/events.lua` 的内容
- 删除所有已迁入 `core/combat_context.lua` 的内容
- 删除所有已迁入 `core/spell_trace.lua` 的内容
- `battle_event_queue.lua` 本身可删除或缩减为 ≤10 行的兼容占位

**验证**: `test ! -f battle_event_queue.lua || test $(wc -l < battle_event_queue.lua) -le 10`

### Phase 2 汇总验证

```bash

# 旧文件已不存在或为空

test ! -f battle_event_queue.lua || test $(wc -l < battle_event_queue.lua) -le 10

# 新模块非空且合理大小

wc -l core/events.lua core/combat_context.lua core/spell_trace.lua

# 期望: 每个 ≤250 行

# 关键函数分布正确

grep -c "function macroTorch.eventHandle" core/events.lua         # 期望: 1
grep -c "function macroTorch.loadImmuneTable" core/combat_context.lua  # 期望: 1
grep -c "function macroTorch.CheckDodgeParryBlockResist" core/spell_trace.lua  # 期望: 1

# 构建成功

./build.sh && echo "Build OK"
```

---

## Phase 3: 自检系统 + Spell Trace 配置化

**覆盖需求**: R4 (Spell Trace 配置化), R5 (登录自检)

**目标**: 实现登录自检框架并填充内置测试，将 spell trace 改为声明式注册。

### 3.1 自检框架

#### T3.1.1 — 创建 `core/selftest.lua`，实现 `SelfTest` 框架

- `macroTorch.SelfTest = { tests = {}, results = {} }`
- `SelfTest:register(name, fn, isOptional)` — 注册测试用例
- `SelfTest:run()` — pcall 包裹每个测试，汇总输出到聊天框
- 汇总格式：`[macro-torch] Self-test: X passed, Y failed, Z warnings`
- 成功项不打印日志，仅汇总行 + 失败/warning 可见
- 可选模块失败报 warning（黄色），核心模块失败报 error（红色）

**验证**: `grep "function macroTorch.SelfTest:register\|function macroTorch.SelfTest:run" core/selftest.lua` 均有结果

#### T3.1.2 — 注册 Lua 基础环境测试（≥8 项）

- `type()`, `pcall()`, `setmetatable()`, `table.insert`, `string.format`, `ipairs`, `unpack`, `error()` 等直接调用验证

**验证**: `grep "SelfTest:register" core/selftest.lua | wc -l` ≥ 8

#### T3.1.3 — 注册 Player 实体属性测试（≥15 项）

- `player.health`, `player.mana`, `player.energy`, `player.comboPoints`, `player.isInCombat`, `player.isOoc`, `player.isProwling`, `player.isInBearForm`, `player.isInCatForm` 等
- 每个测试调用属性并验证返回类型

**验证**: 累计 `SelfTest:register` ≥ 23

#### T3.1.4 — 注册 Target/Pet 属性测试（≥7 项）

- Target: `target.health`, `target.isDead`, `target.isImmuneRip`, `target.bleedCount` 等（函数存在性检测；有目标时实际调用）
- Pet: `pet.health`, `pet.exists` 等（函数存在性检测；有宠物时实际调用）

**验证**: 累计 `SelfTest:register` ≥ 30

#### T3.1.5 — 注册 WoW API 测试（≥30 项）

- 直接调用：`UnitHealth("player")`, `UnitMana("player")`, `GetComboPoints()`, `UnitClass("player")` 等验证返回值
- 存在性：`CastSpell`, `UnitBuff`, `PetAttack`, `IsUsableAction` 等验证 `type() == 'function'`

**验证**: 累计 `SelfTest:register` ≥ 60

#### T3.1.6 — 注册可选模块检测

- `UnitXP` — warning 级别（存在性检测）
- `SP3` — warning 级别（存在性检测）

**验证**: 两个可选模块的测试均为 `isOptional = true`

### 3.2 挂载自检触发

#### T3.2.1 — `core/events.lua` 中挂载自检

- `PLAYER_ENTERING_WORLD` 处理中调用 `macroTorch.SelfTest:run()`
- 首次进入世界运行全量检测，reload 同样运行

**验证**: `grep "SelfTest:run" core/events.lua` 有结果

### 3.3 Spell Trace 配置化

#### T3.3.1 — 实现 `SpellTrace:register()` 声明式 API

- 在 `core/spell_trace.lua` 中添加 `macroTorch.SpellTrace:register(name, config)`
  - `config.immune` — 是否追踪免疫 (bool)
  - `config.land` — 是否追踪 land 事件 (bool)
  - `config.debuffTexture` — debuff 贴图纹理（可选）
- 内部自动调用 `setSpellTracing` + `setTraceSpellImmune`

**验证**: `grep "function macroTorch.SpellTrace:register" core/spell_trace.lua` 有结果

### 3.4 Druid 职业集成

#### T3.4.1 — `SM_Extend_Druid.lua` 中改用 `SpellTrace:register()`

- 将现有的 `setSpellTracing` + `setTraceSpellImmune` 调用对改写为 `SpellTrace:register()` 调用
- 覆盖技能：Rip, Rake, Shred, Claw, Faerie Fire, Pounce, Ravage 等（≥5 个）

**验证**: `grep -c "SpellTrace:register" SM_Extend_Druid.lua` ≥ 5

#### T3.4.2 — `SM_Extend_Druid.lua` 中注册职业特定自检

- 猫形态核心技能存在：Shred, Rip, Rake, Claw, Ferocious Bite, Tiger's Fury, Faerie Fire, Pounce, Ravage, Cower（≥10 项）
- 关键 talent 检测：Ancient Brutality, Omen of Clarity 等

**验证**: `grep -c "SelfTest:register" SM_Extend_Druid.lua` ≥ 10

### Phase 3 汇总验证

```bash

# 自检注册总数 ≥ 70

grep -c "SelfTest:register" core/selftest.lua SM_Extend_Druid.lua  # 期望: ≥70

# SpellTrace 声明式注册 ≥ 5

grep -c "SpellTrace:register" SM_Extend_Druid.lua  # 期望: ≥5

# 聊天框输出格式正确

grep "Self-test:" core/selftest.lua

# 构建成功

./build.sh && echo "Build OK"
```

---

## Phase 4: 职业文件重组 + 构建系统收尾

**覆盖需求**: R6 (classes/ 目录), R8 (Druid 逻辑保持)

**目标**: 拆分 Druid 大类，归类所有职业文件，完成最终目录结构。构建系统切换为严格模式。

### 4.1 Druid 文件拆分（1751 行 → 4 文件）

#### T4.1.1 — 拆分 `classes/Druid.lua`（类定义 + 常量 + 字段函数映射）

从 `SM_Extend_Druid.lua` 提取：

- `macroTorch.Druid:new()` 构造器
- `DRUID_FIELD_FUNC_MAP` 全部字段
- 能量常量：`CLAW_E`, `SHRED_E`, `RAKE_E`, `RIP_E`, `BITE_E`, `FF_E`, `COWER_E`, `TIGER_E` 等
- `registerPlayerClass("Druid", ...)` 调用
- Spell trace 注册 + 职业自检注册（T3.4 产出）
- 全局共享辅助函数：`shouldUseShred`, `shouldCastRip`, `shouldUseBite`, `shouldCastFFDuringWaitWindow`, `getMinimumAffordableAbilityCost`, `computeErps`, `computeNormalRelic`, `selectFerocityOrEmeraldRot`, `recoverNormalRelic`
- 能量计算函数：`computeClaw_E`, `computeShred_E`, `computeRake_E`, `computeRake_Duration`, `computeTiger_E`, `computeTiger_Duration`, `computeRake_Erps`, `computeRip_Erps`, `computePounce_Erps`
- `consumeDruidBattleEvents`, `isTrivialBattleOrPvp`, `isTrivialBattle`, `isFightStarted`, `isKillShotOrLastChance`, `combatUrgentHPRestore`
- `readyBite`, `safeFF`, `safeTigerFury`, `tigerSelfGCD`, `safePounce`, `safeCower`, `safeMaul`, `readyCower`, `readyMaul`, `safeSavageBite`, `readySavageBite`, `readyGrowl`, `safeDemoralizingRoar`, `readyDemoralizingRoar`, `safeSwipe`, `readySwipe`

**验证**: `wc -l classes/Druid.lua` ≈ 200-300 行；`grep "function macroTorch.Druid:new\|DRUID_FIELD_FUNC_MAP\|shouldUseShred\|shouldCastRip\|shouldUseBite" classes/Druid.lua` 均有结果

#### T4.1.2 — 拆分 `classes/Druid/cat.lua`（catAtk 主函数 + 所有模块）

从 `SM_Extend_Druid.lua` 提取 cat 形态全部逻辑：

- `catAtk()` 主入口函数
- 13 个模块（按执行顺序）：`idolRecover`, `healthManaSaver`, `targetEnemy`, `keepAutoAttack`, `rushMod`/`burstMod`, `openerMod`, `oocMod`, `termMod`, `otMod`, `tigerFury`/`keepTigerFury`, `debuffMod`（`keepRip`/`keepRake`/`keepFF`/`safeFF`）, `regularAttack`, `reshiftMod`
- 辅助函数：`cp5Bite`, `energyDischargeBeforeBite`, `tryBiteKillShot`, `dischargeEnergyChangeRelicAndRip`, `quickKeepRip`, `shouldDoReshift`, `canDoReshift`
- `atkPowerBurst`

**验证**: `wc -l classes/Druid/cat.lua` ≈ 900-1100 行；`grep "function macroTorch.catAtk\|function macroTorch.regularAttack\|function macroTorch.keepRip\|function macroTorch.keepRake\|function macroTorch.keepFF" classes/Druid/cat.lua` 均有结果

#### T4.1.3 — 拆分 `classes/Druid/bear.lua`（熊形态函数）

从 `SM_Extend_Druid.lua` 提取：

- `bearAtk()`, `bearOocMod`, `bearOtMod`, `bearDebuffMod`, `bearFFMod`
- `bearRegularAttack`, `bearReshiftMod`, `bearAoe`

**验证**: `wc -l classes/Druid/bear.lua` ≈ 100-200 行；`grep "function macroTorch.bearAtk\|function macroTorch.bearAoe" classes/Druid/bear.lua` 均有结果

#### T4.1.4 — 拆分 `classes/Druid/utility.lua`（buff + 控制 + 物品）

从 `SM_Extend_Druid.lua` 提取：

- `druidBuffs()`, `druidStun()`, `druidDefend()`, `druidControl()`
- `pokemonLoad()` 物品装载系统

**验证**: `wc -l classes/Druid/utility.lua` ≈ 300-400 行；`grep "function macroTorch.druidBuffs\|function macroTorch.pokemonLoad" classes/Druid/utility.lua` 均有结果

#### T4.1.5 — 删除 `SM_Extend_Druid.lua`

- 所有内容已迁移到 `classes/Druid/` 下 4 个文件

**验证**: `test ! -f SM_Extend_Druid.lua`

### 4.2 其他职业文件迁移

#### T4.2.1 — 迁移 `SM_Extend_Hunter.lua` → `classes/Hunter.lua`

**验证**: `test -f classes/Hunter.lua && test ! -f SM_Extend_Hunter.lua`

#### T4.2.2 — 迁移 `SM_Extend_Mage.lua` → `classes/Mage.lua`

**验证**: `test -f classes/Mage.lua && test ! -f SM_Extend_Mage.lua`

#### T4.2.3 — 迁移 `SM_Extend_Priest.lua` → `classes/Priest.lua`

**验证**: `test -f classes/Priest.lua && test ! -f SM_Extend_Priest.lua`

#### T4.2.4 — 迁移 `SM_Extend_Rogue.lua` → `classes/Rogue.lua`

**验证**: `test -f classes/Rogue.lua && test ! -f SM_Extend_Rogue.lua`

#### T4.2.5 — 迁移 `SM_Extend_Warlock.lua` → `classes/Warlock.lua`

**验证**: `test -f classes/Warlock.lua && test ! -f SM_Extend_Warlock.lua`

#### T4.2.6 — 迁移 `SM_Extend_Warrior.lua` → `classes/Warrior.lua`

**验证**: `test -f classes/Warrior.lua && test ! -f SM_Extend_Warrior.lua`

### 4.3 构建系统收尾

#### T4.3.1 — 验证 `build_order.txt` 完整性

- 确认所有 entity/、core/、classes/ 文件均已列入
- 确认文件顺序符合依赖关系（core → entity → classes）
- 确认无遗漏的根目录文件

**验证**: `grep -c "classes/Druid/" build_order.txt` ≥ 4

#### T4.3.2 — `build.sh` 切换为严格模式

- Phase 1 中 build.sh 对不存在的文件静默跳过
- 改为：文件不存在时报错退出

```bash
if [ -f "$line" ]; then
    printf '\n' >> "$target"
    cat "$line" >> "$target"
else
    echo "ERROR: File not found: $line" >&2
    exit 1
fi
```

**验证**: `grep "ERROR: File not found" build.sh` 有结果

### Phase 4 汇总验证

```bash

# 构建成功

./build.sh && echo "Build OK"

# 目录结构正确

ls entity/Unit.lua entity/Player.lua entity/Target.lua entity/Pet.lua
ls core/class.lua core/periodic.lua core/events.lua core/combat_context.lua core/spell_trace.lua core/selftest.lua
ls classes/Druid.lua classes/Druid/cat.lua classes/Druid/bear.lua classes/Druid/utility.lua
ls classes/Hunter.lua classes/Mage.lua classes/Priest.lua classes/Rogue.lua classes/Warlock.lua classes/Warrior.lua

# 旧文件已全部清理

ls SM_Extend_*.lua 2>/dev/null  # 期望: No such file or directory

# Druid 关键函数完整（所有 macroTorch.* 全局符号在产物中可用）

grep -c "function macroTorch.\(catAtk\|regularAttack\|keepRip\|keepRake\|keepFF\|shouldUseShred\|shouldCastRip\|shouldUseBite\|canDoReshift\|bearAtk\|bearAoe\|druidBuffs\|pokemonLoad\)" SM_Extend.lua

# 期望: 13

# 自检注册完整

grep -c "SelfTest:register" SM_Extend.lua  # 期望: ≥70

# initPlayer 多态工厂存在

grep "function macroTorch.initPlayer" SM_Extend.lua

# 旧 hack 不在产物中

grep "macroTorch.player = macroTorch.druid" SM_Extend.lua  # 期望: 无结果

# classMetatable 在产物中仅定义一次

grep -c "function macroTorch.classMetatable" SM_Extend.lua  # 期望: 1

# 模块执行顺序验证（cat.lua 中 13 个模块按优先级排列）

grep "idolRecover\|healthManaSaver\|targetEnemy\|keepAutoAttack\|rushMod\|openerMod\|oocMod\|termMod\|otMod\|tigerFury\|debuffMod\|regularAttack\|reshift" classes/Druid/cat.lua
```

---

## Task 统计

| Phase | Task 数 | 关键产出 |
|-------|---------|---------|
| Phase 1 | 15 | classMetatable 工厂, initPlayer 多态, periodic.lua, 5 个 entity metatable 替换, build_order.txt + build.sh |
| Phase 2 | 9 | events.lua, combat_context.lua, spell_trace.lua（按函数组拆 3 task），battle_event_queue.lua 删除 |
| Phase 3 | 10 | SelfTest 框架 (1) + 4 类测试 (4) + 挂载 (1) + SpellTrace:register (1) + Druid 集成 (2) |
| Phase 4 | 14 | Druid 拆 4 文件 + 删除旧文件 (5)，6 个职业文件迁移 (6)，build_order 检查 (1)，build.sh 严格模式 (1) |
| **合计** | **48** | |

## 依赖关系

```
T1.1.1 ──→ T1.1.2 ──→ T1.3.* (metatable 替换依赖 classMetatable 工厂)
                    ──→ T1.2.1 (LRUStack 改用 classMetatable)
T1.2.1 ──→ T1.2.2 ──→ T1.2.3 ──→ T1.2.4
T1.3.* ──→ T1.5.1 (entity 路径确定后 build_order.txt 才能写全)
T1.4.1 ──→ T1.4.2
T1.4.2 依赖 T1.1.2 (initPlayer 存在)

Phase 1 ──→ Phase 2 (battle_event_queue 剩余内容拆分)
Phase 2 ──→ Phase 3 (SelfTest 挂载到 events.lua; spell_trace.lua 添加 register API)
Phase 3 ──→ Phase 4 (Druid 拆分时包含 Phase 3 的 SpellTrace:register + SelfTest 注册)
```

## 风险和缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 构建顺序错误导致运行时错误 | 高 | build_order.txt 明确定义顺序，每 Phase 后验证 |
| metatable 链行为变化 | 高 | classMetatable 保持精确等价逻辑，每 task 独立 grep 验证 |
| Druid 拆分导致函数引用断裂 | 中 | 所有函数保持 `macroTorch.*` 全局命名，不引入局部作用域 |
| spell trace 拆分后事件处理遗漏 | 中 | 逐行比对迁移，保留所有事件处理分支 |
| 自检在特定环境下误报 | 低 | pcall 包裹每个测试，可选模块均为 warning |

## 时间估算

| Phase | Task 数 | 预估工作量 | 关键复杂度 |
|-------|---------|----------|-----------|
| Phase 1 | 15 | 中-高 | classMetatable 设计、entity 文件逐个改造、initPlayer 惰性注册表 |
| Phase 2 | 9 | 高 | 518 行事件文件按函数组精确拆分、跨模块调用关系保持 |
| Phase 3 | 10 | 中 | 60+ 项自检测试编写、SpellTrace API 设计 |
| Phase 4 | 14 | 中-高 | 1751 行 Druid 精确拆分到 4 文件、6 职业迁移、严格模式切换 |
