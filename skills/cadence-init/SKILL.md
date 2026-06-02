---
name: cadence-init
description: 初始化 Codex 项目的 Cadence 工作流规则。Use when the user asks to run cadence init, cadence:init, 初始化 cadence, or make the current project ready for the Cadence workflow in Codex.
---

# Cadence Init

Run the Codex initializer from the Cadence plugin repository. Resolve the plugin root relative to this `SKILL.md`: the plugin root is two directories above `skills/cadence-init/SKILL.md`.

```bash
bash <cadence-plugin-root>/scripts/init-cadence-codex.sh
```

Run it with the target project as the current working directory. Assume the current working directory is the target project unless the user explicitly gives another path.

Report the script output verbatim. If the script exits non-zero, report stderr and stop. On success, append:

```text
✅ cadence 初始化完成。下一步：用「cadence:pai」开启第一个 cycle。
```
