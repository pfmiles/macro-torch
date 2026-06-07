# Phase 1: 基础设施 — classMetatable 工厂 + Entity 层迁移 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-07
**Phase:** 01-基础设施 — classMetatable 工厂 + Entity 层迁移
**Areas discussed:** classMetatable API 设计, initPlayer 类注册机制, build_order.txt 维护策略, LRUStack + Frame 分离策略

---

## classMetatable API 设计

| Option | Description | Selected |
|--------|-------------|----------|
| A: 最简工厂 | ~20 行代码，1行调用替换9行模板，完全满足 R1 验收标准，后续可按需升级 | ✓ |
| B: 显式 parent | 传 table 引用和 parent 参数，消除字符串拼写风险 | |
| C: Richer builder | 链式 .fieldMap().new().build() 声明式 | |
| D: 混合渐进 | A 为基础 + 可选扩展函数，预留升级空间 | |

**User's choice:** Option A — 最简工厂。`classMetatable(cls, fieldMapName)` 仅消除重复模板，不引入额外抽象。

---

## initPlayer 类注册机制

| Option | Description | Selected |
|--------|-------------|----------|
| A: 硬编码 if-elseif | initPlayer 内 8 路分支，零间接层 | |
| B: 惰性注册表 | 各职业文件自注册，initPlayer 查表+fallback | ✓ |
| C: 构建时拼接 | build.sh 解析 build_order.txt 注释生成注册代码 | |
| D: Player 自感知 | Player:init() 根据 UnitClass 委托子类 | |

**User's choice:** Option B — 惰性注册表。`macroTorch.registerPlayerClass()` + `PLAYER_CLASS_REGISTRY` 查表，各职业文件自描述零耦合。

---

## build_order.txt 维护策略

| Option | Description | Selected |
|--------|-------------|----------|
| A: 一次性全量 | Phase 1 写出全部 Phase 2-4 文件路径，容错模式跳过 | ✓ |
| B: 每 Phase 增量 | 每 Phase 末尾追加当 Phase 新文件，严格模式始终生效 | |
| C: 混合模式 | 全量 + # -- PHASE N -- 注释分界 | |

**User's choice:** Option A — 一次性全量。Phase 1 写出所有最终文件路径，与 ROADMAP Phase 1.5 规划一致。

---

## LRUStack + Frame 分离策略

### LRUStack metatable 改造

| Option | Description | Selected |
|--------|-------------|----------|
| A: 保持手写 | 零风险，75 行自包含 | |
| B: classMetatable({}) | 统一但语义不匹配 | |
| C: classMetatable(nil) | dogfood 新工厂的低风险目标 | ✓ |

### Frame 分离时机

| Option | Description | Selected |
|--------|-------------|----------|
| A: Phase 1 立即独立 | 从 Day 1 干净分离，periodic.lua 完全自包含 | ✓ |
| B: 推迟到 Phase 2 | 改动最小但积累技术债务 | |

**User's choice:** LRUStack=C + Frame=A。LRUStack 改用 classMetatable(nil) 验证工厂，periodic.lua 立即拥有独立 OnUpdate Frame。

---

## Deferred Ideas

None — 讨论保持在 Phase 1 范围内。