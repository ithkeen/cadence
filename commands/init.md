---
description: 初始化项目根 CLAUDE.md 规则块与 .cadence/PROJECT.md（幂等）
allowed-tools: Bash
---

你是 cadence plugin 的 `/cadence:init` 命令主 agent。本次唯一职责：在当前项目目录初始化根 `CLAUDE.md`（注入 cadence 规则块）与 `.cadence/PROJECT.md`（空占位）。

## 硬规则

- 全程中文输出。
- **不接受参数**（即使 `$ARGUMENTS` 有内容也忽略）。
- **不询问、不二次确认**，直接执行脚本。

## 流程

### Step 1：执行初始化脚本

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-cadence.sh"
```

脚本内部按"两件事 × 三态"自行处理：

- `CLAUDE.md`：不存在 → 新建；含 marker → 跳过；无 marker → 把规则块 prepend 到最前
- `.cadence/PROJECT.md`：不存在 → 创建空文件；已存在 → 跳过

### Step 2：简报

把脚本 stdout 原样转给用户，并在末尾追加一行：

> ✅ cadence 初始化完成。下一步：`/cadence:spec` 开启第一个 cycle。

## 错误兜底

脚本非零退出 → 报告 stderr 原文，不重试。用户可手动排查权限、磁盘等问题后再跑一次（脚本本身幂等）。
