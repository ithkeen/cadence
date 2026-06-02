---
name: cadence
description: Cadence 在 Codex 中的总入口。当用户提到 cadence:init、cadence:pai、cadence:pai-with-md、cadence:may、cadence:run、cadence research、cadence code review、cadence md-to-html，或要求在 Codex 中使用 Cadence 工作流时使用。
---

# Cadence

你是 Cadence 在 Codex 中的总入口。Cadence 是一个中文、显式分阶段的开发工作流：

1. `cadence:init` 注入项目规则。
2. `cadence:pai` 澄清需求边界，并产出 `pai-<主题>.md`。
3. `cadence:pai-with-md` 复审并修订已有的 `pai-*.md`。
4. `cadence:may` 把 `pai-*.md` 转成技术设计 `may-<主题>.md`。
5. `cadence:run` 从 `may-*.md` 拆出阶段文件，并按顺序实施。

除非命令、代码或源文件格式另有要求，输出一律使用中文。

## 路径解析

以当前 `SKILL.md` 为基准解析 Cadence 插件根目录：`skills/cadence/SKILL.md` 的上两级目录就是插件根目录。

内部参考文件位于 `skills/cadence/references/`。这些文件是原有斜杠命令和代理的镜像；不要改写、摘要化或翻译它们。执行某个动作时，只读取该动作需要的参考文件，以及它明确点名需要继续读取的参考文件。

## 请求路由

- `cadence:init`、`初始化 cadence` → 读取 `references/init.md`。
- `cadence:pai`、`开启需求 cycle`、`梳理需求边界` → 读取 `references/pai.md`。
- `cadence:pai-with-md`、`cadence 需求复审`、`复审 pai` → 读取 `references/pai-review.md`。
- `cadence:may`、`技术设计`、`pai 转 may` → 读取 `references/may.md`。
- `cadence:run`、`执行 may`、`may 跑成代码` → 读取 `references/run.md`；同时会用到 `references/plan-phases.md` 和 `references/implement-phase.md`。
- `cadence research`、`cadence-research`、外部库 / API / SDK / 标准调研 → 读取 `references/research.md`。
- `cadence code review`、`cadence-code-review`、代码评审请求 → 读取 `references/code-review.md`。
- `cadence md-to-html`、把 Markdown 渲染 / 可视化 / 分享成 HTML → 读取 `references/md-to-html.md`。

如果用户请求的 Cadence 动作不在上面，说明当前支持哪些动作；如果缺少必要输入，再向用户索要。

## 边界

- 这是唯一面向 Codex 的 Cadence 技能。不要要求用户调用 `cadence-pai`、`cadence-may` 或其他已移除的单命令技能。
- 除非用户明确要求独立的本地安装流程，不要向 `~/.agents/skills`、`~/.codex/agents` 或任何 home 目录写入文件。
- `cadence:run` 默认在当前 Codex 会话内串行实施阶段。只有用户明确要求子代理委派，且当前工具策略允许时，才使用 Codex 子代理。
- 保持 Cadence 的阶段边界：`pai` 只讨论做什么，`may` 只讨论怎么设计，`run` 才修改代码。
