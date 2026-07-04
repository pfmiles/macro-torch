---
phase: 18
slug: spellid-spellid-land-tracing-spellidmonitored-current-castin
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-04
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | macroTorch.SelfTest (built-in Lua selftest framework) |
| **Config file** | build_order.txt |
| **Quick run command** | `./build.sh` (compile check — generates SM_Extend.lua) |
| **Full suite command** | In-game: `/macroTorch selfTest` — runs all selftest categories including Category L (spellId whitelist) |
| **Estimated runtime** | ~5 seconds (build + in-game selftest) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** Run `./build.sh` + in-game selftest (Category L)
- **Before `/gsd-verify-work`:** Full in-game selftest must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 1 | — | — | N/A | unit | `./build.sh` | TBD | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Detailed verification map will be populated after planning.*

---

## Wave 0 Requirements

- [ ] `core/selftest.lua` — Category L test stubs for `_spellIdMonitored` whitelist verification
- [ ] `./build.sh` — build succeeds with all Phase 18 changes in `build_order.txt`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| spellId correction in live combat | D-01, D-04 | WoW addon — no automated combat simulation | Enter combat, cast Rake/Rip/Pounce/Ferocious Bite, verify `SM_Extend.lua` persists corrected spellId |
| stale detection warning | D-04 | Requires real SuperWow event timing | Cast monitored spells rapidly, check SavedVariables log for `current_casting_spell was not cleared` warnings |
| monitorSpellId=false exclusion | D-03 | Explicit override test | Temporarily register a spell with `monitorSpellId=false`, verify it does NOT set `current_casting_spell` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending