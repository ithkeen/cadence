---
name: cadence
description: "用户输入包含 cadence:init、cadence:pai、cadence:pai-with-md、cadence:may、cadence:run、cadence:research、cadence:code-review、cadence:md-to-html，或中文冒号形式 cadence：<动作> 时使用。"
---

# Cadence

除命令、代码、文件原文外，输出中文。

## 路由

匹配 `cadence:<动作>` 或 `cadence：<动作>`；先匹配长动作。

- `init`：按 `references/init.md` 处理。
- `pai-with-md`：按 `references/pai-review.md` 处理。
- `pai`：按 `references/pai.md` 处理。
- `may`：按 `references/may.md` 处理。
- `run`：按 `references/run.md` 处理。
- `research`：派发子 agent，使用 `../../assets/codex-agents/research-agent.toml` 作为指引。
- `code-review`：派发子 agent，使用 `../../assets/codex-agents/code-reviewer.toml` 作为指引。
- `md-to-html`：派发子 agent，使用 `../../assets/codex-agents/md-to-html.toml` 作为指引。

## 执行

- 只读取命中的 reference 或 agent TOML；文件明确要求继续读取其他文件时再读。
- 子 agent prompt 必须包含对应 agent TOML 的完整指引和用户任务。
- 未命中动作时，只列出支持动作。
