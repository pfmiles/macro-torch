# Phase 4: 职业文件重组 + 构建系统收尾 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-09
**Phase:** 04-职业文件重组 + 构建系统收尾
**Areas discussed:** Druid 拆分边界, 构建系统切换策略, classes/ 目录结构, 非 Druid 职业处理

---

## Druid 拆分边界

| Option | Description | Selected |
|--------|-------------|----------|
| A: ROADMAP 原方案 | 全部 safe/ready + combat helper + 共享辅助 + 注册放 Druid.lua | |
| B: 按形态就近放置 | 单形态独占函数放形态文件，跨形态共享放 Druid.lua | ✓ |

**User's choice:** 方案 B — 按形态就近放置
**Notes:** 用户从可维护性、扩展性、逻辑单点唯一性三个维度确认方案 B 更优。规则为：单形态独占函数放对应形态文件，跨形态共享函数放 Druid.lua。这条规则统一且直觉。

---

## 构建系统切换策略

| Option | Description | Selected |
|--------|-------------|----------|
| A: 原子切换 | 一次性创建所有 classes/、更新 build_order.txt、删旧文件、切换严格模式 | ✓ |
| C: 分步迁移+验证门 | 先低风险 6 职业，再高风险 Druid 拆分 | |

**User's choice:** 原子切换 — 单 commit 完成所有变更
**Notes:** 用户选择一步到位。变更顺序：先创建新文件 → 更新 build_order.txt + build.sh → 验证构建 → 删除旧文件。

---

## classes/ 目录结构

| Option | Description | Selected |
|--------|-------------|----------|
| D: 仅子目录 snake_case | classes/Druid.lua + classes/druid/cat.lua 等 | |
| B: 统一子目录（全部下沉） | classes/druid/Druid.lua + classes/druid/cat.lua 等 | ✓ |
| A: ROADMAP 原样 | classes/Druid.lua + classes/Druid/cat.lua (PascalCase 子目录) | |

**User's choice:** 统一子目录 — Druid 主文件和子模块全部放入 `classes/druid/`
**Notes:** 用户明确要求将 Druid.lua 也放入子目录中，而非放在 classes/ 顶层。子目录 `druid/` 使用 snake_case，与 `entity/`、`core/` 命名约定一致。其他单文件职业保持 classes/ 顶层。

---

## 非 Druid 职业处理

| Option | Description | Selected |
|--------|-------------|----------|
| E: rename + TODO 标记 | 纯 git mv，Hunter 手写 metatable 旁加 TODO | ✓ |
| A: 纯 rename | 纯 git mv，零改动 | |
| B: rename + Hunter 最小改进 | Hunter 替换为 classMetatable + registerPlayerClass | |

**User's choice:** rename + TODO 标记
**Notes:** Phase 4 严守重组边界，不添加功能。Hunter 手写 metatable 旁加 TODO 注释为后续 Phase 留下路标。

---

## Claude's Discretion

- build_order.txt 中 classes/druid/Druid.lua 排在子模块之前
- safe/ready 函数归属的具体判断（单形态 vs 跨形态边界）
- build.sh 严格模式错误信息格式
- Hunter TODO 注释精确措辞

## Deferred Ideas

- 非 Druid 职业功能完善（classMetatable/registerPlayerClass/SelfTest）→ 未来独立 Phase
- entity/、core/ 目录重命名为 PascalCase → 未来独立 Phase