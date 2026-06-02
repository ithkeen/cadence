---
name: cadence-research
description: Cadence 外部资料调研工作流，查询外部库、API、SDK、标准、法规、模型 API 或多方案对比，产出可信中文调研笔记到 .cadence/research。Use when Cadence pai/may needs web research or the user asks cadence research for external facts.
---

# Cadence Research

Research one external topic and write a Chinese note under the requested output directory, normally `.cadence/research/`.

## Scope

Use for external libraries, APIs, SDKs, standards, regulations, model APIs, version-sensitive behavior, breaking changes, or multi-option comparisons. Do not use for internal repository exploration.

## Rules

- Output Chinese.
- Research only the topic. Do not expand into implementation decisions outside the topic.
- Prefer official docs, standards, RFCs, and vendor docs.
- For technical questions, rely on primary sources whenever possible.
- Search snippets are only discovery clues; fetch/read the source before using a fact.
- Version-sensitive facts must include version and date.
- If a fact cannot be confirmed from authoritative sources, mark it as unconfirmed instead of inventing it.
- Write only the research note file, not project code.

## Depth

- L1: one fact, 1-2 authoritative sources.
- L2: comparison or configuration guide, each option backed by official docs.
- L3: unfamiliar domain, compliance, or many subquestions.

Choose the smallest sufficient depth unless the user specifies one.

## Output Format

Create `<output_dir>/<topic-slug>.md`:

```markdown
# <topic 的中文标题>

> topic：<topic 原文> | 档位：<L1 / L2 / L3> | 日期：<YYYY-MM-DD>

## 一句话结论
<最直接、能回答 topic 的结论>

## 关键事实
- ✅ <事实，附版本 / 限制 / 注意点>
- ⚠️ <单一官方源事实，未交叉验证>
- ❓ <未在权威源找到或存疑的事实>

## 取舍对比
<!-- 如适用 -->

## 已尝试但未找到
<!-- 如适用 -->

## 引用来源
- [<标题>](<URL>) — <来源类型>，<YYYY-MM-DD> 抓取
```

Return:

```text
✅ 调研完成：<产物完整路径>
档位：<L1 / L2 / L3>
摘要：<一句话核心结论>
```

If no credible source can be found, do not write a file. Return `❌ 调研未成功：<原因>`.
