---
phase: "28"
slug: "cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-13"
---

# Phase 28 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| RAW_COMBATLOG 事件流 → addon | 客户端内部事件；本 phase 仅在 SELF_DAMAGE 通道消费自有 intent 对应的行 | 战斗日志行（isBehind 等单字符语义字段） |
| 持久化环 → SavedVariables 文件 | `[cpDamage]` 条目走既有 macroTorch.log 写路径 | 打点 JSON（11 字段，无敏感数据） |
| 外部 SV 文件 → tools/cpdamage.lua | 分析器吃任意路径指定的文件，loadstring 执行其提取段（主要攻击面） | 玩家本地战报文件 |
| 分析器 → 终端 / --json-out 文件 | 输出侧无输入回流，只写用户明确指定的结果路径 | 统计报表 |
| 阶段验收文档 → 用户实机操作 | UAT 指令可被误操作（同开开关/漏补 .toc）→ 静默零数据 | 操作指引 |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-28-01 | Tampering / Elevation | tools/cpdamage.lua loadBlockSandboxed | medium | mitigate | 5.0/5.1 setfenv 空环境禁用 io/os/dofile；5.2+ load(block,nil,'t',env)；执行后仅读 `MACRO_TORCH_LOG["messages"]`；坏执行返回 err exit 1 | closed |
| T-28-02 | DoS | readAll 文件上限 / 条目循环 | low | mitigate | 32MB 拒绝；50k 条截断 + 一次警告 | closed |
| T-28-03 | DoS | decodeJson 坏行 | low | mitigate | pcall 逐行解码，坏行跳过 + 计数告警不中断整批 | closed |
| T-28-04 | Spoofing | 环内虚假 `[cpDamage]` 行 | low | mitigate | 11 字符前缀精确匹配 + pcall decode 成功 + validateEntry 字段校验三门槛 | closed |
| T-28-05 | DoS | 持久化环与 rawdiag2 同开挤爆 | low | accept | D-10 LOG_MAX_SIZE /run 自调兜底；28-04 UAT 文档提醒勿同开 | closed |
| T-28-06 | Tampering | selftest 桩/影子字段泄漏会话 | low | mitigate | 桩经 rawget 快照 + rawset 还原，未还原不得提交（Cat S-03/CR-01 纪律） | closed |
| T-28-A2 | Information Disclosure | .toc 缺失致数据静默丢失 | low | mitigate | UAT §3：SV 段存在性检查 + 补声明修复法；实机 test 1 已实证段持久化 | closed |
| T-28-SC | Tampering | npm/pip/cargo installs | low | accept | 本 phase 无任何包管理器安装（bbcheck.js 只读复用，零新依赖） | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**配置：** ASVS level 1，block on high。威胁最高 medium（T-28-01，已 mitigate），无 high/critical，无阻塞护栏触发。mitigate 类全部有落地证据（28-VERIFICATION.md 静态锚行 + 28-UAT 实机 5/5 + quick 260913-2wo 三解释器复绿）。

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-28-01 | T-28-05 | 双采集通道同开的音量风险属用户自选行为；D-10 提供 /run 调节 + UAT 文档显式提醒 | verify-work secure-phase hook | 2026-09-13 |
| R-28-02 | T-28-SC | 本 phase 零包管理器安装，供应链面为空 | 同上 | 2026-09-13 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-13 | 8 | 8 | 0 | verify-work verify:post secure-phase hook（ASVS L1 short-circuit：authored register + threats_open 0 → 免深审） |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-13