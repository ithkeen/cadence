---
name: cadence
description: Cadence 的 Codex 总入口。Use when the user says cadence:init, cadence:pai, cadence:pai-with-md, cadence:may, cadence:run, cadence research, cadence code review, or asks to use Cadence in Codex.
---

# Cadence

You are the Codex entry point for Cadence. Cadence is a Chinese, explicit-stage development workflow:

1. `cadence:init` injects project rules.
2. `cadence:pai` clarifies requirements and writes `pai-<主题>.md`.
3. `cadence:pai-with-md` reviews and revises an existing `pai-*.md`.
4. `cadence:may` turns a `pai-*.md` into a technical design `may-<主题>.md`.
5. `cadence:run` plans phases from `may-*.md` and implements them serially.

Output Chinese unless a command or source format requires otherwise.

## Resolve Paths

Resolve the Cadence plugin root relative to this `SKILL.md`: the plugin root is two directories above `skills/cadence/SKILL.md`.

Internal references live under `skills/cadence/references/`. Read only the reference needed for the requested action, plus any reference it names.

## Route Requests

- `cadence:init`, `初始化 cadence` → read `references/init.md`.
- `cadence:pai`, `开启需求 cycle`, `梳理需求边界` → read `references/pai.md`.
- `cadence:pai-with-md`, `cadence 需求复审`, `复审 pai` → read `references/pai-review.md`.
- `cadence:may`, `技术设计`, `pai 转 may` → read `references/may.md`.
- `cadence:run`, `执行 may`, `may 跑成代码` → read `references/run.md`; it will also need `references/plan-phases.md` and `references/implement-phase.md`.
- `cadence research`, `cadence-research`, external library/API/SDK/standard research → read `references/research.md`.
- `cadence code review`, `cadence-code-review`, code review requests → read `references/code-review.md`.
- `cadence md-to-html`, render/visualize/share markdown as HTML → read `references/md-to-html.md`.

If the user asks for a Cadence action that is not listed, say which actions are supported and ask for the missing input if needed.

## Boundaries

- This is the only Codex-facing Cadence skill. Do not ask the user to invoke `cadence-pai`, `cadence-may`, or other removed per-command skills.
- Do not install files into `~/.agents/skills`, `~/.codex/agents`, or any home directory unless the user explicitly asks for a separate local installation workflow.
- For `cadence:run`, implement phases inline in the current Codex session by default. Only use Codex subagents if the user explicitly asks for subagent delegation.
- Preserve Cadence's stage boundaries: `pai` discusses what to build, `may` discusses how to build it, and `run` changes code.
