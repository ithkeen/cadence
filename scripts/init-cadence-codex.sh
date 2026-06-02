#!/usr/bin/env bash
# 幂等地初始化 Codex 项目的 cadence 基础设施：
#   项目根 AGENTS.md — 注入 cadence 规则块（三态：不存在→建；含 marker→跳过；无 marker→prepend）
#   项目根 .gitignore — 确保忽略 .idea/、.cadence/ 与 .playwright-mcp/
#
# 由 cadence-init skill 调用。不接受参数。
# 工作目录：优先 $CODEX_PROJECT_DIR，fallback 到当前 cwd。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_FILE="$PLUGIN_ROOT/rules/project-rules.md"
TARGET_DIR="${CODEX_PROJECT_DIR:-$PWD}"
AGENTS_MD="${TARGET_DIR%/}/AGENTS.md"
GITIGNORE="${TARGET_DIR%/}/.gitignore"
MARKER_START="<!-- cadence:rules:start -->"
GITIGNORE_ENTRIES=(".idea/" ".cadence/" ".playwright-mcp/")

if [ ! -f "$RULES_FILE" ]; then
  echo "初始化失败：找不到规则文件 $RULES_FILE" >&2
  exit 1
fi

RULES_BLOCK="$(cat "$RULES_FILE")"

if [ ! -f "$AGENTS_MD" ]; then
  printf '%s\n' "$RULES_BLOCK" > "$AGENTS_MD"
  echo "已创建 $AGENTS_MD"
elif grep -qF "$MARKER_START" "$AGENTS_MD"; then
  echo "$AGENTS_MD 已含 cadence 规则块，跳过"
else
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' EXIT
  printf '%s\n\n' "$RULES_BLOCK" > "$TMPFILE"
  cat "$AGENTS_MD" >> "$TMPFILE"
  mv "$TMPFILE" "$AGENTS_MD"
  trap - EXIT
  echo "已在 $AGENTS_MD 最前面追加 cadence 规则块"
fi

if [ ! -f "$GITIGNORE" ]; then
  : > "$GITIGNORE"
  echo "已创建 $GITIGNORE"
fi

for entry in "${GITIGNORE_ENTRIES[@]}"; do
  if grep -Fxq "$entry" "$GITIGNORE" || grep -Fxq "${entry%/}" "$GITIGNORE"; then
    echo "$GITIGNORE 已含 ${entry}，跳过"
  else
    if [ -s "$GITIGNORE" ] && [ -n "$(tail -c1 "$GITIGNORE")" ]; then
      printf '\n' >> "$GITIGNORE"
    fi
    printf '%s\n' "$entry" >> "$GITIGNORE"
    echo "已在 $GITIGNORE 追加 ${entry}"
  fi
done
