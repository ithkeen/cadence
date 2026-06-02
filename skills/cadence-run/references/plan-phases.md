# Cadence Plan Phases Reference

Read one `may-*.md` file and write self-contained `phaseN.md` files in the same output directory.
This is an internal reference for `cadence-run`, not a standalone user-facing Codex skill.

## Input

Require:

- `may_path`: readable `may-*.md` path
- `output_dir`: defaults to the may document directory

If either path is invalid, stop with a concise Chinese error. If the may document lacks `范围内`, `验收标准`, or `技术栈`, or if acceptance criteria are not machine-checkable enough to plan validation, do not create phase files. Explain what is missing and suggest returning to `cadence:may`.

## Split Rule

Split by feature domain, not by file, function, or layer.

- Keep cohesive APIs and behavior in one phase.
- Do not create one phase per endpoint.
- Do not create separate DB/service/API phases.
- If one in-scope item contains multiple feature domains, split it.

Every phase must answer:

- what it delivers
- how to verify it with exact executable commands
- constraints and what not to do

## Phase Template

```markdown
# Phase N：<功能域主题>

## 目标
<一句话：这个 phase 交付什么>

## 依赖
<前置 phase，如 "Phase 1：用户账户"；无则 "无">

## 范围内
- <功能点，对应 may「范围内」条目原文>

## 技术栈与约束
- 语言 / 框架 / 关键依赖（带版本，摘自 may「技术栈」）
- 测试框架与运行命令
- 不做什么：<摘自 may「范围外」+ 决策清单约束>

## 接口与数据
- <本 phase 涉及的接口形态、数据模型，摘自 may 设计段对应小节>

## 错误与边界
- <失败语义、边界情形，摘自 may「错误处理」「边界与异常情形」>

## 怎么算做完
- 验证命令：
  - `<可执行 shell 命令>`
- 验收（行为级）：
  - <输入 → 期望输出 / 可观察副作用>
```

Before writing, self-check that all in-scope items and acceptance criteria are covered, dependencies have no cycle, every validation command is concrete, and no phase adds extra work.

Return:

```text
✅ 已生成 <N> 个 phase：<output_dir>/phase1.md … phaseN.md
- Phase 1：<主题>（依赖：无）
...
建议按依赖顺序执行。
```
