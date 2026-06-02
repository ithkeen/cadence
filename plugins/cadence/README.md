# Cadence

> 显式触发、中文输出的开发工作流插件，支持 Claude Code plugin 与 Codex plugin。

Cadence 把开发过程拆成 `init -> pai -> pai-with-md -> may -> run`。需求文档、技术设计、phase 任务和调研笔记都落在 `.cadence/`，让一次开发可以按文档在多个阶段之间衔接。

## 工作流

```
cadence:init
    │
    ▼
cadence:pai
    ▼
pai-<主题>.md
    │
    ├─ cadence:pai-with-md
    │
    ▼
cadence:may
    ▼
may-<主题>.md
    │
    ▼
cadence:run
    ▼
phase1.md ... phaseN.md + 代码
```

主要产物：

| 路径 | 内容 |
|---|---|
| `.cadence/cycle-<主题>/pai-<主题>.md` | 需求边界与验收标准 |
| `.cadence/cycle-<主题>/may-<主题>.md` | 技术设计 |
| `.cadence/cycle-<主题>/phaseN.md` | 实施 phase |
| `.cadence/research/*.md` | 外部调研笔记 |

## 安装

### Codex

Codex 插件由 `.codex-plugin/plugin.json` 声明，skills 根目录是 `skills/`。

```bash
codex plugin marketplace add ithkeen/cadence
codex plugin add cadence@cadence-marketplace
```

如果已经添加过旧快照，发布新提交后先刷新：

```bash
codex plugin marketplace upgrade cadence-marketplace
```

本地调试当前 checkout：

```bash
codex plugin marketplace add /path/to/cadence
codex plugin add cadence@cadence-marketplace
```

安装后在新 Codex 会话里触发：

```text
用 cadence:init 初始化当前项目
用 cadence:pai 开启一个需求 cycle
用 cadence:may 做技术设计
用 cadence:run 执行技术设计
```

`cadence:init` 会更新项目根 `AGENTS.md` 与 `.gitignore`，并把 `assets/codex-agents/*.toml` 同步到 Codex agents 目录。涉及文档路径的动作会在触发后询问 `pai` 或 `may` 文件路径。

### Claude Code

Claude Code 插件由 `.claude-plugin/plugin.json` 声明，并通过 `.claude-plugin/marketplace.json` 提供本地 marketplace 元数据。

```text
/plugin marketplace add ithkeen/cadence
/plugin install cadence
```

安装后在项目里先运行：

```text
/cadence:init
```

`/cadence:init` 会更新项目根 `CLAUDE.md` 与 `.gitignore`。

## Codex 入口

| 入口 | 作用 | 主要产物 |
|---|---|---|
| `cadence:init` | 初始化项目规则与运行产物忽略项 | `AGENTS.md`、`.gitignore` |
| `cadence:pai` | 梳理需求边界与验收标准 | `pai-<主题>.md` |
| `cadence:pai-with-md` | 复审并修订 pai 文档 | 就地修订 |
| `cadence:may` | 基于 pai 文档产出技术设计 | `may-<主题>.md` |
| `cadence:run` | 拆 phase 并逐个实现 | `phaseN.md`、代码 |
| `cadence:research` | 外部库、API、标准、法规调研 | `.cadence/research/*.md` |
| `cadence:code-review` | 代码评审 | 中文 review |
| `cadence:md-to-html` | Markdown 渲染为设计系统 HTML | 单文件 HTML |

Codex 工作流路由位于 `skills/cadence/SKILL.md`，流程 reference 位于 `skills/cadence/references/`。Codex agent 定义位于 `assets/codex-agents/*.toml`。

顶层 Codex skills：

| Skill | 作用 |
|---|---|
| `cadence` | Cadence 工作流入口 |
| `tdd` | 红绿重构、接口测试、mock 与重构指导 |
| `onboarding` | 陌生代码库入门文档生成 |

## Claude 入口

| 命令 | 作用 | 主要产物 |
|---|---|---|
| `/cadence:init` | 初始化项目规则与运行产物忽略项 | `CLAUDE.md`、`.gitignore` |
| `/cadence:pai` | 梳理需求边界与验收标准 | `pai-<主题>.md` |
| `/cadence:pai-with-md` | 复审并修订 pai 文档 | 就地修订 |
| `/cadence:may` | 基于 pai 文档产出技术设计 | `may-<主题>.md` |
| `/cadence:run` | 调度 `plan-agent` 与 `code-executor` | `phaseN.md`、代码 |

Claude commands 位于 `commands/`，Claude subagents 位于 `agents/`。

## Agents

Claude 版使用 `agents/*.md`，Codex 版使用 `assets/codex-agents/*.toml`。

| Agent | 作用 |
|---|---|
| `plan-agent` | 把 `may-<主题>.md` 拆成 `phaseN.md` |
| `code-executor` | 按单个 phase 任务用 TDD 落地代码 |
| `research-agent` | 调研外部库、API、标准、法规 |
| `code-reviewer` | 输出高置信度代码评审 |
| `md-to-html` | 把 Markdown 渲染为设计系统 HTML |

## 仓库结构

| 路径 | 内容 |
|---|---|
| `.codex-plugin/plugin.json` | Codex plugin manifest |
| `.claude-plugin/` | Claude plugin manifest 与 marketplace 元数据 |
| `skills/cadence/` | Codex Cadence skill 与流程 references |
| `skills/tdd/` | TDD skill |
| `skills/onboarding/` | Onboarding skill |
| `commands/` | Claude slash commands |
| `agents/` | Claude subagents |
| `assets/codex-agents/` | Codex agent TOML 定义 |
| `assets/html-design/` | `md-to-html` 使用的 HTML 设计系统资产 |
| `rules/project-rules.md` | `cadence:init` 注入的项目规则块 |
| `scripts/` | 初始化、版本与一致性检查脚本 |

## 维护

```bash
scripts/check-plugin-consistency.sh
scripts/bump-version.sh --check
```

发版改版本号：

```bash
scripts/bump-version.sh <X.Y.Z>
```

版本字段由 `.version-bump.json` 定义。

## License

[MIT](./LICENSE) © 2026 ithkeen
