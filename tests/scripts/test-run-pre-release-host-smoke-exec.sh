#!/usr/bin/env bash
# Execute scripts/run-pre-release-host-smoke.sh from a staged tree. Installers, diagnostics,
# validators, the invoke-skill adapter and the Cursor smokes are stubs; no host CLI runs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

T="$TL_TMP/tree"
k2_stage_smoke_tree "$T"
SMOKE="$T/scripts/run-pre-release-host-smoke.sh"
export STUB_LOG="$TL_TMP/stub.log"
tl_stub claude 'exit 0'   # present so the claude host is exercised unless a case hides it

smoke() { # [env...] -- args
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$STUB_LOG"
  rm -rf "$TL_TMP/keep"
  tl_run env "${envs[@]}" SMOKE_KEEP="$TL_TMP/keep" bash "$SMOKE" "$@"
  LOG="$(cat "$STUB_LOG")"
}

# ---- all hosts, everything passes ----
smoke X=1 --
assert_eq "all hosts pass exits 0" 0 "$TL_STATUS"
assert_contains "summary counts" "$TL_OUT" "Pre-release host smoke: 12 passed, 0 failed, 0 skipped (12 checks)"
for c in "structural: validate-host-agnostic-core.sh" "structural: validate-host-install-surface.sh" \
  "structural: validate-host-skill-surface.sh" "codex: invoke-skill routes sb:verify" "codex: install-codex.sh" \
  "codex: sb-diagnostics.sh" "cursor: release-live-matrix-cursor-smoke.sh" "cursor: pre-release-cursor-cli-smoke.sh" \
  "claude: invoke-skill routes sb:verify" "claude: install-claude.sh" "claude: sb-diagnostics.sh"; do
  assert_contains "reports PASS $c" "$TL_OUT" "PASS: $c"
done
assert_contains "adapter invoked for the codex bundle" "$LOG" "adapter invoke-skill sb:verify roots=$T/host-bundles/codex plugin=$T/plugins/silver-bullet"
assert_contains "adapter invoked for the claude bundle" "$LOG" "adapter invoke-skill sb:verify roots=$T/agents/claude"
assert_contains "adapter invoked for the cursor bundle" "$LOG" "adapter invoke-skill sb:verify roots=$T/host-bundles/cursor"
assert_contains "validators receive repo root" "$LOG" "validate-host-skill-surface args=--repo-root $T"
assert_contains "cursor fake home printed" "$TL_OUT" "isolated fake-home: "
assert_contains "cursor workspace printed" "$TL_OUT" "workspace: "
assert_contains "cursor smoke uses current env" "$LOG" "cursor-cli-smoke env="
assert_contains "marker announced" "$TL_OUT" "Wrote isolated marker "
assert_contains "marker copied to the final runtime state dir" "$TL_OUT" "Copied marker to "
MARK="$TL_TMP/keep/codex/.silver-bullet/pre-release-host-smoke"
assert_file_exists "isolated marker kept" "$MARK"
assert_contains "marker lists hosts" "$(cat "$MARK")" "hosts=codex,cursor,claude"
assert_contains "marker lists isolation" "$(cat "$MARK")" "cursor_isolation=fake-home,CURSOR_CONFIG_DIR,--plugin-dir,--workspace"
assert_file_exists "marker copied beside the claude runtime state" "$TL_TMP/keep/claude/.silver-bullet/pre-release-host-smoke"
# the operator's real homes are never touched
assert_file_absent "real HOME untouched" "$HOME/.codex"

# ---- single host runs: marker is already at the destination ----
smoke X=1 -- --host codex
assert_eq "codex only exits 0" 0 "$TL_STATUS"
assert_contains "codex only: summary" "$TL_OUT" "6 passed, 0 failed, 0 skipped"
assert_contains "codex only: marker already in place" "$TL_OUT" "already at "
assert_not_contains "codex only: no cursor smoke" "$TL_OUT" "Cursor host smoke"
smoke X=1 -- cursor
assert_eq "positional cursor exits 0" 0 "$TL_STATUS"
assert_contains "cursor only runs the cursor section" "$TL_OUT" "=== Cursor host smoke (isolated) ==="
assert_not_contains "cursor only: no codex section" "$TL_OUT" "Codex host smoke"
smoke X=1 -- claude
assert_eq "claude only exits 0" 0 "$TL_STATUS"
assert_contains "claude only section" "$TL_OUT" "=== Claude host smoke (isolated) ==="

# ---- unknown host ----
smoke X=1 -- bogus
assert_eq "unknown host exits 2" 2 "$TL_STATUS"
assert_contains "unknown host message" "$TL_ERR" "Unknown host: bogus (use all|codex|cursor|claude)"

# ---- claude CLI absent: skipped, still passes ----
smoke PATH="$(tl_path_without claude)" -- claude
assert_eq "claude skipped exits 0" 0 "$TL_STATUS"
assert_contains "claude skip line" "$TL_OUT" "SKIP: claude: CLI not available"
assert_contains "skip counted" "$TL_OUT" "4 passed, 0 failed, 1 skipped (5 checks)"
# CLAUDE_BIN override pointing at a non-executable file is also a skip
printf 'x' >"$TL_TMP/notexec"
smoke CLAUDE_BIN="$TL_TMP/notexec" -- claude
assert_contains "non-executable CLAUDE_BIN skipped" "$TL_OUT" "SKIP: claude: CLI not available"

# ---- failures ----
smoke STUB_FAIL_validate_host_agnostic_core=1 -- codex
assert_eq "structural failure exits 1" 1 "$TL_STATUS"
assert_contains "structural failure reported" "$TL_OUT" "FAIL: structural: validate-host-agnostic-core.sh"
assert_file_absent "no marker on failure" "$TL_TMP/keep/codex/.silver-bullet/pre-release-host-smoke"
smoke STUB_FAIL_validate_host_install_surface=1 -- codex
assert_contains "install-surface failure reported" "$TL_OUT" "FAIL: structural: validate-host-install-surface.sh"
smoke STUB_FAIL_validate_host_skill_surface=1 -- codex
assert_contains "skill-surface failure reported" "$TL_OUT" "FAIL: structural: validate-host-skill-surface.sh"
smoke STUB_FAIL_INSTALL=1 -- codex
assert_contains "codex install failure reported" "$TL_OUT" "FAIL: codex: install-codex.sh"
assert_not_contains "codex diagnostics skipped after install failure" "$TL_OUT" "codex: sb-diagnostics.sh"
smoke STUB_FAIL_DIAG=1 -- codex
assert_contains "codex diagnostics failure reported" "$TL_OUT" "FAIL: codex: sb-diagnostics.sh"
smoke STUB_FAIL_INSTALL=1 -- claude
assert_contains "claude install failure reported" "$TL_OUT" "FAIL: claude: install-claude.sh"
smoke STUB_FAIL_DIAG=1 -- claude
assert_contains "claude diagnostics failure reported" "$TL_OUT" "FAIL: claude: sb-diagnostics.sh"
smoke STUB_FAIL_CURSOR_MATRIX=1 -- cursor
assert_contains "cursor matrix smoke failure reported" "$TL_OUT" "FAIL: cursor: release-live-matrix-cursor-smoke.sh"
smoke STUB_FAIL_CURSOR_CLI=1 -- cursor
assert_contains "cursor cli smoke failure reported" "$TL_OUT" "FAIL: cursor: pre-release-cursor-cli-smoke.sh"
assert_eq "cursor cli failure exits 1" 1 "$TL_STATUS"

# adapter that does not route the skill: FAIL with a snippet
smoke STUB_ADAPTER_MODE=bad -- codex
assert_contains "unrouted skill reported" "$TL_OUT" "FAIL: codex: invoke-skill routes sb:verify"
assert_contains "snippet of adapter output shown" "$TL_OUT" "snippet: no skill here"
# adapter that exits non-zero is tolerated (output still judged)
smoke STUB_ADAPTER_MODE=fail -- codex
assert_contains "failing adapter reported as unrouted" "$TL_OUT" "FAIL: codex: invoke-skill routes sb:verify"
assert_contains "failing adapter output shown" "$TL_OUT" "snippet: adapter failed"
# missing bundle directory
rmdir "$T/host-bundles/codex"
smoke X=1 -- codex
assert_contains "missing bundle reported" "$TL_OUT" "FAIL: codex: missing agent bundle at $T/host-bundles/codex"
mkdir "$T/host-bundles/codex"

# ---- no runtime-paths helper in the tree: marker stays in the isolated root ----
rm "$T/hooks/lib/runtime-paths.sh"
smoke X=1 -- codex
assert_eq "no runtime-paths exits 0" 0 "$TL_STATUS"
assert_not_contains "no copy step without runtime-paths" "$TL_OUT" "Copied marker"
assert_file_exists "marker still written" "$TL_TMP/keep/codex/.silver-bullet/pre-release-host-smoke"

tl_results
