# Phase 25: Hunter 一键宏改造 - Context

**Gathered:** 2026-08-18
**Status:** Ready for planning
**Nyquist Validation:** SKIPPED by explicit user decision — VALIDATION.md will not be created for this phase.

<domain>
## Phase Boundary

参考 Druid 的一键宏架构（`druidAtk/druidAoe/druidDefend/druidControl/druidMobTagging`），为 Hunter 职业构建同等的 5 个一键宏：`hunterAtk`（练级输出）、`hunterAoe`（范围攻击）、`hunterDefend`（保命）、`hunterControl`（控制）、`hunterMobTagging`（抢怪）。

**当前代码状态：** 现有的 `classes/hunter/` 下 3 个文件（Hunter.lua、combat.lua、utility.lua）是过时的测试代码，仅供参考，需要推倒重来。重构时不必担心破坏原有结构或逻辑。

**目标文件结构（Druid 对齐）：**
- `classes/hunter/Hunter.lua` — 类定义 + 技能方法 + SelfTest + SpellTrace 注册
- `classes/hunter/combo.lua` — 5 个一键宏函数

**不在范围内：**
- Aspect（守护）自动切换 — 用户手动管理
- 宠物自动管理 — 用户手动控制宠物
- Feign Death 保命逻辑 — 用户认为 Feign Death 不属于减伤技能
</domain>

<decisions>
## Implementation Decisions

### hunterAtk 架构设计

- **D-01: 单入口路由** — `hunterAtk()` 作为统一入口，按目标距离自动路由：`< 8yd` → 近战分支，`≥ 8yd` → 远程分支。类似 Druid 的 `druidAtk → catAtk/bearAtk/casterAtk` 形态路由模式。

- **D-02: 12 模块优先级链** — 参照 Druid `catAtk` 的 module-priority chain 模式，使用 `clickContext` 单次缓存表。模块按优先级顺序执行，第一个成功动作 return。模块清单（具体顺序和内容由 planner/researcher 根据 Hunter 机制确定）：
  1. 生存急救（urgent HP restore / potion）
  2. 目标选择（targetEnemy）
  3. 自动攻击（startAutoAtk / startAutoShoot）
  4. 爆发模块（burstMod — Shift 键触发 trinkets）
  5. 起手技模块（opener — 瞄准射击 Shift 触发等）
  6. 钉刺/标记模块（Hunter's Mark → Serpent Sting → Scorpid Sting）
  7. 主要输出模块（Arcane Shot → Multi-Shot → 近战技能）
  8. 仇恨管理模块（otMod — Disengage 降仇恨）
  9. 其他填充模块

- **D-03: 近战/远程切换阈值 8yd** — 使用 `target.distance < 8`（WoW 近战攻击最大距离）。不考虑 5-8yd 死区问题 — 死区内近战更可靠。

- **D-04: Auto Shot 每键触发** — 每次按键都调用 `startAutoShoot()`，确保自动射击保持活跃。类似 Druid 的 `startAutoAtk()` 每键调用模式。

- **D-05: Aimed Shot Shift 手动触发** — 通过 Shift 修饰键在 burstMod 模块中触发 Aimed Shot，类似 Druid 的 burstMod（Shift 触发 Berserk/物品）。不自动使用——Aimed Shot 的 3 秒施法会打断 Auto Shot 循环，不适合自动决策。

- **D-06: 不涉及陷阱** — 陷阱完全交给 `hunterAoe`（伤害陷阱：Explosive/Immolation）和 `hunterControl`（控制陷阱：Freezing），`hunterAtk` 模块链中不包含陷阱逻辑。

- **D-07: 不涉及守护** — Aspect 切换完全由用户手动管理，`hunterAtk` 不调用任何守护切换。

- **D-08: 不涉及宠物** — 宠物管理（攻击/治疗/复活）由用户手动控制，`hunterAtk` 不调用宠物相关逻辑。

### 技能覆盖

- **D-09: ~15 个新技能方法** — 在现有 10 个方法基础上补充：
  - **核心战斗：** `aimed_shot`、`scorpid_sting`、`viper_sting`、`auto_shot` (startAutoShoot/stopAutoShoot)
  - **陷阱：** `immolation_trap`、`explosive_trap`、`freezing_trap`
  - **生存：** `deterrence`、`feign_death`
  - **宠物：** `mend_pet`、`revive_pet`
  - 所有方法使用 `_castSpell({en = '...', zh = '...'}, mode, nil, nil, onSelf, rank)` 模式

- **D-10: Druid 对齐文件结构** — `Hunter.lua`（类定义 + 所有技能方法 + HUNTER_FIELD_FUNC_MAP + SelfTest + SpellTrace 注册）+ `combo.lua`（5 个一键宏函数）。现有 `combat.lua` 和 `utility.lua` 废弃。

### SpellTrace

- **D-11: 钉刺 land tracing** — 为 `Serpent Sting` 和 `Scorpid Sting` 注册 SpellTrace（通过 `SpellTrace:register()`）。**目的：** 通过 land trace 区分自己释放在目标身上的钉刺 vs 其他猎人的钉刺（debuff 检测无法区分来源）。Immune 检测已有自动机制（失败事件自动记录），无需额外配置。

- **D-12: Hunter's Mark 不 trace** — 用户明确不需要。

### hunterAoe

- **D-13: 距离路由** — 远程（≥8yd）：Multi-Shot → Volley；近战（<8yd）：Explosive Trap → Immolation Trap。参照 Druid 的 `druidAoe` 形态路由模式。简洁实现，~20 行。

### hunterDefend

- **D-14: 仅 Deterrence** — `hunterDefend()` 只检查并释放 Deterrence（威慑）。不包含 Feign Death（用户认为不属于减伤技能）、不包含 Disengage、不包含守护切换。极简实现，~5 行。**Reversibility:** reversible — 未来扩展只需在函数内添加优先级判断。

### hunterControl

- **D-15: 距离路由** — 近战（<8yd）：Wing Clip（减速）或 Freezing Trap（冰冻控制）；远程（≥8yd）：Concussive Shot（减速）或 Scatter Shot（迷惑）。参照 Druid 的 `druidControl` 距离分支模式。~30 行。

### hunterMobTagging

- **D-16: 远程抢怪 Arcane Shot rank 1** — 远程距离（≥8yd）使用最低级奥术射击（瞬发、最低法力消耗、30码射程）。确认 tag 成功后（目标正在攻击我）自动衔接 `hunterAtk()` 正常输出。

- **D-17: 近战抢怪 摔绊 (Wing Clip)** — 近战距离（<8yd）使用 Wing Clip（摔绊，瞬发近战直伤 + 减速）。比普攻更可靠的即时 tag。

- **D-18: PvP 过滤** — 选到玩家目标时自动 `ClearTarget()`，防止 Tab 到敌对玩家时误抢 PvP tag。参照 `druidMobTagging` 的二次确认模式。

- **D-19: 自动衔接输出** — 确认 tag 成功后（`target.isAttackingMe`）自动调用 `hunterAtk()` 进入正常输出流程。

### SelfTest

- **D-20: 参照 Druid 级别** — `Hunter.lua` 末尾追加 SelfTest 注册：
  - 基础设施测试（FIELD_FUNC_MAP、singleton、PLAYER_CLASS_REGISTRY）
  - 全部技能方法存在性测试（~25 个）
  - 一键宏函数存在性测试（5 个：hunterAtk/hunterAoe/hunterDefend/hunterControl/hunterMobTagging）
  - 全部使用 `isOptional = true` + `UnitClass('player') ~= 'Hunter'` guard

### Claude's Discretion

- 12 个模块的具体命名、优先级顺序和实现细节
- `clickContext` 缓存字段的具体设计（哪些值需要缓存）
- 技能方法的 `mode` 参数行为（'ready' vs 'safe' vs 'raw'）
- Aimed Shot Shift 触发在 burstMod 中的具体检查条件
- hunterAoe/hunterControl 中具体的优先级链和回退逻辑
- hunterMobTagging 中目标有效性检查的细粒度守卫条件
- SelfTest 测试用例的具体 assert 措辞
- combo.lua 中的注释风格和模块分隔（遵循 Druid combo.lua 模式）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 定义
- `.planning/ROADMAP.md` — Phase 25 目标、依赖关系（depends on Phase 24）
- `.planning/REQUIREMENTS.md` — R1-R8 可验证需求（R3 事件系统模块化约束、R6 目录结构约束）

### 参考实现：Druid 一键宏架构（Hunter 需对齐的模型）
- `classes/druid/combo.lua`（456 行） — **首要参考。** 包含所有 8 个 Druid 一键宏的完整实现：`druidAtk`/`catAtk`/`casterAtk`/`druidAoe`/`druidHeal`/`druidDefend`/`druidControl`/`druidMobTagging`/`druidCharge`。Hunter 的 5 个宏应遵循相同的模式。
- `classes/druid/Druid.lua`（1452 行） — 类定义 + 全部技能方法 + FIELD_FUNC_MAP + SelfTest。Hunter.lua 的对齐目标。
- `classes/druid/cat.lua`（447 行） — 模块化子函数（keepRip/keepRake/keepFF/regularAttack/oocMod 等）。如 Hunter 需要模块拆分可参照。
- `classes/druid/leveling.lua`（229 行） — 练级版宏 `catLeveling`。如未来需要可参照。

### 基础设施参考
- `core/class.lua` — `classMetatable` 工厂（R1）
- `core/selftest.lua` — `SelfTest:register(name, fn, isOptional)` API
- `core/spell_trace.lua` — `SpellTrace:register(name, config)` 声明式 trace API
- `entity/Player.lua` — `_castSpell` / `_isSpellReady` / `_isInRange` / `_hasResource` 等基础方法
- `entity/Unit.lua` — 基础属性字段（distance、health、isCanAttack 等）

### 直接依赖 Phase
- `.planning/phases/23-idol-dance-refactor/23-CONTEXT.md` — Category SelfTest 命名传统参考
- `.planning/phases/22-catatk-selftest-catatk-core-principles-md-d/22-CONTEXT.md` — selftest.lua 结构参考

### 构建系统
- `build_order.txt` — 需更新：添加 `classes/hunter/combo.lua` 在 `classes/hunter/Hunter.lua` 之后
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `macroTorch.classMetatable(cls, fieldMapName)` — 统一 metatable 工厂（`core/class.lua`）
- `macroTorch.Hunter` 类 + `HUNTER_FIELD_FUNC_MAP` — 已在 `classes/hunter/Hunter.lua` 中定义，但内容需重写
- `obj._castSpell(nameTable, mode, ...)` — 技能释放基础方法（`entity/Player.lua`），支持中英文 locale
- `macroTorch.SpellTrace:register(name, config)` — 声明式 spell trace 注册（`core/spell_trace.lua`）
- `macroTorch.SelfTest:register(name, fn, isOptional)` — SelfTest 注册 API（`core/selftest.lua`）
- `macroTorch.registerPlayerClass(name, class)` — 多态 Player 工厂注册（`core/class.lua`）
- `macroTorch.isFightStarted(clickContext)` — 战斗开始判断（`classes/druid/Druid.lua`）
- `macroTorch.isSpellExist(name, bookType)` — 技能存在性检查（`biz_util.lua`）
- `player.targetEnemy()` — 自动选敌（`entity/Player.lua`）
- `player.startAutoAtk()` / `player.startAutoShoot()` — 自动攻击/射击（`entity/Player.lua`）
- Pet 基础方法：`pet.attack()`、`pet.isExist` — `entity/Pet.lua`

### Established Patterns（Druid 对齐 — Hunter 需遵循）
- **类定义 + 技能方法模式：** 构造函数内 `function obj.skill_name(mode, rank)` + locale 双表 `{en = '...', zh = '...'}`
- **FIELD_FUNC_MAP：** 空表起手，按需添加 class-specific lazy-computed 属性
- **SpellTrace 注册：** 在文件末尾，`macroTorch.SpellTrace:register()` 声明式调用
- **SelfTest 注册：** `UnitClass('player') ~= 'Hunter'` guard + `isOptional = true`
- **clickContext 缓存：** 单次按键新建表，存储所有计算值避免重复 WoW API 调用
- **模块优先级链：** 按优先级顺序执行，第一个成功动作 return
- **距离路由：** `target.distance < 8` → 近战，else → 远程

### Integration Points
- `classes/hunter/Hunter.lua` — 修改范围：完全重写（类定义保留框架，技能方法重写、新增 ~15 方法、重写 SelfTest、更新 SpellTrace）
- `classes/hunter/combo.lua` — 新建文件，包含 5 个一键宏函数
- `classes/hunter/combat.lua`、`classes/hunter/utility.lua` — 废弃/删除
- `build_order.txt` — 需添加 `classes/hunter/combo.lua`（在 `classes/hunter/Hunter.lua` 之后）
- `macroTorch.hunter` singleton — 已在 Hunter.lua 底部实例化，保持
- `PLAYER_CLASS_REGISTRY` — 已注册 "Hunter" → `macroTorch.Hunter`，保持

### New/Modified Code
- `classes/hunter/Hunter.lua` — 完全重写（~350 行）：类定义 + 25 个技能方法 + HUNTER_FIELD_FUNC_MAP + SpellTrace（Serpent Sting + Scorpid Sting）+ SelfTest（~30 tests）
- `classes/hunter/combo.lua` — 新建（~350 行）：5 个一键宏函数 + SelfTest 验证
- `build_order.txt` — 添加 `classes/hunter/combo.lua` 行
</code_context>

<specifics>
## Specific Ideas

- **"推倒重来"** — 用户明确当前 Hunter 代码是过时的测试代码，不受现有结构约束。可以完全按照 Druid 模式重新设计。
- **SpellTrace 目标：** 钉刺 land tracing 是为了区分"自己的毒蛇钉刺"vs"其他猎人的毒蛇钉刺"——debuff 检测只能看到 buff 存在，无法判断来源。land trace 记录了"我成功释放了 Serpent Sting 在目标 X 上"，从而可以确认是自己的 debuff。
- **hunterDefend 极简：** 只有 Deterrence 一个技能，不需要复杂的优先级链。未来可能扩展。
- **hunterMobTagging 近战用 Wing Clip：** 用户选择摔绊而非普攻或 Raptor Strike 作为近战抢怪技能——瞬发直伤 + 减速副作用。
- **Aimed Shot Shift 触发：** 放在 burstMod 中，与 trinkets/物品同组，通过 IsShiftKeyDown() 检测。
</specifics>

<deferred>
## Deferred Ideas

- **Aspect 守护自动切换** — 战斗中自动切雄鹰守护、非战斗猎豹守护、近战灵猴守护。用户明确当前不涉及，未来可作为独立 phase。
- **宠物深度管理** — 自动 Mend Pet/Revive Pet/Call Pet。用户明确当前不涉及。
- **Feign Death 集成** — 用户认为不属于减伤技能，可能属于仇恨管理或独立宏。
- **Intimidation（BM 天赋昏迷）** — hunterControl 中未包含，未来可扩展。
- **Viper Sting 自动使用** — 技能方法已定义但一键宏中暂不自动使用，留给用户手动或未来 phase。
- **练级版 hunterAtk（参照 catLeveling）** — 技能存在性检查和低等级降级策略，后续 phase 可扩展。

None — 讨论保持在 Phase 25 范围内。
</deferred>

---

*Phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol*
*Context gathered: 2026-08-18*