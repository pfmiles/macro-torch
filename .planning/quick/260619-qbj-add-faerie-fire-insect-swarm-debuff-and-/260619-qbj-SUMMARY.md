---
status: complete
plan: 260619-qbj-01
date: 2026-06-19
commits:
  - 59e15c0 feat(260619-qbj): add Faerie Fire and Insect Swarm textures to SPELL_TEXTURE_MAP
  - cd9ec17 feat(260619-qbj): extend casterAtk rotation with Faerie Fire, Insect Swarm, and Starfire
files_modified:
  - classes/druid/combo.lua
  - texture_map.lua
---

# Quick Task 260619-qbj: casterAtk debuffs + Starfire rotation

## Summary

Added Faerie Fire and Insect Swarm debuff maintenance to `casterAtk()`, and introduced Starfire as an alternating nuke with Wrath.

## Changes

### Task 1: texture_map.lua
- Added `['Faerie Fire'] = 'Spell_Nature_FaerieFire'` to `SPELL_TEXTURE_MAP` (druid section)
- Added `['Insect Swarm'] = 'Spell_Nature_InsectSwarm'` to `SPELL_TEXTURE_MAP` (druid section)

### Task 2: classes/druid/combo.lua
- Extended `casterAtk()` with priority-based debuff chain:
  - Wrath opener (out of combat) — unchanged
  - Moonfire debuff (priority 1) — unchanged
  - Faerie Fire debuff (priority 2) — new
  - Insect Swarm debuff (priority 3) — new
  - Wrath/Starfire alternation via `macroTorch._starfireNext` toggle — new
- First nuke after all debuffs is Wrath (nil is falsy), then alternates each cast

## Verification

All debuff checks use `buffed()` with both spell name and texture string for robust detection. The `_starfireNext` toggle lives on `macroTorch` (global namespace) to avoid cluttering entity state.