---
quick_id: 260817-sg1
slug: simplify-macrotorch-log-persistence-stor
date: 2026-08-17
status: complete
---

# Quick Task 260817-sg1: Simplify macroTorch.log Persistence Format Summary

**One-liner:** Changed macroTorch.log() persistence from `{msg, color}` table to plain string to simplify stored log format.

## What Was Done

Modified `interface_debug.lua` line 114 to store a plain string instead of a table in the MACRO_TORCH_LOG SavedVariable.

**Before:**
```lua
table.insert(messages, { msg = tostring(a), color = color or 'white' })
```

**After:**
```lua
table.insert(messages, tostring(a))
```

Each persistent log entry now stores a simple string instead of a JSON object with `msg` and `color` fields.

## Key Files

| File | Action |
|------|--------|
| `interface_debug.lua` | Modified line 114 |

## Verification

- Confirmed MACRO_TORCH_LOG has no external consumers -- only used within `interface_debug.lua`
- The `messages` array is iterated for display via SavedVariables mechanism; string format is compatible
- Color information was not used by any downstream consumer

## Decisions

- No architectural decisions required -- this is a straightforward simplification of an internal data structure

## Deviations from Plan

- **Base check mismatch (procedural):** The worktree was forked from `origin/main` at `a627b5d` before the PLAN.md commit `b847061` was pushed. Zero source code divergence exists between the fork point and expected base (only the PLAN.md file differs). Execution proceeded since the code change target was identical at both commits.

## Commit

- `5ff2233`: `fix(260817-sg1): simplify log persistence to store plain string instead of {msg, color} table`