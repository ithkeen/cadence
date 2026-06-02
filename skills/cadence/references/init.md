---
description: 初始化项目根 AGENTS.md 规则块（幂等）
---

运行 Codex 初始化脚本和 agent 安装脚本，把脚本输出原样转给用户，末尾追加：

> ✅ cadence 初始化完成。下一步：`cadence:pai` 开启第一个 cycle。

脚本非零退出则报告 stderr 原文，不重试。

```bash
bash "<插件根目录>/scripts/init-cadence-codex.sh"
bash "<插件根目录>/scripts/install-codex-agents.sh"
```

`<插件根目录>` 是包含 `.codex-plugin/plugin.json`、`skills/`、`scripts/` 的目录。若无法确定插件根目录，先在当前仓库内用 `rg --files | rg 'scripts/init-cadence-codex\.sh$|scripts/install-codex-agents\.sh$'` 定位。
