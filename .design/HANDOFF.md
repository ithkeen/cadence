# Cadence Plugin 交接文档

> 用途：上下文清空后冷启动续做。下一个对话**先读这份**，再读 `.design/` 下其他文档。
> 当前日期：2026-05-11

---

## 项目定位

为 Claude Code 写一个名为 **cadence** 的 plugin。
显式调用、中文输出、不分前后端角色、4 主命令闭环 + 1 辅助命令。
本项目根目录 = plugin 根目录（不安装到全局）。

主链路（4 命令）：
```
/cadence:spec    →  REQUIREMENT.md + REQUIREMENT.html
/cadence:design  →  DESIGN.md + DESIGN.html
/cadence:run     →  PLAN.md（含 plan-reviewer 2 轮）+ RUN-STATE.md + 代码
/cadence:archive →  更新 .cadence/PROJECT.md
```

辅助命令：
```
/cadence:cleanup →  删 CURRENT 指向的 cycle 目录 + 清空 CURRENT（中途放弃用）
```

4 个子 agent：`research-agent`、`plan-reviewer`、`task-executor`、`code-reviewer`。

---

## 已完成（设计 + 实现均落地，设计与实现已对齐）

### 设计阶段（全部定稿，归档在 `.design/`）

| 文件 | 内容 |
|---|---|
| `00-overview.md` | 整体设计、cycle 概念、双层文档结构、协作关系 |
| `01-spec.md` | spec 命令设计（已反向同步实现引入的 5 项细节） |
| `02-design.md` | design 命令设计 |
| `03-run.md` | run 命令设计（plan 阶段 + 调度执行 + reviewer 全流程） |
| `04-archive.md` | archive 命令设计 |
| `05-subagents.md` | 4 种子 agent 完整定义 |
| `06-plugin-spec.md` | Claude Code plugin 规范要点（实现依据） |
| `07-cleanup.md` | cleanup 辅助命令设计 |

### 实现阶段

| 已实现 | 路径 |
|---|---|
| plugin manifest | `.claude-plugin/plugin.json` |
| `/cadence:spec` 命令 | `commands/spec.md` |
| `/cadence:design` 命令 | `commands/design.md` |
| `/cadence:run` 命令 | `commands/run.md` |
| `/cadence:archive` 命令 | `commands/archive.md` |
| `/cadence:cleanup` 命令 | `commands/cleanup.md` |
| `research-agent` 子 agent | `agents/research-agent.md` |
| `plan-reviewer` 子 agent | `agents/plan-reviewer.md` |
| `task-executor` 子 agent | `agents/task-executor.md` |
| `code-reviewer` 子 agent | `agents/code-reviewer.md` |

---

## 未完成

### 端到端测试
plugin 代码全部就绪。需要在新终端实跑一遍验证：

```bash
cd /Users/ithkeen/CodeSpace/agent-project/cadence
claude --plugin-dir ./
```

会话内的冒烟流程建议：

1. `/cadence:spec 添加用户登录功能` —— 造一个 cycle，验证启动前置检查、追问节奏、双写产物
2. `/cadence:cleanup` —— 验证清理能力，让 CURRENT 回到空状态
3. 完整链路：`/cadence:spec ...` → `/cadence:design` → `/cadence:run` → `/cadence:archive` —— 验证 4 主命令串接正常，PROJECT.md 被正确创建
4. 中途放弃测试：`/cadence:spec` 中途调起调研后取消 → `/cadence:cleanup` —— 验证孤儿目录被清理

预期：每个命令显式调用即触发；中文输出；产物落到 `.cadence/cycle-<slug>/`；run 命令两阶段对用户透明（感知不到 plan 是独立阶段）；archive 全 ✅ 才放行。

### 已知风险点（实跑时重点关注）

- **mcp__context7__* 通配语法**：实现时已在 frontmatter 展开为 `mcp__context7__resolve-library-id, mcp__context7__query-docs` 两个具体工具名（涉及 `agents/research-agent.md` 与 `agents/task-executor.md`）。如果运行时报错说工具名不识别，回到 Claude Code 文档查证当前 context7 工具的实际命名。
- **task-executor 写入边界**：prompt 已硬规则禁止 Write `.cadence/` 下文件。如果实跑发现 executor 误改 RUN-STATE.md，加强 prompt 措辞或考虑用 `disallowedTools` 把特定路径的 Write 拒掉。
- **plan-reviewer 第 2 轮后定稿纪律**：是 `commands/run.md` 主 agent 侧的调度纪律，reviewer 自身不知第几轮。如果实跑发现循环 review，检查 run.md 的 Step 9 实现。

实跑出现问题时，按 `commands/<name>.md` 与 `agents/<name>.md` 实际内容直接修，事后再回写设计文档（参考已完成的"反向同步"模式）。

---

## 关键设计决策速查

下个会话冷启动时，看这一节就能记住核心约束，不用通读所有 `.design/` 文档：

### 文件结构
```
.cadence/
├── CURRENT                       游标，单行 cycle 目录名，archive 后清空
├── PROJECT.md                    项目档案（只在 archive 写），导航 + 约定，不含功能详情
└── cycle-<slug>/
    ├── REQUIREMENT.md / .html    spec 产物
    ├── DESIGN.md / .html         design 产物
    ├── PLAN.md                   run 命令 plan 阶段产物（不写 html）
    ├── RUN-STATE.md              run 命令调度状态（每次状态变更完整重写）
    └── research/<topic>.md       按需调研产物（仅 spec/design 阶段产生）
```

各模块 `<module>/README.md` 由 task-executor 维护（属于代码工件，不是 plugin 产物，但 plugin 强制维护）。

### 用户参与密度
spec/design 重（深度对话）→ run（plan 阶段 reviewer 兜底，run 阶段执行不打扰）→ archive 不打扰。

### 双写产物的 md/html 关系
**两份内容不一样**，是同一信息的两种表达。md 给模型读（结构化、消歧），html 给用户读（视觉化、扫读）。Mermaid 用 CDN 引入，不本地化。

### 子 agent 调用约定

| 子 agent | 调用方 | 时机 |
|---|---|---|
| research-agent | spec/design 主 agent | 识别信息缺口 + 用户 AskUserQuestion 确认后 |
| plan-reviewer | run 主 agent（plan 阶段） | 拆完 plan 后 **严格 2 轮**，第 2 轮后无论结果按建议定稿 |
| task-executor | run 主 agent | 每个 task；review 不过时再起一次（fix） |
| code-reviewer | run 主 agent | 每个 task-executor 完成后；返 needs_fix 时起 fix executor，**fix 后不再 review** |

### run 阶段失败兜底
- task-executor 抛错 / 没 commit / acceptance 没满足 → 立即重试 1 次，**不附加失败原因**
- 仍失败 → 标 ❌，依赖者跳过，继续跑能跑的
- archive 前置：RUN-STATE 必须全部 ✅，任何 ❌ 报错退出，**不允许强制归档**

### 主 agent 边界（run）
- ❌ 不调 Edit 改代码（工具白名单不含 Edit）
- ❌ Write 不能用于项目源码（只用于 `.cadence/` 下 PLAN.md / RUN-STATE.md）
- ❌ 不读项目源码
- ✅ 只调 Agent 工具分发 task
- ✅ 维护 RUN-STATE.md（每次状态变更完整重写）

### 并发上限 3
针对 task-executor。code-reviewer / fix executor 跟在 executor 之后串行跑，不抢额度。

### 无用代码硬规则
- task-executor prompt 中明确禁止"为将来扩展先写抽象"、"注释掉的旧实现"、"TODO 占位函数"
- code-reviewer 把"无用代码"列为 critical 审查项，发现必走 fix

### Task 粒度（run 的 plan 阶段拆出）
3h / 30 文件以内为标准。粗了拆，细了合。

### Task schema（PLAN.md 内）
仅 5 字段：`id` / `title` / `deps` / `acceptance` / `context_hint`。
**不要** `files` / `area` 字段。

### fix executor 不是新 agent
是 task-executor 的特化调用：当 prompt 中包含 `[Fix 模式]` 段落与 issues 列表时，task-executor 进入 fix 分支。所以只有 4 个 agent 文件。

---

## 工具白名单（实现已采用）

### 命令

| 命令 | allowed-tools |
|---|---|
| spec | Read, Write, Edit, Bash, Agent, AskUserQuestion |
| design | Read, Write, Edit, Bash, Agent, AskUserQuestion |
| run | Read, Write, Bash, Agent（**不含 Edit**，主 agent plan/run 全程不改代码；PLAN.md 用 Write 整体重写） |
| archive | Read, Write, Edit, Bash |
| cleanup | Read, Write, Bash |

### 子 agent

| 子 agent | tools |
|---|---|
| research-agent | Read, Write, Bash, WebSearch, WebFetch, mcp__context7__resolve-library-id, mcp__context7__query-docs |
| plan-reviewer | Read, Grep, Glob |
| task-executor | Read, Write, Edit, Bash, Grep, Glob, mcp__context7__resolve-library-id, mcp__context7__query-docs |
| code-reviewer | Read, Grep, Glob, Bash |

> 注：设计文档 `.design/06-plugin-spec.md` 中的 `mcp__context7__*` 通配写法在 frontmatter 实际不被识别，实现时已展开为两个具体工具名。

---

## 下个会话起手式建议

1. 读这份 HANDOFF.md
2. 速读 `.design/00-overview.md` 拿核心概念
3. 进入端到端测试（见上文「未完成 → 端到端测试」）
4. 测试中遇到问题 → 直接改 `commands/` 或 `agents/` 下对应文件，事后回写 `.design/`
5. 全部冒烟通过 → 项目 v0.1.0 完成，可以考虑写 README、发布到 marketplace 或其他 plugin 分发渠道
