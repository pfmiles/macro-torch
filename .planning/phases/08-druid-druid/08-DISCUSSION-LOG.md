# Phase 8: 非Druid职业代码结构重构 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-15
**Phase:** 08-druid-druid
**Areas discussed:** 文件拆分粒度, 类定义补齐, 代码现代化程度, 目录结构

---

## 文件拆分粒度

| Option | Description | Selected |
|--------|-------------|----------|
| 2文件：定义+战斗 | 每个职业拆为 Xxx.lua（类定义） + XxxCombat.lua（战斗逻辑） | |
| 3文件：定义+战斗+辅助 | 每个职业拆为 Xxx.lua + combat.lua + utility.lua | |
| 单文件保持 | 每个职业保持单文件，仅内部重组 | |
| **按职业维度灵活拆分** | 有明确维度的类比 Druid cat/bear 多文件，无明确维度的默认 2 文件 | ✓ |

**User's choice:** 有明确维度的类比 Druid cat/bear 多文件，无明确维度的默认 2 文件

**Notes:** 用户指出非 Druid 职业也有自己的拆分维度（战士姿态、法师/猎人天赋类型等），类似 Druid 的 cat/bear。若目前看不出明显维度，就先按 2 文件模式（职业基础逻辑 + 战斗逻辑）拆分。

---

## 类定义补齐

| Option | Description | Selected |
|--------|-------------|----------|
| **全部补齐（推荐）** | 为所有 5 个职业创建完整类定义：classMetatable + FIELD_FUNC_MAP + registerPlayerClass | ✓ |
| 最小补齐 | 仅创建类定义壳和 FIELD_FUNC_MAP（空表），不添加 registerPlayerClass | |

**User's choice:** 全部补齐（推荐）

**Notes:** Warrior/Mage/Priest/Rogue/Warlock 完全对齐 Druid/Hunter 标准架构。Hunter 已有类定义，补齐 registerPlayerClass + SpellTrace + SelfTest。

---

## 代码现代化程度

| Option | Description | Selected |
|--------|-------------|----------|
| 仅结构调整（推荐） | 只做文件拆分和类定义补齐，保持 CastSpellByName() 不变 | |
| 替换为 player.cast() | 将 CastSpellByName 替换为 player.cast()，不创建技能方法 | |
| **全面对齐Druid** | 技能方法 + SpellTrace:register + SelfTest:register，完全对齐 Phase 5-7 模式 | ✓ |

**User's choice:** 全面对齐Druid

**Notes:** 将约 40 处 CastSpellByName() 替换为技能方法对象；内联多语言表 {en='...', zh='...'}；添加 SpellTrace 和 SelfTest 注册。

---

## 目录结构

| Option | Description | Selected |
|--------|-------------|----------|
| **独立子目录（推荐）** | 每个职业 classes/hunter/, classes/warrior/ 等，与 druid/ 深度一致 | ✓ |
| 保持扁平 | 单个 classes/Xxx.lua 文件，或用前缀区分 | |

**User's choice:** 独立子目录（推荐）

**Notes:** 完整对齐 Druid 的目录结构深度。子目录内文件名用小写，与 Druid 的 cat.lua/bear.lua/utility.lua 风格一致。

---

## Claude's Discretion

- 逐职业的文件拆分边界（哪些职业按什么维度拆分、拆几个文件）
- 每个职业的技能方法清单（从现有 CastSpellByName 调用点提取）
- 每个职业的 FIELD_FUNC_MAP 初始内容
- SpellTrace/SelfTest 注册的具体实现
- Hunter 类是否需要从单文件拆分为多文件
- 文件内代码组织顺序和注释风格
- 中文技能名的英文翻译（Rogue: 偷窃→Pick Pocket, 出血→Hemorrhage 等）

## Deferred Ideas

- 非 Druid 职业战斗逻辑完善（属于各自的未来 Phase）
- Warrior Stance 语义化方法（类比 Druid isInCatForm/isInBearForm）
- 天赋系统检测（类比 Druid Ancient Brutality 模式）
- 宠物系统统一管理接口