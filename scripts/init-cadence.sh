#!/usr/bin/env bash
# 幂等地初始化用户项目的 cadence 基础设施：
#   项目根 CLAUDE.md — 注入 cadence 规则块（三态：不存在→建；含 marker→跳过；无 marker→prepend）
#   项目根 .gitignore — 确保忽略 .idea/、.cadence/ 与 .playwright-mcp/（不存在→建；已含→跳过；不含→追加）
#
# 由 /cadence:init 调用。不接受参数。
# 工作目录：优先 $CLAUDE_PROJECT_DIR，fallback 到当前 cwd。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_FILE="$PLUGIN_ROOT/rules/project-rules.md"
TARGET_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
CLAUDE_MD="${TARGET_DIR%/}/CLAUDE.md"
GITIGNORE="${TARGET_DIR%/}/.gitignore"
MARKER_START="<!-- cadence:rules:start -->"
GITIGNORE_ENTRIES=(".idea/" ".cadence/" ".playwright-mcp/")

if [ ! -f "$RULES_FILE" ]; then
  echo "初始化失败：找不到规则文件 $RULES_FILE" >&2
  exit 1
fi

RULES_BLOCK="$(cat "$RULES_FILE")"

# --- CLAUDE.md ---
if [ ! -f "$CLAUDE_MD" ]; then
  printf '%s\n' "$RULES_BLOCK" > "$CLAUDE_MD"
  echo "已创建 $CLAUDE_MD"
elif grep -qF "$MARKER_START" "$CLAUDE_MD"; then
  echo "$CLAUDE_MD 已含 cadence 规则块，跳过"
else
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' EXIT
  printf '%s\n\n' "$RULES_BLOCK" > "$TMPFILE"
  cat "$CLAUDE_MD" >> "$TMPFILE"
  mv "$TMPFILE" "$CLAUDE_MD"
  trap - EXIT
  echo "已在 $CLAUDE_MD 最前面追加 cadence 规则块"
fi

# --- .gitignore ---
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
