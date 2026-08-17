---
phase: 260817-sg1
reviewed: 2026-08-17T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - interface_debug.lua
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 260817-sg1: Code Review Report — interface_debug.lua

**Reviewed:** 2026-08-17
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed the simplification of `macroTorch.log` persistence format at line 114: changing `table.insert(messages, { msg = tostring(a), color = color or 'white' })` to `table.insert(messages, tostring(a))`. One finding requires attention (subsequent-change data migration). No blockers — the change is behaviorally correct given zero code-level consumers of `MACRO_TORCH_LOG.messages`.

## Warnings

### WR-01: No migration path for pre-existing SavedVariable data

**File:** `interface_debug.lua:114`
**Issue:** The change drops the `{msg, color}` table wrapper, storing plain strings. When a user upgrades from a version that wrote the old format, `MACRO_TORCH_LOG.messages` will contain a mix of table entries (old) and string entries (new) loaded from the SavedVariables file. No Lua code reads `messages` today, so this is not a crash risk, but it creates a silent data-format inconsistency. If future code ever iterates `messages` (e.g., a log viewer feature), it would need to handle both shapes.

**Fix:** If a reader of `messages` is ever introduced, add a one-time migration at initialization. For now, no action required — this serves as documentation of the known mixed-format edge.
```lua
-- Optional: one-time migration guard at file level
if MACRO_TORCH_LOG and MACRO_TORCH_LOG.messages then
    for i, entry in ipairs(MACRO_TORCH_LOG.messages) do
        if type(entry) == "table" then
            MACRO_TORCH_LOG.messages[i] = entry.msg or tostring(entry)
        end
    end
end
```

## Info

### IN-01: `color` parameter partially consumed — display honored, persistence dropped

**File:** `interface_debug.lua:103`
**Issue:** `macroTorch.log(a, color)` still accepts `color` and passes it to `macroTorch.show(a, color)` for in-chat display (line 109), but the stored entry no longer captures it. Callers passing a color will see correct display but not persist that color. The sole caller (`core/events.lua:160`) omits color, so this is not a current defect, but the partial consumption is a subtle API contract change worth documenting.

**Fix:** Add a comment noting that `color` controls chat-frame rendering only, not persistence.
```lua
---@param color string 可选颜色（仅影响聊天框显示，不持久化到日志）
```

### IN-02: `'green'` color mapping produces teal, not green (pre-existing)

**File:** `interface_debug.lua:93-94`
**Issue:** The `'green'` branch constructs `c = { r = 0, g = 0.5, b = 0.9, id = 'custom_green' }`. The combination `g = 0.5, b = 0.9` with `r = 0` yields RGB(0, 128, 230) — a blue-leaning teal/azure, not green. A true green would use `g = 1.0` or at least `g = 0.7` with `b = 0`. This is pre-existing and unrelated to the reviewed change.

**Fix:**
```lua
c = { r = 0, g = 1.0, b = 0, id = 'custom_green' }
```
Or for a darker, more readable green in WoW's chat frame:
```lua
c = { r = 0, g = 0.7, b = 0, id = 'custom_green' }
```

### IN-03: `'red'` color maps to `YELL` chat type — naming mismatch (pre-existing)

**File:** `interface_debug.lua:87-88`
**Issue:** The string `'red'` is mapped to `ChatTypeInfo["YELL"]`. While the `YELL` channel in WoW does render in a red/pink hue, the indirection is confusing. A reader scanning the code sees `'red'` with `YELL` and must know WoW internals to understand why. Same pattern applies to `'yellow' -> SYSTEM` and `'blue' -> OFFICER`. Pre-existing; not introduced by this change.

**Fix:** Consider adding a comment clarifying the intent, or renaming the color keys to match the channel semantics.

---

_Reviewed: 2026-08-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_