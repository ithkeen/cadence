---
name: tdd
description: cadence plugin 的 task-executor 在非前端业务逻辑 task 上走 TDD 节奏（R-G-R）的实施指引。每条 acceptance 一轮循环。
---

# TDD 实施指引

本 skill 由 `cadence:task-executor` 在**非前端业务逻辑 task** 上主动加载（触发判据见 task-executor.md 触发型子流程 B）。一旦加载，必须按本文档的 R-G-R 节奏写代码。

## 核心铁律

```
没有失败的测试，不写产品代码。
```

先写代码再写测试 → 测试只验证"代码做了它已经做的事"。先写测试再看它失败 → 才能确认测试真在测目标行为。

如果你先写了产品代码——删掉，从测试开始。不要"留着参考"、不要"边写测试边对照"。

## 单 task 映射

```
每一条 acceptance → 一轮 R-G-R 循环
```

按 acceptance 顺序一条条走，不要"先把所有测试写完再实现"——那只是把"事后补测试"反过来做。

## R-G-R 循环（每条 acceptance 走完整 5 步）

### Step 1 · RED：写最小失败测试

为**当前**这条 acceptance 写**一条**最小测试。

- 一条测试只覆盖一个行为，名字清晰描述（"rejects empty email"）
- 用真代码，能不 mock 就不 mock（mock 是为了隔离外部依赖，不是隔离内部模块）
- 测试不依赖未写的辅助函数；如需要，先写它的测试

不要一次写多条测试。一条够了。

### Step 2 · Verify RED：跑测试确认"红得对"

```bash
<项目测试命令> <测试文件路径>
```

确认：
- 测试**失败**（不是 error / timeout）
- 失败原因是**功能未实现**（断言失败 / 函数不存在 / 返回值不符）
- 失败原因**不是**语法错、import 错、测试本身写错

**测试瞬间通过** → 你在测已有行为，没意义。重写测试覆盖 acceptance 描述的"新行为"。
**报 error** → 修测试代码，重跑直到红得"对"。
**没看见红** → 不要进 Step 3。

### Step 3 · GREEN：写最小代码让测试通过

写**刚好够**让测试通过的代码。

- 不为"以后可能需要"加参数、抽象、扩展点
- 不顺手改其他代码
- 不为别的 acceptance 提前实现

最小代码看起来很傻（如硬编码返回值让测试过）→ 没问题。下一条 acceptance 的测试会逼你泛化，这就是 TDD 自然驱动设计。

### Step 4 · Verify GREEN：跑测试确认"绿得稳"

```bash
<项目测试命令>
```

确认：
- **本条**测试通过
- **项目原有**测试仍全部通过
- 输出 pristine（无意外 warning / error / 控制台噪音）

**本条没过** → 改代码不改测试。
**搞坏了别的测试** → 当场修，不留到"最后一起处理"。

### Step 5 · REFACTOR（可选）

只有绿之后才能做。**能做**：消除重复、改名、抽 helper。**不能做**：加新行为、改测试、顺手优化无关代码。

每改一小步跑一次测试，保持绿。

### 进入下一条 acceptance

回到 Step 1。

## 全部 acceptance 走完后

- **全量跑一次**本模块测试 + 项目相关测试，确认绿
- 跑 lint / typecheck（如配置），输出 pristine
- 全量通过后才能 commit

## 测试基础设施缺失时

按以下顺序探测：
- Node：`package.json` 的 `"test"` script、`jest.config.*` / `vitest.config.*` / `mocha`
- Python：`pytest.ini` / `pyproject.toml` 的 `[tool.pytest.ini_options]` / `tests/` / `unittest`
- Go：`*_test.go`（`go test` 内置）
- Rust：`Cargo.toml`（`cargo test` 内置）
- Java/Kotlin：`pom.xml` 的 surefire / `build.gradle` 的 test plugin
- 其他：按项目语言常识探测

**全部未找到** → 立即返回 `status: "failed"`，`notes`：

> 项目无测试基础设施。本 task 是非前端业务逻辑 task，按 cadence 约定必须 TDD。请回 `/cadence:spec` 设计阶段补齐测试框架选型后重跑。

**禁止**自行装框架（`npm i -D jest` / `pip install pytest` 等）；**禁止**静默跳过 TDD。装框架是 `/cadence:spec` 设计阶段决策，不该塞进单 task。

## Fix 模式

task-executor 在 Fix 模式下也调用本 skill。

### bug 类 issue（行为错误）：强制先写复现测试

reviewer 描述**行为错误**的 issue（severity 通常 major / critical，关键词如"返回错了"、"边界没处理"、"会崩"、"输出不符预期"）：

1. **RED**：写复现测试，覆盖 reviewer 描述的错误（断言"应返回 X 实际返回 Y"）
2. **Verify RED**：跑测试，确认失败原因正是 reviewer 指出的 bug（不是别的）
3. **GREEN**：改代码修 bug
4. **Verify GREEN**：测试通过 + 没搞坏别的

复现测试**留下**作为回归保护，不要修完就删。

### 非 bug 类 issue：不强 TDD

代码质量 / 重构 / 命名 / 未用 import / 风格 → 直接改，refactor 时**保持原测试绿**。

### "测试缺失"类 issue

reviewer 指出"X 函数没有测试" → 仍按 R-G-R 走：先 RED 看到红（说明测试真在检查行为），再确认产品代码已能让它绿。绿之前要改产品代码 → 同时发现了 bug，按 bug 类处理。

## Anti-patterns

| 反模式 | 表现 | 怎么做对 |
|---|---|---|
| **测 mock 行为** | 断言"mock 被调用 N 次"、"mock 收到参数 X" → 你在测 mock 不是测代码 | 测真行为：测代码对真实输入产生的真实输出。如必须 mock，断言代码**对 mock 返回值的处理结果** |
| **给生产代码加 test-only 方法** | 为测试方便加 `destroy()` / `reset()` / `_setState()` → 污染生产 API | 把 cleanup / reset 放进 `test-utils/`，测试 import，生产代码不知道 |
| **不理解依赖就 mock** | mock 高层方法但测试逻辑依赖被 mock 方法的副作用 → 瞎过或乱挂 | 先用真实现跑一遍看测试需要什么副作用，再在**更低层**（外部网络、文件 IO、慢操作）打 mock |
| **不完整 mock** | mock 响应只填测试用到的字段，下游访问别的字段就崩 | mock 镜像真实数据结构**完整**字段；不确定的查文档 / 例子，宁可多填 |

发现自己在写以上任意一种 → 停下、删掉、按"怎么做对"重写。

## 自检清单（与 task-executor 失败判定挂钩）

commit 前自检：

- [ ] 每条 acceptance 都看到对应测试**先红后绿**？
- [ ] 没有"先写代码后补测试"的情况？
- [ ] 项目原有测试仍全部通过？
- [ ] 没为通过测试加 acceptance 范围外的功能？
- [ ] 没断言 mock 行为？
- [ ] 没给生产代码加 test-only API？
- [ ] mock 都完整覆盖了真实数据结构？

任一不满足 → 回到对应步骤，**不要硬撑着 commit**。该返回 `status: "failed"`。

## 红旗：停下并重来

看到这些信号说明已偏离 TDD，**全部重来**：

- 写了代码才发现"哦还得写测试"
- 测试瞬间通过没看见红
- 改测试让它通过（而不是改代码）
- 心里想"这个 task 简单，跳过 TDD"
- 心里想"先实现再写测试也行"
- 心里想"已经写了 30 分钟代码，删了可惜"

最后一条特别要警惕：**沉没成本不是理由**。已写代码删掉重来，比留着假测试给后面埋雷便宜。

## 边界（与 task-executor 其他规则的关系）

- **SPEC.md 测试框架选型 > 本 skill 通用建议**：用 jest / vitest / pytest / unittest 以 SPEC.md / PROJECT.md 写明的为准
- **acceptance > 测试覆盖野心**：本 skill 鼓励"测真行为、覆盖边界"仅适用于 acceptance 涵盖的行为；不要为"覆盖率"补 acceptance 范围外的测试
- **README 同步仍由 task-executor 常驻规则 #2 管**：测试代码不算对外接口，但本 task 让模块对外行为变了，README 仍要更新
- **commit 边界仍由 task-executor 常驻规则 #4 管**：测试和产品代码在**同一个** commit 里（同属本 task），但**不要**把无关改动一起 commit
