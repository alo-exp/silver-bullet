#!/usr/bin/env bash
# Repository invariants checked in CI and by `make check`: valid JSON manifests, aligned
# marketplace versions and release identity, executable entry points, hooks.json script
# references, template placeholders, required-skill lists, mirrored workflow docs, worm
# indicators, file signatures, vendored skills, tracked file sizes, unique site element ids
# and hardened GitHub Actions workflows.
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

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SELF_DIR}/.." && pwd)"
CHECKS=(json-valid manifest-versions release-identity hook-executable hook-references
  template-placeholders deploy-snippet-list required-subset-tracked config-matches-template
  workflows-mirror worm-indicators binary-signatures vendored-skills-lock tracked-file-size
  site-duplicate-ids workflow-hardening)
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
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
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
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .agents/plugins/marketplace.json \
    plugins/silver-bullet/.codex-plugin/plugin.json \
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

# Release-identity surfaces beyond the manifests (tests/scripts/test-release-version-alignment.sh
# covers the plugin manifests, catalog, README and SECURITY.md): the Codex marketplace ref, the
# newest CHANGELOG release and the dogfood config version.
check_release-identity() {
  local ok=0 pkg ref changelog cfg tmpl
  pkg="$(jq -r '.version' package.json)"
  ref="$(jq -r '.plugins[] | select(.name == "silver-bullet") | .source.ref // empty' .agents/plugins/marketplace.json)"
  if [[ "$ref" != "v$pkg" ]]; then
    echo "  .agents/plugins/marketplace.json silver-bullet source.ref is ${ref:-<missing>}, expected v$pkg"
    ok=1
  fi
  # The newest released version: an [Unreleased] section above it is allowed.
  changelog="$(grep -m 1 -E '^## \[[0-9]' CHANGELOG.md | sed -E 's/^## \[([^]]*)\].*/\1/' || true)"
  if [[ "$changelog" != "$pkg" ]]; then
    echo "  the newest CHANGELOG.md release is ${changelog:-<none>}, but package.json is $pkg"
    ok=1
  fi
  # An older config_version makes the hooks treat the dogfood config as a legacy config.
  cfg="$(jq -r '.config_version // .version // empty' "$CONFIG")"
  tmpl="$(jq -r '.config_version // empty' "$TEMPLATE")"
  if [[ "$cfg" != "$tmpl" ]]; then
    echo "  $CONFIG config_version is ${cfg:-<missing>}, but $TEMPLATE is $tmpl"
    ok=1
  fi
  return "$ok"
}

# Entry points must be executable: every top-level hooks/ and scripts/ file that is a *.sh or
# starts with a Bash shebang (hooks/session-start, scripts/silver-bullet, ...). Libraries
# below hooks/lib and scripts/lib are sourced, not run.
check_hook-executable() {
  local f ok=0 bash_shebang_re='^#!.*[/ ]bash([[:space:]]|$)'
  for f in hooks/* scripts/*; do
    [[ -f "$f" ]] || continue
    if [[ "$f" != *.sh ]]; then
      local first=""
      IFS= read -r first <"$f" || true
      [[ "$first" =~ $bash_shebang_re ]] || continue
    fi
    [[ -x "$f" ]] || { echo "  not executable: $f"; ok=1; }
  done
  return "$ok"
}

# Every hooks.json command must name a plugin script written as ${CLAUDE_PLUGIN_ROOT}/... or
# $CLAUDE_PLUGIN_ROOT/..., and that script must exist. A bare hooks/... or scripts/... path
# would resolve against the user's project at runtime and run project-controlled code.
check_hook-references() {
  local cmd script bare ok=0 named
  while IFS= read -r cmd; do
    named=0
    # Every ${CLAUDE_PLUGIN_ROOT}/ path in the command must exist, not only the first.
    while IFS= read -r script; do
      named=1
      [[ -f "$script" ]] || { echo "  hooks.json references a missing script: $script"; ok=1; }
    done < <(printf '%s\n' "$cmd" | grep -oE '\$\{?CLAUDE_PLUGIN_ROOT\}?"?/[^"'"'"'[:space:]&|;]+' | sed -E 's|^.*CLAUDE_PLUGIN_ROOT\}?"?/||')
    # A bare hooks/ or scripts/ path anywhere in the command resolves against the user's project.
    while IFS= read -r bare; do
      named=1
      echo "  hooks.json runs $bare relative to the working directory (the user's project); use \${CLAUDE_PLUGIN_ROOT}/$bare"
      ok=1
    done < <(printf '%s\n' "$cmd" | sed -E 's|\$\{?CLAUDE_PLUGIN_ROOT\}?"?/[^"'"'"'[:space:]&|;]+||g' | tr -s '[:space:]"'"'"'&|;' '\n' | grep -E '^(hooks|scripts)/' || true)
    if [[ "$named" == 0 ]]; then
      echo "  hooks.json command names no hooks/ or scripts/ file: $cmd"
      ok=1
    fi
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

# The deploy gate snippet and prompt-reminder.sh keep fallback copies of the template's
# required_deploy list. Every ${DEFAULT_REQUIRED<op>...} default in prompt-reminder.sh is
# compared, whichever expansion operator it uses, and finding none is a failure.
check_deploy-snippet-list() {
  local ok=0 snippet template literal literals
  snippet="$(sed -n 's/^REQUIRED_DEPLOY="\(.*\)"$/\1/p' scripts/deploy-gate-snippet.sh | head -1)"
  template="$(jq -r '.skills.required_deploy | join(" ")' "$TEMPLATE")"
  if [[ "$snippet" != "$template" ]]; then
    echo "  scripts/deploy-gate-snippet.sh REQUIRED_DEPLOY: $snippet"
    ok=1
  fi
  literals="$(grep -oE '\$\{DEFAULT_REQUIRED(:-|:=|-|=)[^}]*\}' hooks/prompt-reminder.sh |
    sed -E 's/^\$\{DEFAULT_REQUIRED(:-|:=|-|=)//; s/\}$//' || true)"
  if [[ -z "$literals" ]]; then
    echo "  hooks/prompt-reminder.sh: no DEFAULT_REQUIRED fallback list to compare"
    ok=1
  fi
  while IFS= read -r literal; do
    [[ -z "$literal" || "$literal" == "$template" ]] && continue
    echo "  hooks/prompt-reminder.sh DEFAULT_REQUIRED fallback: $literal"
    ok=1
  done <<<"$literals"
  [[ "$ok" == 0 ]] || echo "  $TEMPLATE required_deploy: $template"
  return "$ok"
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

# The dogfood config must carry the same skill lists that new projects receive: every list
# either file defines.
check_config-matches-template() {
  local ok=0 key
  while IFS= read -r key; do
    if [[ "$(jq -c --arg k "$key" '.skills[$k] // [] | sort' "$CONFIG")" != \
      "$(jq -c --arg k "$key" '.skills[$k] // [] | sort' "$TEMPLATE")" ]]; then
      echo "  skills.$key differs between $CONFIG and $TEMPLATE"
      ok=1
    fi
  done < <(jq -rs '[.[].skills // {} | to_entries[] | select(.value | type == "array") | .key] | unique[]' \
    "$CONFIG" "$TEMPLATE")
  return "$ok"
}

check_workflows-mirror() {
  local out
  out="$(diff -r docs/workflows templates/workflows 2>&1)" && return 0
  echo "  docs/workflows and templates/workflows differ:"
  printf '%s\n' "$out" | sed -n '1,20p' | sed 's/^/    /'
  return 1
}

# File-content checks over the tracked files (scripts/lib/repo_invariants.py, from this
# script's own tree, never from the tree under check).
check_worm-indicators() { python3 "$SELF_DIR/lib/repo_invariants.py" worm-indicators .; }
check_binary-signatures() { python3 "$SELF_DIR/lib/repo_invariants.py" binary-signatures .; }
check_vendored-skills-lock() { python3 "$SELF_DIR/lib/repo_invariants.py" vendored-skills-lock .; }
check_tracked-file-size() { python3 "$SELF_DIR/lib/repo_invariants.py" tracked-file-size .; }
check_site-duplicate-ids() { python3 "$SELF_DIR/lib/repo_invariants.py" site-duplicate-ids .; }
check_workflow-hardening() { python3 "$SELF_DIR/lib/repo_invariants.py" workflow-hardening .; }

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
