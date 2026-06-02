---
name: cadence
description: "用户输入包含 cadence:init、cadence:pai、cadence:pai-with-md、cadence:may、cadence:run、cadence:research、cadence:code-review、cadence:md-to-html，或中文冒号形式 cadence：<动作> 时使用。"
---

# Cadence

除命令、代码、文件原文外，输出中文。

## 路由

匹配 `cadence:<动作>` 或 `cadence：<动作>`；先匹配长动作。

- `init`：按 `references/init.md` 处理。
- `pai-with-md`：按 `references/pai-with-md.md` 处理。
- `pai`：按 `references/pai.md` 处理。
- `may`：按 `references/may.md` 处理。
- `run`：按 `references/run.md` 处理。
- `research`：直接调用 `research-agent` 子 agent。
- `code-review`：直接调用 `code-reviewer` 子 agent。
- `md-to-html`：直接调用 `md-to-html` 子 agent。

## 执行

- 只读取命中的 reference；文件明确要求继续读取其他文件时再读。
- 需要调用子 agent 的动作，直接按名称调用已安装到用户空间的 agent。
- 子 agent 没有命令参数或 argv；输入通过发给子 agent 的任务 prompt 传递。prompt 用稳定字段块表达，例如 `[topic] ...`、`[output_dir] ...`，缺必填字段时先问用户补齐。
- 未命中动作时，只列出支持动作。

## 子 agent 输入

- `research-agent`：
  ```text
  [topic] <调研主题>
  [output_dir] .cadence/research
  [depth] <L1|L2|L3，可选>
  ```
- `code-reviewer`：
  ```text
  [diff_command] <git diff 命令；用户未指定时可省略，让 agent 按自身兜底规则处理>
  [review_focus] <用户特别要求关注的点，可选>
  ```
- `md-to-html`：
  ```text
  [input_md] <要渲染的 markdown 路径>
  [output_html] <输出 HTML 路径>
  [title] <标题，可选>
  ```
