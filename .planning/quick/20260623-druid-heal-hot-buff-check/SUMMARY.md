---
status: complete
date: 2026-06-23
---

# druidHeal HoT Buff Check Fix

## Summary

In `druidHeal()` (`classes/druid/combo.lua`), the group/raid healing path was missing HoT buff checks, causing Rejuvenation and Regrowth to be cast redundantly on targets that already had these effects.

## Change

Added `macroTorch.target.buffed()` checks in the group/raid path (lines 203-215):

- **HP 50-70% (Regrowth range)**: Check `Spell_Nature_ResistNature` first → if absent, cast Regrowth; if present, fall back to Rejuvenation (only if `Spell_Nature_Rejuvenation` not already active)
- **HP 70-90% (Rejuvenation range)**: Check `Spell_Nature_Rejuvenation` first → if absent, cast Rejuvenation; if present, skip
- **HP < 50% (Healing Touch)**: No change (direct heal, no HoT overlap concern)

## Result

Group/raid healing now matches the solo mode behavior — HoTs are only cast when the target doesn't already have them, preventing mana waste and GCD waste from unnecessary refreshes.