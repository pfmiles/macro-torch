---
description: Refactor druidControl to distance-based and add caster DPS to druidAtk
---

## Changes

1. **druidControl**: Simplified to distance-based logic — Bash when target < 8 yards, Entangling Roots when >= 8 yards
2. **druidAtk**: Added caster form branch — cast Moonfire if not present on target, otherwise cast Wrath