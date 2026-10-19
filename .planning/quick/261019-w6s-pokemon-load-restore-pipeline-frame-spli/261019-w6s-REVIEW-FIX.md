---
phase: quick-261019-w6s
reviewed: 2026-10-19T15:55:05Z
fixed_at: 2026-10-19T16:07:08Z
review_path: .planning/quick/261019-w6s-pokemon-load-restore-pipeline-frame-spli/261019-w6s-REVIEW.md
fix_scope: critical_warning
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase quick-261019-w6s：Code Review Fix Report（修复报告）

**Fixed at:** 2026-10-19T16:07:08Z
**Source review:** `261019-w6s-REVIEW.md`（本次修复依据，只读未改）
**Iteration:** 1
**Fix scope:** critical_warning（CR-01、WR-01、WR-02、WR-03、WR-04；Info 三条按指令不动）

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped / false_positive: 0
- 唯一改动文件：`entity/Player.lua`（1098 → 1166 行）
- 每笔修复独立原子 commit（分支策略 none，直接提交 main，未 push）
- 验证环境：主检出树（无 worktree；按任务配置 branch=main、`workflow.use_worktrees` 非本项目模式）

---

## 逐条裁决（先裁决、后动刀；全部 5 条判定为**真实问题**，无误报）

裁决标准：引用精确行号 + 代码可达性推演 + 实机取证事实 E1/E2/E3（复述自 REVIEW 硬门实测记录）。
全文件 pokemonEnqueue 链条形状实核（修前逐点枚举，最终行号同 shape）：
- **三步链**（pickupBag → equipCursor → verify*）：入队点 421-423（续跑预扫）、467-469（占用槽装载）、488-490（空槽装载）、585-587（swap 恢复臂）、600-602（主手恢复臂）、849-851（修复链重装）。**6/6 全部三步**，与 REVIEW 描述一致。
- **两步链**（pickupInventory → verifySlotEmpty）：入队点 612-613（纯卸装臂）、911-912（修复臂摘主手）。**2/2 全部两步**，与 REVIEW 描述一致。
- 其余链（rollbackCursor→verifyRollback 三处、depositCursor→verify* 续接）均为 handler 执行后下一 tick 的尾随续接，不参与前端中止。
- 链条严格串行：新链只由上一链尾的 handler 消费后追加，pump 每 tick 队首弹一（先弹后派发），因此任一 pickup* 中止时其配对剩余步必然在队首，按队首排水数量精确（已用 Lua 5.0.3 脚本仿真四种形状 + 附加后续链场景，排水后剩余链完整；`table.remove(q,1)` 两次收缩数组语义验证通过）。

### CR-01：pickupBag 忙光标中止不中止序列，下一 tick equipCursor 会把光标异物装进 13/17
**verdict: fixed（真实问题）**

- **证据（可达性推演）**：装载键一次按压入队 `[pickupBag, equipCursor, verifyEquipLoad]`，pump 不感知序列边界（pokemonPipelineTick 逐 tick `table.remove(queue,1)` 后派发）。忙光标中止只 return 当前 step，equipCursor 留队首；下一 tick dispatch 在 `entity/Player.lua:706` **无条件** `EquipCursorItem(step.slot)`——光标动作作用于“光标上任何物品”（E3 事实：同帧多光标动作只执行第一个、物品滞留光标）。异物装进 13/17，占用槽时客户端 swap 把原占用物逐入背包（REVIEW 第 58 行模型）；装载臂 467-469/488-490 与恢复臂 585-587/600-602 完全同构可触达。
- **修前代码**：718-732（pickupBag 两 abort 均裸 return）。
- **修后代码**：734-755（现文件）。忙光标支在 return 前经 `pokemonQueueEnsure()` 对队首 `table.remove(q,1)`×2 排掉本链的 equipCursor + verify*（Lua 5.0 1-based 收缩语义，含注释论证）。
- **与 REVIEW 建议的唯一偏差（按实际形状修）**：“not in bags”支**不排水**。理由：(a) REVIEW 自身写明该路径空光标 equipCursor 为 no-op、无实物损坏；(b) 若此支也排水，verifyEquipRestore 将永远不可达，WR-04 的“真消失才清条目”成为死代码、其死锁无法解除——REVIEW 的 CR-01 与 WR-04 两段 fix 合起来是互斥的，本报告选择让 verify 保持可达、由 WR-04 判据裁决。
- **原子 commit**：`97c9546` `fix(quick-261019-w6s): resolve code review CR-01 — drain chain pair on pickupBag busy-cursor abort`
- **门结果**：冻结带对焊 4 段 IDENTICAL；Lua 5.0.3/5.1.5/5.4.7 loadfile 全绿；CRLF=0；`git diff --check` clean；新增行无 `#`/`goto`/`::`/`load(`；单光标重数 pokemonStepPickupBag=1。

### WR-01：E1 的 1-2 秒 link 滞后窗口内可能假拒绝——成功装载被误判、修复臂误摘主手
**verdict: fixed（真实问题）**

- **证据（可达性推演）**：修前判别门（859-865）为 `verify=false + isItemExist(itemName) + slot==17 + repair非nil` 即 fire。E1 已实测：空槽装载成功但 `GetInventoryItemLink` 同帧/次 tick 不刷新（1-2 秒后上链）；`isItemExist` 只看背包（biz_util.lua:168-183，bags 0-4 substring 匹配），玩家持有同款第二件时（Grimoire/Dragonling Remote 非唯一）背包副本即误命中 → 四门全过 → 修复臂把主手摘下进包。机理成立：E1 证据 + 判别门四个条件的实际语义逐条核对。
- **修前代码**：859-865（修复臂 fire 门）。
- **修后代码**：877-918（现文件），判别门改在 898-910：首次怀疑不 fire，而是 `step.wait=20` 每个 tick（0.1s interval）把 verify 重排重验，20 tick≈2.0s 覆盖 E1 全窗口；期间第一校验（879 行）一旦 link 刷新即提前 promote；只有二读仍 false 且物品确实在包才 fire 修复臂。计数器语义已用 Lua 5.0.3 仿真（第 20 次运行 fire）。
- **与 REVIEW 建议的偏差**：等待量由 10 tick 升为 20 tick——E1 证据上限是 2 秒，10 tick（1s）仍落在滞后窗内。promote 提前收敛机制不变。
- **原子 commit**：`0ce75d3` `fix(quick-261019-w6s): resolve code review WR-01 — poll slot link through the E1 lag window before firing the repair arm`
- **门结果**：同上全绿；verifyEquipLoad 光标动作为 0（重排只 pokemonEnqueue，无光标 API），动作→验证隔 tick 纪律不变。

### WR-02：卸装方向 link 滞后未取证，verifySlotEmpty 假失败 → 物品永久滞留光标
**verdict: fixed（真实问题）**

- **证据（可达性推演）**：修前 verifySlotEmpty 以“槽 link 不含 itemName”为 lift 成功唯一判据。卸载方向 link 刷新从未取证（REVIEW 明确）；若与 E1 对称滞后，抬升实际成功但 link 滞真 → 假失败 → 队列已无后继消费光标 → 物品滞留光标（E3 复发形态），且滞真期间重按的 pre-check 永远走错支。机理成立，判真实（不得以“未实测卸载方向”判误报）。修前 pickupInventory 亦无光标守卫，无法区分光标上是本物还是异物。
- **修前代码**：736-753（pickupInventory + verifySlotEmpty）。
- **修后代码**：757-792（现文件）。(1) verifySlotEmpty 改用光标状态为主判据：光标操作本地即时生效，`CursorHasItem()` 真即“本物已上光标”→ 直接进 depositCursor；仅在「光标为空 **且** link 仍滞真」时判失败并保留条目。(2) pickupInventory 补光标忙前置守卫。
- **超出 REVIEW 建议的补强（按“中止=序列终了”纪律）**：pickupInventory 的两条中止支各排水 1（本链剩余 verifySlotEmpty，两步链形状已实核）。若不排，忙光标中止后下一 tick verifySlotEmpty 会因“光标忙⇒成功”错觉把**异物**交 depositCursor 存入背包（对玩家拖拽的干扰）；排掉后中止即终了。
- **原子 commit**：`ab9c756` `fix(quick-261019-w6s): resolve code review WR-02 — cursor-based lift verify plus pickupInventory busy-cursor guard`
- **门结果**：同上全绿；pickupInventory=1 光标 API、verifySlotEmpty=0。

### WR-03：castLoadedItem 的 else 重置会清掉 in-flight 装载条目，swap/修复上下文永久抹除
**verdict: fixed（真实问题）**

- **证据（可达性推演）**：帧拆分后装载按键与 verify promote 之间有 0.3-2s in-flight 窗口（WR-01 落地后更长）。窗口内条目形状 `{pendingEquip, pendingSaying, [swappingItem]}`、`useableItem=nil`，castLoadedItem 配对键 545 行判伪 → 落入 else（618-621）`itemLoadingTable[swappingSlot]=nil` 清空。随后 verifyEquipLoad 照常 promote（840-857 只写 useableItem/used/saying）——swap 支 swappingItem 永久丢失、原副手永不换回；修复链 VDU 提交门（805-809 `if itemLoadingTable and itemLoadingTable[step.targetSlot]`）因条目已清静默跳过，mainHandItem 永不记录。基线同帧完成不存在此窗口，确为本重构新竞态。press 窗口重叠在玩家连按时真实可达。
- **修前代码**：618-621（else 裸清）。
- **修后代码**：618-631（现文件）：`if not loadingTable.pendingEquip then ... nil end`——else 只清“已 verify 完成且物品不在槽”的条目；in-flight 条目归队列所有，由 deferred verify promote，swappingItem/mainHandItem 随条目存活并保留（promote 代码 879-896 只用现存 entry 表追加字段，不复建裸表）。
- **原子 commit**：`3983793` `fix(quick-261019-w6s): resolve code review WR-03 — keep in-flight load entries alive across the cast reset branch`
- **门结果**：同上全绿。
- **残余风险备注（非本 finding 拒修理由）**：pocket 物品在 verify 失败后被玩家售出/销毁的极端情形下，死 pending 条目无 else 出口，续跑预扫（420 行）每次重入队 doomed 链，需 /reload 收敛——属历史“pending 无出口”边缘的既有形态，非本批引入的新链条；未加时间判据清除是因 E1 滞后下“equipped-but-lagging”与“gone”在 else 现场不可安全区分。

### WR-04：恢复目标从背包消失 = 全局死锁，收紧锁使装载键永久封死
**verdict: fixed（真实问题）**

- **证据（可达性推演）**：swap/mainHand 恢复目标（swappingItem/mainHandItem）在装载与恢复之间躺在背包，可被售出/存银行/销毁。恢复链 pickupBag“not in bags”中止（752 行）→（按本报告 CR-01 的排水决策，装备对保留继续执行）→ equipCursor 空光标 no-op → verifyEquipRestore 失败并保留条目（修前 871-881）；全局锁（432-439：任何 useableItem 条目锁新装载）使该条目成为永久锁——装载键只打印 "A usable item is already loaded"，唯一出口是手动摘下 pokemon 再按 cast。机理成立、与收紧锁联动构成用户可见死锁，判真实。
- **修前代码**：871-881（verifyEquipRestore 失败仅 show，条目保留）。
- **修后代码**：920-949（现文件）：成功判据不变；新增“真消失”清条目支——三条件同时满足才清：**光标为空（not CursorHasItem，排除抬升失败滞留在光标上的 backItem 被误判消失）且 不在目标槽（isItemNameInSlot 反向）且 不在任何背包（isItemExist 反向）**。瞬时失败（物品在包/在槽/在光标）至少命中其一 → 保留条目、下次按压收敛；真消失 → 清条目 + failMsg，打破死锁，回退到手动恢复。isItemExist 语义已核实为仅背包扫描（biz_util.lua:180-183），与“在任何背包”判据一致。
- **原子 commit**：`ddfa8dc` `fix(quick-261019-w6s): resolve code review WR-04 — clear the loading entry only when the restore target is truly gone`
- **门结果**：同上全绿；verifyEquipRestore=0 光标 API（CursorHasItem 为查询，与 verifyDepositUnequip 796 行先例一致）。

---

## 全部门汇总（对最终文件整体复跑，五项修复全部落地后）

| 门 | 结果 |
| --- | --- |
| 冻结带对焊（① 497-537↔605-645、② 539-563↔647-671、③ say→return obj↔746-754、④ FIELD_MAP→EOF↔757-END，md5 逐一比对） | 4 段全部 IDENTICAL（每次 commit 后均复跑通过） |
| Lua 5.0.3（权威）`loadfile` | 通过 |
| Lua 5.1.5 / 5.4.7 `loadfile`（佐证） | 通过 |
| CRLF 计数 | 0 |
| `git diff 41cc865 HEAD --check -- entity/Player.lua` | clean（早先 PLAN.md 的 blank-line-at-EOF 为编排者文档提交，非本批改动） |
| 新增行禁用 token（`#` / `goto` / `::` / `load(`） | 0 命中 |
| 逐 tick 单光标动作纪律（按函数体 awk 段 grep 计数） | pickupBag=1、pickupInventory=1、depositCursor=1；六个 verify + tick 本体 = 0；validate 恒晚于动作 ≥1 tick（verify 仍是独立队列条目下一 tick 消费；WR-01 的重排每 tick 一次，无同帧动作+验证） |
| 队列排水形状 Lua 5.0.3 仿真 | 三步链排 2 / 两步链排 1、附后续链不误伤、`table.remove(q,1)`×2 收缩正确、wait=20 第 20 次 fire |
| `git status --porcelain` | 五项 commit 后干净（本 REPORT-FIX.md 按要求**不 commit**） |

对照基线（41cc865）最终 diff：`entity/Player.lua` +86 行改动（统共 5 笔，全部在冻结带之外），文件 md5 `4b5fe7000d10e5d11f391f3400d003d8`（修前 pin `e92787b8b042d8994c12477d07fff945`，修复后变化即本批 5 笔，均落在 618-631 / 718-757（评审号码对应修改前 618-621、695-731）/ 736-792（修改前 736-753）/ 877-918（修改前 838-867）/ 920-949（修改前 871-881）五个改区）。

**Commit 序列（main，勿 push 指令持有）：**
1. `97c9546` — CR-01 busy-cursor 排水
2. `0ce75d3` — WR-01 E1 滞后延迟复验
3. `ab9c756` — WR-02 光标判据 + pickupInventory 守卫
4. `3983793` — WR-03 in-flight 条目保活
5. `ddfa8dc` — WR-04 真消失才清条目

**未修项说明：** Info 三条（IN-01/02/03）按 fix_scope=critical_warning 不动；SM_Extend.lua、build 产物、REVIEW.md 未改；.planning 下既有文件未动。

---

_Fixed: 2026-10-19T16:07:08Z_
_Fixer: Claude (gsd-code-fixer, delegated)_
_Iteration: 1_
