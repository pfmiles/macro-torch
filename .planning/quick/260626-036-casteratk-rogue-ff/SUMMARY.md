---
status: complete
quick_id: 260626-036
slug: casteratk-rogue-ff
completed_at: 2026-06-26T00:05:00Z
---

# casterAtk 盗贼精灵之火优先

## 改动

在 `classes/druid/combo.lua` 的 `casterAtk()` 函数中，`isCanAttack` guard 之后插入盗贼 FF 优先检查：

```lua
-- 目标为盗贼时，优先挂精灵之火防止潜行/消失，优先级高于一切
local targetClass = macroTorch.target.class
if (targetClass == 'Rogue' or targetClass == '盗贼')
        and not macroTorch.target.buffed('Faerie Fire', 'Spell_Nature_FaerieFire') then
    macroTorch.player.faerie_fire()
    return
end
```

## 决策优先级

| 条件 | 动作 | 优先级 |
|------|------|--------|
| 目标不可攻击 | return | guard |
| **目标为盗贼 + 无FF** | **FF** ← **新增** | **最高** |
| 未进战 | Wrath 开怪 | 高 |
| 无月火 | Moonfire | 中 |
| 无精灵之火 | Faerie Fire | 中 |
| 无虫群 | Insect Swarm | 中 |
| 星火→愤怒循环 | 循环 | 低 |

## 设计考量

- FF 瞬发 vs Wrath 读条：盗贼可以在 Wrath 读条期间潜行，FF 瞬发确保先手
- 双语类名检查：`Rogue` / `盗贼`，兼容英文/中文客户端
- 仅无 FF 时触发：如果已有 FF debuff 则跳过，避免浪费 GCD

Commit: `4ba8df4`