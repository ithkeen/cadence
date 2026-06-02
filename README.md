# Cadence

> 显式调用、中文输出的开发工作流。支持 Claude Code plugin 与 Codex plugin。

Cadence 把一次开发从「想法」到「代码」拆成一条**显式触发**的流水线：每个阶段一个 slash command，产物落档成 Markdown，下一阶段在上一阶段的产物上继续。需求、设计、拆分、实现各司其职，边界清晰，全程中文。

## 设计理念

- **显式调用**：不靠模型自由发挥猜你要什么，每个阶段你主动敲命令进入。
- **需求 / 设计 / 实现分离**：`pai` 只谈「做什么」，`may` 只谈「怎么做」，`run` 才动代码——前一阶段没锁死，不进下一阶段。
- **产物即契约**：每阶段落一份 Markdown 到 `.cadence/cycle-<主题>/`，下游只读这份文档，不必回头翻上下文。
- **子 agent 各守边界**：拆 phase 的不写代码，写代码的不拆 phase，调研的不碰实现。
- **信任模型能力**：提示词只写模型做不到或易做错的硬约束，能省则省。

## 工作流

```
cadence:init               幂等注入项目根规则块 + .gitignore
        │
   cadence:pai             需求拷打：连环追问划清边界（只谈做什么）
        ▼
   pai-<主题>.md            目标 / 范围内 / 范围外 / 输入输出 / 异常 / 验收
        │
   cadence:pai-with-md      需求复审：审核者视角挑缺口，继续拷打，就地改
        │
   cadence:may             技术设计：定技术栈 / 模块 / 接口 / 数据 / 流程
        ▼
   may-<主题>.md            = pai 正文原样保留 + 追加「# 设计」段
        │
   cadence:run             编排：拆 phase → 逐个 TDD 实现
        ▼
   phase1.md … phaseN.md → 代码
```

产物统一落在 `.cadence/cycle-<主题>/` 下，外部调研笔记落在 `.cadence/research/`。

## 安装

### Codex

Codex 版不使用 Claude 的 slash command / 子 agent 注册机制，而是把用户可触发的能力暴露为 skills。`plan-agent` 与 `code-executor` 是 `cadence:run` 的内部执行说明，不作为独立 Codex skill 暴露。安装后在 Codex 里用自然语言触发即可，例如：

```
用 cadence:init 初始化当前项目
用 cadence:pai 开启一个需求 cycle
用 cadence:may .cadence/cycle-demo/pai-demo.md 做技术设计
用 cadence:run .cadence/cycle-demo/may-demo.md 实现
```

安装方式：

```bash
codex plugin marketplace add ithkeen/cadence
codex plugin add cadence@cadence
```

本地调试当前 checkout 时，也可以把路径作为 marketplace 加进去：

```bash
codex plugin marketplace add /path/to/cadence
codex plugin add cadence@cadence
```

当前仓库根目录就是 Codex 插件根目录，Codex manifest 是 `.codex-plugin/plugin.json`；仓库内不维护 `.agents/` marketplace 包装，也不额外包一层 `plugins/cadence/`。

安装后在新 Codex 会话里使用。先跑一次 `cadence:init`，它会把规则块写进项目根 `AGENTS.md`（幂等，可重复执行）。

### Claude Code

在 Claude Code 中添加本仓库为插件市场并安装：

```
/plugin marketplace add ithkeen/cadence
/plugin install cadence
```

安装后在你的项目里先跑一次 `/cadence:init`，把 cadence 的规则块写进项目根 `CLAUDE.md`（幂等，可重复执行）。

## Codex Skills

| Skill | 作用 | 输入 | 产物 |
|---|---|---|---|
| `cadence-init` | 注入项目 `AGENTS.md` 规则块与 `.gitignore` | 无 | 项目根 `AGENTS.md` |
| `cadence-pai` | 需求拷打，连环追问划清需求 / 功能边界 | 对话 | `pai-<主题>.md` |
| `cadence-pai-review` | 需求复审，挑缺口补齐后就地改文档 | `pai-*.md` 路径或目录 | 就地修订 |
| `cadence-may` | 技术设计，不重做需求，只定实现方案 | `pai-*.md` 路径 | `may-<主题>.md` |
| `cadence-run` | 串起拆 phase 与逐 phase 实现 | `may-*.md` 路径 | `phaseN.md` + 代码 |
| `cadence-research` | 外部库 / API / 标准 / 法规调研 | topic + output dir | `.cadence/research/*.md` |
| `cadence-code-review` | 高置信度 code review | diff 范围 | 中文 review |
| `cadence-md-to-html` | Markdown 渲染为设计系统 HTML | md 路径 + 输出路径 | 单文件 HTML |

`cadence-run` 内部读取 `skills/cadence-run/references/plan-phases.md` 与 `skills/cadence-run/references/implement-phase.md`，对应 Claude 侧的 `plan-agent` 和 `code-executor`。

## Claude Commands

| 命令 | 作用 | 输入 | 产物 |
|---|---|---|---|
| `/cadence:init` | 注入项目 `CLAUDE.md` 规则块与 `.gitignore` | 无 | 项目根 `CLAUDE.md` |
| `/cadence:pai` | 需求拷打，连环追问划清需求 / 功能边界 | 对话 | `pai-<主题>.md` |
| `/cadence:pai-with-md` | 需求复审，挑缺口补齐后就地改文档 | `pai-*.md` 路径 | 就地修订 |
| `/cadence:may` | 技术设计，不重做需求，只定实现方案 | `pai-*.md` 路径 | `may-<主题>.md` |
| `/cadence:run` | 调度 plan-agent 拆 phase、code-executor 逐个实现 | `may-*.md` 路径 | `phaseN.md` + 代码 |

## Claude 子 Agent

| Agent | 职责 | 边界 |
|---|---|---|
| `plan-agent` | 读 `may` 文档，按功能域拆成自包含的 `phaseN.md` | 不写代码、不调度 executor、不读源码、不改 may |
| `code-executor` | 拿单个 phase，用 TDD 红绿重构落地 | 不做任务外的功能 / 优化；不适用于 UI 任务 |
| `research-agent` | 外部库 / API / 标准 / 法规调研，产出中文笔记 | 只读外部资料，被 `pai` / `may` 按需调起 |
| `code-reviewer` | 高置信度 code review，按 severity 输出中文报告 | 只读不改 |
| `md-to-html` | 把 Markdown 按设计系统渲染成单文件 HTML | — |

## Skills

- **tdd**：红-绿-重构循环，测试透过公共接口验证行为而非实现细节。`code-executor` 默认挂载。
- **onboarding**：为陌生代码库生成结构化入门文档，优先 Mermaid 图。

## 约定

- **全程中文**：所有命令与子 agent 产物均为中文。
- **产物目录**：`.cadence/cycle-<主题>/`（cycle 产物）、`.cadence/research/`（调研笔记），均默认进 `.gitignore`。
- **规则块**：`cadence:init` 注入的规则强调简洁优先、精准外科式修改，约束模型不越界改动。Claude 写入 `CLAUDE.md`，Codex 写入 `AGENTS.md`。

## 维护

```bash
scripts/bump-version.sh --check
scripts/check-plugin-consistency.sh
```

发版改版本号时用：

```bash
scripts/bump-version.sh <X.Y.Z>
```

## License

[MIT](./LICENSE) © 2026 ithkeen
