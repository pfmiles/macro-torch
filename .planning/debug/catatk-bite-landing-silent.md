---
status: investigating
trigger: "目前的catAtk循环遇到一个问题需要排查：有一次，已经是在正常的木桩战斗过程中，已经开局了几十秒了，目标身上已经有了rake & rip，此时我打了个5星bite，屏幕上能看到白字输出的“Bite!!!... ooc: false”提示，但却没有看到蓝色的landing信息；然后随后是“Reshift!!!...”信息，且reshift信息中显示当前能量为0，也就是说明前面那个bite肯定是成功打出去了的，不然不会清空能量；但那个bite却没有对应的蓝色landing信息或红色fail信息出现，就静默地走掉了；然后接下来我的catAtk宏就判断rake & rip没有被bite续上，因此后来的5星又打了个rip，但此时其实目标身上的rip还在的(因为其实被bite续上了)。需要帮我排查下bite成功却没有landing信息的原因；我记得bite的landing，应该是全靠self-hit事件来确定的吧？因为它既没有apply debuff的效果，也没有fail反推兜底，那么这个问题就唯一可能会出现在释放之后的确定造成伤害的事件解析身上？我目前能想到的会不会是glance的伤害信息跟普通的伤害信息不一样，导致解析出错？"
created: 2026-09-11T05:37:48Z
updated: 2026-09-11T05:37:48Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: (seed) 该次 bite 的两向通告（蓝 landed / 红 fail）均在 Phase 29 统一 landing 管线中静默：优先疑点 = self-hit 事件行匹配/配对失败（如 crit 行格式差异）与 fail 路径静默跳过；用户证实无卡顿 → 意图 2s 过期门被卡顿点燃的路线降权。
test: (pending)
expecting: (pending)
next_action: "gather initial evidence"

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

- 实机验证受每周 CD 限制：静态路径（bbcheck / grep 电池 / 语义推理）必须自足；实机项固化为极简取证 todo（与 29-04 rebuild 同车）。
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

root_cause: (pending)
fix: (pending)
verification: (pending)
files_changed: []