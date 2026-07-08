# Phase 19: druidControl 改造 — 拆分 bash 到 druidCharge - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

重构 `druidControl()` 控制宏，将 bear 形态的 Bash（猛击）打断逻辑拆分为独立的 `druidCharge()` 方法，同时加入 Feral Charge（野性冲锋）形成距离驱动的冲锋+打断双分支。为两个方法补充形态验证和技能存在性检查，使其在练级阶段也能正常工作。

**涉及文件（预估）：**
- `classes/druid/combo.lua` — druidControl 重构（删除 Bash 分支）+ 新增 druidCharge
- `classes/druid/Druid.lua` — bash()、feral_charge()、bear_form() 技能方法已存在（只读确认）
- `core/selftest.lua` — 新增 Category M 自检

**不涉及：** catAtk、catLeveling、druidAtk 路由、其他职业、Hibernate/Entangling Roots 技能方法（已存在，不改动）
</domain>

<decisions>
## Implementation Decisions

### druidCharge — 距离驱动的冲锋+打断双分支

- **D-01: 职责范围** — druidCharge 同时包含 Feral Charge 和 Bash，按目标距离分两个 if-else 分支。两者之间不是 combo 关系（不需要 Charge 完再 Bash），而是纯粹的距离判定：远距离用 Charge 接近，近距离用 Bash 打断。**共同逻辑：** 形态检查+自动切熊、isSpellExist guard。
- **D-02: 距离分支（两段）** — `≥8 码 → Feral Charge`，`<8 码 → Bash`。超过 Feral Charge 最大范围（25码）属于正常释放失败（技能方法自带 range check），不需要在 druidCharge 中特殊处理。
- **D-03: 形态自动切换** — druidCharge 检测不在熊/巨熊形态时，自动 `bear_form('ready')`（或 `dire_bear_form('ready')`），本次按键 return（等待切形态），下次按键再执行 Charge/Bash。与 druidDefend/druidHeal 的形态切换模式一致。
- **D-04: 练级适配** — 所有技能调用前加 `isSpellExist` guard：Bash 需要 10 级（熊形态），Feral Charge 需要野性天赋 20 点。技能不存在时静默 return，不报错。与 Phase 13/16 模式一致。
- **D-05: 独立方法** — `macroTorch.druidCharge()` 是独立全局一键宏方法，与 `macroTorch.druidControl()` 平级。用户绑定不同按键分别触发。

### druidControl — 删除 Bash 分支，保留控制技能

- **D-06: 删除 Bash 分支** — 从 druidControl 中删除原有的 `<8 码 → Bash` 完整 if 分支。Bash 相关逻辑全部迁移到 druidCharge。
- **D-07: 仅保留控制技能** — 剩余逻辑：`isBeastOrDragonkin() → Hibernate`，`else → Entangling Roots`。两者都在人形态释放，不需要形态检查/切换。
- **D-08: 不自动切形态** — druidControl 保持当前行为：不检查形态、不自动切换形态。如果玩家在熊/猫形态按控制键，Hibernate/Entangling Roots 会因为形态不符自然失败（WoW 原生行为），由玩家自行取消形态后再按。

### Claude's Discretion

- druidCharge 内部代码结构：形态检查→isSpellExist guard→距离判断→技能释放的具体编排顺序
- Feral Charge 最小距离（8码边界情况）的精确处理（`>= 8` vs `> 8`）
- Bash CD 检查是否加入（当前 druidControl 用 `'ready'` 模式，内部已含 CD 检查）
- 切熊形态时优先 Dire Bear Form（若可用）还是普通 Bear Form
- druidControl 删 Bash 分支后的完整代码结构（是否需要增加 isSpellExist guard 给 Hibernate/Entangling Roots）
- SelfTest 注册：具体用例数量、覆盖 druidCharge 存在性+druidControl Bash 分支已删除的验证
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 19 目标
- `.planning/REQUIREMENTS.md` — R8 (Druid 逻辑保持) 约束

### 直接依赖 Phase（最近 3 个）
- `.planning/phases/18-spellid-spellid-land-tracing-spellidmonitored-current-castin/18-CONTEXT.md` — _spellIdMonitored 白名单、_castSpell 桥接（Bash/Feral Charge 不涉及 land tracing，仅参考架构）
- `.planning/phases/17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr/17-CONTEXT.md` — isSpellExist guard 先例、技能方法 `_castSpell` 调用模式
- `.planning/phases/16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra/16-CONTEXT.md` — catLeveling 独立实现模式、isSpellExist guard 模式

### 关键源文件
- `classes/druid/combo.lua:254-271` — 当前 druidControl（Bash + Hibernate + Entangling Roots），主要修改目标
- `classes/druid/Druid.lua:66-68` — `obj.bash(mode, rank)` 技能方法（熊形态，10 怒）
- `classes/druid/Druid.lua:82-84` — `obj.feral_charge(mode, rank)` 技能方法（熊形态，25 码距离，需天赋）
- `classes/druid/Druid.lua:123-130` — `obj.bear_form()` / `obj.dire_bear_form()` 形态切换方法
- `entity/Target.lua:77-83` — `obj.isBeastOrDragonkin()` 目标类型判断
- `biz_util.lua:75-77` — `isSpellExist(spellName, bookType)` 技能存在性检查
- `entity/Player.lua` — `_castSpell` 底层施法瓶颈（只读确认，不改动）

### 相关 Phase（架构参考）
- `.planning/phases/10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol/10-CONTEXT.md` — druidControl 原始设计、druidDefend 形态切换先例

### 构建系统
- `build_order.txt` — combo.lua 位置确认（不改动，仅修改现有文件）
</canonical_refs>

<code_context>
## Existing Code Insights

### druidControl 当前代码 (combo.lua:254-271)
```lua
function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    if target.distance < 8 then
        macroTorch.player.bash('ready')           -- ← 要删除的分支
    elseif target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end
```

### Bash 技能方法 (Druid.lua:66-68)
```lua
function obj.bash(mode, rank)
    return obj._castSpell({ en = 'Bash', zh = '猛击' }, mode, nil, 10, false, rank)
end
```
- 熊形态限定（WoW 原生限制，_castSpell 不做形态检查）
- 10 怒气消耗
- `'ready'` 模式 = 仅检查可用性（CD + 怒气），不实际施放

### Feral Charge 技能方法 (Druid.lua:82-84)
```lua
function obj.feral_charge(mode, rank)
    return obj._castSpell({ en = 'Feral Charge', zh = '野性冲锋' }, mode, 25, nil, false, rank)
end
```
- 熊形态限定，需要野性天赋 20 点
- 25 码射程，8 码最小距离（WoW 原生限制）
- `_castSpell` range=25 参数会在 mode='safe' 时检查距离

### 形态切换参考模式 (druidDefend, combo.lua:238-252)
```lua
function macroTorch.druidDefend()
    -- ... 
    if not macroTorch.player.isInBearForm then
        macroTorch.player.dire_bear_form('ready')
        return   -- ← 本次按键 return，下次按键再执行后续逻辑
    end
    -- ...
end
```
druidCharge 应采用相同模式：不在熊形态→切熊→return。

### Reusable Assets
- `macroTorch.player.bash('ready')` — Bash 技能方法，已含 CD/怒气检查
- `macroTorch.player.feral_charge('safe')` — Feral Charge 技能方法，已含距离检查（25码）+ GCD 检查
- `macroTorch.player.bear_form('ready')` / `macroTorch.player.dire_bear_form('ready')` — 切熊方法
- `macroTorch.player.isInBearForm` — 熊/巨熊形态检测（Phase 7 语义化方法）
- `macroTorch.isSpellExist(spellName, bookType)` — 技能存在性检查
- `macroTorch.target.isBeastOrDragonkin()` — 目标类型判断
- `macroTorch.SelfTest:register(name, fn, isOptional)` — 自检框架

### Established Patterns
- **一键宏"一次一个动作"**: 第一个成功动作 return，不连续执行
- **形态切换": 切形态→本次 return→下次按键执行业务逻辑（druidDefend/druidHeal 先例）
- **isSpellExist guard**: Phase 13/16 模式——技能不存在时静默跳过
- **'ready' vs 'safe' 模式**: 'ready'=仅检查可用性，'safe'=检查能量+距离+CD
- **全局方法定义**: `function macroTorch.druidCharge() ... end`

### Integration Points
- `classes/druid/combo.lua` — druidCharge 新增点（与 druidControl 同文件，紧跟其后）
- `classes/druid/combo.lua:254-271` — druidControl 修改点（删除 Bash 分支）
- `core/selftest.lua` — Category M 自检注册点
- 不涉及 druidAtk 路由、catAtk、catLeveling 或其他 combo 方法
</code_context>

<specifics>
## Specific Ideas

- druidCharge 伪代码结构：
  ```
  1. 目标检查（isCanAttack + targetEnemy fallback）
  2. 形态检查（not isInBearForm → bear_form('ready') → return）
  3. isSpellExist guard（Charge + Bash 分别检查）
  4. 距离判断：>=8 → feral_charge('safe')，<8 → bash('ready')
  ```
- Feral Charge 使用 `'safe'` 模式（内置 range+GCD 检查），Bash 使用 `'ready'` 模式（仅 CD+怒气检查）
- 切熊时优先 Dire Bear Form（若可用且当前非 Dire Bear），fallback 到普通 Bear Form
- druidControl 删除 Bash 分支后，`if target.distance < 8` 整个分支移除，Hibernate 分支 `elseif` 变为 `if`
- druidControl 的 Hibernate 和 Entangling Roots 在 druidControl 不切形态的决策下不需要 isSpellExist guard（低等级没学到就直接 cast 失败，行为符合预期）；但如果需要更友好的练级体验，可添加 optional guard
- Bash 的 CD 由 `'ready'` 模式的 `isSpellReady` 内部处理，不需要额外 CD 检查
</specifics>

<deferred>
## Deferred Ideas

- **旋风（Cyclone）集成**: Turtle WoW 新增技能，可考虑未来加入 druidControl
- **熊形态控制技能扩展**: Demoralizing Roar（挫志咆哮）、Challenging Roar（挑战咆哮）、Growl（低吼）等熊形态技能可各自成方法
- **druidCharge 加入 catLeveling 路由**: 练级版 druidAtk 是否在特定场景自动调用 druidCharge
- **Feral Charge + Bash 真 combo 模式**: 如果 Charge 成功接近目标，是否在同一次按键中自动接 Bash（需要突破"一次一个动作"原则，需 OnUpdate 延迟执行）
- **druidControl isSpellExist guard**: 如果练级阶段 druidControl 也需要技能存在性检查（Hibernate 需要 18 级）

None — 讨论保持在 Phase 19 范围内。
</deferred>

---

*Phase: 19-druidcontrol-bash-druidcharge*
*Context gathered: 2026-07-08*