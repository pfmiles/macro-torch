---
plan: 10-01
phase: 10-Druid-combo
status: complete
tasks: 2/2
files_created:
  - classes/druid/combo.lua
---

## What was built

Created `classes/druid/combo.lua` containing 5 global one-button combo macro methods that route to form-specific sub-methods via if-elseif chains:

- **druidAtk(rough)** — Routes to catAtk (cat form) or bearAtk (bear form). No caster branch.
- **druidAoe()** — Routes to bearAoe (bear form) or hurricane (humanoid/caster with mana >= 880). No cat AOE.
- **druidHeal()** — Self-heal sequence: cancel form → Rejuvenation (HP < 50%, no existing HOT) → Healing Touch (HP < 40%). One action per keypress.
- **druidDefend()** — Defense sequence: Barkskin (any form) → shift to bear → Frenzied Regeneration. One action per keypress.
- **druidControl()** — CC routing: Bash/Feral Charge (bear form), Hibernate/Entangling Roots (humanoid form by target type), auto-shift to bear (other forms).

5 optional SelfTest registrations verify function existence (Druid-only).

## Self-Check: PASSED

- 5 functions verified: `grep -c "function macroTorch.druid"` = 5
- 5 self-tests verified: `grep -c "SelfTest:register.*Druid: combo"` = 5
- No `#` operator used
- No colon syntax outside SelfTest:register
- All required symbols referenced: CancelShapeshiftForm, healthPercent, barkskin, frenzied_regeneration, dire_bear_form, bash, feral_charge, hibernate, entangling_roots, target.type, isNearBy