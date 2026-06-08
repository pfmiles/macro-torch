---
plan: "03-04"
phase: "03-spell-trace"
status: complete
tasks: 2/2
duration: "~7 min"
commits:
  - "6a6187c feat(03-spell-trace): convert Druid spell trace to SpellTrace:register() declarative API"
  - "018c8f0 feat(03-spell-trace): register 25 Druid class-specific self-test items"
---

## What was built

在 `SM_Extend_Druid.lua` 中完成了两项改造：

1. **Spell trace 声明式化**: 将 8 行命令式 `setSpellTracing`/`setTraceSpellImmune` 调用替换为 5 个 `SpellTrace:register()` 声明式注册（Pounce, Rake, Rip, Ferocious Bite, Faerie Fire (Feral)）。零命令式调用残留。

2. **Druid 职业自检**: 在文件末尾注册 25 项自检测试：
   - 类别 F1: 10 项猫形态技能存在性检查（isOptional=false）
   - 类别 F2: 5 项 talent 等级检测（isOptional=false）
   - 类别 F3: 3 项能量常量范围验证（isOptional=false）
   - 类别 G1: 5 项 DRUID_FIELD_FUNC_MAP 字段完整性（isOptional=true）
   - 类别 G2: 2 项形态检测（isOptional=true）

全量自检注册: 75 (infrastructure) + 25 (Druid) = 100 项。

## Notable deviations

- Task 1 的 `SpellTrace:register` 产生了 6 次调用（`grep -c` 统计），因为 grep 同时匹配了注册调用和之前的注释行。实际注册调用是 5 个，符合要求。
- 03-04 agent 遇到 worktree 路径混淆问题（#3099），Task 1 的编辑意外落到了主 repo。由于修改内容本身正确，由 orchestrator 直接提交。Task 2 由 orchestrator 手动完成。

## Self-Check: PASSED

| Check | Value | Req |
|-------|-------|-----|
| SpellTrace:register calls in Druid | 5 | >= 5 |
| Old setSpellTracing/setTraceSpellImmune | 0 | 0 |
| Druid SelfTest:register | 25 | >= 25 |
| Total SelfTest:register (core + Druid) | 100 | >= 85 |
| ./build.sh | OK | OK |
| Key symbols in SM_Extend.lua | 3 | 3 |

## key-files

- created: `SM_Extend_Druid.lua` (modified, +139 lines)