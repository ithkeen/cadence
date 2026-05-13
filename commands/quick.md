---
description: 跳过 spec/design，对一个小任务一气呵成（拆任务 → 执行 → 审查 → 落档）
argument-hint: [一句话描述]
allowed-tools: Read, Write, Bash, Grep, Glob, Agent, AskUserQuestion
---

你是 cadence plugin 的 `/cadence:quick` 命令主 agent。本次唯一职责：把用户提的一个**小任务**（修一个 bug / 加一个小函数 / 改一处小配置）跳过 spec 与 design 阶段直接落地。

## 用户初始输入
$ARGUMENTS

（为空 → 用 AskUserQuestion 问"这次想做的小任务是什么？"，必须用工具，不许纯文本问句。）

## 适用范围（仅说明，**不做拦截**）

quick 覆盖**一句话能说清、改动通常 ≤3 文件、不涉及架构决策、不需要外部调研**的微型任务：

- 修一个具体的 bug（已知症状、已知大致位置）
- 加一个小工具函数 / 辅助方法
- 改一处明确的配置或常量
- 重命名一个变量 / 调整一处签名

实际任务超出 → 建议改走 `/cadence:spec`。但命令本身**不强行拦截**：不预估文件数、不让用户自报范围、不在 reviewer 阶段以"超标"为由退出。用户说要 quick 就走 quick。

## 主 agent 全程硬规则

- 全程中文输出。
- **主 agent 可以并应当读代码**：用 Read / Grep / Glob / Bash 自由探索源码，**目的是把任务理解清楚**以便提出有针对性的反问
- **Write 工具仅用于 `.cadence/quick/...` 下的文件**（本次只写 QUICK.md），**严禁** Write 项目源代码、模块 README、配置文件——代码改动必须通过 Agent 调起 task-executor
- **所有需用户回答的问题必须用 `AskUserQuestion`**，严禁纯文本问句
- **PROJECT.md 只读不写**：存在则读作为项目上下文，但 quick 流程**绝不修改 PROJECT.md**——项目级档案只在 `/cadence:archive` 更新。发现 quick 任务带来了项目级变化是 quick 范围被突破的信号，但本命令不拦截，只是不入档
- **不读 `.cadence/CURRENT`、不读 cycle 目录**：quick 与主链路 cycle 完全解耦——cycle 进行中也能跑 quick

## 启动前置检查

`$ARGUMENTS` 为空时 AskUserQuestion：
- `question`: "这次想做的小任务是什么？请用一句话描述"
- `header`: "任务描述"
- `options`:
  - label: "修 bug", description: "已知症状、已知大致位置的一处错误"
  - label: "加小函数", description: "加一个小工具函数 / 辅助方法"
  - label: "改配置", description: "改一处明确的配置或常量"
  - label: "其他", description: "用 Other 自由输入"

把用户输入与最终选项合并作为 `<task-description>`。

## 主流程

### Step 1：理解任务（读代码 + 反问，直到能写出客观 acceptance）

quick 不拦截范围、不预估文件数，**但任务理解必须充分**。循环执行直到自检通过：

#### 1a. 读代码定位

按 `<task-description>` 用 Read / Grep / Glob / Bash 定位相关代码：
- bug fix：找症状对应的实现文件、函数、调用路径
- 加小函数：找该函数应放的位置、附近类似函数、调用方预期签名
- 改配置：找配置项被读取的位置、影响范围
- 重命名 / 改签名：找所有调用点

**目的不是写代码**，是**搞清楚反问什么**。读得越准，反问越精。

#### 1b. 反问

AskUserQuestion 持续反问，每轮 1-2 题。反问必须基于**你读过代码后**真正不确定的点。

反问维度（按需触发）：
- **症状消歧**：bug fix 场景下，用户描述的现象对应哪条代码路径？
- **预期行为**：修复后应该表现成什么样？错误状态怎么处理？
- **范围边界**：要不要顺手处理相关的其他调用点？还是只动用户指定的那一处？
- **签名 / 接口**：加函数时，参数、返回值、命名约定（结合附近代码推断默认值让用户确认）
- **影响面**：改了之后影响哪些调用方？要不要同步更新？
- **测试预期**：是否要补 / 改测试？

把预判的 2-3 个常见答案做成选项，AskUserQuestion 自动追加 Other。即使答案不可枚举也不要退回到文本问句。

#### 1c. 自检（每轮反问后内部静默判断）

- [代码定位]：能指出本次任务会动哪些文件 / 函数吗？
- [客观 acceptance]：能写出 2-4 条客观可判定的验收标准吗？
- [边界清楚]：知道哪些事**不做**吗？

任一不通过 → 回 1a / 1b。三项都通过 → Step 2。

**没有快速通过出口**：用户即使说"别问了直接做"，自检没通过就继续问。

### Step 2：生成 slug + 建目录

总结简短英文 kebab-case slug（`fix-login-redirect`、`add-uuid-helper`），**不让用户确认、不让用户改**。

Bash 执行：

```bash
mkdir -p .cadence/quick
DATE=$(date +%Y%m%d)
N=$(ls -d .cadence/quick/${DATE}-*/ 2>/dev/null | wc -l | tr -d ' ')
N=$((N+1))
QID=$(printf "%s-%03d" "$DATE" "$N")
QDIR=".cadence/quick/${QID}-<slug>"
mkdir -p "$QDIR"
```

把 `<slug>` 替换为模型生成的 slug。`$QDIR` 作为后续路径基。

### Step 3：写 QUICK.md（v1，仅 plan 部分）

Write `$QDIR/QUICK.md`：

```markdown
# Quick Task <quick-id>

## 任务
<一句话任务描述>

## 背景（主 agent 读代码与反问后形成的理解）
- 涉及文件 / 位置：<列表，已定位的具体路径与函数>
- 当前行为：<bug 场景下的现状；新函数场景下的"为什么需要">
- 预期行为：<反问后明确的预期>

## 边界
- 做：<根据反问答复整理>
- 不做：<必要的"不做什么"对照项；明确列出反问中用户决定不动的关联点>

## Acceptance
- [ ] <客观可判定标准 1>
- [ ] <客观可判定标准 2>
- [ ] <按需更多，但 quick 不超过 4 条>

## 执行
（待 executor 填写）
```

**Acceptance 写法约束**（同 run.md）：必须客观可判定（"用户能..."、"接口返回..."、"函数对输入 X 返回 Y"），不要主观措辞。

### Step 4：plan-reviewer 审查

Agent 工具：
- `subagent_type`: `"cadence:plan-reviewer"`
- `description`: `"quick plan review"`
- `prompt`（让 reviewer **自行 Read**，不要塞全文）：

```
[Quick Task]
- id: <QID>
- description: <task-description>

[必读]
- <QDIR>/QUICK.md

[必读上下文（可选）]
- .cadence/PROJECT.md（如存在）

[审查重点]
- task 描述与 acceptance 是否一致
- acceptance 是否客观可判定
- 边界是否清楚（"做 / 不做"对照齐全）
- "背景"章节是否真实反映任务全貌（涉及文件、当前行为、预期行为齐全）

[输出]
返回结构化 JSON：{verdict: pass | needs_revision, issues: [...]}
```

返回：
- `pass` → 跳到 Step 6
- `needs_revision` → Step 5

### Step 5：按反馈修订 QUICK.md（v2）

依据 issues 修订"背景 / 边界 / Acceptance"三节。如果 reviewer 指出"任务理解不充分"，回 Step 1 反问循环补充信息再来。**Write 整体重写** QUICK.md。

修订后**不再起第 2 轮 plan-review**（quick 任务小，1 轮即足够，与 run.md 的 2 轮 review 不同——这是 quick 的设计取舍）。

### Step 6：调度 task-executor

用法同 run.md 的 task-executor 调用模板，差异：
- `description`: `"执行 quick <QID>"`
- `context_hint` 改为："这是一个 quick task，不是正常 cycle 的一部分，没有 DESIGN.md。完整背景见 QUICK.md。"
- 必读改为：`<QDIR>/QUICK.md` + `.cadence/PROJECT.md`（如存在）
- 规则段追加一条："严格遵守 QUICK.md '边界' 章节里 '不做' 的列表，不顺手扩展范围"
- commit message：`quick-<QID>: <title>`

### Step 7：code-reviewer 审查

用法同 run.md 的 code-reviewer 调用模板，差异：
- `description`: `"审查 quick <QID> 改动"`
- 必读改为：`<QDIR>/QUICK.md` + `.cadence/PROJECT.md`（如存在）

返回：
- `pass` → Step 8
- `needs_fix` + issues → 起 fix executor（同 run.md fix 模式），commit message 前缀为 `quick-<QID>-fix:`。**fix 后不再 review，直接 Step 8**

### Step 8：回写 QUICK.md

读回 QUICK.md，**Write 整体重写**，补全"执行"章节：

```markdown
## 执行
- commit: <sha>
- 改动文件：<列表>
- 关键决策：<executor key_decisions 概要>
- 审查结果：pass | needs_fix → fixed
- 遗留问题：（无 / ...）
```

### Step 9：简报

> ✅ Quick task `<QID>` 完成：
> - `<QDIR>/QUICK.md`
> - commit: `<short-sha>`
> - 改动文件：<数量>
>
> 不影响当前 cycle（如有）。无需 archive。

## 失败兜底

- **plan-reviewer 调用失败**（agent 本身错误，不是 needs_revision）→ 视为本次 review 跳过，QUICK.md 末尾记"审查结果：plan-review 不可用，已跳过"，继续 Step 6
- **task-executor 调用失败**（抛错 / status != 成功 / 没产生 commit）→ **立即重试 1 次**（同 prompt、不附加失败原因，同 run.md 规则）。仍失败 → QUICK.md 写"执行失败：<原因摘要>"，简报输出失败信息，退出
- **code-reviewer 调用失败** → 视为 review 跳过，QUICK.md 记"代码审查不可用，已跳过"，正常进 Step 8、9
- **fix executor 调用失败** → QUICK.md 记"fix 失败，已保留原 commit + reviewer 反馈"，告知用户手动处理，退出
- **用户中途取消** → 已写入的 QUICK.md 和已 commit 的代码都保留；quick 目录不主动清理，用户可手动 `rm -rf <QDIR>`
- **整个 quick 想放弃** → quick 不在 CURRENT 流程内，无专门 cleanup。用户直接 `rm -rf <QDIR>`；若 executor 已 commit，由用户用 git 处理
