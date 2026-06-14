# Druid _castSpell Fix -- Human UAT Checklist

**Phase:** 06 -- Fix Druid _castSpell isSpellReady nil bug (colon/dot syntax mismatch)
**Date:** 2026-06-14
**Prerequisites:**
- WoW 1.12.1 (Turtle WoW) client running
- macro-torch addon loaded with Phase 6 fixes applied
- `./build.sh` completed successfully
- Character: Level 20+ Druid with Cat Form, Bear Form, and healing spells trained
- A target dummy or hostile mob nearby for Type A tests

---

## Pre-Test: Self-Test Verification

- [ ] Run `/mt` in chat
- [ ] Verify summary line shows: `[macro-torch] Self-test: N passed, 0 failed, M warnings`
- [ ] Verify all Category F tests passed (no red "FAIL: F:" messages)
- [ ] If any Category F test failed, stop UAT -- bug fix is incomplete

---

## Type A: Enemy-Target Skills (auto-targets current enemy)

**Setup:** Target a hostile mob or training dummy. Ensure you are in melee range.

### Mode: 'ready' (cooldown check only -- casts if spell is off cooldown)

- [ ] **claw('ready')** -- `/run macroTorch.player.claw('ready')` -- Casts Claw on target if off cooldown
- [ ] **shred('ready')** -- `/run macroTorch.player.shred('ready')` -- Casts Shred on target if off cooldown (requires behind target for full effect, but cast should still fire)
- [ ] **rake('ready')** -- `/run macroTorch.player.rake('ready')` -- Casts Rake on target if off cooldown
- [ ] **rip('ready')** -- `/run macroTorch.player.rip('ready')` -- Casts Rip on target if off cooldown (requires combo points to do anything)
- [ ] **ferocious_bite('ready')** -- `/run macroTorch.player.ferocious_bite('ready')` -- Casts Ferocious Bite on target if off cooldown
- [ ] **faerie_fire_feral('ready')** -- `/run macroTorch.player.faerie_fire_feral('ready')` -- Casts Faerie Fire (Feral) on target if off cooldown

### Mode: 'safe' (range + resource checks before casting)

- [ ] **claw('safe')** -- `/run macroTorch.player.claw('safe')` -- Casts Claw only if in melee range and has enough energy
- [ ] **shred('safe')** -- `/run macroTorch.player.shred('safe')` -- Casts Shred only if in melee range and has enough energy
- [ ] **rip('safe')** -- `/run macroTorch.player.rip('safe')` -- Casts Rip only if in range and has >=30 energy

### Mode: 'raw' (no checks -- always attempts to cast)

- [ ] **claw('raw')** -- `/run macroTorch.player.claw('raw')` -- Always attempts Claw cast (may show "not ready yet" error which is expected if on cooldown)
- [ ] **shred('raw')** -- `/run macroTorch.player.shred('raw')` -- Always attempts Shred cast
- [ ] **rake('raw')** -- `/run macroTorch.player.rake('raw')` -- Always attempts Rake cast
- [ ] **ferocious_bite('raw')** -- `/run macroTorch.player.ferocious_bite('raw')` -- Always attempts Ferocious Bite cast

### Verification Checklist for Type A

- [ ] No Lua errors appear in chat when calling any skill method
- [ ] Skills successfully cast when off cooldown and in range (you see the cast bar or spell animation)
- [ ] 'ready' mode properly checks cooldown (skill not cast when on cooldown)
- [ ] 'safe' mode properly checks range (skill not cast when out of range)
- [ ] 'safe' mode properly checks resource (skill not cast when insufficient energy)

---

## Type B: Self-Target Skills (always casts on player)

**Setup:** Ensure you are out of combat. No target needed.

### Mode: 'ready' (cooldown check only)

- [ ] **cat_form('ready')** -- `/run macroTorch.player.cat_form('ready')` -- Shifts to Cat Form if off cooldown
- [ ] **bear_form('ready')** -- `/run macroTorch.player.bear_form('ready')` -- Shifts to Bear Form if off cooldown (shift out of cat first)
- [ ] **prowl('ready')** -- `/run macroTorch.player.prowl('ready')` -- Activates Prowl (stealth) if in Cat Form and off cooldown
- [ ] **tiger_fury('ready')** -- `/run macroTorch.player.tiger_fury('ready')` -- Activates Tiger's Fury self-buff if off cooldown

### Mode: 'safe' (range + resource checks)

- [ ] **cat_form('safe')** -- `/run macroTorch.player.cat_form('safe')` -- Shifts to Cat Form (self-target has no range restriction; resource check applies if cost > 0)
- [ ] **tiger_fury('safe')** -- `/run macroTorch.player.tiger_fury('safe')` -- Activates Tiger's Fury only if has enough energy for computeTiger_E()

### Mode: 'raw' (no checks -- always attempts)

- [ ] **cat_form('raw')** -- `/run macroTorch.player.cat_form('raw')` -- Always attempts Cat Form shift
- [ ] **tiger_fury('raw')** -- `/run macroTorch.player.tiger_fury('raw')` -- Always attempts Tiger's Fury

### Verification Checklist for Type B

- [ ] No Lua errors appear in chat when calling any self-target skill
- [ ] Form shifts work correctly (character model changes)
- [ ] Self-buffs apply correctly (buff icon appears on player frame)
- [ ] 'safe' mode properly respects resource checks (tiger_fury not cast when insufficient energy)

---

## Type C: Flexible-Target Skills (onSelf parameter controls target)

**Setup:** Target a friendly NPC or no target (self-target mode as fallback).

### Mode: 'ready' -- Self-target (onSelf=true)

- [ ] **healing_touch('ready', true)** -- `/run macroTorch.player.healing_touch('ready', true)` -- Casts Healing Touch on self if off cooldown
- [ ] **rejuvenation('ready', true)** -- `/run macroTorch.player.rejuvenation('ready', true)` -- Casts Rejuvenation on self if off cooldown
- [ ] **mark_of_the_wild('ready', true)** -- `/run macroTorch.player.mark_of_the_wild('ready', true)` -- Casts Mark of the Wild on self if off cooldown

### Mode: 'ready' -- Target a friendly unit (onSelf=false)

- [ ] **healing_touch('ready', false)** -- `/run macroTorch.player.healing_touch('ready', false)` -- Casts Healing Touch on current target if off cooldown
- [ ] **mark_of_the_wild('ready', false)** -- `/run macroTorch.player.mark_of_the_wild('ready', false)` -- Casts Mark of the Wild on current target if off cooldown

### Mode: 'safe' -- Self-target with range check

- [ ] **healing_touch('safe', true)** -- `/run macroTorch.player.healing_touch('safe', true)` -- Casts Healing Touch on self if in range (40yd) and has mana

### Mode: 'raw' -- Self-target no checks

- [ ] **healing_touch('raw', true)** -- `/run macroTorch.player.healing_touch('raw', true)` -- Always attempts Healing Touch on self
- [ ] **mark_of_the_wild('raw', false)** -- `/run macroTorch.player.mark_of_the_wild('raw', false)` -- Always attempts MotW on current target

### Verification Checklist for Type C

- [ ] No Lua errors appear in chat when calling any flexible-target skill
- [ ] onSelf=true correctly casts on the player (heal/buff appears on player frame)
- [ ] onSelf=false correctly casts on current target
- [ ] Range check works in 'safe' mode (40yd for healing spells, 30yd for MotW)

---

## Integration Test: One-Button Macro (catAtk)

**Setup:** Bind catAtk to a key. Target a hostile mob. Enter Cat Form.

- [ ] Press the bound key repeatedly while in combat with a mob
- [ ] Verify: skills fire automatically (claw, shred, rake, rip, ferocious_bite as appropriate)
- [ ] Verify: no Lua errors appear in chat during the entire combat
- [ ] Verify: combo points build up and are consumed correctly
- [ ] Verify: Cat Form skills actually land on target (check damage numbers / debuffs)

---

## Regression Check: Existing Functionality

- [ ] **External isSpellReady call** -- `/run local r = macroTorch.player.isSpellReady('Claw'); macroTorch.show(tostring(r))` -- Shows true or false (not nil, not an error)
- [ ] **External cast call** -- `/run macroTorch.player.cast('Claw', false)` -- Casts Claw on target if available
- [ ] **safeFF function works** -- In cat form, target a hostile mob: `/run macroTorch.safeFF({})` -- Should show FF log message and cast FF if conditions met
- [ ] **Hunter class unaffected** -- If you have a Hunter alt, verify `/run local p = macroTorch.player; p.cast('Auto Shot', false)` works correctly (dot syntax unchanged)

---

## Results Summary

| Category | Pass/Fail | Notes |
|----------|-----------|-------|
| Pre-test /mt | [ ] | |
| Type A: ready | [ ] | |
| Type A: safe | [ ] | |
| Type A: raw | [ ] | |
| Type B: ready | [ ] | |
| Type B: safe | [ ] | |
| Type B: raw | [ ] | |
| Type C: ready | [ ] | |
| Type C: safe | [ ] | |
| Type C: raw | [ ] | |
| Integration (catAtk) | [ ] | |
| Regression | [ ] | |

---

## Sign-Off

- [ ] All categories pass: ALL boxes checked
- [ ] No Lua errors during any test
- [ ] UAT completed by: _______________
- [ ] Date: _______________