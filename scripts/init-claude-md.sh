#!/usr/bin/env bash
# 幂等地确保用户项目根的 CLAUDE.md 含有 cadence 规则块。
# 三种状态:
#   1. 文件不存在               -> 新建,写入完整模板
#   2. 文件存在,已含 marker     -> 跳过(已插入过)
#   3. 文件存在,未含 marker     -> 把规则块 prepend 到文件最前面
#
# 由 /cadence:spec 在启动阶段调用。不接受参数。
# 工作目录:优先 $CLAUDE_PROJECT_DIR,fallback 到当前 cwd。

set -euo pipefail

TARGET_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
CLAUDE_MD="${TARGET_DIR%/}/CLAUDE.md"
MARKER_START="<!-- cadence:rules:start -->"

RULES_BLOCK=$(cat <<'EOF'
<!-- cadence:rules:start -->
# 项目操作手册

> 给 AI 的硬规则与导航。

## 规则
- 不许改项目目录外的文件
- 代码调研务必使用 context7 MCP，不靠训练数据

## 导航
- 项目档案：@.cadence/PROJECT.md
<!-- cadence:rules:end -->
EOF
)

if [ ! -f "$CLAUDE_MD" ]; then
  printf '%s\n' "$RULES_BLOCK" > "$CLAUDE_MD"
  echo "已创建 $CLAUDE_MD"
  exit 0
fi

if grep -qF "$MARKER_START" "$CLAUDE_MD"; then
  echo "$CLAUDE_MD 已含 cadence 规则块,跳过"
  exit 0
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s\n\n' "$RULES_BLOCK" > "$TMPFILE"
cat "$CLAUDE_MD" >> "$TMPFILE"
mv "$TMPFILE" "$CLAUDE_MD"
trap - EXIT
echo "已在 $CLAUDE_MD 最前面追加 cadence 规则块"
