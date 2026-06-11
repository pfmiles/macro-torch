---
quick_id: 260612-1rj
slug: fix-hash-length-operator
status: complete
date: 2026-06-11
---

# Summary: 修复 # 取 table 长度符号不被 WoW 1.12 Lua 支持的问题

## 修改内容

- `core/periodic.lua:111`: `expired[#expired + 1] = name` → `table.insert(expired, name)`
- 提交: `55bd22b` — fix: replace unsupported # length operator with table.insert in periodic.lua

## 分析结论

全代码库仅有 `core/periodic.lua` 1 处使用了 `#` 长度运算符，其余文件均已使用 `macroTorch.tableLen()` 或 `table.insert` 替代。