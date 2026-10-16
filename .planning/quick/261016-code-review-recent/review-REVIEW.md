---
phase: quick-261016-code-review-recent
reviewed: 2026-10-16T15:02:54Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - entity/Player.lua
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase quick-261016-code-review-recent: Code Review Report

**Reviewed:** 2026-10-16T15:02:54Z
**Depth:** standard
**Files Reviewed:** 1 (`entity/Player.lua`, 991 行)
**Status:** issues_found

## Summary

审查对象为 2026-10-16 三个 quick 任务对 `entity/Player.lua` 的累计改动（BASE `9355f9a` → HEAD：`941330a` 15/7、`665dd4a` 299/106、`2c2f413` 7/7，per-commit numstat 与 range diff 315/114 对焊一致）。逐行通读了当前 991 行全文，并跨文件核对了管线依赖的 helper（biz_util.lua / impl_util.lua）与 build 产物。

**验证通过的项目（无发现）：**

- **Lua 5.0 合规**：全文件无 `#` 长度运算符、无 `goto`/`::`（grep 复核为 0 处），新增代码仅用 `ipairs`/`pairs`/`strfind`。
- **零值陷阱纪律**：`macroTorch.getEquippedItemLink`（biz_util.lua:340）确认为裸透传 `GetInventoryItemLink("player", slot)`；entity/Player.lua 内全部 4 处调用点（322、416、544、571）均为局部捕获 + 判空后再用，零裸拼接。改区内 `GetInventoryItemLink` 裸调用 0 处（仅注释提及）。
- **CursorHasItem nil 陷阱**：仅 471 一处，`if CursorHasItem() then` 真值判断（非 `== false`），nil 安全。
- **1.12 客户端机制一致性**：swap 恢复臂依赖「装备到已占用 17 自动换回背包」、mainHandItem 恢复臂依赖「双手剑装 16 一步到位副手自动回包」、装载拒绝支依赖「双手占 16 时副手装 17 被拒」——三条经验事实与代码行为一致，无矛盾。
- **恢复臂字节冻结**：当前文件 707-766 行 md5 = `81258c7e5bd319bc24055525652a8a7d`，与 vbt 冻结值逐字节一致（头带 `0273e4ff…`、改区带 `bdbd6e2d…` 亦复现；见 IN-03 关于尾带的小瑕疵）。恢复臂本体未发现 bug。
- **vbt CD 命中语义**：698-700 置 `useableItemUsed = true` 后落穿恢复臂、成功臂 696 的 `return` 是唯一提前出口——与 vbt 裁决一致；CD 命中时 useableItemUsed 先置 true 再进战斗暂停（707-709），脱战续按直接进恢复臂，不会重试使用——语义正确。
- **战斗纪律**：装载函数入口 491、恢复臂 707 双重战斗守卫，pendingEquip/mainHandItem 全量保留，零动作。

**主要关切：** 全局锁谓词只挡「未使用」条目（`useableItemUsed == false`），使用后未恢复的条目不设防，而同槽再装载会整表覆盖条目并摧毁 `mainHandItem` 恢复状态（CR-01，违背 review 规格中「loadingTable 字段不得泄漏进后续装载周期」的显式不变式；锁谓词经 `git show 665dd4a^` 验证与现状 525 行逐字节相同——该窗口是 20c 之前既有的缺陷，20c 的变化是 `mainHandItem` 成为承重恢复目标，使同一窗口后果升级为摧毁双手剑恢复状态——主手 16 空置 + 双手剑滞留背包进入战斗）。

---

## Critical Issues

### CR-01: 全局锁谓词漏洞——「使用后未恢复」状态可被同槽再装载覆盖，mainHandItem 恢复状态被摧毁

**File:** `entity/Player.lua:523-530`（锁谓词 525 行）、`556-560`/`580-583`（整表覆盖）、`608-612`（mainHandItem 状态建立点）、`730-749`（唯一能恢复双手剑的臂）

**Issue:** 全局锁（523-530）只在 `loadingTable.useableItem and loadingTable.useableItemUsed == false` 时阻止新装载。释放键按下成功使用后置 `useableItemUsed = true`（695/700）但条目仍在（恢复臂要等第二次按键或脱战才清除），此时再按装载键：

1. 前置扫描（499-518）不匹配（pendingEquip 为空），全局锁不触发（used == true）；
2. 装载循环走到同槽目标（17 被旧 pokemon 占据）→ swap 支：`macroTorch.itemLoadingTable[targetSlot] = { useableItem=新物品, useableItemUsed=false, swappingItem=旧pokemon名 }`（556-560）**整表字面量覆盖**；
3. 双手路径建立的 `mainHandItem`（双手剑名，608-612）随覆盖永久丢失；
4. 后续恢复只走 swappingItem 臂：把**旧 pokemon 物品装回 17**，双手剑滞留背包，主手 16 永久空置——需人工手动修复。

该序列用锁定数据可实际触达：装载骷髅/诱饵龙（17 槽、双手路径 A）→ 按释放键使用 → 在恢复前再按装载键且 13 槽五个饰品 pokemon 全部缺席/在 CD（raid 场景常见）→ 循环到 decoy（17 槽）→ swap 支覆盖。**归属澄清（经 `git show 665dd4a^:entity/Player.lua` 实测，旧 424-429 行与当前 525 行谓词逐字节相同）：「使用后未恢复」再装载窗口是 20c 之前既有的缺陷，并非 665dd4a 引入**（此前恢复只依赖 swappingItem/backupItem，被摧毁的后果限于饰品槽的替换物状态；20c 使 `mainHandItem` 成为承重恢复目标后，同一窗口如今摧毁的是双手剑恢复状态）。另产生次生问题：不同槽再装载（如 stale [17] 条目 + 新 [13] 条目并存）时 castLoadedItem 以 `pairs` 任意序迭代且处理首个匹配条目后 `return`（696），行为不确定。

违反 review 规格显式不变式「loadingTable fields must never leak into a later load cycle」与 521 行注释自述的「at most one loaded item at a time」。改区（525、556-560）不属于 707-766 恢复臂字节冻结区，可直接修。

**Fix:** 收紧锁谓词为「条目存在即锁」（恢复臂成功清除条目后才解锁，三个恢复臂均在成功后 `itemLoadingTable[swappingSlot] = nil`）:

```lua
-- 523-530
if macroTorch.itemLoadingTable then
    for _, loadingTable in pairs(macroTorch.itemLoadingTable) do
        if loadingTable.useableItem then  -- was: and loadingTable.useableItemUsed == false
            macroTorch.show("A usable item is already loaded: " .. loadingTable.useableItem)
            return false
        end
    end
end
```

pending（无 useableItem）条目不受影响，仍由前置扫描先于锁恢复。可选加固：556 行覆盖前先保留既有 `mainHandItem`/`swappingItem`（合并而非覆盖）。

---

## Warnings

### WR-01: 「继续失败」pending 状态无出口——最终装备持续被拒时双手剑永久滞留背包

**File:** `entity/Player.lua:594-597`（拒绝门）、`608-612`（pending 建立）、`616-629`（最终装备）、`499-518`（每按复跑）、`683`（cast 跳过无 useableItem 条目）

**Issue:** 双手卸下后可修复路径只在「17 槽 + 主手确有两手武器」时成立。若最终装备因**其他原因**持续被拒（如 toSlots 映射的物品实际为不可装备到 17 的物品类型），流程进入死循环：每次按装载键，前置扫描重试装备（502-503）→ 验证失败 → 514-515 打印失败并 return，`pendingEquip` 永不清理；而 castLoadedItem 外层条件要求 `loadingTable.useableItem`（683），对 pending 条目无任何恢复手段——双手剑一直躺在背包、主手空置，直到玩家手动拖装备（或某次装备侥幸成功）。设计文档声称「失败只留 pendingEquip 供下一键幂等续跑」，但未定义「续跑持续失败」时的收敛路径。

**Fix:** 为重试失败提供明确回退：在 pending 决赛失败后回装双手剑（`obj.equipItem(pendingTable.mainHandItem, 16)` + 验证）并清除条目，回退到「装载干净失败」终态；或对 pending 重试加计数上限，超限即回退。注意此改动位于装载函数（非冻结区），但建议作为新 quick 任务落地并补 UAT 场景（错误类型物品映射到 17 时两键内收敛且双手回 16）。

### WR-02: SM_Extend.lua（build 产物）已陈旧——仍是四旧文本 + 旧管线 + 旧 CD 语义

**File:** `SM_Extend.lua:1648-1674`（04w 前 pokemon 数据：trackingHoundSaying ×4、Dog Whistle、backupItem 行）、`1563`/`1676`（20c 前 loadUseableItemToSlot，无 equipItemToSlotVerified/unequipToBagVerified/pendingEquip）、`1680-1712`（旧 castLoadedItem，带 backupItemName 臂）、`1694`（旧 CD 文案 `Useable item is in CD: `，无 vbt 的 `restoring` 语义）

**Issue:** 仓库根 `SM_Extend.lua` 由 `./build.sh` 从 entity/*.lua 拼接生成（build.sh:22-23），但当前内容停留在 04w **之前**的基线：三个 quick 的全部改动（04w 数据表、20c 三步验证管线、vbt CD 同按恢复）均未进入。任何未重跑 build.sh 就分发该文件的场景（用户从 Cygwin checkout 重建、其他消费者直接复制）都会拿到旧行为——包括已被裁决废弃的「CD 命中不恢复」语义。04w SUMMARY 已备案「待用户下次 build.sh 重建自动再生」；本处按 2026-07-26 review 先例确认其为 WARNING（文件名 SM_Extend.lua），不作为源码审查对象。

**Fix:** 用户侧执行 `./build.sh` 重建；重建后应验证：无 `Dog Whistle`/`trackingHoundSaying`、存在三新条目与 `restoring` 文案、`pendingEquip`/`equipItemToSlotVerified` 出现于新管线。

### WR-03: 遗留 `obj.loadUseableItem`（旧装载器）为无调用死代码，却与新状态机共享同一全局表

**File:** `entity/Player.lua:345-373`

**Issue:** 全仓库 grep（含 docs、classes/，排除 .git/.planning/SM_Extend.lua）确认 `obj.loadUseableItem` 零调用——pokemonLoad 已于 04w 前改走 `loadUseableItemToSlot`。但该遗留函数仍写入共享全局 `macroTorch.itemLoadingTable`，且语义不同：按槽 `useableItem == nil` 门（358）、装备后无条件报成功（无验证，365）、`swappingItem` 记录的是传入参数而非被顶出物品。若未来任何代码或用户外部宏调用它，可绕过新管线的验证与全局锁，在另一槽位制造第二条目（多条目 + pairs 任意序 + 696 首命中即 return 的行为已见于 CR-01 次生效）；在 CR-01 的锁收紧修复后，其条目行为（used 恒 false）也会与新锁语义纠缠。

**Fix:** 删除该函数（连同 375-373 注释块），或迁移其调用方到 `loadUseableItemToSlot`。若无外部调用方可确认（仓库内已证实无），建议随 CR-01 修复同一任务下线，避免保留两个写同一全局表的标准。

---

## Info

### IN-01: 装载表入口只校验 keys/toSlots，未校验 values

**File:** `entity/Player.lua:483-486`（校验）、`532-534`（取值）

**Issue:** 入口校验缺 `useableItemsTable.values`。若 `values[saying]` 为 nil（自定义调用方数据不完整），`obj.hasItem(nil)` → `isItemExist(nil)` → `getItemBagIdAndSlot(nil)` → `string.find(n, nil)` 运行时错误（biz_util.lua:173）。当前唯一调用方 pokemonLoad 数据完整，不可触达；仅作健壮性缺口备案。

**Fix:** 入口补 `or not useableItemsTable.values` 判空并 `macroTorch.show` 报错返回，与 keys/toSlots 一致。

### IN-02: castLoadedItem 767 行 `return` 不可达

**File:** `entity/Player.lua:767`

**Issue:** 所有上游支均提前 `return`（696 成功 / 703-765 恢复臂各臂全 return），767 行防御性 return 为死代码。无害，随下一代维护可清理。

**Fix:** 移除 767 行 `return`（或保留亦可，不阻塞）。

### IN-03: vbt 四带 md5 的「尾 766 起 = c5229c53…」在当前文件上不可复现

**File:** `.planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/261016-vbt-SUMMARY.md:70`

**Issue:** 对当前（= vbt 提交后未再变化的）文件按全部合理区间解读复算：766/767/768 × 989/990/991 起止组合及补尾换行变体，均无 `c5229c53`。另三带精确复现（1-684 = `0273e4ff`、695-706 = `bdbd6e2d`、707-766 = `81258c7e`，恢复臂冻结值成立），文件 991 行与净零位移不变式亦成立。尾带差异不影响代码正确性，仅意味着该文档常数按文献口径不可独立复算（估值：计算时使用了与文字不一致的边界约定）。备案供归档核查，不阻塞。

**Fix:** 无需改代码；若需归档严谨，在 vbt SUMMARY 补注尾带边界的精确命令（如 `sed -n '767,991p'` 的实际口径）。

---

_Reviewed: 2026-10-16T15:02:54Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_