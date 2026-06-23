# Code Review: Druid Skill Diagnostics Print Function

**Task:** quick-260623-wrh-druid
**Commit:** f1bba57 (feat) + 316c041 (docs)
**Review Date:** 2026-06-23
**Depth:** standard
**Files Reviewed:** 3

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| Warning  | 2 |
| Info     | 3 |

---

## Findings

### W-01: `printDruidDiag()` call in selftest is not pcall-protected

**Severity:** Warning
**File:** `core/selftest.lua:95`
**Category:** Error Handling / Defensive Coding

**Finding:**
The call `macroTorch.printDruidDiag()` at line 95 is outside the selftest pcall loop. The selftest loop (lines 60-78) wraps each test in `pcall(test.fn)` to isolate failures, but the diagnostic print at line 95 runs unprotected. If any compute function inside `printDruidDiag()` throws a Lua error, it propagates to the `/mt` command handler and the user sees a raw Lua error in chat.

**Contrast with existing pattern:** All selftest items (lines 61-77) are pcall-isolated. Category F tests (lines 492-571) also use pcall for Druid-specific tests. The diagnostic call breaks this defensive pattern.

**Risk:** Low — the compute functions are stable and unlikely to error in normal gameplay. However, during edge cases (zone transition mid-call, talent reset, addon conflict), a single nil access in any compute function would crash the entire selftest report.

**Fix:**
```lua
-- Line 95: wrap in pcall
local ok, err = pcall(macroTorch.printDruidDiag)
if not ok then
    macroTorch.show("[macro-torch] WARN: Druid diagnostics failed - " .. tostring(err), 'yellow')
end
```

---

### W-02: `string.format("%.2f", ...)` has no nil guard

**Severity:** Warning
**File:** `classes/druid/diag.lua:33-35`
**Category:** Defensive Coding

**Finding:**
Three lines use `string.format("%.2f", macroTorch.computeXxx_Erps())` without nil protection:
- Line 33: `computeRake_Erps()`
- Line 34: `computeRip_Erps()`
- Line 35: `computePounce_Erps()`

If any of these functions returns `nil` (which would be a bug in the compute function, not expected in normal operation), `string.format("%.2f", nil)` throws a Lua error. The other compute calls in the file use `tostring()` which safely converts nil to the string `"nil"`.

**Verified:** All three ERPS functions (`Druid.lua:559-603`) always return a number — they have early-return paths for `ancientBrutalityRank == 0` that return `0`, and all other paths return `energyPerTick / tickInterval`. So this is currently safe, but the inconsistency with the `tostring()` pattern used elsewhere in the same function is a maintenance hazard.

**Risk:** Very low currently — the functions always return numbers. However, if someone refactors these functions and introduces a nil-return path, the diagnostic printer would crash.

**Fix:** Either:
- Option A: Wrap in `tostring()` for consistency: `tostring(macroTorch.computeRake_Erps())` — but loses the `%.2f` formatting
- Option B: Add a safety wrapper: `string.format("%.2f", macroTorch.computeRake_Erps() or 0)`
- Option C (recommended): Apply W-01's pcall fix in selftest, which catches this case too

---

### I-01: Fixed constants are a maintenance risk

**Severity:** Info
**File:** `classes/druid/diag.lua:18-21, 26-27, 31-32`
**Category:** Maintainability

**Finding:**
The following values are hardcoded and labeled `(fixed)`:
- Energy costs: Pounce=50, Bite=35, Rip=30, Cower=20
- Durations: FF=40s, Pounce=18s (stun duration, not bleed)
- ERPS: Auto Tick=10.00, Tiger's Fury Tick=3.33

While the `(fixed)` label correctly communicates that these aren't dynamic, the values could become stale if:
- Turtle WoW custom changes modify these costs
- Talents that affect energy costs are introduced

**Recommendation:** Consider adding a comment block at the top of the function listing which constants are hardcoded and where their source values come from (e.g., "Pounce=50: base energy cost per WoW 1.12.1, verified with Turtle WoW"). This helps future maintainers know what to check.

---

### I-02: Missing trailing newline

**Severity:** Info
**File:** `classes/druid/diag.lua:49`
**Category:** Style

**Finding:**
The file ends at line 49 (`end`) without a trailing newline character. Most other Lua files in the project have a trailing newline. While this doesn't affect Lua execution in WoW's embedded interpreter, it's a minor style inconsistency.

---

### I-03: Diagnostic output triggers unconditionally for Druids on `/mt`

**Severity:** Info
**File:** `core/selftest.lua:94-95`
**Category:** Design / Usability

**Finding:**
Every Druid who runs `/mt` (or triggers selftest via login) will see the full diagnostic dump. There's no way for a Druid player to run selftest without also printing diagnostics.

**Consideration:** For a Druid main who runs `/mt` regularly (e.g., after `/reload`), the 20+ lines of diagnostic output are noise — they likely already know their energy costs. Consider one of:
- A separate `/mt diag` subcommand to print diagnostics on demand
- A once-per-session guard (similar to `_selfTestRan`) so diagnostics only print on first `/mt` of the session
- Keep as-is: the current design is simple and consistent with the quick-task goal

**Verdict:** This is acceptable for a quick task. The SUMMARY explicitly states the function "can be invoked manually via `/run macroTorch.printDruidDiag()`" — the automatic selftest wiring is a bonus. If chat spam becomes an issue, this can be revisited.

---

## Verification Checklist

| Check | Status | Notes |
|-------|--------|-------|
| All compute functions exist | ✅ PASS | All 11 functions verified in `classes/druid/Druid.lua` |
| No `#` unary length operator | ✅ PASS | None found in diag.lua |
| No direct `DEFAULT_CHAT_FRAME` calls | ✅ PASS | All output uses `macroTorch.show()` |
| `UnitClass('player')` guard | ✅ PASS | Line 6 — early return for non-Druids |
| `build_order.txt` placement | ✅ PASS | diag.lua placed after combo.lua, before leveling.lua — correct |
| Function signatures match calls | ✅ PASS | `estimatePlayerDPS()` and `getKSThreshold()` accept optional level param |
| `string.format` usage | ✅ PASS | `%.2f` format correct for ERPS decimal display |
| pcall isolation in selftest | ⚠️ W-01 | Not isolated — see finding |
| Nil safety in string.format | ⚠️ W-02 | Pattern inconsistency — see finding |
| Trailing newline | ⚠️ I-02 | Missing — see finding |

---

## Overall Assessment

**Verdict: APPROVED with minor warnings**

The implementation correctly fulfills the quick task requirements. All compute functions exist and are called correctly. The `UnitClass` guard works as designed. Build integration is correct.

The two warnings (W-01, W-02) are defensive coding concerns — neither is a functional bug. The recommended pcall fix (W-01) would bring the diagnostic call in line with the existing defensive patterns used throughout selftest.

**Recommendation:** Apply W-01 (pcall wrapper) for consistency with the rest of the selftest module. W-02 and I-01/I-02/I-03 can be addressed at the developer's discretion.