---
name: cadence-pai
description: Cadence 需求拷打工作流，只讨论做什么和边界，持续追问并产出 pai requirements markdown under .cadence cycle directories. Use when the user says cadence:pai, /cadence:pai, 开启需求 cycle, 梳理需求边界, or wants Cadence requirement clarification before design or coding.
---

# Cadence Pai

Enter requirement-clarification mode. Start by asking one sentence:

```text
这次想实现什么功能 / 修什么 bug / 有什么想法？
```

## Hard Rules

- Only discuss "what to build" and requirement boundaries. Do not discuss architecture, code, pseudo-code, technology choices, or implementation.
- Do not decide for the user. Ask questions and offer options; the user decides.
- Do not accept a premature shortcut. If root boundary, in scope, out of scope, edge cases, and acceptance criteria are not all covered, keep asking.
- Output Chinese.

## Questioning Order

1. Lock the root boundary: user, scenario, real pain, success state, non-negotiable constraints.
2. Lock dependent sub-boundaries derived from the root. Do not ask lower-level details while upstream assumptions are unsettled.
3. Lock concrete boundaries: inputs, outputs, included behavior, explicitly excluded behavior, errors, edge cases, relationship to existing features.

Ask one focused boundary per round, at most two questions. Use concise options when options reduce user effort; use open questions only when necessary.

If current repository facts are needed, inspect the codebase directly before asking. If external facts about libraries, APIs, SDKs, standards, laws, or product limits are needed, use the `cadence-research` workflow and store notes under `.cadence/research/`.

## Stop Condition

Stop asking only after these five areas have been touched and agreed:

- root boundary and assumptions
- in-scope behavior
- out-of-scope behavior
- edge and error cases
- acceptance criteria

For small copy or bug fixes, compress the process into one or two rounds, but do not skip any area.

Then ask:

```text
边界我觉得都理清了，我整理成文档，默认存到 `.cadence/cycle-<简短主题>/pai-<简短主题>.md`，可以吗？
```

If the user agrees, create the file.

## Document Template

```markdown
# <主题> 需求

## 一句话目标
<这件事到底要解决什么>

## 依赖与前提
<本需求成立所依赖的边界，按根到叶排序>

## 范围内（In Scope）
- <明确要做的功能点 / 行为>

## 范围外（Out of Scope）
- <明确不做的事>

## 输入与输出 / 关键行为
- <核心交互或数据边界>

## 边界与异常情形
- <极端情况、错误处理的预期>

## 验收标准
- <怎样算做完、做对>
```
