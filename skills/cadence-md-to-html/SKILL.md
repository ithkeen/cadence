---
name: cadence-md-to-html
description: 将 Markdown 按 Cadence Stencil & Tablet 设计系统渲染成单文件 HTML。Use when the user asks to render, visualize, share, or present a markdown document as HTML with Cadence.
---

# Cadence Markdown To HTML

Render one Markdown document into a standalone HTML file using the plugin assets:

- `assets/html-design/template.html`
- `assets/html-design/components.md`
- `assets/html-design/composition.md`

Resolve those paths relative to the Cadence plugin root. If the installed skill path is available, the plugin root is two directories above this `SKILL.md`.

## Workflow

1. Read `composition.md`, `components.md`, then `template.html`.
2. Read the input Markdown.
3. Classify the document type: spec, research note, tutorial, memo, longform, or other.
4. Preserve every fact, data point, conclusion, and list item. Reorder and compress wording only when meaning is preserved.
5. Map sections to the design-system components from the references.
6. Write the requested HTML path, creating its parent directory if needed.

## Hard Rules

- Output Chinese status messages.
- Do not add new facts.
- Do not drop qualifiers such as "仅", "除...外", "在 X 条件下", or "大多数".
- Preserve original images and image paths.
- Escape user text for HTML; keep Mermaid source raw inside `<pre class="mermaid">`.
- Do not introduce new visual components or palettes outside the design-system files.

Return `✅ HTML 已渲染：<输出路径>` on success, or `❌ 渲染失败：<原因>` on failure.
