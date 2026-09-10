---
status: diagnosed
trigger: "User reported during UAT (Phase 29-landing, Test 3): 行为都符合预期，就是蓝色和绿色刚好搞反了：rake/bite全都是蓝色的landed, pounce和rip的inferred landed都是绿色的，没有红色"
created: 2026-09-11T00:00:00Z
updated: 2026-09-11T00:10:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — 颜色倒置的根因在渲染层 `macroTorch.show`（interface_debug.lua:87-99）的颜色名→实际色相映射表，而非 Phase 29 通告逻辑或调用点
test: 静态取证已完成（git blame / git show 追溯 + 调用点全量审计 + 自测断言审计）
expecting: 已达成——两臂映射与用户实机观察逐条吻合
next_action: "收尾：写 Resolution.root_cause 与 Evidence，返回结构化 ## ROOT CAUSE FOUND（goal 为 find_root_cause_only，不改任何源码）"

## Symptoms
<!-- IMMUTABLE -->

expected: 单人木桩场景，协议 HUMAN-UAT.md §247-248 约定：绿色=landed（直接判定），蓝色=inferred（推断兜底）。Rake/Ferocious Bite 应恒绿『landed』；Pounce/Rip 应为绿色『landed』或偶发蓝色『landed ... (inferred)』。
actual: landed/inferred 判定分类本身全部正确（无红 failed-on、ripLeft 正常启动、行为钉 D-02/D-03/D-04/D-06 均工作），但颜色编码恰好颠倒：rake/bite 的 landed 通告行全显示蓝色，pounce/rip 的 (inferred) 通告行全显示绿色。
errors: None reported
reproduction: 实机验证（用户 Windows+Cygwin 客户端）；UAT Test 3 记录在 .planning/phases/29-landing/29-UAT.md。判定行为是 Phase 29 统一 landing 重构（D-02 去重压制 / D-03 反推兜底 / D-04 fail 否决窗 / D-06 fail-wins 撤销）的产物。
started: Discovered during UAT（Phase 29 实机验证，2026-09-10）

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: Phase 29 通告调用点的颜色标签传反了（inferred 行传了 'green'、landed 行传了 'blue'）
  evidence: spell_trace_core.lua:451 唯一 'blue' 调用即 (inferred) 兜底行；:499（aura-apply 配对）与 :598（self-hit 配对）两处 'green' 均为直接 landed 行——标签与协议 §247/§248/§254 一致，调用点无误
  timestamp: 2026-09-11T00:10:00Z
- hypothesis: 存在第二个宏 Torch.show 定义在 build 拼接序中覆盖正确实现
  evidence: 全仓唯一 `function macroTorch.show` 定义在 interface_debug.lua:87；全仓唯一 DEFAULT_CHAT_FRAME:AddMessage 也在同函数（interface_debug.lua:99）——渲染通路单点；selftest 内的 show 赋值为测试期 stub
  timestamp: 2026-09-11T00:10:00Z
- hypothesis: 游戏客户端侧颜色配置/频道改写（环境类）导致倒置
  evidence: 用户同时观察到 'red'（failed-on）与横幅白/黄等其余色臂正常；且两个错误臂均能由本仓映射表精确解释（'blue'→OFFICER 渲染绿色、'green'→{0,0.5,0.9} 渲染蓝色），无需外部因素即可完全解释，客户端默认值即可复现
  timestamp: 2026-09-11T00:10:00Z

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-09-11T00:05:00Z
  checked: interface_debug.lua:87-99 macroTorch.show 颜色映射表
  found: 'blue' → ChatTypeInfo["OFFICER"]；'green' → 定制 RGB {r=0, g=0.5, b=0.9, id='custom_green'}
  implication: 两臂实际色相与名称相反——OFFICER 频道在 1.12 客户端渲染为绿色；{0,0.5,0.9} 是蓝通道主导（b=0.9 > g=0.5, r=0）渲染为蓝色。'red'→YELL（红）、'yellow'→SYSTEM（黄）两臂正常，与用户"没有红色"且红/黄横臂无投诉一致
- timestamp: 2026-09-11T00:05:00Z
  checked: 全仓颜色调用点审计（grep 'green'/'blue' 全部非 selftest 源码）
  found: 'blue' 唯一消费者 = spell_trace_core.lua:451 (inferred) 兜底通告；'green' 消费者 = spell_trace_core.lua:499、:598（两处直接 landed 通告）、Target.lua:65、diag.lua 十余处、macroTorch.log 链路（interface_debug.lua:112 转发同表）
  implication: 调用点语义全部符合协议；倒置集中在唯一渲染入口。宏Torch.log 与 diag/Target 的绿色通告同受害（同表转发），属显示层横向缺陷，非 landing 特有
- timestamp: 2026-09-11T00:05:00Z
  checked: git log -S "OFFICER" / -S "custom_green" 追溯
  found: 'blue'→OFFICER 由 7d2369b (event mechanism fixed some bugs, 2025-11-24) 引入；'green'→{r=0,g=0.5,b=0.9} 由 5594a09 (minor mod, 2025-12-03) 引入；均早于 GSD 重构，重构与 CRLF 归一（0c8ba73）仅原样搬运
  implication: 映射缺陷是 2025 年底遗留问题。Phase 27 前无蓝色通道作对照、协议未区分绿/蓝，故长期未被肉眼发现；Phase 29 引入 (inferred) 蓝臂 + HUMAN-UAT §247-248 绿/蓝协议后，倒置首次可被观察到
- timestamp: 2026-09-11T00:08:00Z
  checked: classes/druid/selftest.lua Q-11..Q-16 断言内容
  found: Q-11 捕获 macroTorch.show 后的断言为 capColor == 'blue'（校验标签字符串，非渲染 RGB）；测试期 show 被整体 stub，interface_debug 映射表在自测路径从不执行
  implication: 解释"为何 320 自检全绿仍存在该缺陷"：自检只验证了契约标签，颜色名→色相的翻译层没有任何测试覆盖
- timestamp: 2026-09-11T00:08:00Z
  checked: 用户实机报告与映射表的双向对照
  found: rake/bite landed 行（'green'→{0,0.5,0.9} 蓝）显示蓝色 ✓；pounce/rip (inferred) 行（'blue'→OFFICER 绿）显示绿色 ✓；无 failed-on 红行（'red'→YELL 色相正确）✓
  implication: 症状三要素与映射表两臂逐条吻合——根因证实（实机观测即地面真值），无需再改任何代码验证

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: interface_debug.lua:87-99 `macroTorch.show` 的颜色名到渲染色相的翻译表绿/蓝两臂互相颠倒——'blue' 被映射到 ChatTypeInfo["OFFICER"]（1.12 客户端渲染为绿色），'green' 被映射到定制 RGB {r=0, g=0.5, b=0.9}（蓝通道主导，渲染为蓝色）。Phase 29 通告调用点标签全部正确（spell_trace_core.lua:451 用 'blue' 发 (inferred)、:499/:598 用 'green' 发 landed），倒置发生在下游唯一渲染入口，导致 rake/bite landed 行显示蓝、pounce/rip (inferred) 行显示绿
fix: [未应用——find_root_cause_only] 方向：在 interface_debug.lua 的 macroTorch.show 中纠正两臂色相——'green' 改用真实绿色（如 ChatTypeInfo["GUILD"] 或 {r=0,g=1,b=0}），'blue' 改用真实蓝色（如直接采用现被误命名为 'custom_green' 的 {r=0, g=0.5, b=0.9} 或 ChatTypeInfo["PARTY"]）；建议补一条对映射表色相的自测（当前 Q 系列只断言标签，映射层零覆盖）
verification: [未应用]
files_changed: []