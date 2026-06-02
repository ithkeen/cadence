#!/usr/bin/env bash
# Copy bundled Codex subagent definitions into the user's Codex agent directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$PLUGIN_ROOT/assets/codex-agents"
CODEX_STATE_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_DIR="$CODEX_STATE_DIR/agents"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "安装失败：找不到 Codex agent 目录 $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

copied=0
for agent in "$SOURCE_DIR"/*.toml; do
  if [ ! -e "$agent" ]; then
    echo "安装失败：$SOURCE_DIR 下没有 .toml agent 文件" >&2
    exit 1
  fi

  cp "$agent" "$TARGET_DIR/"
  echo "已安装 $(basename "$agent") 到 $TARGET_DIR"
  copied=$((copied + 1))
done

echo "已同步 ${copied} 个 Codex agent 到 $TARGET_DIR"
