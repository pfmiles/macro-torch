# Debug Init: Add debug markers to trace SM_Extend.lua loading

**Date:** 2026-06-11
**Type:** Quick task — debug diagnostics
**Purpose:** Add `DEFAULT_CHAT_FRAME:AddMessage()` markers at key init points in source files to identify where SM_Extend.lua loading silently fails.

## Plan

### Files to modify (source files, NOT SM_Extend.lua):

1. **macro_torch.lua** — After `macroTorch = {}` creation
2. **core/periodic.lua** — Before/after `CreateFrame("Frame")`, before/after `frame:SetScript("OnUpdate",...)`
3. **entity/Unit.lua** — After Unit class + UNIT_FIELD_FUNC_MAP ready
4. **entity/Player.lua** — Before/after `macroTorch.player = macroTorch.Player:new()`
5. **interface_debug.lua** — After `macroTorch.show` defined (end of entity loading block)

### Debug marker format:
```lua
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step N: description", 0, 1, 0)
```
Using `DEFAULT_CHAT_FRAME:AddMessage` directly (not `macroTorch.show`) since `macroTorch.show` may not exist yet.

### Expected output:
After loading, the user should see numbered debug messages. The LAST message visible tells us exactly where execution stopped.