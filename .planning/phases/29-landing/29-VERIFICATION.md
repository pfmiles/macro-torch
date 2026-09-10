---
phase: 29-landing
verified: 2026-09-10T04:20:00Z
status: human_needed
score: 14/18 must-haves verified
behavior_unverified: 4
behavior_unverified_items:
  - decision: D-02
    truth: "同 cast 单条 land、同质量保留最早（cast 维去重谓词在运行时压制后到证据）"
    test: "游戏内 /mt 执行 Category Q；Q-12（apply 后 recordLandEvent 5.4 被拒）与 Q-15（普通入口被拒/豁免入口直推）必须全绿"
    expected: "landTable 顶值不覆盖、同 cast 单条 land；电脑侧已静态确认谓词存在（spell_trace_core.lua:325-329 / :412-414），本机无 lua 解释器未执行"
    why_human: "去重谓词是运行时状态转移（push 前的 return 分支）；grep 只能证明谓词在位与接线，不能证明夹具跑绿"
  - decision: D-03
    truth: "全窗口静默的 cast 在 ttl 到期后由 0.1s 周期任务推定 landed（蓝色 (inferred)）"
    test: "游戏内 /mt 执行 Q-11（无证据反推：landTable 顶 == cast 时刻、show 恰 1 次蓝色含 (inferred)）与 Q-09（周期任务断言）"
    expected: "反推以 cast 时刻为锚写入并发蓝色通告；反推永不与正推证据竞争"
    why_human: "computeLandTable 六步谓词链每次写入都是运行时行为；周期任务调度帧循环只存在于游戏进程"
  - decision: D-04
    truth: "存在 cast <= failTime <= cast + ttl 的 fail 即否决反推；窗外 fail 不否决"
    test: "游戏内 /mt 执行 Q-13（窗内 +0.5s 否决零通告零 land；窗前 -0.1s 推断照发）"
    expected: "two-phase 断言两阶段均绿"
    why_human: "否决判定是运行时状态转移；电脑侧只确认了静态谓词（spell_trace_core.lua:420 / :499-501）"
  - decision: D-06
    truth: "fail-wins 保留：同 cast 内窗口期 fail 即使后到仍撤销已推 land（revoke 语义不变）"
    test: "游戏内 /mt 执行 Q-05（fail 后到撤销 land 顶值）与 Q-06（fail 先到禁止迟到配对）"
    expected: "land 撤销 + intent state == 'failed'；红字取消行出现"
    why_human: "revoke 机器（removeMatch + 红字取消）零 diff 已静态确认，但撤销行为本身是运行时语义；本机无法执行"
human_verification:
  - test: "在用户 Windows+Cygwin 机执行 ./build.sh 重建 SM_EXTEND.lua（产物落盘后版控外生效），登录核查横幅 CONFIG_OPTIONS 仍为 4 项"
    expected: "重建无报错；SM_EXTEND.lua 为含 Phase 29 代码的新产物；横幅 4 项不变"
    why_human: "构建与产物加载只能在用户机（build 约定 + 本机禁止 build）"
  - test: "游戏内 /mt：Category Q 16 条（Q-01..Q-16）全绿、无红色 FAIL；非 Q 可选黄色 warning 可容忍"
    expected: "自检汇总行 0 failed；Q-01 统一 OR 注册断言、Q-02 0.9 窗配对、Q-09 周期任务、Q-11..Q-16 六组边界全部通过"
    why_human: "selftest 只能在 WoW 1.12 客户端内执行；本机无 lua 解释器与游戏客户端"
  - test: "单人木桩：catAtk 循环打骷髅约 1 分钟观察通告"
    expected: "Rake/Ferocious Bite 恒绿 landed；Pounce/Rip 绿色 landed 或偶发蓝色 (inferred) 均可；无 failed-on 红行；ripLeft 正常启动（不持续重放 Rip）"
    why_human: "落地通告、ripLeft 启动均为游戏内运行时行为"
  - test: "多猫同目标（远程网友零配置合作时选做）：我方 Rip 后观察兜底通告与 ripLeft"
    expected: "apply 行被抑制时 ~1 秒内出现蓝色 (inferred) 通告、ripLeft 启动且不再每帧重放 Rip；对方技能行不触发我方通告"
    why_human: "多猫 apply 抑制只能实机复现；本机无法模拟第二条客户端事件流"
  - test: "猎人角色：Serpent/Scorpid Sting 落地观察（含远程位）"
    expected: "落地仍可见（绿色配对或蓝色推断）；远程钉刺在 ~2 秒弹道窗内正常落地"
    why_human: "弹道飞行延迟是世界行为，仅游戏内可证"
---

# Phase 29: 统一 landing 判定重构 Verification Report

**Phase Goal:** 重构 landing 判定机制：去掉 `landSource` 参数，所有 `land = true` 注册技能统一采用三通道证据（self-hit / apply / fail）OR 语义 + cast 后 `intentTtl` 窗口静默到期反推兜底；cast 维度谓词去重（同 cast 单条、同质量保留最早）；fail-wins 保留；`intentTtl` 成为 register 可选参数（默认 0.9s，猎人钉刺 ~2s 覆盖弹道）；FB 续期 push 豁免去重。

**Verified:** 2026-09-10T04:20:00Z
**Status:** human_needed
**Re-verification:** No — initial verification（本目录此前无 VERIFICATION.md）

**要求面说明:** 本 phase 为 specless phase（phase_req_ids 为空）。验证以 29-CONTEXT.md D-01..D-18 为权威要求面（执行侧已确认其与 REQUIREMENTS.md R1-R8 命名空间不相交），辅以 DESIGN-CONTEXT.md 8 条锁定决策与三个 PLAN 的 must_haves truths/prohibitions。

## Goal Achievement

### 决策级目标回溯（D-01..D-18，file:line 证据）

| # | 决策 | 静态状态 | 证据（本机复跑或直接读源码） |
|---|------|---------|------------------------------|
| D-01 | 去掉 landSource/landSources、按自然属性在场 | ✓ VERIFIED | register 无来源字段（core/spell_trace_core.lua:65-95）；landSources 全源码仅剩 Q-01 阴性断言 1 处（classes/druid/selftest.lua:779，grep -c = 1）；onSelfDamageLine 只留 tracingSpells 门（:539-541）；残留扫描（8 目录、豁免阴性断言后）空输出 |
| D-02 | cast 维去重：同 cast 单条、同质量最早 | ✓ STATIC-PRESENT / HUMAN-NEEDED（运行时） | 谓词 `lastCast and lastLand and lastLand >= lastCast then return` 恰 1 处（:325-329），computeLandTable 复用 1 处（:412-414，grep count=2）；仅 lastCast 存在时生效；行为钉 Q-12/Q-15 已注册未执行 |
| D-03 | 反推兜底：静默窗到期推定 landed，锚=cast | ✓ STATIC-PRESENT / HUMAN-NEEDED（运行时） | maintainLandTables 双门守卫 + 模块级 `registerPeriodicTask('maintainLandTables', {interval = 0.1, ...})`（:366-374，按键恰 1 处，periodic.lua:127 键空闲无覆盖）；computeLandTable 谓词序 = no-cast → `blip <= ttl`（:407）→ 覆盖谓词（:413）→ 窗口 fail 否决（:420）→ `push(lastCast)`（:423）→ 蓝色 '(inferred)'（:427）；行为钉 Q-09/Q-11 已注册未执行 |
| D-04 | fail 否决窗口化 [cast, cast+ttl] | ✓ STATIC-PRESENT / HUMAN-NEEDED（运行时） | computeLandTable 否决 `lastFail[1] >= lastCast and (lastFail[1] - lastCast) <= ttl`（:419-421）；finalizeFail 窗口 `>=0 and <= intent.ttl`（:499-501，diff 确认负差容差块换为窗口化注释）；行为钉 Q-13 已注册未执行 |
| D-05 | intentTtl 一参三用 | ✓ VERIFIED | 三处窗口判定 + 播种 + 推断层全部读 per-spell ttl：播种 landIntentTtls[spell]（:137）、pair purge（:192）、pair 趟（:200）、finalizeFail（:501）、computeLandTable（:403）；`(intent.ttl or macroTorch.LAND_INTENT_TTL)` 恰 3 处 |
| D-06 | fail-wins 保留（后到 fail 撤销已推 land） | ✓ STATIC-PRESENT / HUMAN-NEEDED（运行时） | revoke 机器（removeMatch by landAt + 红字取消行）在 phase 29 diff 中零改动（git diff 4ee2315..HEAD 无 removeMatch/cancelled 行）；行为钉 Q-05/Q-06 已注册未执行 |
| D-07 | intent 播种携带 intent.ttl | ✓ VERIFIED | recordCastTable push 表含 `ttl = macroTorch.landIntentTtls[spell] or macroTorch.LAND_INTENT_TTL`（:136-137，grep 恰 1 处播种） |
| D-08 | FB 续期 push 豁免去重 + 前置条件保留 | ✓ VERIFIED | Druid FB 监听器两处改走 `recordLandEventRenewal('Rake'/'Rip', landTime)`（classes/druid/Druid.lua:856/:863，grep 恰 2）；普通 `macroTorch.recordLandEvent('` 在 Druid.lua 残留 0；isRakePresent/isRipPresent 前置条件原样（:850/:861） |
| D-09 | register 新可选参数 intentTtl | ✓ VERIFIED | config 字段注释含 intentTtl 行（:64）；`config.intentTtl or macroTorch.LAND_INTENT_TTL`（:69）；与 intent.ttl 播种字段同名 |
| D-10 | LAND_INTENT_TTL = 0.9、注释默认窗语义、cpDamage 跟随 | ✓ VERIFIED | `macroTorch.LAND_INTENT_TTL = 0.9` 恰 1 处定义（:17）+ 注释含 "default evidence window…cpDamage pairing keeps referencing"（:14-16）；全文件引用 10 处（9 代码 + 1 注释，门 ≥9）；cpDamage 五函数 diff 零改动（`git diff | grep -c pairCpDamageIntent...` = 0） |
| D-11 | 续期豁免独立函数 | ✓ VERIFIED | `function macroTorch.recordLandEventRenewal(spell, landTime)` 恰 1 处（:341-364），与 recordLandEvent 逐字同构唯独缺去重谓词；生产调用点仅 Druid FB 监听器 2 处 |
| D-12 | 猎人双钉刺 intentTtl = 2、猫德吃默认 | ✓ VERIFIED | Hunter.lua Serpent（:155-159）/Scorpid（:162-166）各一行 `intentTtl = 2`（grep 恰 2）；猫德 4 技能 register 无 ttl 字段（Druid.lua:808-830）；Q-01 断言 landIntentTtls 六项取值（钉刺 2/猫德 0.9）；弹道覆盖闸验 → 优 UAT 第 5 节（人验） |
| D-13 | (inferred) 后缀 | ✓ VERIFIED | `' (inferred)', 'blue'` 格式串恰 1 处（:427）；Q-11/Q-13 断言 string.find(capMsg,'(inferred)',1,true)；游戏内观感由单人木桩/多猫节观察 |
| D-14 | 蓝色通告 | ✓ VERIFIED | 'blue' 颜色参数（:427）；Q-11/Q-13 断言 capColor == 'blue' |
| D-15 | Q-01 重写为统一 OR 断言 | ✓ VERIFIED | 新测试名 + 断言全集（selftest.lua:778-818）：landSources==nil、六 tracingSpells true、LAND_INTENT_TTL==0.9、六项 ttl 取值、三 apply pattern 存在且 FF 缺席（`:816-817`）；Q-02 种植 castAt=1000.0（:838，greps 恰 1）；执行 → 人验 /mt |
| D-16 | 六组边界用例全落地（Category Q = 16） | ✓ VERIFIED（落地）/ 执行人验 | `SelfTest:register("Cat Q-` 恰 16 条（Q-01..Q-16，grep -c = 16）；Q-11~Q-16 六个新注册体逐读实质断言非 stub（Q-12 去重拒后到 / Q-14 双 ttl 边界 / Q-15 续期豁免 / Q-16 2s 窗收 1s 迟到 apply / Q-11 反推 / Q-13 否决双阶段），全部 CR-01 纪律；跑绿 → 人验 /mt |
| D-17 | cpDamage 零结构改动、窗随 0.9 自动生效 | ✓ VERIFIED | cpDamage 段落 diff 0 行（只改到常量自身注释）；pairCpDamageIntent 两个窗口读宏常量（:223/:234） |
| D-18 | 远程反推锚偏早接受、不引入 anchorBias | ✓ VERIFIED | 源码 `anchorBias` 零命中；HUMAN-UAT.md:269 注记行 1 处（greps 各恰 1）；"接受为最终形态"属记录义务——观察确认在单人木桩/钉刺节人验 |

**结论:** 18 条决策全部落地，静态证据 14 条完全充分（VERIFIED）、4 条（D-02/D-03/D-04/D-06）为运行时状态转移语义——机制在位且接线完好，但本机无 lua 解释器与游戏客户端，行为证明依赖用户机 /mt 与实机观察（HUMAN-NEEDED）。**无一 FAILED、无一缺失工件。**

### 三个 PLAN 的 must_haves truths 抽查结果

| Truth（摘） | 状态 | 证据 |
|-------------|------|------|
| land=true 技能不再按 per-spell 来源分派（统一 OR） | ✓ VERIFIED | D-01 行证据；processRawAuraApply 统一走 pair→announce→record（:445-475），onSelfDamageLine 统一走 pair→announce→record（:528-555） |
| register/播种/双窗读 intent.ttl | ✓ VERIFIED | :64/:69/:137/:192/:200/:501 |
| 常量 0.9 + 钉刺 2 | ✓ VERIFIED | :17；Hunter.lua grep = 2；Q-01 断言六项 |
| 同 cast 单条 + fail 窗内毁 land | ✓ STATIC-PRESENT / 人验 | 谓词 :325-329；revoke :502-516（zero-diff）；Q-05/Q-12 待人验 |
| Q-01 统一 OR 重写、Q-02 在 0.9 窗下 | ✓ VERIFIED（编写层）；人验（执行层） | selftest.lua:778-858 与计划规格逐点吻合 |
| 反推通告 (inferred) 蓝、锚 = cast | ✓ STATIC-PRESENT | :423-427；Q-11 断言（待人验执行） |
| blip<=ttl 直返 / 已覆盖不反推 | ✓ VERIFIED | :407/:413 |
| fail 窗内否决/窗外不否决 | ✓ STATIC-PRESENT | :420；Q-13 两阶段（待人验） |
| 双门守卫 + 0.1s unique key | ✓ VERIFIED | :367（tracingSpells 空集 + inCombat 双门）；:374（键恰 1 处、periodic.lua:127 无覆盖） |
| Q-09/Q-11/Q-13 三注册 | ✓ VERIFIED（编写层） | 名称/断言与 29-02 计划规格吻合 |
| D-16 六组全落地、Q 总数 16 | ✓ VERIFIED | grep -c 'SelfTest:register("Cat Q-' = 16；六新用例体实质 |
| cpDamage 零改动 + D-18 入档 | ✓ VERIFIED | diff 0；HUMAN-UAT.md:268-269 |
| HUMAN-UAT Phase 29 六节协议 | ✓ VERIFIED | 标题恰 1 处；六节含 Prerequisites/Pre-Test/单人木桩/多猫/钉刺/Troubleshooting；anchorBias 恰 1 处 |
| 无来源残留 / events+immune 零 diff / SM_Extend 字节一致 | ✓ VERIFIED | 残留扫描空；`git diff --exit-code -- events.lua spell_trace_immune.lua` 零输出；`git status --porcelain -- SM_Extend.lua` 空 |
| SM_Extend 全程字节等于 HEAD | ✓ VERIFIED | 同上；工作树整体 clean |

**Score:** 14/18（4 条 PRESENT_BEHAVIOR_UNVERIFIED — 机制在位、行为未在本地行使，见 behavior_unverified_items 与人验清单）

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| core/spell_trace_core.lua | 统一 OR 核 + 反推层 | ✓ VERIFIED | 666 行；register 新形态、landIntentTtls、去重谓词、recordLandEventRenewal、maintainLandTables/computeLandTable、周期注册全部在位 |
| classes/druid/Druid.lua | 注册点迁移 + FB 续期豁免 | ✓ VERIFIED | diff 仅 register 块与 FB 监听器行；无决策逻辑改动 |
| classes/hunter/Hunter.lua | 双钉刺 intentTtl=2 | ✓ VERIFIED | diff 仅两个 register 块（+13/-5 面） |
| classes/druid/selftest.lua | Category Q 16 条 | ✓ VERIFIED | 16 注册；六新用例体实质断言 |
| classes/druid/HUMAN-UAT.md | Phase 29 六节协议 | ✓ VERIFIED | :227-271 |
| 取整 todo 关闭：druid-rip-land-forensics-next-cd.md | 删除或 no-op | ✓ VERIFIED | 本 phase 跨度内已删除（`git diff 4ee2315..HEAD --summary`: delete mode 100644 .planning/todos/pending/druid-rip-land-forensics-next-cd.md）；29-03 执行时 find=0（no-op 记录自洽——文件在规划期 docs commit 已除） |

### Key Link Verification

| From | To | Via | Status | 证据 |
|------|----|-----|--------|------|
| SpellTrace:register | auraApplySpellPatterns 填充 | 自然属性驱动（immune+debuffTexture）+ pattern 元字符守卫 | ✓ WIRED | spell_trace_core.lua:70-81；落点集 Pounce/Rip/Rake + 双钉刺，FF 豁免（Q-01 :816 断言） |
| events.lua tier-2 | processRawAuraApply | `for spellName, pattern in pairs(macroTorch.auraApplySpellPatterns)` 遍历匹配 | ✓ WIRED | core/events.lua:156-164（零 diff，表填充触发条件变更后自动覆盖） |
| events.lua UNIT_SPELLCAST_SUCCEEDED | recordCastTable | tracingSpells 门 | ✓ WIRED | core/events.lua:165-168 |
| events.lua CHAT 通道 | onSelfDamageLine | 自伤行派发 | ✓ WIRED | core/events.lua:99-101 |
| recordCastTable 播种 ttl | pairLandIntent / finalizeFail 双窗 | intent.ttl（带常量兜底） | ✓ WIRED | :137 → :192/:200 → :501 |
| recordLandEventRenewal | Druid FB 监听器 | 豁免入口调用 x2 | ✓ WIRED | Druid.lua:856/:863 |
| computeLandTable false 周期 | registerPeriodicTask('maintainLandTables') | periodic.lua periodicTasks + 0.1s 帧循环 | ✓ WIRED | :374 → core/periodic.lua:110/:127；加载序 periodic(6) < spell_trace_core(21)，模块级注册行执行时函数已存在 |
| maintainLandTables 战斗门 | macroTorch.inCombat | combat_context onCombatEnter/Exit | ✓ WIRED | combat_context.lua:22/33 |
| landTable 消费侧（ripLeft/immune 路径2/cpDamage） | land 供给 | 既有消费代码 | ✓ WIRED | 消费侧零改动（变更面证明）；immune 路径 2 复活属附带行为（spell_trace_immune.lua 零 diff，人验观察点） |

### Data-Flow Trace（Level 4）

| 数据变量 | 来源 | 真实数据? | Status |
| -------- | ---- | --------- | ------ |
| landTable[spell][mob].top | recordLandEvent（正推：apply 配对 / self-hit）→ push(landTime) | 游戏事件时间 | ✓ FLOWING |
| landTable（反推） | computeLandTable → push(lastCast)（castTable 真实 GetTime） | 真实 cast 记录 | ✓ FLOWING |
| intent.ttl | recordCastTable 播种 ← landIntentTtls ← register config.intentTtl / 常量 0.9 | 注册静态配置 | ✓ FLOWING |
| fail 否决输入 | recordFailTable ← CheckDodgeParryBlockResist 5 类失败行 | 游戏失败事件 | ✓ FLOWING |
| 续期锚 | FB land 监听器 ← onLandEvent 派发 ← recordLandEvent('Ferocious Bite') | 真实 FB 落地时间 | ✓ FLOWING |
| cpDamage 配对窗 | pairCpDamageIntent 读 LAND_INTENT_TTL | 常量 0.9（D-17 自动跟随） | ✓ FLOWING（结构零改动） |

未发现任何 已接线变量终止于硬编码常量或 mock：夹具（Q-02..Q-16）用种植值属测试隔离范畴（CR-01），生产路径全部连真实事件流。Q-02 的 castTable 活钟种植值一事（IN-02）为夹具注释覆盖性夸大，不影响断言真值。

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| 四源码括号平衡 | `node .planning/phases/27-*/tools/bbcheck.js <4 files>` | 4/4 BALANCED | ✓ PASS（本机复跑） |
| trailing whitespace / 行尾 | `git diff --check`（工作树 clean 即空） | 空 | ✓ PASS |
| 来源注册残留 | `grep -rn 'landSource' core/ classes/ ... \| grep -v 'macroTorch.landSources == nil'` | 空输出 | ✓ PASS |
| VERIFICATION-ONLY 契约 | `git diff --exit-code -- core/events.lua core/spell_trace_immune.lua` | 无输出 | ✓ PASS |
| cpDamage 零改动 | `git diff HEAD -- core/spell_trace_core.lua \| grep -c pairCpDamageIntent...` | 0 | ✓ PASS |
| 令牌门 | grep -cn '#\|goto \|::' 4 文件 | 0/0/2/0（Druid 2 处为既有注释 '#' 字形，diff 证实 phase 29 未引入） | ✓ PASS（既有假阳性已入账） |
| /mt Q 序列 | `grep -c 'SelfTest:register("Cat Q-' selftest.lua` | 16 | ✓ PASS |
| selftest 执行（Q-01..Q-16 全绿） | 无 lua 解释器/游戏客户端 | N/A | ? SKIP → 人验 |

### Probe Execution

本 phase 无 project probes（无 `scripts/*/tests/probe-*.sh`）；PLAN/SUMMARY 亦无声明 probe 路径。机器侧门 = bbcheck + grep 电池（上面已复跑全绿）。— N/A

### Requirements Coverage

| 决策 | 来源 | 状态 | 证据 |
|------|------|------|------|
| D-01..D-18 | 29-CONTEXT.md | 14 VERIFIED + 4 HUMAN-NEEDED | 见上表 |
| DESIGN-CONTEXT 锁定 1 | 29 计划集 | ✓ 覆盖（D-01） | — |
| 锁定 2（去重） | — | ✓ 覆盖（D-02） | — |
| 锁定 3（反推） | — | ✓ 覆盖（D-03/D-13/D-14） | — |
| 锁定 4（fail 窗口） | — | ✓ 覆盖（D-04） | — |
| 锁定 5（intentTtl） | — | ✓ 覆盖（D-05/D-09/D-10/D-12） | — |
| 锁定 6（fail-wins） | — | ✓ 覆盖（D-06） | — |
| 锁定 7（FB 豁免） | — | ✓ 覆盖（D-08/D-11） | — |
| 锁定 8（intent 附带 ttl） | — | ✓ 覆盖（D-07） | — |
| ORPHANED requirements | — | 无 | REQUIREMENTS.md 无本 phase 映射（specless）；CONTEXT Deferred 三项明确 EXCLUDED |

### Anti-Patterns / Reviewer-Documented Warnings（29-REVIEW.md WR-01..WR-04）

本 phase 代码评审 0 critical / 4 warnings。按「评审警告不单独推翻锁定决策、只降低对应人验项置信度」的口径逐条记录如下（均已本机确认原文在位）：

| ID | File:Line | 内容 | 严重度 | 对人验的影响 |
|----|-----------|------|--------|-------------|
| WR-01 | core/spell_trace_core.lua:542-554 | self-hit 通道无条件先发绿通告、后进 recordLandEvent 去重——双通道技能（Rake/Pounce）可能出现同 cast 双绿通告（apply 配对先落 + self-hit 后播，第二次表写入被去重丢弃） | ⚠️ Warning | 单人木桩观察若见 Rake/Pounce 偶发双绿『landed』属已知观感残差，非判定失败；判定施放层（表内单条）仍正确。修复（让通告跟随去重结果）属后续改进 |
| WR-02 | core/spell_trace_core.lua:396-427 | computeLandTable 只有下界（blip <= ttl）无跨战斗/重目标 epoch 上界：旧 cast 在同名 mob 的后场战斗中可被误推（蓝通告一枚 + 陈旧锚）。ripLeft 钳 0 与 isRipPresent 卫护使决策面不受伤 | ⚠️ Warning | 实机若在开战后瞬间对同名 mob 看到一次陈旧蓝色 (inferred)，属已知限制；D-03 锁定形态（无 anchorBias 同类护栏）。修复（战斗退出清表或 blip 上界）属后续改进 |
| WR-03 | core/spell_trace_core.lua:214、:459 | 两处陈旧 "2s" 注释（"(2s, D-02)" 与 "(<=2s land offset)"）与实际 0.9 窗矛盾，违反锁定决策 5 的清洗条款（29-01 移交、29-02/29-03 未收口）。常量本身上方注释已更新（:14-16） | ⚠️ Warning | 不影响行为（D-17 锁定）；属文档债。建议下一快速任务将两处注释改为 0.9 语义 |
| WR-04 | classes/druid/HUMAN-UAT.md:266 | Troubleshooting 支路 (b) 描述「蓝色推断后紧跟红色取消」——实现的机器里该序列不可能产生（finalizeFail 只撤销 landed 配对 intent；反推 push 永不置 intent landed；反推后的 fail 必在窗外）。正确形态是绿色配对后跟红撤销 | ⚠️ Warning | 人验执行支路 (b) 时按正确预期观察：**绿色** landed 后紧跟红色『was cancelled by ...』= fail-wins 生效；蓝色 (inferred) 行永不被撤销。UAT 文档行文待修 |

IN-01（三个窗边精确相等点未钉）、IN-02（Q-02 注释覆盖性夸大）、IN-03（expired intent 暂留至 LRU 顶格）为 info 级，不降决策判定。

### 违反禁令检查（judgment-tier prohibitions，本机静态裁决）

| Prohibition | 本机证据 | 裁决 |
|-------------|---------|------|
| 不改 core/events.lua 与 core/spell_trace_immune.lua | `git diff --exit-code` 零输出 | 未违反 ✓（非权威 LLM-judge；human review recommended） |
| 不修改 cpDamage 五函数结构 | diff grep = 0 | 未违反 ✓（同 flag） |
| 不跑 build、不碰 SM_Extend.lua | `git status --porcelain -- SM_Extend.lua` 空；工作树 clean；复审无 build 侧提交 | 未违反 ✓（同 flag） |
| 不引入新 spell、不改 catAtk/hunterAtk 决策逻辑 | 两个职业文件 diff 仅 register 块与 FB 监听器行；无新 register 名 | 未违反 ✓（同 flag） |
| 29-03 不修改 core/ 任何文件 | 29-03 提交（9efc645/575db45）文件面 = selftest.lua + HUMAN-UAT.md | 未违反 ✓（同 flag） |

全部禁令在静态裁决层未检出违反；限于本机无运行时环境，对外部副作用（build 执行态）仅达「本仓库内零证据」强度，留人类复核位。

## Human Verification Required（汇入 29-UAT.md）

以下 5 项由 orchestrator 持久化为 29-UAT.md；操作指引均为既有协议 classes/druid/HUMAN-UAT.md Phase 29 节六节的可勾选条款。D-02/D-03/D-04/D-06 四条行为钉（Q-05/Q-06/Q-11/Q-12/Q-13/Q-15）随第 2 项 /mt 一并闭环。

1. **Windows+Cygwin 重建 SM_EXTEND.lua** — 执行 ./build.sh；要求重建无报错、产物落盘（协议 §1），登录横幅 CONFIG_OPTIONS 仍 4 项（§2）。
2. **游戏内 /mt 自检** — Category Q-01..Q-16 全部绿色、无红 FAIL；非 Q 黄色 warning 可容忍（协议 §2）。这是 4 条 HUMAN-NEEDED 决策的行为证明总入口。
3. **单人木桩通告行为** — catAtk 打骷髅约 1 分钟：Rake/FB 恒绿 landed；Pounce/Rip 绿 landed 或偶发蓝 (inferred)；无 failed-on 红行；ripLeft 启动不重放（协议 §3）。注意 WR-01：Rake/Pounce 偶发双绿通告属已知观感残差。
4. **多猫同目标（推断）兜底 + ripLeft 启动** — 选做：我方 Rip 后 ~1s 内蓝色 (inferred) 兜底通告、ripLeft 启动；对方技能行不触发我方通告（协议 §4）。注意 WR-02：开战后瞬间对同名 mob 的陈旧蓝通告属已知限制。
5. **猎人钉刺 2s 弹道窗** — Serpent/Scorpid 落地可见；远程位 ~2s 窗内正常落地（协议 §5）。fail-wins 观察按 WR-04 修正预期：绿色 landed 后跟红色取消（非蓝后红）。

## Gaps Summary

无 gaps_found：全部 18 条决策落地且静态证据完整，工件无缺失/无 stub/无断开接线；总体状态 human_needed 全部来自「本机无 lua 解释器与游戏客户端」这一环境事实（运行态只能由用户机 /mt 与实机观察闭环），以及 4 条运行时状态转移决策的行为未行使（PRESENT_BEHAVIOR_UNVERIFIED，已在 behavior_unverified_items 与人验清单中）。

额外 INFO（不影响判定）：STATE.md:26 的 Current Status 段仍写「2/3 plans … 29-03 待执行」——机器侧 frontmatter（current_plan: 3、stopped_at、64/64）已更新，人读段落滞后，属 docs commit 簿记小瑕疵。

---

_Verified: 2026-09-10T04:20:00Z_
_Verifier: Claude (gsd-verifier)_