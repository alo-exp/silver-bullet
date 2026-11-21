#!/usr/bin/env bash
# Runtime docs must describe what the adapters and runtime detection really do (R7-05, R7-10).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

COMPAT="$TL_REPO_ROOT/docs/RUNTIME-COMPATIBILITY.md"
EXT="$TL_REPO_ROOT/docs/runtime-extensibility-comparison.md"

assert_not_contains "no claim that the adapter translates tool names" "$(cat "$EXT")" "translated by \`codex-hook-adapter.sh\`"
assert_contains "extensibility doc: adapter only reshapes output" "$(cat "$EXT")" "does no tool-name translation"
assert_contains "compat doc: adapter does not translate tool names" "$(cat "$COMPAT")" "does **not** translate tool names"
assert_contains "compat doc: goose and hermes need SILVER_BULLET_RUNTIME" "$(cat "$COMPAT")" "Goose and Hermes are never auto-detected"
assert_contains "compat doc: CLAUDE_PLUGIN_ROOT only matters for /.codex/" "$(cat "$COMPAT")" "contains \`/.codex/\`"
assert_contains "compat doc: Kay limits section" "$(cat "$COMPAT")" "### Kay limits"
assert_contains "compat doc: Kay has no Stop gating" "$(cat "$COMPAT")" "no Stop, SubagentStop or UserPromptSubmit gating"

# The documented detection really behaves that way.
detect() { env -i HOME="$TL_TMP" PATH="$PATH" "$@" bash -c 'source "$1/hooks/lib/runtime-paths.sh"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_REPO_ROOT"; }
assert_eq "goose is not auto-detected" "claude" "$(detect GOOSE_PROVIDER=x)"
assert_eq "hermes is not auto-detected" "claude" "$(detect HERMES_HOME=/h)"
assert_eq "SILVER_BULLET_RUNTIME=goose selects goose" "goose" "$(detect SILVER_BULLET_RUNTIME=goose)"
assert_eq "CLAUDE_PLUGIN_ROOT under /.codex/ selects codex" "codex" "$(detect CLAUDE_PLUGIN_ROOT=/u/.codex/p)"
assert_eq "CLAUDE_PLUGIN_ROOT elsewhere stays claude" "claude" "$(detect CLAUDE_PLUGIN_ROOT=/u/.claude/p)"

assert_contains "compat doc: Kay payload shapes fail closed" "$(cat "$COMPAT")" "no recognisable path at all is denied (fail closed)"
assert_contains "compat doc: Kay hook timeouts" "$(cat "$COMPAT")" "a timed-out PreToolUse hook denies the call (fail closed)"

tl_results
