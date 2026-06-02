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

require_mirror() {
  local source_path="$1"
  local mirror_path="$2"

  require_file "$source_path"
  require_file "$mirror_path"

  if [[ -f "$REPO_ROOT/$source_path" && -f "$REPO_ROOT/$mirror_path" ]]; then
    if cmp -s "$REPO_ROOT/$source_path" "$REPO_ROOT/$mirror_path"; then
      pass "$mirror_path mirrors $source_path"
    else
      fail "$mirror_path differs from $source_path"
    fi
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
if [[ "$skills_path" == "./skills/" && -d "$REPO_ROOT/skills" ]]; then
  pass "Codex skills root is ./skills/"
else
  fail "Codex skills root should be ./skills/, got: $skills_path"
fi

if find "$REPO_ROOT/skills" -maxdepth 1 -type d -name 'cadence-*' | grep -q .; then
  fail "removed per-command Codex skills still exist under skills/cadence-*"
else
  pass "no per-command Codex skill directories"
fi

expected_skills="cadence onboarding tdd"
actual_skills="$(
  find "$REPO_ROOT/skills" -maxdepth 2 -name SKILL.md -print |
    sed "s#^$REPO_ROOT/skills/##; s#/SKILL.md##" |
    grep -v / |
    sort |
    tr '\n' ' ' |
    sed 's/ $//'
)"
if [[ "$actual_skills" == "$expected_skills" ]]; then
  pass "Codex exposes expected top-level skills: $expected_skills"
else
  fail "unexpected top-level Codex skills: $actual_skills"
fi

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

command_reference_pairs=(
  "commands/init.md|skills/cadence/references/init.md"
  "commands/pai.md|skills/cadence/references/pai.md"
  "commands/pai-with-md.md|skills/cadence/references/pai-review.md"
  "commands/may.md|skills/cadence/references/may.md"
  "commands/run.md|skills/cadence/references/run.md"
)

for pair in "${command_reference_pairs[@]}"; do
  command_path="${pair%%|*}"
  reference_path="${pair#*|}"
  require_mirror "$command_path" "$reference_path"
done

agent_reference_pairs=(
  "agents/code-reviewer.md|skills/cadence/references/code-review.md"
  "agents/research-agent.md|skills/cadence/references/research.md"
  "agents/md-to-html.md|skills/cadence/references/md-to-html.md"
  "agents/plan-agent.md|skills/cadence/references/plan-phases.md"
  "agents/code-executor.md|skills/cadence/references/implement-phase.md"
)

for pair in "${agent_reference_pairs[@]}"; do
  agent_path="${pair%%|*}"
  reference_path="${pair#*|}"
  require_mirror "$agent_path" "$reference_path"
done

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "$failures consistency check(s) failed."
  exit 1
fi

echo
echo "All plugin consistency checks passed."
