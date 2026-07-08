---
phase: 19-druidcontrol-bash-druidcharge
plan: 01
subsystem: Druid macro methods
tags: [druid, refactor, combo-methods, bash, feral-charge, bear-form]
requires: []
provides:
  - macroTorch.druidCharge
  - Modified macroTorch.druidControl (Bash-free)
affects:
  - classes/druid/combo.lua
tech-stack:
  added: []
  patterns:
    - "One-action-per-press: form switch always paired with return"
    - "isSpellExist guard before low-level skill calls (Phase 13/16 pattern)"
    - "druidDefend form-switch pattern (isInBearForm + dire_bear_form isSpellExist + return)"
    - "druidControl target-acquisition pattern (isCanAttack + targetEnemy fallback)"
key-files:
  created: []
  modified:
    - classes/druid/combo.lua
decisions:
  - "Feral Charge uses 'safe' mode (range 25 + GCD + resource check), Bash uses 'ready' mode (CD-only)"
  - "druidCharge target check before form check (avoid wasted form switch with no target)"
  - "Dire Bear Form preferred over Bear Form via isSpellExist guard"
  - "druidControl keeps no form check, no isSpellExist guard — pure CC dispatch (D-07, D-08)"
metrics:
  duration: 3m55s
  completed_date: 2026-07-08
  status: complete
---

# Phase 19 Plan 01: druidControl Bash Split to druidCharge Summary

Split Bash interrupt from druidControl into a dedicated druidCharge() one-button macro method with automatic bear form switch and distance-driven Feral Charge/Bash dual-branch.

## One-Liner

Extracted Bash from druidControl into new druidCharge() with auto-form-switch, isSpellExist guards, and distance >= 8 branch for Feral Charge / < 8 branch for Bash; druidControl reduced to pure Hibernate/Entangling Roots CC dispatch.

## Tasks Completed

| # | Name | Commit | Status |
|---|------|--------|--------|
| 1 | Remove Bash branch from druidControl and promote elseif to if | `8df086b` | done |
| 2 | Create druidCharge() global macro method with distance-driven Charge/Bash | `5ff56f6` | done |
| 3 | Register druidCharge self-test in combo.lua | `2504ad4` | done |

## Key Changes

### druidControl (modified)
- **Removed:** `if target.distance < 8 then macroTorch.player.bash('ready')` block
- **Changed:** `elseif target.isBeastOrDragonkin()` to standalone `if target.isBeastOrDragonkin()`
- **Result:** Pure CC dispatch — Hibernate (beast/dragonkin) or Entangling Roots (otherwise)
- **No:** form checks, isSpellExist guards, or distance checks (per D-07, D-08)

### druidCharge (new)
- **Target check:** isCanAttack + targetEnemy() fallback (druidControl pattern, lines 272-280)
- **Form check:** isInBearForm → Dire Bear Form (isSpellExist guard) with bear_form fallback → return (druidDefend pattern, lines 282-288)
- **Distance >= 8:** isSpellExist("Feral Charge") guard → feral_charge('safe') (lines 290-294)
- **Distance < 8:** isSpellExist("Bash") guard → bash('ready') (lines 295-299)

### Self-test (new)
- "Druid: combo methods -- druidCharge exists" registered at line 338
- UnitClass('player') ~= 'Druid' guard, assert(type == "function"), isOptional=true

## Verification

All plan-level checks passed:

| Check | Expected | Actual |
|-------|----------|--------|
| `grep -c "function macroTorch.druidCharge" combo.lua` | 1 | 1 |
| `grep -c "target.distance < 8" combo.lua` | 0 | 0 |
| `elseif` in druidControl | 0 | 0 |
| `grep -c "druidCharge exists" combo.lua` | 1 | 1 |
| `./build.sh` exit code | 0 | 0 |
| `grep -c "function macroTorch.druidCharge" SM_Extend.lua` | 1 | 1 |

## Deviations from Plan

None - plan executed exactly as written.

## Threat Flags

None — all threat surface matches the plan's `<threat_model>` STRIDE register:
- T-19-01 (form check bypass): isInBearForm reads WoW client state — cannot be spoofed from addon code
- T-19-02 (infinite recursion): one-action-per-press design, no loops, no OnUpdate
- T-19-03 (target type leak): isBeastOrDragonkin reads existing combat data, no new exposure

## Requirements Satisfied

| ID | Requirement | Status |
|----|-------------|--------|
| D-01 | target check before form check in druidCharge | satisfied |
| D-02 | druidCharge auto-switch to bear form + return | satisfied |
| D-03 | distance >= 8: Feral Charge, < 8: Bash | satisfied |
| D-04 | isSpellExist guards for Feral Charge and Bash | satisfied |
| D-05 | druidCharge self-test suite | satisfied |
| D-06 | druidControl Bash branch removed | satisfied |
| D-07 | druidControl Hibernate branch reachable (elseif → if) | satisfied |
| D-08 | druidControl no form check, no isSpellExist, no distance check | satisfied |

## Self-Check: PASSED