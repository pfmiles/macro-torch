---
status: awaiting_human_verify
trigger: "目前的catAtk循环遇到一个问题需要排查：有一次，已经是在正常的木桩战斗过程中，已经开局了几十秒了，目标身上已经有了rake & rip，此时我打了个5星bite，屏幕上能看到白字输出的“Bite!!!... ooc: false”提示，但却没有看到蓝色的landing信息；然后随后是“Reshift!!!...”信息，且reshift信息中显示当前能量为0，也就是说明前面那个bite肯定是成功打出去了的，不然不会清空能量；但那个bite却没有对应的蓝色landing信息或红色fail信息出现，就静默地走掉了；然后接下来我的catAtk宏就判断rake & rip没有被bite续上，因此后来的5星又打了个rip，但此时其实目标身上的rip还在的(因为其实被bite续上了)。需要帮我排查下bite成功却没有landing信息的原因；我记得bite的landing，应该是全靠self-hit事件来确定的吧？因为它既没有apply debuff的效果，也没有fail反推兜底，那么这个问题就唯一可能会出现在释放之后的确定造成伤害的事件解析身上？我目前能想到的会不会是glance的伤害信息跟普通的伤害信息不一样，导致解析出错？"
created: 2026-09-11T05:37:48Z
updated: 2026-09-11T07:10:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

reasoning_checkpoint:
  hypothesis: "F1: bite 自伤证据行先于 cast 记录到达时,D-02 谓词把上一发 [cast,land] 的覆盖误判为本行已覆盖,压制通告与写入;F2: D-03 兜底写入绕过 listener 派遣。二者 AND 后 bite 静默+续期记账丢失 → 误判重放 rip"
  confirming_evidence:
    - "onSelfDamageLine/recordLandEvent 的通告与写入均被 isCastCovered 门控,D-02 谓词用全局栈顶(peekCastEvent/peekLandEvent)计算"
    - "双方桥(CASTEVENT@pending / SUCCEEDED@arg2)与战斗日志行存在同一服务器 tick 的到达序竞态,猫德 bite 是瞬发框架下 GCD 技能,p1.txt 证实用户客户端事件洪流常态"
    - "computeLandTable 对 landTable 直接 push、无 landListeners 派遣(FB 续期 listener 是 onLandEvent 注册的唯一消费者)"
    - "样本行格式与全解析正则吻合,glance 不可能(旧案已排除),isCanAttack 活计算恒真——其余静默路径均被排除"
  falsification_test: "若修后实机仍出现'无绿 landed 且无蓝 (inferred) 且无红 fail'的三无 bite,或 Q-17/Q-18 无法在游戏内通过,则本假设错误,需回到桥记录丢失/兜底不运行的路线"
  fix_rationale: "恢复『cast<=land 不变量』:陈旧覆盖时先补记 cast 时间戳,原门控自然放行(地址级修复竞态根因而非堵通告);兜底改走 recordLandEvent 恢复续期记账(D-03 语义不变,仅写入口统一)"
  blind_spots: "未实锤的残余:①UNIT_CASTEVENT 'CAST' 的精确触发时刻(起点/落点);②竞态触发时用户绿 '(inferred)' 兜底线的可见性(29-04 前色相倒置,观测降级);③miss 行的 vanilla 措辞零样本(missed vs misses)"
  candidate_causes:
    - "code: D-02 谓词无时间维度,stale 覆盖与真重复覆盖不可区分(F1)"
    - "code: 兜底写入口绕过 listener 派遣(F2)"
    - "environment: 事件队列在客户端洪流+帧尖峰下的到达序反转(触发器,code 缺陷的放大器)"
  and_gate: "yes — 全症状链需要 F1(竞态压制自伤证据)与 F2(兜底无法补记账)同时存在:仅 F1 而无 F2,兜底 ground 出 land(虽不记账)会出 (inferred) 线;仅 F2 而无 F1,正常 bites 的直通路径都会派遣 listener。二者皆在代码中经证实"

bug_class: Heisenbug（事件到达序竞态,诱因为客户端事件洪流下的队列反转;系统缺陷 F2 为 Bohrbug 成分）
hypothesis: CONFIRMED — 修复实施中(spell_trace_core.lua 三处 + selftest Q-17/Q-18)
test: static-gates 待跑(bbcheck + git diff --check),Q-17/Q-18 语义推演已过
expecting: Q-17 stale-coverage 修复路径/Q-18 兜底派遣路径,既有 Q-07/Q-12/Q-13 全绿
next_action: "待用户实机（用户 2026-09-11 批准上线试测，保持 ttl 窗口）：① push 仓库（用户推或 Claude 代推）② Cygwin build.sh 重建（同车含 29-04 色相修复）③ 游戏内 /mt：Category Q 全绿（新增 Q-17/Q-18 两绿）④ 木桩 10-15min：所有 bite 出绿 landed（新构建绿=真实绿）、Renewing rake/rip 随 bite 出现、不再有'三无'咬；若复发记录当时是否出现绿 (inferred) 行 → 简报后 /gsd-debug continue catatk-bite-landing-silent（'confirmed fixed' / '仍失败'+现象）"

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

## Evidence
<!-- APPEND only - facts discovered -->

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

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: AND-gate 双因子。F1（触发，rare）：Ferocious Bite 的自伤证据行（CHAT_MSG_SPELL_SELF_DAMAGE）先于 cast 记录（UNIT_CASTEVENT 桥/UNIT_SPELLCAST_SUCCEEDED）落表到达——客户端事件洪流下两条通道的到达序可反转——此时 D-02 cast 维覆盖谓词 isCastCovered 用全局栈顶把上一发 bite 的 [cast,land] 覆盖对误判为"本行已覆盖"：绿 landed 通告被压制（onSelfDamageLine 门控）+ land 写入被 recordLandEvent 去重压制 → Ferocious Bite land listener 不触发 → rake/rip 续期记账丢失 → 术左 ripLeft 后驱 0 → isRipPresent 误判 false → 换 Savagery + 提前重放 Rip。F2（系统性）：D-03 反推兜底 computeLandTable 直接 push landTable、绕过 landListeners 派遣——即使兜底触发，FB 续期 listener 也不会执行、续期记账依然丢失，且反推兜底在 29-04 前构建上的通告'blue'→OFFICER 渲染为绿色，与用户"无蓝无红"观察自洽（用户三无观察的兜底绿线可见性即此解释）。bite 命中机制本身无异常（glance 不可能、事件行格式与全样本吻合、isCanAttack 话计算恒真均已排除）。
fix: ① core/spell_trace_core.lua 新增 isStaleCoveredPair 判别器：covered 且 (lineTime - lastCast) > ttl ⇒ 陈旧覆盖（本行是未落表新 cast 的首条证据，非重复证据）；② onSelfDamageLine 在配对后、门控前检测陈旧覆盖并调用 recordCastTable 补记 cast 时间戳——恢复 cast<=land 全城不变量，原 D-02 门控自然放行（通告+写入+listener 派遣全链路恢复），迟到真实记录被 0.2s dedup 吸收、不二次反转不变量；③ computeLandTable 兜底写入改走 recordLandEvent（推送+派遣 listener），(inferred) 通告先行保持因果序；④ 新增自测 Q-17（陈旧覆盖自救路径）/Q-18（兜底派遣+FB 续期记账）。
verification:
  target_test: { result: skipped, reason: Q-17/Q-18 仅能在游戏内 /mt 运行（本机无 WoW 客户端/Lua 运行时），静态语义推演逐条通过（Now/GetTime 相对时钟、CR-01 夹具纪律、RAKE_DURATION=9/RIP_BASE=10 前置成立）；随 29-04 rebuild 同车游戏内复跑 }
  mutation_check: { result: skipped, reason: 无 Stryker/头less 变异框架可驱动 Lua 游戏内测试 }
  no_op_deletion: { result: pass, 唯一删除（computeLandTable 直接 push）由 RCA 明确论证为经 recordLandEvent 的等价路由（恢复听众派遣），diff 其余纯增补 }
  adjacent_tests: { result: skipped, reason: Q-01..Q-16 须游戏内执行；静态兼容推演已逐条过（Q-07/Q-11/Q-12/Q-13/Q-15/Q-16 无断言冲突，Category T 计数不受影响）}
  revert_and_reconfirm: { result: skipped, reason: bug 为实机竞态、无法在本机复现/回放（无客户端、无录制），回购验证绑定用户的 29-04 rebuild 实机项 }
  guardrail_verdict: pending_human_verify
files_changed: [core/spell_trace_core.lua, classes/druid/selftest.lua]