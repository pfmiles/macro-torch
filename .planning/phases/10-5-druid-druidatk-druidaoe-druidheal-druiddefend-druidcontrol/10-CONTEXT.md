# Phase 10: 创建5个Druid综合一键宏方法 - Context

**Gathered:** 2026-06-16
**Status:** Ready for planning

<domain>
## Phase Boundary

创建 5 个 Druid 顶层"一键宏"方法（`druidAtk`/`druidAoe`/`druidHeal`/`druidDefend`/`druidControl`），每个方法内部按当前形态（猫/熊/人）使用 if-elseif 链路由到对应子方法。用户绑定一个宏按键即可，无需手动切换形态。

同时将 catAtk 中已有的 bear 路由逻辑（Druid.lua:380-384）提取到 druidAtk 中，完成 catAtk 剥离 bear 逻辑的 TODO。

**涉及文件：**
- 新建 `classes/druid/combo.lua` — 5 个 combo 方法
- 修改 `classes/druid/Druid.lua` — catAtk 中移除 bear 路由（lines 380-384）
- 修改 `classes/druid/utility.lua` — 删除旧的 druidDefend/druidControl（无调用者），druidStun 逻辑并入 druidControl
- 修改 `build_order.txt` — 添加 combo.lua

**不涉及：** druidBuffs 保留在 utility.lua，不在本次范围。
</domain>

<decisions>
## Implementation Decisions

### 形态路由策略
- **D-01:** 所有 5 个 combo 方法使用简单 if-elseif 链按形态路由，不使用 dispatch table。WoW 宏执行是同步阻塞的，if-elseif 在 3 个战斗形态上最快（比 table lookup 快 3-4 倍），且与现有 catAtk 中的 bear 路由先例一致。
- **D-02:** 自动形态切换决策按方法语义区别对待：
  - `druidAtk`: **绝不**自动切形态。切形态清空能量/怒气并触发 1.5s GCD，战斗中自动切形态是灾难性的。
  - `druidHeal`: **必须**自动切回人形。野兽形态下无法施放治疗技能，需要 CancelShapeshiftForm 或施放形态技能 toggle off。
  - `druidAoe`: **不自动切形态**。熊和人各有 AOE 技能，在哪个形态就用哪个。
  - `druidDefend`: **部分切换**。Barkskin 全形态通用，Frenzied Regeneration 需切熊。
  - `druidControl`: **自动切人形**。控制技能（Hibernate/Entangling Roots/Bash/Feral Charge）在人形或熊形下使用。

### druidAtk 路由
- **D-03:** if-elseif 链：Cat Form → `catAtk(rough)`，Bear Form/Dire Bear Form → `bearAtk(rough)`，Caster Form → return（未来可扩展 casterAtk）。
- **D-04:** 方法签名：`macroTorch.druidAtk(rough)`，rough 参数透传给 catAtk/bearAtk。
- **D-05:** catAtk 中移除现有的 bear 路由代码（Druid.lua:380-384 的 `if clickContext.isInBearForm then bearAtk(rough); return end`），完成该 TODO 注释的剥离。

### druidAoe 范围
- **D-06:** 熊+人双形态路由：Bear Form → `bearAoe()`，Caster Form → `hurricane('ready')`。Cat Form → return（WoW 1.12.1 猫形态无 AOE 技能）。
- **D-07:** Hurricane 是引导技能，与 bearAoe 的模块化 clickContext 体系不同，不需要复杂的资源管理，只需检查形态+法力+技能就绪后施放。
- **D-08:** 方法签名：`macroTorch.druidAoe()`，无参数（bearAoe 无需参数，Hurricane 使用 mode='ready'）。

### druidHeal 策略
- **D-09:** 单步切人形 + HOT 优先逻辑。每次按键只执行一个动作（符合一键宏哲学）：
  1. 如果在猫/熊形态 → 取消形态（CancelShapeshiftForm 或 toggle 形态技能），返回 true；下次按键进入治疗逻辑
  2. 如果回春术就绪且玩家血量 < 50% 且没有回春 HOT → 施放 `rejuvenation('safe', true)`
  3. 如果玩家血量 < 40% → 施放 `healing_touch('safe', true)`
  4. 否则 do nothing
- **D-10:** V1 仅做自疗（onSelf=true）。团队治疗（治疗坦克、智能选择目标）属于未来 Phase。
- **D-11:** 需要新增"是否在人形态"的判断逻辑。当前 `isInCasterForm` 仅检测枭兽形态。druidHeal 实际需要的是 `not isInCatForm and not isInBearForm`（人形态 = 无形态）。
- **D-12:** 方法签名：`macroTorch.druidHeal()`，无参数。

### druidDefend 策略
- **D-13:** 直接内联重构，不依赖 utility.lua 中的旧版 druidDefend。旧版从 utility.lua 删除（无调用者）。
- **D-14:** 模块优先级：
  1. Barkskin（全形态通用，检查技能就绪）
  2. Frenzied Regeneration（需切熊形态，切熊→狂暴回复）
- **D-15:** 方法签名：`macroTorch.druidDefend()`，无参数。

### druidControl 策略
- **D-16:** 合并 druidStun 逻辑。druidControl 成为统一的控制方法，包含：
  1. 熊形态近身→Bash（晕），熊形态远处→Feral Charge（冲锋）
  2. 人形态→Hibernate（野兽/龙类）或 Entangling Roots（其他）
  3. 非熊非人形态→自动切熊或切人形
- **D-17:** 旧版 druidDefend/druidControl 从 utility.lua 删除。旧版 druidStun 逻辑内联到 druidControl 中并删除。
- **D-18:** 方法签名：`macroTorch.druidControl()`，无参数。

### 文件组织
- **D-19:** 新建 `classes/druid/combo.lua` 包含全部 5 个全局函数定义（`macroTorch.druidAtk` 等）。
- **D-20:** `build_order.txt` 中 combo.lua 放在 utility.lua 之后（combo.lua 可能引用 utility.lua 中的 druidBuffs），bear.lua 和 cat.lua 之前即可。
- **D-21:** druidBuffs 保留在 utility.lua 不动（不在 Phase 10 范围）。

### Claude's Discretion
- druidHeal 中"是否在人形态"判断的具体实现方式（新增 isInHumanoidForm 字段 vs 内联 not isInCatForm and not isInBearForm）
- druidControl 中 Bash vs Feral Charge 的距离判定逻辑细节（复用现有 druidStun 逻辑）
- druidAoe 中 Hurricane 的 mana 检查阈值
- combo.lua 文件内部的代码组织顺序和注释风格
- druidDefend 中 Barkskin 和 Frenzied Regeneration 的具体条件判断
- druidHeal 是否有必要检测"已经有人形态 HOT"避免重复施法
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 10 目标："创建5个Druid综合一键宏方法: druidAtk/druidAoe/druidHeal/druidDefend/druidControl, 内部按形态路由到对应方法"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策
- `.planning/phases/07-druid/07-CONTEXT.md` — D-01/D-02: 形态判断语义化方法（isInCatForm/isInBearForm/isInTravelForm/isInAquaticForm/isInCasterForm）
- `.planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md` — D-01: 纯点号语法约定
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` — D-05/D-06/D-07: _castSpell 架构、技能方法签名分类（Type A/B/C）、mode 参数
- `.planning/phases/08-druid-druid/08-CONTEXT.md` — D-01: 文件拆分粒度约定

### 关键源文件
- `classes/druid/Druid.lua:380-384` — catAtk 中现有的 bear 路由（需移除）
- `classes/druid/Druid.lua:19-430` — Druid:new() 构造器，catAtk 入口 + 全部技能方法
- `classes/druid/cat.lua` — 猫形态 13 个模块（macroTorch.oocMod/termMod/keepRip 等）
- `classes/druid/bear.lua` — 熊形态 bearAtk/bearAoe + 7 个模块
- `classes/druid/utility.lua` — druidBuffs/druidStun/druidDefend/druidControl（druidStun 逻辑并入 druidControl，druidDefend/druidControl 删除）
- `entity/Player.lua` — _castSpell/_isInRange/_hasResource 基类方法，所有技能方法依赖

### 构建系统
- `build_order.txt` — 需添加 `classes/druid/combo.lua`，放在 utility.lua 之后
- `build.sh` — 严格模式（Phase 4 收尾）

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — metatable __index 链、FIELD_FUNC_MAP 懒计算属性机制、catAtk 模块优先级执行模型
- `.planning/codebase/CONVENTIONS.md` — 点号语法、全局函数命名、camelCase 约定
</canonical_refs>

<code_context>
## Existing Code Insights

### catAtk 中现有的 bear 路由（需提取）
```lua
-- Druid.lua:380-384 (catAtk 内部)
-- roughly bear form logic branch, TODO 其实bear形态逻辑应该完全从catAtck逻辑中剥离出来，在最上层的宏里面通过当前形态来路由
if clickContext.isInBearForm then
    macroTorch.bearAtk(clickContext.rough)
    return
end
```

### 现有形态语义化方法（Phase 7 产出）
```lua
-- DRUID_FIELD_FUNC_MAP (Druid.lua:449-463)
isInCatForm → self.isFormActive('Cat Form')
isInBearForm → self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
isInCasterForm → self.isFormActive('Moonkin Form')  -- 仅枭兽，人形态无检测
isInTravelForm → self.isFormActive('Travel Form')
isInAquaticForm → self.isFormActive('Aquatic Form')
```

### druidHeal 需要的人形态判断
当前 `isInCasterForm` 只检测枭兽形态。druidHeal 实际需要 `not isInCatForm and not isInBearForm`（人形态 = 无变形形态）。可考虑在 DRUID_FIELD_FUNC_MAP 中新增 `isInHumanoidForm` 或在内联判断。

### 现有 utility.lua 中的方法状态
- `druidBuffs()` — 保留不动
- `druidStun()` — 逻辑并入 druidControl，删除
- `druidDefend()` — 内联重构到 combo.lua，删除
- `druidControl()` — 内联重构+合并 druidStun，删除

以上 4 个方法均无调用者（从旧 SM_Extend_Druid.lua 迁移后从未被集成），删除不会引起任何断裂。

### Reusable Assets
- **`player.isInCatForm` / `player.isInBearForm`** — Phase 7 语义化形态判断，if-elseif 链直接使用
- **`player._castSpell(localeNames, mode, range, resourceCost, onSelf)`** — 技能方法底层基础设施，所有 druidHeal 中的治疗技能调用都通过它
- **`macroTorch.bearAoe()`** — 已存在于 bear.lua，druidAoe 直接调用
- **`macroTorch.bearAtk(rough)`** / **`obj.catAtk(rough)`** — druidAtk 路由目标
- **`player.rejuvenation(mode, onSelf)`** / **`player.healing_touch(mode, onSelf)`** — druidHeal 使用的治疗技能方法（Type C）
- **`player.hurricane(mode)`** — druidAoe 人形态使用的引导技能（Type B）
- **`player.barkskin(mode)`** / **`player.frenzied_regeneration(mode)`** — druidDefend 使用的防御技能
- **`player.bash(mode)`** / **`player.feral_charge(mode)`** / **`player.hibernate(mode)`** / **`player.entangling_roots(mode)`** — druidControl 使用的控制技能

### Established Patterns
- **全局函数定义**: `function macroTorch.druidAtk(rough) ... end`，与 bear.lua/bearAoe 风格一致
- **clickContext 单次缓存**: catAtk/bearAtk 创建 local clickContext = {}，每个 combo 方法复用此模式
- **一键宏"一次一个动作"**: 第一个成功的动作返回 true/执行后 return，不连续执行多个动作
- **模块优先级执行**: 从 catAtk 继承，druidHeal 按优先级检查条件

### Integration Points
- `classes/druid/Druid.lua:380-384` — 删除 catAtk 中的 bear 路由代码
- `classes/druid/utility.lua` — 删除 druidStun/druidDefend/druidControl，保留 druidBuffs
- `build_order.txt` — 添加 `classes/druid/combo.lua`，放在 utility.lua 之后
- `core/events.lua` — 无需变更（initPlayer 自动处理，combo 方法是全局函数）
</code_context>

<specifics>
## Specific Ideas

- druidAtk 的 if-elseif 链本质上是将 catAtk 中已有的 bear 路由模式提升到顶层，语义等价
- druidAoe 的 Hurricane 分支是简化处理——引导技能不需要 clickContext，直接 `hurricane('ready')`
- druidHeal 的单步切人形：使用 CancelShapeshiftForm()（WoW API 原生）或通过 `cat_form('ready')`/`bear_form('ready')` toggle 回到人形。需注意 reshift 是乌龟服特有技能（切回人形再切回当前形态），对 druidHeal 不合适
- druidDefend 中 Barkskin 是全形态通用技能（可在猫/熊/人形态下使用），无需前置形态切换
- druidControl 合并 druidStun 后的形态路由：熊形态→Bash（近身）或 Feral Charge（远处），人形态→Hibernate 或 Entangling Roots
- combo.lua 中 5 个方法都是全局函数，不是 Druid 实例方法。与 bear.lua/bearAtk 风格一致，与 catAtk（实例方法）不同但合理——combo 方法是顶层调度入口，不依附于特定形态实例
- build_order.txt 中 combo.lua 的具体位置：在 utility.lua 之后、cat.lua/bear.lua 之前即可（因为 combo 只依赖 utility.lua 中的 druidBuffs，不依赖 cat/bear 中的模块函数）
</specifics>

<deferred>
## Deferred Ideas

- **druidHeal 团队治疗**: V1 仅自疗。扩展到治疗队友（治疗坦克、智能选择血最少队友）属于未来 Phase。
- **druidHeal NS 瞬发优化**: 讨论中提到自然迅捷 (Nature's Swiftness) + 瞬发治疗之触的组合，暂不纳入 V1。可作为 druidHeal 增强 Phase 添加。
- **casterAtk 鹌鹑输出**: druidAtk 中 Caster Form 分支当前 return（预留），未来可实现鹌鹑远程输出逻辑。
- **猫形态 AOE**: WoW 1.12.1 中猫无 AOE 技能，如果后续版本/Turtle WoW 添加了猫形态 AOE 技能，可扩展 druidAoe 的猫分支。
- **druidBuff 统一**: 讨论中用户提到 druidBuffs 作为独立方便方法保留。如果未来需要补 buff 的组合宏（如 druidBuff + druidHeal 合并），可再讨论。
- **druidDefend 的 Frenzied Regeneration rage 资源管理**: 当前 druidDefend 只做技能可用性检查，不管理怒气资源。未来可加入 Enrage 前置获取怒气的逻辑（与现有 druidDefend 内部逻辑类似）。

None — 讨论保持在 Phase 10 范围内。
</deferred>

---

*Phase: 10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol*
*Context gathered: 2026-06-16*