#!/usr/bin/env python3
"""Process field-intelligence candidates into normalized, scored reports.

Input is either a JSON array or an object with an `items` array. Each item should
contain evidence gathered by the LLM; this script owns deterministic cleanup,
dedupe, scoring math, thresholding, and Markdown rendering.
"""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


WEIGHTS = {
    "relevance": 0.25,
    "source_quality": 0.25,
    "impact": 0.20,
    "novelty": 0.15,
    "timeliness": 0.10,
    "actionability": 0.05,
}

SOURCE_QUALITY = {
    "official": 10.0,
    "regulator": 10.0,
    "standard": 9.5,
    "paper": 8.5,
    "data": 8.0,
    "report": 7.5,
    "media": 7.0,
    "newsletter": 6.0,
    "blog": 5.0,
    "forum": 4.0,
    "social": 3.0,
    "unknown": 4.0,
}

LOW_AUTHORITY_TYPES = {"blog", "forum", "newsletter", "social", "unknown"}
REJECT_TAGS = {"seo", "clickbait", "pure-opinion", "unverified"}
TRACKING_PARAMS = {
    "fbclid",
    "gclid",
    "mc_cid",
    "mc_eid",
    "ref",
    "ref_src",
    "spm",
    "utm_campaign",
    "utm_content",
    "utm_medium",
    "utm_source",
    "utm_term",
}


def load_json(path: str) -> Any:
    """Load JSON from a file path or stdin when `path` is `-`."""
    if path == "-":
        return json.load(sys.stdin)
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: str, payload: Any) -> None:
    """Write stable UTF-8 JSON to a file path or stdout when `path` is `-`."""
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if path == "-":
        sys.stdout.write(text)
        return
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")


def extract_items(payload: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Return candidate items and metadata from supported input shapes."""
    if isinstance(payload, list):
        return payload, {}
    if isinstance(payload, dict) and isinstance(payload.get("items"), list):
        metadata = {k: v for k, v in payload.items() if k != "items"}
        return payload["items"], metadata
    raise ValueError("input must be a JSON array or an object with an items array")


def clean_text(value: Any) -> str:
    """Normalize arbitrary scalar text without changing meaning."""
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip()


def to_list(value: Any) -> list[str]:
    """Normalize string/list fields into a de-duplicated list of strings."""
    if value is None:
        return []
    raw = value if isinstance(value, list) else [value]
    seen: set[str] = set()
    result: list[str] = []
    for entry in raw:
        text = clean_text(entry)
        key = text.casefold()
        if text and key not in seen:
            seen.add(key)
            result.append(text)
    return result


def normalize_date(value: Any) -> str:
    """Normalize common date strings to YYYY-MM-DD when possible."""
    text = clean_text(value)
    if not text:
        return ""
    match = re.search(r"(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})", text)
    if not match:
        return text
    year, month, day = (int(part) for part in match.groups())
    try:
        return dt.date(year, month, day).isoformat()
    except ValueError:
        return text


def canonicalize_url(url: Any) -> str:
    """Canonicalize URLs for deterministic exact-match dedupe."""
    text = clean_text(url)
    if not text:
        return ""
    parsed = urlsplit(text)
    query = [
        (key, value)
        for key, value in parse_qsl(parsed.query, keep_blank_values=True)
        if key.lower() not in TRACKING_PARAMS and not key.lower().startswith("utm_")
    ]
    path = re.sub(r"/+$", "", parsed.path)
    netloc = parsed.netloc.casefold()
    scheme = parsed.scheme.casefold() or "https"
    return urlunsplit((scheme, netloc, path, urlencode(query), ""))


def clamp_score(value: Any, default: float) -> float:
    """Coerce score dimensions into the inclusive 0-10 range."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        number = default
    return max(0.0, min(10.0, number))


def normalize_scores(raw_scores: Any, source_type: str, has_date: bool) -> dict[str, float]:
    """Fill missing semantic score dimensions with conservative defaults."""
    scores = raw_scores if isinstance(raw_scores, dict) else {}
    defaults = {
        "relevance": 7.0,
        "source_quality": SOURCE_QUALITY.get(source_type, SOURCE_QUALITY["unknown"]),
        "impact": 5.0,
        "novelty": 5.0,
        "timeliness": 7.0 if has_date else 4.0,
        "actionability": 5.0,
    }
    return {key: clamp_score(scores.get(key), default) for key, default in defaults.items()}


def normalize_supporting_sources(value: Any) -> list[dict[str, str]]:
    """Normalize supplementary source links kept after dedupe."""
    if value is None:
        return []
    raw = value if isinstance(value, list) else [value]
    sources: list[dict[str, str]] = []
    seen: set[str] = set()
    for entry in raw:
        if isinstance(entry, dict):
            source = {
                "title": clean_text(entry.get("title")),
                "url": clean_text(entry.get("url")),
                "source": clean_text(entry.get("source")),
                "published_at": normalize_date(entry.get("published_at")),
            }
        else:
            source = {"title": clean_text(entry), "url": "", "source": "", "published_at": ""}
        key = canonicalize_url(source["url"]) or source["title"].casefold()
        if key and key not in seen:
            seen.add(key)
            sources.append(source)
    return sources


def normalize_item(raw: dict[str, Any], index: int) -> dict[str, Any]:
    """Normalize one candidate while preserving LLM-provided semantic fields."""
    source_type = clean_text(raw.get("source_type") or raw.get("type") or "unknown").casefold()
    published_at = normalize_date(raw.get("published_at") or raw.get("date"))
    item = {
        "id": clean_text(raw.get("id")) or f"item-{index + 1}",
        "title": clean_text(raw.get("title")),
        "url": clean_text(raw.get("url")),
        "canonical_url": canonicalize_url(raw.get("url")),
        "source": clean_text(raw.get("source")),
        "source_type": source_type or "unknown",
        "published_at": published_at,
        "fetched_at": normalize_date(raw.get("fetched_at")) or dt.date.today().isoformat(),
        "entities": to_list(raw.get("entities")),
        "core_fact": clean_text(raw.get("core_fact") or raw.get("summary")),
        "importance": clean_text(raw.get("importance") or raw.get("why_important")),
        "evidence": clean_text(raw.get("evidence")),
        "tags": [tag.casefold() for tag in to_list(raw.get("tags"))],
        "supporting_sources": normalize_supporting_sources(raw.get("supporting_sources")),
        "notes": clean_text(raw.get("notes")),
    }
    item["scores"] = normalize_scores(raw.get("scores"), item["source_type"], bool(published_at))
    item["warnings"] = validation_warnings(item)
    return item


def validation_warnings(item: dict[str, Any]) -> list[str]:
    """Report quality issues without dropping recoverable candidates."""
    warnings: list[str] = []
    for field in ("title", "url", "source", "core_fact"):
        if not item.get(field):
            warnings.append(f"missing {field}")
    if not item.get("published_at"):
        warnings.append("missing published_at")
    if not item.get("importance"):
        warnings.append("missing importance")
    return warnings


def normalize_items(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Normalize all candidate objects."""
    return [normalize_item(item, index) for index, item in enumerate(items)]


def normalized_text(value: str) -> str:
    """Return punctuation-light lowercase text for fuzzy matching."""
    value = re.sub(r"[^\w\s]", " ", value.casefold())
    return re.sub(r"\s+", " ", value).strip()


def similarity(left: str, right: str) -> float:
    """Compute a stable fuzzy similarity ratio for short text fields."""
    if not left or not right:
        return 0.0
    return difflib.SequenceMatcher(None, normalized_text(left), normalized_text(right)).ratio()


def entity_overlap(left: dict[str, Any], right: dict[str, Any]) -> bool:
    """Return whether two candidates mention at least one same entity."""
    left_entities = {entity.casefold() for entity in left.get("entities", [])}
    right_entities = {entity.casefold() for entity in right.get("entities", [])}
    return bool(left_entities and right_entities and left_entities.intersection(right_entities))


def is_duplicate(left: dict[str, Any], right: dict[str, Any]) -> tuple[bool, str]:
    """Decide whether two candidates describe the same underlying item."""
    if left.get("canonical_url") and left["canonical_url"] == right.get("canonical_url"):
        return True, "same canonical URL"
    same_day = bool(left.get("published_at") and left.get("published_at") == right.get("published_at"))
    overlaps = entity_overlap(left, right)
    title_ratio = similarity(left.get("title", ""), right.get("title", ""))
    fact_ratio = similarity(left.get("core_fact", ""), right.get("core_fact", ""))
    if fact_ratio >= 0.86 and overlaps:
        return True, "same entity and highly similar core fact"
    if title_ratio >= 0.90 and (same_day or overlaps):
        return True, "highly similar title"
    if title_ratio >= 0.82 and fact_ratio >= 0.80 and (same_day or overlaps):
        return True, "similar title and fact"
    return False, ""


def date_rank(value: str) -> int:
    """Convert normalized dates into sortable integers; unknown dates rank last."""
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value or ""):
        return int(value.replace("-", ""))
    return 99999999


def source_rank(item: dict[str, Any]) -> float:
    """Return source authority used for choosing duplicate representatives."""
    return SOURCE_QUALITY.get(item.get("source_type", "unknown"), SOURCE_QUALITY["unknown"])


def choose_representative(group: list[dict[str, Any]]) -> dict[str, Any]:
    """Choose the retained item in a duplicate group by authority, date, detail."""
    return max(
        group,
        key=lambda item: (
            source_rank(item),
            -date_rank(item.get("published_at", "")),
            len(item.get("core_fact", "")),
            len(item.get("importance", "")),
        ),
    )


def dedupe_items(items: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Merge duplicate candidates and return retained items plus duplicate groups."""
    visited: set[int] = set()
    retained: list[dict[str, Any]] = []
    groups: list[dict[str, Any]] = []
    for index, item in enumerate(items):
        if index in visited:
            continue
        group = [item]
        reasons: list[str] = []
        for other_index in range(index + 1, len(items)):
            if other_index in visited:
                continue
            duplicate, reason = is_duplicate(item, items[other_index])
            if duplicate:
                visited.add(other_index)
                group.append(items[other_index])
                reasons.append(reason)
        visited.add(index)
        representative = dict(choose_representative(group))
        merged_sources = list(representative.get("supporting_sources", []))
        for candidate in group:
            if candidate is representative:
                continue
            source = {
                "title": candidate.get("title", ""),
                "url": candidate.get("url", ""),
                "source": candidate.get("source", ""),
                "published_at": candidate.get("published_at", ""),
            }
            if source["url"] != representative.get("url"):
                merged_sources.append(source)
        representative["supporting_sources"] = normalize_supporting_sources(merged_sources)
        representative["duplicate_count"] = len(group) - 1
        retained.append(representative)
        if len(group) > 1:
            groups.append(
                {
                    "retained": representative.get("title", ""),
                    "reason": "; ".join(sorted(set(reasons))),
                    "merged": [
                        {
                            "title": candidate.get("title", ""),
                            "url": candidate.get("url", ""),
                            "source": candidate.get("source", ""),
                        }
                        for candidate in group
                        if candidate.get("url") != representative.get("url")
                    ],
                }
            )
    return retained, groups


def score_item(item: dict[str, Any]) -> dict[str, Any]:
    """Compute weighted score, hard rejection reasons, and score caps."""
    scored = dict(item)
    scores = scored.get("scores", {})
    weighted = sum(scores.get(key, 0.0) * weight for key, weight in WEIGHTS.items())
    caps: list[dict[str, Any]] = []
    rejected: list[str] = []
    if not scored.get("url"):
        rejected.append("missing source URL")
    if not scored.get("core_fact"):
        rejected.append("missing core fact")
    if REJECT_TAGS.intersection(scored.get("tags", [])):
        rejected.append("reject tag present")
    if not scored.get("published_at"):
        caps.append({"max": 6.0, "reason": "missing published_at"})
    if scored.get("source_type") in LOW_AUTHORITY_TYPES and not scored.get("supporting_sources"):
        caps.append({"max": 6.5, "reason": "single low-authority source"})
    for cap in caps:
        weighted = min(weighted, float(cap["max"]))
    scored["score"] = round(weighted, 2)
    scored["score_caps"] = caps
    scored["rejected_reasons"] = rejected
    return scored


def score_items(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Score each retained candidate with the shared weighting rules."""
    return [score_item(item) for item in items]


def build_result(
    items: list[dict[str, Any]],
    duplicate_groups: list[dict[str, Any]],
    metadata: dict[str, Any],
    min_score: float,
    limit: int,
) -> dict[str, Any]:
    """Build the canonical processed payload consumed by report rendering."""
    selected: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for item in items:
        if item.get("rejected_reasons"):
            rejected.append(item)
        elif item.get("score", 0.0) >= min_score:
            selected.append(item)
        else:
            low = dict(item)
            low["rejected_reasons"] = [f"below min_score {min_score:g}"]
            rejected.append(low)
    selected.sort(key=lambda item: (item.get("score", 0.0), item.get("published_at", "")), reverse=True)
    if limit > 0:
        rejected.extend(selected[limit:])
        selected = selected[:limit]
    return {
        "metadata": metadata,
        "selected": selected,
        "rejected": rejected,
        "duplicate_groups": duplicate_groups,
        "counts": {
            "candidates": metadata.get("candidate_count", len(items)),
            "deduped": len(items),
            "selected": len(selected),
            "rejected": len(rejected),
            "duplicate_groups": len(duplicate_groups),
        },
    }


def md_escape(value: Any) -> str:
    """Escape table-sensitive Markdown characters."""
    return clean_text(value).replace("|", "\\|")


def md_link(title: str, url: str) -> str:
    """Render a Markdown link when URL exists, otherwise plain escaped text."""
    if url:
        return f"[{md_escape(title)}]({url})"
    return md_escape(title)


def render_report(result: dict[str, Any], topic: str, time_range: str, min_score: float, generated_date: str) -> str:
    """Render the processed payload into the field-intelligence report format."""
    selected = result.get("selected", [])
    rejected = result.get("rejected", [])
    duplicate_groups = result.get("duplicate_groups", [])
    counts = result.get("counts", {})
    top = selected[0] if selected else None
    lines = [
        f"# {topic} 高质量信息筛选",
        "",
        f"> 范围：{topic} | 时间：{time_range} | 生成日期：{generated_date}",
        f"> 规则：去重后保留 score >= {min_score:g} 的信息；不足时不补低质量候选。",
        "",
        "## 摘要",
        f"- 候选：{counts.get('candidates', 0)} 条；去重后：{counts.get('deduped', 0)} 条；入选：{counts.get('selected', 0)} 条。",
        f"- 最高分：{md_link(top.get('title', ''), top.get('url', ''))}（{top.get('score')}）。" if top else "- 最高分：无入选信息。",
        "",
        "## 入选信息",
        "",
        "| 分数 | 日期 | 来源 | 标题 | 为什么重要 |",
        "|---:|---|---|---|---|",
    ]
    if selected:
        for item in selected:
            lines.append(
                "| {score:.2f} | {date} | {source} | {title} | {why} |".format(
                    score=float(item.get("score", 0.0)),
                    date=md_escape(item.get("published_at", "")),
                    source=md_escape(item.get("source", "")),
                    title=md_link(item.get("title", ""), item.get("url", "")),
                    why=md_escape(item.get("importance", "")),
                )
            )
    else:
        lines.append("| - | - | - | 无 | 未达到质量门槛 |")
    lines.extend(["", "## 详情", ""])
    for item in selected:
        lines.extend(
            [
                f"### {item.get('title', '')}",
                f"- 分数：{item.get('score')}",
                f"- 来源：{item.get('source_type', '')}，{item.get('source', '')}，{item.get('published_at', '')}，{item.get('url', '')}",
                f"- 涉及实体：{', '.join(item.get('entities', [])) or '未标注'}",
                f"- 核心事实：{item.get('core_fact', '')}",
                f"- 入选理由：{item.get('importance', '')}",
            ]
        )
        if item.get("evidence"):
            lines.append(f"- 证据依据：{item.get('evidence')}")
        if item.get("supporting_sources"):
            links = [
                md_link(source.get("title") or source.get("source") or source.get("url"), source.get("url", ""))
                for source in item["supporting_sources"]
            ]
            lines.append(f"- 补充来源：{'; '.join(links)}")
        lines.append("")
    lines.extend(["## 去重与剔除", ""])
    if duplicate_groups:
        for group in duplicate_groups:
            merged = "；".join(md_link(entry.get("title", ""), entry.get("url", "")) for entry in group.get("merged", []))
            lines.append(f"- 重复组：保留「{group.get('retained', '')}」；原因：{group.get('reason', '')}；合并：{merged}")
    else:
        lines.append("- 重复组：无。")
    if rejected:
        for item in rejected:
            reasons = "；".join(item.get("rejected_reasons", []) or ["未入选"])
            lines.append(f"- 剔除：{md_link(item.get('title', ''), item.get('url', ''))}，原因：{reasons}")
    else:
        lines.append("- 剔除：无。")
    lines.extend(["", "## 来源清单"])
    seen_sources: set[str] = set()
    for item in selected:
        key = item.get("canonical_url") or item.get("url") or item.get("title")
        if key in seen_sources:
            continue
        seen_sources.add(key)
        lines.append(
            f"- {md_link(item.get('title', ''), item.get('url', ''))} — {item.get('source_type', '')}，{item.get('fetched_at', generated_date)} 抓取"
        )
    return "\n".join(lines).rstrip() + "\n"


def command_normalize(args: argparse.Namespace) -> int:
    """CLI entrypoint for normalization only."""
    items, metadata = extract_items(load_json(args.input))
    write_json(args.output, {"metadata": metadata, "items": normalize_items(items)})
    return 0


def command_validate(args: argparse.Namespace) -> int:
    """CLI entrypoint for quality validation."""
    items, _ = extract_items(load_json(args.input))
    normalized = normalize_items(items)
    issues = [
        {"id": item["id"], "title": item["title"], "warnings": item["warnings"]}
        for item in normalized
        if item["warnings"]
    ]
    write_json(args.output, {"ok": not issues, "issues": issues})
    return 1 if issues and args.strict else 0


def command_dedupe(args: argparse.Namespace) -> int:
    """CLI entrypoint for duplicate grouping only."""
    items, metadata = extract_items(load_json(args.input))
    retained, groups = dedupe_items(normalize_items(items))
    write_json(args.output, {"metadata": metadata, "items": retained, "duplicate_groups": groups})
    return 0


def command_score(args: argparse.Namespace) -> int:
    """CLI entrypoint for scoring only."""
    items, metadata = extract_items(load_json(args.input))
    write_json(args.output, {"metadata": metadata, "items": score_items(normalize_items(items))})
    return 0


def command_render(args: argparse.Namespace) -> int:
    """CLI entrypoint for rendering a processed payload."""
    result = load_json(args.input)
    report = render_report(result, args.topic, args.time_range, args.min_score, args.generated_date)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report, encoding="utf-8")
    return 0


def command_pipeline(args: argparse.Namespace) -> int:
    """CLI entrypoint for normalize -> dedupe -> score -> render."""
    raw_items, metadata = extract_items(load_json(args.input))
    normalized = normalize_items(raw_items)
    retained, duplicate_groups = dedupe_items(normalized)
    scored = score_items(retained)
    metadata = dict(metadata)
    metadata["candidate_count"] = len(raw_items)
    result = build_result(scored, duplicate_groups, metadata, args.min_score, args.limit)
    if args.json_output:
        write_json(args.json_output, result)
    report = render_report(result, args.topic, args.time_range, args.min_score, args.generated_date)
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report, encoding="utf-8")
    return 0


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser for all deterministic processing steps."""
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    normalize = subparsers.add_parser("normalize")
    normalize.add_argument("input")
    normalize.add_argument("output")
    normalize.set_defaults(func=command_normalize)

    validate = subparsers.add_parser("validate")
    validate.add_argument("input")
    validate.add_argument("output")
    validate.add_argument("--strict", action="store_true")
    validate.set_defaults(func=command_validate)

    dedupe = subparsers.add_parser("dedupe")
    dedupe.add_argument("input")
    dedupe.add_argument("output")
    dedupe.set_defaults(func=command_dedupe)

    score = subparsers.add_parser("score")
    score.add_argument("input")
    score.add_argument("output")
    score.set_defaults(func=command_score)

    render = subparsers.add_parser("render")
    render.add_argument("input")
    render.add_argument("output")
    render.add_argument("--topic", required=True)
    render.add_argument("--time-range", default="未指定")
    render.add_argument("--min-score", type=float, default=7.0)
    render.add_argument("--generated-date", default=dt.date.today().isoformat())
    render.set_defaults(func=command_render)

    pipeline = subparsers.add_parser("pipeline")
    pipeline.add_argument("input")
    pipeline.add_argument("--report", required=True)
    pipeline.add_argument("--json-output")
    pipeline.add_argument("--topic", required=True)
    pipeline.add_argument("--time-range", default="最近 30 天")
    pipeline.add_argument("--min-score", type=float, default=7.0)
    pipeline.add_argument("--limit", type=int, default=20)
    pipeline.add_argument("--generated-date", default=dt.date.today().isoformat())
    pipeline.set_defaults(func=command_pipeline)

    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the selected processing command."""
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except Exception as exc:  # noqa: BLE001 - CLI should surface concise failures.
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
