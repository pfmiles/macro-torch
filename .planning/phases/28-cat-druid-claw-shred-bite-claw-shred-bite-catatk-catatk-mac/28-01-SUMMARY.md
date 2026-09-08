---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
plan: "01"
subsystem: instrumentation
tags: [lua-5.0, raw-combatlog, json, superwow, offline-analyzer, tracer]

# Dependency graph
requires:
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: "LAND_INTENT_TTL(=2) + LRUStack + events.lua RAW branch + bbcheck.js verification gate"
  - phase: 26-phase-fast
    provides: "quick 260907-vve LOG_MAX_SIZE ring + CONFIG_OPTIONS registry (4 entries at plan start)"
provides:
  - "macroTorch.cpDamageLog per-session switch, nil-guard default false, CONFIG_OPTIONS 5th entry (D-06)"
  - "macroTorch.jsonEncodeScalar strict JSON scalar encoder, Lua 5.0 gsub function-branch escapes"
  - "macroTorch.context._cpDamageBatch combat-entry batch stamp (D-11)"
  - "macroTorch.cpDamageSample / cpDamageCast / pairCpDamageIntent / onCpDamageLine / cpDamageEvent — claw cast-to-damage observation chain on an independent intent queue (D-02 red line)"
  - "events.lua SELF_DAMAGE channel gate between RAWDIAG2 scout and tier-1 whitelist"
  - "tools/cpdamage.lua offline analyzer skeleton — extract / sandbox / filter / decode / print (D-14/D-15)"
affects: ["28-02 (shred/bite hooks + Category U selftests)", "28-03 (analyzer statistics / fitting / --selftest)", "28-04 (user-machine UAT)"]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 8635
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: ["tools/cpdamage.lua (offline analyzer, self-contained Lua 5.0 CLI)"]
  patterns: ["[cpDamage] prefixed JSON line + fixed 11-field order interop contract", "independent parallel intent queue (cpDamageIntents LRUStack(8)) alongside Phase 27 intentTable"]

key-files:
  created: ["tools/cpdamage.lua"]
  modified: ["macro_torch.lua", "impl_util.lua", "core/combat_context.lua", "classes/druid/Druid.lua", "core/spell_trace_core.lua", "core/events.lua"]

key-decisions:
  - "Channel gate adds nothing to the tier-1 whitelist — SELF_DAMAGE is consumed before the tier-1 early-return, keeping Phase 27 consumers disjoint per channel"
  - "cpDamage intents remove (table.remove) on both purge and pair — no state/landAt field because damage pairing carries no fail-wins semantics"
  - "tools/cpdamage.lua flag literals (selftest/json-out) spelled via concatenation so no string contains an adjacent hyphen pair — bbcheck strips line comments before strings, and an in-string '--' would eat the rest of the line and trip the bracket gate"
  - "hits/crits verbs stay implicit in the matched pattern; the JSON only records the crit boolean (D-07 field), the two Lua 5.0-legal patterns never a combined alternation"

patterns-established:
  - "cpDamage tracer slice: cheap-first gate order in cpDamageSample (switch -> dummy -> batch -> GCD probe -> bleed scan)"
  - "offline analyzer sandbox: loadstring+setfenv (5.0/5.1) / load(...,'t',env) (5.2+) dual path, empty environment"

requirements-completed: [D-01, D-02, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12, R8]

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "Config & tool layer — cpDamageLog switch (default false), CONFIG_OPTIONS 5th entry, jsonEncodeScalar encoder, combat-entry batch stamp"
    requirement: "D-06"
    verification:
      - kind: other
        ref: "node .planning/phases/27-.../tools/bbcheck.js macro_torch.lua impl_util.lua core/combat_context.lua + grep anchors (nil-guard==1, cfg entry==1, probe flag==1, encoder==1, batch==1, CONFIG_OPTIONS size==5)"
        status: pass
    human_judgment: false
  - id: D2
    description: "claw cast-side chain — cpDamageSample 11-field snapshot + cpDamageCast independent LRUStack(8) intent plant in obj.claw"
    requirement: "D-02"
    verification:
      - kind: other
        ref: "bbcheck + build.sh + grep -cE 'function macroTorch\\.(cpDamageSample|cpDamageCast|...)' SM_Extend.lua == 5"
        status: pass
    human_judgment: true
    rationale: "cast-time snapshot semantics (GCD probe ordering, guid under SuperWoW, energyPool/bledCount values) can only be proven on the live client; machine has no Lua runtime — 28-03 selftests and 28-04 UAT carry runtime proof"
  - id: D3
    description: "event-side chain — SELF_DAMAGE channel gate + onCpDamageLine hits/crits parsing + pairCpDamageIntent 2s window + cpDamageEvent 11-field JSON emit"
    requirement: "D-01"
    verification:
      - kind: other
        ref: "bbcheck + build.sh + grep -c \"arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE'\" core/events.lua == 1 (gate between scout end and tier-1)"
        status: pass
    human_judgment: true
    rationale: "real RAW_COMBATLOG damage-line pairing needs an in-game Training Dummy session; static gates prove assembly and placement only"
  - id: D4
    description: "tools/cpdamage.lua offline analyzer skeleton — extract (string/comment aware brace matching) / sandboxed load / [cpDamage] prefix filter / recursive JSON decode / fixed-order entry print with bad-line and cap counting"
    requirement: "D-14"
    verification:
      - kind: other
        ref: "bbcheck BALANCED + grep forbidden tokens (no length operator, no goto) == 0 + 4 top-level functions + build manifest untouched"
        status: pass
    human_judgment: true
    rationale: "the script must run under Lua 5.0/5.1/5.4 on the user machine (no interpreter exists here); 28-03 --selftest runs the round-trip fixtures on the real interpreters"

# Metrics
duration: 12min
completed: 2026-09-08
status: complete
---

# Phase 28 Plan 01: catAtk claw/shred/bite damage instrumentation — tracer slice Summary

**cpDamageLog-switched cat damage observation chain: cast-side 11-field snapshot on an independent intent queue, SELF_DAMAGE channel gate, guid-window pairing, `[cpDamage] ` JSON persistence, plus a Lua 5.0 offline extractor skeleton (tools/cpdamage.lua)**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-08T12:24:48Z
- **Completed:** 2026-09-08T12:36:20Z
- **Tasks:** 3
- **Files modified:** 7 (6 modified + 1 created)

## Accomplishments
- claw 单条路径全链打通（静态证明）：开关 → 四级廉价门采样（cpDamageLog/isTargetDummy/batch/GCD probe + bleedCount 0-3）→ 独立 intent 队列（LRUStack(8)，与 Phase 27 intentTable 完全并行）→ SELF_DAMAGE 通道门 → 双 Lua 5.0 pattern hits/crits 解析 → 2s guid 窗口配对 → 固定 11 字段序 JSON 落盘
- 每个卸决策约束兑现：miss/dodge/parry 零附加代码自然丢弃（D-03）、tier-1 白名单集合一字未改、catAtk 决策文件（combo.lua/cat.lua）与构建清单零改动、Phase 27 land 符号与 cpDamage 五函数在 SM_Extend.lua 中并存（14 处 land 命中）
- tools/cpdamage.lua 骨架 575 行：字符串/注释感知括号配平提取（bbcheck 同序）、双路径沙箱执行（loadstring+setfenv / load-t+env）、精确前缀过滤、六形态递归 JSON 解码（深度上限 16）、32MB/50k 防御上限、条数/坏行计数
- 验证电池全绿：7 文件 bbcheck BALANCED、build.sh 重建含 5 个 cpDamage 函数定义、全部 grep 锚点按 plan 期望值命中、git diff --check 干净、diff 范围恰为声明的 7 文件

## Task Commits

Each task was committed atomically:

1. **Task 1 (tracer): 配置与工具层 — cpDamageLog 开关 + JSON 微编码器 + batch 戳** - `fc60d64` (feat)
2. **Task 2: claw 唯一路径 — 采样/独立 intent/通道门/配对/发射** - `a602cc0` (feat)
3. **Task 3: 远端终点 — tools/cpdamage.lua 提取→过滤→解码→吐条目骨架** - `17492f7` (feat)

**Plan metadata:** see final docs commit below.

## Files Created/Modified
- `macro_torch.lua` - cpDamageLog nil-guard (default false) + `_cpDamageProbeWarned` per-login re-arm + CONFIG_OPTIONS 第 5 项（survey 注释 four→five）
- `impl_util.lua` - `macroTorch.jsonEncodeScalar` 严格 JSON 标量编码器（gsub function 分支转义 `\\`/`\"`/控制字符 `\u00XX` 大写四字符宽；禁 `%q`）
- `core/combat_context.lua` - onCombatEnter 末尾 `context._cpDamageBatch = GetTime()`（脱战整体重建 context → 下一批自动新值）
- `classes/druid/Druid.lua` - `cpDamageSample`（11 字段快照 + guid + gcdOk）、`cpDamageCast`（独立 intent 队列种植）、obj.claw 挂两行（采样先于 `_castSpell`，cast 且 gcdOk 才种植）
- `core/spell_trace_core.lua` - `pairCpDamageIntent`（TTL purge + 逆序小写 guid 配对）、`onCpDamageLine`（hits/crits 双模式依序）、`cpDamageEvent`（固定字段序 JSON 组装 + `macroTorch.log('[cpDamage] ' .. json)`）
- `core/events.lua` - RAW 分支通道门（scout 之后、Tier 1 之前）：`cpDamageLog and arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' and arg2`
- `tools/cpdamage.lua` - 新建：离线分析器骨架（readAll/extractMacroTorchLog/loadBlockSandboxed/getMessages/decodeJson/main），自包含 Lua 5.0 方言，绝不进构建清单

## Decisions Made
- 通道门采用「按通道分派」而非修改 tier-1 白名单集合：SELF_DAMAGE 行在门内被消费，tier-1 return 挡住 land 消费者，两边语义零互扰。（与计划一致）
- cpDamage 配对键 = guid + 2s 窗口（不含技能名维度）：由「一 cast 帧恰好一条 intent」的每按键一 action 红线保证；队列元素不带 state/landAt（无 fail-wins 语义），purge 与命中均直接 `table.remove`。
- 脚本 flag 字面量（`--selftest`/`--json-out`）以 `'-' .. '-selftest'` 拼接书写：bbcheck 先剥行注释后剥字符串，字符串内相邻连字符对会吞掉行尾并破坏括号平衡门（Task 3 实测触发后规避）。
- crit 只记布尔字段入 JSON、verb 不单独存储：命中哪条模式即确定 crit 真值与 {hits, crits} 白名单成员资格（A3 容错保留）。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] tools/cpdamage.lua 内字符串含 `--` 触发 bbcheck 括号门失败**
- **Found during:** Task 3 verify（bbcheck 对脚本输出 MISMATCH）
- **Issue:** bbcheck.js 的剥离顺序为「块注释→长字符串→行注释→短字符串」，行注释剥离先于字符串剥离；`--selftest`/`--json-out` 字面量写进字符串后，`--` 起被当行注释吞到行尾，`io.write(` 的 `(` 失去闭合 → MISMATCH
- **Fix:** flag 字面量改为顶层局部 `FLAG_SELFTEST = '-' .. '-selftest'` / `FLAG_JSON_OUT = '-' .. '-json-out'` 拼接构造，全部引用点改用常量；文件内不再有任何字符串包含相邻连字符对
- **Files modified:** tools/cpdamage.lua
- **Verification:** bbcheck BALANCED + 全文件「字符串内双连字符」node 扫描 0 命中 + 530/532/535/539/543 行引用点行为等价
- **Committed in:** 17492f7（Task 3 commit）

---

**Total deviations:** 1 auto-fixed (Rule 3 blocking)
**Impact on plan:** 修复为使计划自身 verify 门（bbcheck BALANCED）成立的实现手段调整，verify 锚点、行为规格、构建清单零改动。无范围蔓延。

## Issues Encountered
- 新文件 tools/cpdamage.lua 的两次 Write 均混入生成损坏（`= =`、`bytete`、`skipipWs`、杂引号等向 token），bbcheck MISMATCH 与自建 node 词法/括号诊断逐点定位后修复；提交前以「bbcheck + 禁用 token grep + 引号结构扫描 + 损坏模式 grep」四重静态审计清零。这再次验证了本机无 Lua 解释器约束下静态门（尤其 bbcheck）的捕获能力。

## Known Stubs

以下均为 28-01 计划明确预留的分派位（Task 3 `<done>` 声明「为 28-03 的统计与报表扩展预留 main 内的分派位」），属有意占位而非未完成功能：

| 文件 | 行 | 内容 | 原因 |
|------|----|------|------|
| tools/cpdamage.lua | 542 | `io.write('selftest runs in the full analyzer build\n')` `--selftest` 分支占位 | 28-03 实现完整 --selftest（fixture 往返 + 5.0 敏感断言） |
| tools/cpdamage.lua | 546 | `--json-out` 分支占位输出 | 28-03 实现结果文件输出 |

另有计划级既定分工：运行级验证（用户机 `--selftest` 两解释器 + 打桩 UAT）由 28-03/28-04 携带（28-VALIDATION.md 确立本机无 lua）。

## User Setup Required

None - no external service configuration required.（注意：持久化依赖游戏机 SuperMacro .toc 含 `MACRO_TORCH_LOG` 声明，RESEARCH A2 已设 28-04 checkpoint:human-verify 覆盖，非本计划行为。）

## Next Phase Readiness
- Wave 2 前置资产全部就位：开关（D-06）、编码器（D-12 前置）、batch（D-11）、采样/种植/配对/发射五函数、events 通道门、分析器骨架。
- 28-02 可直接在已证明的骨架上外扩 obj.shred/obj.ferocious_bite 的挂点（同 obj.claw 两行式）与 Category U 自测；28-03 在 tools/cpdamage.lua 的 main 分派位扩展统计/拟合/报表与完整 --selftest。
- 无阻塞项。

## Self-Check: PASSED
- 三任务 commit 存在：fc60d64 / a602cc0 / 17492f7
- 7 个产物文件全部存在于工作树且 bbcheck BALANCED
- build.sh 重建 SM_Extend.lua 成功，含 5 个 cpDamage 函数定义

---
*Phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac*
*Completed: 2026-09-08*