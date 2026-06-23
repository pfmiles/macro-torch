---
phase: quick-260623-wrh-druid
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - classes/druid/diag.lua
  - build_order.txt
  - core/selftest.lua
autonomous: true
requirements:
  - QUICK-260623-WRH-DRUID-01

must_haves:
  truths:
    - "Diagnostic print function exists as macroTorch.printDruidDiag()"
    - "Function prints all dynamic compute results to chat frame after selftest"
    - "Function can be manually invoked via /run macroTorch.printDruidDiag()"
  artifacts:
    - path: "classes/druid/diag.lua"
      provides: "Druid diagnostic print function"
      min_lines: 40
      contains: "macroTorch.printDruidDiag"
    - path: "build_order.txt"
      provides: "Build inclusion for diag.lua"
      contains: "classes/druid/diag.lua"
  key_links:
    - from: "core/selftest.lua (SelfTest:run after summary line)"
      to: "classes/druid/diag.lua (macroTorch.printDruidDiag)"
      via: "macroTorch.printDruidDiag() call appended after summary in SelfTest:run"
      pattern: "macroTorch\\.printDruidDiag"
    - from: "classes/druid/diag.lua"
      to: "classes/druid/Druid.lua"
      via: "calls computeClaw_E, computeShred_E, computeRake_E, computeTiger_E, computeTiger_Duration, computeRake_Erps, computeRip_Erps, computePounce_Erps, computeReshiftEnergy, estimatePlayerDPS, getKSThreshold"
      pattern: "macroTorch\\.compute"
---

<objective>
Create a standalone diagnostic print method macroTorch.printDruidDiag() that calls all Druid compute functions (energy costs, durations, ERPS values, reshift energy, DPS/threshold estimates) and prints their current results in structured, labeled format to the chat frame.

Purpose: Enable in-game verification of dynamic skill calculations against the actual skill bar values. Useful for checking correctness across different talent specs, gear setups, and buff states without needing to dig into code or re-login.

Output:
- classes/druid/diag.lua (new file) — contains macroTorch.printDruidDiag()
- build_order.txt — updated to include diag.lua (after combo.lua, before leveling.lua)
- core/selftest.lua — updated SelfTest:run() to call printDruidDiag() after summary (Druid-only guard)
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@classes/druid/Druid.lua
@classes/druid/combo.lua
@core/selftest.lua
@interface_debug.lua
@build_order.txt
@CLAUDE.md
@.claude/CLAUDE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create classes/druid/diag.lua with printDruidDiag function and wire into selftest</name>
  <files>classes/druid/diag.lua, build_order.txt, core/selftest.lua</files>
  <action>
**Part A — Create classes/druid/diag.lua:**

Create a single function `macroTorch.printDruidDiag()` that:

1. Guards on Druid class: `if UnitClass('player') ~= 'Druid' then return end`
2. Calls each compute function and prints results using `macroTorch.show()`, grouped into labeled sections:

Section header (white): `[macro-torch] === Druid Skill Diagnostics ===`

**Energy Costs** (green):
- Claw: `macroTorch.computeClaw_E()`
- Shred: `macroTorch.computeShred_E()`
- Rake: `macroTorch.computeRake_E()`
- Tiger's Fury: `macroTorch.computeTiger_E()`
- Note: also print fixed constants from combo.lua (Pounce=50, Bite=35, Rip=30, Cower=20) with label "(fixed)"

**Durations** (green):
- Tiger's Fury: `macroTorch.computeTiger_Duration()`
- Print fixed duration constants (FF=40s, Pounce=18s) with label "(fixed)"

**ERPS (Energy Per Second)** (green):
- Auto Tick: 10.0 (20/2, fixed) with label "(fixed)"
- Tiger's Fury: 3.33 (10/3, fixed) with label "(fixed)"
- Rake Tick: `macroTorch.computeRake_Erps()`
- Rip Tick: `macroTorch.computeRip_Erps()`
- Pounce Tick: `macroTorch.computePounce_Erps()`
- Total (computed via computeErps): print a note that computeErps requires clickContext and is context-dependent

Use string.format("%.2f", value) for ERPS values to keep output tidy.

**Reshift** (green):
- Reshift Energy Gain: `macroTorch.computeReshiftEnergy()`

**Level-Adaptive Estimates** (green):
- Player Level: `UnitLevel('player')`
- Estimated DPS: `macroTorch.estimatePlayerDPS()`
- Kill Shot Threshold: `macroTorch.getKSThreshold()`

Section footer (white): `[macro-torch] === End Diagnostics ===`

Each line format: `[macro-torch] Label: value` using macroTorch.show(line, 'green') for data lines and 'white' for headers/footers.

Comment-text discipline: Do NOT write the word "lit ---" or "literal" followed by dashes in any comment or string in this file. Rephrase any such concepts.

**Part B — Add diag.lua to build_order.txt:**

Insert `classes/druid/diag.lua` line in build_order.txt after `classes/druid/combo.lua` (line 31) and before `classes/druid/leveling.lua` (line 32). Comment line: `# classes/ — Druid diagnostics (quick task 260623-wrh-druid)`.

**Part C — Wire into SelfTest:run():**

In `core/selftest.lua`, in the `SelfTest:run()` function (around line 81-83, after the summary output `macroTorch.show(string.format(...))` and the failed/warning name listing blocks), add a call to `macroTorch.printDruidDiag()` (at the very end of the function, before the closing `end`). This call is outside the `macroTorch._selfTestRan` guard so it only fires once per session. No additional guard needed — printDruidDiag itself has the Druid class check, and the _selfTestRan flag already ensures single execution per session.
</action>
<verify>
<automated>grep -c 'macroTorch.printDruidDiag' classes/druid/diag.lua</automated>
</verify>
<done>
- classes/druid/diag.lua exists with macroTorch.printDruidDiag() function containing all compute function calls, guarded by UnitClass check
- build_order.txt includes classes/druid/diag.lua after combo.lua and before leveling.lua
- core/selftest.lua SelfTest:run() calls macroTorch.printDruidDiag() after summary output
- All output uses macroTorch.show() with green for data lines, white for headers/footers
- Each data line uses Label: value format for easy readability
- No "#" length operator used; no forbidden literal patterns in comments
</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| n/a | This is a diagnostic/print function with no data input, no security boundary |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-diag-01 | Denial of Service | printDruidDiag | accept | Function runs once per session (via _selfTestRan guard). Output volume is bounded (~20 lines). No loop, no user input. Low risk. |
</threat_model>

<verification>
- After build, `grep 'printDruidDiag' SM_Extend.lua` should return 2 matches (function definition + selftest call)
- All output uses macroTorch.show (no raw DEFAULT_CHAT_FRAME:AddMessage calls in diag.lua — interface_debug.lua already defines the abstraction)
</verification>

<success_criteria>
- build.sh produces SM_Extend.lua without errors
- In-game on Druid login: SelfTest runs, then diagnostics appear in chat frame with all compute values
- Non-Druid logins: no diagnostic output (UnitClass guard fires)
- /run macroTorch.printDruidDiag() works from any time after login, showing current values
- Changing gear/talents then re-running /run shows updated values
</success_criteria>

<output>
Create .planning/quick/260623-wrh-druid/260623-wrh-SUMMARY.md when done
</output>