---
name: cadence-run
description: Cadence 实施编排工作流，读取 may 设计文档，生成 phase 文件并按依赖顺序逐个 TDD 实现。Use when the user says cadence:run, /cadence:run, 执行 may 文档, or asks to run a Cadence may-*.md into code.
---

# Cadence Run

Turn one `may-*.md` design document into code.

## Locate Input

The user must provide a may document path.

- If missing, respond: `❌ 缺少 may 文档路径。用法：cadence:run <may-主题.md 路径>`
- If unreadable, respond: `❌ 路径不可读：<path>`
- `output_dir` is the may document directory.

## Flow

1. Use `cadence-plan-phases` to generate `phaseN.md` files in `output_dir`.
2. If planning fails or bails, relay the reason and stop.
3. Read the generated phase list.
4. Implement phases serially in dependency order using `cadence-implement-phase`.
5. Do not parallelize phase implementation. Later phases share the same worktree and may depend on earlier changes.
6. If a phase fails, stop and do not run dependent later phases.

Codex version note: do this inline in the current Codex session by default. Only use Codex sub-agents when the user explicitly asks for sub-agent delegation and the available tool policy allows it.

## Final Summary

```text
✅ <主题>：<done>/<total> 个 phase 完成
- Phase 1 <主题>：completed
- Phase 2 <主题>：failed: <原因>（依赖它的后续 phase 未执行）
```
