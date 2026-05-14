---
description: 归档当前 cycle，更新项目档案 PROJECT.md 并清空 CURRENT
allowed-tools: Read, Write, Edit, Bash
---

你是 cadence plugin 的 `/cadence:archive` 命令主 agent。本次唯一职责：把当前 cycle 的项目级变化合并进 `.cadence/PROJECT.md`，清空 CURRENT。

## 硬规则

- 全程中文输出。
- **唯一产物是 `.cadence/PROJECT.md`**（不生成 RECAP / HTML / 任何新文件）
- **不维护模块 `<module>/README.md`**（那是 `/cadence:run` 子 agent 的事）；**不修改 cycle 目录内任何文件**
- **全信任直接写入**：merge 完成直接写 PROJECT.md，**不展示 diff、不让用户确认**
- **不允许强制归档**：任何 ❌ 都拦截

## 启动前置检查（按顺序）

### 1. 检测当前 cycle

Read `.cadence/CURRENT`：
- 不存在 / 内容为空 → 报错退出：`❌ 当前没有进行中的 cycle，无需归档。`
- 非空 → trim 后作为 `<cycle-dir>`

### 2. 检测 RUN-STATE.md

Read `.cadence/<cycle-dir>/RUN-STATE.md`：
- 不存在 → 报错退出：`❌ 当前 cycle <cycle-dir> 尚未执行（缺少 RUN-STATE.md）。请先 /cadence:run。`
- 存在 → 进 Step 3

### 3. 校验所有 task ✅

解析 RUN-STATE.md。任一 ❌ / 🔄 / ⏳ → 报错退出，列出未完成 task：

> ❌ 归档失败：以下 task 仍未完成
> - `T5`：<状态> — <原因摘要>
>
> 请先 `/cadence:run`（增量模式自动重试 ❌、跳过 ✅），全部 ✅ 后再归档。

全部 ✅ → 进主流程。

## 主流程

### Step 1：读上下文（并行 Read）

- `.cadence/<cycle-dir>/REQUIREMENT.md`
- `.cadence/<cycle-dir>/DESIGN.md`
- `.cadence/<cycle-dir>/RUN-STATE.md`
- `.cadence/PROJECT.md`（不存在视为创建模式）

### Step 2：内存 merge 出新 PROJECT.md

提取本 cycle 的**项目级变化**（不关心执行过程，只关心结果）：

- **技术栈**：新依赖？升级？淘汰？
- **模块地图**：新增？职责调整？拆并？
- **视觉契约**（仅前端 cycle）：DESIGN.md 是否含 `## 视觉契约` 段？
  - 写明"沿用 PROJECT.md 的视觉契约" → PROJECT.md 视觉契约段**保持不动**
  - 含完整契约表（5 字段） → 首次建立，**整段写入** PROJECT.md
  - 无该段（非前端 cycle） → PROJECT.md 视觉契约段**保持不动**

合并到 PROJECT.md 对应章节。已存在条目被推翻 → **更新或删除**而非追加。

> **视觉契约只增不改**：一旦在 PROJECT.md 立住，后续 cycle 一律沿用。用户想换风格需手动改 PROJECT.md，不是 archive 的职责。

### Step 3：写 PROJECT.md

用 **Write 整体重写**（文件不大、merge 是全量推导，重写最简洁）。如果现有 PROJECT.md 极长且本次仅小范围增删，也可 Edit 局部修订；默认走 Write。

#### PROJECT.md 模板

```markdown
# 项目档案

> <一句话项目定位 —— 是什么、给谁、解决什么>

## 技术栈
- 语言、框架、关键依赖、版本（只列对架构有影响的）
- **测试框架与运行命令**（如 `jest` + `npm test`、`pytest` + `pytest`、`go test ./...`）；项目尚无测试基础设施则**显式写**「暂无测试基础设施」，不能省略——下一个 cycle 的 design 会以此判断要不要追问

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

## 视觉契约
<!-- 仅前端项目存在；非前端整段省略。首个前端 cycle 写入，后续沿用，archive 不再改动 -->

| 字段 | 取值 |
|---|---|
| 风格基调 | <minimal-refined / editorial / brutalist / playful-soft> |
| 明暗主调 | <浅色 / 深色 / 跟随系统> |
| 主导色色系 | <冷色系 / 暖色系 / 中性> |
| accent 用途 | <主 CTA / 焦点态 / 关键状态指示，多选> |
| 字体倾向 | <无衬线 / 衬线 / 等宽 / 显示型> |
```

#### 写作原则

- **H1 用通用标题"项目档案"**，不用项目名
- **当前真相**：只写"现在是什么"，不写历史叙事（不要"原本是 X，本 cycle 改成了 Y"）
- 模块表通过 README 链接让读者按需深入；不写"已实现功能"章节
- 章节为空时**省略整段**（不要保留空标题）

### Step 4：清空 CURRENT

Bash `: > .cadence/CURRENT` 截断文件为空。

> 不要用 Write 写空 content——Claude Code 的 Write 校验器把 `content: ""` 判为参数缺失，会反复失败。

### Step 5：简报

> ✅ Cycle `<cycle-dir>` 已归档：
> - PROJECT.md 已更新
> - CURRENT 已清空
>
> 下一步：开始下一个 cycle 时运行 `/cadence:spec`。

## 错误兜底

- Step 1 任一文件读取失败（除 PROJECT.md 不存在为预期）→ 报错退出，不强行 merge
- Write PROJECT.md 失败 → 报告错误，**不清空 CURRENT**（保留现场）
- 截断 CURRENT 失败 → 提醒用户"PROJECT.md 已更新，需手动清空 `.cadence/CURRENT`"
