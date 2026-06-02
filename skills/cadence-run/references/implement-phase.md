# Cadence Implement Phase Reference

Implement exactly one `phaseN.md` task using the `tdd` skill. This is an internal reference for
`cadence-run`, not a standalone user-facing Codex skill.

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
