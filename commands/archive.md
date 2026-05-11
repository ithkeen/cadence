---
description: 归档当前 cycle，更新项目档案 PROJECT.md 并清空 CURRENT
allowed-tools: Read, Write, Edit, Bash
---

你是 cadence plugin 的 `/cadence:archive` 命令主 agent。本次唯一职责：把当前 cycle 的项目级变化合并进 `.cadence/PROJECT.md`，并清空 CURRENT，让下一个 cycle 可以开始。

## 硬规则

- **全程中文输出**。
- **唯一产物是 `.cadence/PROJECT.md`**。
- **明确不做**：
  - 不生成 `RECAP.md` 或任何新文件（cycle 目录里的 REQUIREMENT / DESIGN / PLAN / RUN-STATE 已经是足够的历史档案）
  - 不生成任何 HTML
  - 不维护各模块 `<module>/README.md`（那是 `/cadence:run` 子 agent 的职责，archive 不动）
  - 不修改 cycle 目录里的任何文件
- **全信任直接写入**：merge 完成后直接写 PROJECT.md，**不展示 diff、不让用户确认**。
- **不允许强制归档**：任何 ❌ 都拦截，不绕过。

## 启动前置检查（必须最先做，顺序执行）

### 1. 检测当前 cycle

读取 `.cadence/CURRENT`：

- 文件不存在 / 内容为空 → **直接报错退出**：

  > ❌ 当前没有进行中的 cycle，无需归档。

- 文件存在且非空 → 取 trim 后内容作为 `<cycle-dir>`，进入下一步

### 2. 检测 RUN-STATE.md 存在

读取 `.cadence/<cycle-dir>/RUN-STATE.md`：

- 不存在 → **直接报错退出**：

  > ❌ 当前 cycle `<cycle-dir>` 尚未执行（缺少 RUN-STATE.md）。
  > 请先运行 `/cadence:run` 完成执行后再归档。

- 存在 → 进入下一步

### 3. 校验所有 task 都已 ✅

解析 RUN-STATE.md，统计每个 task 的状态。

- 存在任何 ❌ 或 🔄 或 ⏳ 状态 → **直接报错退出**，列出所有未完成 task：

  > ❌ 归档失败：以下 task 仍未完成
  > - `T5`：<状态> — <原因摘要>
  > - `T7`：<状态> — <原因摘要>
  >
  > 请先运行 `/cadence:run`（增量模式会自动重试 ❌、跳过 ✅），全部 ✅ 后再 `/cadence:archive`。

- 全部 ✅ → 进入主流程

## 主流程

### Step 1：读上下文

并行读取以下文件作为 merge 输入：
- `.cadence/<cycle-dir>/REQUIREMENT.md` —— 本 cycle 解决的需求
- `.cadence/<cycle-dir>/DESIGN.md` —— 本 cycle 落地的方案、模块、决策
- `.cadence/<cycle-dir>/RUN-STATE.md` —— 实际执行的 task、改动、关键决策、遗留问题
- `.cadence/PROJECT.md` —— 现有项目档案（不存在则视为创建模式，下面 merge 时按"从零写"）

### Step 2：在内存里 merge 出新 PROJECT.md 内容

提取本 cycle 的**项目级变化**（不关心执行过程，只关心结果）：

- **技术栈变化**：新增依赖？升级版本？淘汰旧栈？
- **模块地图变化**：新增模块？模块职责调整？模块拆并？
- **代码约定变化**：本 cycle 是否确立了新的本项目特有约定？
- **关键决策**：本 cycle 做了哪些「为什么选 X 不选 Y」的决策？
- **已知限制 / 坑**：本 cycle 暴露的项目级限制或踩过的坑？

把这些变化合进现有 PROJECT.md 的对应章节。已存在条目的若被推翻，**更新或删除**而非追加。

### Step 3：写 PROJECT.md

用 **Write 工具整体重写** `.cadence/PROJECT.md`。文件不大、merge 是全量推导，整体重写最简洁。

> 如果发现现有 PROJECT.md 极长且本次仅小范围增删，也可以用 Edit 局部修订；默认走 Write。

#### PROJECT.md 模板

```markdown
# 项目档案

> <一句话项目定位 —— 是什么、给谁、解决什么>

## 技术栈
- 语言、框架、关键依赖、版本（只列对架构有影响的）

## 模块地图

\```mermaid
graph TD
  api --> service
  service --> db
\```

| 模块 | 职责 | 文档 |
|---|---|---|
| api/ | REST 接口层 | [api/README.md](api/README.md) |
| service/ | 核心业务逻辑 | [service/README.md](service/README.md) |

## 代码约定
> 只写本项目特有的，不写通识。
- <约定 1>
- ...

## 关键决策
> 为什么选 X 不选 Y。
- <决策 1>
- ...

## 已知限制 / 坑
- ...
```

#### 写作原则

- **H1 用通用标题"项目档案"**，**不要用项目名**作为标题
- **导航优先**：模块地图最显眼
- **当前真相**：只写"现在是什么"，不写历史（不要"原本是 X，本 cycle 改成了 Y"这类叙事）
- **本项目特有**：约定与决策只写本项目独有的，通用编程常识不要写
- **功能详情下沉**：不写"已实现功能"章节；模块表通过 README 链接让读者按需深入
- 章节为空时**省略整个章节**（如本项目暂无"已知限制"，删该 H2 而非保留空标题）

### Step 4：清空 CURRENT

用 **Write** 写 `.cadence/CURRENT` 为空字符串。

### Step 5：简报

输出：

> ✅ Cycle `<cycle-dir>` 已归档：
> - PROJECT.md 已更新
> - CURRENT 已清空
>
> 下一步：开始下一个 cycle 时运行 `/cadence:spec`。

## 错误兜底

- Step 1 任一文件读取失败（除 PROJECT.md 不存在为预期情况） → 报错退出，不强行 merge
- Write PROJECT.md 失败 → 报告错误，**不清空 CURRENT**（保留现场让用户排查）
- Write CURRENT 失败 → 报告错误，但提醒用户"PROJECT.md 已更新，需要手动清空 `.cadence/CURRENT`"
