#!/usr/bin/env bash
# Bump or check version fields declared in .version-bump.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

die() {
  echo "error: $*" >&2
  exit 1
}

command -v jq >/dev/null || die "jq not found"
[[ -f "$CONFIG" ]] || die ".version-bump.json not found"

jq_path_for() {
  local field="$1"
  echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./'
}

declared_files() {
  jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"
}

read_field() {
  local file="$1" field="$2"
  jq -r "$(jq_path_for "$field")" "$file"
}

write_field() {
  local file="$1" field="$2" value="$3"
  local tmp
  tmp="$(mktemp)"
  jq "$(jq_path_for "$field") = \"$value\"" "$file" > "$tmp"
  mv "$tmp" "$file"
}

cmd_check() {
  local has_drift=0
  local versions=()

  echo "Version check:"
  echo

  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    if [[ ! -f "$fullpath" ]]; then
      printf "  %-45s  MISSING\n" "$path ($field)"
      has_drift=1
      continue
    fi

    local version
    version="$(read_field "$fullpath" "$field")"
    printf "  %-45s  %s\n" "$path ($field)" "$version"
    versions+=("$version")
  done < <(declared_files)

  echo

  if [[ "${#versions[@]}" -eq 0 ]]; then
    die "no version fields declared"
  fi

  local unique_count
  unique_count="$(printf '%s\n' "${versions[@]}" | sort -u | wc -l | tr -d ' ')"
  if [[ "$unique_count" -gt 1 ]]; then
    echo "DRIFT DETECTED:"
    printf '%s\n' "${versions[@]}" | sort | uniq -c | sort -rn
    has_drift=1
  else
    echo "All declared files are in sync at ${versions[0]}"
  fi

  return "$has_drift"
}

cmd_audit() {
  cmd_check || true
  echo

  local current_version
  current_version="$(
    while IFS=$'\t' read -r path field; do
      [[ -f "$REPO_ROOT/$path" ]] && read_field "$REPO_ROOT/$path" "$field"
    done < <(declared_files) | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
  )"
  [[ -n "$current_version" ]] || die "could not determine current version"

  local -a exclude_args=("--exclude-dir=.git" "--binary-files=without-match")
  while IFS= read -r pattern; do
    exclude_args+=("--exclude=$pattern" "--exclude-dir=$pattern")
  done < <(jq -r '.audit.exclude[]? // empty' "$CONFIG")

  local -a declared_paths=()
  while IFS=$'\t' read -r path _field; do
    declared_paths+=("$path")
  done < <(declared_files)

  local found=0
  while IFS= read -r match; do
    local rel_path
    rel_path="${match%%:*}"
    rel_path="${rel_path#$REPO_ROOT/}"

    local declared=0
    for path in "${declared_paths[@]}"; do
      [[ "$rel_path" == "$path" ]] && declared=1
    done

    if [[ "$declared" -eq 0 ]]; then
      if [[ "$found" -eq 0 ]]; then
        echo "Undeclared files containing '$current_version':"
        found=1
      fi
      echo "  $match"
    fi
  done < <(grep -rn "${exclude_args[@]}" -F "$current_version" "$REPO_ROOT" 2>/dev/null || true)

  [[ "$found" -eq 0 ]] && echo "No undeclared files contain '$current_version'."
}

cmd_bump() {
  local new_version="$1"
  [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "expected semver X.Y.Z"

  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    [[ -f "$fullpath" ]] || die "missing $path"
    local old_version
    old_version="$(read_field "$fullpath" "$field")"
    write_field "$fullpath" "$field" "$new_version"
    printf "  %-45s  %s -> %s\n" "$path ($field)" "$old_version" "$new_version"
  done < <(declared_files)

  echo
  cmd_audit
}

case "${1:-}" in
  --check)
    cmd_check
    ;;
  --audit)
    cmd_audit
    ;;
  --help|-h|"")
    echo "Usage: scripts/bump-version.sh <X.Y.Z> | --check | --audit"
    ;;
  --*)
    die "unknown flag $1"
    ;;
  *)
    cmd_bump "$1"
    ;;
esac
