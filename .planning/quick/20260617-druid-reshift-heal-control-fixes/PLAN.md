---
description: Fix druid reshift skill check, heal self-target, CancelShapeshiftForm error, and druidControl Entangling Roots
---

## Fixes

1. **bearAtk/catAtk reshift guard**: Skip reshift module if player hasn't learned the Reshift spell yet
2. **druidHeal self-target**: Fix range check bypass when onSelf=true in `_castSpell` so self-heals work regardless of target distance
3. **druidHeal CancelShapeshiftForm**: Replace non-existent `CancelShapeshiftForm()` with form-specific cancel via existing spell methods
4. **druidControl human form**: Simplify to always cast Entangling Roots in caster form, remove Hibernate branch