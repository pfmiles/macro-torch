---
description: 将 _castSpell 的默认 mode 从 ready 改为 safe，同步更新所有调用点
---

# Plan: _castSpell 默认 mode → safe

## 改动内容

### 1. 核心：`entity/Player.lua` — `_castSpell` 方法

- 注释行 35: 更新 mode 说明
- 行 58: `if mode == 'safe'` → `if mode ~= 'ready' and mode ~= 'raw'`（让 nil 默认走 safe 路径）

### 2. 移除 `'safe'` 显式参数（22 处）

新默认即为 safe，无需显式传。

| 文件 | 行号 |
|------|------|
| classes/druid/Druid.lua | 387 |
| classes/druid/cat.lua | 53, 59 |
| classes/druid/combo.lua | 8, 10, 12, 56, 58, 60, 64, 68, 71, 104 |
| classes/druid/bear.lua | 27, 33, 48, 53, 80 |
| classes/hunter/combat.lua | 39, 40, 47, 48 |

### 3. 添加显式 `'ready'` 参数（35 处）

原来不传 mode 依赖默认=ready，现在默认改 safe 了，需显式声明。

| 文件 | 行号 |
|------|------|
| classes/druid/Druid.lua | 390 |
| classes/druid/cat.lua | 18, 51, 57 |
| classes/druid/utility.lua | 4, 7, 10 |
| classes/hunter/combat.lua | 44, 72 |
| classes/mage/combat.lua | 27, 39 |
| classes/priest/combat.lua | 30 |
| classes/priest/utility.lua | 55, 57 |
| classes/rogue/combat.lua | 43, 68, 70, 71, 104, 151, 153, 154 |
| classes/warrior/combat.lua | 25, 52, 56, 73, 75, 92, 145 |
| classes/warrior/utility.lua | 28, 49, 55, 64, 73, 76 |

### 4. 无需改动

- 已显式 `'ready'` 的 21 处
- 已显式 `'raw'` 的 2 处