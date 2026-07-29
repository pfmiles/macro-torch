# Phase 21: catAtk-maintainability - Context

**Gathered:** 2026-07-29
**Status:** Ready for planning

<domain>
## Phase Boundary

基于 `catAtk-core-principles.md` 原则→实现逆向审视的结论，对 `catAtk()` 及其子模块进行 4 项纯代码结构改进。**不改行为，零 DPS 影响。** 改动量 ~40 行，涉及 3 个文件。

**4 项改进：**
1. 修复 catAtk 注释编号连续性（combo.lua）
2. 为斩杀双入口添加设计意图注释（combo.lua + cat.lua）
3. 集中化 `isPseudoInfiniteEnergy` 判断（combo.lua + cat.lua + Druid.lua）
4. 从 keepRake 中标注 ATK 爆发副作用（cat.lua）

**来源文档：** `.planning/catAtk-phaseA-maintainability.md` — 包含完整的现状分析、改动方案和排除清单。下游 agent 必须先读此文档再开始计划。

**不在此范围内（已确认排除）：**
- burstMod 中 Berserk 守卫导致跳过后续爆发物品 — 故意设计
- 主动 FF 维护 — 暂缓，收益太小
- recoverNormalRelic 无限能量永不触发 — 已知限制
- oocMod 中 clickContext.ooc 缓存 1 帧延迟 — 可忽略
</domain>

<decisions>
## Implementation Decisions

### Item 1 & 2: 注释修复（纯注释改动）

- **D-01: catAtk 注释编号重排** — 将模块调用处的注释编号修正为与执行顺序一致的连续序列 0-12（0.recoverNormalRelic → 12.reshiftMod），与 `catAtk-core-principles.md` Rule 7 优先级表对齐。仅改注释文本。

- **D-02: 斩杀双入口设计意图注释** — 在 oocMod 调用前注释"清晰预兆优先——OoC 触发时用免费技能打 KillShot/Bite"，在 termMod 调用前注释"普通 GCD 终结技——KillShot > 5CP Bite；若 OoC 已消费则此处跳过"，在 cat.lua oocMod 函数头注释"OoC 模块：节能施法状态下优先用免费技能，KillShot 仍是最优先"。仅添加注释。

- **D-03: Items 1+2 合并为一个 commit** — 两者均为纯注释改动（combo.lua + cat.lua），无逻辑变更，合并为 `docs(catAtk): fix comment numbering and add KillShot design intent comments`。**Reversibility:** reversible

### Item 3: isPseudoInfiniteEnergy 集中化

- **D-04: 字段命名 `clickContext.isPseudoInfiniteEnergy`** — 命名为 `isPseudoInfiniteEnergy`（而非 `isInfiniteEnergy`），强调这是**近似**无穷能量（erps >= SHRED_E），而非字面意义上的"无穷"。精准表达语义。

- **D-05: 在 catAtk 入口处一次计算** — 在 `catAtk()` 中 clickContext 初始化完成后（AUTO_TICK_ERPS、TIGER_ERPS 等字段已设置）、模块执行前，调用 `clickContext.isPseudoInfiniteEnergy = macroTorch.computeErps(clickContext) >= clickContext.SHRED_E`。每次按键 clickContext 重建，自动保证值是最新的。

- **D-06: 替换范围 — 5 处显式比较** — 以下位置改为读 `clickContext.isPseudoInfiniteEnergy`：
  - `cat.lua` — `oocMod`（~162 行）
  - `cat.lua` — `cp5Bite`（~116 行）
  - `cat.lua` — `energyDischargeBeforeBite`（~139 行）
  - `cat.lua` — `dischargeEnergyChangeRelicAndRip`（~252 行，当前用 `local erps` → `skipDischarge`）
  - `Druid.lua` — `shouldUseShred`（~700 行，当前用 `local erps` → `infiniteEnergy`）

- **D-07: 保留范围 — 3 处隐式比较** — 以下位置保持原样，表达不同语义（"能量是否会溢出" vs "是否近似无限能量"）：
  - `Druid.lua` — `shouldDoReshift`：`math.ceil(currentEnergy + erps * 1.5) < nextAbilityCost` — 自然回能是否足够
  - `Druid.lua` — `shouldCastFFDuringWaitWindow`：能量等待窗口判断
  - `Druid.lua` — `recoverNormalRelic`：`energy + erps * 2.5 <= 100` — 是否有空闲 GCD

### Item 4: keepRake ATK 爆发标注

- **D-08: 方案 A — 注释块标注副作用** — 在 keepRake 函数中 ATK 爆发处添加详细注释块，说明为什么在此触发（AP snapshot 最大化流血伤害）、为什么放在 keepRake 而非 burstMod（burstMod 处理手动 Shift 键协调，这里是高价值目标自动优化）。不改动任何代码逻辑或执行顺序。**Reversibility:** reversible

### Commit 策略

- **D-09: 3 commits，按 1+2→3→4 顺序**
  1. `docs(catAtk): fix comment numbering and add KillShot design intent comments` — Items 1+2 合并
  2. `refactor(catAtk): centralize isPseudoInfiniteEnergy in clickContext` — Item 3（3 文件）
  3. `docs(catAtk): annotate ATK burst side effect in keepRake` — Item 4（1 文件）

### Claude's Discretion

- isPseudoInfiniteEnergy 在 combo.lua 中的具体计算行位置（clickContext 初始化之后、模块调用之前）
- 注释的具体措辞（遵循来源文档提供的模板，可微调）
- cp5Bite 和 energyDischargeBeforeBite 中替换的具体代码（当前可能用 `local erps = ...` 或内联比较，统一改为读 `clickContext.isPseudoInfiniteEnergy`）
- 是否需要更新 `catAtk-core-principles.md` 以反映 Item 3 的命名决策
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 阶段定义文档
- `.planning/catAtk-phaseA-maintainability.md` — 4 条目完整分析（现状、目标、改动方案、排除清单、执行建议）。**首要阅读文档。**
- `.planning/catAtk-core-principles.md` — catAtk 14 条设计原则（本阶段的审视依据）
- `.planning/catAtk-phaseB-quality.md` — 后续质量改进阶段（关联文档，非直接依赖）

### 项目级文档
- `.planning/ROADMAP.md` — Phase 21 目标与依赖
- `.planning/REQUIREMENTS.md` — REQ-21-COMMENTS, REQ-21-ISINFINITEENERGY, REQ-21-KEEPRAKE-CLEANUP

### 直接依赖 Phase
- `.planning/phases/20-spell-id-auto-correct-spellid/20-CONTEXT.md` — SPELL_ID_AUTO_CORRECT 全局开关（最新完成的 phase）

### 修改目标文件
- `classes/druid/combo.lua`（375 行） — catAtk 主入口 + 注释编号修改 + isPseudoInfiniteEnergy 计算 + oocMod/termMod 调用处注释
- `classes/druid/cat.lua`（417 行） — keepRake/oocMod/cp5Bite/energyDischargeBeforeBite/dischargeEnergyChangeRelicAndRip
- `classes/druid/Druid.lua`（1383 行） — shouldUseShred

### 构建系统
- `build_order.txt` — 确认 classes/druid/ 文件顺序（不改动）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `macroTorch.computeErps(clickContext)` — 能量恢复速率计算（Druid.lua:853-882），isPseudoInfiniteEnergy 依赖
- `clickContext` — 每次 catAtk 调用新建的缓存表（combo.lua），isPseudoInfiniteEnergy 的新字段载体
- `macroTorch.atkPowerBurst(clickContext)` — ATK 爆发物品消耗（cat.lua），keepRake 中调用的副作用函数

### Established Patterns
- **模块优先级链**: catAtk 中 13 个模块按优先级顺序执行，第一个成功动作 return（combo.lua:144-174）
- **clickContext 单次生命周期**: 每次按键调用新建、当前调用结束后丢弃（combo.lua）
- **全局函数定义**: `function macroTorch.catAtk(rough)` 在 combo.lua 中定义、Druid.lua 中调用
- **注释风格**: Lua 单行 `--` 注释 + 模块编号标记（"12.reshiftMod"）
- **共享决策函数**: `shouldUseShred`/`shouldCastRip`/`shouldUseBite` 定义在 Druid.lua，传入 clickContext 作为参数

### Integration Points
- `classes/druid/combo.lua:144-174` — catAtk 模块调用区（注释编号修改 + isPseudoInfiniteEnergy 计算点）
- `classes/druid/cat.lua:300-314` — keepRake 函数（ATK 爆发注释标注）
- `classes/druid/cat.lua:156-174` — oocMod 函数（design intent 注释 + isPseudoInfiniteEnergy 替换）
- `classes/druid/cat.lua:97-105` — termMod 函数（design intent 注释）
- `classes/druid/Druid.lua:699-700` — shouldUseShred（isPseudoInfiniteEnergy 替换）
</code_context>

<specifics>
## Specific Ideas

- 具体代码改动参考 `.planning/catAtk-phaseA-maintainability.md` 各条目的「目标」部分 —— 包含完整的 before/after 代码片段和行号
- isPseudoInfiniteEnergy 的拼写确认为 `isPseudoInfiniteEnergy`（首字母小写 camelCase，与 clickContext 其他字段风格一致）
- 来源文档中关于 `computeErps` 调用时机的担忧已确认可安全忽略：clickContext 每次按键重建，自动保证 erps 值是最新的
- Items 1+2 虽然可合并为一个 commit，但建议在 commit message body 中分别列出两个改动
</specifics>

<deferred>
## Deferred Ideas

- **burstMod 改造**: 来源文档「不改动的项目」中已记录 —— Berserk 守卫跳过后续爆发物品是故意设计
- **主动 FF 维护**: 收益太小，暂缓
- **recoverNormalRelic 无限能量永不触发**: 已知限制，后需独立处理
- **catAtk-phaseB-quality.md**: Phase B 质量改进（关联但独立于本阶段）

None — 讨论保持在 Phase 21 范围内。
</deferred>

---

*Phase: 21-catAtk-maintainability*
*Context gathered: 2026-07-29*