---
status: complete
summary: Deferred SelfTest:run() from synchronous PLAYER_ENTERING_WORLD to next OnUpdate frame, preventing GameTooltip creation in an incomplete UI environment that caused persistent Wolfsheart detection failure.
---

## Summary

- **Problem**: `computeReshiftEnergy()` returned 40 on first login (missing +20 from Wolfsheart head enchant), returned correct 60 only after `/reload`. Failure persisted for the entire session.

- **Root Cause**: `SelfTest:run()` ran synchronously during `PLAYER_ENTERING_WORLD`, before UI subsystems were fully initialized. `computeReshiftEnergy()` called within self-test created `_tooltipScanFrame` (GameTooltip) in a bad state that persisted for the session.

- **Fix**: Deferred `SelfTest:run()` to the first OnUpdate tick after `PLAYER_ENTERING_WORLD` using a cached frame. The frame is created once and reused across zone transitions; `_selfTestRan` guard prevents duplicate scheduling.

- **Files Changed**:
  - `core/events.lua` — replaced synchronous `SelfTest:run()` with OnUpdate-deferred execution
  - `biz_util.lua` — removed speculative AI-generated comments about tooltip Hide/Show behavior

## How to Verify

1. Completely exit game and restart
2. Enter cat form after login
3. Run `/script DEFAULT_CHAT_FRAME:AddMessage("Reshift Energy: " .. macroTorch.computeReshiftEnergy())`
4. Expected: 60 (5/5 Furor × 8 + Wolfsheart × 20)
5. `/reload` and repeat — should still be 60