---
status: complete
phase: 29-landing
source: [29-VERIFICATION.md]
started: 2026-09-10T20:10:00Z
updated: 2026-09-12T05:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Windows+Cygwin rebuild & login banner
expected: `./build.sh` 无报错；登录横幅 CONFIG_OPTIONS 仍 4 项（协议 HUMAN-UAT.md §1-2）
result: pass

### 2. In-game /mt self-check — Category Q-01..Q-16 all green
expected: 游戏内 `/mt` 自检 Category Q-01..Q-16 全绿、无红 FAIL（HUMAN-UAT.md §2）。这是 D-02（去重压制）、D-03（反推兜底）、D-04（fail 否决窗）、D-06（fail-wins 撤销）四条行为钉的闭环总入口
result: pass
note: 320 passed / 0 failed / 1 warnings — 黄色 warning 属协议可容忍项（§2：非 Q 可选项警告可容忍）

### 3. Single-dummy landing behavior
expected: 单人木桩：Rake/FB 恒绿 landed；Pounce/Rip 绿或偶发蓝 (inferred)；无红 failed-on；ripLeft 正常启动（§3）
result: pass
note: "2026-09-12 gap-closure(29-04) 修复后复验：打桩实机目击绿 landed / 蓝 (Inferred) / 咖啡 Reshift / 粉 FF 四色相全部正确、无红；/mt Category T 绿（324 passed / 0 failed / 1 warn=SP3 optional）。色相倒置已闭环（见 Gaps G-29-3）"

### 4. Multi-druid same target (optional)
expected: 多猫同目标时 apply 被抑制 → ~1s 内蓝色 (inferred) 兜底 + ripLeft 启动、不再每帧重放；他人技能行不触发我方通告（§4）
result: pass

### 5. Hunter stings meeting range
expected: Serpent/Scorpid Sting 落地可见、远程位 ~2s 弹道窗内落地（§5）
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-29-3
  truth: "单人木桩：绿色=landed、蓝色=inferred（HUMAN-UAT.md §247-248）；Rake/FB 恒绿 landed，Pounce/Rip 绿或偶发蓝 (inferred)"
  status: resolved
  resolved_by: 29-04-PLAN.md
  resolved_at: 2026-09-12
  reason: "User reported: 行为都符合预期，就是蓝色和绿色刚好搞反了：rake/bite全都是蓝色的landed, pounce和rip的inferred landed都是绿色的，没有红色"
  severity: minor
  test: 3
  root_cause: "interface_debug.lua:87-99 macroTorch.show 渲染表绿/蓝两臂色相颠倒：'blue'→OFFICER(实渲染绿色)、'green'→{0,0.5,0.9}(实渲染蓝色)。Phase 29 判定逻辑与调用点标签均正确；缺陷为 GSD 重构前遗留（7d2369b/5594a09），Phase 29 建立绿/蓝协议后首次可见"
  artifacts:
    - path: "interface_debug.lua"
      issue: "macroTorch.show 颜色名→渲染色相翻译表绿/蓝两臂颠倒"
    - path: "core/spell_trace_core.lua"
      issue: "通告调用点标签正确（受害方，无需改动）"
    - path: "classes/druid/selftest.lua"
      issue: "Q 系列自检只断言标签字符串且测试期 stub 掉 show，渲染层零覆盖"
  missing:
    - "修正 macroTorch.show 翻译表：'green' 用真实绿色、'blue' 用真实蓝色"
    - "补一条对渲染映射表色相的回归自测（覆盖映射层）"
  debug_session: ".planning/debug/landing-color-inverted.md"