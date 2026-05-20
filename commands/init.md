---
description: 初始化项目根 CLAUDE.md 规则块（幂等）
allowed-tools: Bash
---

执行初始化脚本，把脚本输出原样转给用户，末尾追加：

> ✅ cadence 初始化完成。下一步：`/cadence:spec` 开启第一个 cycle。

脚本非零退出则报告 stderr 原文，不重试。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-cadence.sh"
```
