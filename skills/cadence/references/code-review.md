---
name: cadence-code-review
description: Cadence 高置信度代码评审，只读 git diff 和相关上下文，输出中文 findings。Use when the user asks for code review, cadence code review, review staged changes, review git diff, or after Cadence implementation when a review pass is requested.
---

# Cadence Code Review

Review code changes with a high-confidence, low-noise stance. Do not edit files.

## Diff Selection

Use the user's requested diff command when provided. Otherwise:

1. Try `git diff --cached`
2. If empty, try `git diff`

If no diff exists, return `⚠️ no changes in diff output`.

## Rules

- Output Chinese.
- Only review changed lines and behavior introduced by the diff. Read surrounding files only to understand context.
- Do not report pre-existing issues as findings.
- Do not report style, formatting, missing docstrings, naming preference, best-practice-only advice, theoretical races without a concrete path, or dependency freshness.
- Report only findings with confidence >= 7, except CRITICAL can be >= 5 if uncertainty is explicit.
- Prefer no finding over a guessed finding.

## Finding Categories

Report concrete bugs, security issues, data correctness problems, lifecycle/resource leaks, meaningful code-quality issues that imply a bug, memory safety issues in unsafe contexts, or clear availability risks.

## Output Format

```markdown
# Code Review: <改动简述>

> 评审范围：<实际使用的 diff 命令>
> 改动概览：<文件数和 +/- 概览>

## 1. 摘要
- **改动概述**：<一段话>
- **结论**：N 项 findings（X CRITICAL, Y MAJOR, Z MINOR）

## 2. Findings

### F1. <标题>
- **路径**：`path/to/file.ext:LINE`
- **Severity**：CRITICAL | MAJOR | MINOR
- **Confidence**：N/10
- **类别**：bug | security | correctness | concurrency | code-quality | memory-safety | availability
- **现象**：<1-2 句话>
- **触发路径**：<具体输入 / 状态 / 时序>
- **建议修法**：<最小改动>
```

If no finding meets the threshold, write:

```text
No issues at the required confidence threshold.
```
