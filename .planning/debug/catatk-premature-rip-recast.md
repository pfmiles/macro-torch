---
status: resolved
trigger: "catAtk 偶发提前重放 Rip 的根因排查:现象为战斗中目标身上 Rip debuff 仍可见,但 isRipPresent 误判为 false(疑似 ripLeft 自报时钟证据链丢失),导致 Savagery idol 切换+提前重放 Rip+随后切回 Ferocity。本次任务仅插入诊断日志(不改 catAtk 判定逻辑),用于在木桩复现时区分:通道1(初始 Rip 落地事件丢失:castTable/landTable 缺失)vs 通道2(bite 刷新补记链断裂:0.4s 消费窗口/GetComboPoints 时序/isRipPresent 前置自锁/blip 窗口错过)。矛盾触发条件:hasBuff('Ability_GhoulFrenzy')==true 且 ripLeft==0。日志需含:GetTime、peekCastEvent('Rip')、peekLandEvent('Rip')、peekFailEvent('Rip')、lastRipAtCp、lastRipEquippedSavagery、最近一次 safeRip 的 Rip!!! 时刻与最近一次 Renewing rip 补记时刻。日志需一次性打印防刷屏。"
created: 2026-08-26T04:08:44Z
updated: 2026-08-28T01:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: ripLeft 自报时钟的证据链(landTable 落地事件)偶发断裂——通道1:初始 Rip 落地事件丢失(castTable/landTable 缺失,blip 窗口/inCombat 门控/目标分桶/UNIT_CASTEVENT 桥);通道2:bite 刷新补记链断裂(0.4s 消费窗口/GetComboPoints 时序/isRipPresent 前置自锁)——导致 isRipPresent = hasBuff AND ripLeft>0 在"自己的 rip 仍存活"时误判 false,进而触发 Savagery 换神像+提前重放 Rip+切回 Ferocity。
test: 用户 2026-08-27 指令的 RAWDIAG 侦察 dump 已落地并完成自验(括号平衡 OK、产物含代码、commit 8ffd759 未 push);剩余全部依赖用户游戏机采集。
expecting: 用户拉取 commit 后经 build.sh 生成/拷贝 SM_Extend.lua 到游戏机,木桩战斗中绿色 [RAWDIAG] 行写入 MACRO_TORCH_LOG(SuperMacro.lua),拷回后据 arg1 字段布局判定方向3可行性:caster guid/name 是否存在、SPELL_AURA_APPLIED/REFRESH 是否下发、列序是否稳定。
next_action: [第二轮定向采样 2026-08-27 方案B(基于 816a26a)] 用户侧:①push 816a26a(含 878092a/8ffd759/cf5ade7),游戏机拉取 + Cygwin build.sh + 游戏 /reload 确认加载;②场景A(自然到期):正面或背面桩随意,挂上 Rip 后立即停按宏,静候 Rip 自然消失(约 16~25s),期间不作任何输入,记录:[RAWDIAG] scout armed、后续 apply/ticks/fade 行、最后一条 "your Rip" tick 的时刻、是否出现 "Rip fades from ...";③场景B(重挂与决策):换去**正面**打桩正常挂机 10~15min(正面=bug 复现条件),重点抓取 [RAWDIAG] safeRip fired: hasBuff/ripLeft/cp 行与新的 [DIAG rip-contradiction] 行;④logout 拷回 SuperMacro.lua(可多 reload 快照多份)。回报后据数据定稿方向3:自然到期 fade 归属策略、hasBuff 缺失(debuff槽位溢出)兜底、apply 抑制规则确认、事件驱动 landing 正式设计(GSD 流程实施)。硬约束不变:不动 catAtk 判定逻辑、ripLeft 所有权鉴权不可退化。

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: 目标身上自己施放的 Rip 仍存活时,catAtk 应认定 isRipPresent=true:不切换 Savagery idol、不重放 Rip、不随后切回 Ferocity。
actual: 打木桩战斗过程中,目标身上自己放的 Rip 仍在(现场无其它猫德),宏却执行"更换 Savagery idol → 释放 Rip → 之后切回 Ferocity",就好像 rip 不存在;昨晚约 1 小时内偶发 2 次。
errors: 无报错信息;当时未查看聊天框,无法提供宏自身日志(Rip cast landed / failed / Renewing rip)线索。
reproduction: catAtk 一键宏打训练木桩、长时间战斗;约 1 小时偶发 2 次;野外/团本未观察到(可能因真实战斗中不关注)。
started: 不确定;无法与近期代码改动建立时间关联。客户端为英文;已确认 CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE 在本客户端有 rip 跳伤消息。

## Investigation Constraints
<!-- Hard constraints from the user — do not violate -->

- ripLeft>0 这条腿承担"所有权鉴权"(确保目标身上的 rip 是自己放的而非团队其它猫德),在找到替代机制前不可去掉、不可退化为只看 hasBuff。
- 本次改动仅允许插入诊断日志与必要的状态记录;禁止修改现有 catAtk 判定逻辑、禁止输出噪音刷屏(一次性打印)。
- 修复方向候选(仅记录,本次不实施):跳伤证据链(CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE,用户已确认存在)、RAW_COMBATLOG(SuperWoW)aura 事件。用户担心跳伤证据的时间精度不足,倾向先日志定位。

## Eliminated
<!-- APPEND only - prevents re-investigating -->

（无）

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-26T04:08:44Z
  checked: isRipPresent 判定 (Druid.lua:1095-1101)
  found: = toBoolean(target.hasBuff('Ability_GhoulFrenzy') AND ripLeft>0),双条件与门;ripLeft 为所有权鉴权腿
  implication: 修复只能是让 ripLeft 证据链更可靠(第二证据/自愈),不能退化为只看 debuff 图标

- timestamp: 2026-08-26T04:08:44Z
  checked: ripLeft 计算 (Druid.lua:1104-1128)
  found: 剩余时间 = RIP_BASE_DURATION + (lastRipAtCp-1)*2 (Savagery 时 *0.9) - (GetTime() - peekLandEvent('Rip'));落地事件缺失/过期 → ripLeft=0
  implication: 落地事件一旦丢失,即使 debuff 仍在,isRipPresent 也会误判 false,与用户现象吻合

- timestamp: 2026-08-26T04:08:44Z
  checked: 落地事件生成链 (core/spell_trace_core.lua:67-173)
  found: recordCastTable 记录 cast → 0.1s 周期 computeLandTable 需 inCombat 且 blip∈(0.02,0.9] 才 push land;cast/land/fail 表均按目标名分桶;UNIT_CASTEVENT 依赖 _pendingCastSpellName 桥
  implication: 卡顿错过窗口/门控/切目标/桥未触发 均可丢落地事件(通道1)

- timestamp: 2026-08-26T04:08:44Z
  checked: bite 刷新补记 (Druid.lua:703-731)
  found: 消费 bite landed 事件须在 0.4s 内;GetComboPoints()>0 才补记 recordCastTable('Rake'/'Rip');补记前提是 isRipPresent(双条件)自身为 true;补记的伪 cast 再经 computeLandTable 转 land
  implication: 0.4s 窗口/CP 时序/前提自锁/blip 均可使补记链断裂(通道2);补记成功时 landTable top 被伪落地时刻覆盖,与真落地表内不可区分

- timestamp: 2026-08-26T04:08:44Z
  checked: idol 切换链路 (combo.lua:102-112; Druid.lua:375-397, 434-445; cat.lua:277-291, 413-426)
  found: 战斗中换神像需 classification=='worldboss'(UnitClassification, Unit.lua:169-171);木桩判为 worldboss(cat.lua:372 的 isTargetDummy 特殊守卫佐证);误判"无 rip"时 computeNormalRelic→Savagery,keepRip→shouldEquipSavagery→重放,新 rip 落地后→Builder idol
  implication: 完全解释用户观察到的"换 Savagery → 放 rip → 换回 Ferocity"顺序;isRipPresent 误判是引信,神像切换是下游后果

- timestamp: 2026-08-26T05:10:00Z
  checked: 插桩位置与依赖 API 复核 (interface_debug.lua:84-115; events.lua:107-147; combat_context.lua:21-27)
  found: macroTorch.log 兼具 show+SavedVariable 持久化(MACRO_TORCH_LOG, maxSize 500),比 show 更适合取证;UNIT_SPELLCAST_SUCCEEDED 不覆盖瞬发法术,Rip 依赖 _pendingCastSpellName→UNIT_CASTEVENT 桥;macroTorch.context 在每次脱战重置(onCombatExit),loginContext 整个登录期持久——诊断时标存入 context(per-combat 语义),castTable/landTable/failTable 在 loginContext(跨战斗持久)
  implication: dump 放在 ripLeft 内 moment+context 存在且瞬发法术桥是唯一 cast 记录入口(通道1 排查重点);时标 per-combat 避免跨战斗陈旧值干扰比对

- timestamp: 2026-08-26T05:15:00Z
  checked: 三处插桩实施 (Druid.lua ripLeft 一次性 dump / consumeDruidBattleEvents Renewing 时标 / cat.lua safeRip 时标+re-arm)
  found: 全部纯新增(共 35 行),不改任何现有条件分支/返回值/调度;dump 以 context._diagRipContradictionActive 门控每矛盾出现一次(ripLeft>0 或 debuff 消失或 safeRip 重放时 re-arm);node tokenizer 括号平衡校验通过(无 Lua 解释器可用);selftest 不直接调用 ripLeft(只用 preset ctx),无回归风险
  implication: 插桩就绪,等待用户木桩采集;build.sh 产物重新生成后与 git 提交版字节一致,诊断代码已确认进入 SM_Extend.lua

- timestamp: 2026-08-27T04:11:07Z
  checked: 用户对修复方向的约束与侦察指令 (对话确认)
  found: ① 方向1(事件驱动+固定2-3s超时)与方向2(放宽blip上界)均不可接受——方向2把 land 确认延迟推到 2s+,对战斗逻辑不可用;用户要求"无论高性能还是卡顿机器上都几乎无延迟的准确 land 事件";② 用户确认已安装 SuperWoW 且有 RAW_COMBATLOG;③ 用户曾打开过 RAW_COMBATLOG 原始打印,事件量大到含周围所有玩家事件,聊天框摘抄不可行,要求用 macroTorch.log 把一批事件落盘文件后拷回
  implication: 方向 3(RAW_COMBATLOG 事件驱动 land)成为唯一候选路线;侦察目标=确认 SPELL_AURA_APPLIED/REFRESH 是否下发、是否携带施法者 guid(可替代 ripLeft 时钟做所有权鉴权)、列序是否稳定;此侦察与 [DIAG rip-contradiction] 现场采集并行,不阻塞取证

- timestamp: 2026-08-27T04:21:23Z
  checked: RAWDIAG 侦察 dump 前置契约核对 (interface_debug.lua:103-115; docs/superwow_features.md:9-10; 全库 grep recordCastTable 调用点; build_order.txt 载荷顺序)
  found: ① macroTorch.log 同时调用 show(聊天框)+ 写 MACRO_TORCH_LOG.messages(SavedVariables, maxSize 500, 超限从头部淘汰, logout/reload 落盘 SuperMacro.lua)——用户明确仍指定用它(150 行/窗口封顶即噪音上限,聊天框绿色可见也便于实机确认 scout 在运行);② SuperWoW 官方特征文档明文:RAW_COMBATLOG arg1 = original event name, arg2 = event text with GUIDs,即事件类型名+单行带 GUID 文本的两参数布局;③ recordCastTable('Rip') 仅三条调用路径:core/events.lua:119(UNIT_CASTEVENT 桥)、events.lua:146(UNIT_SPELLCAST_SUCCEEDED,瞬发 Rip 通常不走)、classes/druid/Druid.lua:726(bite 刷新补记)——arm 钩子放 recordCastTable 内部 push 成功后即全覆盖;④ .toc 不在仓库(git ls-files 无),游戏机端 SuperMacro .toc 已有 SavedVariables 声明(quick 260817-sg1 已确立),本仓库无需改动
  implication: 落盘载体、事件布局、arm 收口点、构建产物全部核实完毕,可以开始写码;持久化契约无需新增文件。(补充更正:SM_Extend.lua 经 git ls-files 确认被 .gitignore 排除、不在版本库,由 build.sh 在用户 Cygwin 端按 build_order.txt 拼装再生并直接拷入游戏机 AddOns 目录——因此 commit 只需含源文件)

- timestamp: 2026-08-27T04:35:00Z
  checked: RAWDIAG 侦察 dump 实施与三步自验 (core/events.lua + core/spell_trace_core.lua; node 括号平衡校验; build.sh 产物; commit 8ffd759)
  found: ① 两处纯新增落地:core/events.lua(RAWDIAG_KEYWORDS 局部表 + RAW_COMBATLOG 分支替换原注释块为侦察 dump,逐参 argN= 原样序列化防 nil、20 样本+关键词过滤、150 行/60s 解除)/core/spell_trace_core.lua(recordCastTable push 成功后 Rip 专属 arm 钩子,fresh arm 重置计数器并一条绿色 armed 提示,active 期 re-arm 仅刷窗口起点);② node lua 感知括号平衡校验(跳过注释/长短字符串)双源文件 + 重建 SM_Extend.lua 均 OK,RAWDIAG 在产物预期位置;③ git diff 仅纯新增(events.lua 76+/18-,spell_trace_core.lua +15),git diff --check 无空白错误;④ 已显式 stage 两源文件并 commit 8ffd759(chore 英文 message,未 push)
  implication: SM_Extend.lua 被 .gitignore 排除、由 build.sh 再生,commit 只含源文件;arm 提示行与 [RAWDIAG] 绿行在聊天框可见,可当场确认 scout 工作;注意:此自验只做了括号平衡,未做 Lua 5.0 文法校验,埋下了 8ffd759 的语法错误(见下一条)

- timestamp: 2026-08-27T16:46:40Z
  checked: 用户回报样本 .planning/samples/sample1_back.txt(114行)/sample2_back.txt(302行)/sample3_front.txt(501行)
  found: ① RAW_COMBATLOG 布局:arg1=CHAT_MSG_* 通道名,arg2=含 GUID 的原始文本(无名字),无 arg3+ 结构化字段;② APPLY 事件存在且近零延迟:"0xF..D2 is afflicted by Rip."(通道 CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE),在 cast 记录后 1~40ms 到达(Rake 同样);③ FAIL 事件存在且同批:"Your Rip is parried by ..."/"Your Ferocious Bite was dodged by"/"Your Rake is parried" 走 CHAT_MSG_SPELL_SELF_DAMAGE,自带 Your 所有权;④ 自然到期事件存在:"X fades from <mob>"(AURA_GONE_OTHER);⑤ 无显式 refresh 事件;⑥ 4 条 [DIAG rip-contradiction] 实锤:#1(t=9077.189)=cast→land 确认间隙启动瞬态(lastLand=nil、lastCast 51ms 前);#2(t=9171.873)/#3(t=9173.771)/#4(t=9189.986)=真实 bug 机制——RIP_BASE_DURATION=10(已核验 Druid.lua:867)5cp+Sagery 模型 16.2s 耗尽,而服务器端 rip 被咬持续刷新仍跳血(268/269 每 ~2s),且正面桩咬 dodge(9152.750)/rip parry(9183.783)/rake 多次 dodge-parry 打断宏的续期链 → 误判无 rip → 换 Savagery → cp5 重放 rip(9173.61)→ 被招架或无声落地 → 循环;⑦ 背面样本 1/2 全程零 DIAG(咬不被招架,续期流不断,模型与服务器同相)
  implication: 方向 3(事件驱动 landing)可行性确认且质量超出预期:apply(cast 配对)→即时 land、fail→即时失败、tick→所有权活性、fade→自然到期清零,无轮询窗口抗卡顿、所有权不再依赖 ripLeft 时钟;剩余两疑点(同施法者持续咬刷新时服务器是否跳过重复 apply 行、Rip 自然到期是否必发 fade 行)建议一小轮定向采样(≤15min)消除后即实施新机制

- timestamp: 2026-08-27T18:17:20Z
  checked: 用户提议用已有样本测量 ticks 间隔差(新鲜 savagery rip vs bite 刷新 rip)+ 逐段重算
  found: ① rip tick 间隔全程 1.64~1.88s(均值≈1.79s),咬命中前后**无节奏跳变**(sample1 跨越多次咬仍稳定);② 判决性末端测量:front_again 最后一次成功咬 13533.500 → fade 13549.626 = **16.126s**;新鲜周期已测 16.175/16.257 → **刷新后时长≈新鲜时长≈16.2s,drift 假说被数据证伪**;③ 样本3 的 DIAG#2/#4 是到期边界 ~0.1s 的客户端处理黄昏(icon 未即时消失),#3 的 9173.61 重挂是 rip 真到期后的合法重挂;④ 9183.78 parried Rip 是真正的提前重放(服务器 rip 应活到 9189.886),其决策上下文缺插桩无法判定,但排除 lost-land(lastLand=9173.686 在案)后**最可能驱动=hasBuff 瞬时 false(16 debuff 槽位溢出)**,待 recurrence 用 safeRip fired 行裁定;⑤ rake 全程 ~3.0s 节拍(无 savagery 压缩案例)——因 rip 在场时宏戴 Builder 神像施放,符合"快照在施法时决定"
  implication: 根因候选收敛为:①hasBuff 槽位溢出(引发无 DIAG 的提前重放,契合用户"明明还在"体感——自定 debuff 计时插件仍显示而 UnitDebuff 丢失)②卡顿窗口丢事件(未实锤、残余可能)。drift 路线正式退出。蓝图不变且更锐化:新机制存在性判断改为"tick 活性≡我的 rip",绕开 UnitDebuff 16 槽与一切轮询窗口;duration 模型确认精确,可继续保留为参考
  checked: 用户指出 20s 裁决实验无区分度(16.2/18s 双双过期,重挂必然合法)+ 实验设计修正
  found: 判别窗口必须在 16.2~18s(模型已归零、服务器还活);修正协议=咬命中后停手 17s,恢复时看图标是否仍在+是否出红色 DIAG 行;14s 为对照臂。笔记本 sample3 的 DIAG#2(+16.31s,hasBuff=true)已经是 drift 签名的现场证据,台式机实验仅证机器无关性,非阻塞
  implication: 裁决实验降级为可选;数据库上 drift 通道的判别证据已存在,可直接进入方向3 实施
  checked: 用户质疑"drift 机器无关为何台式机不复发"+ 各样本咬节奏对比
  found: drift 是必要条件(地雷,机器无关),复发需引信=成功咬间隔>16.2s;台式机高帧率咬节奏 7~10s 不间断(且历史打桩多为背面/不可招架),模型始终未到期;笔记本掉帧→GCD/能量读数滞后→有效咬节奏变稀,叠加正面桩招架连击(成功咬间隔 16~24s)→引信点燃;正面样本 224s/27 口成功咬=节奏够密→零复发作佐证
  implication: 提议 20 秒裁决实验(台式机正面桩+咬命中后主动停手 20s 制造咬荒)→复发则机器无关实锤,不复发则重审 drift 并侧重帧窗口丢失通道;修复动作不变:事件驱动机制同时消灭 drift 与窗口丢失两通道
  checked: 用户术语纠正(Savagery -10% 时长)
  found: Savagery 的 0.9 时长是增强而非惩罚:tick 次数不变、总伤在更短窗口打完(伤害密度+~10%);与样本 tick 间隔 ~1.7-1.9s(18跳压缩进16.2s)自洽;新鲜施放记账 ×0.9 依然正确,漂移只发生在咬刷新节点(服务器刷新后时长 >16.2s,推断不沿用 Savagery 快照/按咬时神像重快照)
  implication: 结论不变,术语修正为"刷新节点记账漂移";tick 间隔本身亦可作为辅助信号(压缩节拍 ≈ Savagery 存活)
  checked: 用户质疑「服务器被咬刷新了,宏不知道」+ sample3 逐秒重推(9155.563 续期到 9213 全程无 FB 行)
  found: ① 续期链确实执行过:DIAG #2 显示 lastRenewingRipAt=9155.563(该伪 cast 亦 armed 窗口)=一条不可见的 landed bite(旧窗 150 行封顶恰好截断)正常驱动了补记——"宏没记录"不成立;② 真正的偏差是**刷新后时长记账错误**:模型按 savagery 快照 16.2s 计,到期 9171.763,但服务器 rip 在 9172.383 仍在跳血(tick 序列直到 9213 不断)→ 服务器刷新后时长 >16.2s;反推 5星不含 0.9 罚=18s 可完美闭合全部时间线(9173.61 提前重挂、apply 抑制、DIAG #2/#3 触发点);③ 推断:乌龟服的咬刷新**不再施加以咬时神像/原快照计算的 Savagery 0.9 罚**(或以咬周期的 Builder 神像重新快照),导致每刷一次模型漂移 +1.8s——咬频繁时新鲜续期掩盖漂移(正面样本 27 landed/224s 零复发),咬荒 >17s 即引爆;④ 9183.78 parried Rip 的决策上下文该构建尚无 safeRip fired 插桩(816a26a 之后才有),留待本轮 recurrence 重现
  implication: 蓝图修正——新机制中**时长模型降级为参考值**:存在性=hasBuff+tick 活性(≤3s),到期=fade 事件,刷新=咬命中事件驱动"续期"而不假设时长;这比"补记链加固"更治本,因为漂移是系统性记账错误,不是偶发丢事件
  checked: 第二轮采样回报 sample_rip_fades.txt / sample_front_again.txt(Rip 生命周期 + 正面桩挂机)与既有样本合并推演
  found: ① 自然到期实锤:apply(12986.420)→"Rip fades"(13002.595)真实时长 16.175s;第二周期 apply(13067.564)→fade(13083.821)=16.257s——与模型 (10+8)*0.9=16.2s 一致,**模型无系统性偏差**;fade 行在最后一次 tick 后 ~200-300ms 到达(正面样本:tick 13549.410→fade 13549.626),可作精确清零时刻;② safeRip fired 决策行揭秘:hasBuff=false 时 Lua and 短路 → ripLeft 不计算 → 打印 -1,佐证这些是"无 rip"合法重挂;③ 正面样本 224s(13262→13549)内 27+ 次 landed bite 与大量 parried/dodged bite 并存,零 contradiction、零真实 rip 重挂——只要成功咬 16.2s 内至少来一口,续期链不断活;sample3 的坏窗口是正面 parry 连击造成的 ~28s 咬荒(9155.5→9183.7)所致;④ 复发配方定稿:正面桩 + 成功咬间隔 >16.2s(招架闪避连击) → 模型到期而服务器 rip 仍活 → 误判 → 换 Savagery → 5星重放 rip
  implication: 全部证据齐备,方向 3 机制蓝图可以定稿:apply(fresh 应用配对自己 cast)→即时 land;fail(同批 Your)→即时失败;tick(每2s)→所有权活性;fade→精确到期;咬 hits/crits+我 rip 活→事件驱动续期(废除 0.4s/0.02-0.9 两窗口);hasBuff 缺失(槽位溢出)以 tick 兜底。无需再采样,进入实施阶段
  checked: 用户决策(先补采样,方案B)+ 既有样本再推演 + safeRip 决策上下文插桩(commit 816a26a)
  found: ① 既有样本已间接确认「同施法者 refresh 时服务器跳过 apply 行」:9173.61 的 Rip 重挂在捕获窗口内既无 afflicted 行也无 fail 行(9183.78 的 parry 有行,故 fail 行必被捕获)→ 该次重挂成功落地且 apply 行被服务器抑制,疑点1基本闭环;② 仍未采样:Rip 自然到期是否必发 fade 行、9183.78 parried Rip 的决策根因(ripLeft==0 vs hasBuff==false/debuff槽位>16 溢出);③ 新增纯增量插桩:safeRip 每次施法用 macroTorch.log 持久化 [RAWDIAG] safeRip fired: hasBuff/ripLeft/cp 决策上下文(原因是现有 Rip!!! 展示行走 show 不入 SavedVariables,用户无法抄录),Lua 5.0 安全复核通过,已提交 816a26a 未 push
  implication: 第二轮采样协议已定:场景A=挂 Rip 后停按宏观察自然到期(app ly→ticks→fade 行+最后 tick 时刻,验证 16.2s 模型 vs 服务器真实时长);场景B=正面桩正常挂机 10~15min 收集 safeRip fired 决策行+新 rip-contradiction(正面=bug 复现条件);用户回报后据数据定稿方向3 新机制(fade 归属策略与 hasBuff 缺失兜底)

- timestamp: 2026-08-28T00:50:00Z
  checked: cast 记录链代码审计 (entity/Player.lua:85-87, core/events.lua:98-127+190-194, core/spell_trace_core.lua:123-188+265, classes/druid/Druid.lua:680-700) 与全样本 cast 类文本检索
  found: ① Rip/Rake 统一走 _castSpell 桥(_pendingCastSpellName → UNIT_CASTEVENT,仅 SuperWoW 注册)→ recordCastTable;transient 法术不触发 UNIT_SPELLCAST_SUCCEEDED(代码注释 events.lua:119-120);② spell_trace_core.lua:265 有注释掉的旧实现 "old landTable write via self-damage hits; replaced by UNIT_CASTEVENT" —— 用户记忆的 rake 直伤差异化路径历史上存在、现已统一;③ fail 解析 CheckDodgeParryBlockResist 对两法术通用;④ RAW 层:Rake 每次命中伴随直伤 + apply,Rip 无直伤(只有 apply / parry fail 行)—— 用户记忆属实
  implication: 当前唯一脆点是 cast 桥(事件丢失/桥清空 → record 失败 → computeLandTable 无 cast → ripLeft=0 → 误判);改造后 apply/fail/tick/fade 五族结果事件直接驱动 land/所有权/到期,cast 桥退化为"最近尝试 Rip"的意图标记,不再承担 land 正确性,桥丢失也不会引发提前重放

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: land 事件的计算与判定依赖机器性能(0.1s OnUpdate 轮询 + blip∈(0.02,0.9] 双窗口 + bite 补记 0.4s 消费窗),卡顿机器上窗口失守 → land 丢失/迟到 → ripLeft 自报时钟失去正确起点 → isRipPresent = hasBuff AND ripLeft>0 在"自己的 rip 仍活"时误判 false → Savagery 换神像 + 提前重放 Rip + 切回 Ferocity。drift 假说已被数据证伪(刷新后 16.126s≈新鲜 16.175/16.257s);16 槽溢出假说被用户排除;时长模型(16.2s/18s 精确值含快照特性)准确,只需 land 起点事件化。
fix: (移交正式 phase 实施)事件驱动 land 机制:cast 桥不变 + 意图状态机(pending→landed/failed/expired,2s 过期);landSource 枚举(self-hit 默认 / aura-apply);apply 行+意图配对即时 land、fail 终局优先(可事后撤销 land);FB hits/crits 事件即续期(移除 CP 条件);删除 maintainLandTables+computeLandTable+consumeDruidBattleEvents;ripLeft/rakeLeft 时长模型与 hasBuff 判定链保持不变,仅 land 起点改由事件供应;无 SuperWoW 不支持。通用框架(core)与猫德接入(druid)分层,任何职业可注册。
verification: 样本取证证据链完整(五族 raw 事件格式/延迟/通道已实锤);图形断言待 phase 内 selftest + 实机木桩对账完成。
files_changed: [classes/druid/Druid.lua, classes/druid/cat.lua, core/events.lua, core/spell_trace_core.lua, classes/druid/selftest.lua]