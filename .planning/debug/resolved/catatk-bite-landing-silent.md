---
status: resolved
trigger: "目前的catAtk循环遇到一个问题需要排查：有一次，已经是在正常的木桩战斗过程中，已经开局了几十秒了，目标身上已经有了rake & rip，此时我打了个5星bite，屏幕上能看到白字输出的“Bite!!!... ooc: false”提示，但却没有看到蓝色的landing信息；然后随后是“Reshift!!!...”信息，且reshift信息中显示当前能量为0，也就是说明前面那个bite肯定是成功打出去了的，不然不会清空能量；但那个bite却没有对应的蓝色landing信息或红色fail信息出现，就静默地走掉了；然后接下来我的catAtk宏就判断rake & rip没有被bite续上，因此后来的5星又打了个rip，但此时其实目标身上的rip还在的(因为其实被bite续上了)。需要帮我排查下bite成功却没有landing信息的原因；我记得bite的landing，应该是全靠self-hit事件来确定的吧？因为它既没有apply debuff的效果，也没有fail反推兜底，那么这个问题就唯一可能会出现在释放之后的确定造成伤害的事件解析身上？我目前能想到的会不会是glance的伤害信息跟普通的伤害信息不一样，导致解析出错？"
created: 2026-09-11T05:37:48Z
updated: 2026-09-12T05:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

reasoning_checkpoint (Fix-1 landed 2026-09-11, user-adjudicated):
  hypothesis: "M1 CONFIRMED+fixed(code-proven): rescue 分支对推断锚点覆盖对(lastLand==lastCast)的补记制造幻影 cast+intent → 双腾账/双 Renewing;fix=isAnchorCoveredPair anchor-equality guard(rescue 分支命中即 return,不补记/不通告/不派遣)+Q-19 回归。M2 CONFIRMED-by-constraint(维持): 客户端 bars 通道迟滞冻结 CP/energy——用户对 FF!!! cp 值无 recall 补充,约束推断不变。M3 re-routed(用户裁决): 服务器 bite 确刷 rake+rip 且图标会重置 → '服务器不刷新 rake'路线作废;Renewing rake 缺席回归客户端侧 UnitDebuff 数据滞后/16 槽驱逐类环境解释;Fix-3b(删 FB listener 的 rake 续锚)作废,永不落地。CLOSED 2026-09-12: /mt 324 passed / 0 failed / 1 optional-warn(SP3 全局,与本案无关);实机两簇闭环(咬只续现存 debuff/补耙 A 蓝=兜底救账/补耙 B=客户端 debuff 数据通道迟滞);guard 终形经 code-review --fix 升级为 inferredAnchors 标记判别(a30f5fb)。"
  confirming_evidence:
    - "用户裁决(2026-09-11): bite 会刷新 rake 和 rip 两种 buff(服务器侧确定行为,不用怀疑),Rake 图标被咬刷新会重置 → M3 服务器路线消除,M3 完全回归客户端 debuff 数据问题"
    - "用户 /mt 全绿:Q-17/Q-18 与 Category T 均过(95cbb6e 修复的实机回归面干净)"
    - "Fix-1 静态电池 PASS:bbcheck 括号平衡(BALANCED ×2)、git diff --check 干净(LF)、Lua5.0 token 门(无 goto/无 # 长度/无 label);Q-17 静态推演不受影响(fixture 为严格不等真实证据对,不触发 equality guard);Q-18/Q-07/Q-12/Q-15 判定路径 untouched"
    - "Q-19 fixture 复现 M1 最小交叠:推断锚点(lastLand==lastCast)+迟到自伤行 → 断言零通告/零补记/零续锚重写;hasBuff 桩 true 使 listener 若被派遣必留迹"
  falsification_test: "Fix-1 实机判据:下次木桩若双腾账/双 Renewing 再现,或 Q-19 于 /mt 红,则 M1 修复无效(回调查);若 'Renewing rake 缺席'仍发生且 Rake 图标在场,则 M3 客户端 UnitDebuff 数据滞后/16 槽驱逐路线坐实(Fix-3b 作废与此自洽,勿重提删锚)"
  fix_rationale: "anchor-equality guard 只截获 lastLand==lastCast(推断锚点/救援补记对签名);real-evidence 对 lastLand-lastCast>0 天然绕过,真实 F1 竞态(上发严格不等对)仍走原 rescue 补记(Q-17 继续绿)。Fix-3b 作废依据:服务器确刷 rake,FB listener 的 rake 续锚记账非钟表谎言。M2 无宏侧修复(读活 bars 是设计),宏侧 CP 台账交叉校验涉及 29/30 锁定判定语义,不落地"
  blind_spots: "①rescue 幻影对 [stamp,land] 亦 exact-eq:若后续 cast 的记录桥同样迟到,其首条证据会被 guard 压制 → 该 cast 收敛到 0.9s 推断蓝(记账不丢,通告降级蓝)——已推演可接受;②M2 冻结 ~5s 但无整体卡顿(chat/bars 通道分流);③Fix-2(DIAG 插桩)评估后决定不捆绑(单变量归因纪律+下次清单全程可肉眼观察),保留为后续项"
  candidate_causes:
    - "[code fix-introduced] M1: rescue 与推断锚点的叠交互(已修: anchor-equality guard + Q-19)"
    - "[environment] M2: 客户端 bars 通道迟滞(维持约束推断,待下次实机观察冻结是否再现)"
    - "[environment] M3(原形态作废 2026-09-12:用户澄清咬只续现存 debuff 不新增,单 Renewing rip=rake 真到期正常机制): 残余待判=补耙 B 判门归因——白 Rake!!! 打印自带 'Rake present:' 字段,false→客户端图标(hasBuff)滞后坐实 / true→keepRake 判定树分支问题立案回查"
  and_gate: "yes — 原始观察簇 = M1×M2 同时成立;M3 原形态经用户澄清作废(单 Renewing 回归机制正常面)。M1 已修;M2 留实机观察;M3 残余转判门归因"

bug_class: Bohrbug(M1, fixed, verified) ; M2(客户端通道迟滞,环境,维持约束推断,未再现) ; M3(原形态作废)
hypothesis: 全部纳案:M1 修复经用户 324/0/1 实机验收封板;补耙簇闭环(咬只续现存+兜底救账+数据通道迟滞,无缺陷);无残余待修项
test: 静态电池 PASS 已跑;游戏内 /mt 2026-09-12: 324 passed / 0 failed / 1 warning(SP3 optional global not found——SuperMacro 全局可选探测,与本案无关);Q-17/18/19 与 Category T 在 324 全绿之列
expecting: 已兑现:双腾账/双 Renewing 未再现;无静默咬;两簇补耙同签名闭环
next_action: 归档:本会话转 .planning/debug/resolved/（human 验收 324/0/1 + 两簇实机闭环）——结案,无后续动作

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: 5 星 Bite 成功打出后应出现蓝色 landing 通告（不符时红色 fail 通告）；该次 bite 落地后 rake & rip 的续期应被宏记录，不重放 rip。
actual: 白字 “Bite!!!... ooc: false” 可见、随后 “Reshift!!!...” 显示能量 0；无蓝色 landing、无红色 fail，该次 bite 通告整体静默；宏随后判断 rake & rip 未被续期，用后来的 5 星重打 rip（目标身上 rip 实际已被该次 bite 续上、仍存活）。
errors: 无任何报错或红字（静默）。
reproduction: 正常木桩战斗开局几十秒后、目标已有 rake+rip 时打 5 星 bite；偶发（其余 bite 均正常出蓝 landing）。实机构建 = Phase 29 Wave 1-3 构建（29-04 修复之前、色相仍倒置；色相倒置与本问题无关——本问题为通告整体缺失）。
started: 2026-09-11 前后实机观察（实机验证受每周 CD 限制）。
user_observed (AskUserQuestion 2026-09-11): ① 非 debug 模式 addon 不回显原始事件行、也不打印 miss/dodge 原始信息——用户只能观测到“无蓝 landing 且无红 fail”；② Bite 前后流畅、无卡顿；③ macroTorch.log 落盘（SuperMacro.lua, maxSize 500）非默认行为，需主动插桩输出才可取证，SuperMacro.lua 可拷回。

## Investigation Constraints
<!-- Hard constraints — do not violate -->

- 实机验证排期：本案为木桩复现，无每周副本 CD 限制——用户下次上线打桩即可取证（与 29-04 rebuild 同车）；静态路径（bbcheck / grep 电池 / 语义推理）仍须自足，实机项固化为极简取证 todo。
- 修复不得退化 Phase 29 已锁定判定语义（D-02 去重压制 / D-03 反推兜底 / D-04 fail 否决窗 / D-06 fail-wins 撤销 / ripLeft 所有权鉴权）。
- Lua 5.0（禁 # 长度/goto）、LF 行尾；SM_EXTEND.lua 是构建产物不入库。
- 若需取证插桩：纯新增、不改判定逻辑、一次性输出、macroTorch.log 落盘（沿用旧案 RAWDIAG 模式）。

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: bite 产生 glance（偏斜）导致伤害行格式不同、解析失败
  evidence: 1.12 引擎偏斜只作用于白字自动攻击且仅对高于自身 3 级目标；Bite 是黄字终结技，机制上不可能 glance
  timestamp: 2026-09-11T05:37:48Z
- hypothesis: 机器卡顿/冻结使 bite 意图在 2s 过期门（pending→expired）内未被 self-hit 事件配对
  evidence: 用户 2026-09-11 确认该次 bite 前后流畅无卡顿
  timestamp: 2026-09-11T05:37:48Z
- hypothesis: 步骤 9 绿 landed 属于第二个实体 bite（bite_C 真实命中）
  evidence: 能量守恒排除——bite_B 实体施放后真实能量 12,1.05s 后至多 ≈22,<35 不可能被服务器接受第二发;且 95cbb6e 的互补推演给出同假说同款双土地账输出(幻影 cast 补记 + 二次绿 + 二次 Renewing),Occam 取单实体
  timestamp: 2026-09-11T08:30:00Z
- hypothesis: 两次白字判定是 4.5s 窗口内积攒星到 5 的合法重判（bite_0 消耗后经 FF+claw×N 重建）
  evidence: 几何排除——FF(1星)+多发 claw 需 140+ 总能量,而窗口内可用能量(2→47≈45+复原)最多支撑 1 发 claw(35e),CP 至多 2 < 3/5;且同值 47 双印要求两个判定帧读同一冻结值,合法重建路径下能量条会正常行走
  timestamp: 2026-09-11T08:30:00Z
- hypothesis: "咬后续期 rake 缺失 = 客户端 UnitDebuff 数据滞后"（M3 原形态，包括对 2026-09-11 旧簇与 2026-09-12 新簇的该解释）
  evidence: 用户 2026-09-12 澄清游戏机制：咬只能刷新目标身上已存在的 rake/rip，不能凭空新增。咬时 rake 已经自然到期（9s 上限）→ 单 Renewing rip 是"只续现存"的应然输出，属正常机制；咬后补耙亦为正常决策。据此两簇的"只续 rip"都有了朴素解释，客户端滞后解释失据
  timestamp: 2026-09-12
- hypothesis: M3 服务器路线——服务器 bite 命中不刷新 Rake（仅 Rip），宏的 FB-rake 续期记账是钟表谎言，rake 真实 9s 到期恰好落进簇窗（旧案仅实锤 rip 刷新）
  evidence: 用户 2026-09-11 裁决澄清：bite 会刷新 rake 和 rip 两种 buff（服务器侧确定行为，不用怀疑），Rake 图标被咬刷新会重置——Renewing rake 缺席不是服务器机制，而是客户端侧 UnitDebuff 数据滞后/16 槽驱逐类环境问题；Fix-3b（删 rake 续锚）随之作废
  timestamp: 2026-09-11T10:00:00Z

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-09-11T08:30:00Z
  checked: Follow-up field-test cluster (12min dummy, fix 95cbb6e live) — full code trace of the bite decision chain, landing accounting stack, and renewal listener against the user's 11-step transcript
  found: ① 白字打印 cat.lua:447 在 ferocious_bite('ready') 之后无条件执行(成功与否都印),且 _castSpell 对游戏侧拒绝无感知(Player.lua:82-84 无条件 return true)——打印≠真实施放;② 所有 bite 打印路径 cp5Bite(cat.lua:118-156, CP==5)、quickKeepRip(cat.lua:341, CP>=3 且非 rip present)都传 clickContext.comboPoints,唯一写入点是 combo.lua:91 = player.comboPoints = 活读 GetComboPoints()(Druid.lua:544-546),mana = 活读 UnitMana(entity/Unit.lua:114-116)——从未有 memoized energy/CP 字段;③ 两次打印同值 47 + bite_B 实体(推断有 cast 记录)要求 4.5s 回复窗口内 CP/energy bar 冻结(通道被洪流推迟),而第二实体 bite 违反能量守恒(1.05s 后真实能量 22<35);④ M1 盲区实证:isStaleCoveredPair(325-335) 对'covered = lastLand == lastCast'(推断锚点,computeLandTable:470-478 recordLandEvent(spell,lastCast)) 与'covered = 上发内部对'(F1 设计目标)不可区分——迟到 >0.9s 且 covered 一律 rescue(608-620),对已推断 cast 的迟到行制造幻影 cast+intent(recordCastTable 97-138 会 push intent)+二次绿+二次 listener;⑤ FB listener(Druid.lua:952-968)rake 臂被 isRakePresent=hasBuff AND rakeLeft>0(Druid.lua:1359-1365)双钥;bite_0 续锚后 rakeLeft≈4.5>0 → Renewing rake 缺席必是 hasBuff(Rake) 假,两次采样差 200ms 皆假而 rip 皆真 → Rake 客户端真实缺席;⑥ 旧案只实锤 FB 刷新 rip(未实锤 rake);服务器若仅在 bite 时刷新 rip 而 rake 真实 9s 到期(最后真实 Rake cast ≈ 簇前 9s),则以 '补 rake' 由 keepRake 的 hasBuff 臂挽回——与用户'恢复正常:补 rake'吻合;⑦ FF!!! 打印(Druid.lua:1512-1516)含 'cp: X' 与 'at energy: X' 字段,可作回忆判别器
  implication: M1(修复引入的双土地账交互,code-proven,需修:anchor-equality guard+Q-19)/M2(既有:客户端 bars 通道迟滞引发 CP 冻结→双 bite 判定,环境放大器;无宏侧免修,可选台账校验为设计裁决项)/M3(既有:rake 的 FB 续期记账为钟表谎言 un 此服务器不刷 rake,待实机确证)

- timestamp: 2026-09-11T06:40:00Z
  checked: Phase 29 静默四臂全链审计 (spell_trace_core / events / periodic / cat.lua / combo.lua / Unit.lua + 样本实证)
  found: ① 表现层:onSelfDamageLine 绿通告与 recordLandEvent 写入均受 isCastCovered(D-02) 与 isCanAttack 门控;isCanAttack=UnitExists+UnitCanAttack 活计算,桩战恒真(排除);② 样本实证:英文客户端 bite/rake/rip 各事件族 0xF GUID 行格式与全部解析正则吻合(miss 行零样本);p1.txt(用户实机 9/9)证实事件洪流下 SELF_DAMAGE 行照常到达;③ cast 记录双桥:UNIT_CASTEVENT 布局(arg1=casterGUID,arg3='CAST')正确并消费 _pendingCastSpellName,UNIT_SPELLCAST_SUCCEEDED 兜底;④ 决定性机制：recordCastTable 里 castTable 与 intent 在事件桥落表后才存在——猫德 GCD 技能(bite)为瞬发框架下 cast 记录(CASTEVENT 桥)与战斗日志 hit 行在客户端队列到达序可反转;此时 isCastCovered(peekCastEvent 返回上一发 cast)把上一发 [cast,land] 覆盖对误判为"本行已覆盖";⑤ 反推兜底 computeLandTable 直接 push landTable、绕过 landListeners 派遣(FB 续期 listener 永不触发);⑥ 消费点审计:peekCastEvent/castTable 全部消费者均在 land 框架内(recordFailTable lag 展示 / isCastCovered / computeLandTable),补记爆炸半径安全;⑦ 调度器 periodic.inCombat 均正常(排除兜底不运行的路线)
  implication: F1(竞态触发,rare):stale 覆盖 → 通告+写入+续期记账三失;F2(系统性):兜底不派遣 listener → 即使兜底触发续期记账也丢失。两者共同解释"bite 静默 + 误判未续期重放 rip"全症状链;实机 29-04 前构建的兜底线色相倒置解释了"看不见蓝线"

- timestamp: 2026-09-11T05:37:48Z
  checked: Prior Art — 旧案 .planning/debug/catatk-premature-rip-recast.md（status: resolved，2026-08-28）
  found: 同一 bug 家族旧案沉淀的取证底料：① 客户端为英文，RAW_COMBATLOG 布局 = arg1 CHAT_MSG_* 通道名 + arg2 带 GUID 原始文本；② Rip/Rake（直伤+apply）与 Bite（纯直伤）事件族：apply 行“is afflicted by Rip”走 CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE、fail 行“Your Ferocious Bite was dodged by”走 CHAT_MSG_SPELL_SELF_DAMAGE、tick 走 periodic self damage、自然到期“fades from”= AURA_GONE_OTHER、无显式 refresh 事件；③ 服务器端 bite 命中持续刷新 rip 已实锤（刷新后时长≈新鲜时长，tick 活性可作所有权）；④ 同施法者 refresh 时服务器跳过 apply 行；⑤ 旧机制 land 轮询窗口是机器性能敏感的，Phase 29 已整体替换为事件驱动（cast 桥 + 意图状态机 2s 过期 + landSource 枚举：self-hit 默认 / aura-apply；FB hits/crits 事件即续期、无 CP 条件）
  implication: 本次新案 = 新架构下 bite 通告整体静默。Bite 无 apply debuff、其 landed 证据全靠 self-hit 行判定的描述与 Phase 29 D-14 设计一致；核查点集中在 self-hit 行匹配/pairing 与 fail 通告两臂的输出环节

- timestamp: 2026-09-11T05:37:48Z
  checked: 本次实案环境事实（用户 AskUserQuestion 回复 + 前置机制澄清）
  found: 能量归零只能证明施放动作发生（1.12 终结技 miss 同样消耗能量），该次 bite 有 hit/miss 两种可能路径；macroTorch.log 落盘非默认、取证需主动插桩；用户游戏机可拷回 SuperMacro.lua
  implication: 静态排查必须同时覆盖 hit-arm（self-hit 匹配→landed 通告）与 fail-arm（miss/dodge/parry 事件→红 fail 通告）两条路径的静默可能；实机取证依赖插桩版构建产出

- timestamp: 2026-09-12
  checked: 簇再现（用户带时间戳全转录）：bite 绿 landing 2853.608 → Renewing rip → 咖啡 Reshift(nextMove: Rake) → 白 Rake!!! (present: false, 补耙 A) → 玫红 FF!!! cp: 1 → 蓝 Rake (Inferred) 2855.854 → 白 Rake!!! (present: false, 补耙 B) → 绿 Rake landing 2858.458 → 此后正常
  found: ① 时间戳推演：A 施放≈2854.95（蓝行=施放+0.9s 反推），B 落地 2858.458（A→B 间隔≈3.3s，35e 能量回填可行）；② **cp: 1 铁证**：咬已吃光星，FF 打印的 cp: 1 只能来自耙 A → A 真命中，不是 miss（miss 无星）→ 蓝行推断与真实一致，账无误；③ A 的双证据通道（自伤行+新挂流血的 apply 行）在 0.9s 窗内双双未到 → 通道迟滞；若 1~2s 后才到，自伤行会被标记判别（Q-19）静默吞掉、apply 行被过期意图丢弃——两者皆是设计静默，故转录里不见绿；④ B 决策时打印 present: false——rakeLeft 时钟已被 A 的蓝字兜底刷新（应为≈5.6s>0），故 false 即 hasBuff（客户端 UnitDebuff）仍读不到 ≈3.4s 前已命中的耙 → 客户端 debuff 数据通道滞后（与 M2 状态条冻结同族的环境延迟）；B 落地绿后一切跟上 → 自愈；⑤ 小涟漪：B 落地前 rakeLeft 以 A 施放时刻为锚，若 B 迟迟不落地时钟会早报到期——本次 B 立即绿已自愈，非缺陷
  implication: 该簇形态（咬后单 Renewing=真到期 + 补耙 A 蓝 + 补耙 B present:false）第一次带时间戳+cp 字段完整闭环：全程无判定逻辑缺陷、无账错、无双报；纯环境型（证据通道迟滞被兜底救账 + debuff 数据通道滞后致一发 35e 冗余耙）。是否做"蓝字兜底后宽限"优化仍为可选设计项

- timestamp: 2026-09-12
  checked: 新实机簇（用户打桩报告，构建=WR-02 标记判别 + violet→pink 重命名后）：Bite 白字→绿 bite landing→仅一行 Renewing rip（无 Renewing rake）→咖啡 Reshift(nextMove: Rake)→两行白 Rake!!!（补耙 A）→蓝 Rake (Inferred)→又一行白 Rake!!!（补耙 B）→绿 Rake landing→此后正常
  found: ① 用户纠偏前提（同 09-12）：咬只刷新现存 debuff 不新增——咬时 rake 已自然到期（9s 上限），单 Renewing rip 与咬后补耙均为正常机制，非回归非滞后；② 补耙 A 蓝字=新耙双证据通道（自伤行+新挂流血必发的 apply 行）在 0.9s 窗内双双静默→沉默窗反推兜底照设计接住（候选=咬/换形/续期洪流的通道迟滞，与 M2 状态条冻结同族的环境延迟；代价仅 rakeLeft 时钟以施放时刻为锚，误差<1s 无害）；③ 补耙 B=待判题：Rake 判定门为双钥匙（客户端图标 UnitDebuff + 自维护 rakeLeft 时钟）；A 的蓝字兜底已把 landTable 顶刷新→rakeLeft 应为正值→B 成立多半因客户端图标数据滞后，但白 Rake!!! 打印自带 'Rake present:' 字段，下次一行即可钉死（false→图标滞后坐实；true→keepRake 判定树其它分支问题，立案回查）；④ 绿行前有新鲜白字施放打印→蓝绿为两发真耙，WR-02 标记判别无回归迹象；⑤ 时间戳值未转述（判别 todo 已固化 .planning/todos/pending/rake-lag-vs-regression-discriminators.md）
  implication: 咬后续期行为无异常（机制澄清后）；真正残余=补耙 B 的判门归因，证据入口已内置（Rake present 字段），无需插桩；"咬后客户端滞后"（M3 原形态）作废，连同旧簇"只续 rip"一起回归朴素解释区

- timestamp: 2026-09-11T10:00:00Z
  checked: 用户 human-verify 裁决（2026-09-11）与 Fix-1 落地执行
  found: ① 批准 Fix-1（rescue 分支 anchor-equality guard + Q-19 回归自测），并纠正 bite 会刷新 rake 与 rip 两种 buff（服务器侧确定行为）、Rake 图标被咬刷新会重置；② /mt 全绿：Q-17/Q-18 与 Category T 均过；③ FF!!! 行 cp 值无 recall → M2 维持约束推断（无新实锤）；④ Fix-3b（删 rake 续锚）作废不落地；⑤ Fix-2（DIAG 插桩）捆绑裁决：不捆绑——下次实机清单全程可肉眼观察（双腾账是否消失/状态条冻结是否再现/Rake 图标与 Renewing rake 缺席场景），插桩会引入第二变量破坏 Fix-1 实机归因；macroTorch.log 取证为既有惯例，需要时以独立 quick 立项随 rebuild 交付
  implication: M1 已修+已提交（anchor-equality guard + Q-19）；M2/M3 无线索升级，靠下次木桩实机观察确认；Fix-2 保留为后续项，触发条件=下次实机观察出现不可归因歧义

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: AND-gate 双因子（原始静默案）。F1（触发，rare）：Ferocious Bite 的自伤证据行（CHAT_MSG_SPELL_SELF_DAMAGE）先于 cast 记录（UNIT_CASTEVENT 桥/UNIT_SPELLCAST_SUCCEEDED）落表到达——客户端事件洪流下两条通道的到达序可反转——此时 D-02 cast 维覆盖谓词 isCastCovered 用全局栈顶把上一发 bite 的 [cast,land] 覆盖对误判为"本行已覆盖"：绿 landed 通告被压制（onSelfDamageLine 门控）+ land 写入被 recordLandEvent 去重压制 → Ferocious Bite land listener 不触发 → rake/rip 续期记账丢失 → 术左 ripLeft 后驱 0 → isRipPresent 误判 false → 换 Savagery + 提前重放 Rip。F2（系统性）：D-03 反推兜底 computeLandTable 直接 push landTable、绕过 landListeners 派遣——即使兜底触发，FB 续期 listener 也不会执行、续期记账依然丢失，且反推兜底在 29-04 前构建上的通告'blue'→OFFICER 渲染为绿色，与用户"无蓝无红"观察自洽（用户三无观察的兜底绿线可见性即此解释）。bite 命中机制本身无异常（glance 不可能、事件行格式与全样本吻合、isCanAttack 话计算恒真均已排除）。95cbb6e 修复后的实机新簇：M1（fix-introduced，code-proven = 95cbb6e 的 isStaleCoveredPair rescue 与推断锚点交叠）：bite_B 自伤行迟到 >0.9s → 推断锚点（lastLand==lastCast）先行覆盖本 cast → 迟到行被误判'未落表新 cast 首条证据' → recordCastTable 补记幻影 cast+intent → 二次绿 landed + 二次 listener 派遣（双腾账/双 Renewing）。M2（环境，维持约束推断）：客户端 CP/能量 bar 更新在洪流下冻结 ~5-6s → cp5Bite 双白字同值、第二发被服务器以真实能量拒。M3（环境，用户裁决后）：Renewing rake 缺席 = 客户端 UnitDebuff 数据滞后/16 槽驱逐类问题（服务器 bite 确刷 rake+rip、Rake 图标会重置）。
fix: ①（95cbb6e）isStaleCoveredPair 陈旧覆盖判别 + rescue 补记 cast 时间戳（恢复 cast<=land 不变量）+ computeLandTable 兜底改走 recordLandEvent（恢复 listener 派遣）+ Q-17/Q-18；②（Fix-1，本次）onSelfDamageLine rescue 分支新增 isAnchorCoveredPair（lastLand==lastCast）anchor-equality guard——命中即 return，不补记/不通告/不派遣；新增 Q-19 回归（推断锚点 + 迟到自伤行交叠最小 repro）。Fix-3b（删 FB listener 的 rake 续锚）经用户裁决作废、永不落地。Fix-2（一次性 DIAG 插桩）决定不捆绑，保留为后续项。③（2026-09-12 code-review --fix）anchor-equality guard 经复核升级为 inferredAnchors 显式标记判别（a30f5fb）：数值等值无法区分推断锚与救援同帧产物，标记化后重复 F1 竞态回归完整救援路径（不补记/不通告/不派遣仅对真推断锚生效）；Q-19 改种标记。最终形态：95cbb6e → 881594c → a30f5fb。
verification:
  target_test: { result: passed_in_game, evidence: 2026-09-12 /mt = 324 passed / 0 failed / 1 warning（SP3 optional global not found——可选项探测，与本案无关）; Q-17/Q-18/Q-19 与 Category T 在通过清单内；伴随实机还完成两簇补耙复验（同签名闭环，无缺陷） }
  mutation_check: { result: skipped, reason: 无 Stryker/无头 Lua 运行时可驱动游戏内测试（既有惯例，95cbb6e 同） }
  no_op_deletion: { result: pass, diff 为纯增补：isAnchorCoveredPair 新函数 + rescue 分支 guard-早退 + Q-19 注册；早退（deletion-shaped）有 RCA 明确论证（M1 幻影补记链路，见 reasoning_checkpoint fix_rationale） }
  adjacent_tests: { result: skipped_static_ok, reason: Q-01..Q-18 须游戏内执行；静态兼容推演已逐条过（Q-17 fixture 为严格不等真实证据对、不触发 equality guard；Q-07/Q-12/Q-15/Q-18 判定路径 untouched）；bbcheck BALANCED ×2 }
  revert_and_reconfirm: { result: skipped, reason: bug 为实机竞态、无法在本机复现/回放（无客户端、无录制）；回购验证绑定用户木桩——2026-09-12 两轮打桩无静默咬/无双腾账，视为确认 }
  guardrail_verdict: passed_human_verify
files_changed: [core/spell_trace_core.lua, classes/druid/selftest.lua]