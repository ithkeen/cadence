---
name: commit-message
description: Write standardized English commit messages for code changes. Use when the user asks to commit, push, create, draft, polish, review, or normalize commit messages, including Chinese requests about git commit information or commit style.
---

# Commit Message

Generate English commit messages that follow Cadence's concise Conventional Commit style. Apply this whenever the user asks to commit, push, or prepare a commit message.

## Format

Use this structure:

```text
type(scope): imperative summary

Body sentence or short paragraph explaining the meaningful behavior change.
```

- Write the entire commit message in English, even when the request or examples are Chinese.
- Use common types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `build`, `ci`.
- Use a scope when a clear subsystem, command, skill, package, or document area exists.
- Write the summary in imperative present tense, with no trailing period.
- Keep the body focused on user-visible behavior, workflow, contract, or architectural changes. Do not list files unless the file name is the product surface.
- Use one body paragraph for normal commits; use bullets only when separate changes would be hard to read as a paragraph.
- Do not add issue IDs, co-author lines, generated-by lines, or emojis unless the user explicitly asks.

## Workflow

1. Inspect the relevant diff before writing the message. Prefer staged changes for an actual commit; use the requested diff when the user provides one.
2. Choose the narrowest accurate type and scope.
3. Summarize the primary intent in the header.
4. Use the body to explain what changed and why it matters, not how every file changed.
5. If the user asks to commit or push, use the generated message as the commit message and continue only within the user's requested git action.

## Examples

```text
feat(run): add plan-agent and code-executor orchestration

Route run execution through plan-agent phase splitting and code-executor implementation, removing the retired frontend-executor path from the workflow.
```

```text
refactor(plan-agent): split may docs into phase task files

Change plan-agent from a single plan.yaml output to self-contained phase files derived from may documents, so each phase can be handed directly to code-executor.
```

```text
docs(rules): add subagent prompt and description guidelines

Tighten the guidance for concise prompts and description-owned routing context, then define the required subagent description fields.
```
