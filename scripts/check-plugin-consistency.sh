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

require_dir() {
  local path="$1"
  if [[ -d "$REPO_ROOT/$path" ]]; then
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

require_tree_mirror() {
  local source_path="$1"
  local mirror_path="$2"

  require_dir "$source_path"
  require_dir "$mirror_path"

  if [[ -d "$REPO_ROOT/$source_path" && -d "$REPO_ROOT/$mirror_path" ]]; then
    if diff -qr "$REPO_ROOT/$source_path" "$REPO_ROOT/$mirror_path" >/dev/null; then
      pass "$mirror_path mirrors $source_path"
    else
      fail "$mirror_path differs from $source_path"
    fi
  fi
}

require_codex_reference() {
  local action="$1"
  local command_path="$2"
  local reference_path="$3"
  local reference_file="$REPO_ROOT/$reference_path"

  require_file "$command_path"
  require_file "$reference_path"

  if [[ -f "$reference_file" ]]; then
    if grep -q "# cadence:$action" "$reference_file"; then
      pass "$reference_path declares cadence:$action"
    else
      fail "$reference_path should declare # cadence:$action"
    fi

    if grep -Eq '\$ARGUMENTS|allowed-tools:|argument-hint:|AskUserQuestion|Agent\(subagent_type=|Read |Write |Bash|Edit|用法：/cadence:' "$reference_file"; then
      fail "$reference_path contains Claude-only command/tool syntax"
    else
      pass "$reference_path removes Claude-only command/tool syntax"
    fi
  fi
}

require_codex_agent_portable() {
  local asset_path="$1"
  local agent_file="$REPO_ROOT/$asset_path"

  require_file "$asset_path"

  if [[ -f "$agent_file" ]]; then
    if grep -Eq 'CLAUDE_PLUGIN_ROOT|WebSearch|WebFetch|AskUserQuestion|Agent\(subagent_type=|allowed-tools:|argument-hint:|(^|[^[:alnum:]_])(Read|Write|Bash|Edit|Grep|Glob)([^[:alnum:]_]|$)|CLAUDE\.md|mcp__context7__' "$agent_file"; then
      fail "$asset_path contains Claude-only command/tool syntax"
    else
      pass "$asset_path removes Claude-only command/tool syntax"
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
  ".agents/plugins/marketplace.json" \
  "plugins/cadence/.codex-plugin/plugin.json" \
  ".codex-plugin/plugin.json"; do
  require_file "$file"
  jq empty "$REPO_ROOT/$file" >/dev/null || fail "$file is invalid JSON"
done

claude_name="$(jq -r '.name' "$REPO_ROOT/.claude-plugin/plugin.json")"
codex_name="$(jq -r '.name' "$REPO_ROOT/.codex-plugin/plugin.json")"
codex_wrapper_name="$(jq -r '.name' "$REPO_ROOT/plugins/cadence/.codex-plugin/plugin.json")"
if [[ "$claude_name" == "$codex_name" && "$codex_name" == "$codex_wrapper_name" ]]; then
  pass "Claude/Codex plugin names match"
else
  fail "plugin names differ"
fi

claude_version="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
codex_version="$(jq -r '.version' "$REPO_ROOT/.codex-plugin/plugin.json")"
codex_wrapper_version="$(jq -r '.version' "$REPO_ROOT/plugins/cadence/.codex-plugin/plugin.json")"
market_version="$(jq -r '.plugins[0].version' "$REPO_ROOT/.claude-plugin/marketplace.json")"
if [[ "$claude_version" == "$codex_version" &&
      "$codex_version" == "$codex_wrapper_version" &&
      "$codex_wrapper_version" == "$market_version" ]]; then
  pass "manifest versions match"
else
  fail "version drift: claude=$claude_version codex=$codex_version wrapper=$codex_wrapper_version marketplace=$market_version"
fi

if [[ -f "$REPO_ROOT/.codex-plugin/plugin.json" && -d "$REPO_ROOT/skills" ]]; then
  pass "repository root is the Codex plugin root"
else
  fail "repository root is missing Codex plugin files"
fi

if [[ -f "$REPO_ROOT/plugins/cadence/.codex-plugin/plugin.json" && -d "$REPO_ROOT/plugins/cadence/skills" ]]; then
  pass "plugins/cadence is a complete Codex plugin package"
else
  fail "plugins/cadence is missing Codex plugin files"
fi

require_mirror ".codex-plugin/plugin.json" "plugins/cadence/.codex-plugin/plugin.json"
require_tree_mirror "skills" "plugins/cadence/skills"
require_tree_mirror "assets" "plugins/cadence/assets"
require_tree_mirror "rules" "plugins/cadence/rules"
require_mirror "scripts/init-cadence-codex.sh" "plugins/cadence/scripts/init-cadence-codex.sh"
require_mirror "scripts/install-codex-agents.sh" "plugins/cadence/scripts/install-codex-agents.sh"
require_mirror "README.md" "plugins/cadence/README.md"
require_mirror "LICENSE" "plugins/cadence/LICENSE"

codex_marketplace_name="$(jq -r '.name' "$REPO_ROOT/.agents/plugins/marketplace.json")"
if [[ "$codex_marketplace_name" == "cadence-marketplace" ]]; then
  pass "Codex marketplace name is cadence-marketplace"
else
  fail "Codex marketplace name should be cadence-marketplace, got: $codex_marketplace_name"
fi

codex_market_plugin_name="$(jq -r '.plugins[0].name' "$REPO_ROOT/.agents/plugins/marketplace.json")"
if [[ "$codex_market_plugin_name" == "$codex_name" ]]; then
  pass "Codex marketplace plugin name matches manifest"
else
  fail "Codex marketplace plugin name should be $codex_name, got: $codex_market_plugin_name"
fi

codex_market_source="$(jq -r '.plugins[0].source.source' "$REPO_ROOT/.agents/plugins/marketplace.json")"
codex_market_path="$(jq -r '.plugins[0].source.path' "$REPO_ROOT/.agents/plugins/marketplace.json")"
if [[ "$codex_market_source" == "local" && "$codex_market_path" == "./plugins/cadence" ]]; then
  pass "Codex marketplace points at plugins/cadence"
else
  fail "Codex marketplace should use local source path ./plugins/cadence, got: source=$codex_market_source path=$codex_market_path"
fi

codex_market_installation="$(jq -r '.plugins[0].policy.installation' "$REPO_ROOT/.agents/plugins/marketplace.json")"
codex_market_authentication="$(jq -r '.plugins[0].policy.authentication' "$REPO_ROOT/.agents/plugins/marketplace.json")"
codex_market_category="$(jq -r '.plugins[0].category' "$REPO_ROOT/.agents/plugins/marketplace.json")"
if [[ "$codex_market_installation" == "AVAILABLE" &&
      "$codex_market_authentication" == "ON_INSTALL" &&
      "$codex_market_category" == "Productivity" ]]; then
  pass "Codex marketplace policy and category are installable"
else
  fail "Codex marketplace should be AVAILABLE/ON_INSTALL/Productivity"
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

require_file "scripts/install-codex-agents.sh"
if grep -q 'assets/codex-agents' "$REPO_ROOT/scripts/install-codex-agents.sh" &&
   grep -q 'CODEX_HOME' "$REPO_ROOT/scripts/install-codex-agents.sh" &&
   grep -q '.codex' "$REPO_ROOT/scripts/install-codex-agents.sh" &&
   grep -q '__CADENCE_PLUGIN_ROOT__' "$REPO_ROOT/scripts/install-codex-agents.sh"; then
  pass "scripts/install-codex-agents.sh installs bundled Codex agents"
else
  fail "scripts/install-codex-agents.sh should install assets/codex-agents into CODEX_HOME agents and template plugin-root placeholders"
fi

codex_reference_pairs=(
  "pai-with-md|commands/pai-with-md.md|skills/cadence/references/pai-with-md.md"
  "may|commands/may.md|skills/cadence/references/may.md"
  "run|commands/run.md|skills/cadence/references/run.md"
)

for pair in "${codex_reference_pairs[@]}"; do
  action="${pair%%|*}"
  rest="${pair#*|}"
  command_path="${rest%%|*}"
  reference_path="${rest#*|}"
  require_codex_reference "$action" "$command_path" "$reference_path"
done

require_file "commands/init.md"
require_file "skills/cadence/references/init.md"
if grep -q 'init-cadence.sh' "$REPO_ROOT/commands/init.md" &&
   grep -q 'init-cadence-codex.sh' "$REPO_ROOT/skills/cadence/references/init.md" &&
   grep -q 'install-codex-agents.sh' "$REPO_ROOT/skills/cadence/references/init.md"; then
  pass "Claude/Codex init entries use harness-specific scripts"
else
  fail "init entries should use harness-specific scripts"
fi

require_file "commands/pai.md"
require_file "skills/cadence/references/pai.md"
if grep -q 'allowed-tools:' "$REPO_ROOT/commands/pai.md" &&
   ! grep -q 'allowed-tools:\|AskUserQuestion\|Agent(subagent_type=' "$REPO_ROOT/skills/cadence/references/pai.md"; then
  pass "Codex pai reference removes Claude-only tool declarations"
else
  fail "Codex pai reference should not contain Claude-only tool declarations"
fi

require_file "skills/cadence/SKILL.md"
if grep -q '直接调用 `research-agent`' "$REPO_ROOT/skills/cadence/SKILL.md" &&
   grep -q '直接调用 `code-reviewer`' "$REPO_ROOT/skills/cadence/SKILL.md" &&
   grep -q '直接调用 `md-to-html`' "$REPO_ROOT/skills/cadence/SKILL.md" &&
   ! grep -q '完整指引\|agent TOML\|作为指引' "$REPO_ROOT/skills/cadence/SKILL.md"; then
  pass "Codex cadence skill routes installed agents by name"
else
  fail "Codex cadence skill should route installed agents by name without TOML prompt instructions"
fi

codex_agent_assets=(
  "assets/codex-agents/code-reviewer.toml|name = \"code-reviewer\""
  "assets/codex-agents/research-agent.toml|name = \"research-agent\""
  "assets/codex-agents/md-to-html.toml|name = \"md-to-html\""
  "assets/codex-agents/plan-agent.toml|name = \"plan-agent\""
  "assets/codex-agents/code-executor.toml|name = \"code-executor\""
)

for pair in "${codex_agent_assets[@]}"; do
  asset_path="${pair%%|*}"
  expected_name="${pair#*|}"
  require_file "$asset_path"
  if [[ -f "$REPO_ROOT/$asset_path" ]] && grep -q "$expected_name" "$REPO_ROOT/$asset_path"; then
    pass "$asset_path declares $expected_name"
  else
    fail "$asset_path should declare $expected_name"
  fi

  require_codex_agent_portable "$asset_path"
done

if grep -q '__CADENCE_PLUGIN_ROOT__' "$REPO_ROOT/assets/codex-agents/md-to-html.toml"; then
  pass "assets/codex-agents/md-to-html.toml keeps install-time plugin-root placeholder"
else
  fail "assets/codex-agents/md-to-html.toml should keep __CADENCE_PLUGIN_ROOT__ for install-time templating"
fi

if grep -q 'design_assets_root' "$REPO_ROOT/assets/codex-agents/md-to-html.toml"; then
  fail "assets/codex-agents/md-to-html.toml should not expose design_assets_root override"
else
  pass "assets/codex-agents/md-to-html.toml uses bundled design assets only"
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "$failures consistency check(s) failed."
  exit 1
fi

echo
echo "All plugin consistency checks passed."
