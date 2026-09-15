---
phase: quick-260915-uzs
reviewed: 2026-09-15T14:38:24Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - build_order.txt
  - classes/druid/cat.lua
  - classes/druid/energy_probe.lua
  - core/events.lua
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase quick-260915-uzs: Code Review Report（cumulative tt3+udx+uzs energy-tick 取证变更集）

**Reviewed:** 2026-09-15T14:38:24Z
**Depth:** standard
**Files Reviewed:** 4（build_order.txt +1 行、classes/druid/cat.lua +3 行、classes/druid/energy_probe.lua 新建 117 行、core/events.lua +15 行；diff base `bf47ecc^`，纯插入零删除）
**Status:** issues_found（0 critical / 3 warning / 4 info）

## Summary

本 review 覆盖 260915-tt3 + 260915-udx + 260915-uzs 三个 quick 的累积最终态（代码 commit：bf47ecc / d9319f2 / a80fe39 / 344a81a）。整体结构干净：`macroTorch.energyProbe` 默认 OFF（nil-guard 每次登录重挂 false），OFF 时全部 tap 短路零输出零 API 读；8 种线路型（SES/EV/POLL/RAW/CAST/REL/PDT-RAW/PDT-CHAT）全齐且全部经 `macroTorch.log`（无专用存储桶、无 DEFAULT_CHAT_FRAME 直写）；无法术白名单、无节流（符合 capture-everything 设计）；Lua 5.0.3 正门与 luac 语法门双通过、build.sh 冒烟构建成功、`git diff --check` 干净。发现 3 条 Warning：一是 EPR|RAW 的 `'nergize'` 过滤大小写敏感、疑似对 SuperWoW 大写 raw token 恒不匹配（该通道可能实机零捕获）；二是 EV 行把裸事件名字段插在 TYPE 与 `t=` 之间、偏离其余 7 种的 `EPR|<TYPE>|t=...` 固定列契约；三是 UnitMana 第一返回值缺 nil 守卫、POLL 错误帧会逐帧重抛。均不影响默认关闭时的生产行为。

### 六项 review focus 验证结论（对照 live code，非文档）

1. **（a）RAW 分支执行流 — 通过**。EPR|RAW tap（events.lua:158-160）为纯只读透传：无 return、不消费/改写 arg1/arg2，后续 cpDamage gate（168-170）、tier-1 白名单 return（176-178）、tier-2/3 循环全部原样可达，无一被跳过。EPR|PDT tx=RAW（179-181）插在 tier-1 return 之后，天然限定两个 periodic 通道——与 uzs SUMMARY 锁定设计「白名单 return 先行保证 arg1 合法」一致。
2. **（b）UnitMana 双返回值处理 — 发现问题（WR-03）**。`local e, m = UnitMana('player')` 两处只对第二返回值做 `m = m or 0`，第一返回值 e 无守卫直接进算术与 `%d` 格式化。
3. **（c）pcall 包裹的 builder — 通过**。SES 行两组 pcall：form 读取失败退化 `'0'`、GetNetStats 失败记 `'pcfail'`，任何失败路径产出的仍是合法 KV 行，不会产生畸形字段。
4. **（d）macroTorch.log nil 时序 — 通过（附 IN-01 纪律备忘）**。`macroTorch.log` 于 interface_debug.lua:113 加载期无条件定义，build_order 第 18 行（先于 events.lua:25、energy_probe.lua:36 等一切 tap 所在文件），任何事件/帧回调触发时不可能为 nil；但 8 个 tap 中仅 PDT×3 带 `macroTorch.log and` 守卫，其余 6 个不带，两派写法并存。
5. **（e）EV 分桶算术 — 通过**。read-baseline → compute → store 顺序正确；每事件名首条 d=0/dt=0 为「零增量不滤除」设计内；Lua 中 0 为真值、`lastEnergy[evName] or e` 无 JS 式假性回退；PEW 无条件重置 + 门控发射，OFF 时零输出零持久化写。
6. **（f）GetTime() 位置与字段序 — 部分通过（WR-02）**。8 种线路型时间字段全部 `%.3f` 一致；但 EV 模板把裸字段 evName 插在 TYPE 与 `t=` 之间，是唯一违反「`t=` 紧随 TYPE」的头字段序的行型。

### 项目定律实证（review context 的 6 条）

- 定律 1（Lua 5.0）：energy_probe.lua 经 `/usr/bin/luac -p` 与 5.0.3 正门 `loadfile` 双通过，无 `#`/`goto`。
- 定律 2（全经 macroTorch.log）：8 线路型全部直调 `macroTorch.log`；`probeTick`/`energyProbeLog` 全仓残留 0。
- 定律 3（无节流/白名单）：无 rate limit、无 spell whitelist；`'nergize'` 门是题材通道过滤而非白名单——WR-01 指控的是该门匹配不到任何行，而非不该有门。
- 定律 4（SM_Extend.lua 未手改）：git 变更面无该文件；build.sh 重建产物经 `git check-ignore` 于 .gitignore 内。
- 定律 5（OFF 默认零成本）：nil-guard 默认 false；OFF 时 OnEvent 在 flag 检查后立即 return（PEW 分支的 pcall 读取也在 flag 检查之后）、OnUpdate 仅置零即 return。
- 定律 6（EPR| 扁平 KV + t= 字段位）：7/8 行型合规，EV 行为例外（WR-02）。

## Critical Issues

无。

## Warnings

### WR-01: `'nergize'` 大小写敏感的过滤疑似使 EPR|RAW 通道实机零捕获（需实机确认）

**File:** `core/events.lua:158`
**Issue:** `string.find(arg2, 'nergize')` 是大小写敏感精确子串匹配。WoW 1.12 战斗日志事件 token 按 API 惯例全大写（本仓注册的 `CHAT_MSG_SPELL_PERIODIC_SELF_ENERGIZE` 即大写）；SuperWoW 的 RAW_COMBATLOG 携带原始服务端行，token 形如 `SPELL_ENERGIZE` / `SPELL_PERIODIC_ENERGIZE` / `RANGE_ENERGIZE`（用户参考库已记录「raw 日志含 _ENERGIZE 行」）。若 raw 行确为大写（三个 quick 的实机验证均为 unrun，本机无 WoW 客户端，从未实测），小写 `'nergize'` 恒不匹配，**EPR|RAW 通道整段静默零行**——该通道是 tt3 的核心交付物之一，三个 quick 的 unrun-verify 清单都含「'nergize' 行出现 EPR|RAW」条目。该 tap 位于 RAW 分支头部、只读落穿无 return，不影响后续 cpDamage/tier-1 路径，故为取证数据缺口、无生产回归。
**Fix:** 实机先取一条 RAW_COMBATLOG energize 行确认大小写；若为大写则改：
```lua
if macroTorch.energyProbe and arg2 and string.find(string.lower(arg2), 'nergize') then
```
或兼容双写 `(string.find(arg2, 'nergize') or string.find(arg2, 'ENERGIZE'))`。Lua 5.0 均有 `string.lower`/`string.find`，无语法风险。

### WR-02: EV 行在 TYPE 与 `t=` 之间插入裸事件名字段，偏离 `EPR|<TYPE>|t=` 固定列契约

**File:** `classes/druid/energy_probe.lua:57`
**Issue:** 模板 `"EPR|EV|%s|t=%.3f|earg=%s|e=%s|m=%s|d=%d|dt=%d"` 把 evName（UNIT_ENERGY / UNIT_MANA / CHAT_MSG_SPELL_PERIODIC_SELF_ENERGIZE）作为无 key 的裸字段插在 EV 与 `t=` 之间。其余 7 种线路型（SES/POLL/RAW/CAST/REL/PDT-RAW/PDT-CHAT）全部是 `EPR|<TYPE>|t=...`。管道切分后按固定列取 `fields[2] == 't=...'` 的离线解析器对 EV 行整体错位一列（fields[2] 变事件名、fields[3] 才是 t=）——离线解析正是本探针的唯一下游；且 evName 与 earg 信息重叠但不互替（earg 只带 arg1 值，UNIT 事件下恒为 'player'，无法靠 earg 区分三种事件来源）。
**Fix:** 将事件名改为 `t=` 之后的 KV 字段，例如：
```lua
macroTorch.log(string.format("EPR|EV|t=%.3f|ev=%s|earg=%s|e=%s|m=%s|d=%d|dt=%d", now, evName, tostring(evArg), tostring(e), tostring(m), d, dt))
```
（其余参数顺序与 fmt 锚位不动，仅把裸 `%s` 改为 `ev=` 并相应调整实参顺序。）

### WR-03: UnitMana 第一返回值无 nil 守卫，EV/POLL 可能在事件/帧处理中硬错误且 POLL 逐帧重抛

**File:** `classes/druid/energy_probe.lua:48-50`（recordEvLine）、`107-109`（probeOnUpdate）
**Issue:** 两处对第二返回值写了 `m = m or 0`（作者自身承认返回值可能为 nil 的状态存在），但第一返回值 e 无守卫直接进算术：EV 行 `math.floor(e - (lastEnergy[evName] or e))`（e 为 nil 时 `nil - number` 抛错击穿 OnEvent），POLL 行 `e - (lastPollEnergy or e)` 同病。更重要的是 POLL 的 error 放大路径：减法发生在 `pollAccum = pollAccum - 1.0`（112 行）**之前**——错误帧 pollAccum 不减、依旧 ≥1.0，nil 状态存续期间 OnUpdate 每帧重抛一次（WoW 1.12 对 OnUpdate 错误不静默，逐帧弹错），直到 UnitMana 恢复或用户手动关开关。另 POLL 的 d 未做 `math.floor` 即进 `%d`（EV 行做了），依赖「能量值恒整」的隐性前提，两行形状不对称。
**Fix:**
```lua
local e, m = UnitMana('player')
e = e or 0
m = m or 0
```
两处同改；POLL 的 d 同时对齐 EV 写法 `local d = math.floor(e - (lastPollEnergy or e))`，使 `%d` 不依赖整数前提。

## Info

### IN-01: macroTorch.log 守卫纪律不一致（恒真的防御代码）

**File:** `core/events.lua:125/130/179`（带守卫）vs `core/events.lua:153/158`、`classes/druid/energy_probe.lua:57/82/113`、`classes/druid/cat.lua:413`（不带）
**Issue:** `macroTorch.log` 在 interface_debug.lua:113 加载期无条件定义、build_order 先于全部 tap 文件加载，事件/帧触发时不可能为 nil。8 个 tap 中 3 个 PDT tap 额外带 `macroTorch.log and` 合取（恒真、永不生效），其余 6 个不带。两派并存会误导后续 tap 作者以为 log 可能为 nil。
**Fix:** 不必改行为。建议统一去掉 3 处 `macroTorch.log and`（与 6 个既有 tap 对齐），或在模块注释注明「log 恒在，守卫仅历史遗留」。

### IN-02: 模块头注释 "SavedVariables-only" 措辞已过期

**File:** `classes/druid/energy_probe.lua:17`
**Issue:** udx refactor 后 EPR 行同时聊天可见 + 落共享 MACRO_TORCH_LOG.messages，头注释仍称 SavedVariables-only。udx SUMMARY 已记录为锁定范围外有意保留（偏差 2）；但新读者按字面理解会误判探针输出面（以为无聊天输出）。
**Fix:** 未来解锁修订时改为 `-- energy tick forensics probe: flag-gated, additive-only instrumentation (chat-visible + shared SavedVariables persistence via macroTorch.log)`。

### IN-03: txt=/earg= 承载原始消息文本、未做管道字符转义

**File:** `core/events.lua:126/131/159/180`（txt=）、`classes/druid/energy_probe.lua:57`（earg=）
**Issue:** 管道分隔扁平 KV 依赖 `|` 不出现于值内。当前值源为服务端生成的 fixed-format 战斗日志/聊天行（实战中不含管道，风险理论存在）；但若未来扩展到含玩家自命名内容（目标名、公会名、msg 类事件）的原始行，一个 `|` 即可使离线列解析整体错位。
**Fix:** 写入前对文本字段做 `txt = string.gsub(txt, '|', '\\124')`（或离线端约定最大列数容错解析）。当前低优先，可不改。

### IN-04: energy_probe.lua 无文件尾换行

**File:** `classes/druid/energy_probe.lua:117`
**Issue:** 文件以无换行结尾（diff 显示 `\ No newline at end of file`），与仓库 .gitattributes LF 约定的其余文件不一致。build.sh 拼接不受影响，但下次在该文件追加行时 diff 会显示「整行重写」噪音。
**Fix:** 补一个 EOF 换行即可。

## Verification（实际执行的工具门与结果）

| 门 | 命令 / 对象 | 结果 |
|----|------------|------|
| 累积 diff 取证 | `git diff bf47ecc^..HEAD -- build_order.txt classes/druid/cat.lua classes/druid/energy_probe.lua core/events.lua` | 纯插入零删除：build_order +1、cat.lua +3、energy_probe.lua 新建 117 行、events.lua +15 |
| 语法门 1 | `/usr/bin/luac -p classes/druid/energy_probe.lua` | LUAC51-OK |
| 语法门 2（Lua 5.0 正门） | `/tmp/luabuild/lua-5.0.3/bin/lua -e "assert(loadfile('.../energy_probe.lua'))"` | LUA50-LOADFILE-OK |
| 构建冒烟 | `bash build.sh`（repo root；non-cygwin 不拷贝） | BUILD-OK；产物含 8 线路型：SES/EV/POLL/RAW/CAST/REL 各 1、PDT 3（tx=RAW×1 + tx=CHAT×2） |
| diff 卫生 | `git diff bf47ecc^..HEAD --check` | DIFF-CHECK-CLEAN |
| 定律 2 扫尾 | 全仓 grep `probeTick`/`energyProbeLog`（除 .git/.planning） | 0 残留 |
| macroTorch.log 定义 | interface_debug.lua:113 + build_order.txt 第 18 行 | 加载期无条件定义、先于全部 tap 文件 |

未执行的验证：三个 quick 的 unrun-verify 实机电池（本机无 WoW 客户端）——特别是 WR-01 需实机取一条 RAW_COMBATLOG energize 行确认大小写后定案；PDT 双传输（tx=RAW 与 tx=CHAT 双行出现）亦待 Windows+Cygwin 实机验证。

---

_Reviewed: 2026-09-15T14:38:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_