---
quick_id: 260916-utm
slug: catatk-builder-1-selectferocityoremerald
description: "catAtk builder 神像选择三层化：selectFerocityOrEmeraldRot 增加 clickContext 参数，两件都拥有时按 T1优先(8/8 Cenarion→Ferocity)→战斗中粘性(已穿任一 builder 保持当前件)→战斗类型(fast/trivial/pvp→Ferocity，普通→Emerald Rot) 三层选择；computeNormalRelic 4 处调用点改传 clickContext；执行层(recoverNormalRelic/ensureRelicEquipped/equipRelic/dischargeEnergyChangeRelicAndRip)零改动；新增 Cat O-08..O-16 九项 selftest。Lua 5.0 语法约束。恰 2 文件、2 原子 commit。"
date: 2026-09-16
phase: quick-260916-utm
plan: 260916-utm
type: execute
wave: 1
depends_on: []
files_modified: [classes/druid/Druid.lua, classes/druid/selftest.lua]
autonomous: true
requirements: ["D-01@quick-260916-utm", "D-02@quick-260916-utm", "D-03@quick-260916-utm", "D-04@quick-260916-utm", "D-05@quick-260916-utm"]
estimate:
  tokens: 40000
  raw_tokens: 20000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "两件都拥有且 countEquippedItemNameContains('Cenarion') >= 8 → 恒返回 Idol of Ferocity，且该判定先于粘性（O-10 pin：战斗中穿 E 时仍得 F）"
    - "两件都拥有、非 8/8 T1、战斗中：已穿 Ferocity → 返回 Ferocity；已穿 Emerald Rot → 返回 Emerald Rot；粘性守卫在选择层 selectFerocityOrEmeraldRot 内部实现（D-02，O-11/O-12 pin）"
    - "两件都拥有、非 8/8 T1、战斗中但当前穿戴非 builder（如 Savagery）或非战斗：macroTorch.isTrivialBattleOrPvp(clickContext) or macroTorch.isFastBattleNotPvp(clickContext) 为真 → Ferocity，为假 → Emerald Rot（D-04，O-13/O-14/O-15 pin）"
    - "只拥有一件 → 选那件；两件都无 → 默认 Ferocity：既有单件/默认分支字节语义不变（O-08/O-09 pin）"
    - "computeNormalRelic 4 处调用点全部传 clickContext；仓库内不再存在无参调用 selectFerocityOrEmeraldRot()（grep -F 计数 0）"
    - "执行层零改动：recoverNormalRelic/ensureRelicEquipped/equipRelic/cat.lua 的 dischargeEnergyChangeRelicAndRip 及仓库其余文件无任何 diff（D-03，git diff --name-only 逐 commit 恰 1 文件）"
    - "静态门全绿：bbcheck 两文件 BALANCED；三解释器 loadfile（lua-5.0.3 为准、5.1.5/5.4.7 佐证）通过；diff 新增行 Lua 5.0 令牌门 0；CRLF 0；Druid.lua 行数 1781→1795；selftest 'Cat O-' 注册计数 7→16（D-05）"
  artifacts:
    - "/home/admin/workspace/macro-torch/classes/druid/Druid.lua（仅 600-657 区域改动：4 个 return 调用点 + selectFerocityOrEmeraldRot 函数体重构，1795 行）"
    - "/home/admin/workspace/macro-torch/classes/druid/selftest.lua（O-07 之后、Category Q 注释块之前插入 O-08..O-16 九组注册，tab 缩进）"
    - "/home/admin/workspace/macro-torch/.planning/quick/260916-utm-catatk-builder-1-selectferocityoremerald/260916-utm-SUMMARY.md（quick 流程收口，不入代码 commit）"
  key_links:
    - "computeNormalRelic 四分支（603/607/615/619 的 return 行）→ selectFerocityOrEmeraldRot(clickContext)：唯一调用面"
    - "selectFerocityOrEmeraldRot → player.countEquippedItemNameContains / player.isRelicEquipped / player.isInCombat / macroTorch.isTrivialBattleOrPvp(clickContext) / macroTorch.isFastBattleNotPvp(clickContext)：判定依赖链"
    - "选择层 → 执行层（recoverNormalRelic/equipRelic/dischargeEnergyChangeRelicAndRip）：本次零触碰；返回值契约仍为 'Idol of Ferocity' / 'Idol of the Emerald Rot' 两枚字符串（D-03）"
    - "selftest O-08..O-16 → 选择层：stub 全还原纪律（CR-01），isInCombat 为 UNIT_FIELD_FUNC_MAP accessor，须 rawget 快照 + rawset 遮蔽 + rawset 还原"
---

# PLAN: catAtk builder 神像选择三层化（Druid.lua 选择层 + O-08..O-16 selftests）

## 目标

1. **Druid.lua（D-01/D-02/D-04）**：`macroTorch.selectFerocityOrEmeraldRot` 增加 `clickContext` 参数，两件都拥有时的选择从"静态 8/8 T1 二分支"重构为三层优先级：
   - 第 1 层：`player.countEquippedItemNameContains('Cenarion') >= 8` → 永远 `Idol of Ferocity`（与 Emerald Rot 效果冲突；既有行为零回归）；
   - 第 2 层：`player.isInCombat` 且已穿戴任一 builder（先用 `isRelicEquipped('Idol of Ferocity')` 判、再判 Emerald Rot）→ 返回当前穿戴件，禁止 builder↔builder 互切；
   - 第 3 层：`macroTorch.isTrivialBattleOrPvp(clickContext) or macroTorch.isFastBattleNotPvp(clickContext)` 为真 → Ferocity，否则 → Emerald Rot。
   同时 `computeNormalRelic` 的 4 处 `return macroTorch.selectFerocityOrEmeraldRot()` 全部改为传 `(clickContext)`。
2. **执行层零改动（D-03）**：`recoverNormalRelic` / `ensureRelicEquipped` / `equipRelic` / `cat.lua` 的 `dischargeEnergyChangeRelicAndRip` 及仓库其余文件零 diff。
3. **selftest（D-01/D-02/D-04 pin）**：`classes/druid/selftest.lua` Category O 区新增 O-08..O-16 九项注册，覆盖：单件双向、8/8 T1 优先于粘性、粘性双向、fast/trivial/pvp→F、普通→E、战斗中穿非 builder→战斗类型、真实判定函数接线（预置懒缓存字段）。
4. **零回归**：既有 O-01..O-07 全部断言只依赖"非 Savagery / 是 Savagery"两级语义，新三层只影响 Builder 内部 F/E 二选一，不产生新回归路径；既有 O 测试无需改动。

## 背景事实（2026-09-16 规划时实地取证，编辑锚点以本节为准）

- 工作树 clean；HEAD = `69c2e4b`。`git status --porcelain` 为空。
- `classes/druid/Druid.lua` 共 **1781 行**（LF，`grep -c $'\r'` = 0）。锚点逐行核对过：
  - `600` = `function macroTorch.computeNormalRelic(clickContext)`；四调用点为 `603`/`607`/`615`/`619`，文本完全一致：`        return macroTorch.selectFerocityOrEmeraldRot()`（8 空格缩进）。
  - `625-629` = 现有中文头注释；`630` = `function macroTorch.selectFerocityOrEmeraldRot()`（无参）；`657` = 函数尾 `end`。
  - `659` = `function macroTorch.recoverNormalRelic(clickContext, relicName)` —— D-03 禁区起点，本计划所有 Druid.lua 编辑必须止于 657 行以内。
- `classes/druid/selftest.lua` 共 **2504 行**（LF，`grep -c $'\r'` = 0；文件尾以 `end` + 换行结束，无悬空 EOF 问题）。Category O 区现状：`register("Cat O-` 恰 **7** 处（O-01..O-07），O-07 注册块尾为 `947 行 end, true)`；`949` 行起为 `-- Category Q:` 注释块 —— **插入点 = 947 与 949 之间**。全文件 tab 缩进，新增测试沿用 tab。
- 判定依赖实现（已定位，供 stub 设计）：
  - `macroTorch.player.isInCombat` = `UNIT_FIELD_FUNC_MAP` accessor（`entity/Unit.lua:226-228`，读 `UnitAffectingCombat`）。stub 必须 `rawget(macroTorch.player, 'isInCombat')` 快照（正常为 nil）、`rawset` 写布尔遮蔽、测试后按快照值 `rawset` 还原（nil 还原即删除自有键、accessor 复活 —— Phase 26-03 CR-01 纪律）。
  - `player.hasItem` / `player.isRelicEquipped` / `player.countEquippedItemNameContains` 均为 Player 实例自有键方法（构造期 `function obj.X` 赋值），普通赋值 stub + 快照还原即可；`player.isRelicEquipped` 委托 `macroTorch.isRelicEquipped`（= `biz_util.lua:359` 起别名 `isRangedWeaponEquipped`，读 slot 18，规划不触碰）。
  - `macroTorch.isTrivialBattleOrPvp(clickContext)` = `target.isPlayerControlled or isTrivialBattle(clickContext)`；`isTrivialBattle` 先读 `clickContext.isTrivialBattle` 缓存（nil 时才触目标检测，`isCanAttack` 守卫）。`macroTorch.isFastBattleNotPvp(clickContext)` 先做 PvP 排除（读 `target.isPlayerControlled`，安全 accessor），再读 `clickContext.isFastBattleNotPvp` 缓存。**两者均为普通全局函数**，O-08..O-15 直接快照/赋值 stub 两函数；O-16 以预置 `ctx.isTrivialBattle` / `ctx.isFastBattleNotPvp` 字段走真实判定体，证明 D-04 表达式的 clickContext 接线。
- 工具在位（规划时实测）：`/usr/bin/luac`；`/tmp/luabuild/lua-5.0.3/bin/lua`、`/tmp/luabuild/lua-5.1.5/src/lua`、`/tmp/luabuild/lua-5.4.7/src/lua`（三个解释器 `loadfile` 可用，仅语法解析不执行 WoW 全局）；bbcheck 路径 `.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js`（调用 `node`）。
- 新函数体 47 行替换旧体 33 行 → Druid.lua 预期 **1795 行**（+14，纯插入面）；调用点 4 行仅内容变化不加行。
- 本机无 WoW 客户端：九项新 selftest 的实机运行由用户 Windows+Cygwin 重建后 `/mt` 目视（unrun-verify 口径，SUMMARY 备案；本 quick 不碰 WINDOWS.md）。

## 锁定约束（违反即失败）

1. **只改两个文件**：`classes/druid/Druid.lua`、`classes/druid/selftest.lua`。`core/events.lua`、`cat.lua`、`combo.lua`、`recoverNormalRelic` 及其所在全部代码、`build_order.txt`、`SM_Extend.lua`、`.planning/STATE.md`、`.planning/WINDOWS.md` 及仓库其余文件零触碰（D-03）。
2. **Druid.lua 编辑面锁定**：仅 (a) 625-657 函数注释+函数体整块替换、(b) 603/607/615/619 四个 return 行换内容。编辑后 Druid.lua = 1795 行；`git diff` 的 hunk 必须全部落在 600-660 行带内，659 行（recoverNormalRelic）起零 diff。
3. **三层优先级与判定表达逐字锁定**：第 1 层比较写作 `countEquippedItemNameContains('Cenarion') >= 8`；第 2 层先判 Ferocity 再判 Emerald Rot；第 3 层表达式写作 `macroTorch.isTrivialBattleOrPvp(clickContext) or macroTorch.isFastBattleNotPvp(clickContext)`（D-04 原文，顺序不可颠倒、不可改写等价形式）。
4. **粘性守卫只在两件都拥有的分支内**：单件分支、两件都无分支的既有 keys 字节不变（"只存在一个时选那个"两条 if 与"两个都不存在"默认 return 原样保留）。
5. **执行层与既有测试不动**：O-01..O-07 及 Category Q 之后全部测试字节不变；recoverNormalRelic 等执行函数不动；新函数返回值仍只会是 `'Idol of Ferocity'` / `'Idol of the Emerald Rot'` 两枚既有字符串，选择函数不在任何分支返回 Savagery。
6. **Lua 5.0(WoW 1.12) 合规（D-05）**：新代码无 `#` 长度运算符、无 `goto`、无 `::`、无 `\` 续行；中文注释风格与现有 Druid.lua 注释一致；行尾 LF。
7. **stub 还原纪律（CR-01）**：O-08..O-16 每个测试先快照后安装 stub；函数调用放 pcall 内、结果收局部变量；**全部还原动作先于任何 assert**；`isInCombat` 用 rawget/rawset 往返。任何失败路径都不得留下污染会话的 stub。
8. **原子性**：Task 1 commit 只含 Druid.lua，Task 2 commit 只含 selftest.lua；SUMMARY.md 由 quick 流程 docs 收口，不进代码 commit。

## 任务

### Task 1: Druid.lua 三层选择重构 + 4 调用点传参（D-01/D-02/D-04，commit 1）

**文件**: `classes/druid/Druid.lua`（仅此一个）

**执行步骤（2 次 Edit，顺序固定；任何锚点不匹配=文件漂移，停下报告，不得自行发挥）：**

**(a) 函数头注释 + 函数体整块替换**（625-657，旧 33 行 → 新 47 行）：

```
--- before ---
-- 在Idol of Ferocity和Idol of the Emerald Rot之间选择
-- 逻辑：检查拥有情况（背包 or 身上）：如果只有一个存在，选那个
--       如果两个都存在：
--       - 若穿着8/8 Cenarion T1，选Ferocity（不冲突）
--       - 否则选Emerald Rot（与8/8 T1效果冲突）
function macroTorch.selectFerocityOrEmeraldRot()
    local IDOL_FEROCITY = 'Idol of Ferocity'
    local IDOL_EMERALD_ROT = 'Idol of the Emerald Rot'

    local player = macroTorch.player
    local hasFerocity = player.hasItem(IDOL_FEROCITY) or player.isRelicEquipped(IDOL_FEROCITY)
    local hasEmeraldRot = player.hasItem(IDOL_EMERALD_ROT) or player.isRelicEquipped(IDOL_EMERALD_ROT)

    -- 只存在一个时选那个
    if hasFerocity and not hasEmeraldRot then
        return IDOL_FEROCITY
    end
    if hasEmeraldRot and not hasFerocity then
        return IDOL_EMERALD_ROT
    end

    -- 两个都存在时，根据8/8 T1判断
    if hasFerocity and hasEmeraldRot then
        if player.countEquippedItemNameContains('Cenarion') >= 8 then
            return IDOL_FEROCITY
        else
            return IDOL_EMERALD_ROT
        end
    end

    -- 两个都不存在，默认返回Ferocity（兼容原逻辑）
    return IDOL_FEROCITY
end
--- after ---
-- 在Idol of Ferocity和Idol of the Emerald Rot之间选择
-- 逻辑：检查拥有情况（背包 or 身上）：如果只有一个存在，选那个
--       如果两个都存在，按三层优先级（D-01/D-02/D-04）：
--       1. 8/8 Cenarion T1：永远 Ferocity（T1 套装效果与 Emerald Rot 冲突）
--       2. 战斗粘性：战斗中已穿戴任一 builder 神像时保持当前穿戴，禁止互切
--       3. 战斗类型：fast/trivial/pvp → Ferocity；普通战斗 → Emerald Rot
function macroTorch.selectFerocityOrEmeraldRot(clickContext)
    local IDOL_FEROCITY = 'Idol of Ferocity'
    local IDOL_EMERALD_ROT = 'Idol of the Emerald Rot'

    local player = macroTorch.player
    local hasFerocity = player.hasItem(IDOL_FEROCITY) or player.isRelicEquipped(IDOL_FEROCITY)
    local hasEmeraldRot = player.hasItem(IDOL_EMERALD_ROT) or player.isRelicEquipped(IDOL_EMERALD_ROT)

    -- 只存在一个时选那个
    if hasFerocity and not hasEmeraldRot then
        return IDOL_FEROCITY
    end
    if hasEmeraldRot and not hasFerocity then
        return IDOL_EMERALD_ROT
    end

    -- 两个都存在时的三层选择
    if hasFerocity and hasEmeraldRot then
        -- 1. 8/8 Cenarion T1：套装效果与 Emerald Rot 冲突，无条件 Ferocity（D-01）
        if player.countEquippedItemNameContains('Cenarion') >= 8 then
            return IDOL_FEROCITY
        end
        -- 2. 战斗粘性：战斗中已穿戴任一 builder，保持当前件，禁止互切（D-02）
        if player.isInCombat then
            if player.isRelicEquipped(IDOL_FEROCITY) then
                return IDOL_FEROCITY
            end
            if player.isRelicEquipped(IDOL_EMERALD_ROT) then
                return IDOL_EMERALD_ROT
            end
        end
        -- 3. 战斗类型：fast/trivial/pvp → Ferocity，否则 Emerald Rot（D-04）
        if macroTorch.isTrivialBattleOrPvp(clickContext) or macroTorch.isFastBattleNotPvp(clickContext) then
            return IDOL_FEROCITY
        end
        return IDOL_EMERALD_ROT
    end

    -- 两个都不存在，默认返回Ferocity（兼容原逻辑）
    return IDOL_FEROCITY
end
```

**(b) 4 调用点传参**（单次 Edit，`replace_all`，old 文本与函数定义行无重叠、恰命中 4 处）：

```
--- before ---
        return macroTorch.selectFerocityOrEmeraldRot()
--- after ---
        return macroTorch.selectFerocityOrEmeraldRot(clickContext)
```

**验证门（全过才算完成）：**

1. `grep -c "return macroTorch.selectFerocityOrEmeraldRot(clickContext)" classes/druid/Druid.lua` → **4**
2. `grep -Fc "selectFerocityOrEmeraldRot()" classes/druid/Druid.lua` → **0**（无参形式清零，含函数定义行）
3. `wc -l < classes/druid/Druid.lua` → **1795**
4. `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua` → **BALANCED**
5. 三解释器语法门（在仓库根目录执行；5.0 为准）：`/tmp/luabuild/lua-5.0.3/bin/lua -e "assert(loadfile('classes/druid/Druid.lua'))"`、`/tmp/luabuild/lua-5.1.5/src/lua -e "assert(loadfile('classes/druid/Druid.lua'))"`、`/tmp/luabuild/lua-5.4.7/src/lua -e "assert(loadfile('classes/druid/Druid.lua'))"` → 均 exit 0
6. diff 范围 Lua 5.0 令牌门：`git diff -U0 -- classes/druid/Druid.lua | grep '^+' | grep -v '^+++' | grep -c '#\|goto \|::'` → **0**（注释里的 `#` 老行在 942-943，不在 diff 面内，门不受污染）
7. CRLF：`grep -c $'\r' classes/druid/Druid.lua` → **0**
8. D-03 范围门：`git diff --name-only` → 恰 `classes/druid/Druid.lua` 一行；`git diff -U0 -- classes/druid/Druid.lua | grep '^@@'` → 全部 hunk 行号 < 660（659 起 recoverNormalRelic 零 diff）

**提交（门 1-8 全绿后，只 add 一个文件）**：
message: `feat(260916-utm): selectFerocityOrEmeraldRot clickContext + 3-layer priority (T1/sticky/battle-type)`

### Task 2: selftest Cat O-08..O-16 九项注册（D-01/D-02/D-04 pin，commit 2）

**文件**: `classes/druid/selftest.lua`（仅此一个）

**插入锚点**：947 行 `	end, true)`（O-07 注册尾）与 949 行 `	-- Category Q: event-driven land-framework regression tests` 之间；tab 缩进；九项全部 `macroTorch.SelfTest:register("Cat O-XX: ...", function() ... end, true)`（isOptional=true，与邻居一致）；全部位于文件顶部既有 `if UnitClass('player') == 'Druid' then` 块内。

**通用 stub 纪律（每项测试必须遵守，CR-01）**：
- 快照（安装前）：`player.hasItem`、`player.isRelicEquipped`、`player.countEquippedItemNameContains`（普通赋值快照）；`rawget(player, 'isInCombat')`（accessor 遮蔽，正常为 nil）；`macroTorch.isTrivialBattleOrPvp`、`macroTorch.isFastBattleNotPvp`（两个全局函数快照，O-16 两项除外——保留真实实现）。
- 安装：hasItem 按名字含 Ferocity/Emerald 返回测试指定布尔；isRelicEquipped 按名字返回测试指定布尔；countEquippedItemNameContains 返回测试指定数值；isInCombat 用 `rawset` 写布尔；两个判定函数赋 `function(ctx) return <bool> end`（空 ctx 直接用 `{}`）。
- 执行：`local ok, res = pcall(function() return macroTorch.selectFerocityOrEmeraldRot(ctx) end)`；多轮测试（O-13/O-15/O-16）安装一次 stub、每轮一个 pcall 各自收结果。
- 还原（断言之前）：六项按快照普通赋值还原 + `rawset(player, 'isInCombat', 快照值)`（nil 还原即删除自有键，accessor 复活）。
- 断言：先 `assert(ok, "selectFerocityOrEmeraldRot pcall failed: " .. tostring(res))`，再逐轮 `assert(res == <预期字符串>, "<编号> expected <预期>, got " .. tostring(res))`。

**九项测试逐项契约（种子 → 预期）：**

| # | 注册名（`Cat O-XX: ` 前缀后文案） | 种子 | 预期 |
|---|----------------------------------|------|------|
| O-08 | `Ferocity-only ownership returns Ferocity` | hasItem: F 有 / E 无；isRelicEquipped: 全 false；C=0；isInCombat=false；Vt=false, Vf=false | `Idol of Ferocity` |
| O-09 | `Emerald-Rot-only ownership returns Emerald Rot` | hasItem: E 有 / F 无；其余同 O-08 | `Idol of the Emerald Rot` |
| O-10 | `8/8 Cenarion T1 beats in-combat stickiness` | hasItem: 两件都有；isRelicEquipped: E=true / F=false；C=8；isInCombat=true；Vt/Vf=false（若穿透则战斗类型会给出 E——断言 F 即证明 T1 先于粘性） | `Idol of Ferocity` |
| O-11 | `in-combat wearing Ferocity sticks to Ferocity` | hasItem: 两件都有；isRelicEquipped: F=true / E=false；C=0；isInCombat=true；Vt/Vf=false（穿透则得 E） | `Idol of Ferocity` |
| O-12 | `in-combat wearing Emerald Rot sticks to Emerald Rot` | hasItem: 两件都有；isRelicEquipped: E=true / F=false；C=0；isInCombat=true；Vt/Vf=true（穿透则得 F） | `Idol of the Emerald Rot` |
| O-13 | `fast/trivial battle type selects Ferocity (both verdict arms)` | hasItem: 两件都有；isRelicEquipped: 全 false；C=0；isInCombat=false；**两轮**：轮 a Vt=true/Vf=false；轮 b Vt=false/Vf=true | 两轮均 `Idol of Ferocity`（轮 b pin 表达式第二臂） |
| O-14 | `normal battle selects Emerald Rot` | hasItem: 两件都有；isRelicEquipped: 全 false；C=0；isInCombat=false；Vt=false, Vf=false | `Idol of the Emerald Rot` |
| O-15 | `in-combat non-builder falls through to battle type` | hasItem: 两件都有（模拟在包内未穿）；isRelicEquipped: 全 false（当前穿戴 Savagery/其他）；C=0；isInCombat=true；**两轮**：轮 a Vt=true/Vf=false；轮 b Vt=false/Vf=false | 轮 a `Idol of Ferocity`；轮 b `Idol of the Emerald Rot` |
| O-16 | `real verdict wiring — seeded clickContext reaches isTrivialBattleOrPvp / isFastBattleNotPvp` | 开头两守卫：`if not macroTorch.target.isCanAttack then return end`、`if macroTorch.target.isPlayerControlled then return end`（对齐 P 系列既有守卫）；**不 stub 两个判定函数**；hasItem: 两件都有；isRelicEquipped: 全 false；C=0；isInCombat=false；**两轮**：轮 a `ctx = { isTrivialBattle = true }`；轮 b `ctx = { isTrivialBattle = false, isFastBattleNotPvp = true }`（预置懒缓存字段使真实判定体不经目标血量臂直接给出 verdict，证明 D-04 表达式把 clickContext 传入了真实函数） | 两轮均 `Idol of Ferocity` |

**验证门（全过才算完成）：**

1. `grep -c 'register("Cat O-' classes/druid/selftest.lua` → **16**（7 → +9）
2. 插入位置门：`grep -n 'register("Cat O-0[89]\|register("Cat O-1[0-6]' classes/druid/selftest.lua` 返回的 9 个行号全部 < `grep -n '^[[:space:]]*-- Category Q:' classes/druid/selftest.lua` 的行号且 > `grep -n 'Cat O-07' classes/druid/selftest.lua` 的行号
3. `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/selftest.lua classes/druid/Druid.lua` → **BALANCED**
4. 三解释器语法门（selftest.lua，命令同 Task 1 门 5 换文件名）→ 均 exit 0
5. diff 范围 Lua 5.0 令牌门（`git diff -U0 -- classes/druid/selftest.lua | grep '^+' | grep -v '^+++' | grep -c '#\|goto \|::'`）→ **0**
6. CRLF：`grep -c $'\r' classes/druid/selftest.lua` → **0**
7. 还原纪律目视门（人工核对，写进提交信息下方无改动）：九个注册体内六项 stub 的每次安装都有对应还原行；所有还原行先于第一个 assert；isInCombat 均走 rawset 往返；O-16 只有 5 项 stub（不动两个判定函数）
8. D-03 范围门：`git diff --name-only` → 恰 `classes/druid/selftest.lua` 一行；`git diff -U0 -- classes/druid/selftest.lua | grep '^@@'` → 全部 hunk 行号在 940-960 带与 2504 之后的增行带内

**提交（门 1-8 全绿后，只 add 一个文件）**：
message: `test(260916-utm): Cat O-08..O-16 builder selection pins (T1/sticky/battle-type)`

**不当场验证的口径**：九项 selftest 的运行时行为（/mt 全绿）本机无法执行（无 WoW 客户端），实机目视由用户 Windows+Cygwin 重建后完成（unrun-verify，SUMMARY 备案；本 quick 不碰 WINDOWS.md）。既有 O-01..O-07/P/Q 系列运行时行为不受影响（D-03 + 既有断言两级语义论证）。

## GATE 汇总（执行时统一口径）

- **commits**：恰 2 个代码 commit，消息逐字使用上述锁定文案；`git log -2 --format='%s'` 核对。
- **工作树**：`git status --porcelain` 最终仅剩 `.planning/quick/260916-utm-*/` 未跟踪目录与 SUMMARY（由 quick 流程收口），无其他漂移。
- **`git diff --check`**：两个 commit 均无输出。
- **Lua 5.0 三解释器 + bbcheck 双文件联合门**（Task 2 门 3/4 已含）。

## Threat Model

### Trust Boundaries

| Boundary | Description |
|----------|-------------|
| 运行时物品/战斗状态 API → 选择层 | `GetInventoryItemLink`（经 `getEquippedItemLink`）/ `UnitAffectingCombat` / 玩家背包查询在每次点击时读取的装备与战斗状态，可能在帧间变化（背包道具被换、进入/脱离战斗），由选择层按"每次点击读取 + 粘性只锁 builder 内互切"消化 |

选择层不接触网络/文件/外部字符串；两枚神像名与 'Cenarion' 为源码内字符串字面量，无注入面。

### STRIDE Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-utm-01 | Tampering | selftest stub 安装/还原（classes/druid/selftest.lua O-08..O-16） | medium | mitigate | CR-01 纪律：安装前快照、pcall 包裹、还原先于任何 assert、`isInCombat` 走 rawget/rawset 往返（nil 还原即删除自有键、accessor 复活）；Task 2 门 7 目视门强制九项逐一核对配对。残留 stub 只影响单次会话判定，reload 自愈 |
| T-utm-02 | Logic | `macroTorch.selectFerocityOrEmeraldRot` 三层优先级（T1→粘性→战斗类型） | high | mitigate | 判定顺序与表达式按锁定约束逐字实现；O-10 pin T1>粘性、O-11/O-12 pin 粘性双向外加"穿透即得对立结果"的否定性种子，O-13/O-14/O-15/O-16 pin 战斗类型映射与真实函数接线。爆炸半径限于 Builder↔Builder 二选一：执行层零改动（D-03 文件范围门），Savagery 路径与 recover 链完全不被波及 |

无 npm/pip/cargo 安装面，不设 SC 行。

## 输出

- 代码 commit ×2（Task 1 / Task 2，见上述锁定消息），bytes 范围见各任务门。
- 完成后由 quick 流程收口：`.planning/quick/260916-utm-catatk-builder-1-selectferocityoremerald/260916-utm-SUMMARY.md`（含 unrun-verify 备案与 gate 结果），STATE.md 表追加一行。