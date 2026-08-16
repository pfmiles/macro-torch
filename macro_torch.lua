--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]] --

-- some machanisms impl
if not macroTorch then
    macroTorch = {}
end

-- DEBUG: init trace step 1 — macroTorch table created
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 1: macroTorch table created", 0, 1, 0)

-- DEPRECATED: spellId no longer used in cast→land→immune chain since Phase 24.
-- Retained for legacy SuperWoW spellId auto-correction (opt-in via /run).
-- SPELL_ID_AUTO_CORRECT: global switch that controls whether the spellId auto-correction
-- mechanism is active. When true, the addon uses UNIT_CASTEVENT events to detect
-- and correct client-specific Global Spell ID mismatches against the SPELL_NAME_TO_ID
-- static baseline. Default is false (opt-in) — enable in-game via:
--   /run macroTorch.SPELL_ID_AUTO_CORRECT = true
-- When false (default), all spellId correction is disabled:
--   - resolveSpellId() returns static SPELL_NAME_TO_ID values only (no runtime correction)
--   - current_casting_spell bridge variable is never set
--   - UNIT_CASTEVENT spellId correction is skipped
--   - loadSpellIdMap() skips loading and migrating persisted corrections
macroTorch.SPELL_ID_AUTO_CORRECT = false

