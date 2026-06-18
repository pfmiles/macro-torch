---
status: complete
description: 将 _castSpell 默认 mode 从 ready 改为 safe
date: 2026-06-18
---

# Summary: _castSpell 默认 mode → safe

## 改动

- **核心**: `entity/Player.lua:58` — `if mode == 'safe'` → `if mode ~= 'ready' and mode ~= 'raw'`，使 `nil` 默认走 safe 检查
- **移除 `'safe'` 显式参数**: 22 处 (Druid 18 + Hunter 4)
- **添加显式 `'ready'` 参数**: 35 处 (Druid 7 + Hunter 2 + Mage 2 + Priest 3 + Rogue 8 + Warrior 13)

## 验证

- `./build.sh` 构建通过
- 所有 `player.method('safe')` 调用已移除
- 所有原无 mode 调用已显式标注 `'ready'`