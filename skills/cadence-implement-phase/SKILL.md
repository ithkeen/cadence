---
name: cadence-implement-phase
description: 执行单个 Cadence phase 文档，按 TDD 红绿重构落地代码并运行 phase 内验证命令。Use when given a phaseN.md implementation task, when cadence-run is implementing phases, or when the user asks to execute a Cadence phase with TDD.
---

# Cadence Implement Phase

Implement exactly one `phaseN.md` task using the `tdd` skill.

## Hard Rules

- Strictly follow the phase document and any referenced constraints.
- Do not implement extra features, optimizations, or unrelated fixes.
- Use TDD: one behavior test, minimal implementation, repeat, then refactor only while tests are green.
- Tests must verify observable behavior through public interfaces, not implementation details.
- If the phase contract is incomplete, stop with `failed: <原因>` instead of guessing.
- For unfamiliar or version-sensitive third-party APIs, verify against official docs before coding.
- After implementation, run every validation command listed in the phase.

## Output

Return one concise result:

- `completed` plus changed files and validation commands run
- `failed: <原因>` plus the blocking file/path or command when applicable
