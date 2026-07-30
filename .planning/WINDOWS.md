---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-07-30T15:31:25.495Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 21 | stub | classes/druid/cat.lua |  | No stubs introduced — pure comment addition only | open |  | 2026-07-29T14:37:47.097Z |  |
| 2 | 22 | stub | classes/druid/selftest.lua | 108 | Batch 2 end marker: placeholder for plan 22-02 expansion tests | open |  | 2026-07-30T15:31:25.495Z |  |

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
  }
]
````
