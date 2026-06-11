---
slug: fix-hash-length-operator
date: 2026-06-11
quick_id: 260612-1rj
---

# Plan: 修复 # 取 table 长度符号不被 WoW 1.12 Lua 支持的问题

## 问题

WoW 1.12.1 的 Lua 版本不支持 `#` 长度运算符。代码库中有 1 处使用了该运算符：

- `core/periodic.lua:111` — `expired[#expired + 1] = name`

## 修改方案

将 `expired[#expired + 1] = name` 替换为 `table.insert(expired, name)`。

`table.insert` 是 WoW 1.12.1 Lua API 原生支持的函数，语义完全等价，且项目其他地方已在广泛使用。

## 影响范围

- 修改文件：`core/periodic.lua`（1 行）
- 无其他文件受影响