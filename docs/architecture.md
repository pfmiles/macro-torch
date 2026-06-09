# macro-torch 重构完成后代码架构

> 最后更新: 2026-06-09 | Phase 1-4 全部完成后的最终架构

## 总览

macro-torch 重构将原有的单文件混杂架构重组为 **4 层分层的模块化结构**：

- **根目录** — 入口命名空间 + 工具函数
- **core/** — 基础设施层（class 工厂、周期任务、事件系统、战斗上下文、spell trace、自检）
- **entity/** — 实体层（OOP 类继承体系，统一 metatable 构建）
- **classes/** — 职业层（各职业技能逻辑，Druid 1751 行拆为 4 文件）

构建系统从脆弱的 `grep -v` 黑名单改为**声明式 build_order.txt + 严格模式 build.sh**。

---

## 构建系统

```
┌──────────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  build_order.txt     │───▶│  build.sh         │───▶│  SM_Extend.lua   │
│  声明式文件列表        │    │  严格模式拼接器    │    │  单文件构建产物    │
│  core/→entity/→classes│    │  文件缺失则报错    │    │  ≈3000+ 行 Lua    │
└──────────────────────┘    └──────────────────┘    └──────────────────┘
```

**build_order.txt** 按依赖顺序列出所有源文件，支持注释 (`#`) 和空行。构建顺序：

```
macro_torch.lua → impl_util.lua → biz_util.lua
  → core/class.lua → core/periodic.lua
  → entity/Unit.lua → entity/Player.lua → entity/Target.lua → entity/Pet.lua
  → entity/TargetTarget.lua → entity/TargetPet.lua → entity/PetTarget.lua
  → entity/Group.lua → entity/Raid.lua
  → texture_map.lua → interface_debug.lua
  → core/combat_context.lua → core/spell_trace_core.lua
  → core/spell_trace_immune.lua → core/events.lua
  → core/selftest.lua
  → classes/druid/Druid.lua → classes/druid/cat.lua → classes/druid/bear.lua → classes/druid/utility.lua
  → classes/Hunter.lua → classes/Mage.lua → classes/Priest.lua
  → classes/Rogue.lua → classes/Warlock.lua → classes/Warrior.lua
```

**build.sh** 严格模式下，任何文件缺失都会报错退出，确保构建产物完整性。

---

## 分层架构

### 根目录 · 入口与工具层

```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│macro_torch   │ │impl_util.lua │ │biz_util.lua  │ │texture_map   │ │interface_    │
│.lua          │ │              │ │              │ │.lua          │ │debug.lua     │
│              │ │string/table  │ │业务工具       │ │              │ │              │
│全局命名空间   │ │工具函数       │ │距离/背包      │ │贴图映射       │ │调试接口       │
│macroTorch={} │ │              │ │              │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

| 文件 | 职责 |
|------|------|
| `macro_torch.lua` | 全局命名空间 `macroTorch={}` |
| `impl_util.lua` | string/table 工具函数 |
| `biz_util.lua` | 业务工具函数（距离计算、背包操作等） |
| `texture_map.lua` | 贴图纹理映射表 |
| `interface_debug.lua` | 调试接口函数 |

---

### core/ · 基础设施层 (Phase 1-3)

```
┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│ class.lua [P1] │ │periodic.lua[P1]│ │ events.lua [P2]│ │selftest.lua[P3]│
│                │ │                │ │                │ │                │
│ classMetatable │ │ LRUStack       │ │ 独立OnEvent    │ │ SelfTest       │
│ 工厂函数       │ │ 数据结构       │ │ Frame          │ │ :register()    │
│                │ │                │ │                │ │ :run()         │
│ initPlayer()   │ │ register       │ │ 14个事件注册   │ │                │
│ 多态初始化     │ │ PeriodicTask   │ │                │ │ 60+内置测试    │
│                │ │ remove         │ │ eventHandle    │ │                │
│ registerPlayer │ │ PeriodicTask   │ │ 集中式if-elseif│ │ Lua基础/WoW API│
│ Class() 注册表 │ │ setRepeat      │ │ dispatch       │ │ Player/Target  │
│                │ │                │ │                │ │ /Pet 属性      │
│                │ │ onPeriodic     │ │ 挂载:          │ │                │
│                │ │ Update         │ │ SelfTest:run() │ │ 可扩展注册点   │
│                │ │ +独立OnUpdate  │ │ + initPlayer() │ │                │
│                │ │ Frame          │ │                │ │                │
└────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘

┌────────────────────┐ ┌──────────────────────────┐ ┌──────────────────────┐
│combat_context [P2] │ │spell_trace_core.lua [P2] │ │spell_trace_immune    │
│.lua                │ │                          │ │.lua [P2]             │
│                    │ │ 17个 trace 核心函数       │ │                      │
│ onCombatExit()     │ │ · setSpellTracing        │ │ spellsImmuneTracing  │
│ onCombatEnter()    │ │ · setTraceSpellImmune    │ │ 免疫追踪             │
│ onPlayerEntering   │ │ · maintainLandTables     │ │                      │
│ World()            │ │ · recordCastTable        │ │ loadImmuneTable      │
│                    │ │ · recordFailTable        │ │ 免疫表加载           │
│ 战斗状态管理       │ │ · computeLandTable       │ │                      │
│ context 生命周期   │ │ · consumeLandEvent       │ │ loadDefiniteBleeding │
│ inCombat 标志      │ │ · consumeFailEvent       │ │ Table                │
│                    │ │ · peekCast/Fail/Land     │ │ 确定性流血表加载     │
│                    │ │ · landTableAnyMatch      │ │                      │
│                    │ │ · landTableAllMatch      │ │                      │
│                    │ │ · CheckDodgeParry        │ │                      │
│                    │ │   BlockResist            │ │                      │
│                    │ │                          │ │                      │
│                    │ │ DEBUFF_LAND_LAG 常量     │ │                      │
│                    │ │                          │ │                      │
│                    │ │ [P3] SpellTrace:register │ │                      │
│                    │ │ 声明式注册 API           │ │                      │
└────────────────────┘ └──────────────────────────┘ └──────────────────────┘
```

| 文件 | Phase | 职责 |
|------|-------|------|
| `class.lua` | P1 | `classMetatable` 工厂（统一 metatable 构建）、`initPlayer()` 多态工厂、`registerPlayerClass()` 惰性注册表 |
| `periodic.lua` | P1 | `LRUStack` 数据结构、周期任务管理（`registerPeriodicTask`/`removePeriodicTask`/`setRepeat`）、独立 OnUpdate Frame |
| `events.lua` | P2 | 独立 OnEvent Frame、14 个事件注册、`eventHandle` 集中式 dispatch、挂载 SelfTest + initPlayer |
| `combat_context.lua` | P2 | `onCombatExit`/`onCombatEnter`/`onPlayerEnteringWorld` 战斗状态管理、`context` 生命周期、`inCombat` 标志 |
| `spell_trace_core.lua` | P2-P3 | 17 个 spell trace 函数 + `DEBUFF_LAND_LAG` 常量、`SpellTrace:register()` 声明式 API (P3) |
| `spell_trace_immune.lua` | P2 | `spellsImmuneTracing` 免疫追踪、`loadImmuneTable`/`loadDefiniteBleedingTable` 表加载 |
| `selftest.lua` | P3 | `SelfTest:register`/`SelfTest:run` 框架、60+ 项内置测试、可扩展注册点 |

---

### entity/ · 实体层 (Phase 1)

```
                        ┌──────────────────────┐
                        │     Unit.lua 基类     │
                        │  UNIT_FIELD_FUNC_MAP │
                        │  buff/debuff 检测    │
                        └──────────┬───────────┘
                                   │ extends
           ┌───────────┬───────────┼───────────┬───────────┐
           ▼           ▼           ▼           ▼           ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
    │Player.lua│ │Target.lua│ │ Pet.lua  │ │TargetPet │ │PetTarget │
    │          │ │          │ │          │ │.lua      │ │.lua      │
    │PLAYER_   │ │TARGET_   │ │PET_      │ │          │ │          │
    │FIELD_FUNC│ │FIELD_FUNC│ │FIELD_FUNC│ │extends   │ │extends   │
    │_MAP      │ │_MAP      │ │_MAP      │ │Unit      │ │Unit      │
    │          │ │          │ │          │ │          │ │          │
    │技能施放  │ │免疫追踪  │ │          │ │          │ │          │
    │物品使用  │ │伤害预测  │ │          │ │          │ │          │
    │姿态检查  │ │特殊目标  │ │          │ │          │ │          │
    └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │TargetTarget  │
                 │.lua          │
                 │extends Target│
                 └──────────────┘

    ┌──────────────┐ ┌──────────────┐
    │ Group.lua    │ │ Raid.lua     │
    │ 空壳         │ │ 空壳         │
    └──────────────┘ └──────────────┘
```

| 文件 | 父类 | 职责 |
|------|------|------|
| `Unit.lua` | — | 基类，`UNIT_FIELD_FUNC_MAP`，buff/debuff 检测，战力评估 |
| `Player.lua` | Unit | `PLAYER_FIELD_FUNC_MAP`，技能施放、物品使用、姿态/形态检查 |
| `Target.lua` | Unit | `TARGET_FIELD_FUNC_MAP`，免疫追踪、伤害预测、特殊目标处理 |
| `Pet.lua` | Unit | `PET_FIELD_FUNC_MAP` |
| `TargetTarget.lua` | Target | 目标的目标，无独立 FIELD_FUNC_MAP |
| `TargetPet.lua` | Unit | 目标的宠物，无独立 FIELD_FUNC_MAP |
| `PetTarget.lua` | Unit | 宠物的目标，无独立 FIELD_FUNC_MAP |
| `Group.lua` | — | 空壳，预留给队伍逻辑 |
| `Raid.lua` | — | 空壳，预留给团队逻辑 |

所有实体类均使用 `classMetatable` 工厂构建 metatable，消除了 Phase 1 前手写的 ~9 行重复模板。

---

### classes/ · 职业层 (Phase 4)

```
┌──────────────────────────────────────────────────────────────┐
│               🐾 Druid (1842 行 → 4 文件拆分)                 │
│                                                              │
│  ┌─────────────────────┐  ┌─────────────────────────────┐   │
│  │ Druid.lua           │  │ cat.lua                     │   │
│  │                     │  │                             │   │
│  │ 类定义 + new()      │  │ catAtk 辅助函数            │   │
│  │ catAtk() 主入口     │  │                             │   │
│  │ 能量常量 (CLAW_E..) │  │ 13 个模块 (按优先级):       │   │
│  │ _MAP                │  │  0. idolRecover            │   │
│  │                     │  │  1. healthManaSaver        │   │
│  │ 全局共享辅助函数:    │  │  2. targetEnemy            │   │
│  │ · shouldUseShred    │  │  3. keepAutoAttack         │   │
│  │ · shouldCastRip     │  │  4. rushMod                │   │
│  │ · shouldUseBite     │  │  5. openerMod              │   │
│  │ · shouldCastFF      │  │  7. oocMod                 │   │
│  │   DuringWaitWindow  │  │  6. termMod                │   │
│  │ · getMinimum        │  │  8. otMod                  │   │
│  │   AffordableAbility │  │  9. tigerFury              │   │
│  │   Cost              │  │ 10. debuffMod              │   │
│  │ · computeErps       │  │     (keepRip/keepRake/     │   │
│  │ · computeNormalRelic│  │      keepFF/safeFF)        │   │
│  │                     │  │ 11. regularAttack          │   │
│  │ SpellTrace:register │  │     (Shred/Claw)           │   │
│  │ SelfTest:register   │  │ 12. reshiftMod             │   │
│  │                     │  │                             │   │
│  │ registerPlayerClass │  │ 辅助函数:                   │   │
│  │ ("Druid", ...)      │  │ · cp5Bite                  │   │
│  └─────────────────────┘  │ · canDoReshift             │   │
│                           │ · energyDischargeBeforeBite│   │
│  ┌─────────────────────┐  │ · dischargeEnergyChange    │   │
│  │ bear.lua            │  │   RelicAndRip              │   │
│  │                     │  │ · quickKeepRip             │   │
│  │ bearAtk()           │  └─────────────────────────────┘   │
│  │ bearOocMod          │                                    │
│  │ bearOtMod           │  ┌─────────────────────────────┐   │
│  │ bearDebuffMod       │  │ utility.lua                 │   │
│  │ bearRegularAttack   │  │                             │   │
│  │ bearReshiftMod      │  │ druidBuffs()                │   │
│  │ bearAoe             │  │ druidStun()                 │   │
│  └─────────────────────┘  │ druidDefend()               │   │
│                           │ druidControl()              │   │
│                           │ pokemonLoad() 物品装载系统  │   │
│                           └─────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘

┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│Hunter.lua│ │Mage.lua  │ │Priest.lua│ │Rogue.lua │ │Warlock   │ │Warrior   │
│          │ │          │ │          │ │          │ │.lua      │ │.lua      │
│原SM_     │ │原SM_     │ │原SM_     │ │原SM_     │ │原SM_     │ │原SM_     │
│Extend_   │ │Extend_   │ │Extend_   │ │Extend_   │ │Extend_   │ │Extend_   │
│Hunter    │ │Mage      │ │Priest    │ │Rogue     │ │Warlock   │ │Warrior   │
└──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘

所有 SM_Extend_*.lua 已删除，全部迁移至 classes/ 目录
```

| 文件 | 职责 |
|------|------|
| `classes/Druid.lua` | 类定义 + `catAtk()` 主入口 + 能量常量 + `DRUID_FIELD_FUNC_MAP` + 全局共享辅助函数 + SpellTrace/SelfTest 注册 |
| `classes/Druid/cat.lua` | 13 个模块 + cat 辅助函数 (~400 行) |
| `classes/Druid/bear.lua` | 熊形态全部逻辑 (~190 行) |
| `classes/Druid/utility.lua` | buffs/stun/defend/control + pokemonLoad 物品装载 (~90 行) |
| `classes/{Hunter,Mage,Priest,Rogue,Warlock,Warrior}.lua` | 原 `SM_Extend_*.lua` 直接迁移 |

---

## Metatable 继承链

这是整个 OOP 体系的核心设计模式。`classMetatable` 工厂统一构建所有 metatable，保持递归回退语义：

```
Druid 实例 (macroTorch.player)
  │
  │ __index 查找
  ▼
DRUID_FIELD_FUNC_MAP  ──不回退──▶  Druid class (Player 实例)
  (动态字段函数映射)                    │
                                      │ __index 查找
                                      ▼
                              PLAYER_FIELD_FUNC_MAP  ──不回退──▶  Player class (Unit 实例)
                                                                    │
                                                                    │ __index 查找
                                                                    ▼
                                                            UNIT_FIELD_FUNC_MAP  ──不回退──▶  Unit class (基类)
```

**查找顺序**: 实例自身 → FIELD_FUNC_MAP（同层不回退）→ 父级 class → 父级 FIELD_FUNC_MAP → ... → Unit class

**classMetatable 工厂实现**（`core/class.lua`）:

```lua
function macroTorch.classMetatable(cls, fieldMapName)
    return {
        __index = function(t, k)
            if fieldMapName and macroTorch[fieldMapName] and macroTorch[fieldMapName][k] ~= nil then
                return macroTorch[fieldMapName][k](t)
            end
            return cls[k]  -- 触发父级的递归 metatable 回退
        end
    }
end
```

所有实体类使用一行替换原来的 ~9 行手写 metatable 模板：

```lua
-- 之前 (每个类重复):
setmetatable(obj, {
    __index = function(t, k)
        if macroTorch.PLAYER_FIELD_FUNC_MAP and macroTorch.PLAYER_FIELD_FUNC_MAP[k] ~= nil then
            return macroTorch.PLAYER_FIELD_FUNC_MAP[k](t)
        end
        return self[k]
    end
})

-- 之后:
setmetatable(obj, macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP"))
```

---

## 运行时数据流

### 三大驱动模式

```
┌─────────────────────────────────────────────────────────────────┐
│  事件驱动 (events.lua → eventHandle)                             │
│                                                                  │
│  WoW 事件触发                                                    │
│    │                                                             │
│    ▼                                                             │
│  eventHandle(event)                                              │
│    │                                                             │
│    ├── PLAYER_REGEN_ENABLED  ──▶ onCombatExit()                  │
│    ├── PLAYER_REGEN_DISABLED ──▶ onCombatEnter()                 │
│    ├── PLAYER_ENTERING_WORLD ──▶ onPlayerEnteringWorld()         │
│    │                             + initPlayer()                  │
│    │                             + SelfTest:run()                │
│    ├── SPELLCAST_START       ──▶ setSpellTracing()               │
│    ├── SPELLCAST_FAILED      ──▶ recordFailTable()               │
│    ├── CHAT_MSG_SPELL_*      ──▶ recordCastTable()               │
│    │                             + computeLandTable()            │
│    ├── CHAT_MSG_COMBAT_*     ──▶ CheckDodgeParryBlockResist()    │
│    └── UI_ERROR_MESSAGE      ──▶ context.behindAttackFailedTime  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  周期驱动 (periodic.lua → OnUpdate)                              │
│                                                                  │
│  OnUpdate Frame (独立于 events.lua)                               │
│    │                                                             │
│    ├── maintainLandTables()    (spell_trace_core.lua)            │
│    │   清理过期的 cast/fail 表                                   │
│    │                                                             │
│    └── spellsImmuneTracing()   (spell_trace_immune.lua)          │
│        每 0.1s 检查免疫状态                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  用户驱动 (按钮按下 → 职业逻辑)                                   │
│                                                                  │
│  按钮按下                                                        │
│    │                                                             │
│    ▼                                                             │
│  catAtk() / bearAtk() / ...   (classes/)                        │
│    │                                                             │
│    ├── macroTorch.player.xxx  (entity/ 实例属性)                 │
│    ├── macroTorch.target.xxx  (entity/ 实例属性)                 │
│    ├── macroTorch.context     (core/combat_context)              │
│    ├── peekCastEvent()        (core/spell_trace_core)            │
│    ├── isImmune()             (entity/Target → spell_trace_immune)│
│    └── 施放决定 → CastSpell()  (WoW API)                         │
└─────────────────────────────────────────────────────────────────┘
```

### 启动流程

```
PLAYER_ENTERING_WORLD 事件
  │
  ├──▶ onPlayerEnteringWorld()
  │      ├── 初始化 loginContext = {}
  │      └── 调用 initPlayer()
  │             ├── UnitClass('player') 获取职业
  │             ├── 查 registerPlayerClass 注册表
  │             └── 返回 Druid/Player/... 实例
  │
  └──▶ SelfTest:run()
         ├── Lua 基础环境测试
         ├── Player 属性测试
         ├── Target/Pet 属性测试
         ├── WoW API 可用性测试
         └── 汇总输出到聊天框
```

### 全局对象

| 对象 | 类型 | 说明 |
|------|------|------|
| `macroTorch.player` | Player/Druid/... | `initPlayer()` 多态工厂创建 |
| `macroTorch.target` | Target | 当前目标 |
| `macroTorch.pet` | Pet | 玩家宠物 |
| `macroTorch.context` | table | 战斗上下文，进出战斗时创建/重置 |

---

## 文件统计

| 层级 | 目录 | 文件数 | Phase | 说明 |
|------|------|--------|-------|------|
| 入口+工具 | 根目录 | 5 | — | macro_torch, impl_util, biz_util, texture_map, interface_debug |
| 基础设施 | `core/` | 7 | P1-P3 | class, periodic, combat_context, spell_trace_core, spell_trace_immune, events, selftest |
| 实体层 | `entity/` | 9 | P1 | Unit, Player, Target, Pet, TargetTarget, TargetPet, PetTarget, Group, Raid |
| 职业层 | `classes/` | 10 | P4 | Druid(4), Hunter(1), Mage(1), Priest(1), Rogue(1), Warlock(1), Warrior(1) |
| 构建系统 | 根目录 | 2 | P1 | build_order.txt, build.sh |
| **合计** | | **33** | | |

---

## 关键设计决策

| 决策 | 说明 |
|------|------|
| **classMetatable 工厂** | 统一的 metatable 构建，替代 5 处重复手写模板，一行调用等价原 ~9 行代码 |
| **initPlayer 多态** | 惰性注册表 + 工厂函数，替代运行时 `macroTorch.player = macroTorch.druid` 的 hack |
| **Frame 分离** | periodic (OnUpdate) 和 events (OnEvent) 使用独立 Frame，无共享状态，避免耦合 |
| **声明式构建** | build_order.txt 单文件定义拼接顺序，build.sh 严格模式下文件缺失即报错 |
| **Druid 拆分** | 1751 行按职责拆为 4 文件（类定义 → 猫形态 → 熊形态 → 工具），均保持 `macroTorch.*` 全局命名 |
| **SelfTest 自检** | 每次进入世界自动运行 60+ 项测试，pcall 包裹单项、可选模块 warning 级别 |
| **SpellTrace 声明式** | `SpellTrace:register()` API 替代手动 `setSpellTracing` + `setTraceSpellImmune` 调用对 |

---

## 相关文件

- `docs/architecture.drawio` — draw.io 可编辑源文件（含颜色分层和更丰富视觉效果）
- `.planning/ROADMAP.md` — 完整路线图和 Phase 详情
- `docs/REFACTOR_PLAN.md` — 原始重构设计文档
- `build_order.txt` — 声明式构建顺序