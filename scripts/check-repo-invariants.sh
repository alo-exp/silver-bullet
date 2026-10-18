#!/usr/bin/env bash
# Repository invariants checked in CI and by `make check`: valid JSON manifests, aligned
# marketplace versions, executable hooks, hooks.json script references, template
# placeholders, required-skill lists, and mirrored workflow docs.
#
# Usage:
#   bash scripts/check-repo-invariants.sh                 # every check
#   bash scripts/check-repo-invariants.sh --check NAME    # one check (repeatable)
#   bash scripts/check-repo-invariants.sh --list          # list check names
#   bash scripts/check-repo-invariants.sh --root DIR      # check another tree
#
# Prints "PASS <check>" or "FAIL <check>" per check and exits 1 when any check fails,
# 64 on a usage error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKS=(json-valid manifest-versions hook-executable hook-references template-placeholders
  deploy-snippet-list required-subset-tracked config-matches-template workflows-mirror)
SELECTED=()

usage_error() {
  echo "check-repo-invariants: $1" >&2
  exit 64
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ -d "${2:-}" ]] || usage_error "no such directory: ${2:-}"
      ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --check)
      [[ " ${CHECKS[*]} " == *" ${2:-} "* ]] || usage_error "unknown check: ${2:-}"
      SELECTED+=("$2")
      shift 2
      ;;
    --list)
      printf '%s\n' "${CHECKS[@]}"
      exit 0
      ;;
    -h | --help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) usage_error "unknown option: $1" ;;
  esac
done
[[ ${#SELECTED[@]} -gt 0 ]] || SELECTED=("${CHECKS[@]}")
cd "$ROOT"

CONFIG=".silver-bullet.json"
TEMPLATE="templates/silver-bullet.config.json.default"

check_json-valid() {
  local f ok=0
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .cursor-plugin/plugin.json \
    .cursor-plugin/marketplace.json .agents/plugins/marketplace.json \
    plugins/silver-bullet/.cursor-plugin/plugin.json plugins/silver-bullet/.codex-plugin/plugin.json \
    hooks/hooks.json "$TEMPLATE" "$CONFIG" package.json; do
    jq empty "$f" >/dev/null 2>&1 || { echo "  invalid JSON: $f"; ok=1; }
  done
  return "$ok"
}

# market_version FILE: version of the silver-bullet entry in a marketplace manifest.
market_version() {
  jq -r '.plugins[] | select(.name == "silver-bullet") | .version' "$1"
}

check_manifest-versions() {
  local ok=0 plugin market pair
  for pair in .claude-plugin/plugin.json:.claude-plugin/marketplace.json \
    .cursor-plugin/plugin.json:.cursor-plugin/marketplace.json \
    plugins/silver-bullet/.codex-plugin/plugin.json:.agents/plugins/marketplace.json; do
    plugin="$(jq -r '.version' "${pair%%:*}")"
    market="$(market_version "${pair#*:}")"
    if [[ "$plugin" != "$market" ]]; then
      echo "  ${pair%%:*} is $plugin but ${pair#*:} is $market (run scripts/sync-release-marketplace-versions.sh)"
      ok=1
    fi
  done
  return "$ok"
}

check_hook-executable() {
  local f ok=0
  for f in hooks/session-start hooks/*.sh scripts/*.sh; do
    [[ -x "$f" ]] || { echo "  not executable: $f"; ok=1; }
  done
  return "$ok"
}

check_hook-references() {
  local cmd script ok=0
  while IFS= read -r cmd; do
    # shellcheck disable=SC2016 # literal ${CLAUDE_PLUGIN_ROOT} in hooks.json commands
    [[ "$cmd" =~ \$\{CLAUDE_PLUGIN_ROOT\}/([^\"[:space:]]+) ]] || continue
    script="${BASH_REMATCH[1]}"
    [[ -f "$script" ]] || { echo "  hooks.json references a missing script: $script"; ok=1; }
  done < <(jq -r '.. | .command? // empty' hooks/hooks.json)
  return "$ok"
}

check_template-placeholders() {
  local ok=0 spec file token
  for spec in scripts/lib/install-claude/templates/CLAUDE.md.base:PROJECT_NAME \
    scripts/lib/install-claude/templates/CLAUDE.md.base:TECH_STACK \
    scripts/lib/install-claude/templates/CLAUDE.md.base:GIT_REPO \
    templates/silver-bullet.md.base:ACTIVE_WORKFLOW \
    "$TEMPLATE:PROJECT_NAME"; do
    file="${spec%:*}"
    token="${spec##*:}"
    grep -q "{{${token}}}" "$file" || { echo "  missing {{${token}}} in $file"; ok=1; }
  done
  return "$ok"
}

# The deploy gate snippet keeps a fallback copy of the template's required_deploy list.
check_deploy-snippet-list() {
  local snippet template
  snippet="$(sed -n 's/^REQUIRED_DEPLOY="\(.*\)"$/\1/p' scripts/deploy-gate-snippet.sh | head -1)"
  template="$(jq -r '.skills.required_deploy | join(" ")' "$TEMPLATE")"
  [[ "$snippet" == "$template" ]] && return 0
  echo "  scripts/deploy-gate-snippet.sh REQUIRED_DEPLOY: $snippet"
  echo "  $TEMPLATE required_deploy: $template"
  return 1
}

# A required skill that is not tracked can never be recorded, so the gate never opens.
check_required-subset-tracked() {
  local ok=0 file missing
  for file in "$TEMPLATE" "$CONFIG"; do
    missing="$(jq -r '
      .skills as $s | ($s.all_tracked // []) as $all |
      ["required_planning", "required_planning_devops", "required_deploy",
       "required_deploy_devops", "required_release", "required_release_devops"][] as $k |
      ($s[$k] // [])[] | select(. as $x | $all | index($x) | not) | "\($k): \(.)"' "$file")"
    if [[ -n "$missing" ]]; then
      echo "  $file: required but not in all_tracked:"
      printf '    %s\n' "$missing"
      ok=1
    fi
  done
  return "$ok"
}

# The dogfood config must carry the same skill lists that new projects receive.
check_config-matches-template() {
  local ok=0 key
  for key in required_deploy all_tracked required_planning required_planning_devops required_deploy_devops; do
    if [[ "$(jq -c --arg k "$key" '.skills[$k] // [] | sort' "$CONFIG")" != \
      "$(jq -c --arg k "$key" '.skills[$k] // [] | sort' "$TEMPLATE")" ]]; then
      echo "  skills.$key differs between $CONFIG and $TEMPLATE"
      ok=1
    fi
  done
  return "$ok"
}

check_workflows-mirror() {
  local out
  out="$(diff -r docs/workflows templates/workflows 2>&1)" && return 0
  echo "  docs/workflows and templates/workflows differ:"
  printf '%s\n' "$out" | sed -n '1,20p' | sed 's/^/    /'
  return 1
}

status=0
for check in "${SELECTED[@]}"; do
  if out="$("check_$check" 2>&1)"; then
    echo "PASS $check"
  else
    echo "FAIL $check"
    status=1
  fi
  [[ -z "$out" ]] || printf '%s\n' "$out"
done
exit "$status"
