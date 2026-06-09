---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: ready_to_plan
last_updated: "2026-06-09T04:22:05.552Z"
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 16
  completed_plans: 13
  percent: 75
---

# Project State

## Current Status

- **Milestone**: macro-torch 架构重构
- **Started**: 2026-06-07
- **Current Phase**: Phase 3 context 已就绪，等待 planning
- **Active Branch**: main

## Phase Progress

| Phase | 状态 | 开始 | 完成 | 提交 |
|-------|------|------|------|------|
| Phase 1: 基础设施 + Entity 迁移 | ✅ complete | 2026-06-07 | 2026-06-08 | 6 plans |
| Phase 2: 事件系统拆分 | ✅ complete | 2026-06-08 | 2026-06-08 | 3 plans |
| Phase 3: 自检 + Spell Trace 配置化 | 🔵 context-ready | — | — | — |
| Phase 4: 职业重组 + 构建系统 | ⬜ pending | — | — | — |

## Key Decisions

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-06-07 | 启动重构项目 | REFACTOR_PLAN.md 已对齐，架构方案确认 |
| 2026-06-07 | 4 Phase 拆分方案 | 比原始 7 Step 更聚焦，每 Phase 可独立验证 |
| 2026-06-07 | Phase 1 同时做 entity 迁移 | classMetatable + entity 迁移是不可分的原子操作 |
| 2026-06-07 | 保持所有 macroTorch.* 全局命名 | WoW 1.12.1 不支持 require，必须全局可见 |
| 2026-06-07 | build_order.txt + build.sh 提前到 Phase 1 | Phase 1 移动 entity/ 文件后旧 build.sh 硬编码路径失效，必须同步更新构建系统 |
| 2026-06-07 | build.sh Phase 1 使用容错模式 | 后续 Phase 逐步创建新文件，build.sh 跳过不存在文件避免报错；Phase 4 切换到严格模式 |
| 2026-06-07 | periodic.lua 和 events.lua 使用独立 Frame | 原 battle_event_queue.lua 中共享 frame，拆分后各自创建独立 frame，无共享状态 |
| 2026-06-07 | classMetatable 最简工厂方案 | 仅消除重复模板，不引入 parent 参数/builder 模式，保持类继承隐式 |
| 2026-06-07 | initPlayer 惰性注册表 | 各职业自注册 `registerPlayerClass()`，initPlayer 查表+fallback，消除多态 hack |
| 2026-06-07 | build_order.txt 一次性全量 | Phase 1 写出所有 Phase 2-4 文件路径，容错模式跳过未创建文件 |
| 2026-06-07 | LRUStack 改用 classMetatable(nil) | 验证工厂设计，统一 metatable 模式，无父类情况显式传 nil |
| 2026-06-07 | periodic.lua Phase 1 独立 Frame | OnUpdate 代码块与 OnEvent handler 零耦合，立即分离无过渡状态 |

## Open Questions

- Group/Raid 实体是否有实际使用场景，需要后续跟用户确认后再决定是否实现（当前保持空壳）
- 非 Druid 职业文件（Hunter/Mage 等）是否需要在此次重构中也进行逻辑完善？文档只要求作为参考样例保留

## References

- [PROJECT.md](PROJECT.md) — 项目背景和约束
- [REQUIREMENTS.md](REQUIREMENTS.md) — 8 项可验证需求
- [ROADMAP.md](ROADMAP.md) — 4 Phase 详细实施步骤
- [config.json](config.json) — 工作流配置
- [../docs/REFACTOR_PLAN.md](../docs/REFACTOR_PLAN.md) — 原始重构计划
- [codebase/](codebase/) — 现有代码库分析文档

## Commands

```bash

# 开始 Phase 1

/gsd:plan-phase 1

# 执行当前 Phase

/gsd:execute-phase

# 验证 Phase 完成

/gsd:validate-phase
```
