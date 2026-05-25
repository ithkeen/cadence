---
description: 通过对话锁定做什么 / 验证标准，产出 REQUIREMENTS.md（spec 命令的中间产物）
allowed-tools: Read, Write, Bash, Agent, AskUserQuestion
argument-hint: "[cycle-slug]"
---

<命令目的>
本命令只做"需求澄清"，唯一目标：把 REQUIREMENTS.md 写详细——把「做什么 / 不做什么」与「验证标准」钉死，作为下一步 `/cadence:spec` 的输入。

两件事必须清楚：

1. **做什么 / 不做什么** — 范围边界、隐性期待都已澄清
2. **验证标准** — 完成的判定条件，每条都能落成一个可执行的检查动作

技术约定（技术栈、模块、接口、流程）**完全不在本命令范围内**，留给 `/cadence:spec`。
</命令目的>

<全局规则>

- **输出语言与边界**：全程中文输出。主 agent 不直接读项目源代码，不向用户汇报现状侦察结果（"我看到这是个 React 项目"等不要说）。不拆任务、不写伪代码 / 函数名 / 实现细节
- **用户决策点规范**：每轮最多 1~2 个问题，不连珠炮。所有需用户回答的问题必须用 `AskUserQuestion`（决策型把选项写清；开放型预判 2-3 个常见答案做选项，工具自动追加 Other；一次最多 4 题、每题 2-4 选项）。A-1 开场问句是一处例外，用纯文本
- **无快速通过出口**：用户即使说"别问了直接落档"，自检没走完就继续问

</全局规则>

<阶段留口模板>

A-3 留口环节复用以下模板，文案按 <阶段名> / <继续动作> / <继续描述> 变量化：

```
AskUserQuestion([
  {
    header: "下一步",
    question: "<阶段名>已经聊到这里了，下一步？",
    multiSelect: false,
    options: [
      { label: "<继续动作>",       description: "<继续描述>" },
      { label: "<阶段名>还想再聊", description: "回到追问循环，下一轮 gate 通过后再次出现本环节" }
    ]
  }
])
```

</阶段留口模板>

<主流程>

# 阶段 0：解析参数 + 定位 cycle

参数 `$ARGUMENTS` 解析规则：

1. 去掉两侧空白；剥掉可能的 `cycle-` 前缀，得到 `<slug>`
2. 拼出目标目录：`.cadence/cycle-<slug>/`

**有参数：**

- 目录不存在 → 视为新建：`mkdir -p .cadence/cycle-<slug>/`，跳过 A-1 开场问，直接进入 A-2 让用户描述需求
- 目录存在 + 已有 `REQUIREMENTS.md` → AskUserQuestion：

  ```
  AskUserQuestion([
    {
      header: "已有需求",
      question: "Cycle `<slug>` 已存在 REQUIREMENTS.md，怎么处理？",
      multiSelect: false,
      options: [
        { label: "在已有需求基础上改", description: "Read 已有 REQUIREMENTS.md 作为起点，进入追问继续打磨" },
        { label: "重新开始覆盖",       description: "丢弃已有 REQUIREMENTS.md，从 A-2 开始重新澄清" }
      ]
    }
  ])
  ```

  - 选「在已有需求基础上改」→ Read REQUIREMENTS.md 全文作为内存中的需求段共识起点，跳过 A-1，进入 A-2
  - 选「重新开始覆盖」→ 跳过 A-1，进入 A-2 重新澄清；A-4 落档时直接覆盖
- 目录存在 + 已有 `SPEC.md` → AskUserQuestion：

  ```
  AskUserQuestion([
    {
      header: "已完成 spec",
      question: "Cycle `<slug>` 已经跑过 /cadence:spec 并产出 SPEC.md，确认要回退到只做 requirements 吗？",
      multiSelect: false,
      options: [
        { label: "退出",                description: "不动现有产物，直接结束本命令" },
        { label: "继续跑 requirements", description: "强制重做需求段。注意：完成后需重新跑 /cadence:spec 才能产出新的 SPEC.md" }
      ]
    }
  ])
  ```

  - 选「退出」→ 礼貌结束
  - 选「继续跑 requirements」→ 按上一条同样的「在已有需求基础上改 / 重新开始覆盖」二级询问处理

**无参数：**

```bash
ls -dt .cadence/cycle-*/ 2>/dev/null
```

- 0 个 → 进入 A-1 开场问，让用户描述需求并据此造 slug
- 1 个 → 直接采纳该 cycle，按"目录存在"分支处理
- 2-4 个 → AskUserQuestion 让用户选（label 取 slug，description 取 mtime 与 REQUIREMENTS.md / SPEC.md 是否存在）+ 一个「新建 cycle」选项（选则进入 A-1 开场问）
- \> 4 个 → 列出全部 cycle（按 mtime 倒序），AskUserQuestion 用前 3 个最近的 + 「新建 cycle」+ Other 输入框

确认 cycle 后进入对应阶段。

---

# 阶段 A：需求

## A-1：开场问 + 定 slug

仅在「无参数 + 无任何已有 cycle」或「无参数 + 用户选了新建 cycle」时进入。

用纯文本问句开场：

> 这次想做什么？

等待用户回答。

**用户回答后立即（不向用户输出可见信息）：**

- 根据回答总结简短英文 kebab-case slug（如 `add-login`、`mvp-blog-site`），不让用户确认、不让用户改
- 执行 `mkdir -p .cadence/cycle-<slug>`，已存在直接覆盖里面文件
- slug 一旦定下不再改名

之后进入 A-2。

## A-2：需求追问循环

每轮顺序执行：

1. 调研扫描（见 <调研循环>）
2. 追问（每轮 1~2 题，AskUserQuestion）
3. 内部静默自检（不输出过程）
4. 自检通过 → A-3；否则回 1

**追问的 4 个维度（只问这些）：**

1. 目标用户 / 使用场景 — 谁用、什么场景
2. 核心价值 / 要解决的问题 — 为什么做
3. **范围边界（做什么 + 不做什么）** — 一等公民。对每个"做什么"反问对应的"不做什么"；模糊词必须追问消歧（"登录" → 第三方登录？记住我？忘记密码？验证码？）；主动列举用户没说但通常会期待的功能，逐一确认是否在范围内
4. **验证标准** — 一等公民。怎样算这个 cycle 完成，每条都要具体到可以直接翻译成一个检查动作（运行某命令、访问某 URL、看到某行为），覆盖范围段每个"做什么"至少一条对应。不接受"功能正常"、"测试通过"这类空话——要么写明"运行 `<command>`，全部用例通过"，要么写明被验证的具体行为

技术栈、性能、约束、风险**完全不要问**（归 `/cadence:spec`）。

**内部自检：**

- [范围] 所有"做"都有对应"不做"？模糊词都消歧了？常见隐性期待都问过了？
- [验证] 每条验证项都能直接翻译成一个检查步骤？覆盖了每个"做什么"？
- [其他维度] 目标用户 / 核心价值都清楚？
- 把自己当下游设计者：拿到当前需求段，能不能直接进入技术设计？

任一不通过 → 继续追问。

## A-3：需求段留口

按 <阶段留口模板> 调用，变量取值：

- `<阶段名>` = 需求
- `<继续动作>` = 直接落档 REQUIREMENTS.md
- `<继续描述>` = 把当前共识写成 REQUIREMENTS.md，结束本命令

选"需求还想再聊" → 回 A-2；选"直接落档 REQUIREMENTS.md" → A-4。

## A-4：落档 REQUIREMENTS.md

Write `.cadence/cycle-<slug>/REQUIREMENTS.md`，把内存中的需求段共识**一次性整体写入**：

```markdown
# <自然语言标题>

<段落叙述：要做什么、给谁用、解决什么>

---

# 需求

## 做什么
- ...

## 不做什么
- ...

## 验证标准
<!-- 每条都要能直接翻译成一个检查动作。具体到运行什么命令 / 访问什么地址 / 看到什么行为 -->
- [ ] ...
- [ ] ...
```

**结构要求：**

- 措辞严格（"用户能..."而非"支持..."），不省略边界条件
- 每条「验证标准」都要能被直接翻译成一个检查动作
- 不写实施步骤、不拆任务、不写代码、不写技术栈

## A-5：收尾

> ✅ Cycle `cycle-<slug>` 需求已落档：
> - `.cadence/cycle-<slug>/REQUIREMENTS.md`
>
> 下一步：`/cadence:spec <slug>` 进入技术设计阶段。

</主流程>

<调研循环>

## 调研机制（A-2 每轮强制调用）

### 触发节奏

每轮用户回复后、产出下一轮追问前，执行一次"调研扫描"：

1. **列候选** — 从用户最新回复 + 已澄清需求中挑出具名的产品类型 / 业务领域 / 合规标准 / 竞品 / 行业术语
2. **对照已调研** — `ls .cadence/cycle-<slug>/research/ 2>/dev/null`。文件名匹配 → 已覆盖，跳过
3. **对剩余候选逐个判断**是否命中下方触发条件
4. **任意一个命中 → 必须 AskUserQuestion**

### 触发条件

候选话题命中任一即触发：

- 涉及陌生业务领域
- 涉及合规 / 法规 / 标准（GDPR、PCI-DSS 等）
- 用户希望参考竞品但没给出具体参考

**不触发**：常识性补充、用户已说清楚、已在 `research/` 中找到。

### 询问方式

```
AskUserQuestion([
  {
    header: "是否调研",
    question: "这个话题需要先做点调研再继续吗？",
    multiSelect: false,
    options: [
      { label: "继续调研", description: "调起 research-agent 拉外部资料，落档后回到追问" },
      { label: "跳过",     description: "不调研，继续往下追问" }
    ]
  }
])
```

### 用户同意调研时

1. **确保 research 子目录存在**（cycle 目录已建好）：`mkdir -p .cadence/cycle-<slug>/research`（幂等）

2. 调起 research-agent：

   ```
   Agent(
     subagent_type="cadence:research-agent",
     description="调研 <topic>",
     prompt="
   [topic]       <一句话主题>
   [output_dir]  .cadence/cycle-<slug>/research

   请按 research-agent 系统约定产出调研笔记，落到 output_dir 下。
   "
   )
   ```

3. 完成后 Read 产物作为后续追问上下文
4. research-agent 失败（无产出） → 告知"调研未成功，跳过"，继续主流程

用户拒绝 → 不调，继续追问。

</调研循环>

<异常处理>

- 用户回答完全不像开发任务（聊天闲聊、技术求助） → 礼貌说明 requirements 用途，不强行进入流程
- 用户中途说"算了不做了" → 不写后续文件，礼貌退出。已建的 cycle 目录不主动清理，用户可手动 `rm -rf .cadence/<cycle-dir>`
- `$ARGUMENTS` 含非法字符（`/` 之类） → 一行报错退出：`❌ 非法的 cycle slug：<原始参数>`
- Bash / Write 失败 → 直接报告错误，不重试

</异常处理>

<产物>

- `.cadence/cycle-<slug>/REQUIREMENTS.md` — 需求段（A-4 一次性写入）
- `.cadence/cycle-<slug>/research/*.md` — 按需调研的笔记（如有）

</产物>

<成功标准>

- [ ] `.cadence/cycle-<slug>/REQUIREMENTS.md` 存在，含「做什么 / 不做什么 / 验证标准」三节
- [ ] 收尾文案明确告知用户下一步是 `/cadence:spec <slug>`
- [ ] 若产生过调研，`.cadence/cycle-<slug>/research/*.md` 存在

</成功标准>