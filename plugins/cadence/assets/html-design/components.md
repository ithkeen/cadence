# Stencil & Tablet — 组件片段清单

> **来源**：本文件每一段 HTML 都是从 `template.html` 中直接抽出的、已渲染验证过的结构。
> **样式来源**：所有视觉规则在 `template.html` 内的 `<style>` 块里。本文件**不携带任何 CSS**。
> **使用方式**：复制片段 → 替换 `{{占位符}}` → 粘到 `<main class="main">` 内的对应位置。

---

## 使用规则（违反即破坏设计）

1. **禁止**修改任何 `class="..."` 的值（包括变体后缀如 `tablet--orange`）
2. **禁止**写 `style="..."` inline 样式
3. **禁止**新增 `<link rel="stylesheet">` 或额外 `<style>` 块
4. **禁止**嵌套未在本清单中出现过的组合（例如 tablet 套 tablet）
5. **必须**对填入占位符的用户内容做 HTML 转义：`&` → `&amp;`、`<` → `&lt;`、`>` → `&gt;`、`"` → `&quot;`
6. **必须**保持 TOC 的 `<a href="#xxx">` 与正文章节的 `id="xxx"` 同步
7. 中文内容**必须**给容器加 `lang="zh"`，否则不会切到 Noto Serif SC

---

## 0. 页面骨架（每篇文档只用一次）

整页只有这一个最外层结构。所有内容组件都放在 `<main class="main">` 内。

```html
<div class="page">

  <!-- TOC（目录）：见 §1 -->
  <nav class="toc" aria-label="Table of contents">...</nav>

  <main class="main">
    <!-- 封面：见 §2 -->
    <!-- 章节、组件、段落：见 §3 起 -->
    <!-- 页脚：见 §13 -->
  </main>

</div>
```

---

## 1. TOC 目录

**何时用**：每篇文档恰好一次，放在 `<main>` 之前。
**占位符**：每条目录项替换编号 `{{NUM}}` 与文字 `{{LABEL}}`，`href` 必须与正文章节 `id` 一致。

```html
<nav class="toc" aria-label="Table of contents">
  <p class="toc__label">Contents</p>
  <ul class="toc__list">
    <li><a href="#{{ID}}"><span class="toc__num">{{NUM}}</span><span>{{LABEL}}</span></a></li>
    <li><a href="#{{ID}}"><span class="toc__num">{{NUM}}</span><span>{{LABEL}}</span></a></li>
    <!-- 重复 N 条 -->
  </ul>
</nav>
```

---

## 2. 封面 cover

**何时用**：文档开头一次。
**占位符**：`{{SUPER}}` 副标签（卷号/日期/版本）、`{{HERO}}` 文档大标题、`{{LEAD}}` 一句话简介、`{{NAME}}` 文档身份名、`{{DATE}}` 日期。

```html
<header class="cover">
  <p class="cover__super">{{SUPER}}</p>
  <h1 class="cover__hero">{{HERO}}</h1>
  <p class="lead">{{LEAD}}</p>
  <div class="cover__lockup">
    <span class="cover__mark" aria-hidden="true"></span>
    <span class="cover__name">{{NAME}}</span>
    <span class="cover__date">{{DATE}}</span>
  </div>
</header>
```

`{{HERO}}` 内可以用 `<br>` 手动换行控制断字。

---

## 3. 章节分隔条 section divider

**何时用**：每个大章节开始前可选放一条，强化视觉层级。短文档可以不用。
**占位符**：`{{NUM}}` 章节编号（建议两位数字）、`{{EYEBROW}}` 章节小标签、`{{HEADLINE}}` 章节标题。

```html
<div class="section-divider">
  <span class="section-divider__num">{{NUM}}</span>
  <div class="section-divider__body">
    <p class="section-divider__eyebrow">{{EYEBROW}}</p>
    <p class="section-divider__headline">{{HEADLINE}}</p>
  </div>
</div>
```

---

## 4. 章节包装 section

**何时用**：每个 H2 级章节包一层 `<section>`，给 `id` 让 TOC 可以跳。

```html
<section id="{{ID}}">
  <h2>{{H2_TITLE}}</h2>
  <p>{{BODY_PARAGRAPH}}</p>
  <!-- 任意组件 -->
</section>
```

---

## 5. 正文基础排版

直接用 HTML 标签即可，无需 class。**严禁**用 `<div>` 包正文。

```html
<h2>{{H2_TITLE}}</h2>
<h3>{{H3_TITLE}}</h3>
<h4>{{H4_TITLE}}</h4>

<p class="lead">{{LEAD_PARAGRAPH}}</p>      <!-- 章节首句，22px -->
<p>{{BODY_PARAGRAPH}}</p>                   <!-- 默认段落，18px -->

<ul>
  <li>{{ITEM}}</li>
  <li>{{ITEM}}</li>
</ul>

<ol>
  <li>{{ITEM}}</li>
  <li>{{ITEM}}</li>
</ol>

<p>这是一段含 <strong>加粗</strong> 和 <a href="{{URL}}">链接</a> 的正文。</p>
```

---

## 6. TL;DR 摘要框 action bar

**何时用**：章节开头放要点摘要。每页最多 1–2 个，过度使用会噪。
**占位符**：`{{TAG}}` 类别标签（如 "TL;DR"、"Heads up"、"Note"）、`{{HEADLINE}}` 一句话总结、列表项可选。

```html
<aside class="action-bar">
  <div class="action-bar__head">
    <span class="action-bar__tag">{{TAG}}</span>
    <span class="action-bar__sep" aria-hidden="true"></span>
    <h3 class="action-bar__headline">{{HEADLINE}}</h3>
  </div>
  <ul>
    <li>{{POINT}}</li>
    <li>{{POINT}}</li>
    <li>{{POINT}}</li>
  </ul>
</aside>
```

`<ul>` 段可整段删除，只留 headline 也成立。

---

## 7. Tablet 卡片（callout）

**何时用**：成组陈列要点、原则、模块。**单独 1 块视觉显薄**，建议 2 块或 4 块成组。
**色彩语义**（来自 design-html.md 的 matrix pill 公约外推）：
- `tablet--orange`：主要 / takeaway
- `tablet--teal`：成功 / 正面
- `tablet--magenta`：警示 / 反例 / 强声明
- `tablet--mustard`：提醒 / 注意
- `tablet--sienna` / `--blue` / `--olive`：补色变化
- `tablet--paper`：中性、最低视觉权重

### 7a. 单个 tablet

**占位符**：`{{NUMERAL}}` 通常是数字或单个汉字、`{{HEADLINE}}` 卡片标题、`{{BODY}}` 一两句正文。
**变体**：把 `tablet--orange` 换成上面任一变体名。

```html
<article class="tablet tablet--orange">
  <span class="tablet__numeral">{{NUMERAL}}</span>
  <h4 class="tablet__headline">{{HEADLINE}}</h4>
  <p class="tablet__body">{{BODY}}</p>
</article>
```

### 7b. Tablet 2 列网格

**何时用**：2 / 4 / 6 块成组陈列。

```html
<div class="tablet-row">
  <article class="tablet tablet--orange">
    <span class="tablet__numeral">{{NUMERAL}}</span>
    <h4 class="tablet__headline">{{HEADLINE}}</h4>
    <p class="tablet__body">{{BODY}}</p>
  </article>
  <article class="tablet tablet--teal">
    <span class="tablet__numeral">{{NUMERAL}}</span>
    <h4 class="tablet__headline">{{HEADLINE}}</h4>
    <p class="tablet__body">{{BODY}}</p>
  </article>
  <!-- 继续重复，建议总数为偶数 -->
</div>
```

---

## 8. 统计数字卡片 stat card

**何时用**：陈列数据 / 指标，最多 3 个一组。

### 8a. 单个 stat

**占位符**：`{{NUM}}` 数字、`{{SUFFIX}}` 单位（%、×、K、M，可省）、`{{LABEL}}` 数字含义。

```html
<div class="stat">
  <span class="stat__num">{{NUM}}<span class="stat__suffix">{{SUFFIX}}</span></span>
  <p class="stat__label">{{LABEL}}</p>
</div>
```

### 8b. stat 3 列网格

```html
<div class="stat-row">
  <div class="stat">
    <span class="stat__num">{{NUM}}<span class="stat__suffix">{{SUFFIX}}</span></span>
    <p class="stat__label">{{LABEL}}</p>
  </div>
  <div class="stat">
    <span class="stat__num">{{NUM}}<span class="stat__suffix">{{SUFFIX}}</span></span>
    <p class="stat__label">{{LABEL}}</p>
  </div>
  <div class="stat">
    <span class="stat__num">{{NUM}}<span class="stat__suffix">{{SUFFIX}}</span></span>
    <p class="stat__label">{{LABEL}}</p>
  </div>
</div>
```

---

## 9. 代码块 code

### 9a. 行内代码

```html
<p>使用 <code>{{TOKEN}}</code> 引用变量。</p>
```

### 9b. 多行代码块

**何时用**：除 mermaid 外的所有代码围栏（任意语言或无语言标记）。mermaid 源码走 §14b，**不要**塞进这里。
**占位符**：`{{CODE}}` 内必须做 HTML 转义。

```html
<pre><code>{{CODE}}</code></pre>
```

---

## 10. 矩阵表 matrix table

**何时用**：方案对比、特性对照、能力矩阵。
**占位符**：表头与单元格内容；状态单元用 §11 的 pill。

```html
<table class="matrix">
  <thead>
    <tr>
      <th scope="col">{{COL_HEAD}}</th>
      <th scope="col">{{COL_HEAD}}</th>
      <th scope="col">{{COL_HEAD}}</th>
      <th scope="col">{{COL_HEAD}}</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">{{ROW_LABEL}}</th>
      <td>{{CELL}}</td>
      <td>{{CELL}}</td>
      <td>{{CELL}}</td>
    </tr>
    <!-- 重复行 -->
  </tbody>
</table>
```

---

## 11. 状态 pill（颜色公约固定）

**何时用**：表格单元、行内状态、列表项标记。
**颜色公约**（不要乱用）：
- `pill--yes`：肯定 / 完成 / 支持
- `pill--partial`：部分 / 受限 / 警告
- `pill--no`：否定 / 阻塞 / 不支持
- `pill--note`：注释 / 中性说明

```html
<span class="pill pill--yes">{{LABEL}}</span>
<span class="pill pill--partial">{{LABEL}}</span>
<span class="pill pill--no">{{LABEL}}</span>
<span class="pill pill--note">{{LABEL}}</span>
```

---

## 12. 引用面板 quote panel

**何时用**：pull quote / 重要引语。每篇文档建议 ≤2 次，否则失重。
**占位符**：`{{QUOTE}}` 引文本体（不含引号，引号由组件提供）、`{{ATTRIBUTION}}` 出处。

```html
<figure class="quote-panel">
  <span class="quote-panel__mark" aria-hidden="true">&ldquo;</span>
  <blockquote class="quote-panel__text">{{QUOTE}}</blockquote>
  <figcaption class="quote-panel__attribution">{{ATTRIBUTION}}</figcaption>
</figure>
```

---

## 13. 图片 figure（A 方案 · inline）

**何时用**：正文里的常规配图、截图、示意图。**默认选这一个**。
**占位符**：`{{IMG_SRC}}` 图片地址、`{{ALT}}` 替代文字（无障碍必填）、`{{CAPTION}}` 一行小标题。
**约束**：图片会撑满正文列宽（720px），所以**横图最好 ≥800px 宽**；标题用一行讲清楚，不要写整段。

```html
<figure class="figure">
  <img src="{{IMG_SRC}}" alt="{{ALT}}">
  <figcaption>{{CAPTION}}</figcaption>
</figure>
```

`<figcaption>` 可省略——无标题图也成立。

---

## 14. 图片 figure-tablet（C 方案 · 画框版）

**何时用**：需要强调的关键图（架构图、流程图、产品截图）。**每篇 ≤2 个**，否则失重。比 A 视觉权重重一档。
**占位符**：`{{IMG_SRC}}` 图片地址、`{{ALT}}` 替代文字、`{{LABEL}}` 短编号标签（如 "Fig 01"、"图 1"）、`{{CAPTION}}` 一两句说明文字。
**约束**：横图最好 ≥800px 宽；`{{LABEL}}` 控制在 6 字以内，否则会挤压正文。

```html
<figure class="figure-tablet">
  <img src="{{IMG_SRC}}" alt="{{ALT}}">
  <figcaption>
    <span class="figure-tablet__label">{{LABEL}}</span>
    <span class="figure-tablet__text">{{CAPTION}}</span>
  </figcaption>
</figure>
```

---

## 14b. Mermaid 图 mermaid-figure（画框版 · 浏览器渲染）

**何时用**：markdown 代码围栏的 language 标记为 `mermaid` 时使用。其他语言一律走 §9b。视觉权重与 §14 同档（画框版），**每篇 ≤2 个**，否则失重。
**占位符**：`{{MERMAID_SRC}}` mermaid 源码、`{{LABEL}}` 短编号标签（如 "Fig 02"、"图 2"）、`{{CAPTION}}` 一两句说明文字。
**约束**：
- `{{MERMAID_SRC}}` **原样**写入，**不做** HTML 转义（**覆盖头部使用规则 #5**）；`-->`、`&`、`<` 必须保留，否则 mermaid 解析失败
- `<pre class="mermaid">` 里**不要**再嵌 `<code>`；模板末尾的渲染脚本只识别 `.mermaid` 节点，套了 `<code>` 不会触发
- 图由浏览器 lazy 加载 mermaid@11 ESM 后渲染——离线 / 打印 / 截 PDF 会只剩源码。**重要的关键图请改用 §14 figure-tablet** 贴静态 SVG / PNG
- `{{LABEL}}` 控制在 6 字以内
- Mermaid 是摘要图，不是清单容器；单图控制在 10 个节点、12 条边以内。目录、接口、文件、依赖清单过长时，改用 §10 matrix、§7b tablet-row 或 §5 列表。
- 新生成 Mermaid 时，节点 ID 只用短 ASCII 标识；包含 `/`、`:`、`()、{}`、`[]`、逗号、空格、代码片段或中文的展示文本放进双引号标签，例如 `api["api: HTTP handlers"]`。无法确信语法有效时，不用 Mermaid。

```html
<figure class="mermaid-figure">
  <pre class="mermaid">
{{MERMAID_SRC}}
  </pre>
  <figcaption>
    <span class="mermaid-figure__label">{{LABEL}}</span>
    <span class="mermaid-figure__text">{{CAPTION}}</span>
  </figcaption>
</figure>
```

---

## 15. 页脚 doc footer

**何时用**：每篇文档结尾一次。

```html
<footer class="doc-footer">
  <span>{{LEFT}}</span>
  <span>{{RIGHT}}</span>
</footer>
```

---

## 16. CJK（中文）使用方式

**触发条件**：容器加 `lang="zh"`，自动切到 Noto Serif SC、行高 1.8、字距 0。

```html
<h2 lang="zh">{{中文标题}}</h2>
<p lang="zh">{{中文段落，中英混排在 <strong>使用 Stencil 2026</strong> 之间自然留盘古之白}}</p>

<article class="tablet tablet--orange">
  <span class="tablet__numeral" lang="zh">一</span>
  <h4 class="tablet__headline" lang="zh">{{中文标题}}</h4>
  <p class="tablet__body" lang="zh">{{中文正文}}</p>
</article>
```

**注意**：
- 整篇中文文档：在最外层 `<html lang="zh">` 即可，里面无需逐个加
- 中英混排文档：英文段不加 `lang`，中文段加 `lang="zh"`
- 中文标题末尾**不加** `。`
- 全角标点 `，。：；！？`，不用半角
- 中英 / 中数之间留半角空格（盘古之白）

---

## 兜底策略

**内容形态不在本清单中怎么办**：

1. 优先用 `tablet--paper`（中性低权重 tablet）兜底，把内容塞进 body
2. 长附录 / 原始日志 → 用原生 `<details><summary>{{标题}}</summary>{{内容}}</details>`
3. 单条事实 / 警示 → §11 的 pill
4. 实在不匹配 → 用 §5 的基础排版（h2/h3/p/ul/ol）

**禁止**：自创组件、自创 class、写 inline style。
