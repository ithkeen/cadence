#!/usr/bin/env bash
# Check cross-harness plugin metadata and Cadence command/skill mappings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

failures=0

fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

pass() {
  echo "OK: $*"
}

require_file() {
  local path="$1"
  if [[ -f "$REPO_ROOT/$path" ]]; then
    pass "$path exists"
  else
    fail "$path missing"
  fi
}

command -v jq >/dev/null || {
  echo "FAIL: jq not found"
  exit 1
}

for file in \
  ".claude-plugin/plugin.json" \
  ".claude-plugin/marketplace.json" \
  ".codex-plugin/plugin.json"; do
  require_file "$file"
  jq empty "$REPO_ROOT/$file" >/dev/null || fail "$file is invalid JSON"
done

claude_name="$(jq -r '.name' "$REPO_ROOT/.claude-plugin/plugin.json")"
codex_name="$(jq -r '.name' "$REPO_ROOT/.codex-plugin/plugin.json")"
[[ "$claude_name" == "$codex_name" ]] && pass "Claude/Codex plugin names match" || fail "plugin names differ"

claude_version="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
codex_version="$(jq -r '.version' "$REPO_ROOT/.codex-plugin/plugin.json")"
market_version="$(jq -r '.plugins[0].version' "$REPO_ROOT/.claude-plugin/marketplace.json")"
if [[ "$claude_version" == "$codex_version" && "$codex_version" == "$market_version" ]]; then
  pass "manifest versions match"
else
  fail "version drift: claude=$claude_version codex=$codex_version marketplace=$market_version"
fi

if [[ -f "$REPO_ROOT/.codex-plugin/plugin.json" && -d "$REPO_ROOT/skills" ]]; then
  pass "repository root is the Codex plugin root"
else
  fail "repository root is missing Codex plugin files"
fi

if [[ -e "$REPO_ROOT/.agents" || -e "$REPO_ROOT/plugins/cadence" ]]; then
  fail "redundant Codex marketplace wrapper exists: remove .agents/ and plugins/cadence/"
else
  pass "no redundant Codex marketplace wrapper"
fi

skills_path="$(jq -r '.skills' "$REPO_ROOT/.codex-plugin/plugin.json")"
[[ -d "$REPO_ROOT/$skills_path" ]] && pass "Codex skills path exists" || fail "Codex skills path missing: $skills_path"

for asset in \
  "$(jq -r '.interface.composerIcon // empty' "$REPO_ROOT/.codex-plugin/plugin.json")" \
  "$(jq -r '.interface.logo // empty' "$REPO_ROOT/.codex-plugin/plugin.json")"; do
  [[ -z "$asset" ]] && continue
  [[ -f "$REPO_ROOT/$asset" ]] && pass "asset exists: $asset" || fail "asset missing: $asset"
done

require_file "rules/project-rules.md"
for script in scripts/init-cadence.sh scripts/init-cadence-codex.sh; do
  if grep -q 'rules/project-rules.md' "$REPO_ROOT/$script"; then
    pass "$script reads shared project rules"
  else
    fail "$script does not read shared project rules"
  fi
done

command_skill_pairs=(
  "commands/init.md|skills/cadence-init/SKILL.md"
  "commands/pai.md|skills/cadence-pai/SKILL.md"
  "commands/pai-with-md.md|skills/cadence-pai-review/SKILL.md"
  "commands/may.md|skills/cadence-may/SKILL.md"
  "commands/run.md|skills/cadence-run/SKILL.md"
)

for pair in "${command_skill_pairs[@]}"; do
  command_path="${pair%%|*}"
  skill_path="${pair#*|}"
  require_file "$command_path"
  require_file "$skill_path"
done

require_file "agents/plan-agent.md"
require_file "skills/cadence-run/references/plan-phases.md"
require_file "agents/code-executor.md"
require_file "skills/cadence-run/references/implement-phase.md"

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "$failures consistency check(s) failed."
  exit 1
fi

echo
echo "All plugin consistency checks passed."
