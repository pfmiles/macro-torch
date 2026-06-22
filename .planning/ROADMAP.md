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

**Plans:** 6/6 plans complete
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — classMetatable 工厂 + initPlayer/registerPlayerClass (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — 删除多态 hack + Druid 注册 + initPlayer 接入 (Wave 2)
- [x] 01-03-PLAN.md — LRUStack 迁移 + periodic task 系统 + 独立 OnUpdate Frame + 清理 (Wave 2)
- [x] 01-04-PLAN.md — Unit/Player/Target → entity/ 迁移 + metatable 替换 (Wave 2)
- [x] 01-05-PLAN.md — Pet/TargetTarget/TargetPet/PetTarget/Group/Raid → entity/ 迁移 (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-06-PLAN.md — build_order.txt + build.sh 声明式构建系统 (Wave 3)

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

#### T1.3.1 — 改造 `Unit.lua` → `entity/Unit.lua`

- 文件移动到 `entity/Unit.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "UNIT_FIELD_FUNC_MAP")`
- `UNIT_FIELD_FUNC_MAP` 保持在 `Unit.lua` 中，作为全局变量 `macroTorch.UNIT_FIELD_FUNC_MAP`

**验证**: `grep "macroTorch.classMetatable" entity/Unit.lua` 有结果；`grep "setmetatable(obj, {" entity/Unit.lua` 无结果

#### T1.3.2 — 改造 `Player.lua` → `entity/Player.lua`

- 文件移动到 `entity/Player.lua`
- `new()` 中手写 metatable 替换为 `macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP")`
- `PLAYER_FIELD_FUNC_MAP` 保持全局注册

**验证**: `grep "macroTorch.classMetatable" entity/Player.lua` 有结果；`grep "setmetatable(obj, {" entity/Player.lua` 无结果

#### T1.3.3 — 改造 `Target.lua` → `entity/Target.lua`

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

**目标**: 将 `battle_event_queue.lua` 剩余内容按职责拆分到 `core/combat_context.lua`、`core/spell_trace_core.lua`、`core/spell_trace_immune.lua`、`core/events.lua`。

> **Frame 分离说明**: 原 `battle_event_queue.lua` 中一个 frame 同时承载 OnUpdate 和 OnEvent。Phase 1 已将 OnUpdate 迁入 `periodic.lua`，Phase 2 为 events 创建独立的 OnEvent frame，两者无共享状态。

**Plans:** 3/3 plans complete
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — 创建 core/combat_context.lua + core/spell_trace_core.lua（基础层）
- [x] 02-02-PLAN.md — 创建 core/spell_trace_immune.lua + core/events.lua（免疫追踪 + 事件层）

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-03-PLAN.md — 更新 build_order.txt + 删除 battle_event_queue.lua（收尾清理）

### 2.1 core/events.lua

#### T2.1.1 — 创建 `core/events.lua`，建立独立 OnEvent Frame

- 创建 `local frame = CreateFrame("Frame")`（独立于 periodic.lua）
- 注册 14 个事件：`PLAYER_ENTERING_WORLD`, `PLAYER_TARGET_CHANGED`, `SPELLCAST_START`, `SPELLCAST_STOP`, `SPELLCAST_FAILED`, `SPELLCAST_INTERRUPTED`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `CHAT_MSG_COMBAT_SELF_MISSES`, `CHAT_MSG_SPELL_SELF_DAMAGE`, `CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE`, `CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE`, `UI_ERROR_MESSAGE`, `UNIT_CASTEVENT` (SUPERWOW_STRING 条件)
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

- 创建三个独立函数供 eventHandle 调用：`onCombatExit()`, `onCombatEnter()`, `onPlayerEnteringWorld()`
- 不直接访问 WoW event 全局变量

**验证**: `grep "macroTorch.inCombat\|macroTorch.context" core/combat_context.lua` 有结果

#### T2.2.2 — 迁移 `loadImmuneTable` / `loadDefiniteBleedingTable`（注：移至 spell_trace_immune.lua 而非此处）

> **CONTEXT D-02 权威决策**: loadImmuneTable/loadDefiniteBleedingTable 放入 `core/spell_trace_immune.lua`，非 combat_context.lua。

**验证**: `grep "function macroTorch.loadImmuneTable\|function macroTorch.loadDefiniteBleedingTable" core/spell_trace_immune.lua` 均有结果；`grep "loadImmuneTable" core/combat_context.lua` 无结果

### 2.3 core/spell_trace_core.lua + core/spell_trace_immune.lua

#### T2.3.1 — 创建 `core/spell_trace_core.lua`，迁移 trace 基础设施 + cast/fail/land 表管理

- 迁移 `macroTorch.DEBUFF_LAND_LAG` 常量
- 迁移 `macroTorch.tracingSpells` / `macroTorch.traceSpellImmunes` 初始化
- 迁移 `setSpellTracing` / `setSpellTracingByName` / `setTraceSpellImmune` / `setTraceSpellImmuneByName`
- 迁移 `maintainLandTables` + `registerPeriodicTask`
- 迁移 `recordCastTable` / `recordFailTable` / `computeLandTable`
- 迁移 `consumeLandEvent` / `consumeFailEvent` / `peekCastEvent` / `peekFailEvent` / `peekLandEvent`
- 迁移 `landTableAnyMatch` / `landTableAllMatch` / `CheckDodgeParryBlockResist`

**验证**: 全部 17 个函数在 core/spell_trace_core.lua 中定义

#### T2.3.2 — 创建 `core/spell_trace_immune.lua`，迁移 immune tracing + 免疫/流血确定性表

- 迁移 `spellsImmuneTracing` + `registerPeriodicTask`
- 迁移 `loadImmuneTable` / `loadDefiniteBleedingTable`

**验证**: 全部 3 个函数在 core/spell_trace_immune.lua 中定义

### 2.4 清理

#### T2.4.1 — 删除 `battle_event_queue.lua` + 更新 build_order.txt

- 从 build_order.txt 移除 `battle_event_queue.lua` 条目
- 将 `core/spell_trace.lua` 条目替换为 `core/spell_trace_core.lua` + `core/spell_trace_immune.lua`
- 删除 `battle_event_queue.lua` 文件

**验证**: `test ! -f battle_event_queue.lua`；build_order.txt 不包含 battle_event_queue.lua 或 core/spell_trace.lua（单数）

### Phase 2 汇总验证

```bash

# 旧文件已不存在

test ! -f battle_event_queue.lua

# 新模块非空且合理大小

wc -l core/events.lua core/combat_context.lua core/spell_trace_core.lua core/spell_trace_immune.lua

# 期望: 每个 ≤250 行

# 关键函数分布正确

grep -c "function macroTorch.eventHandle" core/events.lua                           # 期望: 1
grep -c "function macroTorch.loadImmuneTable" core/spell_trace_immune.lua            # 期望: 1
grep -c "function macroTorch.CheckDodgeParryBlockResist" core/spell_trace_core.lua   # 期望: 1

# build_order.txt 正确

grep -c "battle_event_queue.lua" build_order.txt                                    # 期望: 0
grep -c "core/spell_trace_core.lua" build_order.txt                                 # 期望: 1
grep -c "core/spell_trace_immune.lua" build_order.txt                               # 期望: 1

# 构建成功

./build.sh && echo "Build OK"
```

---

## Phase 3: 自检系统 + Spell Trace 配置化

**覆盖需求**: R4 (Spell Trace 配置化), R5 (登录自检)

**目标**: 实现登录自检框架并填充内置测试，将 spell trace 改为声明式注册。

**Plans:** 4/4 plans complete
Plans:
**Wave 1**

- [x] 03-01-PLAN.md — SelfTest 框架 + ~60 项基础设施测试 + /mt SLASH 命令 (Wave 1)
- [x] 03-02-PLAN.md — SpellTrace:register() 声明式 API (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-03-PLAN.md — events.lua 挂载 SelfTest:run() + build_order.txt 顺序修正 (Wave 2)
- [x] 03-04-PLAN.md — Druid 改用 SpellTrace:register() + 职业自检注册 (Wave 2)

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

- 在 `core/spell_trace_core.lua` 中添加 `macroTorch.SpellTrace:register(name, config)`
  - `config.immune` — 是否追踪免疫 (bool)
  - `config.land` — 是否追踪 land 事件 (bool)
  - `config.debuffTexture` — debuff 贴图纹理（可选）
- 内部自动调用 `setSpellTracing` + `setTraceSpellImmune`

**验证**: `grep "function macroTorch.SpellTrace:register" core/spell_trace_core.lua` 有结果

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

**Plans:** 3/3 plans complete
Plans:
**Wave 1**

- [x] 04-01-PLAN.md -- Druid split: SM_Extend_Druid.lua into 4 files under classes/druid/ (Wave 1)
- [x] 04-02-PLAN.md -- Non-Druid migration: 6 SM_Extend_*.lua to classes/ via git mv + Hunter TODO (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-03-PLAN.md -- Build system finalization: build_order.txt + build.sh strict mode + cleanup (Wave 2)

**覆盖需求**: R6 (classes/ 目录), R8 (Druid 逻辑保持)

**目标**: 拆分 Druid 大类，归类所有职业文件，完成最终目录结构。构建系统切换为严格模式。

### 4.1 Druid 文件拆分（1870 行 → 4 文件）

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
ls core/class.lua core/periodic.lua core/events.lua core/combat_context.lua core/spell_trace_core.lua core/spell_trace_immune.lua core/selftest.lua
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

### Phase 5: Druid技能方法封装改造 - 将player.cast()字符串调用重构为技能对象方法，支持多语言客户端，从Druid试点

**Goal:** Refactor `player.cast('SkillName')` string-based spell casting into typed skill object methods (`player.claw()`, `player.wrath('safe')`) with multi-locale support (en/zh). Druid pilot phase covering ~53 skill methods and ~32 call sites across 5 files.

**Requirements**: R8, D-01 through D-08
**Depends on:** Phase 4
**Plans:** 5/5 plans complete
Plans:
**Wave 1**

- [x] 05-01-PLAN.md — Add _castSpell, _isInRange, _hasResource to entity/Player.lua (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 05-02-PLAN.md — Add ~43 Druid skill methods to classes/druid/Druid.lua, remove old wrappers (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 05-03-PLAN.md — Replace ~13 player.cast() calls in cat.lua + Druid.lua (Berserk + safeFF), delete 12 safe/ready functions (Wave 3)
- [x] 05-04-PLAN.md — Replace ~6 player.cast() calls in bear.lua, delete 9 safe/ready functions (Wave 3)
- [x] 05-05-PLAN.md — Replace ~13 player.cast() calls in utility.lua (Wave 3)

### Phase 6: Fix Druid _castSpell isSpellReady nil bug (colon/dot syntax mismatch in Player.lua)

**Goal:** Fix colon/dot syntax mismatch in _castSpell that causes all Druid skill methods to silently fail. Replace 4 self:xxx() internal calls in entity/Player.lua with obj.xxx(), and replace 53 self:_castSpell(...) calls in classes/druid/Druid.lua with obj._castSpell(...). Add ~15 Category F selftest tests and HUMAN-UAT.md manual checklist.
**Requirements**: R8, D-01 through D-07
**Depends on:** Phase 5
**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 06-01-PLAN.md — Fix _castSpell internal calls (4 lines in entity/Player.lua) + Druid skill methods (53 lines in classes/druid/Druid.lua) + Category F selftest (15 tests in core/selftest.lua) (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 06-02-PLAN.md — Create HUMAN-UAT.md manual test checklist (Wave 2)

### Phase 7: Druid 形态判断语义化方法

**Goal:** 在保留 isFormActive 通用方法的同时，为 Druid 类新增 5 个语义化形态判断方法（isInCatForm/isInBearForm/isInTravelForm/isInAquaticForm/isInCasterForm），并替换 Druid.lua/bear.lua/utility.lua 中现有的 isFormActive 硬编码调用。
**Requirements**: REQ-07-SEMANTIC, REQ-07-REPLACE, REQ-07-BEAR-OR, REQ-07-RESERVED, REQ-07-SELFTEST
**Depends on:** Phase 6
**Plans:** 1/1 plans complete
Plans:

- [x] 07-01-PLAN.md — 新增 5 个 DRUID_FIELD_FUNC_MAP 形态判断条目 + 替换 7 处 isFormActive 硬编码调用 + 更新 5 个 Category G2 SelfTest 注册

### Phase 8: 对照当前druid相关的代码架构及目录组织结构，将现有的其它职业的代码也重构为同样的架构及目录结构；目前除了druid，其它职业的代码逻辑其实并未真正使用，因此你可以大胆重构而无需担心破坏它们的业务逻辑

**Goal:** 将 Hunter/Warrior/Rogue/Mage/Priest/Warlock 共 6 个非 Druid 职业文件重构为与 Druid 一致的 classes/<class>/ 子目录架构，包含完整类定义（classMetatable + FIELD_FUNC_MAP + registerPlayerClass）、_castSpell 技能方法（多语言支持）、SpellTrace:register 声明式注册、SelfTest:register 自检注册
**Requirements**: REQ-08-CLASS-DEF, REQ-08-SKILL-METHODS, REQ-08-SPELLTRACE, REQ-08-SELFTEST, REQ-08-BUILD, REQ-08-NO-FLAT, REQ-08-INITPLAYER
**Depends on:** Phase 7
**Plans:** 4/4 plans complete
Plans:
**Wave 1**

- [x] 08-01-PLAN.md — Hunter (3 files) + Warrior (3 files) 类定义、技能方法、战斗/工具文件创建 (Wave 1)
- [x] 08-02-PLAN.md — Rogue (2 files) + Mage (2 files) 类定义、技能方法、战斗文件创建 + Rogue 英文技能名确认检查点 (Wave 1)
- [x] 08-03-PLAN.md — Priest (3 files) + Warlock (2 files) 类定义、技能方法、战斗/工具文件创建 (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 08-04-PLAN.md — build_order.txt 更新 + 6 个旧扁平文件删除 + build.sh 构建验证 (Wave 2)

### Phase 9: 将pokemonLoad从druid/utility.lua移动到Player层作为通用方法

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 8
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 9 to break down)

### Phase 10: 创建5个Druid综合一键宏方法: druidAtk/druidAoe/druidHeal/druidDefend/druidControl, 内部按形态路由到对应方法

**Goal:** 创建 classes/druid/combo.lua，提供 5 个全局顶层"一键宏"方法（druidAtk/druidAoe/druidHeal/druidDefend/druidControl），按形态 if-elseif 链路由到对应子方法；同时将 catAtk 中的 bear 路由逻辑提取到 druidAtk，删除 utility.lua 中的旧版 druidStun/druidDefend/druidControl。
**Requirements**: D-01 through D-21 (from 10-CONTEXT.md)
**Depends on:** Phase 9
**Plans:** 2 plans

Plans:

- [x] 10-01-PLAN.md — 创建 classes/druid/combo.lua (5 个 combo 方法 + 5 个 SelfTest 注册)
- [x] 10-02-PLAN.md — 修改 Druid.lua (删除 bear 路由) + utility.lua (删除 3 个旧函数) + build_order.txt (添加 combo.lua)

---

### Phase 11: druidHeal 智能治疗 — 单人补buff vs 团/队最低血量目标

**Goal:** 改造 druidHeal 使其区分单人模式和团队模式。单人模式按"补buff"逻辑依次施放回春→愈合→治疗之触；团队/raid模式遍历成员找到血量最低者，根据其损血百分比选择技能（90%回春、70%愈合、50%治疗之触），目标限定40码范围内。

**Requirements**: REQ-11-SOLO, REQ-11-GROUP, REQ-11-RANGE
**Depends on:** Phase 10
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 11 to break down)

### Phase 13: 使catAtk一键宏适配小号练级场景：技能存在性检查、动态能量消耗计算、低等级降级策略，同时保持60级满级极限DPS能力不变

**Goal:** 使 catAtk 一键宏适配小号练级场景：技能存在性检查（isSpellExist guard）、动态能量消耗计算（computeReshiftEnergy 替代硬编码60）、低等级降级策略（模块级 guard 自动跳过不可用技能，rotation 自然 fallback 到 Claw）。保持60级满级极限DPS能力完全不变。

**Requirements**: R8-PRESERVE (60级满技能+DPS不变), LOW-LVL-SKIP (低等级自动跳过不可用技能), DYNAMIC-RESHIFT (天赋+装备动态计算reshift能量), DECISION-GUARD (共享决策函数skill缺失时返回false)
**Depends on:** Phase 10
**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 13-01-PLAN.md — Guard插入: computeReshiftEnergy新函数+RESHIFT_ENERGY动态替换+3个共享决策函数guard+openerMod guard+shouldDoReshift零值检查 (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 13-02-PLAN.md — Selftest: 8个Category H自检注册 (computeReshiftEnergy范围验证/决策函数guard验证/level60对等验证/fallback链验证) (Wave 2)

### Phase 14: 改进战斗时长预测与斩杀判断 — 将 isTrivialBattle 和 isKillShotOrLastChance 中硬编码的60级静态DPS估算（条件B）替换为等级自适应的动态估算，使练级阶段也能准确判断'快速战斗'和'斩杀线'

**Goal:** 将 `isTrivialBattle` 和 `isKillShotOrLastChance` 中硬编码的60级静态DPS估算（条件B）替换为等级自适应的动态估算，使练级阶段也能准确判断"快速战斗"和"斩杀线"

**Requirements**: REQ-14-DPS, REQ-14-KS, REQ-14-DELETE, REQ-14-GUARD, REQ-14-FALLBACK, REQ-14-TEST
**Depends on:** Phase 13
**Plans:** 1/1 plans complete

Plans:

- [x] 14-01-PLAN.md — Add estimatePlayerDPS() + getKSThreshold(), modify isTrivialBattle condition B, simplify isKillShotOrLastChance, delete 15 KS_CP* constants, add 6 Category I selftests

### Phase 15: 将catAtk从Druid实例方法重构为combo.lua全局一键宏方法

**Goal:** 将 catAtk 从 `obj.catAtk`（Druid 实例方法）重构为 `macroTorch.catAtk(rough)`（combo.lua 全局一键宏方法），与 casterAtk/bearAtk 等其他一键宏保持一致的调用模式。函数体逻辑不变，仅改变挂载位置和调用方式。

**Requirements**: REQ-15-MOVE, REQ-15-CALLER, REQ-15-SELFTEST
**Depends on:** Phase 10
**Plans:** 1/1 plans complete
**Status:** ✅ complete

Plans:

- [x] 15-01 — 将 catAtk 函数体从 Druid.lua 移至 combo.lua，更新 druidAtk 调用方，添加 selftest，构建验证通过 (2026-06-20)

### Phase 16: 目前catAtk的逻辑作为满级猫德输出逻辑已经拿到了服务器第一dps，是经过了实战考验的。现在我在练新的猫德角色，希望练级过程也能用上一键宏，但我并不希望直接在catAtk上面改，而是专门在catLeveling函数中构造一个练级版；对于练级过程来讲，除了用技能之前都要判断该技能是否存在(可能还没学到)之外，只有3个点比较重要：起手技、中间循环(包括debuff、buff保持以及伤害循环)、斩杀线；起手技其实只有ravage或pounce，这个的选择依赖对战斗时长的预测：如果预测本次战斗属于"快速战斗"，则用ravage,否则用pounce,判断是否"快速战斗"的逻辑可以重用catAtk中用的逻辑; "中间循环"主要是保持自身猛虎之怒、保持目标身上的双流血buff，以及见缝插针地用精灵之火(野性版)，这部分逻辑可以参考catAtk现有逻辑，但不必直接调用catAtk，而是为catLeveling重新实现，毕竟里面应该会有差异；最后的"斩杀线"判断对于练级也很重要，它能够判断何时使用一个技能(通常是消耗连击点数的直接伤害终结技)能够不浪费连击点数地终结掉当前的目标，使得dps最大化、从而杀怪时间最短化，这个斩杀线的计算方法应该也是能和catAtk共用的

**Goal:** 创建 catLeveling() 练级版一键宏 — 独立于 catAtk 实现，按优先级链执行起手技选择(Ravage/Pounce)、斩杀判断(复用 isKillShotOrLastChance)、中间循环(TF/Rip/Rake/FF/Shred/Claw)、Reshift(低等级自动跳过)。全程 isSpellExist guard，无神像逻辑，无 catAtk keep 模块调用。
**Requirements**: REQ-16-01, REQ-16-02, REQ-16-03, REQ-16-04, REQ-16-05, REQ-16-06, REQ-16-07
**Depends on:** Phase 15
**Plans:** 2 plans

Plans:
**Wave 1**

- [ ] 16-01-PLAN.md — catLeveling 完整实现（clickContext + 9 模块 + druidAtk 路由更新）

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 16-02-PLAN.md — catLeveling Selftest 注册（6 条测试：函数存在性、共享函数引用、catAtk 不变性）

---

## Task 统计

| Phase | Task 数 | 关键产出 |
|-------|---------|---------|
| Phase 1 | 15 | classMetatable 工厂, initPlayer 多态, periodic.lua, 5 个 entity metatable 替换, build_order.txt + build.sh |
| Phase 2 | 5 | events.lua, combat_context.lua, spell_trace_core.lua, spell_trace_immune.lua, battle_event_queue.lua 删除 |
| Phase 3 | 10 | SelfTest 框架 (1) + 4 类测试 (4) + 挂载 (1) + SpellTrace:register (1) + Druid 集成 (2) |
| Phase 4 | 14 | Druid 拆 4 文件 + 删除旧文件 (5)，6 个职业文件迁移 (6)，build_order 检查 (1)，build.sh 严格模式 (1) |
| **合计** | **44** | |

## 依赖关系

```
T1.1.1 ──→ T1.1.2 ──→ T1.3.* (metatable 替换依赖 classMetatable 工厂)
                    ──→ T1.2.1 (LRUStack 改用 classMetatable)
T1.2.1 ──→ T1.2.2 ──→ T1.2.3 ──→ T1.2.4
T1.3.* ──→ T1.5.1 (entity 路径确定后 build_order.txt 才能写全)
T1.4.1 ──→ T1.4.2
T1.4.2 依赖 T1.1.2 (initPlayer 存在)

Phase 1 ──→ Phase 2 (battle_event_queue 剩余内容拆分)
Phase 2 ──→ Phase 3 (SelfTest 挂载到 events.lua; spell_trace_core.lua 添加 register API)
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
| Phase 2 | 5 | 高 | 468 行事件文件按函数组精确拆分、跨模块调用关系保持 |
| Phase 3 | 10 | 中 | 60+ 项自检测试编写、SpellTrace API 设计 |
| Phase 4 | 14 | 中-高 | 1751 行 Druid 精确拆分到 4 文件、6 职业迁移、严格模式切换 |
