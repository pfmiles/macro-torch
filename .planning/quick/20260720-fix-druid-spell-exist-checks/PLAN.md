---
quick_id: "260720-m7k"
slug: "fix-druid-spell-exist-checks"
description: "Add isSpellExist() checks to druid caster/heal/control/aoe/defend functions to prevent attempting to cast unlearned spells during leveling"
created: "2026-07-20T07:59:00Z"
status: "planned"
---

# Fix: Add isSpellExist checks to druid caster-form combat functions

## Problem

In `classes/druid/combo.lua`, several functions called when the druid is NOT in cat/bear form lack `isSpellExist()` guards. Only Wrath (愤怒) is available from level 1 — other spells like Moonfire (Lv4), Starfire (Lv20), Faerie Fire (Lv14), Insect Swarm (Lv20+), Regrowth (Lv12), Rejuvenation (Lv4), Hibernate (Lv18), Entangling Roots (Lv8), Hurricane (Lv40), Barkskin (Lv10), Frenzied Regeneration (Lv40) are all learned later or via talents.

The **cat form leveling** function (`catLeveling()` in `leveling.lua`) and `druidCharge()` already use `isSpellExist()` correctly — the same pattern was simply missed in the caster/heal/control/aoe/defend functions.

## Affected Functions (all in `classes/druid/combo.lua`)

1. **`casterAtk()`** (lines 3-31) — 5 spells missing checks: Faerie Fire, Moonfire, Insect Swarm, Starfire (+ Wrath which is innate)
2. **`druidHeal()`** (lines 191-236) — Healing Touch/Regrowth/Rejuvenation missing checks
3. **`druidControl()`** (lines 254-283) — Hibernate, Entangling Roots
4. **`druidAoe()`** (lines 181-189) — Hurricane
5. **`druidDefend()`** (lines 238-252) — Barkskin, Frenzied Regeneration

## Fix Strategy

Follow the established pattern from `catLeveling()` and `druidCharge()`:

- Wrap non-innate spell casts with `macroTorch.isSpellExist('SpellName', 'spell')`
- Wrath is innate (Lv1) — no guard needed, serves as fallback
- Healing Touch is innate (Lv1) — no guard needed, serves as fallback
- When a spell doesn't exist, skip/short-circuit the branch and fall through to next available option
- For debuff checks (buffed()), keep them — they're harmless and return false when debuff can't be applied

### casterAtk() fix logic:

```lua
function macroTorch.casterAtk()
    if not macroTorch.target.isCanAttack then
        return
    end
    local targetClass = macroTorch.target.class
    if (targetClass == 'Rogue' or targetClass == '盗贼')
            and macroTorch.isSpellExist('Faerie Fire', 'spell')
            and not macroTorch.target.buffed('Faerie Fire', 'Spell_Nature_FaerieFire') then
        macroTorch.player.faerie_fire()
        return
    end
    if not macroTorch.player.isInCombat then
        macroTorch.player.wrath()  -- innate, always exists
    elseif macroTorch.isSpellExist('Moonfire', 'spell')
            and not macroTorch.target.buffed('Moonfire', 'Spell_Nature_StarFall') then
        macroTorch.player.moonfire()
    elseif macroTorch.isSpellExist('Faerie Fire', 'spell')
            and not macroTorch.target.buffed('Faerie Fire', 'Spell_Nature_FaerieFire') then
        macroTorch.player.faerie_fire()
    elseif macroTorch.isSpellExist('Insect Swarm', 'spell')
            and not macroTorch.target.buffed('Insect Swarm', 'Spell_Nature_InsectSwarm') then
        macroTorch.player.insect_swarm()
    elseif macroTorch.isSpellExist('Starfire', 'spell')
            and macroTorch.context.starfireNext then
        if macroTorch.player.starfire() then
            macroTorch.context.starfireNext = false
        end
    else
        -- Fallback: Wrath (innate). Reset starfireNext if starfire not learned
        if macroTorch.player.wrath() then
            if macroTorch.isSpellExist('Starfire', 'spell') then
                macroTorch.context.starfireNext = true
            end
        end
    end
end
```

### druidHeal() fix logic:

Add `isSpellExist` before Regrowth and Rejuvenation; Healing Touch is innate (Lv1) so no guard needed.

### druidControl() fix logic:

Add `isSpellExist` before Hibernate and Entangling Roots; if neither available, do nothing.

### druidAoe() fix logic:

Add `isSpellExist('Hurricane', 'spell')` before the Hurricane cast.

### druidDefend() fix logic:

Add `isSpellExist` before Barkskin and Frenzied Regeneration.

## Files to Change

- `classes/druid/combo.lua` — the only file that needs modification