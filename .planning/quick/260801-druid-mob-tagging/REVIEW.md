---
status: fixed
files_reviewed: 1
critical: 0
warning: 1
info: 3
total: 4
fixed: 1
skipped: 3
depth: standard
reviewed_at: 2026-08-01
fixed_at: 2026-08-02
---

## 审查摘要

审查 `classes/druid/combo.lua` 中新增的 `macroTorch.druidMobTagging(rough)` 函数（第 346-401 行）及自测注册（第 441-444 行）。

**整体评价：** 代码质量良好，结构清晰，与现有代码模式一致。未发现严重 bug。1 个 Warning 和 3 个 Info 级别发现。

---

## 发现列表

### WR-01: 人形态路径缺少目标校验（Warning）

- **文件:** `classes/druid/combo.lua`
- **行号:** 351-355
- **分类:** correctness

**问题描述：**

人形态分支在施放 Moonfire 之前未校验目标有效性。猫/熊形态分支（第 358-364 行）有完整的 `target.isCanAttack`、`target.distance > 30`、`target.isPlayerControlled` 校验和 PvP 玩家过滤，但人形态分支直接 `moonfire('ready')` 后调用 `druidAtk(rough)` 并 return。

**风险场景：**

如果在 PvP 区域以人形态运行此宏，且当前目标为 PvP 玩家，会直接对其施放 Moonfire，触发 PvP 标记。PLAN.md 和 SUMMARY.md 均提到"排除 PvP 玩家"作为设计目标。

**修复建议：**

在人形态分支开头添加目标校验，或将其移到人形态判断之前作为公共逻辑：

```lua
-- 公共目标校验（移到人形态判断之前）
if target.isCanAttack and target.isPlayerControlled then
    ClearTarget()
    return
end
```

**严重程度：** Warning — 仅影响 PvP 区域人形态场景，实际触发概率低（mob tagging 通常在动物形态下使用）。

**修复结果：** ✅ **已修复 (2026-08-02)** — 在人形态 Moonfire 施放前增加 `target.isPlayerControlled` → `ClearTarget()` 过滤，与猫/熊路径 PvP 过滤逻辑一致。

---

### IN-01: 缺少 Moonfire 法术存在性检查（Info）

- **文件:** `classes/druid/combo.lua`
- **行号:** 352
- **分类:** consistency

**问题描述：**

`player.moonfire('ready')` 未使用 `macroTorch.isSpellExist('Moonfire', 'spell')` 进行前置检查。同函数内 Maul（第 383 行）和 Faerie Fire (Feral)（第 396 行）均有此防御性检查。

**风险评估：** Moonfire 是德鲁伊 4 级基础技能，实际不可能缺失。仅风格一致性问题。

**修复结果：** ⏭️ **跳过** — 验证为误报。Moonfire 100% 存在，`isSpellExist` 检查无实际收益。

---

### IN-02: 缺少 Claw 法术存在性检查（Info）

- **文件:** `classes/druid/combo.lua`
- **行号:** 377
- **分类:** consistency

**问题描述：**

`player.claw('ready')` 未使用 `macroTorch.isSpellExist('Claw', 'spell')` 进行前置检查。与同函数内 Maul/FF(Feral) 的防御模式不一致。

**风险评估：** Claw 是猫形态 1 级基础技能，实际不可能缺失。仅风格一致性问题。

**修复结果：** ⏭️ **跳过** — 验证为误报。Claw 100% 存在，`isSpellExist` 检查无实际收益。

---

### IN-03: druidCharge() 调用后形态可能改变（Info）

- **文件:** `classes/druid/combo.lua`
- **行号:** 391-399
- **分类:** design-note

**问题描述：**

在 5-30yd 引怪区路径中（第 391 行），猫形态下调用 `druidCharge()` 会切换到熊形态（druidCharge 内部检测到非熊形态会变身并 return）。之后继续执行 `faerie_fire_feral('ready')` 和 `druidAtk(rough)`，此时 druidAtk 会走 `bearAtk(rough)` 而非 `catAtk(rough)`。

**影响：** 猫形态玩家在 5-30yd 距离引怪后会变成熊形态继续输出。这在功能上是合理的（猫无冲锋技能，切熊冲锋是唯一快速贴脸手段），但行为与函数名 "MobTagging"（抢完怪后预期继续猫形态输出）有微妙偏差。

**建议：** 无需修改，可在注释中补充说明此行为。

**修复结果：** ⏭️ **跳过** — 验证为误报。猫形态切熊冲锋是 PLAN.md 明确设计意图，注释已充分说明。

---

## 正面评价

- ✅ 纯新增函数，不修改任何已有逻辑
- ✅ 正确复用 `druidCharge()`、`druidAtk()` 等已有模块
- ✅ 对 Maul 和 FF(Feral) 做了防御性 `isSpellExist` 检查
- ✅ 自测注册完整（第 441-444 行）
- ✅ 注释清晰，中英文混合风格与项目一致
- ✅ 决策树实现与 PLAN.md 一致