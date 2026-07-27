---
status: complete
description: Defer SelfTest:run() execution from PLAYER_ENTERING_WORLD to next OnUpdate frame to fix computeReshiftEnergy session-persistent failure
---

## Problem

`computeReshiftEnergy()` returns 40 on first login (missing Wolfsheart +20), returns correct 60 after `/reload`. The failure persists for the entire session.

## Root Cause

`SelfTest:run()` runs synchronously during `PLAYER_ENTERING_WORLD` (core/events.lua:52), before UI subsystems (tooltip, inventory) are fully initialized. The first call to `computeReshiftEnergy()` within self-test creates `_tooltipScanFrame` (GameTooltip) in an incomplete environment. This "bad state" frame is cached and reused for the entire session.

After `/reload`, the tooltip subsystem is already warmed up, so the frame is created healthy.

## Fix

In `core/events.lua`, defer `SelfTest:run()` to the next OnUpdate frame using a cached frame object:

```lua
elseif event == 'PLAYER_ENTERING_WORLD' then
    macroTorch.onPlayerEnteringWorld()
    if not macroTorch._selfTestRan then
        macroTorch._selfTestFrame = macroTorch._selfTestFrame or CreateFrame("Frame")
        macroTorch._selfTestFrame:SetScript("OnUpdate", function(self)
            macroTorch.SelfTest:run()
            self:SetScript("OnUpdate", nil)
        end)
    end
```

## Files Changed

- `core/events.lua` — defer SelfTest:run() to next OnUpdate frame