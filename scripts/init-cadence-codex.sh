#!/usr/bin/env bash
# 幂等地初始化 Codex 项目的 cadence 基础设施：
#   项目根 AGENTS.md — 注入 cadence 规则块（三态：不存在→建；含 marker→跳过；无 marker→prepend）
#   项目根 .gitignore — 确保忽略 .idea/、.cadence/ 与 .playwright-mcp/
#
# 由 cadence-init skill 调用。不接受参数。
# 工作目录：优先 $CODEX_PROJECT_DIR，fallback 到当前 cwd。

set -euo pipefail

TARGET_DIR="${CODEX_PROJECT_DIR:-$PWD}"
AGENTS_MD="${TARGET_DIR%/}/AGENTS.md"
GITIGNORE="${TARGET_DIR%/}/.gitignore"
MARKER_START="<!-- cadence:rules:start -->"
GITIGNORE_ENTRIES=(".idea/" ".cadence/" ".playwright-mcp/")

RULES_BLOCK=$(cat <<'EOF'
<!-- cadence:rules:start -->
# Cadence 项目规则

## 1. 工作目录边界

禁止修改当前工作目录（打开会话的目录）外的文件，除非获得用户明确同意。

## 2. 注释要求

新增接口和函数代码时，要加清晰注释；注释应解释对外契约、边界和非显然决策，不写空泛复述。

## 3. 简洁优先

用解决问题所需的最少代码。不添加超出要求之外的功能，不为只用一次的代码做抽象，不加入未被要求的灵活性或可配置性。

## 4. 精准外科式修改

只动必须动的地方。不要顺手优化相邻代码、注释或格式；不要重构没有坏掉的东西；与既有风格保持一致。移除因本次改动产生的未使用 import、变量、函数，但不要删除无关既有死代码，除非用户要求。

检验标准：每一行被改动的代码都应能直接追溯到用户请求。
<!-- cadence:rules:end -->
EOF
)

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
