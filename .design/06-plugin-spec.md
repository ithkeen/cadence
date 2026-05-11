# Claude Code Plugin 规范要点（实现依据）

来源：
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/slash-commands
- https://github.com/anthropics/claude-plugins-official
- https://github.com/ericbuess/claude-code-docs

## 目录布局（强约束）
```
cadence/                          ← plugin 根（也就是当前项目根）
├── .claude-plugin/
│   └── plugin.json               ← 唯一允许放在这里的文件
├── commands/                     ← 必须在根，不能放 .claude-plugin/
│   ├── spec.md
│   ├── design.md
│   ├── run.md
│   ├── archive.md
│   └── cleanup.md
├── agents/                       ← 必须在根
│   ├── research-agent.md
│   ├── plan-reviewer.md
│   ├── task-executor.md
│   └── code-reviewer.md
└── README.md                     ← 可选
```
组件（commands/agents/hooks）必须在 plugin **根目录**，不能放在 `.claude-plugin/` 内。

## plugin.json
最小字段：
```json
{
  "name": "cadence",
  "description": "显式调用、中文输出的开发工作流 plugin",
  "version": "0.1.0"
}
```
其他可选字段：`author`、`commands`、`hooks` 等。`name` 字段会作为 skill/命令的命名空间前缀，命令调用为 `/cadence:<command>`。

## 命令文件（commands/*.md）

文件名（去掉 `.md`）= 命令名。例如 `commands/spec.md` → `/cadence:spec`。

格式：YAML frontmatter + Markdown 正文。正文是命令被调用时模型执行的 prompt。

### frontmatter 字段
| 字段 | 类型 | 说明 |
|---|---|---|
| `description` | string | 命令一句话描述 |
| `argument-hint` | string | 自动补全提示，如 `[topic]` |
| `allowed-tools` | string / list | 该命令运行时允许的工具白名单 |
| `model` | string | 覆盖默认模型 |

### 正文中的参数
用 `$ARGUMENTS` 引用调用时传入的参数。

### 示例
```markdown
---
description: 澄清需求并产出 REQUIREMENT.md / .html
allowed-tools: Read, Write, Edit, Bash, Agent, AskUserQuestion
---

你是 cadence 的 spec 命令主 agent。本次任务：澄清需求...

[完整 spec 命令的 prompt 内容]
```

## Agent 文件（agents/*.md）

文件名 = agent 名（不含 plugin 命名空间前缀）。

格式：YAML frontmatter + Markdown 正文（系统 prompt）。

### frontmatter 字段
| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | string | agent 标识（默认取文件名） |
| `description` | string | 描述 + 何时调用 |
| `model` | string | `sonnet` / `opus` / `haiku` / `inherit` |
| `tools` | string / list | 该 agent 允许使用的工具（白名单）|
| `disallowedTools` | string / list | 黑名单 |
| `effort` | string | `low` / `medium` / `high` / `xhigh` / `max` |
| `maxTurns` | number | 最大对话轮次 |

### 示例
```markdown
---
name: code-reviewer
description: 审查刚完成 task 引入的代码改动。检查正确性、架构一致性、README 同步、无用代码等。
model: sonnet
tools: Read, Grep, Glob, Bash
---

你是 cadence 的 code reviewer。本次任务：审查刚完成的 task 引入的代码。

[完整审查清单 + 输出格式]
```

## 调用子 agent
在命令或父 agent 的 prompt 中，通过 `Agent` 工具调用子 agent，参数 `subagent_type` 传子 agent 的 `name`：

```
使用 Agent 工具：
- subagent_type: "code-reviewer"
- description: "审查 T3 改动"
- prompt: "..."
```

**前置**：该命令的 `allowed-tools` 必须包含 `Agent`。

## 本地开发与测试
```bash
claude --plugin-dir ./cadence
```
免安装直接调试。

## Cadence Plugin 落地映射

### 命令 → 文件
| 命令 | 文件 | allowed-tools |
|---|---|---|
| `/cadence:spec` | `commands/spec.md` | Read, Write, Edit, Bash, Agent, AskUserQuestion |
| `/cadence:design` | `commands/design.md` | Read, Write, Edit, Bash, Agent, AskUserQuestion |
| `/cadence:run` | `commands/run.md` | Read, Write, Bash, Agent |
| `/cadence:archive` | `commands/archive.md` | Read, Write, Edit, Bash |
| `/cadence:cleanup` | `commands/cleanup.md` | Read, Write, Bash |

run 命令的主 agent **不需要 Edit 工具**（设计硬规则：主 agent 不改代码；PLAN.md / RUN-STATE.md 用 Write 整体重写）。

### 子 agent → 文件
| 子 agent | 文件 | tools |
|---|---|---|
| research-agent | `agents/research-agent.md` | Read, Write, Bash, WebSearch, WebFetch, mcp__context7__* |
| plan-reviewer | `agents/plan-reviewer.md` | Read, Grep, Glob |
| task-executor | `agents/task-executor.md` | Read, Write, Edit, Bash, Grep, Glob, mcp__context7__* |
| code-reviewer | `agents/code-reviewer.md` | Read, Grep, Glob, Bash |

reviewer 类只读，executor 可写、可执行。

### 命名空间
plugin name 为 `cadence`，所以命令调用形如 `/cadence:spec`。子 agent 通过 `subagent_type` 引用时不带前缀，直接 `task-executor` 等。
