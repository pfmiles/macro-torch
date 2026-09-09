# Phase 29: 统一 landing 判定重构 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-10
**Phase:** 29-landing
**Areas discussed:** API 形态, 反推通告观感, 测试与验证范围, 边界行为拍板

---

## API 形态

| Option | Description | Selected |
|--------|-------------|----------|
| intentTtl | 与 intent.ttl 播种字段同名，一参三用名实相符 | ✓ |
| pairTtl | 强调配对用途，但反推/fail 同窗，名不副实 | |
| landTtl | 以落地视角命名，与 cast/intent 链路关联弱 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 保留 LAND_INTENT_TTL 为默认值 | 值改 0.9，cpDamage 自动跟随 | ✓ |
| 保留但改名 | 改名强调默认窗语义 | |
| 删除常量 | 未传参路径各自硬编码，脆弱 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 独立函数 recordLandEventRenewal | 绕过去重直推新锚，语义边界清晰 | ✓ |
| 加参数控制 | 一个入口两种语义 | |
| 直写栈结构 | 违反封装 | |

**User's choice:** 三项均采用推荐项
**Notes:** 远程钉刺不配 default 无功（弹道），但对 intentTtl 无影响

---

## 反推通告观感

| Option | Description | Selected |
|--------|-------------|----------|
| 后缀 (inferred) | 沿用现有 landed 文案 + 后缀，实机肉眼可辨 | ✓ |
| 独立前缀 | 多一套文案维护 | |
| 静默不发通告 | 实机无法肉眼确认兜底生效 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 蓝色 | 继承旧 computeLandTable 观感，通道可辨 | ✓ |
| 绿色 | 与正推同色，通道不可辨 | |
| 黄色 | 与 fail/immune 告警混淆 | |

**User's choice:** 后缀 (inferred) + 蓝色
**Notes:** 无

---

## 测试与验证范围

| Option | Description | Selected |
|--------|-------------|----------|
| 重写为行为断言 | 断言统一 OR 行为，表已删 | ✓ |
| 最小删除 | 测的是被删机制，无意义 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 全量六组用例 | 反推/拒重/fail 窗口内外/ttl 边界/续期豁免/远程迟到时序 | ✓ |
| 核心四条 | 覆盖浅 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 跟随全局 0.9 | 同一常量自动生效，近战足够 | ✓ |
| 独立保持 2s | 多一个例外分支，无实锤必要 | |

**User's choice:** 全部推荐项
**Notes:** 无

---

## 边界行为拍板

| Option | Description | Selected |
|--------|-------------|----------|
| 接受为最终形态 | 保守提前重挂、不留空窗，最小参数集 | ✓ |
| 预留字段位 | 注释标注 future | |
| 现在就引入 | 期望飞行时间靠猜，兜底场景无实测依据 | |

**User's choice:** 接受为最终形态
**Notes:** Deferred Ideas 三项确认：FF 开 land 追踪、anchorBias 参数、动态 TTL 学习

---

## Claude's Discretion

无——本轮全部问题用户均明确拍板（多为推荐项）。

## Deferred Ideas

- FF 开 land 追踪（未来可能想让 FF 走统一通道）
- anchorBias 参数（若将来要消掉远程兜底锚偏差）
- 动态 TTL 学习（按目标/距离自学习 resolve 延迟，已否定防再提）