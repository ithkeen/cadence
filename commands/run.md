---
description: 串联 plan-agent 与 executor，按 plan.yaml 调度跑完整个 cycle
allowed-tools: Read, Write, Bash, Agent, AskUserQuestion
argument-hint: "[cycle-slug]"
---

<命令目的>
spec 阶段已经把「做什么 / 技术约定 / 验证标准」钉死，run 命令只负责一件事：
**把 SPEC 跑完**——拿 cycle slug 进来，自动产 plan、按依赖调度 executor、维护状态、出事即停。

run 命令是**调度器**，不是 implementer：

- 不读源码、不评估 SPEC / plan 合理性、不跟 executor 谈细节
- 不写业务代码、不动 executor 的工作树状态
- 任一 step 失败 → 立即停整个 run，把失败信号原样上报，让用户去修

下游 executor（code-executor / frontend-executor）按 plan.yaml 中每个 step 的 `kind` 字段派发。
</命令目的>

<全局规则>

- **输出语言**：全程中文。executor 简报原样转发（不翻译、不改写）
- **失败即停**：任一 step 返回 failed → 不再派发未启动的 step，进入失败收尾
- **状态文件归 run 独占**：`.cadence/cycle-<slug>/run-state.yaml` 只由本命令读写，executor 不感知
- **不动工作树残留**：executor 失败时改动留在工作树，run 命令不 reset / 不清理 / 不 stash
- **默认不与用户对话**：仅在主流程明确指定的几个询问点开口
- **依赖关系是硬约束**：调度循环里，一个 step 的所有 `depends_on` 必须全部 success 才能进入派发池
- **串行调度**：一次只派发 1 个 executor，等返回后再派发下一个

</全局规则>

<主流程>

# 阶段 0：解析参数 + 定位 cycle

参数 `$ARGUMENTS` 解析规则：

1. 去掉两侧空白；剥掉可能的 `cycle-` 前缀，得到 `<slug>`
2. 拼出目标目录：`.cadence/cycle-<slug>/`

**无参数处理：**

```bash
ls -dt .cadence/cycle-*/ 2>/dev/null
```

- 0 个 → 一行报错退出：`❌ 未找到任何 cycle 目录。请先跑 /cadence:spec 创建 cycle`
- 1 个 → 直接采纳，无需询问
- 2-4 个 → AskUserQuestion 让用户选（label 取 slug，description 取 mtime 与 SPEC.md 是否存在）
- \> 4 个 → 列出全部 cycle（按 mtime 倒序），AskUserQuestion 用前 3 个最近的 + Other 输入框；用户在 Other 里填 slug

**目录不存在 / 不可读 → 一行报错退出**：

```
❌ Cycle 目录不存在：.cadence/cycle-<slug>/
可用 cycle：<ls 结果 或 "无">
```

确认 cycle 目录后继续阶段 1。

---

# 阶段 1：入口检查 + 分支准备

## 1.1 关键文件检查

| 检查项 | 不通过的处理 |
|---|---|
| `.cadence/cycle-<slug>/SPEC.md` 存在且非空 | ❌ `SPEC.md 未找到或为空：<path>。请先跑 /cadence:spec` 退出 |
| `.cadence/cycle-<slug>/` 可写（用于落 plan.yaml / run-state.yaml） | ❌ `Cycle 目录不可写：<path>` 退出 |
| 当前在 git 仓库内（`git rev-parse --git-dir`） | ❌ `不在 git 仓库内，executor 无法 commit` 退出 |
| 工作树干净（`git status --porcelain` 输出为空） | ❌ `工作树有未提交改动，先 stash 或 commit 再跑：<git status -s 输出前 5 行>` 退出 |

## 1.2 分支准备

避免直接在 main / master 上落 cycle commits（reviewer 的 `git diff --merge-base origin/HEAD` 会失效，且团队主分支不该堆 cycle 半成品）。

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)
target_branch="cadence/cycle-<slug>"
```

按以下三态处理：

| 情况 | 处理 |
|---|---|
| `current_branch` 不在 {`main`, `master`} 之列 | 直接沿用当前分支，不切；输出一行：`📌 在分支 <current_branch> 上跑 cycle` |
| `current_branch` 是 `main` / `master`，且 `target_branch` 已存在（本地 ref）| `git checkout <target_branch>`；输出：`📌 切到已存在的 cycle 分支 <target_branch>`（续跑场景） |
| `current_branch` 是 `main` / `master`，且 `target_branch` 不存在 | `git checkout -b <target_branch>`；输出：`🌿 已新建并切到 cycle 分支 <target_branch>` |

**纪律：**

- 成功 / 失败收尾**都不切回原分支**——cycle 成果留在 cycle 分支上，merge / cherry-pick / 丢弃由用户决定
- checkout 失败 → 一行报错退出：`❌ 切分支失败：<git 错误信号>`，不重试、不强切

进入阶段 2。

---

# 阶段 2：处理 plan.yaml

```bash
test -f .cadence/cycle-<slug>/plan.yaml
```

**不存在 → 直接调 plan-agent：**

```
Agent(
  subagent_type="cadence:plan-agent",
  description="为 cycle-<slug> 生成 plan.yaml",
  prompt="
spec_path: .cadence/cycle-<slug>/SPEC.md
output_dir: .cadence/cycle-<slug>

请按 plan-agent 系统约定，把 SPEC.md 切成可执行的 step 序列，落档为 plan.yaml。
"
)
```

- 成功（plan.yaml 已写）→ 进入阶段 3
- bail（plan-agent 返回 `❌ Plan 未生成 ...`）→ **把 bail 简报原样转给用户**，run 命令退出（不写 run-state.yaml）

**已存在 → AskUserQuestion：**

```
AskUserQuestion([
  {
    header: "plan 处理",
    question: "plan.yaml 已存在，怎么处理？",
    multiSelect: false,
    options: [
      { label: "复用现有 plan", description: "保留 plan.yaml 与 run-state.yaml（若有），按当前 state 续跑" },
      { label: "重新生成",       description: "重调 plan-agent 覆盖 plan.yaml，并清掉 run-state.yaml 从头跑" }
    ]
  }
])
```

- 选「复用现有 plan」→ 进入阶段 3
- 选「重新生成」→ `rm -f .cadence/cycle-<slug>/run-state.yaml`，然后按"不存在"分支重调 plan-agent；**若 plan-agent bail，旧 plan.yaml 仍在但 run-state 已删——不恢复，把 bail 简报原样转给用户退出**

---

# 阶段 3：加载 / 初始化 run-state

**计算 plan.yaml 内容哈希**（git 必装，跨平台稳）：

```bash
git hash-object .cadence/cycle-<slug>/plan.yaml | cut -c1-12
```

记为 `<plan_hash>`。

**Read plan.yaml 全文**，在内存中解析出：

- 顶层：`tech_stack[]` / `global_forbidden[]` / `meta`
- `steps[]`：每个 step 的 `step_id` / `kind` / `goal` / `depends_on[]` / `spec_refs[]` / `verify[]` / `acceptance` / `forbidden[]`，外加 `kind: frontend` step 的 `mode` / `aesthetic_direction` / `reference_urls` / `dev_server`（若有）

**Run-state 处理三态：**

| 情况 | 处理 |
|---|---|
| `run-state.yaml` 不存在 | 初始化：所有 step `status: pending`，写入 plan_hash / started_at / 各 step kind |
| 存在 + `plan_hash` 匹配 | 续跑：保留 `success` 的 step；`failed` 与 `pending` 全部回置为 `pending`，准备重新派发 |
| 存在 + `plan_hash` 不匹配 | AskUserQuestion：`保留 state 复核` / `重置 state 按新 plan 跑`；选保留 → 退出让用户排查；选重置 → 重新初始化 state |

**Run-state schema（写入磁盘的精确格式）：**

```yaml
cycle: <slug>
plan_path: .cadence/cycle-<slug>/plan.yaml
plan_hash: <git hash-object 前 12 位>
started_at: <ISO8601 UTC>
last_updated_at: <ISO8601 UTC>
steps:
  "S01-<slug>":
    kind: code              # 便于人工 cat run-state 一眼看类型
    status: pending         # pending | success | failed
    commit: null            # 成功填短 7 位 hash；其他情况 null
    error: null             # 失败填 executor 返回的失败信号原文；其他 null
    started_at: null        # 每次派发前更新
    finished_at: null       # 返回后更新
  "S02-<slug>":
    ...
```

**关键纪律：**

- 状态枚举只允许 `pending` / `success` / `failed` 三个值——不引入 `running`，串行同步等待天然不需要中间态
- 每个 step 结束后整体覆盖写一次 run-state.yaml（Write 全文，简单可靠）
- `plan_hash` 字段一旦写入就锁定本次 run 与 plan.yaml 的版本关系；plan.yaml 改动 → hash 必变 → 走不匹配分支

进入阶段 4。

---

# 阶段 4：调度循环（串行）

## 4.1 计算 ready 池

遍历 `steps[]`，挑出同时满足以下条件的 step：

- `status == pending`
- 所有 `depends_on` 中的 step_id 在 run-state 中 `status == success`（空数组视为依赖满足）

记为本轮 `ready[]`。

**终止条件：**

- 所有 step 都 success → 跳出循环，进入阶段 5 成功收尾
- `ready` 为空但仍有 pending → 跳出循环，进入阶段 5 失败收尾

## 4.2 取本轮 step

从 `ready` 中按 `step_id` 字典序取**第一个**作为本轮 `current_step`。

按字典序取保证可复现：相同 plan + 相同 state 重跑总会产生相同的调度顺序，方便排查。

## 4.3 派发

对 `current_step` 发出一次 Agent 调用，**同步等待返回**。派发前：

- 把 `current_step` 的 `started_at` 写入 run-state，整体 Write 一次

**subagent 选型：** `kind: code` → `cadence:code-executor`；`kind: frontend` → `cadence:frontend-executor`。

**注入字段（所有 step 公共）：**

```yaml
step_id: "<step_id>"
kind: <code | frontend>
goal: <goal>
depends_on: <depends_on YAML 数组>
spec_refs:
  - ...
verify:
  - cmd: ...
    must_pass: true
acceptance: |
  - ...
forbidden:
  - ...

# plan 全局段，视为本步额外硬约束（plan-agent 已写明：注入责任在调度方）
tech_stack:
  - <plan.yaml tech_stack 原样>
global_forbidden:
  - <plan.yaml global_forbidden 原样>
```

**frontend step 额外字段（按下表透传）：**

| 字段 | 透传条件 | 说明 |
|---|---|---|
| `mode` | 必透传 | frontend-executor 把 mode 当必填，缺即 failed |
| `aesthetic_direction` | 仅 `mode: greenfield` 时透传 | inherit 模式下不要带；空字符串原样写出 |
| `reference_urls` | 仅 `mode: greenfield` 时透传 | inherit 模式下不要带；为空就写 `[]` |
| `dev_server` | 仅 plan 显式给出时透传 | 否则整段省略，让 executor 用默认值 |

**注入要点：**

- step YAML 块：把 plan.yaml 中该 step 的字段原样照搬，不裁剪不改写
- `tech_stack` / `global_forbidden`：原样从 plan.yaml 顶层复制
- 不向 executor 透露 cycle slug / SPEC.md 路径 / 其他 step（executor 只看自己的契约）

## 4.4 解析返回 + 更新 state

executor 简报只有两种形态（见 executor 文档输出契约）：

```
✅ Step <step_id>: <commit 短 7 位 hash>
❌ Step <step_id>: failed — <失败类型 + 关键信号>
```

解析：

- 成功 → `state[current_step] = { status: success, commit: <hash>, finished_at: <now> }`
- 失败 → `state[current_step] = { status: failed, error: <整行简报的 "— " 后面部分>, finished_at: <now> }`
- 格式无法识别（既不是 ✅ 也不是 ❌ 开头）→ 视为 failed，error 写：`executor 返回格式异常: <截前 200 字>`

整体 Write 一次 run-state.yaml（更新 last_updated_at）。

**current_step 标为 failed → 立即跳出循环**，进入阶段 5 失败收尾。

## 4.5 进入下一轮

无 failed → 回到 4.1。

---

# 阶段 5：收尾

## 5.1 全部 success：先 review 再收尾

### 5.1.1 调 code-reviewer + 落档 review.md

所有 step success 后、输出收尾文案前，调一次 `code-reviewer` 对本 cycle 整体改动做 advisory review。**review 是 advisory 性质：不论结果如何都不改 cycle 成功结论、不改任何 step status、不阻塞收尾**。

```
Agent(
  subagent_type="cadence:code-reviewer",
  description="cycle-<slug> 全 step 完成后的整体 review",
  prompt="
scope: branch
focus: |
  对照 .cadence/cycle-<slug>/SPEC.md 检查本 cycle 的实现是否对齐「做什么」与「验证标准」、是否漏项、是否越界（实现了 SPEC 没要求的事）、是否违反 SPEC「## 技术栈」与「## 不做什么」锁定的约定。

  本 cycle 共 <N> 个 step（code: <n_code>，frontend: <n_frontend>），每个 step 一个 commit，commit message 末尾带 `Step: <step_id>` 标记。提交清单：
  - S01-<slug>: <commit_hash>
  - S02-<slug>: <commit_hash>
  ...

  重点聚焦本 cycle 引入的改动；diff 中若包含本 cycle 之外的既有代码，按 reviewer 默认纪律（diff 外的 pre-existing issues 不在范围内）跳过。
"
)
```

**注入要点：**

- `scope` 固定 `branch`（reviewer 会跑 `git diff --merge-base origin/HEAD`，覆盖本 cycle 落地的所有 commits）
- `focus` 必须把 SPEC.md 路径与提交清单都写出来，让 reviewer 拿到对照标准与 commit 标记
- 不向 reviewer 透露 plan.yaml / run-state.yaml（reviewer 不读 plan，靠 SPEC + commit 标记定位）

**返回归一为二态（供 5.1.2 / 5.1.3 消费）：**

| 形态 | 落档 review.md | review 状态 |
|---|---|---|
| 完整报告（以 `# Code Review:` 开头） | 是 | `reviewed_ok`，附 `(X CRITICAL, Y MAJOR, Z MINOR)` |
| 报告体内 `No issues at the required confidence threshold.` | 是 | `reviewed_ok`，零 finding |
| 返回以 `❌ Review 未成功：` 或 `⚠️ no changes in scope=` 开头 | 否 | `review_skipped`，附原文一行 |
| Agent 调用本身报错（subagent 不可用 / 沙箱拒绝） | 否 | `review_skipped`，附错误信号 |

review.md 落档且至少含 1 条 CRITICAL 或 MAJOR finding → 进 5.1.2 自动修复；否则跳到 5.1.3 收尾。

### 5.1.2 自动修复 CRITICAL + MAJOR findings

**触发条件**：5.1.1 落档了 review.md，且报告中至少有 1 条 severity 为 CRITICAL 或 MAJOR 的 finding。任一条件不满足直接跳到 5.1.3。

**纪律：**

- **一轮即停**：fix 跑完不再 review、不再循环；剩余问题留给下个 cycle
- **finding 全文注入**：派发 prompt 必须包含每条 CRITICAL/MAJOR finding 的完整内容（path / severity / 类别 / 现象 / 触发路径 / 建议修法），让 executor 拿到语义上下文，避免依赖 file:line 的机械坐标在多次修改中漂移

**派发：**

从 review.md 解析出所有 severity ∈ {CRITICAL, MAJOR} 的 finding 完整片段，按 F<n> 顺序拼接。从 plan.yaml 顶层提取 `tech_stack` / `global_forbidden` 与所有 step 的 `verify` cmd（去重后作为 fix step 的回归测试集合）。统一派 `code-executor`：fix 任务多为后端式 patch（边界检查、错误处理、scope 偏离修正、补测试），其工具集可覆盖；涉及前端文件的 finding 由 executor 用 Edit 直接改，浏览器自验留给下个 cycle。

```
Agent(
  subagent_type="cadence:code-executor",
  description="cycle-<slug> review findings 自动修复",
  prompt="
step_id: \"FIX-<slug>\"
kind: code
goal: 按 review.md 修复 CRITICAL + MAJOR findings；不引入新功能、不动 SPEC 未要求的事
depends_on: []
spec_refs:
  - \"review:.cadence/cycle-<slug>/review.md\"
  - \"spec:.cadence/cycle-<slug>/SPEC.md\"
verify:
  # 从 plan.yaml 抽取的所有 step verify cmd 去重后逐条注入；保证修复不让既有测试退化
  - cmd: <plan.yaml 中第 1 条 verify.cmd>
    must_pass: true
  - cmd: <plan.yaml 中第 2 条 verify.cmd>
    must_pass: true
  # ... 全部去重 verify cmd
acceptance: |
  - review.md 中下列 finding 的「建议修法」已落地（每条 finding 的现象在改动后不再可触发）
  - 既有测试套件全部通过（verify 段 cmd 全部 exit 0）
  - 未引入 review.md 未要求的新功能 / 新文件 / 新依赖
forbidden:
  - 引入新依赖
  - 修改 SPEC.md 未列出的功能

# 注入责任在调度方
tech_stack:
  - <plan.yaml tech_stack 原样>
global_forbidden:
  - <plan.yaml global_forbidden 原样>

# 待修复 findings（review.md 中 severity ∈ {CRITICAL, MAJOR} 的全部 finding 原文片段）
findings_to_fix: |
  ### F1. <标题>
  - 路径：<file:line>
  - Severity：CRITICAL | MAJOR
  - Confidence：N/10
  - 类别：<类别>
  - 现象：<原文>
  - 触发路径：<原文>
  - 建议修法：<原文>

  ### F2. ...
"
)
```

**注入要点：**

- 不向 executor 透露 cycle slug（除了 step_id 里的 slug 本身）/ run-state.yaml / 其他 step 历史
- `verify` 段必须从 plan.yaml 各 step 的 verify cmd 去重合并而来，作为"不退化"的回归基线
- `findings_to_fix` 用 review.md 原文片段，**不要重写或精简**——reviewer 的措辞是 confidence ≥ 7 的产物，executor 拿原文最稳

**commit 行为**：

executor 走 code-executor 既定的 commit 流程，唯一差别在 commit message：

- 标题：`fix(review): cycle-<slug> CRITICAL/MAJOR findings`
- 正文行：
  - `Step: FIX-<slug>`
  - `Review: F1, F2, ...`（命中的 finding 编号列表）

**返回归一为三态（供 5.1.3 消费）：**

| 形态 | auto-fix 状态 |
|---|---|
| ✅ 成功 | `fix_ok`，附 `commit 短 hash` 与命中 finding 列表 |
| ❌ 失败（继承 code-executor 输出契约） | `fix_failed`，附整行简报原文；不退回 cycle success 结论；未 commit 改动按其既定行为留在工作树 |
| Agent 调用本身报错 | `fix_errored`，附错误信号 |

进入 5.1.3。

### 5.1.3 收尾输出

按 step_id 字典序输出已完成列表：

```
✅ Cycle cycle-<slug> 已全部完成

共 <N> 个 step（code: <n_code>，frontend: <n_frontend>），全部 commit 已落地。

提交清单（按 step 顺序）：
- S01-<slug>: <commit>
- S02-<slug>: <commit>
...

Code review（advisory）：
<review 段，按下方规则填>

<auto-fix 段，按下方规则填>

下一步：
- 复核 git log（含 fix commit 若有）与 SPEC.md「验证标准」
- 复核 review.md 中未自动修的 MINOR finding（若有），按需人工处理
- 按 SPEC 的验证标准逐条做最终验收
```

**review 段：**

```
if review 状态 == reviewed_ok 且 (CRITICAL+MAJOR+MINOR > 0):
  - 报告：.cadence/cycle-<slug>/review.md
  - 结论：X CRITICAL, Y MAJOR, Z MINOR
elif review 状态 == reviewed_ok 且 全 0:
  - 报告：.cadence/cycle-<slug>/review.md
  - 结论：无达阈值 finding（reviewer 已确认）
else:  # review_skipped
  - 结论：review 未跑成：<原文一行>
```

**auto-fix 段：**

```
if 5.1.2 未触发:
  省略整段
elif fix_ok:
  Auto-fix：
  - 已自动修复 <N> 项 CRITICAL+MAJOR findings：<F1, F2, ...> | commit: <短 hash>
elif fix_failed:
  Auto-fix：
  - 自动修复未成功：<executor 失败简报原文一行>；改动留工作树，请人工复核或 git restore 后重试
elif fix_errored:
  Auto-fix：
  - 自动修复未跑成：<错误信号>
```

## 5.2 失败中止

```
❌ Cycle cycle-<slug> 中止于 Step <failed_step_id>

失败原因（executor 简报原文）：
<error 内容>

进度：
- 已完成 <X> / <总数 N>
- 失败 step：<failed_step_id>
- 未派发 / 被依赖卡住的 step：S0c, S0d, ...

工作树状态：
- executor 失败时未 commit 的改动留在工作树（按 executor 既定行为）
- 请用 `git status` / `git diff` 复核

下一步：
- 修复失败 step 的根因（改代码 / 改测试 / 改 SPEC + 重新 plan）
- 再次跑 `/cadence:run <slug>` 会自动从 <failed_step_id> 续跑，已 success 的 step 跳过
```

## 5.3 状态文件最终落档

无论成功 / 失败，最后再 Write 一次 run-state.yaml（last_updated_at 取最终时间）。

</主流程>

<异常处理>

主流程未覆盖的边角情况：

| 情形 | 处理 |
|---|---|
| `$ARGUMENTS` 含非法字符（`/` 之类） | 一行报错退出：`❌ 非法的 cycle slug：<原始参数>` |
| `.cadence/` 不存在 | 一行报错退出：`❌ 项目未初始化 cadence。请先跑 /cadence:spec` |
| plan.yaml 已存在但内容残缺（缺 `steps:` 段 / 无法 YAML 解析） | 一行报错退出：`❌ plan.yaml 解析失败：<关键信号>。建议在阶段 2 选「重新生成」` |
| executor 调用本身报错（subagent 不可用 / 沙箱拒绝） | 视为 failed，error 字段写：`executor 调用失败: <错误信号>`；走失败收尾 |
| run-state.yaml 写失败 | 一行报错退出：`❌ 写 run-state.yaml 失败：<原因>` |
| 用户手动中断（Ctrl+C） | 已完成的 step 已 commit + state 已落档；下次 run 自动从 pending 处继续 |

**绝不做的事：**

- 不 `git reset` / 不 `git stash` / 不 `rm` 工作树文件
- 不 `--no-verify` / 不 `--force` / 不 push
- 不替用户决定怎么修失败 step（只上报，不动手）
- 不在 run-state 里塞 executor 不该看到的字段（保持简单）

</异常处理>

<产物>

- `.cadence/cycle-<slug>/plan.yaml` — plan-agent 产（run 不动其内容）
- `.cadence/cycle-<slug>/run-state.yaml` — 本命令独占维护
- `.cadence/cycle-<slug>/review.md` — code-reviewer 产（仅全 success 收尾路径产出；reviewer 调失败则不产出）
- git commits — executor 产（每个 success step 一个 commit；含 5.1.2 自动修复时额外的 1 个 fix commit）

</产物>
