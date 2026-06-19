---
phase: 260619-qbj
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - classes/druid/combo.lua
  - texture_map.lua
autonomous: true
requirements: []

must_haves:
  truths:
    - "casterAtk opens with Wrath when entering combat"
    - "casterAtk applies Moonfire debuff before other debuffs"
    - "casterAtk applies Faerie Fire debuff when Moonfire is up"
    - "casterAtk applies Insect Swarm debuff when Moonfire and Faerie Fire are up"
    - "casterAtk alternates Wrath and Starfire after all three debuffs are up"
  artifacts:
    - path: "classes/druid/combo.lua"
      provides: "Updated casterAtk with Faerie Fire, Insect Swarm, and Starfire rotation"
    - path: "texture_map.lua"
      provides: "Faerie Fire and Insect Swarm texture entries for buffed() detection"
  key_links:
    - from: "classes/druid/combo.lua casterAtk()"
      to: "texture_map.lua SPELL_TEXTURE_MAP"
      via: "macroTorch.target.buffed() — uses spell name + texture from SPELL_TEXTURE_MAP"
    - from: "classes/druid/combo.lua casterAtk()"
      to: "classes/druid/Druid.lua spell methods"
      via: "macroTorch.player.faerie_fire() / insect_swarm() / starfire()"
---

<objective>
Add Faerie Fire, Insect Swarm debuff maintenance and Starfire nuke alternation to casterAtk rotation.

Purpose: Extend the caster DPS rotation from Moonfire-only to a full three-debuff + dual-nuke rotation.
Output: Updated casterAtk() in combo.lua with debuff priority logic and Wrath/Starfire alternation; texture_map.lua extended with Faerie Fire and Insect Swarm entries.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@classes/druid/combo.lua
@texture_map.lua
@classes/druid/Druid.lua
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Faerie Fire and Insect Swarm textures to SPELL_TEXTURE_MAP</name>
  <files>texture_map.lua</files>
  <action>
Add two entries to macroTorch.SPELL_TEXTURE_MAP inside the druid section (between "Moonfire" and the warrior section):
- ['Faerie Fire'] = 'Spell_Nature_FaerieFire'
- ['Insect Swarm'] = 'Spell_Nature_InsectSwarm'

Place them immediately after the Moonfire entry to keep the druid section together. Do not touch any warrior entries.
</action>
<verify>
  <automated>grep -c "'Faerie Fire'" /Users/yue.weny/finalanswer/macro-torch/macro-torch/texture_map.lua | grep -v '^#' | xargs test 1 -eq</automated>
</verify>
  <done>SPELL_TEXTURE_MAP contains Faerie Fire and Insect Swarm entries; buffed() calls using these names will resolve their textures for debuff detection.</done>
</task>

<task type="auto">
  <name>Task 2: Update casterAtk rotation with three-debuff maintenance and Wrath/Starfire alternation</name>
  <files>classes/druid/combo.lua</files>
  <action>
Replace the existing casterAtk() function body with the following logic order:

1. Early return if target.isCanAttack is false (unchanged guard).
2. If NOT in combat: cast Wrath as opener (unchanged).
3. If in combat AND Moonfire debuff missing: cast Moonfire (debuff priority 1).
4. If in combat AND Faerie Fire debuff missing: cast Faerie Fire (debuff priority 2).
   - Use buffed('Faerie Fire', 'Spell_Nature_FaerieFire') for the check.
5. If in combat AND Insect Swarm debuff missing: cast Insect Swarm (debuff priority 3).
   - Use buffed('Insect Swarm', 'Spell_Nature_InsectSwarm') for the check.
6. All three debuffs are up: alternate between Wrath and Starfire.
   - Use a boolean toggle stored as macroTorch._starfireNext (initialize to nil/false, not on macroTorch.player).
   - First nuke after debuffs: Wrath (since _starfireNext is falsy initially).
   - After casting Wrath: set macroTorch._starfireNext = true.
   - After casting Starfire: set macroTorch._starfireNext = false.
   - Cast Starfire when _starfireNext is truthy, Wrath when falsy.

The toggle variable lives on macroTorch (global namespace), not on the player object, to avoid cluttering entity state with rotation-internal state.
</action>
<verify>
  <automated>grep -c "macroTorch._starfireNext" /Users/yue.weny/finalanswer/macro-torch/macro-torch/classes/druid/combo.lua | grep -v '^#' | xargs test 3 -ge</automated>
</verify>
  <done>casterAtk() follows the priority chain: Wrath opener -> Moonfire -> Faerie Fire -> Insect Swarm -> alternating Wrath/Starfire nukes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Debuff detection via buffed() | WoW client API returns texture-based debuff info — trust client data; no external input |
| Spell casting via _castSpell | Internal spell method calls with no user-supplied parameters |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-qbj-01 | Tampering | SPELL_TEXTURE_MAP entries | accept | Static data table — no runtime modification vector; incorrect textures would only cause debuff detection failure (non-exploitable) |
| T-qbj-02 | Information Disclosure | macroTorch._starfireNext | accept | Boolean toggle with no PII or sensitive data; local WoW addon state only |
</threat_model>

<verification>
All checks are unit-level (manual code review + grep gates). No in-game testing is possible in this environment.
</verification>

<success_criteria>
- SPELL_TEXTURE_MAP gains Faerie Fire and Insect Swarm entries under the druid section
- casterAtk() debuff checks: Moonfire first, then Faerie Fire, then Insect Swarm
- casterAtk() nuke logic alternates Wrath/Starfire via macroTorch._starfireNext toggle
- Existing behavior preserved: Wrath opener on combat entry, Moonfire priority
</success_criteria>

<output>
Create .planning/quick/260619-qbj-add-faerie-fire-insect-swarm-debuff-and-/260619-qbj-SUMMARY.md when done
</output>