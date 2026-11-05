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
cp -R "$TL_REPO_ROOT/hooks" "$PKG/hooks"
[[ ! -e "$PKG/tests" ]] && tl_pass "package has no tests/ directory" || tl_fail "package has no tests/ directory"

for h in claude codex opencode pi; do
  assert_file_exists "shipped $h adapter" "$PKG/scripts/lib/agent-adapters/$h.sh"
  # shims keep the live-test entry points working
  assert_file_exists "live-test shim for $h" "$TL_REPO_ROOT/tests/live/agents/$h/agent.sh"
  tl_run bash -c "source '$TL_REPO_ROOT/tests/live/agents/$h/agent.sh'; agent_name"
  assert_eq "$h shim sources the shipped adapter" "$h" "$TL_OUT"
done

# Each delegate must reach its adapter AND the stub CLI: assert exit status and the stub's own output
# (the stub echoes its argv to a log), not just the absence of one error.
for h in claude codex opencode pi; do
  tl_stub "$h" "echo \"stub-$h \$*\" >>'$TL_TMP/stub-$h.log'; echo stub-$h-out; exit 0"
  # Pi has no strict mode (default outside the project is strict): pass --mode permissive explicitly.
  tl_run timeout 90 env HOME="$HOME" TMPDIR="$TL_TMP/tmp" \
    CLAUDE_BIN="$TL_BIN/$h" CODEX_BIN="$TL_BIN/$h" OPENCODE_BIN="$TL_BIN/$h" PI_BIN="$TL_BIN/$h" \
    CLAUDE_USE_INTERACTIVE=0 SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=0 \
    bash "$PKG/scripts/agent-$h-delegate.sh" --work-dir "$TL_TMP/work" --prompt "say hi" --skip-preflight --no-escalate --mode permissive
  assert_not_contains "$h delegate finds its adapter in a tests-free package" "$TL_ERR" "live adapter at"
  assert_eq "$h delegate exits 0 from the package" "0" "$TL_STATUS"
  # (the OpenCode adapter streams its CLI output to the log only; the launch log below proves it ran)
  [[ "$h" == opencode ]] || assert_contains "$h delegate output is the stub CLI's" "$TL_OUT" "stub-$h-out"
  assert_file_exists "$h stub CLI was launched" "$TL_TMP/stub-$h.log"
done

tl_results
