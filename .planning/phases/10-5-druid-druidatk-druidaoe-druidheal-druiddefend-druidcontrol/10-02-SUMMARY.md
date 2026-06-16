---
plan: 10-02
phase: 10-Druid-combo
status: complete
tasks: 2/2
files_modified:
  - classes/druid/Druid.lua
  - classes/druid/utility.lua
  - build_order.txt
---

## What was built

**Task 1:** Removed bear form routing from catAtk in Druid.lua:
- Deleted `clickContext.isInBearForm = player.isInBearForm` cache (line 348)
- Deleted bear routing block (lines 380-384): `if clickContext.isInBearForm then macroTorch.bearAtk(...) return end`
- catAtk now only runs when explicitly called from cat form via druidAtk routing

Removed 3 obsolete functions from utility.lua:
- `macroTorch.druidStun()` — logic merged into druidControl in combo.lua
- `macroTorch.druidDefend()` — replaced by new druidDefend in combo.lua
- `macroTorch.druidControl()` — replaced by new druidControl in combo.lua
- `macroTorch.druidBuffs()` retained unchanged (per D-21)

**Task 2:** Added `classes/druid/combo.lua` to build_order.txt after utility.lua. Build.sh produces SM_Extend.lua with all 5 new combo methods and no deleted old functions.

## Self-Check: PASSED

- No `clickContext.isInBearForm` cache in Druid.lua (verified via grep)
- No bear routing block in Druid.lua (verified via grep)
- Only druidBuffs remains in utility.lua (3 functions deleted, 1 kept)
- combo.lua present in build_order.txt after utility.lua
- Build succeeds: `./build.sh` exit 0
- SM_Extend.lua: 5 combo methods present, druidStun absent, druidBuffs present
- catAtk still exists in SM_Extend.lua (as obj.catAtk instance method on Druid)