---
status: complete
commit: fec615b
files_reviewed:
  - core/events.lua
  - biz_util.lua
---

## Review: Defer SelfTest to Next Frame

### Summary

2 files changed, 0 findings. Change is clean and correct.

### File-by-File Analysis

#### `core/events.lua` — Defer SelfTest:run() to OnUpdate

**Change**: Replace synchronous `SelfTest:run()` with OnUpdate-deferred execution.

**Verification**:

| Check | Result |
|-------|--------|
| `_selfTestRan` guard prevents duplicate scheduling | ✅ nil before first run → register; `true` after → skip |
| Frame cached via `or CreateFrame` | ✅ single allocation, reused across zone transitions |
| OnUpdate self-cleans with `SetScript("OnUpdate", nil)` | ✅ handler removed after first execution |
| `_selfTestRan` set early in `SelfTest:run()` (L51) | ✅ even if tests error, flag is set → no re-registration |
| `self` parameter correctly used in OnUpdate callback | ✅ matches WoW 1.12 OnUpdate signature |
| Zone transition behavior unchanged | ✅ `_selfTestRan=true` → skip; self-test output only once |

**No issues found.**

#### `biz_util.lua` — Remove speculative comments

**Change**: Removed two AI-generated comment lines about tooltip Hide/Show behavior.

**Verification**:

| Check | Result |
|-------|--------|
| Comments removal only — no code changed | ✅ zero functional impact |
| Underlying logic unchanged | ✅ `ClearLines()` + `SetInventoryItem()` calls preserved |

**No issues found.**

### Categories

- **Critical**: 0
- **Warning**: 0
- **Info**: 0