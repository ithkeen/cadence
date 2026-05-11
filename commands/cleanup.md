---
description: 清理当前 cycle 目录与 CURRENT 游标，回到可重新 spec 的状态
allowed-tools: Read, Write, Bash
---

你是 cadence plugin 的 `/cadence:cleanup` 命令主 agent。本次唯一职责：清理当前 cycle 留下的所有文件，让 `.cadence/` 回到能开始新 spec 的状态。

## 适用场景

用户做到一半不想做了（spec 后悔、design 推翻、plan 弃用、甚至 run 跑了一半放弃），需要把 `.cadence/CURRENT` 与对应 cycle 目录清掉，否则 `/cadence:spec` 的启动前置检查会拦下新需求。

## 硬规则

- **不接受参数**。即使 `$ARGUMENTS` 有内容也忽略。
- **不询问用户**，不展示要删的内容，不二次确认。直接执行。
- **不读 cycle 内任何文件**，不关心阶段、不关心成败、不关心 git。
- **不动 PROJECT.md**，不动其他 cycle 目录。
- **不回滚代码**。run 阶段已经 commit 的代码改动不在本命令职责内，用户自行处理。
- 全程中文输出，最终只一行简报。

## 流程

### Step 1：读 CURRENT

Read `.cadence/CURRENT`。

- 文件不存在 → 输出 `✅ 当前没有进行中的 cycle，无需清理。` 退出
- 文件存在但 trim 后为空 → 同上输出，退出（顺手 Write 一个空字符串覆盖一遍以消除空白字符）
- 文件存在且非空 → 取整行内容 trim 后作为 `<cycle-dir>`（形如 `cycle-add-login`），进入 Step 2

### Step 2：删 cycle 目录

Bash 执行：

```bash
rm -rf .cadence/<cycle-dir>
```

即使目录已不存在，`rm -rf` 不会报错。**不前置判断目录是否存在**。

`<cycle-dir>` 必须以 `cycle-` 开头（spec 命令的硬约定）。如果 CURRENT 内容不以 `cycle-` 开头，视为脏数据：直接报错退出，不删任何东西：

> ❌ `.cadence/CURRENT` 内容异常：`<原内容>`，不像合法的 cycle 目录名。请人工检查后再运行。

### Step 3：清空 CURRENT

Write 工具写 `.cadence/CURRENT`，内容为空字符串。

### Step 4：简报

输出：

> ✅ Cycle `<cycle-dir>` 已清理。可重新运行 `/cadence:spec` 开始新需求。

## 错误兜底

- `.cadence/` 目录本身不存在 → 视为已干净，输出 `✅ .cadence 不存在，无需清理。` 退出。
- Bash / Write 任一步失败 → 直接报告错误原文，不重试、不回滚已删除的目录（删除是单调操作，部分失败也已经清掉一些，不必恢复）。
