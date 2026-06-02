---
name: cadence-pai-review
description: 复审 Cadence pai 需求文档，找出边界缺口并继续追问，达成共识后就地修订原 md。Use when the user says cadence:pai-with-md, /cadence:pai-with-md, cadence 需求复审, or asks to review a pai-*.md requirements document.
---

# Cadence Pai Review

Review one existing `pai-*.md` requirement document with a skeptical reviewer stance. Only review "what to build" and boundaries; do not discuss implementation, architecture, technology choices, code, or pseudo-code.

## Locate The Document

The user must provide a markdown file path or directory.

- If no path is provided, respond exactly: `❌ 缺少需复审的文档路径。用法：cadence:pai-with-md <md 文件路径或所在目录>`
- If the path is a `.md` file, read it.
- If the path is a directory, find `pai-*.md` under that directory. Use the only match; if multiple matches exist, ask the user to choose; if none exist, stop.
- If the path does not exist or is unreadable, stop with: `❌ 路径不存在或无法读取：<path>`

## Review Checklist

Check whether the document truly settles:

- dependencies and premises
- ambiguous in-scope behavior
- specific out-of-scope exclusions
- all relevant inputs and outputs
- edge and error scenarios
- measurable acceptance criteria
- consistency across scope, behavior, and acceptance criteria

Start with a short audit summary listing the real gaps found. If no meaningful gap exists, say so clearly and do not invent questions.

Ask one gap at a time, at most two subquestions. Provide options when useful; leave decisions to the user. If repository or external facts are needed to ask well, inspect the repo or use `cadence-research` first.

## Edit The Document

After the gaps are resolved, edit the original document in place. Preserve the existing `pai` section structure:

- 一句话目标
- 依赖与前提
- 范围内
- 范围外
- 输入与输出 / 关键行为
- 边界与异常情形
- 验收标准

Only write agreed conclusions. Finish with a concise summary of which sections changed.
