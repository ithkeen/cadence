# Claude Code 子 agent `description` 字段写作规范调研

> 调研主题：生产级别、功能出色的 Claude Code 子 agent，其 frontmatter 中的 `description` 字段都怎么写、写哪些内容、背后有哪些讲究
> 调研档位：L3
> 调研日期：2026-05-21
> 解读说明：本文按当前（2026 年 5 月）Claude Code 文件型子 agent（`.claude/agents/*.md` 与 `~/.claude/agents/*.md`）的 frontmatter `description` 字段解读。Agent SDK 的 `AgentDefinition.description`（编程式定义）共用同一套语义，文中一并覆盖。

---

## 1. 一句话结论

`description` 是 Claude 路由器决定"要不要把任务交给这个子 agent"的**唯一信号**，写法上业界已经收敛出三条强约束：**(a) 一句话说清"何时该用我"**（句式偏 "Use when …" / "MUST BE USED to … whenever …"）；**(b) 嵌入领域动作词** 以提高召回（review / audit / debug / refactor / research …）；**(c) 不要把行为指令塞进 description** —— 那是 prompt body 的事。"Use PROACTIVELY" / "MUST BE USED" 是官方文档亲自示范的触发短语，但**滥用会导致整个工作流被该 agent 抢权**，需克制使用。[高]

---

## 2. 关键事实

### 2.1 字段本身

- ✅ `description` 与 `name` 是 frontmatter 中**仅有的两个必填字段**。官方 frontmatter 字段表对 `description` 的定义就一句话：*"When Claude should delegate to this subagent"*。[高，官方原文]
- ✅ 子 agent 由路由器自动调度的核心信号就是 `description`：*"Claude uses each subagent's description to decide when to delegate tasks. When you create a subagent, write a clear description so Claude knows when to use it."*。[高，官方原文]
- ✅ 调用契机：除自动路由外，用户也可以用自然语言（"use the X subagent"）、`@` 提及、或 `--agent <name>` 三种方式显式调用；显式调用时 `description` 已不再决定路由，但仍会出现在 `/agents` 列表与 typeahead 上供用户辨识。[高，官方原文]
- ✅ 官方未给 `description` 设字符上限。社区惯例区间约 **80–400 字符**：短到一行（debugger 的官方例子约 130 字符），长到三、四句（wshobson 的 security-auditor、code-reviewer 接近 400 字符）。[中，多样本归纳]
- ⚠️ Windows 上，整个 frontmatter（含 description + prompt）若通过命令行 JSON 传入会受 8191 字符 cmdline 上限影响，文件型 agent 不受此限。[中，SDK 文档原文：*"On Windows, subagents with very long prompts may fail due to command line length limits (8191 chars)"*]

### 2.2 "Use PROACTIVELY" / "MUST BE USED" 触发短语

- ✅ 官方文档亲自示范两种短语，并明确说明用途：*"To encourage proactive delegation, include phrases like 'use proactively' in your subagent's description field."*。[高，官方原文]
- ✅ 官方 example 中四个示例 agent 有三个用了 "Proactively" / "Use proactively" / "Use immediately"：
  - code-reviewer：*"Expert code review specialist. Proactively reviews code for quality, security, and maintainability. **Use immediately after writing or modifying code.**"*
  - debugger：*"Debugging specialist for errors, test failures, and unexpected behavior. **Use proactively when encountering any issues.**"*
  - data-scientist：*"Data analysis expert for SQL queries, BigQuery operations, and data insights. **Use proactively for data analysis tasks and queries.**"*
- ✅ "MUST BE USED" 是社区惯例（不在官方文档原文里出现，但被 awesome-claude-agents 之类的高引用最佳实践文档推荐进模板）：*"description: MUST BE USED to <do X> whenever <condition>. Use PROACTIVELY before <event>."*。[中，社区最佳实践]
- ⚠️ **滥用 "Use PROACTIVELY" 会让该 agent 截胡其他任务**。社区共识："vague descriptions ('helps with code') get the subagent invoked at random. Specific descriptions ('reviews a recent diff and returns issues by severity') get it invoked exactly when appropriate."[中，社区博客]

### 2.3 反模式

- ✅ #1 反模式是 **vague description**：*"the description field is Claude's primary routing signal. When descriptions use generic capability language ('helps with code', 'implement the feature') instead of specific triggering conditions and output shapes, the orchestrator either fails to route to the subagent at all or routes the wrong tasks to it — and these failures happen silently."*[中，跨多个社区来源交叉]
- ✅ #2 反模式是 **把行为指令塞进 description**：*"Never mix behavioural instructions meant for the agent into the description block."* description 给路由器看，prompt body 给 agent 自己看，受众不同。[中，awesome-claude-agents best-practices]
- ✅ #3 反模式是 **泛名 + 泛 description**：*"Naming an agent with a generic label that matches Anthropic's internal agent vocabulary can silently override your system prompt. Claude infers expected behavior from the name and applies default rules, ignoring your config."* 修复：用 job-shaped 名字（`repo-explorer`, `pr-reviewer`, `docs-researcher`）+ 行动语言的 description。[中，社区博客]
- ❓ 官方文档**没有正面讨论**反模式，只在 best practices tip 里说 *"Write detailed descriptions: Claude uses the description to decide when to delegate"*。所有反模式总结来自社区。

### 2.4 是否要写"何时不要用"

- ❓ 官方文档**未要求**也未禁止写"何时不要用"。examples 里的官方 4 个示例 agent 均**没有写**负向条件。
- ⚠️ 社区里 dev.to 等博客有提出三段式（Triggers on / Action / Output），其中 Triggers 隐含了"不在列表里就不会用"，但**显式写"不要用于 X"** 在主流样本里几乎找不到。[中]
- 推论：负向条件主要靠**精准的正向触发**和**与同 scope 内其他 agent 描述的差异化**来实现，而不是显式写否定句。

---

## 3. 真实仓库样本横向对比

### 3.1 抓样

| Agent | 仓库 | description 第一句 | 触发短语 | 长度 | 语言 |
|---|---|---|---|---|---|
| code-reviewer | Anthropic 官方示例（`code.claude.com/docs/en/sub-agents`） | *"Expert code review specialist. Proactively reviews code for quality, security, and maintainability."* + *"Use immediately after writing or modifying code."* | Proactively + Use immediately | ~165 字符 | 英文 |
| debugger | 同上 | *"Debugging specialist for errors, test failures, and unexpected behavior."* + *"Use proactively when encountering any issues."* | Use proactively | ~120 字符 | 英文 |
| data-scientist | 同上 | *"Data analysis expert for SQL queries, BigQuery operations, and data insights."* + *"Use proactively for data analysis tasks and queries."* | Use proactively | ~135 字符 | 英文 |
| code-reviewer | `wshobson/agents` (★35.7k) | *"Elite code review expert specializing in modern AI-powered code analysis, security vulnerabilities, performance optimization, and production reliability. Masters …. **Use PROACTIVELY** for code quality assurance."* | Use PROACTIVELY | ~365 字符 | 英文 |
| backend-architect | 同上 | *"Expert backend architect specializing in scalable API design, microservices architecture, and distributed systems. Masters REST/GraphQL/gRPC APIs … . Handles service boundary definition, inter-service communication, resilience patterns, and observability. **Use PROACTIVELY when creating new backend services or APIs.**"* | Use PROACTIVELY when | ~410 字符 | 英文 |
| security-auditor | 同上 | *"Expert security auditor specializing in DevSecOps, comprehensive cybersecurity, and compliance frameworks. … **Use PROACTIVELY for security audits, DevSecOps, or compliance implementation.**"* | Use PROACTIVELY for | ~395 字符 | 英文 |
| debugger | 同上 | *"Debugging specialist for errors, test failures, and unexpected behavior. **Use proactively when encountering any issues.**"* | Use proactively | ~120 字符（直接抄官方） | 英文 |
| test-automator | 同上 | *"Create comprehensive test suites including unit, integration, and E2E tests. Supports TDD/BDD workflows. **Use for test creation during feature development.**"* | Use for | ~165 字符 | 英文 |
| code-reviewer | `VoltAgent/awesome-claude-code-subagents` | *`"Use this agent when you need to conduct comprehensive code reviews focusing on code quality, security vulnerabilities, and best practices."`* | Use this agent when | ~140 字符 | 英文，带双引号 |
| debugger | 同上 | *`"Use this agent when you need to diagnose and fix bugs, identify root causes of failures, or analyze error logs and stack traces to resolve issues."`* | Use this agent when | ~150 字符 | 英文 |
| backend-developer | 同上 | *`"Use this agent when building server-side APIs, microservices, and backend systems that require robust architecture, scalability planning, and production-ready implementation."`* | Use this agent when | ~180 字符 | 英文 |
| research-analyst | 同上（`categories/10-research-analysis`） | *`"Use this agent when you need comprehensive research across multiple sources with synthesis of findings into actionable insights, trend identification, and detailed reporting."`* | Use this agent when | ~180 字符 | 英文 |
| frontend-developer | `contains-studio/agents` | *"Use this agent when building user interfaces, implementing React/Vue/Angular components, handling state management, or optimizing frontend performance. This agent excels at …. **Examples: <example>…</example> ×3**"* | Use this agent when + Examples | 数百字符（含 3 个 example 块） | 英文 |
| test-results-analyzer | 同上 | *"Use this agent for analyzing test results, synthesizing test data, identifying trends, and generating quality metrics reports. … **Examples: <example>…</example> ×4**"* | Use this agent for + Examples | 数百字符 | 英文 |

### 3.2 从样本归纳的写法流派

按风格大致分三派：

**A. 简短触发派（官方示范 + wshobson 一部分）** — 1～2 句。第一句"身份/能力"，第二句"何时用"。例：debugger、test-automator。**适合**：定位单一、和同 scope 其他 agent 无歧义的 agent。

**B. 长能力清单派（wshobson 大部分）** — 3～4 句。先 "Expert X specializing in A, B, C"，再 "Masters …"，再 "Handles …"，最后 "Use PROACTIVELY for …"。**特征**：堆砌技术栈关键词以提高召回率（路由器是按词匹配的，关键词越多越容易被命中）。**风险**：覆盖范围越大越容易抢其他 agent 的活。

**C. 用例 + 示例派（contains-studio）** — description 字段里塞 2～4 个 `<example>` 块，每个示例包含 Context / user / assistant / commentary。**特征**：用 few-shot 示例硬教路由器"看到这种 user 输入应该选我"。**代价**：description 体积膨胀到几百字符甚至 1 KB+。

**VoltAgent 是 A 派的标准化变体**：固定句式 `"Use this agent when you need to ..."`，并整体加双引号（YAML 里非必需，但兼容性更稳）。

### 3.3 关于第一句句式

- **官方示例**：动词 / 名词短语开头（"Expert code review specialist."、"Debugging specialist for ..."、"Data analysis expert for ..."）—— 身份 + 领域。
- **wshobson**：固定 "Expert X specializing in ..." / "Elite X specializing in ..." / "Master X specializing in ..."。
- **VoltAgent + contains-studio**："Use this agent when ..." —— 直接动作触发句。
- **共同点**：**几乎没有任何 description 是以 "This is a..." / "An agent that ..." 这种被动/纯名词起手** —— 路由器对动作语言更敏感。

### 3.4 触发短语使用比例（基于 14 个样本）

| 触发短语 | 出现次数 |
|---|---|
| Use proactively / Use PROACTIVELY | 7 |
| Use this agent when / for | 5 |
| Use immediately | 1 |
| Use when | 1 |
| 完全不写触发短语 | 0 |

**结论**：**所有生产级 agent 的 description 都带显式触发短语**。这是路由可靠性的硬性约定，不是文体偏好。[高]

### 3.5 中英文混用

- 抓到的 14 个高 star / 官方样本**全部用英文**。
- 用户当前 5 个 agent 是"中文描述 + 末尾一句英文触发短语"——属于自创风格，社区无直接先例。
- 合理性分析：Claude Code 路由器是 LLM，对中英文都能匹配；但触发短语 "Use proactively after ..." 是 Anthropic 在训练 / RLHF 中**明确强化过**的英文 idiom，保留英文一句确实能提高召回。这种"中文主体 + 英文触发尾巴"是合理的本地化策略。[中]

### 3.6 是否暴露输入契约 / 输出形态

- **官方 4 个示例**：**不暴露** description 层，最多说 "for SQL queries"。输入 / 输出契约写在 prompt body 里。
- **wshobson**：偏向暴露**能力清单**而非输入契约。
- **contains-studio**：通过 `<example>` 块隐式暴露输入形态（user 那行）和输出风格（assistant 那行）。
- **副作用约定（"不写文件" / "会写文件"）**：14 个样本里**完全没有人**在 description 里写。这条信息通常被认为属于 prompt body 或 `tools` 字段管辖。

### 3.7 是否写依赖（如 "requires Playwright MCP"）

- 14 个样本里**0 个**在 description 里声明依赖。
- 官方推荐的做法是用 `mcpServers` 字段或在 prompt body 里说明，**而不是放进 description**。理由：description 是路由信号，"需要 X MCP" 不影响路由决策，只影响运行可行性。
- 用户的 frontend-executor 里写了 "要求用户预装 Playwright MCP；自由创意场景下还需 frontend-design plugin" —— 这是少见但**有合理价值**的反例（见 §5 点评）。

---

## 4. 给用户 5 个 agent 的具体修改建议

通用判断尺：**每条 description 是否做到了 (a) 第一句能让路由器一眼看懂"何时该选我"；(b) 末尾有英文触发短语；(c) 没有把行为指令塞进 description；(d) 与同 scope 其他 agent 描述差异化清晰，不重叠**。

### 4.1 code-reviewer

- **现状原文**：
  > 通用 code review 子 agent。给定评审范围与可选评审重点，**以 Markdown 文本作为 agent 返回内容**交回一份高置信度、低噪音的中文 review 摘要，供主 agent 决策后续修复。不写任何文件。Use proactively after writing or modifying code, or when the user explicitly asks to review changes / a branch / staged work.

- **诊断**：
  - 优点：触发短语清晰（`Use proactively after writing or modifying code` 直接对齐官方 code-reviewer 范式）；尾句枚举触发场景（"a branch / staged work"）有助召回。
  - 问题 1：**"以 Markdown 文本作为 agent 返回内容"**、**"不写任何文件"** 属于副作用契约 / 行为指令，应进 prompt body 而不是 description。路由器不需要也不会用这条信息选 agent，反而占用了路由器的注意力。
  - 问题 2：**"给定评审范围与可选评审重点"** 也是输入契约，同理不该进 description。
  - 问题 3：**"通用 code review 子 agent"** 这种自我标签弱信号；不如直接给身份 + 能力词（"高质量 code review specialist"）让路由器抓得更稳。

- **建议**：身份 + 能力词 + 显式触发场景 + 触发短语。把"不写文件 / Markdown 返回 / 输入契约"全部移到 prompt body。

- **修改后示例**：
  > 高置信度 code review 子 agent。识别 bug、安全风险、可维护性问题与重复代码，按严重度分组输出中文 review 摘要。适用于代码改完想要"先 review 再决定要不要 merge / 继续改"的场景，以及对分支 / staged diff 的事前审阅。Use proactively after writing or modifying code, or when the user asks to review changes, a branch, or staged work.

### 4.2 code-executor

- **现状原文**：
  > 通用代码实施子 agent。接收 plan-agent 切好的单个原子步骤（YAML 输入契约），按 files_allowed 白名单写代码、跑测试自验、成功则 commit、产出三态 YAML 简报。只执行单个步骤，不拆任务、不重新规划。适用于按计划落地后端 / CLI / 库 / 一般业务代码。Use when given a step block from a plan-agent.

- **诊断**：
  - 优点：触发条件**异常精准**——"Use when given a step block from a plan-agent" 是 description 里少见的"协议层触发"，与你 cadence 项目的多 agent 编排范式高度耦合，几乎不会被误调。
  - 优点：末段"适用于按计划落地后端 / CLI / 库 / 一般业务代码"是清晰的正向场景枚举。
  - 优点："只执行单个步骤，不拆任务、不重新规划"是**少见但有价值的负向边界声明**——避免路由器把规划任务塞过来。属于上文 §2.4 提到的"显式负向条件"的少数合理用例。
  - 问题 1：**"接收 plan-agent 切好的单个原子步骤（YAML 输入契约）"**、**"按 files_allowed 白名单写代码、跑测试自验、成功则 commit、产出三态 YAML 简报"** 是完整的输入 / 执行 / 输出契约，对路由器无价值，应移入 prompt body。
  - 问题 2：description 体量略大（约 200+ 中文字符 ≈ 400+ 字节），路由层每次都要带这段进上下文。

- **建议**：保留触发协议 + 正向场景 + 关键负向边界，移走所有契约细节。

- **修改后示例**：
  > 通用代码实施子 agent。按 plan-agent 切好的单步骤契约落地代码：写代码、跑测试自验、commit、回简报。**只执行单个步骤，不拆任务、不重新规划。** 适用于后端 / CLI / 库 / 一般业务代码。Use when given a step block from a plan-agent.

### 4.3 frontend-executor

- **现状原文**：
  > 前端代码实施子 agent。在 code-executor 的步骤执行契约之上叠加：开工前系统侦察（默认尊重项目既有 design system；无系统时启用 frontend-design skill）/ AI 默认黑名单硬约束 / Playwright MCP 浏览器自验。适用于按计划落地 UI 组件、页面、前端交互。要求用户预装 Playwright MCP；自由创意场景下还需 frontend-design plugin。Use when given a UI step block from a plan-agent.

- **诊断**：
  - 优点：触发协议清晰（`UI step block from a plan-agent`），且**和 code-executor 形成精准互补**——前者收 UI step，后者收非 UI step，路由器二选一不会迷糊。这种"用触发词差异化做路由"是 §3.2 提到的好做法。
  - 优点：末段正向场景（"UI 组件、页面、前端交互"）召回词到位。
  - 问题 1：**"在 code-executor 的步骤执行契约之上叠加"** —— 路由器不需要知道继承关系，这条只对你自己复盘有用。
  - 问题 2：**"开工前系统侦察 / AI 默认黑名单硬约束 / Playwright MCP 浏览器自验"** 是行为细节，应进 prompt body。
  - 问题 3：**"要求用户预装 Playwright MCP；自由创意场景下还需 frontend-design plugin"** —— 这是 14 个样本里唯一类似的"依赖声明"。**但 description 不是讲依赖的地方**：路由器决定 "选不选这个 agent" 时根本管不到"是否装了 MCP"；如果没装会运行时失败，不该靠路由器规避。建议移到 prompt body 开头作为前置检查项。

- **建议**：与 code-executor 对称结构 + 强调"和 code-executor 的区分点是 UI"。

- **修改后示例**：
  > 前端代码实施子 agent。按 plan-agent 切好的 **UI 步骤**契约落地 UI 组件、页面、前端交互：尊重项目既有 design system，浏览器自验后 commit，回简报。**只执行单个 UI 步骤，不拆任务、不重新规划。** Use when given a UI step block from a plan-agent (use code-executor for non-UI steps).

  说明：括号里那句 `(use code-executor for non-UI steps)` 是给路由器看的差异化提示，让它在 step 类型暧昧时不至于乱选。Playwright MCP / frontend-design plugin 的依赖声明改放到 prompt body 第一段。

### 4.4 doc-to-html-renderer

- **现状原文**：
  > 把任意文本文档智能渲染成单文件 HTML。读者拿到的不是原文直译，而是按文档类型重新组织过、信息无遗漏但可视化更高、读起来比读原文舒服的版本。

- **诊断**：
  - 优点：第一句**最直接**——"把 X 渲染成 Y"，路由器一眼就懂。
  - 优点：第二句**讲清了价值差异化**——和"直接给我个 HTML 模板"或"原文转 HTML"的弱方案划清界限。
  - 问题 1：**完全没有触发短语**。14 个样本里 14/14 都带触发短语，这条是异常值。当用户说"帮我把这份 PRD 渲染成 HTML"时，路由器靠你的能力陈述匹配是够的；但当用户说"把这份 spec 整理一下"——"整理"是否触发本 agent？没有触发短语会让边界模糊场景下召回降低。
  - 问题 2：**没有显式说"何时该用我"**。比如"想给非技术读者读"、"想要可视化更友好的形态"、"要打印 / 分享 / 归档" 这些场景值得点出来，对路由是强信号。
  - 问题 3：**没有说明输入边界**——是 Markdown？纯文本？任意文件？"任意文本文档"略宽泛。

- **建议**：保留现有第一/二句，补一个触发场景 + 触发短语。

- **修改后示例**：
  > 把任意文本文档（Markdown / 纯文本 / 调研笔记 / spec / 会议记录）智能渲染成单文件 HTML。读者拿到的不是原文直译，而是按文档类型重新组织过、信息无遗漏但可视化更高、读起来比读原文舒服的版本。Use when the user wants to render / visualize / share / present a document as HTML, or asks to "把 X 整理成 HTML / 网页"。

### 4.5 research-agent

- **现状原文**（已 Read 文件确认）：
  > 通用外部知识调研 agent。给定一个调研主题与输出目录，产出一份精准、可信、可执行的中文调研笔记。适用于陌生业务、合规法规、陌生技术栈、版本敏感 API、外部协议、多方案对比等场景。

- **诊断**：
  - 优点：身份明确（"通用外部知识调研 agent"）。
  - 优点：**适用场景枚举得很好**——"陌生业务 / 合规法规 / 陌生技术栈 / 版本敏感 API / 外部协议 / 多方案对比" 几乎覆盖了实际触发条件，这是 §3.2 长 description 里最有路由价值的部分。
  - 问题 1：**没有触发短语**（和 doc-to-html-renderer 一样的异常）。
  - 问题 2：**"给定一个调研主题与输出目录"** 是输入契约，对路由器无价值。建议移入 prompt body（实际上你 prompt body 里已经写了"输入约定"）。
  - 问题 3：与 Claude Code 内置的 `Explore` / `Plan` / `general-purpose` subagent 可能有边界歧义——你的 research-agent 是"查外部信息"，built-in Explore 是"查 codebase"。建议显式把这条边界写进来，避免路由器把"查代码"的活塞过来。

- **建议**：删输入契约 + 加触发短语 + 加 codebase 边界差异化。

- **修改后示例**：
  > 通用**外部知识**调研 agent。产出一份精准、可信、可执行的中文调研笔记，落到指定输出目录。适用于陌生业务、合规法规、陌生技术栈、版本敏感 API、外部协议、多方案对比等场景。**不用于代码库内部探索（用 Explore subagent）。** Use proactively when the user asks to research / investigate / compare an external topic, library, API, regulation, or standard.

---

## 5. 整体复盘 & 几条横向规律

对照官方 + 14 个生产样本，用户的 5 个 agent 的共性优缺点：

| 维度 | 用户做得好的 | 用户可以更好的 |
|---|---|---|
| 触发短语 | code-reviewer、code-executor、frontend-executor 三个都有 | doc-to-html-renderer、research-agent **缺失** |
| 身份/能力词 | 5/5 都有 | OK |
| 适用场景枚举 | research-agent、frontend-executor 做得好 | doc-to-html-renderer 略弱 |
| 中英混用 | 中文身份 + 英文触发尾，是合理本地化 | 与社区主流（全英文）不同，但有理论依据 |
| 行为指令污染 | — | code-reviewer / code-executor / frontend-executor **都把契约 / 输出形态 / 副作用约定塞进了 description**，应移到 prompt body |
| 与其他 agent 边界 | code-executor vs frontend-executor 互补做得**非常好**（业界少见的精准协议触发） | research-agent 没声明"与 Explore 的边界"，doc-to-html-renderer 没声明"与直接生成 HTML 的边界" |
| description 长度 | 都在 100–250 中文字符（约 200–500 字节），不算超标 | 删掉行为指令后体感会更轻 |

**两条最高优先级的修改**：
1. **删掉 description 里的输入 / 输出契约、副作用约定**（"以 Markdown 返回"、"不写任何文件"、"YAML 输入契约"、"产出三态简报"、"要求用户预装 Playwright MCP"）—— 这些是 prompt body 的事，不影响路由。
2. **给 doc-to-html-renderer 和 research-agent 补上英文触发短语**——保持 5 个 agent 的"中文主体 + 英文 Use ... 尾"风格统一。

---

## 6. 已尝试但未找到

- **官方对 description 字符长度的硬上限**：尝试过 `code.claude.com/docs/en/sub-agents`、`code.claude.com/docs/en/agent-sdk/subagents`，**没有任何字符上限定义**。仅 SDK 文档提到 Windows cmdline 8191 字符的间接限制。
- **官方对"是否应在 description 写否定 / 排除条件"的指引**：未找到。社区主流也不写否定条件，靠正向触发 + agent 差异化。
- **官方对 description 中英文的偏好**：未找到任何指引。可以推断路由器对两种语言都能工作，但 "Use PROACTIVELY" / "MUST BE USED" 作为英文 idiom 在训练数据中的强化程度高于中文等价物。

---

## 7. 引用来源

### 官方文档（一手）

- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) — 官方文档，2026-05-21 抓取。这是 description 字段定义、frontmatter 字段表、四个官方 example agent（code-reviewer / debugger / data-scientist / db-reader）、自动委派机制、`use proactively` 短语建议的唯一一手出处。
- [Subagents in the SDK — Claude Docs](https://code.claude.com/docs/en/agent-sdk/subagents) — 官方 SDK 文档，2026-05-21 抓取。覆盖 `AgentDefinition.description` 编程式定义、troubleshooting 中 "Claude not delegating to subagents" 的修复建议（"Write a clear description"）、Windows cmdline 8191 字符限制。

### 高 star 仓库样本（一手）

- [wshobson/agents](https://github.com/wshobson/agents) — ★35.7k，2026-05-21 抓取。当前已重构为 plugin 架构，agent 文件位于 `plugins/<plugin-name>/agents/*.md`。本文摘取的 frontmatter 样本：
  - `plugins/comprehensive-review/agents/code-reviewer.md`
  - `plugins/comprehensive-review/agents/architect-review.md`
  - `plugins/comprehensive-review/agents/security-auditor.md`
  - `plugins/backend-development/agents/backend-architect.md`
  - `plugins/backend-development/agents/test-automator.md`
  - `plugins/debugging-toolkit/agents/debugger.md`
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — 100+ agent collection，2026-05-21 抓取。本文摘取：
  - `categories/04-quality-security/code-reviewer.md`
  - `categories/04-quality-security/debugger.md`
  - `categories/01-core-development/backend-developer.md`
  - `categories/10-research-analysis/research-analyst.md`
- [contains-studio/agents](https://github.com/contains-studio/agents) — 2026-05-21 抓取。代表"用例 + `<example>` 块"派。本文摘取：
  - `engineering/frontend-developer.md`
  - `testing/test-results-analyzer.md`

### 社区最佳实践（二手，用作模式归纳与反模式来源）

- [vijaythecoder/awesome-claude-agents — best-practices.md](https://github.com/vijaythecoder/awesome-claude-agents/blob/main/docs/best-practices.md) — 2026-05-21 抓取。"MUST BE USED to <do X> whenever <condition>. Use PROACTIVELY before <event>." 模板句式与 "Never mix behavioural instructions into description" 原则的出处。
- [4 Claude Code Subagent Mistakes That Kill Your Workflow — DEV.to](https://dev.to/alireza_rezvani/4-claude-code-subagent-mistakes-that-kill-your-workflow-and-the-fixes-3n72) — 发布于 Feb 2 (2026)，2026-05-21 抓取。Triggers / Action / Output 三段式建议、vague description 反模式与修复（活化率 50% 案例）。
