# Phase 22: catAtk-selftest-catatk-core-principles-md-d - Context

**Gathered:** 2026-07-30
**Status:** Ready for planning

<domain>
## Phase Boundary

基于 `catAtk-core-principles.md` 的 14 条设计原则，为 `catAtk()` 及其子模块建立 **~38 个 SelfTest 回归测试用例**（Batch 1 + Batch 2，按规则编号顺序 1→9），附带修正 `catAtk-core-principles.md` 中 `isInfiniteEnergy` → `isPseudoInfiniteEnergy` 的命名不一致。**零行为变更，纯质量基础设施。**

**来源文档：** `.planning/catAtk-phaseB-quality.md`（条目 5 + 部分条目 6）

**不在此范围内：**
- Batch 3 副作用验证测试（`energyDischargeBeforeBite`/`cp5Bite` 的"是否调用了 X"验证）— 需要函数签名增强，留给后续 phase
- Phase B doc 条目 6 的三项文档补充（6.1 加速攒星、6.2 keepRake ATK 爆发、6.3 附录D）— Phase 21 已完成
</domain>

<decisions>
## Implementation Decisions

### 实施范围 (Implementation Scope)

- **D-01: Batch 1+2，按规则编号顺序** — Batch 1（纯函数 ~10 tests: PF-01~07 + R9-01~03）→ Batch 2（条件决策 ~28 tests: Rule 1/2/4/5/6/7/8 的 `should*` 函数）。**Reversibility:** reversible
- **D-02: Batch 3 明确排除** — 副作用验证（R1-01~04, R12-01~03）需要 `energyDischargeBeforeBite`/`cp5Bite` 加返回值才能测试，不在本 phase 范围。测试设计已记录在 Phase B doc 中供将来参考。

### 测试命名 (Test Naming)

- **D-03: 统一格式 `"Principle R<n>-<nn>: description"`** — 如 `"Principle R1-01: overflow prevention — skip energy discharge when isPseudoInfiniteEnergy"`。子编号对应 Phase B doc 中的测试表。`isOptional` 均为 `true`（Druid 职业专属）。

### 游戏依赖处理 (Game Dependency)

- **D-04: 条件 skip 策略** — 测试 `computeReshiftEnergy`（Rule 2）时：非 Druid 或无 Furor 天赋或无 Wolfsheart 附魔 → 静默 return（不 fail）；游戏条件满足 → 正常 assert 预期值。不引入 mock 机制。
- **D-05: clickContext 预设值绕行** — `shouldDoReshift` 等函数中通过 `clickContext` 字段预设值绕过 `macroTorch.player.mana` 等游戏状态依赖。

### 函数签名 (Function Signatures)

- **D-06: 不修改任何函数签名** — Batch 1+2 覆盖的 `should*` 决策函数和纯函数均有返回值。保持零行为变更原则。

### 测试放置 (Test Placement)

- **D-07: 新建 `classes/druid/selftest.lua`** — 单文件包含全部 38 个 SelfTest 注册，按规则编号排序（R1→R2→R4→R5→R6→R7→R8→R9→PF），每个规则用注释 header 分隔。`UnitClass('player') == 'Druid'` guard 在文件顶部统一处理。
- **D-08: build_order.txt 位置** — 放在 `classes/druid/cat.lua` 之后（测试调用 cat.lua 和 Druid.lua 中的函数）。

### 文档修正 (Doc Fix)

- **D-09: 修正 `catAtk-core-principles.md` 附录 D Rule 13** — `isInfiniteEnergy` → `isPseudoInfiniteEnergy`。仅改一个 token，使文档与 Phase 21 代码一致。

### Commit 策略 (Commit Strategy)

- **D-10: 分 2 个 commit**
  1. `test(catAtk): add Batch 1 SelfTest — pure functions + killshot thresholds` — 含 `selftest.lua`（~10 tests）、`build_order.txt` 更新、`catAtk-core-principles.md` 命名修正
  2. `test(catAtk): add Batch 2 SelfTest — conditional decision tests for Rules 1-8` — 含 `selftest.lua`（~28 tests）

### Claude's Discretion

- 测试函数内部 assert 条件的具体措辞
- clickContext 预设字段的具体命名和值
- selftest.lua 内部注释结构（规则分区 header 格式）
- 条件 skip guard 的具体写法（`UnitClass` check + `talentRank` + `isKeywordInEquippedItemTooltip`）
- `isOptional` 参数：所有 Principle R 测试统一用 `true`（Druid 专属）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 测试设计依据
- `.planning/catAtk-core-principles.md` — 14 条设计原则（规则的完整说明）+ 附录 D 可追溯矩阵（测试→原则映射依据）
- `.planning/catAtk-phaseB-quality.md` — 条目 5：完整测试用例设计表（R1~R12 + PF，含预设 ctx 和预期结果）+ 执行建议

### Phase 定义
- `.planning/ROADMAP.md` — Phase 22 目标与依赖
- `.planning/REQUIREMENTS.md` — R5 (登录自检) 约束

### 直接依赖 Phase
- `.planning/phases/21-catAtk-maintainability/21-CONTEXT.md` — `isPseudoInfiniteEnergy` 命名决策（D-04, D-06, D-07）

### SelfTest 框架参考
- `core/selftest.lua` — `SelfTest:register(name, fn, isOptional)` API + 现有测试模式（含 Druid 职业门控 `UnitClass('player')` guard）
- `classes/druid/Druid.lua` — 现有 Druid 专项 SelfTest 注册模式（Phase 3/5/7/14/15）

### 被测试的目标函数
- `classes/druid/cat.lua`（417 行） — catAtk 子模块：`keepRip`, `keepRake`, `keepFF`, `regularAttack`, `oocMod`, `termMod`, `otMod`, `cp5Bite`, `energyDischargeBeforeBite`, `dischargeEnergyChangeRelicAndRip`, `tryBiteKillShot`, `shouldDoReshift`, `readyReshift`
- `classes/druid/Druid.lua`（1383 行） — 决策函数：`shouldUseShred`, `shouldCastRip`, `shouldUseBite`, `shouldCastFFDuringWaitWindow`, `isKillShotOrLastChance`, `isTrivialBattle`, `getKSThreshold`, `estimatePlayerDPS`, `computeErps`, `computeReshiftEnergy`, `computeNormalRelic`
- `classes/druid/combo.lua`（375 行） — `catAtk` 主入口 + `clickContext` 初始化结构

### 构建系统
- `build_order.txt` — 需添加 `classes/druid/selftest.lua`（放在 `classes/druid/cat.lua` 之后）

### 相邻文档（非直接依赖，供参考）
- `.planning/catAtk-phaseA-maintainability.md` — Phase 21 改动背景
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `macroTorch.SelfTest:register(name, fn, isOptional)` — 测试注册 API（`core/selftest.lua`）
- `clickContext` 缓存机制 — 每次 `catAtk()` 调用新建的表，测试可通过预设 ctx 字段完全绕过 WoW API
- `UnitClass('player')` — WoW API 职业门控，已有 Druid 测试全部使用此 guard

### Established Patterns

**测试模式（从现有 SelfTest 提取）：**
```lua
-- Pattern A: 纯函数测试 (computeErps, estimatePlayerDPS, getKSThreshold)
macroTorch.SelfTest:register("Druid: estimatePlayerDPS(15) returns 25", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.estimatePlayerDPS(15)
    assert(val == 25, "expected 25, got " .. tostring(val))
end, true)

-- Pattern B: 条件决策测试（构造 clickContext 预设值）
macroTorch.SelfTest:register("Druid: shouldCastRip with 5CP normal battle", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ctx = {
        isRipPresent = false,
        isImmuneRip = false,
        comboPoints = 5,
        rough = false,
        isTrivialBattle = false,
        isFightStarted = true,
        isNearBy = true,
    }
    assert(macroTorch.shouldCastRip(ctx), "5CP without Rip should cast Rip")
end, true)

-- Pattern C: 条件 skip（computeReshiftEnergy — 依赖游戏状态时静默 return）
macroTorch.SelfTest:register("Principle R2-01: reshift energy 0 → no reshift", function()
    if UnitClass('player') ~= 'Druid' then return end
    if macroTorch.player.talentRank('Furor') == 0
        and not macroTorch.isKeywordInEquippedItemTooltip(1, 'Wolfsheart') then
        return  -- skip: no Furor, no Wolfsheart
    end
    -- test logic with real talent/equipment
end, true)
```

### Key Decision Functions (all return boolean — testable without signature changes)

| Function | File | Returns | Tested in |
|----------|------|---------|-----------|
| `shouldUseShred(ctx)` | Druid.lua:681 | boolean | R6 |
| `shouldCastRip(ctx)` | Druid.lua:909 | boolean | R4, R5 |
| `shouldUseBite(ctx)` | Druid.lua | boolean | R7 |
| `shouldCastFFDuringWaitWindow(ctx)` | Druid.lua:842 | boolean | R8 |
| `shouldDoReshift(ctx)` | cat.lua:195 | boolean | R2 |
| `isKillShotOrLastChance(ctx)` | Druid.lua:783 | boolean | R9 (via getKSThreshold) |
| `isTrivialBattle(ctx)` | Druid.lua | boolean | R4, R5, R6 (preset) |

### Pure Functions (return computed values — easiest to test)

| Function | File | Returns | Tested in |
|----------|------|---------|-----------|
| `getKSThreshold(level)` | Druid.lua:489 | number | R9 |
| `estimatePlayerDPS(level)` | Druid.lua | number | PF-04,05 |
| `computeReshiftEnergy()` | Druid.lua | number | PF-01~03 (game-dependent) |
| `computeErps(ctx)` | Druid.lua:802 | number | PF-06,07 |

### Integration Points
- `core/selftest.lua` — `SelfTest:run()` 通过 `PLAYER_ENTERING_WORLD` 触发（`events.lua`），通过 `/mt` SLASH 命令手动触发
- `build_order.txt` — 新文件必须在 `classes/druid/cat.lua` 之后、构建收尾之前

### New File
- `classes/druid/selftest.lua` — 新建，~250 行（38 个 test × 平均 6 行），内容结构：
  ```
  Apache 2.0 license header
  --- catAtk 原则回归测试（Phase 22）---
  if UnitClass('player') == 'Druid' then
      -- Batch 1: Pure Functions
      -- PF-01 ~ PF-07
      -- R9-01 ~ R9-03
      
      -- Batch 2: Conditional Decision Tests
      -- R1: Overflow Prevention
      -- R2: Starvation Avoidance
      -- R4+R5: Bleed Primacy
      -- R6: Builder Choice
      -- R7: GCD Priority / Bite
      -- R8: FF Fill
  end
  ```
</code_context>

<specifics>
## Specific Ideas

- 测试用例的完整设计（含 ctx 预设值、预期结果）见 `.planning/catAtk-phaseB-quality.md` 条目 5.2 各表格
- `isPseudoInfiniteEnergy` 的拼写确认（Phase 21 D-04）在测试中保持一致
- computeReshiftEnergy 的 PF-01~03 测试中使用条件 skip：`player.talentRank('Furor') == 0 && !isKeywordInEquippedItemTooltip(1, 'Wolfsheart')` → return
- Phase B doc 中 `isInfiniteEnergy` 引用应理解为 `isPseudoInfiniteEnergy`（Phase 21 命名）
- 所有测试 `isOptional = true`（Druid 专属，非 Druid 登录时静默跳过）
</specifics>

<deferred>
## Deferred Ideas

- **Batch 3 副作用验证测试**: R1-01~04（energyDischargeBeforeBite 泄能验证）, R12-01~03（cp5Bite 圣物 swap）— 需要给 `energyDischargeBeforeBite`/`cp5Bite` 加返回值，留给后续 phase
- **active FF maintenance test**: 主动 FF 维护测试（与 Rule 8 等待窗口 FF 不同的逻辑）— FF 主动维护逻辑本身未实现，先不测
- **集成级 catAtk() 调用测试**: 构造完整 clickContext 并在安全环境下调用 catAtk() — 风险高（可能触发实际施法），留待 Batch 3 之后

None — 讨论保持在 Phase 22 范围内。
</deferred>

---

*Phase: 22-catatk-selftest-catatk-core-principles-md-d*
*Context gathered: 2026-07-30*