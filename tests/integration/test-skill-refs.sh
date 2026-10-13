#!/usr/bin/env bash
# test-skill-refs.sh — CONS-01 regression guard
#
# Scans every skills/**/SKILL.md for host-recognized skill invocation patterns,
# extracts the skill reference, normalizes it, and verifies each resolves to
# a real skill in the repo or in the declared external-plugin skill catalog.
#
# Why a declared catalog rather than pure filesystem scan: the upstream
# plugins (engineering, design, product-management, superpowers,
# multai, episodic-memory, context7-plugin) are resolved by the Claude
# runtime — their SKILL.md files may live outside ${SB_RUNTIME_HOME_ROOT}/plugins in
# CI/fresh-clone environments. We pin the set of expected external skills
# explicitly so CI can run deterministically.
#
# To add a new cross-plugin skill reference, add the qualified name
# (plugin:skill) OR the bare skill to EXTERNAL_SKILLS / BUILTIN_WHITELIST.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

BUILTIN_WHITELIST=(
  compact clear help
)

EXTERNAL_SKILLS=(
  writing-plans writing-skills verification-before-completion
  receiving-code-review requesting-code-review brainstorming
  finishing-a-development-branch executing-plans dispatching-parallel-agents
  using-superpowers systematic-debugging test-driven-development
  using-git-worktrees subagent-driven-development
  architecture system-design code-review testing-strategy documentation
  deploy-checklist tech-debt incident-response debug standup
  user-research ux-copy research-synthesis accessibility-review
  design-system design-critique design-handoff
  brainstorm write-spec roadmap-update metrics-review sprint-planning
  competitive-brief synthesize-research product-brainstorming stakeholder-update
  orchestrator comparator consolidator landscape-researcher solution-researcher
  remembering-conversations search-conversations context7-mcp docs
)

CATALOG_FILE=$(mktemp)
trap 'rm -f "$CATALOG_FILE"' EXIT
ls "$REPO_ROOT/skills" 2>/dev/null | sort -u > "$CATALOG_FILE"

in_local_catalog() { grep -qxF "$1" "$CATALOG_FILE"; }
in_external() {
  local n="$1"
  for s in "${EXTERNAL_SKILLS[@]}"; do [[ "$s" == "$n" ]] && return 0; done
  return 1
}
is_builtin() {
  local n="$1"
  for s in "${BUILTIN_WHITELIST[@]}"; do [[ "$s" == "$n" ]] && return 0; done
  return 1
}

resolve_ref() {
  local raw="$1"
  raw="${raw#/}"
  local cmd="${raw%% *}"
  local prefix="" bare
  if [[ "$cmd" == *:* ]]; then
    prefix="${cmd%:*}"
    bare="${cmd##*:}"
  else
    bare="$cmd"
  fi
  is_builtin "$bare" && return 0
  in_local_catalog "$bare" && return 0
  in_external "$bare" && return 0
  if [[ "$prefix" == "silver" || "$prefix" == "sb" ]]; then
    in_local_catalog "silver-$bare" && return 0
  fi
  return 1
}

echo "[skill-refs] scanning skills/**/SKILL.md"
while IFS= read -r skill_file; do
  rel="${skill_file#$REPO_ROOT/}"
  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    if resolve_ref "$raw"; then
      pass
    else
      fail "$rel — unresolved skill reference: \`$raw\`"
    fi
  done < <(
    {
      grep -oE -i 'invoke `[^`]+` via the Skill tool' "$skill_file" \
        | sed -E 's/^[Ii]nvoke `([^`]+)` via the Skill tool$/\1/'
      grep -oE -i 'invoke `[^`]+` through the active runtime'\''s SB-recognized skill invocation channel' "$skill_file" \
        | sed -E 's/^[Ii]nvoke `([^`]+)` through the active runtime'\''s SB-recognized skill invocation channel$/\1/'
    } | sort -u
  )
done < <(find "$REPO_ROOT/skills" -name SKILL.md)

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
