# druidHeal HoT Buff Check Fix

## Problem

`druidHeal()` in `classes/druid/combo.lua` has two code paths:

1. **Solo mode** (lines 210-220): ✅ Correctly checks for existing Rejuvenation (`Spell_Nature_Rejuvenation`) and Regrowth (`Spell_Nature_ResistNature`) buffs before casting on self.

2. **Group/Raid mode** (lines 197-209): ❌ Missing buff checks. Only uses HP thresholds to decide which spell to cast, without checking whether the target already has the HoT effect. This causes redundant HoT refreshing (overwriting), wasting mana and GCDs.

## Fix

Add buff checks to the group/raid mode, matching the intent of the solo mode. After `TargetUnit(lowestUnit)`, `macroTorch.target` refers to the lowest HP group member, so `macroTorch.target.buffed(...)` can be used to check buffs on the heal target.

### Logic

- **HP < 50%**: Cast Healing Touch (direct heal, no HoT check needed)
- **HP 50-70%**: Check if target has Regrowth HoT → if not, cast Regrowth; if yes, fall back to Rejuvenation (only if Rejuvenation not already active)
- **HP 70-90%**: Check if target has Rejuvenation HoT → if not, cast Rejuvenation; if yes, skip (no lower priority HoT available)

## Files Changed

- `classes/druid/combo.lua` — `druidHeal()` function, group/raid healing path