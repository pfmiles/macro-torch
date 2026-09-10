---
phase: 29-landing
reviewed: 2026-09-11T03:30:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/HUMAN-UAT.md
  - classes/druid/selftest.lua
  - classes/hunter/Hunter.lua
  - core/events.lua
  - core/spell_trace_core.lua
  - interface_debug.lua
  - tools/cpbuild.lua
findings:
  critical: 0
  warning: 1
  info: 5
  total: 6
status: issues_found
---

# Phase 29: Code Review Report (29-04 Gap-Closure Delta + Range Superset)

**Reviewed:** 2026-09-11T03:30:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This pass covers the diff range `08ed9055^..HEAD`, with review rigor prioritized on the two
29-04 gap-closure deliverables — the `macroTorch.show` green/blue hue arms in
`interface_debug.lua` (commit 403116d) and the Category T-02 render-hue regression in
`classes/druid/selftest.lua` (commit 6bd0015) — plus a regression sweep over the other six
scoped files (phase 29 landing core, phase 30 DKI/cpBuild instrumentation, `tools/cpbuild.lua`).

**Verdict on the 29-04 focus:** the hue fix is correct. The pre-fix tree had the green arm
carrying a blue-dominant literal and the blue arm carrying `ChatTypeInfo["OFFICER"]` (green in
vanilla 1.12) — the exact inversion UAT gap G-29-3 diagnosed. The new literals
(`blue = {0, 0.5, 0.9}`, `green = {0, 1, 0}`) are hue-dominant per the D-14 contract, and the
label usage across the range is consistent: `'blue'` only from the inference announcer
(`spell_trace_core.lua:451`), `'green'` only from the two real-evidence announcers
(`:498`, `:598`), `'red'` for fail/cancel lines, `'yellow'` for probe warnings — a grep
inventory found no mismatched arms. T-02 drives the REAL `macroTorch.show` with planted
downstream consumers only, which is the right architecture.

**Prior-review provenance (not duplicated as new findings).** All five warnings of the phase-29
second-pass review (this file's previous revision, 2026-09-10) are verified fixed in the tree,
per `.planning/phases/29-landing/29-REVIEW-FIX.md` iteration 1:
- WR-01 (dedup-vs-announce asymmetry): the self-hit announce is now gated on `isCastCovered`
  (`core/spell_trace_core.lua:596-600`).
- WR-02 (no inference epoch guard): the `blip > ttl * 6` upper bound is in place (`:431`).
- WR-03 (stale "2s" comments): rewritten to 0.9s semantics (`:214`, `:481`).
- WR-04 (impossible HUMAN-UAT branch b): rewritten to green-then-red (`classes/druid/HUMAN-UAT.md:266`).
- WR-05 (self-hit channel ownership): target-name ownership check after absorb/damage suffix
  stripping (`:578-581`).

Phase-30 review fixes from commits 6272e90 / 7f85576 / 5f03a82 are likewise present:
`resetCpBuildDki` existence guards on both event joins (`core/events.lua:79-81`, `:104-106`)
and the GCD-probe troubleshooting split by channel (`classes/druid/HUMAN-UAT.md:318-319`).
The `.planning/WINDOWS.md` unrun-verify ledger already tracks items 6 (S-05..S-12 DKI pins) and
7 (T-02 render-hue asserts) as in-game `/mt` runs pending on the Windows+Cygwin client; WR-01
below overlaps item 7's coverage domain and is reported with that provenance noted.

**Scoping note:** the review-config file list contained `tools/c/cpbuild.lua`; the actual file
is `tools/cpbuild.lua` (no `c/` subdirectory), which was reviewed. Same class of config-typo the
previous revision recorded for `core/spell_trace_core.l.lua`.

No CRITICAL defects are provable. Decision-facing consumers (`isRipPresent`/`isRakePresent`/
`isPouncePresent` debuff AND checks, `ripLeft`/`rakeLeft` clamping) still neutralize the worst
ledger corruptions identified in earlier passes.

## Warnings

### WR-01: T-02's red/yellow arms are structurally indistinguishable — a channel swap or a yellow-to-green inversion passes

**File:** `classes/druid/selftest.lua:1865-1874` (planted ChatTypeInfo at 1843-1849; yellow
assert at 1869-1870)

**Issue:** The test header claims "a hue inverted in any arm turns this test red/yellow," but
the oracle only discriminates the blue/green pair (the actual G-29-3 defect). Two of the five
arms are blind:
- The red arm asserts `r >= g and r >= b` and the yellow arm asserts `r >= b and g >= b`, but
  both real arms dereference planted `ChatTypeInfo` entries that are themselves warm-dominant
  (`YELL = {1, 0.5, 0}` is red-dominant; `SYSTEM = {1, 1, 0}`). If `show()` swapped `'red'` and
  `'yellow'`, cap2 would render the planted SYSTEM hue (1 >= 1 and 1 >= 0 both hold) and cap3
  the planted YELL hue (1 >= 0 and 0.5 >= 0 both hold) — every assertion still passes.
- The yellow assertion accepts any hue dominant in r OR g, including pure green: a yellow arm
  mapped to the green literal `{0, 1, 0}` yields `r >= b` (0 >= 0) and `g >= b` (1 >= 0) — pass.
- Unlike cap1, no assertion pins `cap2.id` / `cap3.id`, which would catch any swap at the
  channel level regardless of hue.

The comment's "any arm" guarantee is therefore overstated. The in-game execution of T-02,
including whether these arms ever see adversarial input, is also still an open unrun-verify
item (`.planning/WINDOWS.md` ledger item 7) — so the blind spot has not been exercised yet.

**Fix:** Pin channel identity alongside hue dominance, which closes the swap case
deterministically:

```lua
assert(cap2 and cap2.id == 'planted_yell',
    "T-02 red arm must resolve to the planted YELL channel, got " .. tostring(cap2 and cap2.id))
assert(cap3 and cap3.id == 'planted_system',
    "T-02 yellow arm must resolve to the planted SYSTEM channel, got " .. tostring(cap3 and cap3.id))
```

and/or make the planted `YELL` a genuinely warm-yellow literal (e.g. `{1, 0.8, 0}`) so the
hue check for the yellow arm requires `r` and `g` strictly above `b` with a visible gap, and
shrink the header comment to claim coverage of the blue/green inversion plus channel pinning
for the rest.

## Info

### IN-01: `decodeJson` in tools/cpbuild.lua is dead code (~245 lines, zero call sites)

**File:** `tools/cpbuild.lua:315-559`

**Issue:** The [cpBuild]/[cpBuildT] families are space-separated, not JSON; nothing in the file
calls `decodeJson` (the only later reference is a comment at line 669). The function arrived as
part of the byte-copied cpdamage.lua harness (D-07) and is pure maintenance surface: it must
stay Lua-5.0-legal forever and passes the same batteries but can never execute.

**Fix:** Delete the function and the harness comment's mention of it, or add a one-line note
that it is retained only for harness parity with tools/cpdamage.lua (D-07) and is intentionally
unexercised.

### IN-02: events.lua handler arms for never-registered events are unreachable

**File:** `core/events.lua:118-127` (PLAYER_DEAD, CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS,
CHAT_MSG_SPELL_AURA_GONE_SELF), `:196-198` (CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES /
CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE)

**Issue:** The registrations for all five are absent (three commented out at lines 34-36; the
creature-vs-self pair never registered), so every branch is dead. Harmless, but a maintainer
reading the dispatcher believes these channels are handled. Pre-existing pattern, unchanged by
this range.

**Fix:** Either drop the dead branches or add the corresponding `frame:RegisterEvent` calls;
if the events are reserved for future work, mark them with a `-- reserved (unregistered)` note
so the dispatch table stays honest about what can fire.

### IN-03: parseSamples silently truncates at the first nil hole in the message ring

**File:** `tools/cpbuild.lua:743-744` (`countList` via ipairs at 77-83)

**Issue:** `countList(messages)` counts with `ipairs`, which stops at the first nil index; the
loop then reads only `messages[1..total]`. The client writer keeps the ring contiguous
(`table.insert` + `table.remove(messages, 1)`), so genuine data is safe, but a hand-edited or
corrupted SavedVariables file with a hole would silently drop every entry after the hole with
no warning — the analyzer would report partial statistics as complete.

**Fix:** Count all non-nil entries in one pass (a nil-aware counter) instead of an `ipairs`
count, and emit a warning when holes are detected, so a truncated read can never masquerade as
a complete report.

### IN-04: `--rake-dur` accepts non-positive values silently and produces nonsense cutoffs

**File:** `tools/cpbuild.lua:1163-1201` (flag parse), `:878-899` (calculatePassRates)

**Issue:** `--rake-dur 0` or a negative value passes `tonumber` and the parser, and
`calculatePassRates` then computes cutoffs `d - 1` / `0.9*d - 1` that are zero or negative —
every `t <= cutoff` fails, both rows report 0% with no error, and the user cannot tell the
output is garbage from a bad flag.

**Fix:** Reject non-positive durations at parse time:

```lua
local dur = tonumber(args[i + 1])
if dur == nil or dur <= 0 then
    io.write('error: ' .. FLAG_RAKE_DUR .. ' expects a positive number of seconds, got: ' ..
        tostring(args[i + 1]) .. '\n')
    printUsage()
    os.exit(1)
end
```

### IN-05: T-02 swaps the live client globals ChatTypeInfo and DEFAULT_CHAT_FRAME with truncated stand-ins

**File:** `classes/druid/selftest.lua:1834-1858`

**Issue:** The planted `ChatTypeInfo` table has only five keys (the real table has ~20: PARTY,
RAID, WHISPER, etc.) and the planted `DEFAULT_CHAT_FRAME` stub has only `AddMessage`. The
window is synchronous within one OnUpdate tick (no chat events can interleave), restore-before-
assert is followed, and global stubbing is already the suite's precedent (Q-series replace
`macroTorch.show`/`loginContext` wholesale), so this is a documented hazard rather than a
defect. If the selftest runner ever becomes asynchronous or another addon's OnUpdate runs
mid-test, a nil-index or missing-method call in third-party code becomes possible.

**Fix:** Keep as-is for now (consistent with CR-01 precedent); if the runner changes, snapshot
and restore with `setmetatable({}, { __index = savedCTI })` so absent keys still resolve
during the window.

---

_Reviewed: 2026-09-11T03:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_