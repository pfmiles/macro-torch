---
phase: quick-260914-0ql
reviewed: 2026-09-13T17:01:29Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/cat.lua
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase quick-260914-0ql: Code Review Report

**Reviewed:** 2026-09-13T17:01:29Z
**Depth:** standard
**Files Reviewed:** 1（`git diff e776e98^..e776e98 -- classes/druid/cat.lua` 精确锁定 +6/−0；e776e98..HEAD 之间仅 .planning 文档提交，cat.lua 未再触碰）
**Status:** issues_found

## Summary

对 feature commit `e776e98`（"feat(cat): cp5Bite skips discharge when rake <=1.3s (bite renews rake)"）的 6 行纯插入按 standard depth 审查，交叉核验了 `classes/druid/Druid.lua` 的 `isRakePresent`/`rakeLeft`/`computeRake_Duration`/FB 续期监听器与 `core/selftest.lua` 的 P 系列 stub（后者为上下文读取，非审查目标）。

**验证通过的核心口径（无发现，仅陈述佐证）：**

1. **变更面与锁定约束**：`git diff e776e98^..e776e98 --numstat` = `6 0 classes/druid/cat.lua`——恰 1 文件、6 插入、0 删除。新块位于 cat.lua:139-143，与 PLAN 锁定约束 3 逐字一致（8 空格缩进、英文注释、块前空行、与 rip 块 135-137 严格同构）。
2. **条件自身健全性**：`rakeLeft` 恒返回数字（Druid.lua:1428-1444：无 land 事件时 0，否则 `computeRake_Duration - (GetTime - lastLand)` 且截断到 0 下限，不可能 nil/非有限数）；`isRakePresent` 为真时，同一条 `and` 链已先求值过 `rakeLeft > 0`（Druid.lua:1361-1362），故 `rakeLeft(clickContext) <= 1.3` 必然是已 memoize 的 number <= number 比较——Lua 5.0 无混合类型比较报错面。有效触发窗口 (0, 1.3]，与 PLAN 口径 `∈ (0,1.3]` 吻合。
3. **链上短路互作**：`shouldDischarge and` 前缀保证伪无限能量门（cat.lua:130-132）置 false 后两个流血门都不再调用 helper（PLAN 约束 4 达成，无额外 `rakeLeft` 调用）；rip 门先触发时 rake 门的 helper 调用整体跳过——两门都是纯 false 置位器，顺序对结果无影响。
4. **下游路径**：`shouldDischarge = false` 时跳过 `if shouldDischarge then` 块（含 ooc 泄能），进入 ooc → readyBite / else safeBite——与 rip 门既有下游画像完全一致；与 `isDischarged` 重入去重无冲突；`energyDischargeBeforeBite` 的 rake 补挂回退分支（cat.lua:190）前置 `not isRakePresent`，与新门（前置 isRakePresent）互斥、零碰撞。
5. **设计模型一致性**：FB 落地续期监听器（Druid.lua:952-968）用全新 `{}` clickContext 在落地时重判 in-fight 状态并 `recordLandEventRenewal` 以满时长快照重启时钟，符合 WoW 1.12 "bite 刷新在场 rake/rip" 机制；fast battle 天然免疫已确认（D-05 keepRake 门 cat.lua:374：fast battle 不施放 rake → isRakePresent 恒 false → 新门不触发）。
6. **Lua 5.0 / 格式门独立复验**：锚点 grep 均唯一（`Check Rake duration` ×1、`rakeLeft <= 1.3` ×1、`ripLeft <= 2.3` ×1）；CRLF 字节数 0（LF 干净）；插入行 CJK 计数 0；新行无 `#`/`goto`/`::` token。

唯一发现是一条**测试交互类 Warning**：既有的 Category P 回归测试 P-03 未 stub `rakeLeft`，新门在登录自测环境会以真实 `rakeLeft`（恒 0）触发并绕过该测试刻意保留的真实 `energyDischargeBeforeBite` 路径——测试仍绿，但其守护的 no-condition fall-through 回归 pin（quick 260825-vp9 泄能洞 A/B 修复的存活证明）被静默架空。生产逻辑本身无 bug：新条件、短路由、阈值与续期模型全部正确。

## Warnings

### WR-01: P-03 自测未 stub `rakeLeft`，新门在登录环境静默架空其守护的 fall-through 回归 pin

**File:** `classes/druid/cat.lua:141`（新 Rake 门）与 `core/selftest.lua:864-904`（"P: cp5Bite still bites when no discharge condition matches"）

**Issue:** 该测试（quick 260825-vp9 存根）stub 了 `isRipPresent→true`（872 行）、`ripLeft→4`（873 行）、`isRakePresent→true`（874 行），但**未 stub `rakeLeft`**。新门求值顺序为 `isRakePresent(stub true) and rakeLeft(…真实实现)`，于是真实 `rakeLeft` 被调用：登录自测环境无攻击目标 → `peekLandEvent('Rake')` 在 `not macroTorch.target.isCanAttack` 处直接返回 nil（spell_trace_core.lua:757-759）→ `rakeLeft = 0`（Druid.lua:1430-1432）→ `0 <= 1.3` 成立 → 新门置 `shouldDischarge = false` → cat.lua:145 的 `if shouldDischarge then` 整体跳过，**该测试刻意保留的真实 `energyDischargeBeforeBite`（注释 858-863 明言 "The discharge helper stays real; mana is pinned"）不再被调用**。测试仍绿（safeBite stub 置 biteCalled → 断言 pass），但它要覆盖的"真实排水函数无排水条件时 cp5Bite 仍应咬出"这条 fall-through 路径已被新门短路绕过——泄能洞 A/B 若未来回归，此测试将静默失明；同时 mana=50 影子锚定（50 < BITE_E+CLAW_E = 80 的精心布点）变为死代码。

同类现象（同一条发现内备案）：P-02（"defers the bite when a discharge is attempted"，822-854 行）经新门首次在 cp5Bite 链上触达**真实 `isRakePresent`**（该测试未 stub）；今日环境下安全（登录无目标 → `UnitDebuff('target', i)` 全 nil → `hasBuff` 恒 false → 门不开），但同属"P 系列 stub 未覆盖新门依赖"的一类隐患。

**Fix:** 为 P-03 补 `rakeLeft` stub 并 restore，保持测试原设计场景（rake 在场且新鲜 → 新门不触发、真实排水函数走 no-condition fall-through）：

```lua
    local origIsRakePresent = macroTorch.isRakePresent
    local origRakeLeft = macroTorch.rakeLeft          -- NEW
    ...
    macroTorch.isRakePresent = function(clickContext) return true end
    macroTorch.rakeLeft = function(clickContext) return 9 end   -- NEW: keep rake fresh so the 1.3s gate stays open
    ...
    macroTorch.isRakePresent = origIsRakePresent
    macroTorch.rakeLeft = origRakeLeft                -- NEW
```

注意：此修复触碰 `core/selftest.lua`（第二文件），超出本 quick 任务"仅改 cat.lua"的锁定范围；PLAN 备案段本已预留"另开 quick 任务加 rake stub 自测"的口径——建议该后续任务按此思路**先修复 P-03 既有 pin，再新增 rake 将到期的新 pin**（PLAN 备案只预见了新 pin，未发现 P-03 已受新门影响）。

---

_Reviewed: 2026-09-13T17:01:29Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_