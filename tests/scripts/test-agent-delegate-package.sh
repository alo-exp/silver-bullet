#!/usr/bin/env bash
# R10b-05: the /sb:agent-* delegates must run from a package that ships scripts/ but
# no tests/ (the Codex plugin cache). Copy scripts/ alone, run each delegate against
# a stub CLI, and assert it gets past the adapter lookup.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

PKG="$TL_TMP/pkg"
mkdir -p "$PKG" "$TL_TMP/work" "$TL_TMP/bin" "$TL_TMP/tmp"
cp -R "$TL_REPO_ROOT/scripts" "$PKG/scripts"
[[ ! -e "$PKG/tests" ]] && tl_pass "package has no tests/ directory" || tl_fail "package has no tests/ directory"

for h in claude codex opencode pi; do
  assert_file_exists "shipped $h adapter" "$PKG/scripts/lib/agent-adapters/$h.sh"
  # shims keep the live-test entry points working
  assert_file_exists "live-test shim for $h" "$TL_REPO_ROOT/tests/live/agents/$h/agent.sh"
  tl_run bash -c "source '$TL_REPO_ROOT/tests/live/agents/$h/agent.sh'; agent_name"
  assert_eq "$h shim sources the shipped adapter" "$h" "$TL_OUT"
done

for h in claude codex opencode pi; do
  tl_stub "$h" "echo stub-$h; exit 0"
  tl_run timeout 60 env HOME="$HOME" TMPDIR="$TL_TMP/tmp" \
    CLAUDE_BIN="$TL_BIN/$h" CODEX_BIN="$TL_BIN/$h" OPENCODE_BIN="$TL_BIN/$h" PI_BIN="$TL_BIN/$h" \
    bash "$PKG/scripts/agent-$h-delegate.sh" --work-dir "$TL_TMP/work" --prompt "say hi" --skip-preflight --no-escalate
  assert_not_contains "$h delegate finds its adapter in a tests-free package" "$TL_ERR" "live adapter at"
done

tl_results
