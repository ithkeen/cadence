---
name: field-intelligence
description: 抓取并筛选某个领域的领先信息，覆盖信息发现、来源取证、结构化提取、清洗去重、质量评分和落盘保存。当用户要求监控或搜集 AI、金融、行业趋势、竞品动态、投资机会、政策变化、论文/产品发布等高质量信息，或提到"抓取信息"、"去重"、"打分"、"高质量信息"、"保存到文件"、"领域情报"、"field intelligence"时使用。Use when the task is to gather, deduplicate, score, and save high-quality domain intelligence from external sources.
---

# 领域情报筛选

为某个领域建立一份可追溯的高质量信息清单。输出中文，除非用户指定其他语言。

## 默认边界

用户没有指定时，使用以下默认值；缺少领域或主题时先询问。

- 时间范围：最近 30 天。
- 数量：最多保留 20 条高质量信息。
- 最低分：7.0 / 10；不足时可以少于 20 条，不要用低质量信息凑数。
- 输出路径：`.cadence/research/<topic-slug>-intelligence-<YYYY-MM-DD>.md`。
- 输出格式：Markdown；用户要求 JSON/CSV 时再追加对应文件。

## 工作流

1. **确定采集边界**：明确领域、时间范围、目标读者、地区/语言限制、排除项和输出路径。
2. **发现候选信息**：需要最新信息时必须联网检索。优先覆盖不同来源类型：官方公告、监管/标准机构、论文与预印本、头部公司/项目、权威媒体、数据平台、行业报告。金融领域只做信息整理，不给买卖建议。
3. **读取原文取证**：搜索结果只用于发现线索；候选进入清单前必须读取原文或权威摘要页。无法确认发布时间、来源或核心事实的候选不得高分。
4. **结构化提取**：把候选写成 `candidates.json`，每条候选包含下面的字段和六个评分维度。不要手算总分。
5. **脚本处理**：运行 `scripts/process_items.py pipeline`，让脚本统一完成清洗、去重、加权评分、降分/剔除和 Markdown 渲染。
6. **回报结果**：回复报告路径、入选条数、最高分信息；如果脚本剔除了大量候选，说明主要原因。

## 候选 JSON

```json
{
  "items": [
    {
      "title": "信息标题",
      "url": "https://example.com/source",
      "source": "来源名",
      "source_type": "official",
      "published_at": "YYYY-MM-DD",
      "fetched_at": "YYYY-MM-DD",
      "entities": ["公司/机构/项目"],
      "core_fact": "可被来源支撑的核心事实，不写观点发挥。",
      "importance": "为什么这条信息重要。",
      "evidence": "短证据说明或原文事实依据。",
      "tags": ["ai", "product"],
      "supporting_sources": [
        {
          "title": "补充来源标题",
          "url": "https://example.com/another",
          "source": "补充来源名",
          "published_at": "YYYY-MM-DD"
        }
      ],
      "scores": {
        "relevance": 8,
        "source_quality": 9,
        "impact": 8,
        "novelty": 7,
        "timeliness": 8,
        "actionability": 6
      }
    }
  ]
}
```

`source_type` 使用：`official`、`regulator`、`standard`、`paper`、`data`、`report`、`media`、`newsletter`、`blog`、`forum`、`social`、`unknown`。低权威来源没有补充来源时会被脚本封顶。

## 脚本

脚本路径：`scripts/process_items.py`。它只依赖 Python 标准库。

常用命令：

```bash
python3 scripts/process_items.py pipeline candidates.json \
  --topic "AI" \
  --time-range "最近 30 天" \
  --min-score 7 \
  --limit 20 \
  --json-output processed.json \
  --report .cadence/research/ai-intelligence-YYYY-MM-DD.md
```

可单独调试的子命令：

- `validate <input> <output> [--strict]`：检查必填字段和质量警告。
- `normalize <input> <output>`：规范 URL、日期、列表字段和评分字段。
- `dedupe <input> <output>`：合并重复信息并输出重复组。
- `score <input> <output>`：按统一规则计算总分和封顶原因。
- `render <processed-json> <report>`：把处理结果渲染成 Markdown。

## 评分规则

LLM 只给六个维度的 0-10 原始分；脚本按权重计算总分。

| 维度 | 权重 | 判定标准 |
|---|---:|---|
| 相关性 | 25% | 是否直接命中用户指定领域、问题和地区/时间边界 |
| 来源质量 | 25% | 官方/一手/权威来源最高；转载、营销稿、匿名爆料降分 |
| 影响力 | 20% | 是否可能改变技术路线、市场格局、监管环境、资金流向或关键决策 |
| 新颖性 | 15% | 是否不是旧闻重发、常识总结或低信息密度观点 |
| 时效性 | 10% | 是否在指定窗口内，且相对同类信息更早或更及时 |
| 可行动性 | 5% | 是否能转化为后续跟踪、分析、决策或研究问题 |

降分规则：

- 核心事实无来源：不进入清单。
- 发布时间缺失且无法从上下文确认：脚本最高给 6 分。
- 只有单一低权威来源：脚本最高给 6.5 分。
- `tags` 包含 `seo`、`clickbait`、`pure-opinion`、`unverified`：脚本剔除。
- 金融信息涉及预测、荐股或交易结论：只记录事实和风险，不把结论包装成建议。

## 输出格式

```markdown
# <领域> 高质量信息筛选

> 范围：<领域/主题> | 时间：<起止日期> | 生成日期：<YYYY-MM-DD>
> 规则：去重后保留 score >= <阈值> 的信息；不足时不补低质量候选。

## 摘要
- 候选：<N> 条；去重后：<N> 条；入选：<N> 条。
- 最高分：<标题>（<score>）。
- 主要发现：<1-3 条>

## 入选信息

| 分数 | 日期 | 来源 | 标题 | 为什么重要 |
|---:|---|---|---|---|
| 8.7 | YYYY-MM-DD | <来源> | [<标题>](<URL>) | <一句话理由> |

## 详情

### <标题>
- 分数：<score>
- 来源：<来源类型>，<来源名>，<发布时间>，<URL>
- 涉及实体：<公司/机构/人物/项目>
- 核心事实：<不超过 3 句>
- 入选理由：<对应评分维度的简述>
- 补充来源：<重复组内保留的其他权威链接，没有则省略>

## 去重与剔除

- 重复组：<被合并的信息及保留理由>
- 剔除：<低分或不可验证候选，简述原因>

## 来源清单
- [<标题>](<URL>) — <来源类型>，<YYYY-MM-DD> 抓取
```

## 质量门槛

- 不编造发布时间、融资金额、产品状态、监管结论或市场数据。
- 不把搜索摘要当证据；必须引用可打开的来源 URL。
- 重要数字尽量用一手来源或两个独立来源交叉验证。
- 来源过度集中时，在摘要中说明局限。
- 联网失败或没有足够可信来源时，不生成伪清单；向用户说明未产出文件或仅基于用户提供材料处理。
