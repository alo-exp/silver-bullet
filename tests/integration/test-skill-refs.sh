#!/usr/bin/env bash
# test-skill-refs.sh — CONS-01 regression guard
#
# Scans every skills/**/SKILL.md for 'invoke `X` via the Skill tool' patterns,
# extracts the skill reference, normalizes it, and verifies each resolves to
# a real skill in the repo or in the declared external-plugin skill catalog.
# Also validates any `gsd-review --<flag>` usage against gsd-review's
# authoritative flag list.
#
# Why a declared catalog rather than pure filesystem scan: the upstream
# plugins (engineering, design, product-management, superpowers, gsd,
# multai, episodic-memory, context7-plugin) are resolved by the Claude
# runtime — their SKILL.md files may live outside ~/.claude/plugins in
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

# ---------------------------------------------------------------------------
# Built-in slash commands (resolved by the Claude harness, not a plugin).
# ---------------------------------------------------------------------------
BUILTIN_WHITELIST=(
  compact clear help
)

# ---------------------------------------------------------------------------
# External-plugin skills Silver Bullet is allowed to invoke. Plugin prefix
# is optional — both `plugin:skill` and bare `skill` are accepted.
# ---------------------------------------------------------------------------
EXTERNAL_SKILLS=(
  # gsd (get-shit-done)
  gsd-do gsd-new-project gsd-new-milestone gsd-plan-phase gsd-execute-phase
  gsd-autonomous gsd-discuss-phase gsd-secure-phase gsd-ui-phase gsd-ui-review
  gsd-ship gsd-debug gsd-verify-work gsd-review gsd-code-review
  gsd-code-review-fix gsd-docs-update gsd-pr-branch gsd-add-tests
  gsd-scan gsd-map-codebase gsd-forensics gsd-add-backlog gsd-add-todo
  gsd-analyze-dependencies gsd-audit-milestone gsd-audit-uat
  gsd-milestone-summary gsd-complete-milestone gsd-plan-milestone-gaps
  gsd-validate-phase gsd-fast gsd-quick gsd-update gsd-resume-work
  # superpowers
  writing-plans writing-skills verification-before-completion
  receiving-code-review requesting-code-review brainstorming
  finishing-a-development-branch executing-plans dispatching-parallel-agents
  using-superpowers systematic-debugging test-driven-development
  using-git-worktrees subagent-driven-development
  # engineering
  architecture system-design code-review testing-strategy documentation
  deploy-checklist tech-debt incident-response debug standup
  # design
  user-research ux-copy research-synthesis accessibility-review
  design-system design-critique design-handoff
  # product-management
  brainstorm write-spec roadmap-update metrics-review sprint-planning
  competitive-brief synthesize-research product-brainstorming stakeholder-update
  # multai
  orchestrator comparator consolidator landscape-researcher solution-researcher
  # episodic-memory / context7
  remembering-conversations search-conversations context7-mcp docs
)

# ---------------------------------------------------------------------------
# Authoritative gsd-review flag list (from gsd-review SKILL.md argument-hint).
# ---------------------------------------------------------------------------
GSD_REVIEW_FLAGS=(--phase --gemini --claude --codex --opencode --qwen --cursor --all --reviews)

# ---------------------------------------------------------------------------
# Build local repo skill catalog.
# ---------------------------------------------------------------------------
CATALOG_FILE=$(mktemp)
trap 'rm -f "$CATALOG_FILE"' EXIT
ls "$REPO_ROOT/skills" 2>/dev/null | sort -u > "$CATALOG_FILE"
# Also accept names prefixed with `silver-` when the raw ref is `silver:<x>`
# (e.g. silver:validate → silver-validate).

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
is_gsd_review_flag() {
  local f="$1"
  for g in "${GSD_REVIEW_FLAGS[@]}"; do [[ "$g" == "$f" ]] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
# Resolve raw ref to candidate skill names. Returns 0 if any resolve.
# ---------------------------------------------------------------------------
resolve_ref() {
  local raw="$1"
  # Strip leading slash
  raw="${raw#/}"
  # Take first whitespace-delimited token as the command.
  local cmd="${raw%% *}"

  local prefix="" bare
  if [[ "$cmd" == *:* ]]; then
    prefix="${cmd%:*}"
    bare="${cmd##*:}"
  else
    bare="$cmd"
  fi

  # Direct candidates.
  is_builtin "$bare" && return 0
  in_local_catalog "$bare" && return 0
  in_external "$bare" && return 0

  # silver:foo → silver-foo in local catalog.
  if [[ "$prefix" == "silver" ]]; then
    in_local_catalog "silver-$bare" && return 0
  fi

  return 1
}

extract_flags() {
  printf '%s\n' "$1" | grep -oE -- '--[a-z][a-z0-9-]*' || true
}

# ---------------------------------------------------------------------------
# Scan every SKILL.md under skills/.
# ---------------------------------------------------------------------------
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

    # gsd-review flag check
    local_raw="${raw#/}"
    if [[ "$local_raw" == gsd-review* ]]; then
      while IFS= read -r flag; do
        [[ -z "$flag" ]] && continue
        if is_gsd_review_flag "$flag"; then
          pass
        else
          fail "$rel — gsd-review invoked with unknown flag: $flag (in: \`$raw\`)"
        fi
      done < <(extract_flags "$raw")
    fi
  done < <(grep -oE -i 'invoke `[^`]+` via the Skill tool' "$skill_file" \
           | sed -E 's/^[Ii]nvoke `([^`]+)` via the Skill tool$/\1/')
done < <(find "$REPO_ROOT/skills" -name SKILL.md)

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
