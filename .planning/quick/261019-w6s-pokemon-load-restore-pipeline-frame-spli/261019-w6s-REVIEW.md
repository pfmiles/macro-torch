---
phase: quick-261019-w6s
reviewed: 2026-10-19T15:55:05Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - entity/Player.lua
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase quick-261019-w6s: Code Review Report

**Reviewed:** 2026-10-19T15:55:05Z
**Depth:** standard
**Files Reviewed:** 1 (`entity/Player.lua`, 1098 行）
**Status:** issues_found

## Summary

审查对象为 41cc865（`fix(261019-w6s): frame-split pokemon load/restore pipeline (Player.lua)`）相对基线 0e3a183 对 `entity/Player.lua` 的改动（+311/−175，962→1097 行语义区）+ 与改动交互的整文件全局状态（`macroTorch.itemLoadingTable` / `macroTorch.pokemonEquipQueue` / 全局助手）。已逐行通读 1098 行全文，并跨文件核对 `core/periodic.lua`（registerPeriodicTask/onPeriodicUpdate pcall 契约）、`impl_util.lua`（toBoolean/tableLen/isNumber/getItemNameFromLink）、`biz_util.lua`（getItemBagIdAndSlot/isItemExist/getEquippedItemLink）、`classes/druid/Druid.lua`（cpBuildDkiPoll 先例）、`build.sh`/`build_order.txt`（拼装顺序）。

### 硬门实测记录（本轮独立复跑，全部与规划 pin 一致）

- **整文件 md5**：`e92787b8b042d8994c12477d07fff945` == 要求值 ✓；工作树内容 == 41cc865 blob，审查前无未提交改动。
- **四处冻结带对焊**（`git show 0e3a183:entity/Player.lua` 与现文件按同名锚行取段逐字节 diff）：① pokemonLoad 区（现 497-537 ↔ 旧 605-645）**IDENTICAL**；② cast 头+按压 1 臂+CD 分支（现 539-563 ↔ 旧 647-671）**IDENTICAL**；③ say→classMetatable→return obj（现 626-634 ↔ 旧 746-754）**IDENTICAL**；④ PLAYER_FIELD_FUNC_MAP→EOF（现 893-1098 ↔ 旧 757-END）**IDENTICAL** ✓。
- **Lua 5.0 合规**：`/tmp/luabuild/lua-5.0.3/bin/lua`（权威）、5.1.5/5.4.7（佐证）`loadfile` 三棵全绿 ✓；CRLF 计数 0；新增行（diff 的 `+` 行）无 `#`/`goto`/`::`/`load(` ✓；`git diff --check` clean ✓。
- **逐 tick 单光标动作纪律**（按函数体 sed 段 grep 计数实测）：`pokemonStepPickupBag`/`pokemonStepPickupInventory`/`pokemonStepDepositCursor` 各恰 1 次光标 API；六个 verify handler（SlotEmpty/DepositUnequip/DepositPlain/EquipLoad/EquipRestore/Rollback）各 0 次；dispatch（`pokemonPipelineStep`）2 次（互斥分支各 1）；tick 本体 0 次 ✓。verify 恒排在动作 step 后（enqueue 顺序：动作→verify，depositCursor/verifySlotEmpty 的续接 enqueue 都发生在自身执行之后的返回路径，下一 tick 才被 pump 消费）✓。
- **idle/战斗门**：tick 先 `tableLen==0` 早退（零 API）、后 `UnitAffectingCombat` PAUSE（在 dequeue 之前，步骤不丢）、最后才 dequeue（现 669-682，顺序实测 TICK<U3<RM）✓；load 内顺序实测 Combat pause(408) < Resume pre-scan(418) < Global lock(432) ✓。
- **装配/注册**：`registerPeriodicTask('pokemonPipelineTick', …)` 全文件恰 1 处（684 行）；`build_order.txt` 中 `core/periodic.lua`(6) 先于 `entity/Player.lua`(9) 加载，调用点无 nil 风险；同名键注册幂等（periodic.lua:128 键覆盖），cpBuildDkiPoll（Druid.lua:474）同款先例 ✓。删除的 `equipItemToSlotVerified`/`unequipToBagVerified` 全仓库零调用方残留，`itemLoadingTable`/`pokemonEquipQueue` 无文件外写者 ✓。
- **总体评价**：架构改造方向正确——同帧装备+验证废除（删除的两个助手零残留）、swap/restore 三臂同队列、rollback 双步链、战斗 PAUSE、R-02 的 16 槽唯一触碰路径（grep 核实全部 16 槽触碰都收敛在 repair 快照/VDU 提交的 mainHandItem 两条链上）均成立。**但逐 step 的「abort」语义与队列解耦存在一个可证实的缺口**：pickupBag 的忙光标中止并不中止其后续 `equipCursor`，会在下一次 tick 把玩家光标上的异物装备进目标槽（CR-01）。另有四个边界路径的健壮性缺口（E1 的 1-2 秒 link 滞后 vs 0.1s verify、卸装方向 link 未经取证、cast 键与 in-flight 装载的竞态、恢复目标消失后的全局死锁），详见下节。

### 历史 finding 逐条结论（上次 review-REVIEW.md 的 7 条）

- **CR-01（loadingTable 同槽再装载覆盖摧毁 mainHandItem 恢复状态）**：**化解**。基线 0e3a183 起锁谓词已是收紧后的 `if loadingTable.useableItem then`（任何携带 useableItem 的条目锁新装载，无 used==false 附加条件），本次逐字节保留并实测与基线一致（现 432-439）；且帧拆分后全新条目写入（462/484 行）被「续跑预扫 return → 全局锁 return」双重前置拦断，不再存在「同槽覆盖销毁 mainHandItem」的可达路径。但该收紧锁与恢复失败联动产生新的死锁面，见 WR-04。
- **WR-01（pending 持续失败无出口）**：**部分化解**。castLoadedItem 的 else 支（现 618-621）可清除 pending 条目（出口存在），重试改由队列承载；但「目标物品持续不可装备」时每次按键仍无限重试+失败（无重试上限/回退），且该 else 清除与帧拆分产生新竞态 WR-03。
- **WR-02（SM_Extend.lua 构建产物陈旧）**：**仍存在**（本 quick 只改源文件，产物待用户 `./build.sh` 重建，SUMMARY 已备案 user-side unrun-verify，不重复计为新 finding）。
- **WR-03（遗留 obj.loadUseableItem 死代码共享同一全局表）**：**化解**。现文件已无 `obj.loadUseableItem` 定义（grep 实测 0 处），唯一装载入口为 loadUseableItemToSlot。
- **IN-01（values 字段未校验）**：**仍存在**（见本轮 IN-01）。
- **IN-02（castLoadedItem 尾 return 不可达）**：**仍存在**（重构后等价形态，见本轮 IN-02）。
- **IN-03（vbt 尾带 md5 文档常数不可复现）**：文档归档问题，本次不涉及（本轮四处冻结带常数已全部独立复现，见上）。

---

## Critical Issues

### CR-01: pickupBag 的「忙光标中止」不中止序列——后续 equipCursor 会拿玩家光标上的异物装备进目标槽

**File:** `entity/Player.lua:721-731`（中止分支）、`695-696`（无条件执行的 equipCursor）、配对上肢体：`467-469`/`488-490`（装载两支）、`585-587`/`600-602`（恢复两支）

**Issue:** 注释（719-720 行）承诺「busy cursor or a vanished item aborts the sequence with the pending entry kept for the next press」，但实现只 return 了当前 step。装载键一次按压的入队形状是 `[pickupBag, equipCursor, verifyEquipLoad]` 三步连排，pump 不感知序列边界：tick N 的 `pokemonStepPickupBag` 因 `CursorHasItem()` 为真（玩家正手动拖拽某物品，或此前任一回滚/中断把物品滞留在了光标上——这正是 E3 想消灭的状态）而中止后，tick N+1 的 `EquipCursorItem(step.slot)`（695-696）**照常执行**，把玩家光标上的异物装备进目标槽 13/17：

1. 目标槽空闲且异物可装备到该槽 → 异物被装上，`verifyEquipLoad` 因槽内不是 pokemon 名而报 unconfirmed——玩家装备被静默改写；
2. 目标槽被占用（如恢复臂准备换回原副手时 17 上还挂着 pokemon）→ 客户端 swap：**原占用物被逐入背包、异物上槽**，玩家的原装备位移+错装，且此时若异物品类不合，还会再叠加一次残留；恢复臂（`585-587`/`600-602`）的同款三步排入缺口完全同构。

这是 E3 级光标/装备混乱在本重构中的新生窗口：设计靠「每 tick 恰一个光标动作」挡住同帧多动作，但没有挡住「中止一个动作后，下一个 tick 执行属于同一序列的下一个动作」。物品消失（727-730 支）时 `EquipCursorItem` 空光标为 no-op，无实物损坏，但忙光标支是实体损坏路径。恢复臂中第二步 `equipCursor` 的目标是 swappingSlot/16，损坏面更大。

**Fix:** pickupBag 的两条中止路径必须把本序列的剩余两步（equipCursor + verify，按本文件全部入队点的统一三步形状）从队首排掉，保证「中止 = 序列终了」。Lua 5.0 合法修复：

```lua
function macroTorch.pokemonStepPickupBag(step)
    if CursorHasItem() then
        macroTorch.show('Useable item load unconfirmed: cursor busy, load aborted')
        -- Abort the WHOLE chain: the paired equipCursor must never run
        -- against a foreign cursor item. Every 3-step chain in this file is
        -- enqueued as pickupBag -> equipCursor -> verify*, so drain the
        -- remaining two steps of this chain before returning.
        local q = macroTorch.pokemonQueueEnsure()
        table.remove(q, 1)  -- equipCursor of this chain
        table.remove(q, 1)  -- verify* of this chain
        return
    end
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(step.itemName)
    if not bagId or not slotIndex then
        macroTorch.show('Useable item load failed: ' .. step.itemName .. ' not in bags')
        local q = macroTorch.pokemonQueueEnsure()
        table.remove(q, 1)  -- equipCursor of this chain
        table.remove(q, 1)  -- verify* of this chain
        return
    end
    PickupContainerItem(bagId, slotIndex)
end
```

（如需更稳的长期形态，可为 step 增加序列 id 字段按序排水；当前文件只有齐整的三步/两步链，队首排两步即精确。）

---

## Warnings

### WR-01: 修复臂的「确认拒绝」判别在 E1 的 1-2 秒 link 滞后窗口内可能误触发——装载成功也会把主手 1H 卸进包

**File:** `entity/Player.lua:838-867`（判别门在 859 行）

**Issue:** R-02 名义上的四个触发条件（verify=false、`isItemExist(itemName)`、slot==17、repair 快照非空）在实现里全部以「+1 tick（0.1s）」的 `isItemNameInSlot` 读数为基础。规划事实 E1 自己写明的是「物品 1-2 秒后上链」——若空槽装载方向的 `GetInventoryItemLink` 刷新大于 0.1s，且玩家背包里有同款第二件（本文件 7 表里 `Ancient Cornerstone Grimoire`/`Decoy Dragonling Remote` 均非唯一物品，可持有多份），成功路径会出现以下误判：
1. equip 真实成功（C 场景：1H 主手 + 17 空）→ tick+1 槽 link 仍为空（E1 滞后）→ verify=false；
2. `isItemExist(pokemon)` 为真——真值是**背包里的另一个副本**，并非「被客户端拒绝退回的那件」；
3. 四个门全过 → 修复臂误触发：把玩家主手 1H（repair 快照名）摘进背包、重装背包里的副本 → 主手短暂空置、装备状态无谓振荡。后续虽可由恢复臂两键收敛，但 R-02「修复臂只在 confirmed refusal 触发、不碰 16 槽」的排他语义被打破，且玩家主手武器在 raid 准备期被静默卸下。
即使没有副本，E1 量级下的 0.1s 首验大概率假阴性，导致「一键收敛」退化为必须重按，与 SUMMARY 承诺的 0.3-1.5s 自动收敛不符。副本只是把「假阴性」升级为「假恢复」。

**Fix:** 判别「假拒绝」唯一可靠的信号是时间——在 firing 修复臂之前做延迟复验（例如以 age 计数把 verify 重排 10 个 tick ≈ 1s 后再读一次 link），只有二读仍为 false 且物品在包才 fire。Lua 5.0 合法修复（替换 859-865 的判别段）：

```lua
    -- First doubt is not a confirmed refusal: the empty-slot equip link can
    -- lag by 1-2 s (E1). Re-run this same verify ~1 s later; only a second
    -- consecutive false reading with the item back in the bags is a refusal.
    if step.repair and slot == 17 and macroTorch.isItemExist(step.itemName) then
        step.wait = step.wait or 10
        step.wait = step.wait - 1
        if step.wait > 0 then
            macroTorch.pokemonEnqueue(step)
            return
        end
        macroTorch.pokemonEnqueue({ t = 'pickupInventory', slot = 16, itemName = step.repair })
        macroTorch.pokemonEnqueue({ t = 'verifySlotEmpty', slot = 16, itemName = step.repair, mode = 'twohand',
            targetSlot = slot, useableItem = step.itemName, saying = step.saying })
        macroTorch.show('Useable item load refused: moving the two-handed weapon out of the main hand, retrying')
        return
    end
    macroTorch.show('Useable item load failed to slot ' .. slot .. ': ' .. step.itemName .. ' (unconfirmed, retry next press)')
```

### WR-02: 卸装方向 link 刷新未经取证——verifySlotEmpty 失败支会让物品永久滞留在光标上

**File:** `entity/Player.lua:746-753`（verifySlotEmpty）、`736-742`（pickupInventory）

**Issue:** `pokemonStepVerifySlotEmpty` 以「槽 link 不含 itemName」作为 lift 成功的唯一判据；失败即 show + return，序列终了——而此刻若 lift 实际已成功（纯卸装臂的 pokemon、修复臂的两手武器都在玩家**光标上**），队列里已无任何后继 step 会消费光标：物品滞留光标，条目保留。1.12 取证只覆盖了「装载方向」的 link 滞后（E1：加装成功后 1-2s 才上链）与「占用槽 swap」方向（E2）；**槽变空（卸载方向）的 link 刷新滞后与否从未取证**。若卸载方向与 E1 对称（同属服务端确认后的本地模型刷新），「装进背包再等验证」的纯卸装/修复 deposit 链会在第一验就假失败并把物品留在光标上（E3 复发形态），且重按也无法解除（重按链的 pre-check `isItemNameInSlot` 因 link 依旧滞真而全部走错支）。pickupInventory 本身也没有光标前置守卫（736-742 只查槽名），无从区分「光标是刚 lift 的本物还是异物」。

**Fix:** 用光标状态作为 lift 成功的确定性判据（游标操作在 1.12 是本地即时生效），并给 pickupInventory 补光标空前置守卫。两步配合后 `CursorHasItem()` 真即等价于「本物已上光标」。Lua 5.0 合法修复：

```lua
function macroTorch.pokemonStepPickupInventory(step)
    if CursorHasItem() then
        macroTorch.show('Useable item load unconfirmed: cursor busy, retry next press')
        return
    end
    if not macroTorch.player.isItemNameInSlot(step.slot, step.itemName) then
        macroTorch.show('Useable item load unconfirmed: slot ' .. step.slot .. ' no longer holds ' .. step.itemName)
        return
    end
    PickupInventoryItem(step.slot)
end

function macroTorch.pokemonStepVerifySlotEmpty(step)
    -- Cursor ops mutate the local model immediately; the slot link can lag
    -- (E1-class latency, removal direction never forensically pinned). With
    -- the pickupInventory cursor guard above, a busy cursor here IS the
    -- lifted item - proceed. Only stop the chain when the cursor is empty.
    if not CursorHasItem() and macroTorch.player.isItemNameInSlot(step.slot, step.itemName) then
        macroTorch.show('Useable item load unconfirmed: failed to lift ' .. step.itemName .. ' from slot ' .. step.slot)
        return
    end
    macroTorch.pokemonEnqueue({ t = 'depositCursor', fromSlot = step.slot, itemName = step.itemName, mode = step.mode,
        targetSlot = step.targetSlot, useableItem = step.useableItem, saying = step.saying })
end
```

### WR-03: castLoadedItem 的 else 重置支会清掉 in-flight 装载条目——deferred verify 带来的新竞态，swap 上下文/修复上下文可被永久抹除

**File:** `entity/Player.lua:618-621`（else 重置支）、`838-857`（promote 重建条目时只写 useableItem/used/saying）

**Issue:** else 支的语义是「useableItem 条目对应的物品已不在槽上→重置条目」，它是为**已 verify 完成的**条目写的。帧拆分后，装载按键与 verify 提级之间出现 0.3-1.5s 的 in-flight 窗口：此时条目形状是 `{pendingEquip=..., pendingSaying=..., (swap 支还有 swappingItem=...)}`、`useableItem=nil`——castLoadedItem 的配对键 `loadingTable.useableItem`（545 行）判伪，直接落入 else 支把条目清空。随后 verifyEquipLoad 照常跑：装备已落地 → promote 重建条目（841-853 行只写 useableItem/useableItemUsed/saying），**swappingItem / mainHandItem 从此不复存在**：
- swap 支：装载时被顶出的原副手（swappingItem）已进背包，之后恢复臂退化为纯卸装臂，原副手永远不被换回；
- 修复链中途：VDU 的提交门（805-809 行 `if itemLoadingTable and itemLoadingTable[step.targetSlot]`）因条目被清而静默跳过，两手武器进了背包却没记下 mainHandItem——恢复臂退化为纯卸装，两手武器永远滞留背包。
基线（0e3a183）里装载/验证同帧完成，按键间不存在这个窗口，这是本重构引入的新竞态。

**Fix:** else 支只清「已 verify 完成且物品不在槽」的条目，放过携带 pendingEquip 的 in-flight 条目。Lua 5.0 合法修复：

```lua
                else
                    -- sth got wrong, just reset - only for verified entries.
                    -- An in-flight (pending) load is owned by the queue; the
                    -- deferred verify will promote it in the next ticks.
                    if not loadingTable.pendingEquip then
                        macroTorch.itemLoadingTable[swappingSlot] = nil
                    end
                end
```

### WR-04: 恢复目标从背包消失 = 全局死锁——verifyEquipRestore 永不收敛、收紧后的全局锁把装载键永久封死

**File:** `entity/Player.lua:871-881`（verifyEquipRestore 失败保留条目）、`432-439`（全局锁）+ 三个入队点 `585-587`/`600-602`/`612-613`

**Issue:** 恢复三臂的目标物品（swappingItem / mainHandItem）若在装载与恢复之间被玩家售出/存入银行/销毁（都在背包里，随时可被操作——装载后它们就躺在包里），恢复链每次按键都走「pickupBag『not in bags』中止 → equipCursor 空光标 no-op → verifyEquipRestore 失败保留条目」的循环，**永不收敛**；而上轮 CR-01 的收紧锁（432-439：任何 useableItem 条目锁新装载）使该循环成为全局死锁：装载键从此只能打印 "A usable item is already loaded"，唯一的出口是玩家手动把 pokemon 取下再按 cast（触发 else 支）。基线同样保留失败条目，但当时锁形同虚设（used 判定）且有同帧助手兜底；收紧锁落地后，这个「无上限重试 + 不可解除锁定」组合是新形成的用户可见死锁面。

**Fix:** verifyEquipRestore 失败时，若目标物品既不在目标槽也不在任何背包中（真正消失），清除条目并提示回退到手动恢复，打破死锁。Lua 5.0 合法修复：

```lua
function macroTorch.pokemonStepVerifyEquipRestore(step)
    if macroTorch.player.isItemNameInSlot(step.slot, step.backItem)
            and not macroTorch.player.isItemNameInSlot(step.goneSlot, step.goneItem) then
        if macroTorch.itemLoadingTable then
            macroTorch.itemLoadingTable[step.goneSlot] = nil
        end
        macroTorch.show(step.okMsg)
        return
    end
    -- The restore target may have vanished (sold / banked / destroyed) while
    -- it sat in the bags; an unrestorable entry would lock the load key
    -- forever behind the global lock. Verify it is truly gone (neither in
    -- its slot nor in any bag) before dropping the state.
    if not macroTorch.player.isItemNameInSlot(step.slot, step.backItem)
            and not macroTorch.isItemExist(step.backItem) then
        if macroTorch.itemLoadingTable then
            macroTorch.itemLoadingTable[step.goneSlot] = nil
        end
        macroTorch.show(step.failMsg)
        return
    end
    macroTorch.show(step.failMsg)
end
```

---

## Info

### IN-01: 装载表入口仍只校验 keys/toSlots，未校验 values（上轮 IN-01 沿用）

**File:** `entity/Player.lua:400-403`（校验）、`442`（取值）

**Issue:** 若自定义调用方传入缺 `values` 的表，`useableItem` 为 nil → `hasItem(nil)` → `string.find(n, nil)` 运行时错误。当前唯一调用方 pokemonLoad 数据完整，不可触达；仅健壮性缺口备案。

**Fix:** 入口补 `or not useableItemsTable.values` 判空报错返回，与 keys/toSlots 一致。

### IN-02: castLoadedItem 恢复臂后的 `return` 不可达（上轮 IN-02 的等价形态）

**File:** `entity/Player.lua:617`

**Issue:** 恢复臂结构改变后，564-616 的所有分支（combat 571 / swap 583、588 / mainHand 598、603 / plain 610、614）均提前 return，`useableItemUsed` 在进入该段前恒为 true（CD 支也置 true 后落穿），617 行防御性 return 为死代码。无害，随维护清理即可。

**Fix:** 删除 617 行（或保留，不阻塞）。

### IN-03: saying 的 `isNumber` 守卫与 verify 失败提示存在历史遗留与噪音

**File:** `entity/Player.lua:851`（isNumber 守卫）、`866`/`880`（失败提示重入）

**Issue:** `if step.saying and not macroTorch.isNumber(step.saying)` 是从 20c 沿用的旧防御（saying 恒为字符串常量），语义上已无意义；且反复按键收敛期间的「unconfirmed/failed」show 提示在真假阴性窗口（WR-01 的滞后窗）内会每按键重复刷屏，可按需静默重试轮次。

**Fix:** saying 守卫可简化为 `if step.saying then`；失败提示可在延迟复验（WR-01 Fix）落地后自然收敛，无需额外改动。

---

_Reviewed: 2026-10-19T15:55:05Z_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
