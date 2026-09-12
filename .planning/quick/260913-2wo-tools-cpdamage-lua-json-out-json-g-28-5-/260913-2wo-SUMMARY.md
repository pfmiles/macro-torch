---
quick_id: 260913-2wo
phase: quick
plan: 260913-2wo
subsystem: tools
tags: [cpdamage, json, strict-json, encoder, G-28-5, lua-5.0]
requires: []
provides: ["encodeKey quoting numeric object keys in cpdamage --json-out archives"]
affects: [tools/cpdamage.lua]
status: complete
---

# Quick Task 260913-2wo: tools/cpdamage.lua `--json-out` 严格 JSON 化（G-28-5 闭合） Summary

`lua tools/cpdamage.lua <SV> --json-out <file>` 产出的归档现在全部对象键为带引号字符串（tier 桶 `"0".."3"`、batch 桶 `"1000"` 等），Node `JSON.parse` 无错解析；新增 `encodeKey` 键编码助手（字符串键经 `encodeScalar`、数字键为引号包裹的稳定跨版本数文本、其余类型引号 tostring 兜底），`encodeValue` 对象分支改走 `encodeKey(k)`，selftest 33→35 项（新增精确引号形状断言 + 严格 decoder 往返断言），三个 Lua 解释器（5.0.3/5.1.5/5.4.7）全绿；屏显报告字节级逐字不变（实测 pre/post 版本 stdout 全等）。

## Tasks Completed

### Task 1: 新增 encodeKey + 两项 selftest 断言（先 RED 后 GREEN）
- **Commit:** `1b62f12` — `fix(tools): quote numeric object keys via encodeKey in cpdamage --json-out (G-28-5)`
- **Changes:** `encodeKey` 插于 `encodeScalar`（564 行 `end`）与 `encodeValue` 注释之间（17 行新增，含注释）；对象分支 `encodeScalar(k)` → `encodeKey(k)`（598 行）；`runSelftest` 在 mUni/bad2 解码检查之后、`statsRef` 构造之前插入两条断言（期望串用 `DQ = string.char(34)` 拼接，沿用文件既有的括号门避让设计）
- **RED 见证:** 修改前基线 `ALL 33 PASSED`/exit 0；仅加入两条断言后 5.4.7 上 `selftest: FAIL - json encoder quotes numeric object keys` + exit 1 —— 新门实测捕获 G-28-5（裸数字键 `0:{"n":0}` 被形状断言拒绝）
- **GREEN:** 修复后 5.4.7 上 `selftest: ALL 35 PASSED` + exit 0
- **Diff form:** 1 file, 26 insertions(+), 1 deletion(-)，仅三区域（encodeKey 新增、键函数替换、两条新断言）

### Task 2: 三解释器全绿 + 端到端 Node 严格解析 + 屏显不变口径门
- **Commit:** 无（纯验证与复查，零代码变更）
- **三解释器:** 5.0.3 / 5.1.5 / 5.4.7 均 `selftest: ALL 35 PASSED` 且 exit 0（Lua 5.0 运行时实证通过，`[0]` 构造器键、`string.format` 等均为 5.0 既有特性）
- **端到端:** `lua tools/cpdamage.lua /tmp/luabuild/sv.lua --json-out /tmp/luabuild/out-x-g285.json`（5.0.3）exit 0 → Node v24.19.0 `JSON.parse` 打印 `STRICT-JSON-OK`；归档内容实测 tier/batch 桶键均为引号形式（`"claw":{"1":{"n":0},"2":...}`），对比旧产物 `out-x.json` 的裸键病灶（`{1:{"n":0},...}`）已消除
- **屏显不变（实证，强于计划的 grep 口径门）:** 用 `git show HEAD~1:tools/cpdamage.lua` 提取修复前版本，同一输入、同一 `--json-out` 路径各跑一次，两次 stdout `diff` 结果为空 → `SCREEN-OUTPUT-IDENTICAL`（printReport/printClawShredTable/printOocTable/printBiteLine/decisionLines 输出逐字不变）
- **计划口径门:** `git diff HEAD~1 | grep -E '^[+-]' | grep -cE 'printReport|printClawShredTable|printOocTable|printBiteLine|decisionLines'` = `0`；diff 仅上述三区域；`encodeScalar` 一字未动
- **Lua 5.0 合规扫描:** 新增行无 `#` 长度运算符、无 goto/`::`、无 `\x` 十六进制转义；无 CRLF（行尾 LF，`.gitattributes` 约定）

## Deviations from Plan

None - plan executed exactly as written. 补充说明（非偏差，属计划口径内执行）：

- **encodeValue 头部注释保留原样：** 计划任务 2 步骤 3 锁定 diff 仅三区域，故 566-568 行注释 "keyed through encodeScalar" 未改；`encodeKey` 自带注释已声明其对键编码的取代关系。若要同步该注释措辞，须超三区域门，留待后续计划处理。
- **stdout 逐字对比为计划 grep 口径门的加强证明：** 计划仅要求 diff 行不含屏幕函数名（0 计数门）；本执行额外用 HEAD~1 版本实跑对比，得到字节级全等证据（同一输入、同一输出路径下唯一差异为零）。
- **旧产物 `/tmp/luabuild/out-x.json` 结构为旧版工具的 `aggregate` 包裹形态：** 仅用作裸键病灶的背景证据，未作为验证基准；本任务的严格解析基准是新产出 `out-x-g285.json` 的 Node `JSON.parse` 通过。

## Unrun Verification

无——计划内全部验证（三解释器 selftest、真实 SV 端到端 + Node 严格解析、屏显不变口径门、Lua 5.0 合规复查）均已在本机实跑完成；`tools/` 目录不参与构建，全程未运行 build.sh，`SM_Extend.lua` 零读写。

## Threat Flags

无——离线分析工具改动，不引入任何网络端点、鉴权路径或信任边界 schema 变化；`--json-out` 写出路径沿用既有行为。

## Known Stubs

无。

## Self-Check: PASSED

- File created/modified exists: `/home/admin/workspace/macro-torch/tools/cpdamage.lua`（工作树，diff 已核验 26+/1-）
- Commits exist: `1b62f12`（`git log -1` 已核验，`fix(tools): quote numeric object keys via encodeKey in cpdamage --json-out (G-28-5)`）
- 三解释器 `ALL 35 PASSED`、Node `STRICT-JSON-OK`、屏幕函数 diff 门 `0`、stdout 全等 —— 全部实跑通过