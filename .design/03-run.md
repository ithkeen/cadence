# /cadence:run 设计（已定稿）

## 定位
一个命令完成「拆 plan + 调度执行」的全流程。主 agent 在两个阶段切换角色：
- **plan 阶段**：思考者 / 拆解者 / 写 PLAN.md
- **run 阶段**：调度器，分发子 agent 执行

PLAN.md 是 run 命令的内部产物，用户不需要在中间检查；命令一气呵成。

## 调用形式
```
/cadence:run
```
不带参数。读 `CURRENT` + `REQUIREMENT.md` + `DESIGN.md` + `PROJECT.md`（如有）。

## 入口状态判断（必须最先做）

读 cycle 目录下文件，按以下顺序决定走哪条路：

| PLAN.md | RUN-STATE.md | 行为 |
|---|---|---|
| 不存在 | 不存在 | 走「plan 阶段」→ 走「run 阶段」 |
| 存在 | 不存在 | 跳过 plan，直接走「run 阶段」 |
| 存在 | 存在且有进度（含 ✅ 或 ❌） | 跳过 plan，进入「run 阶段增量模式」 |
| 存在 | 存在但全部 pending | 跳过 plan，正常走「run 阶段」 |
| 不存在 | 存在 | 异常状态，报错退出："RUN-STATE.md 存在但 PLAN.md 缺失，请人工排查" |

跳过 plan 阶段时输出一行简报：`检测到已有 PLAN.md，跳过规划阶段。`

## plan 阶段（主 agent 自己执行，不派子 agent）

### 不做清单
- 不修改需求 / 设计（发现问题报错退出，让用户回上游）
- 不写代码、不写实现细节
- 不预先分配子 agent
- 不输出 HTML

### Task schema
```yaml
- id: T1
  title: 一句话说清做什么
  deps: []
  acceptance:
    - ...
  context_hint: 参考 DESIGN.md 的"xxx"章节
```

字段说明：
- `id` —— 短标识，依赖引用用
- `title` —— 一句话说清做什么
- `deps` —— 依赖的 task id 列表，run 阶段按此画依赖图
- `acceptance` —— 客观可判定的完成标准
- `context_hint` —— 指向 DESIGN.md 章节，子 agent 不读全文

明确**不要**的字段：
- `files`（不写死路径）
- `area`（不预设 frontend/backend/db 等角色）

### Task 粒度标准
- 可独立交付：完成有可验收成果
- 上下文可承载：task 描述 + DESIGN 指定章节就能开工
- 验收明确：客观可判定
- 粗略 3h 内、改动 ≤ 30 文件

超过 → 拆；远低于 → 合。

### plan 阶段流程
1. Read REQUIREMENT.md / DESIGN.md / PROJECT.md（PROJECT.md 不存在则跳过）
2. 主 agent 按粒度标准 + DESIGN 模块边界拆 task 清单
3. **Write PLAN.md（v1）** —— 用 Write 整体写入，不用 Edit
4. 调 plan-reviewer（Agent 工具，subagent_type: "plan-reviewer"）做第 1 轮 challenge：
   - 依赖关系成环 / 遗漏？
   - task 过粗（>3h 或 >30 文件）？
   - task 过细（不构成有意义交付单元）？
   - acceptance 是否客观可验证？
   - DESIGN 每个决策是否都有 task 承接？
   - 漏了测试 / 文档 / 部署？
5. 主 agent 按 reviewer 反馈修订 → **Write PLAN.md（v2，整体重写）**
6. 调 plan-reviewer 做第 2 轮 challenge
7. 第 2 轮反馈 → **Write PLAN.md（final，整体重写）**——**严格 2 轮，第 2 轮后无论 reviewer 是否仍有意见都按主 agent 综合判断定稿**
8. plan 阶段结束，进入 run 阶段

### 为什么主 agent 自己生成而不派 plan-generator 子 agent
- plan 生成是「迭代决策」型：reviewer 反馈后主 agent 自己迭代时上一轮思考脉络还在；派子 agent 每轮都要重新读上下文，传递有损
- plan-reviewer 已经是子 agent，「生成 vs 审查」分开持有更合理；生成者再隔一层会让反馈链过长
- run 调度逻辑很简单（按 deps 拓扑跑），主 agent 上下文在 plan 阶段产生的"残留"对调度决策几乎无影响

## run 阶段（派子 agent 并发执行）

### 主 agent 硬规则（仅限 run 阶段）
- ❌ 不读项目源码
- ❌ 不直接修改项目源码（Write 工具只用于 `.cadence/` 下文件）
- ✅ 只调 Agent 工具分发 task
- ✅ 维护 RUN-STATE.md

> 注：plan 阶段主 agent 同样只 Write `.cadence/cycle-<slug>/PLAN.md`，不碰项目源码，规则一致。整个 `/cadence:run` 主 agent 全程不接触项目源码。

### 工具白名单
`Read, Write, Bash, Agent`

**不含 Edit**。PLAN.md 和 RUN-STATE.md 的更新都用 Write 整体重写——文件小、迭代次数有限，整体重写是最简语义。

### 子 agent 硬规则
每个 task-executor 完成时必须：
- 通过 acceptance 校验
- **维护模块 README**：涉及的每个模块（新增或修改）必须更新 README.md；新模块必须创建 README.md
- 自己 `git add` + `git commit`，message 格式：`<task-id>: <title>`
- 返回结构化摘要 `{状态, 改动文件列表, 关键决策, 遗留问题}`

模块 README 是子 agent 的**强制产物**之一，未更新视为未完成。PROJECT.md 由 archive 维护，README 由子 agent 维护，分层职责。

失败判定（任一即失败）：
- 抛错退出
- 摘要中 `状态 != 成功`
- 没产生 commit（除非 task 改动为 0）
- code-reviewer 返回 `needs_fix`（见下文）

### 子 agent 输入（每个 task 的 prompt 模板）

```
你是 cadence 的执行子 agent。本次任务：

[Task]
- id, title, acceptance, context_hint

[必读上下文]
- .cadence/cycle-<slug>/REQUIREMENT.md
- .cadence/cycle-<slug>/DESIGN.md（context_hint 指向章节）
- .cadence/PROJECT.md（如存在）

[可读上下文]
- 项目源码（自由读取定位实现）
- RUN-STATE.md 中已完成 task 的摘要

[规则]
- 所有 acceptance 项目必须客观满足
- 维护涉及模块的 README.md
- 完成后 git add + git commit（message: <task-id>: <title>）
- 返回结构化摘要
- 禁止"为将来扩展先写抽象"、"注释掉的旧实现"、"TODO 占位函数"
```

### code-reviewer 介入

每个 task-executor 完成后，主 agent 调 code-reviewer（Agent 工具）审查刚提交的改动：
- 正确性
- 架构一致性
- README 是否同步
- **无用代码**（critical 项）

返回值：
- `pass` → task 标 ✅
- `needs_fix` + 反馈 → 主 agent 起一个新的 task-executor（fix executor）执行修复，**fix 后不再 review**

### RUN-STATE.md
主 agent 调度过程中**唯一**的状态载体。每次状态变更时**完整重写**（追加容易出错）。

结构：
- 概览（总数、各状态计数、最后更新时间）
- 依赖图（Mermaid）
- 每个 Task 详情：状态、commit hash、改动文件、关键决策、遗留问题、失败原因（如有）

不另外维护 log.md。

### 调度逻辑
1. 读 PLAN.md 构建依赖 DAG
2. 读 RUN-STATE.md（不存在则初始化为全 pending）
3. 找所有 `deps 全部 ✅` 且自身 ≠ ✅ 的 task → 待启动队列
4. **并发上限 3**：队列取最多 3 个起 task-executor
5. 每个 executor 完成 → 串行起 code-reviewer → 按 reviewer 结果决定 ✅ 或起 fix executor
6. 状态变更 → 重写 RUN-STATE.md → 检查解锁 → 队列补位
7. 失败兜底：
   - executor 抛错 / 没 commit / acceptance 不满足 → **立即重试 1 次**（同一 prompt，不附加失败原因）
   - 仍失败 → 标 ❌，依赖者跳过，继续跑能跑的
8. 队列空 + 无运行中 → 跑完，给用户简报

并发上限 3 仅针对 task-executor。code-reviewer / fix executor 跟在 executor 之后串行跑，不抢额度。

### 增量执行（重跑）
重新调用 `/cadence:run` 时：
- ✅ 的 task 跳过
- ❌ 的 task 重新尝试（用户可能已修复阻塞原因）
- 未记录的 task 当新任务跑

### 最终汇总
读 RUN-STATE.md 给用户：
```
本次 cycle 共 N 个 task：
✅ 完成 X 个：T1, T2, ...
❌ 阻塞 Y 个：T5, T7
  - T5: <原因>
  - T7: <原因>

下一步建议：
- 解决阻塞项后重新跑 /cadence:run（增量执行）
- 或全部 ✅ 后跑 /cadence:archive 归档
```

## 关键约束（用户明确表达过的偏好）
- 主 agent 自己生成 plan，不派 plan-generator 子 agent
- 主 agent 全程不读源码、不改源码
- PLAN.md / RUN-STATE.md 用 Write 整体重写，不用 Edit
- plan-reviewer 严格 2 轮，第 2 轮后定稿不再 review
- 单一状态文件 RUN-STATE.md，不要 log.md
- 并发上限 3
- 每个 task 一个 commit
- 失败立即重试，不附加失败原因
- code-reviewer 把"无用代码"列为 critical 项
- 不输出 HTML
