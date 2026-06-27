---
quick_id: 260627-g4j
description: 修复 spell_trace_immune.lua 日志问题
status: complete
---

## Summary

修复了 `core/spell_trace_immune.lua` 中的两个日志问题：

### 问题 1: 日志与实际动作不一致
- **修复前:** `spellsImmuneTracing` 中 line 44/56 的 "recording immune by fail/land event" 日志在 `recordImmune` 执行前就打印了。当 `recordImmune` 内部因记录已存在而静默跳过时，日志声称"正在记录"但实际什么都没写入。
- **修复后:** 删除这两行 premature 日志。`recordImmune` 内部的日志 "Spell: X is recorded IMMUNE to Y" 只在确实写入时输出，准确反映实际行为。

### 问题 3: Land event 日志缺少法术名
- **修复前:** land event 日志 `"recording immune by land event: " .. landEvent` 只有时间戳，无法定位是哪个法术。
- **修复后:** 与问题 1 一起删除。`recordImmune` 的日志已包含完整法术名称。

**变更文件:** `core/spell_trace_immune.lua` — 删除 2 行日志
**Commit:** fef6f2f