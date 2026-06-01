# Cadence

> 显式调用、中文输出的开发工作流 Claude Code 插件。

Cadence 把一次开发从「想法」到「代码」拆成一条**显式触发**的流水线：每个阶段一个 slash command，产物落档成 Markdown，下一阶段在上一阶段的产物上继续。需求、设计、拆分、实现各司其职，边界清晰，全程中文。

## 设计理念

- **显式调用**：不靠模型自由发挥猜你要什么，每个阶段你主动敲命令进入。
- **需求 / 设计 / 实现分离**：`pai` 只谈「做什么」，`may` 只谈「怎么做」，`run` 才动代码——前一阶段没锁死，不进下一阶段。
- **产物即契约**：每阶段落一份 Markdown 到 `.cadence/cycle-<主题>/`，下游只读这份文档，不必回头翻上下文。
- **子 agent 各守边界**：拆 phase 的不写代码，写代码的不拆 phase，调研的不碰实现。
- **信任模型能力**：提示词只写模型做不到或易做错的硬约束，能省则省。

## 工作流

```
/cadence:init              幂等注入项目根 CLAUDE.md 规则块 + .gitignore
        │
   /cadence:pai            需求拷打：连环追问划清边界（只谈做什么）
        ▼
   pai-<主题>.md            目标 / 范围内 / 范围外 / 输入输出 / 异常 / 验收
        │
   /cadence:pai-with-md     需求复审：审核者视角挑缺口，继续拷打，就地改
        │
   /cadence:may            技术设计：定技术栈 / 模块 / 接口 / 数据 / 流程
        ▼
   may-<主题>.md            = pai 正文原样保留 + 追加「# 设计」段
        │
   /cadence:run            编排：plan-agent 拆 phase → code-executor 逐个实现
        ▼
   phase1.md … phaseN.md → 代码
```

产物统一落在 `.cadence/cycle-<主题>/` 下，外部调研笔记落在 `.cadence/research/`。

## 安装

在 Claude Code 中添加本仓库为插件市场并安装：

```
/plugin marketplace add ithkeen/cadence
/plugin install cadence
```

安装后在你的项目里先跑一次 `/cadence:init`，把 cadence 的规则块写进项目根 `CLAUDE.md`（幂等，可重复执行）。

## 命令

| 命令 | 作用 | 输入 | 产物 |
|---|---|---|---|
| `/cadence:init` | 注入项目 `CLAUDE.md` 规则块与 `.gitignore` | 无 | 项目根 `CLAUDE.md` |
| `/cadence:pai` | 需求拷打，连环追问划清需求 / 功能边界 | 对话 | `pai-<主题>.md` |
| `/cadence:pai-with-md` | 需求复审，挑缺口补齐后就地改文档 | `pai-*.md` 路径 | 就地修订 |
| `/cadence:may` | 技术设计，不重做需求，只定实现方案 | `pai-*.md` 路径 | `may-<主题>.md` |
| `/cadence:run` | 调度 plan-agent 拆 phase、code-executor 逐个实现 | `may-*.md` 路径 | `phaseN.md` + 代码 |

## 子 Agent

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
- **规则块**：`/cadence:init` 注入的规则强调简洁优先、精准外科式修改，约束模型不越界改动。

## License

[MIT](./LICENSE) © 2026 ithkeen
