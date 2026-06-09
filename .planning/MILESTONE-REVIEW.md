---
status: reviewed
scope: milestone
milestone: v1.0 — macro-torch 架构重构
phases_reviewed: [01, 02, 03, 04]
total_files_reviewed: 28
depth: deep
critical: 0
warning: 3
info: 5
total: 8
reviewed_at: 2026-06-09
---

# 里程碑 v1.0 完整审查报告

## 审查范围

从 Phase 1 首个 commit (`e87a412`) 到 HEAD (`e64a796`)，共 28 个源文件变更。

| 层 | 文件数 | 文件 |
|----|--------|------|
| core/ | 7 | class, periodic, events, combat_context, spell_trace_core, spell_trace_immune, selftest |
| entity/ | 9 | Unit, Player, Target, Pet, TargetTarget, TargetPet, PetTarget, Group, Raid |
| classes/ | 8 | Druid (4子文件), Hunter, Mage, Priest, Rogue, Warlock, Warrior |
| 根目录 | 4 | build_order.txt, build.sh, battle_event_queue.lua(已删除), event_stack.lua(已删除) |

---

## 目标达成评估

### R1: 统一 Metatable 工厂 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| 手写 `setmetatable(obj, {` 在 entity/ + classes/ 下为 0 | ✅ 0 处匹配 |
| `classMetatable` 使用次数 ≥ 5 | ✅ 13 处 (SM_Extend.lua) |
| 字段查找行为等价 | ✅ metatable 链不变 |

**覆盖**: Unit, Player, Target, Pet, TargetTarget, TargetPet, PetTarget, Druid, Hunter, LRUStack — 共 10 个类使用 classMetatable。

### R2: 多态初始化 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| `initPlayer()` 工厂存在 | ✅ `core/class.lua:52` |
| `battle_event_queue.lua` 已删除 | ✅ 文件完全删除 |
| Druid 登录时 player 类型为 Druid | ✅ `registerPlayerClass("DRUID", ...)` 在 Druid.lua:254 |
| 非 Druid fallback 到 Player | ✅ `initPlayer()` fallback 逻辑正确 |

**注意**: 仅 Druid 注册了 `PLAYER_CLASS_REGISTRY`。Hunter 有完整的类定义但未注册 — 这是有意的，因为非 Druid 职业类仅为参考样例。详见 Info-01。

### R3: 战斗事件系统模块化 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| `battle_event_queue.lua` ≤ 10 行或完全删除 | ✅ 完全删除 |
| 4 个 core/ 模块存在 | ✅ periodic(139行), events(118行), combat_context(40行), spell_trace(274行 split into 2 files) |
| 功能正常 | ✅ 各模块独立 Frame，无共享状态 |

### R4: Spell Trace 配置化 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| `SpellTrace:register()` API 存在 | ✅ `spell_trace_core.lua:58` |
| Druid 使用声明式 API | ✅ 5 个 spell (Pounce, Rake, Rip, FB, FF) 在 Druid.lua:437-456 |
| 内部计算逻辑不变 | ✅ castTable → failTable → landTable → immuneTable 链完整 |

### R5: 登录自检机制 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| `SelfTest:register()` / `SelfTest:run()` | ✅ `selftest.lua:34,49` |
| 内置测试覆盖 | ✅ 96 项注册 (10 Lua + 34 WoW API + 20 Player + 7 Target/Pet + 2 Optional + 25 Druid) |
| PLAYER_ENTERING_WORLD 自动触发 | ✅ `events.lua:52` |
| pcall 隔离 | ✅ 每个测试独立 pcall |

### R6: 文件目录重组 ✅ 达成

```
entity/  — 9 files ✅
core/    — 7 files ✅
classes/ — 8 files (Druid/含子目录 + 6 个其他职业) ✅
```

### R7: 声明式构建系统 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| `build_order.txt` 明确顺序 | ✅ 37 行，含注释分组 |
| `build.sh` 不用 `grep -v` 黑名单 | ✅ 严格模式，文件缺失时报错退出 |
| `./build.sh` 成功生成 | ✅ SM_Extend.lua 生成正常 |

### R8: Druid 猫德逻辑保持 ✅ 达成

| 验收标准 | 结果 |
|----------|------|
| ≥9 个关键函数存在 | ✅ 9+ 个：regularAttack, keepRip, keepRake, keepFF, shouldUseShred, shouldCastRip, shouldUseBite, shouldDoReshift (原 canDoReshift), shouldCastFFDuringWaitWindow, reshiftMod |
| 能量常量逻辑不变 | ✅ CLAW_E, SHRED_E, RAKE_E 等全部保留 |
| 模块执行顺序不变 | ✅ 0-12 模块顺序与 CLAUDE.md 文档一致 |

**说明**: `catAtk` 是 Druid 实例方法 (`obj.catAtk`)，而非全局函数 — 这是 OOP 设计的正确实现。

---

## 发现项

### ⚠️ 警告 (Warning)

#### WR-01: `not not` 双重否定惯用法 — 风格不一致
- **文件**: `classes/druid/Druid.lua:848`
- **代码**: `if not not macroTorch.loginContext.tigerTimer then`
- **说明**: `not not x` 在 Lua 中是合法的布尔强制转换，但项目中其他位置统一使用 `macroTorch.toBoolean()`。这种不一致降低了代码可读性。
- **建议**: 改为 `if macroTorch.toBoolean(macroTorch.loginContext.tigerTimer) then` 以保持风格一致。

#### WR-02: Mage/Priest/Rogue/Warlock/Warrior 无类定义和 metatable
- **文件**: `classes/{Mage,Priest,Rogue,Warlock,Warrior}.lua`
- **说明**: 这 5 个文件仅包含全局辅助函数（如 `mageRangedAtk`），没有 `macroTorch.Xxx = macroTorch.Player:new()` 类定义，也没有 `:new()` 构造器。与 Hunter（有完整类定义+classMetatable）和 Druid（有完整类定义+classMetatable+注册表）不一致。
- **建议**: 如果这些文件仅为参考样例，建议在文件头部添加注释说明其参考性质；如果将来需要支持这些职业，需要补充类定义。

#### WR-03: `ffLeft` 使用 `not not` 双重否定
- **文件**: `classes/druid/Druid.lua:936`
- **代码**: `if not not macroTorch.context.ffTimer then`
- **说明**: 同 WR-01，使用 `not not` 做布尔强制转换。
- **建议**: 改为 `macroTorch.toBoolean(macroTorch.context.ffTimer)`。

### ℹ️ 信息 (Info)

#### Info-01: 仅 Druid 注册了 PLAYER_CLASS_REGISTRY
- **文件**: `classes/druid/Druid.lua:254`, `core/class.lua:52`
- **说明**: 当前 `initPlayer()` 工厂的注册表只有 Druid 一个条目。所有其他职业都 fallback 到 `macroTorch.Player:new()`。考虑到当前只有 Druid 有实战级别的猫德逻辑，这是合理的。
- **影响**: 如果将来要为其他职业添加实战逻辑，需要记得调用 `registerPlayerClass()`。

#### Info-02: `_selfTestRan` 标志位生命周期
- **文件**: `core/selftest.lua:26,51`
- **说明**: 自检只运行一次（通过 `_selfTestRan` 标志位控制），后续 `/mt` 命令可手动触发。这符合设计要求（"成功项不打印日志，仅汇总行"）。但需注意：`_selfTestRan` 只在 UI reload 时重置，游戏中无法通过常规操作重置。
- **影响**: 低。设计如此。

#### Info-03: spell_trace 拆分为两个文件
- **文件**: `core/spell_trace_core.lua` + `core/spell_trace_immune.lua`
- **说明**: Phase 2 将 spell trace 功能拆分为 core（cast/fail/land table 核心逻辑，274行）和 immune（免疫追踪+持久化表加载，104行）两个文件。原始 REFACTOR_PLAN 中预计为单个 `spell_trace.lua`，实际拆分为两个更符合单一职责原则。
- **影响**: 无。实际设计优于原始计划。

#### Info-04: Hunter 类有完整定义但未注册
- **文件**: `classes/Hunter.lua:17-55`
- **说明**: Hunter 有完整的 `:new()` 构造器 + `classMetatable` + `HUNTER_FIELD_FUNC_MAP`，但未调用 `registerPlayerClass("HUNTER", macroTorch.Hunter)`。这意味着 `initPlayer()` 不会为猎人返回 Hunter 实例。
- **影响**: 低。当前 Hunter 类主要为参考样例。

#### Info-05: `build.sh` 严格模式下缺少 Cygwin 检查
- **文件**: `build.sh:31-33`
- **说明**: Cygwin 拷贝逻辑使用 `$OSTYPE = "cygwin"` 检查。在 macOS/Linux 上不会触发拷贝，这是正确的。但如果用户使用 MSYS2 或 WSL，`$OSTYPE` 可能不同，拷贝不会自动执行。
- **影响**: 低。当前用户使用 macOS。

---

## 架构评估

### 正面评价

1. **单一职责**: `battle_event_queue.lua`（原 518 行）成功拆分为 7 个独立模块，每个模块职责明确
2. **消除重复**: `classMetatable` 工厂消除了 10 个类中 ~90 行重复的 metatable 模板代码
3. **消除 Hack**: `initPlayer()` 工厂替代了运行时实例替换 hack
4. **声明式优于命令式**: `SpellTrace:register()` API 替代了成对的 `setSpellTracing`/`setTraceSpellImmune` 调用
5. **质量保障**: 96 项自检覆盖，每次进入世界自动运行
6. **构建系统进化**: 从容错模式（Phase 1）到严格模式（Phase 4），渐进式提高质量门禁

### 关注点

1. **非 Druid 职业类**: 5 个职业类（Mage/Priest/Rogue/Warlock/Warrior）是纯全局函数集合，与 Druid/Hunter 的 OOP 风格不一致。如果长远目标是对所有职业使用统一 OOP 模式，建议逐步完善。
2. **Group/Raid 仍为空壳**: 与里程碑开始前状态相同，未做任何实现。

---

## 逻辑正确性

### 已验证正确的逻辑链路

| 链路 | 状态 |
|------|------|
| `initPlayer()` → `PLAYER_CLASS_REGISTRY` 查表 → `Druid:new()` | ✅ |
| `Druid:new()` → `classMetatable(self, "DRUID_FIELD_FUNC_MAP")` → metatable 链 | ✅ |
| `SpellTrace:register()` → `setSpellTracing()` + `setTraceSpellImmune()` | ✅ |
| `eventHandle()` → `PLAYER_ENTERING_WORLD` → `onPlayerEnteringWorld()` → `initPlayer()` + `SelfTest:run()` | ✅ |
| `onPeriodicUpdate()` → pcall 保护 → 定时任务执行 | ✅ |
| `spellsImmuneTracing()` → `consumeFailEvent()` / `consumeLandEvent()` → immune 表维护 | ✅ |
| `catAtk()` 模块执行顺序: idolRecover → healthMana → targetEnemy → autoAttack → burstMod → openerMod → oocMod → termMod → otMod → tigerFury → debuffMod → regularAttack → reshiftMod | ✅ |
| `computeNormalRelic()` 战斗模式分支 (非战斗/快速/普通) | ✅ |
| `shouldDoReshift()` 能量预算计算 + `math.ceil()` 比较 | ✅ |

### 代码审查修复历史 (已修复)

以下问题已在 Phase 1-4 的代码审查中发现并修复，本次审查确认修复有效：

| ID | 问题 | 修复 commit |
|----|------|-------------|
| CR-01 (04) | `pickPocketState` 应为全局 `macroTorch.pickPocketState` | `145ddb2` |
| CR-02 (04) | `build.sh` 中 bash-specific `[[ ]]` 替换为 POSIX `[ ]` | `3b8b3a6` |
| WR-01 (04) | Hunter metatable 改用 classMetatable | `3237a7d` |
| WR-02 (04) | `computeNormalRelic` 中无效 nil-check | `d199768` |
| WR-03 (04) | `mageRangedAtk`/`mageMeleeAtk` 未使用参数 `reapLine` | `b67b4d6` |
| WR-01 (03) | `SUPERWOW_STRING` 检查增加 nil guard | `ca00432` |
| WR-02 (03) | 自测中的裸全局引用 | `4ab4897` |
| WR-03 (03) | Savagery snapshot flags 移至 loginContext | `9a11d76` |
| WR-04 (03) | ripLeft/rakeLeft nil guard | `d434657` |
| WR-05 (03) | SpellTrace:register() spellId 验证 | `6fb44e8` |
| WR-06 (03) | computeNormalRelic nil guard | `eda6200` |
| WR-01-04 (02) | immune 追踪 nil guard + 文档 | `cf43081` 等 |
| WR-01-03 (01) | onPeriodicUpdate collect-then-delete + build_order.txt 缺失 guard + Druid metatable | `12c7ff0` 等 |

---

## 总结

**里程碑目标已达成**。8 项需求全部满足，架构重构完成：

- ✅ 消除了 metatable 模板重复
- ✅ 消除了运行时多态 hack
- ✅ `battle_event_queue.lua` 成功拆分为 7 个独立模块
- ✅ 建立了声明式 SpellTrace API
- ✅ 建立了 96 项登录自检机制
- ✅ 文件按三层架构重组
- ✅ 构建系统进化为声明式严格模式
- ✅ Druid 猫德全部战斗逻辑完整保留

**3 个警告**（代码风格不一致、非 Druid 类缺少结构）和 **5 个信息项**，无严重（Critical）问题。

**建议**: 可以放心发布。WR-01/WR-03 的风格修复可以在后续随手处理。