---
phase: quick-260913-46s
quick_id: 260913-46s
fixed_at: 2026-09-13T11:27:14Z
review_path: /home/admin/workspace/macro-torch/.planning/quick/260913-46s-tools-cpdamage-lua-cc-decisions-additive/260913-46s-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
commits:
  - 94f17b7 fix(260913-46s): WR-01 reject non-finite --erps values (inf/nan/overflow) so --json-out stays strict JSON
  - e042f9f fix(260913-46s): WR-02 guard rDB claw rows against nil avgEff/avgDmg (hand-written stats degrade instead of crashing)
verification_env: isolated git worktree /home/admin/workspace/macro-torch/.claude/worktrees/rf-260913-46s-149424-1789298619 (branch gsd-reviewfix/260913-46s-149424, fast-forwarded to main at cleanup). All gate runs happened inside that worktree before teardown.
---

# Phase quick-260913-46s: Code Review Fix Report

**Fixed at:** 2026-09-13T11:27:14Z
**Source review:** 260913-46s-REVIEW.md（status: issues_found，2 warning / 3 info）
**Iteration:** 1

**Summary:**
- Findings in scope: 2（WR-01、WR-02；IN-01~03 属 Info，fix_scope=critical_warning，按用户约束一律不审不改）
- Fixed: 2
- Skipped: 0
- Status: all_fixed

判定流程：按用户硬性约束，每个 in-scope finding 均先在三解释器（`/tmp/luabuild/lua-5.0.3/bin/lua`、`/tmp/luabuild/lua-5.1.5/src/lua`、`/tmp/luabuild/lua-5.4.7/src/lua`）与 Node v24.19.0 上实际复现，复现成功才修复；修复增量仅 `tools/cpdamage.lua`（总 delta +31/−2，2 个删除行即两处守卫条件行的替换），每 finding 一个原子 commit，宏本体、11 字段 schema、Druid.lua 零触碰，未执行任何构建脚本。

## WR-01: --erps 校验放过 inf/nan → --json-out 产出非法 JSON

**判定：真问题（已修复）。**

### 复现证据（修复前，worktree 内原样代码）

命令形状：`<解释器> tools/cpdamage.lua /tmp/luabuild/sv.lua --erps <V> --json-out /tmp/luabuild/repro-<V>.json`；随后 `node -e 'JSON.parse(fs.readFileSync(...))'` 验证落盘 JSON。

| 解释器 | `--erps inf` | `--erps nan` | `--erps 1e999` |
|--------|--------------|--------------|----------------|
| 5.0.3 | rc=0，屏显 `assumed ERPS = inf/s`，JSON `"erps":inf`，Node REJECT `Unexpected token 'i'` | rc=0，JSON `"erps":nan`，Node REJECT `Unexpected token 'a'` | rc=0，`1e999` 溢出为 inf，JSON `"erps":inf`，Node REJECT |
| 5.1.5 | 同 5.0.3，REJECT | 同 5.0.3，REJECT | 同 5.0.3，REJECT |
| 5.4.7 | 已 rc=1（其自身 tonumber 拒收 'inf' 字面量，JSON 未落盘） | 已 rc=1 | **rc=0**，JSON `"erps":inf`，Node REJECT `Unexpected token 'i'` |

结论：5.0.3 / 5.1.5 三路全部穿透守卫；5.4.7（最严格解释器）仍被溢出路径 `1e999` 穿透。三解释器全部可达，违背任务锁定约束 4（--json-out 必须 Node `JSON.parse` 可解析）。WR-01 为真问题。

### 修复内容（commit `94f17b7`，仅 tools/cpdamage.lua，+15/−1）

1. 新增 `local function validErps(num)`：`num ~= nil and num >= 0 and num == num and num <= 999`。NaN 通不过有序比较与自等测试；Lua 5.0 无 `math.huge`，溢出上限用字面量 999（远高于 28-OOC-BITE-CRITERIA.md 任何可达断点——文档基准封顶 25.4/s）。
2. `main()` 的 FLAG_ERPS 分支守卫由 `num == nil or num < 0` 改为 `not validErps(num)`；error 行文本、printUsage、exit(1) 行为逐字不变。
3. selftest 新增 5 项断言（直测 `validErps`，覆盖 inf/nan 拒绝路径）：nil 拒、`-3` 拒、NaN（`0 / 0`）拒、溢出 inf（`tonumber('1e999')`）拒、`0`/`26` 接受。banner 计数为动态 `tostring(passed)`，49 → 54（WR-01 后）→ 55（WR-02 后），与实际断言数一致。

### 验收输出（修复后）

- 三解释器 selftest：`ALL 54 PASSED` ×3（WR-01 提交后即时验证）。
- 同命令复测：inf / nan / 1e999 在三解释器全部 rc=1 + `error: --erps requires a non-negative energy-per-second number`，`--json-out` 目标文件**不落盘**（参数解析先于文件处理退出）。
- 边界六连（abc / -3 / 缺参 / inf / nan / 1e999）× 三解释器共 21 组：全部 rc=1 且恰好 1 条 error 行。

## WR-02: rDB 构造分支对 avgEff/avgDmg 无 nil 守卫

**判定：真问题（已修复）。**

### 复现证据（修复前）

构造最小 hand-written stats（`claw[2] = { n = 1, avgDmg = 1 }` 缺 avgEff；shred[2] 与 `biteRegression = { usable = true, ... }` 保证执行路径到达 rDB 构造行），以去除 `main(arg)` 尾部后拼装复现尾的 cpdamage.lua 副本运行：

| 解释器 | 实际输出 |
|--------|----------|
| 5.0.3 | `WR02-REPRO: crash - ...:1096: attempt to perform arithmetic on field 'avgEff' (a nil value)` |
| 5.1.5 | 同上（措辞同 5.0） |
| 5.4.7 | `...:1096: attempt to perform arithmetic on a nil value (field 'avgEff')` |

三解释器一致：`(cb.avgDmg - 37 * reg.b) / cb.avgEff` 对 nil 算术硬崩溃。与同函数 E 循环已有的守卫（`b.n > 0 and b.avgEff ~= nil`）不对称；selftest 自身已示范手写 stats 入参用法。WR-02 为真问题。

### 修复内容（commit `e042f9f`，仅 tools/cpdamage.lua，+16/−1）

1. rDB 分支守卫由 `cb ~= nil and cb.n > 0` 补为 `cb ~= nil and cb.n > 0 and cb.avgDmg ~= nil and cb.avgEff ~= nil`，与 E 循环守卫对称。缺失层键保持 nil；两层全缺时 rDB 置 nil（既有降级路径原样生效，屏显走锁定降级文本 `no bleed<t> claw samples`、verdict 层 `n/a`）。真实管线（`buildClawShredBuckets.finalize` 保证 n>0 ⇒ 均值非 nil）行为零变化。
2. selftest 新增 1 项断言：claw[2] 缺 avgEff、claw[3] 完整的手写 stats → 不崩溃、`rDB.bleed2 == nil` 且 `rDB.bleed3 ~= nil`（缺失层跳过、其余层保留）。

### 验收输出（修复后）

- 同复现脚本（由修复后代码重建）三解释器重跑：`WR02-REPRO: no crash; rDB=nil verdicts=nil` + 屏显降级行 `no bleed2 claw samples` / `no bleed3 claw samples`、`bleed2 -> n/a, bleed3 -> n/a`（与锁定降级文本一致）。
- 三解释器 selftest `ALL 55 PASSED`。

## 全电池验收（与 PLAN Task 2 同标准，全部在隔离 worktree 内实跑）

1. **三解释器 selftest**：5.0.3 / 5.1.5 / 5.4.7 各 `selftest: ALL 55 PASSED` 且 exit 0（banner 数字与实际断言数一致）。
2. **端到端严格 JSON**：`lua tools/cpdamage.lua /tmp/luabuild/sv.lua --json-out /tmp/luabuild/out-cc-fixed.json --erps 26`（5.0.3）→ Node `JSON.parse` 打印 `STRICT-JSON-OK oocBite erps=26 old keys intact`（`oocBite.erps===26`；decisions/aggregate/batches/dropped/source/generatedAt/truncated 既有顶层键完整）。
3. **`--erps` 边界六连**（abc / -3 / 缺参 / inf / nan / 1e999）× 三解释器：全部 exit 1 + 1 条 error 行。
4. **屏显 additive 口径门**：a8e7852 快照版与修复版同输入 stdout（5.0.3、sv.lua、默认 --erps=10）`diff` 为**空**（0 删除行、0 新增行）——既有输出段字节不变，OOC-Bite Criteria 段格式不变。
5. **bbcheck / diff / 5.0 合规**：`bbcheck.js tools/cpdamage.lua: BALANCED`；`git diff --check` 干净；新增行 `#|goto|::` 扫描 0 命中、字面 `\x` 0 命中、字符串字面量无相邻连字符对；Lua 5.0 语法合规（`num ~= num` 自等测试、无 math.huge、上限字面量 999）。
6. **提交纪律**：两个 fix commit（94f17b7、e042f9f），各仅含 tools/cpdamage.lua；本报告不随 fix commit 提交（由编排流程处理）。

---

_Fixed: 2026-09-13T11:27:14Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_