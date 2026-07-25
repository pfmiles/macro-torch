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

-- Static Global Spell ID baseline for Druid land-traced spells (60-level, Turtle WoW client).
-- Flat dual-key table: each language name entry maps to the same Global Spell ID.
-- Used by resolveSpellId() in spell_trace_core.lua for name-based spellId resolution.
-- Faerie Fire (Feral) is NOT mapped — it uses immune tracing only (land=false), no spellId needed.
macroTorch.SPELL_NAME_TO_ID = {
    -- English names
    ["Pounce"] = 9827,
    ["Rake"] = 9904,
    ["Rip"] = 9896,
    ["Ferocious Bite"] = 31018,
    -- Chinese names (from Druid.lua _castSpell locale tables)
    ["突袭"] = 9827,        -- Pounce
    ["斜掠"] = 9904,        -- Rake
    ["撕扯"] = 9896,        -- Rip
    ["凶猛撕咬"] = 31018,    -- Ferocious Bite
}