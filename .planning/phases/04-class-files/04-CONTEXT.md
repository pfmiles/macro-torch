# Phase 4: 职业文件重组 + 构建系统收尾 - Context

**Gathered:** 2026-06-09
**Status:** Ready for planning

<domain>
## Phase Boundary

将 `SM_Extend_Druid.lua`（1870行）拆分为 4 个文件放入 `classes/druid/`，将其余 6 个 `SM_Extend_*.lua` 迁移到 `classes/` 目录，更新 `build_order.txt`，`build.sh` 从容错模式切换到严格模式，最后删除所有旧文件。

覆盖需求: R6 (classes/ 目录), R8 (Druid 逻辑保持)
</domain>

<decisions>
## Implementation Decisions

### Druid 拆分边界
- **D-01:** 采用按形态就近放置策略。单形态独占函数放对应形态文件，跨形态共享函数放 `classes/druid/Druid.lua`。

**`classes/druid/Druid.lua`** (~200行):
- `macroTorch.Druid:new()` 构造器
- `DRUID_FIELD_FUNC_MAP` 全部字段
- 能量常量：`CLAW_E`, `SHRED_E`, `RAKE_E`, `RIP_E`, `BITE_E`, `FF_E`, `COWER_E`, `TIGER_E` 等
- `registerPlayerClass("DRUID", ...)` 调用
- SpellTrace:register() 注册 + SelfTest:register() 注册
- 全局共享辅助函数：`shouldUseShred`, `shouldCastRip`, `shouldUseBite`, `shouldCastFFDuringWaitWindow`, `getMinimumAffordableAbilityCost`, `computeErps`, `computeNormalRelic`, `selectFerocityOrEmeraldRot`, `recoverNormalRelic`
- 能量计算函数：`computeClaw_E`, `computeShred_E`, `computeRake_E`, `computeRake_Duration`, `computeTiger_E`, `computeTiger_Duration`, `computeRake_Erps`, `computeRip_Erps`, `computePounce_Erps`
- 跨形态共享函数：`safeFF`, `isFightStarted`, `isKillShotOrLastChance`, `combatUrgentHPRestore`, `consumeDruidBattleEvents`

**`classes/druid/cat.lua`** (~1020行):
- `catAtk()` 主入口函数
- 13 个模块（按优先级顺序）
- cat 专属 safe/ready：`safeShred`, `readyShred`, `safeClaw`, `readyClaw`, `safeRake`, `safeRip`, `safeBite`, `readyBite`, `safeCower`, `readyCower`, `safeTigerFury`, `safePounce`, `atkPowerBurst`
- cat 专属辅助函数：`cp5Bite`, `energyDischargeBeforeBite`, `tryBiteKillShot`, `dischargeEnergyChangeRelicAndRip`, `quickKeepRip`, `shouldDoReshift`, `canDoReshift`
- cat 专属 combat helper：`isTrivialBattleOrPvp`, `isTrivialBattle`

**`classes/druid/bear.lua`** (~290行):
- `bearAtk()` 主入口函数
- bear 模块：`bearOocMod`, `bearOtMod`, `bearDebuffMod`, `bearFFMod`, `bearRegularAttack`, `bearReshiftMod`, `bearAoe`
- bear 专属 safe/ready：`safeMaul`, `readyMaul`, `safeSavageBite`, `readySavageBite`, `readyGrowl`, `safeDemoralizingRoar`, `readyDemoralizingRoar`, `safeSwipe`, `readySwipe`

**`classes/druid/utility.lua`** (~350行):
- `druidBuffs()`, `druidStun()`, `druidDefend()`, `druidControl()`
- `pokemonLoad()` 物品装载系统

### 构建系统切换策略
- **D-02:** 采用原子切换。一次性完成：创建所有 `classes/` 文件 → 更新 `build_order.txt`（移除旧路径、修正新路径） → `build.sh` 切换严格模式 → 删除所有 `SM_Extend_*.lua` 旧文件。单 commit 完成，git bisect 无中间态。

### classes/ 目录结构
- **D-03:** 采用统一子目录策略。Druid 主文件及子模块全部放入 `classes/druid/` 子目录：

```
classes/
├── druid/
│   ├── Druid.lua       ← 类定义、常量、共享函数、注册
│   ├── cat.lua         ← catAtk + 13模块
│   ├── bear.lua        ← bearAtk + bear模块
│   └── utility.lua     ← buff、控制、pokemonLoad
├── Hunter.lua
├── Mage.lua
├── Priest.lua
├── Rogue.lua
├── Warlock.lua
└── Warrior.lua
```

- 子目录 `druid/` 使用 snake_case，与 `entity/`、`core/` 命名约定一致
- 其他职业为单文件，放 `classes/` 顶层
- 只有需要拆分的职业（当前仅 Druid）才有子目录

### 非 Druid 职业处理
- **D-04:** 采用纯 rename + TODO 标记。6 个职业文件通过 `git mv` 迁移到 `classes/`，不改动功能代码。Hunter 手写 metatable 旁添加 TODO 注释（`-- TODO(Phase-N): migrate to macroTorch.classMetatable`），为后续各职业完善 Phase 留下清晰路标。其余 5 个 standalone 函数文件（Mage/Priest/Rogue/Warlock/Warrior）不做改动。

### Claude's Discretion
- build_order.txt 中 `classes/druid/Druid.lua` 必须排在 `classes/druid/cat.lua` 等子模块之前（父文件先于子模块加载）
- safe/ready 函数与 combat helper 的具体归属判断（单形态 vs 跨形态的边界）
- Druid 拆分时各文件精确行数（在 200/1020/290/350 目标附近浮动）
- build.sh 严格模式的具体错误信息格式
- Hunter TODO 注释的精确措辞
- 原子切换 commit 的文件变更顺序（先创建新文件再删除旧文件，保证中间状态可构建）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 4 完整实施步骤（T4.1 Druid 拆分、T4.2 职业迁移、T4.3 构建收尾）、验证命令
- `.planning/REQUIREMENTS.md` — R6 (文件目录重组) 和 R8 (Druid 猫德逻辑保持) 验收标准

### Phase 1-3 决策（影响 Phase 4）
- `.planning/phases/01-classmetatable-entity/01-CONTEXT.md` — D-09 (build_order.txt 一次性全量)、D-10 (容错→严格模式切换)
- `.planning/phases/02-events-system/02-CONTEXT.md` — D-03 (直接函数调用 + build_order 顺序)、D-04 (battle_event_queue 完全删除)
- `.planning/phases/03-spell-trace/03-CONTEXT.md` — D-06 (SpellTrace:register 声明式 API)、D-09 (Druid 自检覆盖边界)

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — Module execution order (0-12 priority)、OOP metatable 继承链、Combat event tracking flow
- `.planning/codebase/CONVENTIONS.md` — 全局函数命名、safe/ready 双模式、FIELD_FUNC_MAP 模式、构建拼接顺序
- `.planning/codebase/STRUCTURE.md` — 当前文件布局、build_order 顺序规则

### 关键源文件
- `SM_Extend_Druid.lua` (1870行) — Phase 4 拆分的源文件，所有 Druid 逻辑的权威来源
- `build_order.txt` (44行) — 当前包含新旧路径共存，Phase 4 需移除旧路径并修正新路径
- `build.sh` — 当前容错模式，Phase 4 切换严格模式
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **SM_Extend_Druid.lua** (1870行): 已使用 `macroTorch.classMetatable`、已集成 `SpellTrace:register()`（5个技能）、已注册 `SelfTest:register()`（~20项）。直接按函数边界拆分，无需改写任何函数内部实现。
- **SM_Extend_Hunter.lua** (6.8K): 唯一有 OOP 类结构的非 Druid 文件，手写 9 行 `setmetatable`/`__index` 模板，与 classMetatable 等价但未切换。迁移时仅加 TODO 注释。
- **build_order.txt** (44行): 已预置所有 Phase 4 classes/ 路径（当前被容错模式跳过），Phase 4 仅需修正路径字符串（`classes/Druid/` → `classes/druid/`）并移除旧 SM_Extend_*.lua 条目。

### Established Patterns
- **全局函数命名空间**: 所有函数均为 `macroTorch.*`，拆分不改变可见性，仅改变文件物理位置。`build_order.txt` 顺序保证定义先于调用。
- **safe/ready 双模式**: cat 形态和 bear 形态各自有独立的 safe/ready 函数集，天然适合按形态文件分组。
- **模块优先级顺序**: catAtk 中 13 个模块按固定优先级（0-12）执行，拆分后此顺序必须在 cat.lua 中完整保留。

### Integration Points
- **build_order.txt**: 移除 7 个 `SM_Extend_*.lua` 行，将 `classes/Druid.lua` 及 `classes/Druid/*.lua` 替换为 `classes/druid/Druid.lua` 等 4 行
- **build.sh**: 将 `[ -f "$line" ] && cat` 容错逻辑替换为严格检查（`[ -f "$line" ] || { echo "ERROR: File not found: $line"; exit 1; }`）
- **旧文件删除**: 7 个 `SM_Extend_*.lua` 文件在确认新路径构建成功后删除
- **ROADMAP.md**: T4.1.1-T4.1.4 验证命令中的路径需更新：`classes/Druid.lua` → `classes/druid/Druid.lua`，`classes/Druid/cat.lua` → `classes/druid/cat.lua` 等
</code_context>

<specifics>
## Specific Ideas

- Druid 子目录命名：`classes/druid/`（snake_case），主文件 `classes/druid/Druid.lua`（PascalCase 保持与类名一致）。`druid/` 子目录与 `core/`、`entity/` 命名风格统一。
- 原子切换的变更顺序：先创建所有 classes/ 新文件 → 更新 build_order.txt → 更新 build.sh → `./build.sh` 验证通过 → 删除旧 SM_Extend_*.lua 文件 → 再次 `./build.sh` 验证。确保任何中间 git checkout 都有可构建的 build_order.txt。
</specifics>

<deferred>
## Deferred Ideas

- **非 Druid 职业完善**: Hunter/Mage/Priest/Rogue/Warlock/Warrior 的功能完善（classMetatable 迁移、registerPlayerClass 注册、SelfTest 注册、SpellTrace 注册）属于未来独立 Phase。Phase 4 仅在 Hunter 手写 metatable 旁留 TODO 标记作为路标。
- **entity/ 和 core/ 目录重命名**: 若需将 `entity/`、`core/` 改为 PascalCase（与 `classes/druid/Druid.lua` 文件名风格一致），属于未来独立 Phase。

None — 讨论保持在 Phase 4 范围内。
</deferred>

---

*Phase: 04-职业文件重组 + 构建系统收尾*
*Context gathered: 2026-06-09*