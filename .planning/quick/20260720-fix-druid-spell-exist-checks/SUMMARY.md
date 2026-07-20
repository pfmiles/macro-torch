---
quick_id: "260720-m7k"
slug: "fix-druid-spell-exist-checks"
status: complete
date: "2026-07-20"
---

# Fix: Add isSpellExist checks to druid caster-form combat functions

## Summary

Added `macroTorch.isSpellExist()` guards to all non-innate spell casts in `classes/druid/combo.lua` caster-form functions. This prevents macro errors when a low-level druid attempts to cast spells they have not yet learned. Wrath (Lv1) and Healing Touch (Lv1) are innate spells and intentionally left unguarded as fallbacks.

## Changes

**File modified:** `classes/druid/combo.lua` (+33 / -15)

### casterAtk()
- Faerie Fire: added `isSpellExist` before cast (Lv14 spell)
- Moonfire: added `isSpellExist` before cast (Lv4 spell)
- Insect Swarm: added `isSpellExist` before cast (Lv20+ spell)
- Starfire: added `isSpellExist` before cast and only set `starfireNext` if spell exists (Lv20 spell)
- Wrath: unchanged (innate Lv1, fallback)

### druidAoe()
- Hurricane: added `isSpellExist` guard (Lv40 spell)

### druidHeal()
- Regrowth: added `isSpellExist` guard at all call sites in both group and solo branches (Lv12 spell)
- Rejuvenation: added `isSpellExist` guard at all call sites in both group and solo branches (Lv4 spell)
- Healing Touch: unchanged (innate Lv1)

### druidDefend()
- Barkskin: added `isSpellExist` before `isSpellReady` check (Lv10 spell)
- Frenzied Regeneration: added `isSpellExist` before `isSpellReady` check (Lv40 spell)

### druidControl()
- Hibernate: added `isSpellExist` guard (Lv18 spell)
- Entangling Roots: added `isSpellExist` guard (Lv8 spell)
- When neither spell is available, the function silently does nothing (safe no-op)

## Build Verification

`./build.sh` ran successfully -- SM_Extend.lua generated (331,566 bytes).

## Deviations

None. Plan executed exactly as written.

## Commit

`3bb1f0e` - fix(druid): add isSpellExist guards to caster/heal/control/aoe/defend functions for leveling safety
