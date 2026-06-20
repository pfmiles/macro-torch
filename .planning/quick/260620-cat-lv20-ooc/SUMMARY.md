---
quick_id: 260620-uun
slug: cat-lv20-ooc
status: complete
date: 2026-06-20
---

## 变更内容

修改 `classes/druid/leveling.lua` 中的 `cat_lv20()` 函数：
- 在 Rip/Claw 决策逻辑前增加 ooc（Omen of Clarity / 清晰预兆）判定
- ooc 触发时直接使用 Claw（免费施放），无需判断 Rip 条件
- 其余逻辑保持不变

## 提交

`a775068` feat(druid): add ooc handling to cat_lv20 — prioritize Claw on Omen of Clarity proc