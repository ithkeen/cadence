# 子 Agent 设计（已定稿）

## 总览
plugin 涉及 **4 种**子 agent：

| 名字 | 出现在 | 触发条件 | 单 cycle 调用次数 |
|---|---|---|---|
| `research-agent` | `/cadence:spec`, `/cadence:design` | 主 agent 识别"信息缺口" + 用户确认 | 0~N（按需） |
| `plan-reviewer` | `/cadence:run`（plan 阶段） | 主 agent 拆完 plan | 严格 2 次 |
| `task-executor` | `/cadence:run` | 每个 task 启动；review 不过时再起一次（fix） | 每 task 1~2 次 + 失败重试 1 次 |
| `code-reviewer` | `/cadence:run` | 每个 task-executor 完成后 | 每 task 1 次 |

**不分前后端 / DBA 等角色**，executor 是通用型，靠 prompt 注入区分。

---

## 1. research-agent

### 定位
按需的外部知识调研。**不新增命令**，由 spec / design 主 agent 在识别到"信息缺口"时建议、用户确认后调起。

### 触发条件（主 agent 内置识别逻辑）

**spec 阶段**：
- 涉及陌生业务领域
- 涉及合规 / 法规 / 标准
- 用户希望参考竞品但未给具体参考

**design 阶段**：
- 涉及主 agent 不熟悉的技术栈
- 涉及多方案对比但主 agent 没把握说清取舍
- 涉及版本敏感的 API
- 涉及外部协议 / 集成

**不触发**：
- 在已有代码上加功能
- 单纯新增一个函数
- 用户已把方案说清楚
- 常识性信息

### 询问形态
```
我注意到这次涉及 <xxx>，我对它没有十足把握。
要不要我先调研一下：<topic 1>、<topic 2>？
（继续 / 跳过）
```
用户同意才调用，否则跳过继续 spec/design。

### 输入
- 调研主题（topic）
- 当前 cycle 已有上下文（REQUIREMENT/DESIGN/PROJECT 如有）—— 仅供理解 why，不要解决项目问题

### 调研要求
- 工具：WebSearch / WebFetch / Context7
- 优先官方文档、近 1 年内容
- 涉及版本明确版本号
- 涉及取舍给对比表
- 涉及代码给可执行最小示例
- 全中文输出

### 输出
路径：`.cadence/cycle-<slug>/research/<topic-slug>.md`

格式：
1. 一句话结论
2. 关键事实清单
3. 取舍对比（如适用）
4. 代码示例（如适用）
5. 引用来源

### 失败处理
联网失败 / 工具异常 → 不产出文件，视为本次调研未发生。主 agent 告知用户："调研未成功，跳过，继续。" 不阻塞主流程。

### 边界
- 只读外部信息 + 只写 research/<topic-slug>.md
- 不读项目源码
- 不修改其他 .cadence/ 文件

### 与其他阶段的关系
- spec / design 后续追问中将 research/ 内容作为上下文
- plan / run 阶段**不读** research/（决策已定，run 用 context7 查文档）
- archive 时 research/ 跟随 cycle 留档，不进 PROJECT.md

---

## 2. plan-reviewer

### 定位
质量门，挑 plan 的毛病。

### 调用流
```
拆 plan → review #1 → 主 agent 修订 → review #2 → 主 agent 按建议**最终修订一次**（不再 review）→ 写 PLAN.md
```
永远 2 轮 review，第二轮后直接定稿。

### 输入
- 完整 cycle 上下文（REQUIREMENT + DESIGN + PROJECT 全文）
- 待审 plan
- 审查清单：依赖成环 / 粒度（3h / 30 文件）/ 验收客观性 / 设计覆盖 / 隐性 task 遗漏

### 输出
```json
{
  "verdict": "pass" | "needs_revision",
  "issues": [{"task_id": "T3", "type": "...", "problem": "...", "suggestion": "..."}]
}
```

### 边界
只读、不改 plan、不调用编辑工具、不与用户对话。

---

## 3. task-executor

### 定位
实际写代码、改文件、维护 README、commit 的人。

### 输入
- 单个 task 描述（id / title / acceptance / context_hint）
- 必读：REQUIREMENT.md、DESIGN.md（context_hint 章节）、PROJECT.md（如有）
- 可读：项目源码（自由读取）
- **不传**其他 task 的摘要（依赖产物已在代码和 README 里）

### 硬规则
1. 完成所有 acceptance 项
2. 涉及模块必须更新 README.md；新模块必须创建 README.md
3. **不得提交无用代码** —— 新增/修改代码必须被实际调用或在 acceptance 范围内：
   - 不要为将来扩展先写抽象接口
   - 不要保留注释掉的旧实现
   - 不要留 TODO 占位函数
4. git add + git commit，message 格式：`<task-id>: <title>`
5. 返回结构化摘要

### 输出
```json
{
  "status": "success" | "failed",
  "files_changed": ["path1", ...],
  "modules_touched": ["api/", "service/"],
  "commit": "<git sha>",
  "key_decisions": ["选 X 因为 Y"],
  "notes": "遗留 / 警告"
}
```

### 边界
- 自由读源码、自由编辑代码
- **不修改 .cadence/ 下任何文件**（PLAN/RUN-STATE/PROJECT 是主 agent 维护的）
- 不与用户对话（失败也不问）
- 不读其他 task 产物，避免上下文爆炸

### 失败处理（主 agent）
- 抛错 / 没 commit / acceptance 没满足 → 立即重试 1 次（同一 prompt，不附加失败原因）
- 仍失败 → 标 ❌，依赖者跳过

---

## 4. code-reviewer

### 定位
task 级代码审查。每个 task-executor 完成后**自动**触发。

### 调用流
```
executor 完成 → code-reviewer 审 →
  ├─ pass → task ✅，调度推进
  └─ needs_fix → 主 agent 起 fix executor 修 → task ✅（不再 review）
```
单 task 最多 1 次 review + 1 次 fix。

### 输入
- Task 上下文（id / title / acceptance）
- 本次改动（commit sha / files_changed / executor 的 key_decisions）
- 必读：REQUIREMENT、DESIGN（context_hint 章节）、PROJECT
- 改动文件最新内容、git diff

### 审查维度
1. **正确性**：实现是否真的满足 acceptance？有无明显 bug？
2. **架构一致性**：是否符合 DESIGN？是否破坏 PROJECT.md 约定？
3. **README 同步**：被改模块 README 是否真的更新、是否准确？
4. **明显代码问题**：硬编码、未处理错误、安全坑、明显性能问题
5. **测试**：关键路径是否有测试？
6. **无用代码（critical）**：所有引入代码必须实际被用到，包括但不限于：
   - 未被引用的函数 / 类 / 变量 / 常量
   - 未被使用的 import / require
   - 注释掉的代码块
   - 永远走不到的分支
   - 创建但从未使用的文件
   - 定义但从未调用的接口
   一旦发现，severity 必须标 critical。

### 不审查
- 风格细节、命名喜好
- 性能微优化
- "可以更好"但当前可接受的实现

### 输出
```json
{
  "verdict": "pass" | "needs_fix",
  "issues": [
    {
      "severity": "critical" | "major" | "minor",
      "location": "src/auth/login.ts:42",
      "problem": "...",
      "suggestion": "..."
    }
  ]
}
```

### 边界
- 只读，不改代码
- 自由读源码、读 git diff、读 .cadence/

---

## fix executor（task-executor 的特化调用）

### 触发
code-reviewer 返回 needs_fix 时，主 agent 起 task-executor 的特殊变体。

### 输入
- 原 task 描述
- 已完成改动（原 commit sha / files_changed）
- **完整 issues 列表**（含 location / problem / suggestion）
- 同 task-executor 的必读

### 硬规则（额外）
- 修复所有列出的问题
- 维护 README（同原 executor）
- git commit message 格式：`<task-id>-fix: <一句话描述修复>`
- **不得引入 acceptance 范围外的新功能**
- **不得修复 reviewer 没提的"顺手优化"**

最后两条防止 fix 借机扩大 scope。

### 失败处理
fix 自身失败 → 标 ❌（与原 executor 失败一致），依赖者跳过。**不会再起 review** 也不会再 fix。

---

## 与并发的关系
并发上限 3 是针对 task-executor 的。code-reviewer / fix executor 跟在 task-executor 之后串行跑，不抢额度。

"task 完成"的完整定义：
- executor 成功 + reviewer pass，OR
- executor 成功 + reviewer needs_fix + fix executor 成功

任一失败均算 task ❌。

---

## 关键约束（用户明确表达过的偏好）
- 不分前后端等角色 agent，全部通用
- research 不新增命令，仅在 spec/design 中由主 agent 建议 + 用户确认调用
- research 不出现在 run 阶段（run 用 context7 查文档）
- research 失败视为未调用，不阻塞主流程
- plan-reviewer 严格 2 轮
- task-executor 不接其他 task 摘要
- README 不二次校验，executor 说改了就信
- code-reviewer 在 task 级运行（不在 cycle 级）
- review 不过 → fix → 不再 review
- 明确"无用代码"为 critical 审查项
- executor 自己也要主动避免无用代码（prompt 硬规则）
