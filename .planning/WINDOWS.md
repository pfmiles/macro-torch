---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 2
total_count: 4
last_updated: 2026-09-08T13:49:44.997Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 21 | stub | classes/druid/cat.lua |  | No stubs introduced — pure comment addition only | open |  | 2026-07-29T14:37:47.097Z |  |
| 2 | 22 | stub | classes/druid/selftest.lua | 108 | Batch 2 end marker: placeholder for plan 22-02 expansion tests | open |  | 2026-07-30T15:31:25.495Z |  |
| 3 | 28 | stub | tools/cpdamage.lua | 542 | selftest branch placeholder prints placeholder text; full selftest lands in 28-03 | fixed |  | 2026-09-08T12:37:50.223Z | 2026-09-08T13:49:44.744Z |
| 4 | 28 | stub | tools/cpdamage.lua | 546 | json-out branch placeholder prints placeholder text; result-file output lands in 28-03 | fixed |  | 2026-09-08T12:37:50.446Z | 2026-09-08T13:49:44.997Z |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "21",
    "file": "classes/druid/cat.lua",
    "line": null,
    "description": "No stubs introduced — pure comment addition only",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-29T14:37:47.097Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "stub",
    "phase": "22",
    "file": "classes/druid/selftest.lua",
    "line": 108,
    "description": "Batch 2 end marker: placeholder for plan 22-02 expansion tests",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T15:31:25.495Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "stub",
    "phase": "28",
    "file": "tools/cpdamage.lua",
    "line": 542,
    "description": "selftest branch placeholder prints placeholder text; full selftest lands in 28-03",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-08T12:37:50.223Z",
    "resolved_at": "2026-09-08T13:49:44.744Z"
  },
  {
    "id": 4,
    "kind": "stub",
    "phase": "28",
    "file": "tools/cpdamage.lua",
    "line": 546,
    "description": "json-out branch placeholder prints placeholder text; result-file output lands in 28-03",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-08T12:37:50.446Z",
    "resolved_at": "2026-09-08T13:49:44.997Z"
  }
]
````
