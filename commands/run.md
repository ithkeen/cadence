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
- **不与用户对话**（阶段 0 的 slug 询问、阶段 2 的 plan 复用询问、阶段 3 的 hash 不匹配询问除外）
- **依赖关系是硬约束**：调度循环里，一个 step 的所有 `depends_on` 必须全部 success 才能进入派发池
- **并发上限 3**：wave 批调度，同一批最多 3 个 executor 并行

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
- ≤ 4 个 → AskUserQuestion 让用户选（label 取 slug，description 取 mtime 与 SPEC.md 是否存在）
- > 4 个 → 列出全部 cycle（按 mtime 倒序），AskUserQuestion 用前 3 个最近的 + Other 输入框；用户在 Other 里填 slug

**目录不存在 / 不可读 → 一行报错退出**：

```
❌ Cycle 目录不存在：.cadence/cycle-<slug>/
可用 cycle：<ls 结果 或 "无">
```

确认 cycle 目录后继续阶段 1。

---

# 阶段 1：入口检查

检查目标 cycle 目录下的关键文件：

| 检查项 | 不通过的处理 |
|---|---|
| `.cadence/cycle-<slug>/SPEC.md` 存在且非空 | ❌ `SPEC.md 未找到或为空：<path>。请先跑 /cadence:spec` 退出 |
| `.cadence/cycle-<slug>/` 可写（用于 plan.yaml / run-state.yaml） | ❌ `Cycle 目录不可写：<path>` 退出 |
| 当前在 git 仓库内（`git rev-parse --git-dir`） | ❌ `不在 git 仓库内，executor 无法 commit` 退出 |

通过则进入阶段 2。

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
[spec_path]    .cadence/cycle-<slug>/SPEC.md
[output_dir]   .cadence/cycle-<slug>

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
- 选「重新生成」→ `rm -f .cadence/cycle-<slug>/run-state.yaml`，然后按"不存在"分支重调 plan-agent

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
    kind: code              # 与 plan.yaml 一致；冗余存储便于不读 plan 也能看状态
    status: pending         # pending | success | failed
    commit: null            # 成功填短 7 位 hash；其他情况 null
    error: null             # 失败填 executor 返回的失败信号原文；其他 null
    started_at: null        # 每次派发前更新
    finished_at: null       # 返回后更新
  "S02-<slug>":
    ...
```

**关键纪律：**

- 状态枚举只允许 `pending` / `success` / `failed` 三个值——不引入 `running`，wave 同步等待天然不需要中间态
- 每个 wave 结束后整体覆盖写一次 run-state.yaml（Write 全文，简单可靠）
- `plan_hash` 字段一旦写入就锁定本次 run 与 plan.yaml 的版本关系；plan.yaml 改动 → hash 必变 → 走不匹配分支

进入阶段 4。

---

# 阶段 4：调度循环（wave 批调度，≤3 并发）

按以下逻辑循环跑 wave：

## 4.1 计算 ready 池

遍历 `steps[]`，挑出同时满足以下条件的 step：

- `status == pending`
- 所有 `depends_on` 中的 step_id 在 run-state 中 `status == success`（空数组视为依赖满足）

记为本轮 `ready[]`。

**终止条件：**

- `ready` 为空 **且** 没有 step 待处理（所有 step 都 success） → 跳出循环，进入阶段 5 成功收尾
- `ready` 为空 **但**仍有 pending step（说明依赖链被前面的 failed 卡死）→ 这种情况理论上只在前一 wave failed 时出现，已在阶段 4.4 提前跳出；防御性兜底：跳出循环，进入阶段 5 失败收尾

## 4.2 取 batch

从 `ready` 中按 `step_id` 字典序取**前 3 个**作为本轮 `batch[]`（不超 3）。

按字典序取保证可复现：相同 plan + 相同 state 重跑总会产生相同的 wave 切分，方便排查。

## 4.3 并行派发

**在同一条消息内**，对 `batch` 中每个 step 发出一个 Agent 调用（让它们真正并行）。派发前：

- 把每个 step 的 `started_at` 写入 run-state，整体 Write 一次

派发模板（按 `kind` 选 subagent）：

**kind == code：**

```
Agent(
  subagent_type="cadence:code-executor",
  description="Step <step_id>: <goal 前 40 字>",
  prompt="
step_id: \"<step_id>\"
kind: code
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

# 以下为 plan 全局段，视为本步额外硬约束（plan-agent 已写明：注入责任在调度方）
tech_stack:
  - <plan.yaml tech_stack 原样>
global_forbidden:
  - <plan.yaml global_forbidden 原样>
"
)
```

**kind == frontend：**

```
Agent(
  subagent_type="cadence:frontend-executor",
  description="Step <step_id>: <goal 前 40 字>",
  prompt="
step_id: \"<step_id>\"
kind: frontend
goal: <goal>
mode: <plan.yaml step.mode 原样：greenfield 或 inherit>
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
# 仅 mode: greenfield 且 plan.yaml step 中存在时附带；inherit 模式下不要透传
aesthetic_direction: <原样；空字符串也原样写出>
reference_urls:
  - <原样；为空就写 []>
# 仅当 plan.yaml step 中显式给出 dev_server 时附带；否则整段省略，让 executor 用默认值
dev_server:
  start_cmd: ...
  ready_signal: ...
  failure_signal: ...
  url: ...
  timeout_seconds: ...

# 以下为 plan 全局段，视为本步额外硬约束（plan-agent 已写明：注入责任在调度方）
tech_stack:
  - <plan.yaml tech_stack 原样>
global_forbidden:
  - <plan.yaml global_forbidden 原样>
"
)
```

**注入要点：**

- step YAML 块：把 plan.yaml 中该 step 的字段原样照搬，不裁剪不改写
- `tech_stack` / `global_forbidden`：原样从 plan.yaml 顶层复制；plan-agent 文档明确："注入责任在调度方"
- frontend step 的 `mode` 必透传（executor 把 `mode` 当必填，缺即 failed）；`aesthetic_direction` / `reference_urls` 仅 greenfield 时透传，inherit 模式下不要带；`dev_server` 仅当 plan 显式给出时透传，否则省略让 executor 走默认值
- 不向 executor 透露 cycle slug / SPEC.md 路径 / 其他 step（executor 只看自己的契约）

## 4.4 解析返回 + 更新 state

每个 executor 简报只有两种形态（见 executor 文档输出契约）：

```
✅ Step <step_id>: <commit 短 7 位 hash>
❌ Step <step_id>: failed — <失败类型 + 关键信号>
```

逐个解析：

- 成功 → `state[step_id] = { status: success, commit: <hash>, finished_at: <now> }`
- 失败 → `state[step_id] = { status: failed, error: <整行简报的 "— " 后面部分>, finished_at: <now> }`
- 格式无法识别（既不是 ✅ 也不是 ❌ 开头）→ 视为 failed，error 写：`executor 返回格式异常: <截前 200 字>`

整体 Write 一次 run-state.yaml（更新 last_updated_at）。

**任一 step 在本 wave 中标为 failed → 立即跳出循环**，进入阶段 5 失败收尾。同 wave 中其他 success 的 step 保留 success 状态（已经 commit，不回滚）。

## 4.5 进入下一 wave

无 failed → 回到 4.1，N += 1。

---

# 阶段 5：收尾

## 5.1 全部 success：先 review 再收尾

### 5.1.1 调 code-reviewer 做 cycle 末整体 review

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

**返回处理：**

把 reviewer 返回的完整 Markdown 报告 Write 到 `.cadence/cycle-<slug>/review.md`（整体覆盖写）。

- 成功（返回以 `# Code Review:` 开头的完整报告） → 解析报告「## 1. 摘要」中的 `N 项 findings（X CRITICAL, Y MAJOR, Z MINOR）` 行，把这三组数字与 review.md 路径带入 5.1.2 收尾文案
- 报告体内是 `No issues at the required confidence threshold.` → 同样落档 review.md，收尾文案以"无达阈值 finding"表述
- 返回以 `❌ Review 未成功：` 或 `⚠️ no changes in scope=` 开头 → **不中断收尾**，把这一行原样作为 review 状态写进收尾文案、**不写 review.md**
- reviewer 子 agent 调用本身报错（subagent 不可用 / 沙箱拒绝） → 同上，收尾文案标注 "review 未跑成：<错误信号>"，不写 review.md

### 5.1.2 收尾输出

按 step_id 字典序输出已完成列表：

```
✅ Cycle cycle-<slug> 已全部完成

共 <N> 个 step（code: <n_code>，frontend: <n_frontend>），全部 commit 已落地。

提交清单（按 step 顺序）：
- S01-<slug>: <commit>
- S02-<slug>: <commit>
...

Code review（advisory）：
- 报告：.cadence/cycle-<slug>/review.md
- 结论：<X CRITICAL, Y MAJOR, Z MINOR> ｜ 或 "无达阈值 finding" ｜ 或 "review 未跑成：<原文一行>"

下一步：
- 复核 review.md 中的 findings（若有），按需修复
- 复核 git log 与 SPEC.md「验证标准」
- 按 SPEC 的验证标准逐条做最终验收
```

**review 状态行的三态文案：**

- 有 finding（任一计数 > 0） → `结论：1 CRITICAL, 2 MAJOR, 0 MINOR`（按报告原值填）
- 无达阈值 finding → `结论：无达阈值 finding（reviewer 已确认）`
- review 未跑成 → 省略「报告」行，「结论」行写 `结论：review 未跑成：<reviewer 返回原文一行>`

## 5.2 失败中止

```
❌ Cycle cycle-<slug> 中止于 Step <failed_step_id>

失败原因（executor 简报原文）：
<error 内容>

进度：
- 已完成 <X> / <总数 N>
- 本次 wave 同批 success 的 step（已 commit）：S0a, S0b
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

| 情形 | 处理 |
|---|---|
| `$ARGUMENTS` 含非法字符（`/` 之类） | 一行报错退出：`❌ 非法的 cycle slug：<原始参数>` |
| `.cadence/` 不存在 | 一行报错退出：`❌ 项目未初始化 cadence。请先在 /cadence:spec` |
| `plan-agent` 返回 bail | 把 bail 简报原样转给用户，run 命令退出，不写 run-state.yaml |
| plan.yaml 已存在但内容残缺（缺 `steps:` 段 / 无法 YAML 解析） | 一行报错退出：`❌ plan.yaml 解析失败：<关键信号>。建议在阶段 2 选「重新生成」` |
| executor 调用本身报错（subagent 不可用 / 沙箱拒绝） | 视为 failed，error 字段写：`executor 调用失败: <错误信号>`；走失败收尾 |
| `code-reviewer` 调用失败 / 返回错误简报 | **不阻塞收尾**：不写 review.md，把 reviewer 返回原文一行写进收尾文案的 review 状态行 |
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
- git commits — executor 产（每个 success step 一个 commit）

</产物>

<成功标准>

- [ ] 阶段 0 能在无参 / 有参 / 错参三种入口下都给出明确处理
- [ ] 阶段 2 plan.yaml 存在时必 ask user 复用 vs 重新生成，不擅自决定
- [ ] 阶段 3 plan_hash 不匹配必 ask user，不擅自重置状态
- [ ] 阶段 4 严格遵守：所有 depends_on 都 success 才能进 ready；同 wave ≤ 3 并发；任一 failed 立即跳出
- [ ] 阶段 5 成功 / 失败两条收尾路径都输出完整进度
- [ ] 全 success 收尾路径：先调 `code-reviewer`（advisory，scope=branch，focus 含 SPEC.md 路径与提交清单），落档 review.md，结论摘要写进收尾文案；reviewer 失败不阻塞收尾
- [ ] 每个 wave 结束都把 run-state.yaml 整体覆盖写一次（增量持久化）
- [ ] executor 简报原样转发，不翻译不改写
- [ ] 不动 executor 工作树残留、不动用户 git 历史

</成功标准>
