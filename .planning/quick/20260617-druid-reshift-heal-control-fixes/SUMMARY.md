---
status: complete
completed_at: 2026-06-17
---

## Changes

1. **bearReshiftMod / reshiftMod**: Added `isSpellExist('Reshift', 'spell')` guard — skips reshift module entirely when spell not learned
2. **druidHeal CancelShapeshiftForm fix**: Replaced non-existent `CancelShapeshiftForm()` with form-specific cancellation (cat_form / dire_bear_form / bear_form cast toggles off current form)
3. **_castSpell range check**: Added `not onSelf` bypass — self-cast heals no longer fail due to target distance check
4. **druidControl human form**: Simplified to always cast Entangling Roots, removed Hibernate branch