# Phase 16: catLeveling 练级版一键宏 - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

创建 `catLeveling()` 函数 — 专门为小号练级优化的独立一键宏。**不修改 catAtk**（保持满级服务器第一 DPS 能力不变），新建独立函数，聚焦练级场景的三个核心决策点：

1. **起手技选择** — Ravage vs Pounce，复用 `isTrivialBattleOrPvp` 判断"快速战斗"
2. **中间循环** — 猛虎之怒保持、双流血 buff (Rip+Rake) 维持、精灵之火(野性版) 穿插、攒星技(Shred/Claw)
3. **斩杀判断** — 复用 `isKillShotOrLastChance`（Phase 14 已简化）+ `shouldUseBite`

全程所有技能使用前通过 `isSpellExist` guard（沿用 Phase 13 模式）。

**现有骨架：** `classes/druid/leveling.lua` 已有 `macroTorch.catLeveling()` 定义，含潜行起手逻辑（Pounce/Ravage）和 `<24` 级基础分支。`druidAtk` (`combo.lua:160-172`) 已路由 `level < 60 → catLeveling()`、`level >= 60 → catAtk(rough)`。

**涉及文件：**
- `classes/druid/leveling.lua` — catLeveling 主体实现（重构现有骨架）
- `classes/druid/Druid.lua` — 复用的共享判定函数（只读，不改动）
- `classes/druid/combo.lua` — druidAtk 路由（已就绪，无需改动）
- `classes/druid/cat.lua` — catAtk 参考实现（只读，不改动）
- `core/selftest.lua` — 新增 catLeveling selftest
- `build_order.txt` — leveling.lua 已列入（确认）

**不涉及：** catAtk 任何改动、神像舞逻辑、其他职业、druidAtk/druidAoe 等其他 combo 方法。
</domain>

<decisions>
## Implementation Decisions

### Rotation 架构
- **D-01:** catLeveling **完全独立实现**。构建自己的简化 clickContext（仅 ~12 个必要字段，不含 ERPS/relic 相关字段），内联简化版 debuff/buff 维护和攻击循环。仅复用纯判定函数：`shouldUseShred`、`shouldCastRip`、`shouldUseBite`、`isKillShotOrLastChance`、`isTrivialBattleOrPvp`、`getOpenerHealthThreshold`、`computeClaw_E`/`computeShred_E`/`computeRake_E`/`computeRip_E` 等能耗计算函数。**不调用** catAtk 的 keep 型模块（keepRip/keepRake/keepTigerFury/keepFF/regularAttack），因为它们深度耦合 relic 舞和 energy overflow 泄放逻辑。

### 中间循环优先级
- **D-02:** 严格对齐 catAtk 已验证的优先级顺序：**猛虎之怒 → Rip → Rake → 精灵之火(野性)穿插 → 攒星技(Shred/Claw)**。buff/debuff 维持优先于伤害输出。TF 必须在 Rip/Rake 之前挂上，其回能效果通过 computeErps 传递给所有后续能量决策。
- **D-03:** 保留 reshift 模块但不下沉具体逻辑 — `computeReshiftEnergy` 低等级返回 0 时 `shouldDoReshift` 首行 guard 自动跳过，无需显式移除。
- **D-04:** ooc (Omen of Clarity) 不需要独立模块 — regularAttack 内部通过 `clickContext.ooc` 判断 `'ready'` 模式即可处理免费施放。ooc 时有 combo points 可直接 `ferocious_bite('ready')`。

### 终结技策略
- **D-05:** 复用 catAtk 现有 Bite 逻辑：**斩杀优先于一切**。`isKillShotOrLastChance` → true 时任意 CP 直接 `ferocious_bite('raw')`（跳过能量检查）。非斩杀 → 调用 `shouldUseBite`（快速战斗 CP>=3 / 普通战斗 5cp+Rip 激活）。
- **D-06 [用户澄清]:** CP 上限始终为 5，不随等级变化。不存在"低等级 CP 上限不足 5"的问题。
- **D-07 [用户澄清]:** 斩杀是最终目的，高于 Rip 激活等一切优化。能斩杀时直接斩杀，不等 Rip。

### 神像舞
- **D-08:** catLeveling **完全移除神像逻辑**。不调用 `computeNormalRelic`、`recoverNormalRelic`、`dischargeEnergyChangeRelicAndRip` 等任何 idol 相关函数。WoW Classic 所有猫德神像均为 55-60 级 endgame 掉落，练级阶段不存在神像物品。满级神像舞完整保留在 catAtk 中（`druidAtk` 路由 `level >= 60 → catAtk`）。

### Claude's Discretion
- 简化 clickContext 的具体字段列表（约 12 个字段的确切选择）
- 各模块（keepTigerFury/Rip/Rake/FF/regularAttack）内联实现的具体代码
- keepFF "等待窗口"是否保留（零成本，条件不满足时直接 return）
- Selftest 的具体用例数量和覆盖范围
- leveling.lua 中现有 `<24` 分支的重构方式（保留 vs 改为通用模块结构）
- catLeveling 是否接受 `rough` 参数（与 catAtk 签名对齐）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 16 目标："catLeveling 练级版一键宏 — 起手技选择、中间循环(debuff/buff/精灵之火)、斩杀线判断"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策（直接依赖）
- `.planning/phases/13-catatk-60-dps/13-CONTEXT.md` — `isSpellExist` guard 模式、`computeReshiftEnergy` 动态计算、共享决策函数 guard、模块级 guard 先例
- `.planning/phases/14-istrivialbattle-iskillshotorlastchance-60-dps-b/14-CONTEXT.md` — `estimatePlayerDPS`、`getKSThreshold`、简化后的 `isKillShotOrLastChance`（条件A willDieInSeconds + 条件B 等级自适应单阈值）
- `.planning/phases/15-catatk-druid-combo-lua/15-CONTEXT.md` — catAtk 已移至 combo.lua 全局函数、druidAtk 路由结构
- `.planning/phases/10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol/10-CONTEXT.md` — druidAtk if-elseif 形态路由模式

### 关键源文件
- `classes/druid/leveling.lua` — catLeveling 当前骨架（潜行起手 + <24 分支），Phase 16 的主要修改目标
- `classes/druid/combo.lua:160-172` — druidAtk 形态路由（`level < 60 → catLeveling` 已就绪）
- `classes/druid/cat.lua` — catAtk 13 模块完整实现（参考实现，不改动）
- `classes/druid/Druid.lua` — 共享判定函数：`shouldUseShred`、`shouldCastRip`、`shouldUseBite`、`isKillShotOrLastChance`、`isTrivialBattleOrPvp`、`getOpenerHealthThreshold`、能耗计算函数、`computeReshiftEnergy`、`isSpellExist` guard 基础设施
- `entity/Player.lua` — `_castSpell` / `_isInRange` / `_hasResource` 基类方法
- `biz_util.lua:75-77` — `isSpellExist(spellName, bookType)` 已有基础设施

### 构建系统
- `build_order.txt` — 确认 `classes/druid/leveling.lua` 位置（应在 combo.lua 之后或之前？）

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — metatable __index 链、clickContext 缓存模式、模块优先级执行模型
- `.planning/codebase/CONVENTIONS.md` — 点号语法、全局函数命名、camelCase 约定、Lua 注释风格
</canonical_refs>

<code_context>
## Existing Code Insights

### catLeveling 现有骨架 (leveling.lua)
```lua
function macroTorch.catLeveling()
    -- 形态检查
    if not macroTorch.player.isInCatForm then return end
    -- 目标检查 + 自动选敌
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy(); return
    end
    -- 潜行起手：Pounce/Ravage 选择
    if player.isProwling then
        -- 非快速战斗 + Pounce 可用 + 非免疫 → Pounce
        -- 否则 → Ravage
    end
    -- 战斗后开启自动攻击
    if player.isInCombat then player.startAutoAtk() end
    -- OOC 处理：免费 Claw
    if player.isOoc then player.claw('ready'); return end
    -- <24 分支：Rip + Claw
end
```

### druidAtk 路由 (combo.lua:160-172)
```lua
function macroTorch.druidAtk(rough)
    if macroTorch.player.isInCatForm then
        if macroTorch.player.level >= 60 then
            macroTorch.catAtk(rough)
        else
            macroTorch.catLeveling()
        end
    -- bear/caster 路由...
end
```
注意：catLeveling 当前无参数，但 catAtk 接受 `rough`。如需传递 rough 参数需修改路由行。

### catAtk 中可复用的共享判定函数（Druid.lua）
| 函数 | 用途 | catLeveling 是否复用 |
|------|------|---------------------|
| `shouldUseShred(clickContext)` | Shred vs Claw 决策 | ✅ 复用 |
| `shouldCastRip(clickContext)` | 是否该打 Rip | ✅ 复用 |
| `shouldUseBite(clickContext)` | 是否该打 Bite | ✅ 复用 |
| `isKillShotOrLastChance(clickContext)` | 斩杀判断 | ✅ 复用 |
| `isTrivialBattleOrPvp(clickContext)` | 快速战斗判断 | ✅ 复用（起手技选择） |
| `getOpenerHealthThreshold()` | 起手技血量阈值 | ✅ 复用 |
| `computeClaw_E/Shred_E/Rake_E/Rip_E/Tiger_E` | 动态能耗计算 | ✅ 复用 |
| `computeReshiftEnergy()` | 动态 reshift 能量 | ✅ 复用（低等级自动 no-op） |
| `computeErps(clickContext)` | 能量恢复速率 | ⚠️ 练级可简化（无 relic 贡献） |
| `getMinimumAffordableAbilityCost` | 最低可用技能消耗 | ❌ catLeveling 不需要（无 reshift 决策） |
| `recoverNormalRelic` | 恢复常驻神像 | ❌ 不涉及 |
| `selectFerocityOrEmeraldRot` | 神像选择 | ❌ 不涉及 |
| `shouldCastFFDuringWaitWindow` | FF 等待窗口判断 | ⚠️ 可选保留（零成本 guard） |

### 与 catAtk 的 13 模块对比（catLeveling 需要的最小集）
| catAtk 模块 | catLeveling 是否需要 | 理由 |
|------------|---------------------|------|
| idolRecover | ❌ 移除 | D-08: 无神像逻辑 |
| healthManaSaver | ❌ 移除 | 药水逻辑差异大，练级可后续添加 |
| targetEnemy | ✅ 保留 | 已存在于骨架 |
| keepAutoAttack | ✅ 保留 | 已存在于骨架 |
| rushMod | ❌ 移除 | 无 Berserk/Trinket |
| openerMod | ✅ 重写 | 已有骨架，需按 D-05 完善 |
| oocMod | ✅ 内联 | 在 regularAttack 中处理（D-04） |
| termMod | ✅ 内联 | 简化版 Bite 判断（D-05） |
| otMod | ❌ 移除 | 无 Cower/团本威胁 |
| tigerFury | ✅ 重写 | 内联实现（D-02） |
| debuffMod | ✅ 重写 | 内联 Rip/Rake/FF（D-02） |
| regularAttack | ✅ 重写 | 内联 Shred/Claw（D-02） |
| reshiftMod | ✅ 保留 | 低等级自动 no-op（D-03） |

### Reusable Assets
- **共享判定函数** (`Druid.lua`): 全部可复用，已 level-adaptive + isSpellExist guarded
- **`macroTorch.isSpellExist(spellName, bookType)`** (`biz_util.lua:75`): 已存在
- **`player._castSpell(localeNames, mode, range, resourceCost, onSelf)`**: 底层技能释放
- **所有 Druid 技能方法** (`Druid.lua`): `player.claw()`、`player.shred()`、`player.rip()`、`player.rake()`、`player.ferocious_bite()`、`player.tigers_fury()`、`player.faerie_fire_feral()`、`player.pounce()`、`player.ravage()` 等
- **`macroTorch.SelfTest:register(name, fn, isOptional)`** (`core/selftest.lua`): 自检框架

### Established Patterns
- **clickContext 单次缓存**: `if clickContext.X == nil then compute; cache end`
- **模块级 guard**: `if not condition then return end` — reshiftMod 先例
- **全局函数定义**: `function macroTorch.catLeveling() ... end`
- **一键宏"一次一个动作"**: 第一个成功动作 return，不连续执行

### Integration Points
- `classes/druid/combo.lua:165` — druidAtk 已调用 catLeveling，无需改动
- `classes/druid/leveling.lua` — 主战场，重构现有骨架
- `core/selftest.lua` — 新增 catLeveling selftest
- `build_order.txt` — 确认 leveling.lua 位置
</code_context>

<specifics>
## Specific Ideas

- catLeveling 不需要 `rough` 参数（练级无需区分 rough 模式），但 druidAtk 路由行需要相应调整或 catLeveling 接受并忽略该参数
- 现有 `<24` 骨架代码可作为模块结构的起点，重构为通用的优先级模块链（TF → Rip → Rake → FF → Shred/Claw），而非等级段 if-else
- 等级段差异仅体现在 `isSpellExist` guard 自动跳过，不需要显式 `if level < N` 分支——这与 Phase 13 的设计理念一致
- FF 等待窗口可保留（零成本 guard），但练级场景触发概率低
- 起手技逻辑骨架已基本正确：非快速战斗 + Pounce 可用 + 非免疫 → Pounce，否则 → Ravage
- 练级中遇到精英怪/副本 boss 时 `isTrivialBattleOrPvp` 会正确返回 false，自动走正常战斗路径（高星 Rip、等 Rip 激活再 Bite）
</specifics>

<deferred>
## Deferred Ideas

- **healthManaSaver 练级版**: 药水/治疗逻辑可在后续 Phase 添加，当前 catLeveling 跳过
- **rushMod/burstMod 练级版**: 低等级可能无爆发技能，60 级时已有 catAtk 路由
- **Cower/OT 管理**: 练级 solo 不需要威胁管理
- **其他职业练级版**: Warrior/Rogue 等职业的低等级一键宏属于各自未来 Phase
- **catLeveling rough 模式**: 未来如需支持，可在签名中加 `rough` 参数并透传

None — 讨论保持在 Phase 16 范围内。
</deferred>

---

*Phase: 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra*
*Context gathered: 2026-06-22*