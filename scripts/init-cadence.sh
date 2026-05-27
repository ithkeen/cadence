#!/usr/bin/env bash
# 幂等地初始化用户项目的 cadence 基础设施：
#   项目根 CLAUDE.md — 注入 cadence 规则块（三态：不存在→建；含 marker→跳过；无 marker→prepend）
#   项目根 .gitignore — 确保忽略 .idea/、.cadence/ 与 .playwright-mcp/（不存在→建；已含→跳过；不含→追加）
#
# 由 /cadence:init 调用。不接受参数。
# 工作目录：优先 $CLAUDE_PROJECT_DIR，fallback 到当前 cwd。

set -euo pipefail

TARGET_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
CLAUDE_MD="${TARGET_DIR%/}/CLAUDE.md"
GITIGNORE="${TARGET_DIR%/}/.gitignore"
MARKER_START="<!-- cadence:rules:start -->"
GITIGNORE_ENTRIES=(".idea/" ".cadence/" ".playwright-mcp/")

RULES_BLOCK=$(cat <<'EOF'
<!-- cadence:rules:start -->
# 必须遵循以下要求

## 1. 禁止修改当前工作目录（打开会话的目录）外的文件。除非获取用户的同意。

# 行为准则

## 1. 简洁优先

**用解决问题所需的最少代码。不写任何投机性的东西。**

- 不要添加任何超出要求之外的功能。
- 不要为只用一次的代码做抽象。
- 不要加入未被要求的"灵活性"或"可配置性"。
- 不要为不可能发生的场景编写错误处理。
- 如果你写了 200 行而其实 50 行就够，就重写。

问自己：「资深工程师会不会觉得这太复杂了？」如果会，就简化。

## 2. 精准外科式修改

**只动你必须动的地方。只清理你自己留下的烂摊子。**

在修改现有代码时：

- 不要"顺手优化"相邻的代码、注释或格式。
- 不要重构没有坏掉的东西。
- 与现有风格保持一致，即便你自己的写法会不同。
- 如果你注意到无关的死代码，提一下——不要删除它。

当你的改动产生了"孤儿"时：

- 移除因**你的**改动而变得未被使用的 import、变量、函数。
- 不要移除既有的死代码，除非被要求这样做。

检验标准：每一行被改动的代码都应能直接追溯到用户的请求。
<!-- cadence:rules:end -->
EOF
)

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
