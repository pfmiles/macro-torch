# macro-torch 重构需求

## R1: 统一 Metatable 工厂

**来源**: REFACTOR_PLAN.md §1

所有实体类的 `new()` 方法使用统一的 `macroTorch.classMetatable(cls, fieldMapName)` 工厂函数替代手写 metatable 模板。

**受影响的类** (5个):
- `Unit.lua` — 使用 `"UNIT_FIELD_FUNC_MAP"` ✅ (01-04)
- `Player.lua` — 使用 `"PLAYER_FIELD_FUNC_MAP"` ✅ (01-04)
- `Target.lua` — 使用 `"TARGET_FIELD_FUNC_MAP"` ✅ (01-04)
- `Pet.lua` — 使用 `"PET_FIELD_FUNC_MAP"` (等待 01-05)
- `SM_Extend_Druid.lua` — 使用 `"DRUID_FIELD_FUNC_MAP"` (等待后续 Phase)

**验收标准**:
- [-] `grep -c "setmetatable(obj, {"` 在 entity/ 和 classes/ 下结果为 0（不含 core/class.lua 自身）
- [-] `grep -c "macroTorch.classMetatable"` 在 entity/ + classes/ 下结果 ≥ 5（当前: 3 — Unit/Player/Target 完成 via 01-04）
- [ ] 字段查找行为完全等价：`druid.health` → `DRUID_FIELD_FUNC_MAP` → `Druid class` → `PLAYER_FIELD_FUNC_MAP` → `Player class` → `UNIT_FIELD_FUNC_MAP` → 找到

## R2: 多态初始化

**来源**: REFACTOR_PLAN.md §2

`macroTorch.player` 从一开始就是正确类型的实例，不需要运行时替换。

**验收标准**:
- [ ] `macroTorch.initPlayer()` 工厂函数存在，根据 `UnitClass('player')` 返回正确类型的实例
- [ ] `battle_event_queue.lua` 中不再有 `macroTorch.player = macroTorch.druid` 的替换逻辑
- [ ] Druid 登录时 `macroTorch.player` 类型为 Druid 实例，具备 `comboPoints`、`isOoc`、`isProwling` 等专属字段
- [ ] 非 Druid 职业登录时 `macroTorch.player` 类型为 Player 实例

## R3: 战斗事件系统模块化

**来源**: REFACTOR_PLAN.md §3

将 `battle_event_queue.lua` (518 行) 按职责拆分为 4 个 `core/` 模块:

| 新文件 | 职责 | 迁入内容 |
|--------|------|----------|
| `core/periodic.lua` | 周期性任务调度 | `registerPeriodicTask`, `setRepeat`, `onPeriodicUpdate`, `LRUStack` (从 `event_stack.lua`) |
| `core/events.lua` | 事件帧 + 事件处理 | CreateFrame, 事件注册, `eventHandle`, `PLAYER_ENTERING_WORLD` 自检触发 |
| `core/combat_context.lua` | 战斗进出 + context 生命周期 | `PLAYER_REGEN_ENABLED/DISABLED`, `macroTorch.context` 初始化/销毁 |
| `core/spell_trace.lua` | Spell trace + immune 追踪 | `tracingSpells`, `traceSpellImmunes`, `maintainLandTables`, `spellsImmuneTracing`, `recordCastTable`, `recordFailTable`, `computeLandTable`, `CheckDodgeParryBlockResist` |

**验收标准**:
- [ ] `battle_event_queue.lua` 不超过 10 行（仅剩兼容重定向或完全删除）
- [ ] 4 个新 `core/` 模块各不超过 250 行
- [ ] `build_order.txt` 中 core/ 文件出现在正确位置
- [ ] 登录游戏进入战斗后 spell trace、immune 检测、combat context 功能正常

## R4: Spell Trace 配置化

**来源**: REFACTOR_PLAN.md §4

提供 `macroTorch.SpellTrace:register(name, config)` 声明式 API 替代命令式的 `setSpellTracing` + `setTraceSpellImmune` 调用对。

**验收标准**:
- [ ] `SpellTrace:register()` API 存在，接受 `{immune, land, debuffTexture}` 配置
- [ ] Druid 类使用 `SpellTrace:register()` 注册所有需要追踪的 spell（Rip, Rake, Shred, Claw, FF 等）
- [ ] 内部 castTable → failTable → landTable → immuneTable 计算逻辑不变

## R5: 登录自检机制

**来源**: REFACTOR_PLAN.md §3, §4 (Step 4)

每次 `PLAYER_ENTERING_WORLD` 事件触发时自动运行自检，验证关键 API 和模块可用性。

**验收标准**:
- [ ] `core/selftest.lua` 实现 `SelfTest:register()` / `SelfTest:run()` 框架
- [ ] 内置测试覆盖: Lua 基础环境 (≥5项), 可选模块 (UnitXP, SP3), Player 实体属性 (≥15项), Target/Pet 实体属性, WoW API (≥50项)
- [ ] 聊天框输出汇总: `[macro-torch] Self-test: X passed, Y failed, Z warnings`
- [ ] 成功项不打印日志，仅汇总行 + 失败/warning 可见
- [ ] 可选模块失败报 warning（黄色），核心模块失败报 error（红色）
- [ ] 每个测试用 `pcall` 包裹，单个失败不阻塞其他测试
- [ ] Druid 职业在 `classes/Druid.lua` 中注册职业特定测试（猫形态技能存在性）

## R6: 文件目录重组

**来源**: REFACTOR_PLAN.md §5

按三层架构重组文件:

```
entity/   — Unit, Player, Target, Pet, Group, Raid, TargetTarget, TargetPet, PetTarget
core/     — class, periodic, events, combat_context, spell_trace, selftest
classes/  — Druid (含 Druid/cat, Druid/bear, Druid/utility), Hunter, Mage, Priest, Rogue, Warlock, Warrior
```

根目录保留: `macro_torch.lua`, `impl_util.lua`, `biz_util.lua`, `interface_debug.lua`, `texture_map.lua`

**验收标准**:
- [-] 目录结构符合上述规划（entity/: Unit/Player/Target 已迁 via 01-04, core/: class.lua 已创建 via 01-01）
- [ ] 所有 `macroTorch.*` 全局符号在新位置保持可用
- [ ] `build.sh` 生成的 `SM_Extend.lua` 中符号完整

## R7: 声明式构建系统

**来源**: REFACTOR_PLAN.md §7

`build_order.txt` 每行一个文件路径，空行和 `#` 注释忽略。`build.sh` 读取并按序拼接。

**验收标准**:
- [ ] `build_order.txt` 包含所有源文件的明确顺序
- [ ] `build.sh` 不使用 `grep -v` 黑名单
- [ ] `./build.sh` 成功生成 `SM_Extend.lua`
- [ ] 产物与原 `SM_Extend.lua` 中的功能等价（Druid catAtk 逻辑完整）

## R8: Druid 猫德逻辑保持

**来源**: 用户硬约束

所有现有的 cat 形态战斗逻辑（catAtk, keepRip, keepRake, keepFF, regularAttack, reshift 等）保持功能完全不变。

**验收标准**:
- [ ] `grep -c "function macroTorch.\(catAtk\|regularAttack\|keepRip\|keepRake\|keepFF\|shouldUseShred\|shouldCastRip\|shouldUseBite\|canDoReshift\)" SM_Extend.lua` 返回 ≥ 9
- [ ] 能量常量（CLAW_E, SHRED_E, RAKE_E 等）初始化逻辑不变
- [ ] DRUID_FIELD_FUNC_MAP 所有字段不变
- [ ] 模块执行顺序不变（idolRecover → healthManaSaver → targetEnemy → keepAutoAttack → rushMod → openerMod → oocMod → termMod → otMod → tigerFury → debuffMod → regularAttack → reshift）

## 优先级

| 优先级 | 需求 | 理由 |
|--------|------|------|
| P0 | R1, R2, R3, R7 | 基础设施和构建系统必须先到位 |
| P1 | R6 | 目录结构是后续工作的骨架 |
| P2 | R4, R5 | 自检和配置化是质量保障 |
| P3 | R8 | 全程验证，每个 phase 后确认 |