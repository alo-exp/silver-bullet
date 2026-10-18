#!/usr/bin/env bash
# CLI behavior of scripts/validate-claude-agent-token-budget.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/validate-claude-agent-token-budget.sh"

mkroot() {
  local root="$1"
  mkdir -p "$root/agents/claude/alpha" "$root/agents/claude/beta" "$root/agents/claude/gamma" "$root/agents/claude/delta"
  printf -- '---\nname: alpha\ndescription: "%s"\n---\nbody\n' "$(printf 'a%.0s' {1..400})" >"$root/agents/claude/alpha/SKILL.md"
  printf -- '---\nname: beta\ndescription: %s\nuser-invocable: false\n---\n' "$(printf 'b%.0s' {1..40})" >"$root/agents/claude/beta/SKILL.md"
  printf -- '---\nname: gamma\ndescription: >\n  folded\n---\n' >"$root/agents/claude/gamma/SKILL.md"
  printf 'no frontmatter here\n' >"$root/agents/claude/delta/SKILL.md"
}

# --help prints the header comment and exits 0
tl_run bash "$SCRIPT" --help
assert_eq "help exits 0" 0 "$TL_STATUS"
assert_contains "help shows usage" "$TL_OUT" "validate-claude-agent-token-budget.sh [--repo-root PATH]"

# unknown argument exits 2 with a message on stderr
tl_run bash "$SCRIPT" --bogus
assert_eq "unknown arg exits 2" 2 "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "unknown argument: --bogus"

# missing python3
NOPY="$(tl_path_without python3)"
tl_run env PATH="$NOPY" bash "$SCRIPT" --repo-root "$TL_TMP/none"
assert_eq "no python3 exits 1" 1 "$TL_STATUS"
assert_contains "no python3 message" "$TL_ERR" "python3 required"

# missing agents/claude directory
mkdir -p "$TL_TMP/empty"
tl_run bash "$SCRIPT" --repo-root "$TL_TMP/empty"
assert_eq "missing agents/claude exits 1" 1 "$TL_STATUS"
assert_contains "missing dir message" "$TL_OUT" "missing $TL_TMP/empty/agents/claude"

# within budget: counts only skills that have a plain description
mkroot "$TL_TMP/r1"
tl_run bash "$SCRIPT" --repo-root "$TL_TMP/r1"
assert_eq "within budget exits 0" 0 "$TL_STATUS"
assert_contains "two counted skills, ~110 tokens" "$TL_OUT" "2 skills, ~110 tokens (all)"
assert_contains "user-invocable subset excludes beta" "$TL_OUT" "1 skills, ~100 tokens"
assert_contains "top list" "$TL_OUT" "~100  alpha"
assert_contains "pass line" "$TL_OUT" "PASS: Claude agent description token budget"

# over budget
tl_run bash "$SCRIPT" --repo-root "$TL_TMP/r1" --max-tokens 50
assert_eq "over budget exits 1" 1 "$TL_STATUS"
assert_contains "fail line" "$TL_OUT" "FAIL: total description tokens ~110 exceed budget 50"

# default repo-root resolves to the checkout and the shipped agents pass
tl_run bash "$SCRIPT"
assert_eq "repo agents within default budget" 0 "$TL_STATUS"

tl_results
