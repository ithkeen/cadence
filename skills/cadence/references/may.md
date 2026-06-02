---
name: cadence-may
description: Cadence 技术设计工作流，读取 pai 需求文档，只做技术设计并产出 may design markdown. Use when the user says cadence:may, /cadence:may, 技术设计, or asks to turn a pai-*.md requirements document into a Cadence may design document.
---

# Cadence May

Read a `pai-*.md` requirement document and produce `may-<主题>.md` in the same directory. Do not rewrite requirements. The output is the original pai body verbatim, followed by `---` and a `# 设计` section.

## Locate Input

The user must provide a `pai-*.md` path.

- If missing, respond: `❌ 缺少 pai 需求文档路径。用法：cadence:may <pai-需求.md 路径>`
- If unreadable, respond: `❌ 路径不可读：<path>`
- Derive `<主题>` from the file name by removing `.md` and an optional leading `pai-`.
- If `may-<主题>.md` already exists, ask whether to overwrite or exit.

## Design Rules

- Output Chinese.
- Do not redo requirement analysis. Treat the pai document as agreed scope.
- Do not write code, pseudo-code, task phases, or implementation function names.
- Inspect the codebase only when needed for technical decisions.
- For external libraries, APIs, SDKs, standards, regulations, model APIs, breaking changes, or version-sensitive facts, use `cadence-research` and inline key facts into the design.
- Ask at most 1-2 questions per round. For technology choices, first present 2-3 options with one recommended option and the reason, then let the user decide.
- If the user says to write immediately but design decisions are still missing, continue asking.

Cover the dimensions that apply:

- technology stack, including named test framework and exact test command
- module boundaries
- data model
- interface design
- error and failure semantics
- key workflow
- non-functional constraints
- risks and decisions

For UI work, also settle:

- each UI block mode: `greenfield` or `inherit`
- `greenfield` aesthetic direction from: `brutalist`, `editorial`, `luxury-refined`, `playful`, `retro-futurist`, `industrial`, `soft-pastel`, `art-deco`, `maximalist-chaos`, `brutally-minimal`, `cyberpunk`, `organic-natural`
- `inherit` visual anchor
- palette, typography, component library with version, dark mode, key interaction states

## Done Criteria

Every in-scope requirement and every acceptance criterion has a technical counterpart; module boundaries are clear; uncertainty is settled; choices have reasons; UI work has mode and visual rules.

Then ask whether to write the document.

## Design Section Template

```markdown
---

# 设计

## 技术栈
- 语言 / 框架 / 关键依赖（带版本）
- 测试框架与运行命令

## 模块划分
- <模块名>：<职责一句话> [新增 / 修改 / 沿用]

## 数据模型
- <实体名>：字段、关系、持久化方式

## 接口设计
- <接口名>：方法、入参、出参、错误情形

## 错误处理
- <关键流程失败语义：错误结构 / 错误码命名 / 可重试性 / 降级>

## 关键流程
1. <主流程步骤>

## 非功能性约束
- 性能 / 安全 / 可观测 / 部署

## 视觉与交互风格
<!-- 仅 UI 需求写本节，纯后端 / 库 / CLI 删除 -->

## 决策清单
- 选 X 不选 Y，因为 ...
```

Finish with:

```text
✅ 技术设计已落档：<may-path>，源需求文档未动。复核后交下游实施。
```
