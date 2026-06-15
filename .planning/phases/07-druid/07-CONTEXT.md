# Phase 7: Druid 形态判断语义化方法 - Context

**Gathered:** 2026-06-15
**Status:** Ready for planning

<domain>
## Phase Boundary

在保留 `isFormActive` 通用方法的同时，为 Druid 类新增 5 个语义化形态判断方法（`isInCatForm`/`isInBearForm`/`isInTravelForm`/`isInAquaticForm`/`isInCasterForm`），并替换 `classes/druid/Druid.lua`、`classes/druid/bear.lua`、`classes/druid/utility.lua` 中现有的 7 处 `isFormActive` 硬编码字符串调用。

不改变任何战斗逻辑，纯重构 — 语义等价替换。
</domain>

<decisions>
## Implementation Decisions

### 方法定义位置
- **D-01:** 5 个语义化方法定义在 `DRUID_FIELD_FUNC_MAP` 中作为懒计算属性，与现有 `isOoc`/`isProwling`/`isBerserk` 模式一致。`isFormActive` 保留在 `entity/Player.lua` 基类不变，作为通用 fallback（Warrior Stance 等场景仍可用）。

### isInBearForm 覆盖范围
- **D-02:** `isInBearForm` 同时检查 `'Bear Form'` 和 `'Dire Bear Form'`（OR 逻辑），覆盖 level 10-39 德鲁伊。两种形态在 WoW 1.12.1 中不会同时存在于形态条上，OR 逻辑无歧义。

### 方法完整性
- **D-03:** 5 个方法全部实现。`isInTravelForm`/`isInAquaticForm`/`isInCasterForm`（当前零调用）标注 `-- reserved for future expansion` 注释，与 Phase 5 已有的形态技能方法（`travel_form()`/`aquatic_form()` 等）形成对称 API。

### 替换范围
- **D-04:** 替换所有 7 处 `isFormActive` 硬编码调用：
  - `classes/druid/Druid.lua:348-349,531` — 3 处
  - `classes/druid/bear.lua:66,102` — 2 处
  - `classes/druid/utility.lua:15,39` — 2 处

### Claude's Discretion
- DRUID_FIELD_FUNC_MAP 中 5 个新属性的精确顺序和位置
- 注释措辞（`-- reserved for future expansion`）
- self-test 注册的具体实现（复用现有 Category D Druid 测试模式）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 7 目标："在保留 isFormActive 通用方法的同时，为 Druid 类新增 5 个语义化形态判断方法"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策
- `.planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md` — D-01 (纯点号语法约定)
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` — D-04 (技能方法集中在 Druid 构造函数)
- `.planning/phases/04-class-files/04-CONTEXT.md` — D-01 (按形态就近放置，跨形态共享放 Druid.lua)

### 关键源文件
- `entity/Player.lua:158-169` — `isFormActive` 当前定义（使用 `GetShapeshiftFormInfo` API）
- `classes/druid/Druid.lua:433+` — `DRUID_FIELD_FUNC_MAP` 现有条目（isOoc/isProwling/isBerserk 参考模式）
- `classes/druid/Druid.lua:348-349,531` — catAtk 和 recoverNormalRelic 中的 isFormActive 调用
- `classes/druid/bear.lua:66,102` — bearAoe 和 bearAtk 中的 isFormActive 调用
- `classes/druid/utility.lua:15,39` — druidStun 和 druidDefend 中的 isFormActive 调用

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — metatable __index 链 + FIELD_FUNC_MAP 计算属性机制
- `.planning/codebase/CONVENTIONS.md` — 点号定义惯例、全局函数命名
</canonical_refs>

<code_context>
## Existing Code Insights

### isFormActive 当前实现
```lua
-- entity/Player.lua:158
function obj.isFormActive(formName)
    local numOfStances = GetNumShapeshiftForms()
    for i = 1, numOfStances do
        local idx, spellName, active = GetShapeshiftFormInfo(i)
        if active then
            if macroTorch.equalsIgnoreCase(spellName, formName) then
                return true
            end
        end
    end
    return false
end
```

### 目标模式（参考 isOoc/isProwling/isBerserk）
```lua
-- DRUID_FIELD_FUNC_MAP 现有条目模式:
macroTorch.DRUID_FIELD_FUNC_MAP["isOoc"] = function(target)
    -- 通过 self.ref 访问 player 实例
end
```

### 7 处调用点详情
| # | 文件 | 行 | 当前调用 | 替换为 |
|---|------|-----|---------|--------|
| 1 | Druid.lua | 348 | `player.isFormActive('Dire Bear Form')` | `player.isInBearForm` |
| 2 | Druid.lua | 349 | `player.isFormActive('Cat Form')` | `player.isInCatForm` |
| 3 | Druid.lua | 531 | `player.isFormActive('Cat Form')` | `player.isInCatForm` |
| 4 | bear.lua | 66 | `macroTorch.player.isFormActive('Dire Bear Form')` | `macroTorch.player.isInBearForm` |
| 5 | bear.lua | 102 | `player.isFormActive('Dire Bear Form')` | `player.isInBearForm` |
| 6 | utility.lua | 15 | `macroTorch.player.isFormActive('Dire Bear Form')` | `macroTorch.player.isInBearForm` |
| 7 | utility.lua | 39 | `macroTorch.player.isFormActive('Dire Bear Form')` | `macroTorch.player.isInBearForm` |

### Reusable Assets
- **`DRUID_FIELD_FUNC_MAP`** (`classes/druid/Druid.lua`): 已有 `isOoc`/`isProwling`/`isBerserk` 等计算属性，5 个新方法按同模式添加
- **`isFormActive`** (`entity/Player.lua:158`): 新增方法内部委托给它，不重复实现 WoW API 调用

### Established Patterns
- **FIELD_FUNC_MAP 懒计算属性**: `DRUID_FIELD_FUNC_MAP["propertyName"] = function(target) ... end`，通过 metatable `__index` 链解析
- **点号语法**: 方法定义和调用全代码库使用点号（Phase 6 D-01）
- **SelfTest 注册**: Category D Druid 测试通过 `SelfTest:register()` 注册

### Integration Points
- `classes/druid/Druid.lua` — 新增 5 个 DRUID_FIELD_FUNC_MAP 条目 + 5 个 SelfTest 注册
- `classes/druid/Druid.lua:348-349,531` — 3 处调用替换
- `classes/druid/bear.lua:66,102` — 2 处调用替换
- `classes/druid/utility.lua:15,39` — 2 处调用替换
- `entity/Player.lua` — 无变更（isFormActive 保留不动）
- `build_order.txt` / `build.sh` — 无需变更
</code_context>

<specifics>
## Specific Ideas

- 每个新方法 ~3-5 行，直接委托给 `self.isFormActive('FormName')`（或 OR 组合）
- `isInBearForm` 特殊处理：`self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')`
- 未调用的 3 个方法标注 `-- reserved for future expansion`，告知未来维护者这是有意预留而非遗漏
- 调用方替换是纯机械操作：字符串 `'Cat Form'` → 方法调用 `.isInCatForm`，语义等价
- 保留 `clickContext.isInCatForm` / `clickContext.isInBearForm` 的缓存模式不变（DRUID_FIELD_FUNC_MAP 懒计算属性首次访问后 metatable 缓存）
</specifics>

<deferred>
## Deferred Ideas

- **Travel/Aquatic/Caster 形态战斗逻辑**: 目前代码库中无相关实现，属于未来 Phase。Phase 7 仅提供形态判断基础设施（D-03 的 reserved 注释即为这些未来 Phase 预留）。
- **Warrior Stance 语义化方法**: `isFormActive` 对 Warrior 的 Battle/Defensive/Berserker Stance 同样适用。若未来需要，可参照 Druid 模式为 Warrior 类添加。
- **DRUID_FIELD_FUNC_MAP 性能优化**: 当前 metatable 查找开销对 WoW 宏系统可忽略，无优化需求。

None — 讨论保持在 Phase 7 范围内。
</deferred>

---

*Phase: 07-Druid 形态判断语义化方法*
*Context gathered: 2026-06-15*