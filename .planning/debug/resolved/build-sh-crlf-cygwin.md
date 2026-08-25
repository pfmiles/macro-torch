---
slug: build-sh-crlf-cygwin
status: resolved
trigger: "用户将仓库拿到 Windows 的 Cygwin 环境下运行 ./build.sh 抛出 CRLF 相关错误"
created: 2026-08-26
updated: 2026-08-26T00:11:00Z
---

# Debug Session: build-sh-crlf-cygwin

## Trigger

为何当前代码拿到 Windows 的 Cygwin 环境下运行 build.sh 会抛这些错误：

```
$ ./build.sh
./build.sh: line 2: $'\r': command not found
./build.sh: line 4: $'\r': command not found
./build.sh: line 28: syntax error near unexpected token `done'
'/build.sh: line 28: `done < build_order.txt
```

## Symptoms

- **Expected behavior**: `./build.sh` 在 Cygwin 下正常执行构建流程。
- **Actual behavior**: 第 2、4 行报 `$'\r': command not found`，第 28 行报 `syntax error near unexpected token \`done'`。
- **Error messages**: 见 Trigger 中的终端输出原文。
- **Timeline**: 从未在 Cygwin 下成功运行过（首次运行即报错）。
- **Reproduction**:
  - 代码来源：Windows 的 Git 客户端 `git clone` 获取。
  - 仅在 Cygwin 下试过 `build.sh`，未验证其他 .sh 脚本。

## Evidence

- timestamp: 2026-08-26T00:00:00Z — 仓库侧 build.sh 与 build_order.txt 均为纯 LF 行尾（`file` 确认 "POSIX shell script, ASCII text executable"，`grep -U $'\r'` 无匹配）。仓库中无 `.gitattributes` 文件。
- timestamp: 2026-08-26T00:01:00Z — 报错行号与仓库文件内容精确对应：第 2、4 行是空行（CRLF 下空行变为 \r，bash 尝试执行 `$'\r'` 报 command not found）；第 28 行正是 `done < build_order.txt`（报错原文完整引用）；`do\r`（第 15 行）不被识别为关键字导致 `done` 语法错误。用户输出中 `'/build.sh: line 28:` 前导引号是 \r 光标回退的终端显示伪影。
- timestamp: 2026-08-26T00:02:00Z — 模拟实验：`git clone -c core.autocrlf=true file://<repo> /tmp/crlf-repro`（模拟 Windows Git 客户端默认配置）。结果：工作区 build.sh 与 build_order.txt 均为 CRLF（`file` 确认），`sh build.sh` 报错与用户输出逐行一致。核心机制：仓库无 .gitattributes 声明行尾 → 客户端 autocrlf=true 在 checkout 时 LF→CRLF。
- timestamp: 2026-08-26T00:03:00Z — 二级故障确认：build_order.txt 被转成 CRLF 后，`while IFS= read -r line` 读出的每行为 `文件名\r`，`[ -f "$line" ]` 必然失败。即脚本修复后仍需要 build_order.txt 的 eol=lf 声明。
- timestamp: 2026-08-26T00:04:00Z — 仓库文件清点：1 个 .sh（build.sh）、1 个 .txt（build_order.txt）、43 个 .lua（被 build.sh 拼接进 SM_Extend.lua，Lua 对 CRLF 宽容但会产生混合行尾）、零个 .bat/.cmd。tracked 文件无其他 shell 脚本。
- timestamp: 2026-08-26T00:05:00Z — 修复后验证（autocrlf=true 模拟 clone）：build.sh/build_order.txt 均纯 LF（`check-attr` 确认 eol: lf），build.sh 运行成功生成 SM_Extend.lua。但拼接产物仍有 1347 行含 \r：定位为 7 个 .lua blob（biz_util, impl_util, texture_map, interface_debug, classes/druid/{utility,cat,bear}.lua）+ 1 个 .md（docs/UnitXP_SP3_doc.md，不在属性范围）在仓库中本身就是 CRLF（历史上 Windows 端提交）。`eol=lf` 只在 checkin(clean) 时归一化，checkout 不改写已存在的 CRLF blob——仅声明属性不足以修好这些已有 blob，需要 `git add --renormalize .`。
- timestamp: 2026-08-26T00:06:00Z — renormalize 后 staged blob 全部 0 CRLF 行；抽样（biz_util.lua、classes/druid/utility.lua）`tr -d '\r'` 与旧 blob diff 为空，语义零变化；1347 行改动 = 纯行尾归一。
- timestamp: 2026-08-26T00:07:00Z — 本地工作区刷新说明：git 的 up-to-date 检测（cleaned 内容与索引一致即跳过写入）导致 `reset --hard`/`checkout-index` 都不重写这 7 个工作区文件（字节仍是旧 CRLF）；用 HEAD clone 的 LF 内容覆盖落盘后，`git status` 出现 phantom "M"（`update-index --refresh` 异常报 needs update），最终 `git add` 同一内容（无 staged diff、blob 不变）后状态归净。工作区 SHA == 索引 SHA == HEAD SHA（md5 6c29c6ee…/git hash-object 2e527917… 三方一致）。
- timestamp: 2026-08-26T00:08:00Z — 最终验证（详见 Resolution.verification）：HEAD clone（autocrlf=true）全 LF + BUILD OK + 输出 0 个 \r；revert 模拟（父提交 b9355fa~1）精确复现原始三行报错；真实仓库回归构建 exit=0、输出 0 个 \r、git status 干净。
- timestamp: 2026-08-26T00:09:00Z — human-verify checkpoint 用户回复："仍然 build.sh 运行抛错，而且是一模一样的错误"。未附报错原文，未说明重取文件方式（方式 A 重新 clone / 方式 B 原地刷新），未确认两笔修复提交（b9355fa/0c8ba73）是否已到达 Windows 侧。初步筛选："一模一样"强烈暗示修复提交未到达 Windows 工作区（旧内容重新校验必然逐字节复现）；次优假设才是属性未生效（重新 checkout 未被执行）。
- timestamp: 2026-08-26T00:10:00Z — Linux 端远端状态确证（continuation）：`git rev-parse origin/main` == `git ls-remote origin main` == 0c8ba73，本地 main 与 origin/main 0 ahead / 0 behind → 两笔修复提交确已在 GitHub 官方远端（git@github.com:pfmiles/macro-torch.git）。含义更新（去掉了"本地未 push"这一分支）：若用户从官方远端重新 clone，提交必然可达；"一模一样"报错只剩三个来源 —— (a) 工作区未实际刷新（旧 clone / 旧工作区 / Git 客户端缓存未 fetch）；(b) clone 源不是官方远端而是本地路径 / 共享目录旧副本（镜像旧内容，.gitattributes 永不生效）；(c) 提交已到达但重新 checkout 未执行或 .gitattributes 未生效（属性只影响声明后的 checkout）。
- timestamp: 2026-08-26T00:11:00Z — 用户最终确认为 RESOLVED。用户在自己的真实 Cygwin 环境走了环境级修复路径（用户侧选择）：在 ~/.bashrc 增加 `set -o igncr` + `export SHELLOPTS`，重新 source 后 ./build.sh 运行成功。注：用户在真机上验证的是环境级容忍路径；仓库级修复路径（.gitattributes + renormalize）的验证是 Linux 侧 autocrlf=true 模拟 checkout（已有证据），两条路径都如实记录、不作越权声明。用户曾问"环境修复后两笔提交是否仍必要"，我们建议同时保留（env-fix 是逐机容忍、repo-fix 是仓库级根治），用户接受，提交保留且已在远端。

## Eliminated

## Current Focus

- bug_class: Bohrbug（环境相关但机制确定性）
- hypothesis: CONFIRMED —— 仓库无 .gitattributes 声明 + 客户端 autocrlf=true checkout 转换是根因；二级问题为 7 个 CRLF .lua blob。三组自查命令未及回传即被用户划上句号：用户在真机走了环境级路径（igncr/SHELLOPTS）并确认成功，问题被视为解决。
- test: Linux 端全部通过（模拟 clone 复现 / revert 复现 / 修复后验证 / 回归构建）；真机验证仅覆盖环境级修复路径（见 Evidence 00:11），仓库级修复路径由 Linux 模拟 checkout 验证。
- expecting: （已关闭）会话归档
- next_action: 无 —— 会话已 resolved，归档至 .planning/debug/resolved/

## Resolution

root_cause: 仓库缺少固定行尾属性声明的 .gitattributes；客户端 core.autocrlf=true 在 checkout 时把未声明行尾的文本文件（build.sh、build_order.txt、*.lua）从仓库 LF 转成工作区 CRLF。Cygwin POSIX bash 不解析 CRLF：空行变为 `\r` 命令（line 2/4），`do\r` 不被识别为关键字（line 28 语法错误）。两个条件（仓库无声明 + 客户端转换开启）同时成立才触发；仓库侧声明 eol=lf 后客户端配置对匹配文件失效。附带的二级问题：7 个 .lua blob 历史上以 CRLF 提交，eol=lf 只在 checkin 时归一化，需 renormalize 一遍。
fix: 两笔提交：(1) b9355fa 新增 .gitattributes 声明 `*.sh/*.lua/*.txt text eol=lf` 覆盖客户端 checkout 转换；(2) 0c8ba73 `git add --renormalize` 将 7 个 CRLF .lua blob 归一为 LF（纯行尾改动，语义零变化）。注：docs/UnitXP_SP3_doc.md 也是 CRLF blob，但 .md 不在属性范围且无害，保持原样。用户侧最终落地为环境级修复（真机 Cygwin）：~/.bashrc 增加 `set -o igncr` + `export SHELLOPTS`，重新 source 后 ./build.sh 成功。用户问过仓库提交是否仍必要，主张两项都保留（env-fix 是逐机容忍、repo-fix 是仓库级根治），用户接受；两笔提交保留且已在远端（ls-remote 确证 main = 0c8ba73）。
verification:
  target_test:        { result: skipped, reason: "仓库无测试套件（Lua 插件项目）；以模拟 checkout 实验代替 driving test" }
  mutation_check:     { result: skipped, reason: "无 Stryker、无测试套件" }
  no_op_deletion:     { result: pass, detail: "b9355fa 纯新增配置文件（10 行，0 删除）；0c8ba73 为纯行尾归一化（strip \\r 后 diff 为空），无误删任何分支/短路逻辑" }
  adjacent_tests:     { result: skipped, reason: "无测试套件" }
  revert_and_reconfirm: { result: pass, bug_returned_on_revert: true, fixed_on_reapply: true, detail: "revert 模拟 = clone b9355fa~1 + core.autocrlf=true → CRLF + 原始三行报错精确复现；reapply = clone HEAD(0c8ba73) + 同配置 → 全 LF + BUILD OK + 产物 0 个 \\r" }
  regression:         { result: pass, detail: "真实仓库 sh build.sh exit=0，SM_Extend.lua 生成且 0 个 \\r 字节，git status 干净" }
  human_verify:       { result: pass, detail: "用户在真实 Cygwin 环境确认解决：~/.bashrc 加 set -o igncr + export SHELLOPTS，重新 source 后 ./build.sh 运行成功。准确边界：真机验证的是环境级容忍路径；仓库级修复路径由 Linux autocrlf=true 模拟 checkout 验证（target_test/revert 证据），两条路径均如实记录、不越权声明" }
  guardrail_verdict: accepted
  oracle_type: implicit (crash) — 判定标准为脚本解析/执行成功且拼接产物无 CR 字节
files_changed: [.gitattributes, biz_util.lua, impl_util.lua, texture_map.lua, interface_debug.lua, classes/druid/utility.lua, classes/druid/cat.lua, classes/druid/bear.lua]