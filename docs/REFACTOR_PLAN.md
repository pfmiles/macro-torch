# macro-torch 重构计划

## Context

macro-torch 是一个 WoW 1.12.1 插件，为 SuperMacro 生成一键战斗宏代码。猫德逻辑已成熟（全服 DPS 第一），但整体架构存在技术债务：
- 五个类的 metatable 构建代码大量重复（每个类 ~9 行完全相同的模式）
- 战斗事件系统与职业逻辑混杂在同一文件
- Group/Raid 实体是空壳
- Player → Druid 的多态通过运行时替换实例实现（hack）
- 构建脚本依赖脆弱的 `grep -v` 黑名单
- 没有登录自检机制

目标：**沉淀通用的实体层和基础设施**，使任何职业都能以统一的 OOP 方式编写宏逻辑，同时保持猫德全部现有功能。新增登录自检机制保障代码变更安全。

---

## 核心设计

### 1. 统一 Metatable 工厂函数

提取 `macroTorch.classMetatable(cls, fieldMapName)` 函数，一行替代重复模板：

```lua
-- core/class.lua
function macroTorch.classMetatable(cls, fieldMapName)
    return {
        __index = function(t, k)
            if fieldMapName and macroTorch[fieldMapName] and macroTorch[fieldMapName][k] ~= nil then
                return macroTorch[fieldMapName][k](t)
            end
            return cls[k]  -- cls 是父类实例，自然触发递归 metatable 回退
        end
    }
end
```

使用方式：
```lua
function macroTorch.Player:new()
    local obj = {}
    -- 定义实例方法...
    setmetatable(obj, macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP"))
    return obj
end
```

**不改变现有语义**。"类即父类实例"的递归 metatable 链完全保留：
```
druid 实例 → DRUID_FIELD_FUNC_MAP → Druid class（Player 实例）
  → PLAYER_FIELD_FUNC_MAP → Player class（Unit 实例）
  → UNIT_FIELD_FUNC_MAP → Unit class
```

### 2. 多态初始化

用工厂函数替代当前 hack（`battle_event_queue.lua:76-78` 的运行时替换）：

```lua
-- macro_torch.lua
function macroTorch.initPlayer()
    local class = UnitClass('player')
    if class == 'Druid' and macroTorch.Druid then
        return macroTorch.Druid:new()
    elseif class == 'Hunter' and macroTorch.Hunter then
        return macroTorch.Hunter:new()
    -- ... 其他职业
    else
        return macroTorch.Player:new()
    end
end

-- 在 PLAYER_ENTERING_WORLD 事件中调用
macroTorch.player = macroTorch.initPlayer()
```

`macroTorch.player` 从一开始就是正确类型的实例，不需要后续替换。

### 3. 登录自检机制（Self-Test）

每次进入世界时自动运行，验证关键 API 和模块可用性。

**设计原则：**
- 始终运行，不让用户手动触发
- 用 `pcall` 包裹每个测试，单个失败不阻塞其他测试
- 在聊天框输出汇总结果：`[macro-torch] Self-test: X passed, Y failed, Z warnings`
- 可选模块（UnitXP, SP3）失败只报 warning，不报 error
- 成功项不打日志，仅汇总 + 失败/warning 可见
- 可扩展：各职业可以注册自己的检查项

**核心文件：`core/selftest.lua`**

```lua
macroTorch.SelfTest = {
    tests = {},
    results = { passed = 0, failed = 0, warnings = 0 }
}

function macroTorch.SelfTest:register(name, fn, isOptional)
    table.insert(self.tests, { name = name, fn = fn, optional = isOptional })
end

function macroTorch.SelfTest:run()
    self.results = { passed = 0, failed = 0, warnings = 0 }
    for _, test in ipairs(self.tests) do
        local ok, err = pcall(test.fn)
        if ok then
            self.results.passed = self.results.passed + 1
        elseif test.optional then
            self.results.warnings = self.results.warnings + 1
            macroTorch.show("[WARN] " .. test.name .. ": " .. tostring(err), "yellow")
        else
            self.results.failed = self.results.failed + 1
            macroTorch.show("[FAIL] " .. test.name .. ": " .. tostring(err), "red")
        end
    end
    local msg = string.format("[macro-torch] Self-test: %d passed, %d failed, %d warnings",
        self.results.passed, self.results.failed, self.results.warnings)
    local color = self.results.failed > 0 and "red" or "green"
    macroTorch.show(msg, color)
end
```

**内置测试覆盖四类检查：**

**(a) Lua 基础环境**
- 基本的 Lua 标准库函数（`type`, `table.insert`, `string.find`, `pcall`, `setmetatable` 等）
- 直接调用并验证返回类型

**(b) 可选扩展模块（均为 warning，不影响核心功能）**
- UnitXP — 距离计算、背后判定（代码中 `Unit.lua:149`、`Player.lua:504`、`biz_util.lua:187` 使用）
- SP3（SUPERWOW）— 提供 `SUPERWOW_STRING` 全局变量、`UNIT_CASTEVENT` 事件、`UnitExists` 返回 guid（`battle_event_queue.lua:66-68`、`Unit.lua:117` 使用）

**(c) 实体属性 —— 实际调用验证**

Player（始终可用，直接调用并验证返回类型）：
- `health` → number, `mana` → number, `healthMax` → number, `manaMax` → number
- `isInCombat` → boolean, `isExist` → boolean, `isDead` → boolean
- `class` → string, `name` → string, `level` → number, `guid` → number (if SP3)
- `isPlayerControlled` → boolean, `isInGroup` → boolean
- `hasBuff` → function, `buffed` → function（method 存在性）

Target / Pet（不一定可用，检查函数存在性 + 类型）：
- Target：`isCanAttack`, `isExist`, `isFriendly`, `isHostile`, `isPlayerControlled` — 验证 `type(fn) == 'function'`，若当前有目标则额外实际调用一次
- Pet：`isExist`, `isAttackActive` — 验证存在性，若有宠物则实际调用

**(d) WoW API 可用性验证**

测试策略：**能调用的就直接调用并验返回值类型，不能立即调用的验函数存在性**。

可直接调用（传入 `"player"` 参数，始终安全）：
- `UnitHealth("player")` → number
- `UnitMana("player")` → number
- `UnitHealthMax("player")` → number
- `UnitManaMax("player")` → number
- `UnitExists("player")` → truthy
- `UnitClass("player")` → string
- `UnitName("player")` → string
- `UnitLevel("player")` → number
- `UnitIsDead("player")` → boolean (false)
- `UnitAffectingCombat("player")` → boolean
- `UnitPowerType("player")` → 调用不报错
- `UnitRace("player")` → string
- `UnitSex("player")` → number
- `UnitFactionGroup("player")` → string
- `UnitIsPlayer("player")` → true
- `GetNumShapeshiftForms()` → number
- `GetComboPoints()` → number
- `GetNumPartyMembers()` → number (可能 0)
- `GetNumRaidMembers()` → number (可能 0)
- `HasPetUI()` → boolean
- `GetTime()` → number
- `GetBattlefieldInstanceRunTime()` → number
- `GetInventoryItemLink("player", 1)` → string or nil
- `GetActionTexture(1)` → string or nil
- `GetActionCooldown(1)` → number
- `GetSpellName(1, "spell")` → string or nil

仅检测存在性（不能无副作用调用或可能失败）：
- `UnitCanAttack`, `UnitCanAssist`, `UnitIsEnemy`, `UnitPlayerControlled`
- `UnitCreatureType`, `UnitCreatureFamily`, `UnitClassification`, `UnitInRaid`, `UnitIsUnit`
- `UnitBuff`, `UnitDebuff`, `GetPlayerBuffTimeLeft`
- `CastSpell`, `CastSpellByName`, `CastShapeshiftForm`, `SpellReady`, `GetSpellCooldown`
- `GetSpellTexture`, `GetSpellAutocast`, `ToggleSpellAutocast`, `IsCurrentCast`
- `IsAttackAction`, `IsCurrentAction`, `IsAutoRepeatAction`, `IsEquippedAction`, `HasAction`, `UseAction`
- `GetActionText`, `GetInventoryItemCooldown`, `GetInventoryItemTexture`, `GetInventorySlotInfo`
- `GetContainerItemLink`, `GetContainerItemCooldown`, `GetContainerItemInfo`, `GetContainerNumSlots`, `UseContainerItem`
- `GetShapeshiftFormInfo`, `GetNumTalents`, `GetNumTalentTabs`, `GetTalentInfo`
- `PetAttack`, `PetAggressiveMode`, `PetDefensiveMode`, `PetPassiveMode`, `PetFollow`, `PetWait`, `PetDismiss`, `PetStopAttack`, `IsPetAttackActive`
- `TargetNearestEnemy`, `TargetUnit`, `TargetTarget`, `TargetPet`, `ClearTarget`, `AssistUnit`, `CheckInteractDistance`
- `CreateFrame`, `SendChatMessage`

**扩展点：** 各职业可在类文件中注册职业特定测试（如 Druid 检查猫形态技能是否存在）：
```lua
macroTorch.SelfTest:register("Druid: cat form spells exist", function()
    assert(macroTorch.isSpellExist("Shred", "spell"), "Shred missing")
    assert(macroTorch.isSpellExist("Rip", "spell"), "Rip missing")
end)
```

### 4. Spell Trace 配置化

当前 spell tracing 通过全局表手动管理。重构为声明式注册：

```lua
-- 各职业在类初始化时注册
macroTorch.SpellTrace:register("Rip", {
    immune   = true,
    land     = true,
    debuffTexture = "Ability_GhoulFrenzy"
})
```

内部 castTable → failTable → landTable → immuneTable 的计算逻辑保留，只改注册入口。

### 5. 文件目录结构

子目录仅用于源码组织，构建产物仍是单个 `SM_Extend.lua`（不使用 Lua 的 `require`/`module` 机制）：

```
macro-torch/
├── macro_torch.lua           # 命名空间 + initPlayer
├── impl_util.lua             # 基础工具函数（tableLen, toBoolean 等）
├── biz_util.lua              # 业务工具（getSpellIdByName, castSpellByName 等）
├── core/
│   ├── class.lua             # classMetatable 工厂 + initPlayer
│   ├── periodic.lua          # 周期性任务调度 + LRUStack（从 event_stack.lua 迁入）
│   ├── events.lua            # 事件帧 + eventHandle + PLAYER_ENTERING_WORLD 自检触发
│   ├── combat_context.lua    # 战斗进出、context 生命周期
│   ├── spell_trace.lua       # 可配置的 spell trace + SpellTrace:register()
│   └── selftest.lua          # 自检框架 + 内置测试
├── entity/
│   ├── Unit.lua              # 基类
│   ├── Player.lua            # 玩家类
│   ├── Target.lua            # 目标类 + HRPS
│   ├── Pet.lua               # 宠物类
│   ├── Group.lua             # 小队（空壳，待定）
│   ├── Raid.lua              # 团队（空壳，待定）
│   ├── TargetTarget.lua
│   ├── TargetPet.lua
│   └── PetTarget.lua
├── classes/
│   ├── Druid.lua             # Druid 类定义 + FIELD_FUNC_MAP + 能量常量（唯一实战级职业）
│   ├── Druid/
│   │   ├── cat.lua           # catAtk + 所有猫形态模块
│   │   ├── bear.lua          # 熊形态模块
│   │   └── utility.lua       # druidBuffs, druidStun, druidDefend, 物品装载等
│   ├── Hunter.lua            # 以下 6 个为参考样例，展示实体 API 用法，无实战逻辑
│   ├── Mage.lua
│   ├── Priest.lua
│   ├── Rogue.lua
│   ├── Warlock.lua
│   └── Warrior.lua
├── interface_debug.lua       # 调试工具
├── texture_map.lua           # 贴图映射
├── build_order.txt           # 声明式拼接顺序
└── build.sh                  # 新构建脚本
```

### 6. Group / Raid 实体

暂保持空壳（`macroTorch.group = {}`、`macroTorch.raid = {}`），待后续明确使用模式后再决定是继承 Unit 还是走集合/迭代器路线。

### 7. 构建系统

`build_order.txt` 每行一个文件路径，空行和 `#` 注释忽略。`build.sh` 读取并按序拼接，保留 Cygwin 拷贝到 SuperMacro 目录的逻辑。

---

## 实施步骤

### Step 1: 创建 `core/class.lua` + `core/periodic.lua`

- 从 `event_stack.lua` 迁移 `LRUStack` 到 `core/periodic.lua`
- 新建 `core/class.lua`，实现 `macroTorch.classMetatable(cls, fieldMapName)`
- 实现 `macroTorch.initPlayer()` 多态工厂

### Step 2: 改造 Entity 层使用 `classMetatable`

修改 `Unit.lua`、`Player.lua`、`Target.lua`、`Pet.lua`、`TargetTarget.lua` 的 `new()` 方法，将 `setmetatable` 模板替换为一行 `macroTorch.classMetatable(self, "FIELD_MAP_NAME")`。

**不改变任何逻辑**，纯代码去重。字段查找行为完全等价。

### Step 3: 拆分 `battle_event_queue.lua` → `core/`

- `core/periodic.lua`：`registerPeriodicTask`、`setRepeat`、`onPeriodicUpdate`、`LRUStack`
- `core/events.lua`：CreateFrame、事件注册、`eventHandle` 入口、挂载自检触发
- `core/combat_context.lua`：`PLAYER_REGEN_ENABLED/DISABLED` 处理、`macroTorch.context` 生命周期
- `core/spell_trace.lua`：`tracingSpells`、`traceSpellImmunes`、`maintainLandTables`、`spellsImmuneTracing`、`recordCastTable`、`recordFailTable`、`computeLandTable` + `SpellTrace:register()` API

### Step 4: 实现 `core/selftest.lua` — 自检系统

- 实现 `SelfTest:register()` / `SelfTest:run()` 框架
- 编写内置测试注册（模块检测、API 检测、实体属性检测）
- 在 `core/events.lua` 的 `PLAYER_ENTERING_WORLD` 事件中调用 `macroTorch.SelfTest:run()`
- Druid 类在 `classes/Druid.lua` 中注册职业特定测试

### Step 5: 拆分 `SM_Extend_Druid.lua` + 归类其他职业

- `classes/Druid.lua`：类定义、构造器、`DRUID_FIELD_FUNC_MAP`、能量常量初始化、职业自检注册
- `classes/Druid/cat.lua`：`catAtk` 及所有模块（burstMod, oocMod, termMod, keepRip, keepRake, regularAttack, reshift 等）
- `classes/Druid/bear.lua`：`bearOocMod`、`bearAoe` 等熊形态函数
- `classes/Druid/utility.lua`：`druidBuffs`、`druidStun`、`druidDefend`、`druidControl`、物品装载逻辑
- 其他 6 个职业文件（Hunter/Mage/Priest/Rogue/Warlock/Warrior）：直接迁移到 `classes/` 下，不拆子模块，作为参考样例保留

### Step 6: 移除多态 hack + 适配 Spell Trace

- 删除 `battle_event_queue.lua` 中 `macroTorch.player = macroTorch.druid` 的替换逻辑
- 改为依赖 Step 1 的 `initPlayer()` 多态工厂
- 在 `classes/Druid.lua` 初始化中，将原有的 `setSpellTracing` / `setTraceSpellImmune` 调用改为 `SpellTrace:register()` 风格

### Step 7: 创建 `build_order.txt` + 重写 `build.sh`

---

## 验证

- `./build.sh` 生成 `SM_Extend.lua`
- 自检覆盖：`grep "SelfTest:register"` 统计注册的测试数量，预期 ≥ 50 项
- Druid 符号完整：`grep -c "function macroTorch.\(catAtk\|regularAttack\|keepRip\|keepRake\|keepFF\)" SM_Extend.lua`
- metatable 链审查：追踪 `druid_instance.health` → `DRUID_FIELD_FUNC_MAP` → `Druid class` → `PLAYER_FIELD_FUNC_MAP` → `Player class` → `UNIT_FIELD_FUNC_MAP` → 找到
- `initPlayer()` 正确：Druid 登录时 `macroTorch.player` 类型为 Druid 实例，具备 `comboPoints`、`isOoc`、`isProwling` 等 Druid 专属字段
- 进游戏验证自检报告输出到聊天框，无 FAIL 项