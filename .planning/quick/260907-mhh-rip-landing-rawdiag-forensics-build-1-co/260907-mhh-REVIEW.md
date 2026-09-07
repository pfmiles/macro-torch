---
phase: quick-260907-mhh-rip-landing-rawdiag-forensics-build
reviewed: 2026-09-07T12:06:24Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - core/events.lua
  - core/spell_trace_core.lua
  - classes/druid/cat.lua
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase quick-260907-mhh: Code Review Report

**Reviewed:** 2026-09-07T12:06:24Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the strictly-additive RAWDIAG2 forensics instrumentation introduced by
commit `953bd50` relative to `f2ac754` (scope: `core/events.lua`,
`core/spell_trace_core.lua`, `classes/druid/cat.lua`). Verdict: the build is
safe as shipped for its stated purpose — no crash, no gameplay-decision, no
security risk in any of the three probes — with two forensics-validity warnings
and three info notes. No critical issues.

**Verified-correct against plan intent (differential review):**

- **Strictly additive:** `git show 953bd50 --numstat` = 16/51/46 insertions,
  0 deletions. `git diff --check` clean. Every pre-existing branch, return
  value, guard and scheduling decision is untouched.
- **Lua 5.0 validity:** no `#` length operator, no `goto`/labels anywhere in
  the new blocks. Array growth uses `table.insert` + counter
  (events.lua:159-164). `string.find(serialized, kw, 1, true)` uses the plain
  4th arg, valid in 5.0. `_G['arg' .. ai]` computed-key indexing is 5.0-safe.
  No 5.1+ syntax introduced.
- **Arm-gating is leak-proof:** the arm hook (spell_trace_core.lua:135-141)
  requires `macroTorch.context` AND `macroTorch.inCombat`. Verified in
  core/combat_context.lua: onCombatExit (line 22-25) sets `inCombat = false`
  and replaces `context` with a fresh `{}` — the `_rawdiag2Active` flag cannot
  survive a combat exit, and on a fresh session `context` is nil until
  onCombatEnter. No stale-arm path exists.
- **Selftest interference: none.** Grep confirms no `inCombat`, `safeRip`, or
  `rawdiag` references in either selftest file. Q-02/Q-03
  (classes/druid/selftest.lua:774/811) call `recordCastTable('Rip')` in a
  boot-time test where `macroTorch.context` is nil and `macroTorch.inCombat`
  is nil, so the arm hook short-circuits; the pair ledger reads
  `_rawdiag2Active` from the nil context and stays silent. Even a hypothetical
  in-combat re-run cannot corrupt assertions: the arm hook writes only
  `macroTorch.context` fields, never the fake `loginContext` the assertions
  read, and Q-02/Q-03 stub `macroTorch.show` so `macroTorch.log` produces no
  chat noise.
- **Disarm-before-duty ordering is consistent:** the RAW_COMBATLOG scout block
  (events.lua:144-180) runs before the tier-1 whitelist and may itself disarm;
  the pair ledger in processRawAuraApply (spell_trace_core.lua:273) reads the
  flag afterwards in the same synchronous handler, so the ledger can never log
  beyond a disarmed window. The window can also never be skipped: the first
  RAW event after 60s disarms before dumping.
- **No nil-crash surface added:** in the cat.lua stamp, every new read is
  shielded by pre-existing code that already dereferences the same objects
  (`isRipPresent` at cat.lua:426 already calls `macroTorch.target.hasBuff`
  before the stamp; `ripLeft` returns a memoized number, never nil — verified
  Druid.lua:1146-1162 always assigns before returning; `peekLandEvent`
  returns nil-safe via the `isCanAttack` guard and the stamp null-handles it;
  `rawdiag2IntentDepth` guards the full loginContext/intentTable/mob chain and
  falls back to 0). `computeRip_Duration()` is nil-arg tolerant
  (Druid.lua:1194-1208), so even the uncached `ripLeft` compute path cannot
  error.
- **Dedup placement is correct:** the arm hook sits AFTER the 0.2s
  duplicate-record early return (spell_trace_core.lua:105-108), so dual
  UNIT_CASTEVENT + UNIT_SPELLCAST_SUCCEEDED firings of one cast do not
  double-reset the window.
- **Ledger exactly-one-line invariant holds:** no-marker and guid-mismatch
  paths log and return; success path logs exactly one of pair-ok /
  no-pair:no-intent (mutually exclusive on `intent`).
- **Volume bounds hold structurally:** scout dump hard-capped at 150 lines per
  arm via the pre-dump check, auto-disarm at 60s wall-time, `macroTorch.log`
  rotation bounded at 500 SavedVariables entries (interface_debug.lua:110-114).
- **Security:** all output flows through `macroTorch.log` →
  `DEFAULT_CHAT_FRAME:AddMessage` with `tostring` coercions; no file writes,
  no secrets, no eval/dofile. The 1.12 client's AddMessage does not parse
  clickable links (a TBC+ feature), so raw-line text is inert. Client-side
  addon context — no trust boundary crossed.

Two Warnings and three Info findings below.

## Warnings

### WR-01: ctx stamp re-queries hasBuff live instead of reading the cached decision input — the evidence can diverge from what isRipPresent decided on

**File:** `classes/druid/cat.lua:439`

**Issue:** The stamp's own comment (cat.lua:433-437) and the plan claim the
decision inputs are "read from already-computed clickContext caches ... so
these reads hit caches". True for `ripLeft(clickContext)` (memoized at
Druid.lua:1146-1162) but **false for hasBuff**: the stamp calls
`macroTorch.target.hasBuff('Ability_GhoulFrenzy')` directly — a fresh live
40-slot `UnitDebuff`+`UnitBuff` scan (entity/Unit.lua:26-34) — instead of the
cached `clickContext.isRipPresent` (Druid.lua:1137-1143) that actually fed the
cast decision. `clickContext` caches persist across clicks within a fight, so
the decision's hasBuff sample and the stamp's hasBuff sample can be taken
hundreds of milliseconds apart. For the arbitration this divergence is
material: `isRipPresent=true` (decision saw our Rip active, hence the
suppression question) can stamp `hasBuff=false` (live scan says gone), or vice
versa, misleading the offline verdict on exactly the field the forensics
exists to pin down — the same class of contradiction the todo's
`hasBuff` debuff-view leg warns about.

**Fix:** stamp the cached decision input, and log the live scan separately
only if a divergent sample is wanted:

```lua
macroTorch.log('[RAWDIAG2 ctx] isRipPresent=' .. tostring(clickContext.isRipPresent) ..
    ' hasBuffLive=' .. tostring(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) ..
    ' ripLeft=' .. string.format('%.3f', macroTorch.ripLeft(clickContext)) ..
    ' landTop=' .. (rawdiag2LandTop and string.format('%.3f', rawdiag2LandTop) or 'nil') ..
    ' intentDepth=' .. tostring(macroTorch.rawdiag2IntentDepth('Rip')) ..
    ' cp=' .. tostring(clickContext.comboPoints) ..
    ' t=' .. string.format('%.3f', GetTime()), 'yellow')
```

At minimum, correct the comment and the line label — `hasBuff=` must be
`hasBuffLive=` so offline readers cannot mistake it for the decision input.

### WR-02: arming is unconditional on every in-combat Rip cast — incidental combat floods the shared 500-line rotating buffer and can rotate out the actual test evidence before export

**File:** `core/spell_trace_core.lua:135-141` (arm), dumping via `core/events.lua:144-180`, persistence via `interface_debug.lua:110-114`

**Issue:** Every recorded in-combat Rip cast arms the scout — every fight, for
the lifetime of the build. In a keyword-heavy fight ('afflicted'/'Bite' lines
are frequent beyond dummy tests), the per-arm budget (20 unconditional
samples + up to 150 keyword lines) can be consumed in seconds, and the pair
ledger goes silent for the rest of that window (the cap flips
`_rawdiag2Active` off and the ledger reads the flag — so a noisy window can
kill the decisive pair-ok/no-pair evidence for the very cast that armed it).
Combined with the CD-paced sampling protocol this is a real forensic risk:
between the dummy-test session and the user copying out
`SavedVariables/SuperMacro.lua`, any incidental combat (a dungeon, a raid, a
world boss) runs Rip casts that arm windows and flood the shared 500-line
`MACRO_TORCH_LOG` rotation — plausibly displacing the R0~R3 evidence lines
before export. It is also permanent per-cast chat noise (`[RAWDIAG2 ctx]` on
every accepted Rip with no gate at all) until a removal build lands.

**Fix:** add a master switch so the instruments only run in the sampling
session, e.g. arm only when explicitly enabled:

```lua
if spell == 'Rip' and macroTorch.context and macroTorch.inCombat
        and macroTorch.rawdiag2Enabled then
    ... -- existing arm body
end
```

with `macroTorch.rawdiag2Enabled` defaulting to `false` in `macro_torch.lua`
and set via `/script macroTorch.rawdiag2Enabled = true` for the dummy
protocol; gate the cat.lua ctx stamp on the same flag. Also record the
operational note: export `MACRO_TORCH_LOG.messages` immediately after the
test window (logout/reload) so evidence cannot be rotated out.

## Info

### IN-01: the first-20 layout samples are consumed by the highest-rate raw traffic, not by apply lines

**File:** `core/events.lua:173`

**Issue:** The unconditional-sample budget (`_rawdiag2Samples < 20`) starts
counting at arm time — the instant of the cast record. Combat-log melee/white
lines arrive far faster than the ~1s Rip apply, so in any populated zone the
"field-layout samples" are almost always 20 swing/aura-noise lines, never the
decisive apply/fade lines the layout samples are meant to illustrate. Keyword
matching still catches the decisive lines (the 'afflicted'/'fades' filter is
the real workhorse), so the probe remains functional — but the sample feature
does not do the job its comment describes. Also note the plain substring
match means 'Rip' matches `Riposte` and 'Bite' matches any bite-family line;
only noise within the 150 cap in keyword-heavy fights.

**Fix:** acceptable as-is for the dummy protocol; if layout samples of apply
lines are wanted, anchor the sample budget to keyword-matched lines only
(increment `_rawdiag2Samples` in the `interesting` branch). Or state in the
comment that samples are for arg-shape documentation and are expected to be
consumed immediately.

### IN-02: tail-arg serialization relies on the client nil-ing unused arg globals between events

**File:** `core/events.lua:159-164`

**Issue:** The nil-stop loop assumes `_G['arg' .. ai]` is nil beyond the
event's real arg count. On the 1.12 event-dispatch model the `arg1..argN`
globals are reused per dispatch and historical client versions did not
guarantee nil-ing unused slots. If the SuperWoW RAW_COMBATLOG payload has
fewer args than the previous event left populated, the dump could splice
stale tail args from an earlier event into the line. Cosmetic for the
verdict (arg1=channel and arg2=line, the two fields the arbitration reads,
are always freshly set), but it can make a "layout sample" look malformed.

**Fix:** defensively bound the loop to the payload actually delivered — e.g.
also require `ai <= 10` is no fix; instead capture expected shape knowledge:
read arg1/arg2 directly (as the tier-1 whitelist already does) and stop
serializing at the first arg known-optional per the RAW_COMBATLOG arity, or
verify on first use in the dummy session and adjust the cap. Low-confidence
environmental note — may be a non-issue on this SuperWoW fork; flagging so
the sampler treats a spliced tail as artifact, not evidence.

### IN-03: window/cap/sample constants are inline magic numbers

**File:** `core/events.lua:147,151,161,173`

**Issue:** 60 (window seconds), 150 (line cap), 20 (sample budget), 12
(arg-count ceiling) are inlined literals, and 60/150 appear once each in the
disarm messages. The rhythm of the constants is documented in the block
comment but a re-tune (e.g. lengthening the window for a slower multi-cat
pull) requires editing three spots plus the comment, inviting drift between
code and its own documentation.

**Fix:** hoist to file-local constants next to `RAWDIAG2_KEYWORDS`:

```lua
local RAWDIAG2_WINDOW_SECS = 60
local RAWDIAG2_LINE_CAP = 150
local RAWDIAG2_SAMPLE_BUDGET = 20
local RAWDIAG2_MAX_ARGS = 12
```

and interpolate them in both disarm messages.

---

_Reviewed: 2026-09-07T12:06:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_