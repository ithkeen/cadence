---
name: tdd
description: cadence plugin 的 task-executor 在非前端业务逻辑 task 上走 TDD 节奏（R-G-R）的实施指引。每条 acceptance 一轮循环。
---

# TDD（Test-Driven Development）实施指引

## 总览

本 skill 被 `cadence:task-executor` 在**非前端业务逻辑 task** 上主动加载（触发判据见 task-executor.md 硬规则 #7）。一旦加载，你**必须**按本文档的 R-G-R 节奏写代码。

### 核心铁律

```
没有失败的测试，不写产品代码。
```

如果你先写了产品代码——删掉它，从测试开始。不要"留着参考"、不要"边写测试边对照"、删就是删。

为什么？**先写代码后写测试**，测试会瞬间通过——它只验证了"代码做了它已经做的事"，没法证明"代码做了它应该做的事"。**先写测试再看它失败**，才能确认测试真在测目标行为。

### 单 task 映射

cadence 的 task 来自 PLAN.md，每个 task 有若干条 `acceptance`。映射规则：

```
每一条 acceptance → 一轮 R-G-R 循环
```

按 acceptance 顺序一条条走，不要"先把所有测试写完再实现"——那只是把"事后补测试"反过来做。

## R-G-R 循环

按 acceptance 逐条循环，每条 acceptance 走完整 5 步：

### Step 1 · RED：写最小失败测试

为**当前**这条 acceptance 写**一条**最小测试。

- 一条测试只覆盖一个行为，名字清晰描述该行为（"rejects empty email"、"retries failed operations 3 times"）
- 用真代码，能不 mock 就不 mock（mock 是为了隔离外部依赖，不是为了 mock 内部模块）
- 测试代码本身**不要**依赖任何还没写的辅助函数；如果需要的辅助函数也没有，先写它的测试

不要一次写多条测试。一条够了。

### Step 2 · Verify RED：跑测试，确认它"红得对"

```bash
<项目测试命令> <测试文件路径>
```

确认三件事：

- 测试**失败**（不是 error / 不是 timeout）
- 失败原因是"**功能未实现**"（断言失败 / 函数不存在 / 返回值不符）
- 失败原因**不是**语法错、import 错、测试代码本身写错

**测试瞬间通过**？→ 你在测已有行为，测试没意义。重写测试，让它真正覆盖 acceptance 描述的"新行为"。

**测试报 error**（不是断言失败）？→ 修测试代码本身，重跑，直到红得"对"。

**没看见红**？→ 不要进 Step 3。

### Step 3 · GREEN：写最小代码让测试通过

写**刚好够**让测试通过的代码。

- 不为"以后可能需要"加参数、抽象、扩展点、工厂方法
- 不顺手改其他代码（哪怕你看出它写得丑）
- 不为别的 acceptance 提前实现（那是下一轮的事）

如果"最小代码"看起来很傻（例如硬编码返回值让一个测试过），**没问题**——下一条 acceptance 的测试会逼你把它泛化。这就是 TDD 自然驱动设计的方式。

### Step 4 · Verify GREEN：跑测试，确认它"绿得稳"

```bash
<项目测试命令>
```

确认三件事：

- **本条**测试通过
- **项目原有**测试仍全部通过
- 输出 pristine（没有意外的 warning / error / 控制台噪音）

**本条没过**？→ 改代码，不改测试。

**搞坏了别的测试**？→ 当场修，不要留到"最后一起处理"。

### Step 5 · REFACTOR（可选）：清理

只有在绿之后才能做。能做的：

- 消除重复（你刚写的代码与已有代码重复了）
- 改名（变量 / 函数名不够准）
- 抽 helper（多个地方在做同样的事）

**不能做**的：

- 加新行为
- 改测试
- 顺手优化无关代码

每改一小步跑一次测试，保持绿。

### 进入下一条 acceptance

回到 Step 1。

## 全部 acceptance 走完后

- **全量跑一次**本模块测试 + 项目相关测试（不只是你刚写的），确认绿
- 跑 lint / typecheck（如项目配了），输出 pristine
- 这次全量通过之后才能 commit

## 测试基础设施缺失时

按以下顺序探测项目的测试基础设施：

- Node：`package.json` 里有 `"test"` script，或 `jest.config.*` / `vitest.config.*` / `mocha` 配置
- Python：`pytest.ini` / `pyproject.toml` 的 `[tool.pytest.ini_options]` / `tests/` 目录 / `unittest` 用法
- Go：项目里有任何 `*_test.go`（`go test` 内置）
- Rust：`Cargo.toml`（`cargo test` 内置）
- Java/Kotlin：`pom.xml` 的 surefire / `build.gradle` 的 test plugin
- 其他：按项目语言常识探测

**全部未找到** → 立即返回 `status: "failed"`，`notes` 字段填：

> 项目无测试基础设施。本 task 是非前端业务逻辑 task，按 cadence 约定必须 TDD。请回 `/cadence:design` 阶段补齐测试框架选型后重跑。

**不要**自行装框架（`npm i -D jest` / `pip install pytest` 等都禁止）。**不要**静默跳过 TDD 把代码写了就 commit。这是 task-executor 硬规则 #7 的强约束。

理由：装测试框架是项目级决策，应在 `/cadence:design` 阶段确定，不该塞进单个业务 task 的范围。

## Fix 模式

task-executor 在 Fix 模式下也会调用本 skill。规则如下：

### bug 类 issue：强制先写复现测试

reviewer 给的 issue 里，凡是描述**行为错误**的（severity 通常是 major / critical，关键词如"返回错了"、"边界没处理"、"会崩"、"输出不符预期"）：

1. **RED**：写一条复现测试，覆盖 reviewer 描述的错误行为（断言"应该返回 X 但实际返回 Y"）
2. **Verify RED**：跑测试，确认它失败，且失败原因正是 reviewer 指出的 bug（不是别的）—— 这一步是证明 bug 真存在、测试真覆盖它
3. **GREEN**：改代码修 bug
4. **Verify GREEN**：跑测试，确认通过 + 没搞坏别的测试

复现测试**留下**作为回归保护，不要修完就删。

### 非 bug 类 issue：不强 TDD

代码质量 / 重构 / 命名 / 未使用 import / 风格类 issue：直接改即可，refactor 时**保持原测试绿**。这类 issue 没有"行为错误"可复现。

### "测试缺失"类 issue

reviewer 指出"X 函数没有测试"：补测试时仍按 R-G-R 走 —— 先 RED 看到红（说明测试真在检查行为），再确认产品代码已能让它绿。如果绿之前需要改产品代码，那就是同时发现了 bug，按 bug 类处理。

## Anti-patterns

写测试时常踩的坑，每一条都会让"绿"失去意义：

| 反模式 | 表现 | 怎么做对 |
|---|---|---|
| **测 mock 行为** | 断言"mock 被调用 N 次"、"mock 收到的参数是 X" → 你在测 mock 不是测代码 | 测真行为：测代码对真实输入产生的真实输出。如必须 mock，断言代码**对 mock 返回值的处理结果**，不要断言对 mock 的调用 |
| **给生产代码加 test-only 方法** | 为了测试方便在 class 加 `destroy()` / `reset()` / `_setState()` → 污染生产 API，可能被误用 | 把 cleanup / reset 放进 `test-utils/`，测试 import 它，生产代码不知道 |
| **不理解依赖就 mock** | 把高层方法 mock 掉，但测试逻辑依赖被 mock 方法的副作用 → 测试要么瞎过要么乱挂 | 先用真实现跑一遍看测试需要什么副作用，再在**更低层**（外部网络调用、文件 IO、慢操作）打 mock |
| **不完整 mock** | mock 响应只填测试用到的字段，下游代码访问别的字段就崩 | mock 镜像真实数据结构**完整**字段；不确定的字段查文档 / 例子，宁可多填 |

发现自己在写以上任意一种 → 停下，删掉这块测试，按"怎么做对"重写。

## 自检清单（与 task-executor 失败判定挂钩）

commit 前自检：

- [ ] 每条 acceptance 都看到对应测试**先红后绿**？
- [ ] 没有"先写代码后补测试"的情况？
- [ ] 项目原有测试仍全部通过？
- [ ] 没为通过测试加 acceptance 范围外的功能？
- [ ] 没断言 mock 行为？
- [ ] 没给生产代码加 test-only API？
- [ ] mock 都完整覆盖了真实数据结构？

任一不满足 → 回到对应步骤，**不要硬撑着 commit**。任一不满足意味着 task-executor 硬规则 #7 + 失败判定都不通过，应返回 `status: "failed"`。

## 红旗：停下并重来

看到这些信号说明你已经偏离 TDD，**全部重来**：

- 写了代码才发现"哦还得写测试"
- 测试瞬间通过没看见红
- 改测试让它通过（而不是改代码）
- 心里想"这个 task 简单，跳过 TDD"
- 心里想"先实现再写测试也行"
- 心里想"已经写了 30 分钟代码，删了可惜"

最后一条特别要警惕：**沉没成本不是理由**。已经写的代码删掉重来，比留着假测试给后面埋雷便宜。

## 边界（与 task-executor 其他硬规则的关系）

- **DESIGN.md 的测试框架选型 > 本 skill 的通用建议**：项目用 jest 还是 vitest、pytest 还是 unittest，以 DESIGN.md / PROJECT.md 写明的为准，本 skill 只给节奏，不替你选框架
- **acceptance > 测试覆盖野心**：本 skill 鼓励"测真行为、覆盖边界"仅适用于 acceptance 涵盖的行为；不要为了"测试覆盖更全"补 acceptance 范围外的测试，那是别的 task 的事
- **README 同步仍由 task-executor 硬规则 #2 管**：测试代码不算模块对外接口，但本 task 让模块的对外行为变了，README 仍要更新
- **commit 边界仍由 task-executor 硬规则 #4 管**：测试文件和产品代码在**同一个** commit 里（同属本 task），但**不要**把无关改动一起 commit
