#!/usr/bin/env bash
# The shipped Codex adapter (scripts/lib/agent-adapters/codex.sh) must not bypass hook trust or the
# sandbox by default, and strict mode never does (R4-23, R8-15). The adapter runs its exec path
# against a recording stub codex; nothing real is launched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

ADAPTER="$TL_REPO_ROOT/scripts/lib/agent-adapters/codex.sh"
W="$TL_TMP/work"; mkdir -p "$W" "$TL_TMP/tmp" "$TL_TMP/cbin"
ARGV="$TL_TMP/argv.log"
cat >"$TL_TMP/cbin/codex" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then echo "codex 0.0.0"; exit 0; fi
printf '%s\n' "\$*" >"$ARGV"
echo "stub-codex-done"
EOF
chmod +x "$TL_TMP/cbin/codex"

# run_adapter MODE [ENV=VAL...]: exec path, adapter sourced in a clean shell
run_adapter() {
  local mode="$1"
  shift
  rm -f "$ARGV"
  local -a unset_args=()
  local name
  while IFS= read -r name; do
    unset_args+=(-u "$name")
  done < <(compgen -e | grep -E '^(SB_LIVE_|SB_AGENT_|SB_E2E_|CODEX_)' | grep -v '^SB_COV_' || true)
  tl_run timeout 90 env "${unset_args[@]}" TMPDIR="$TL_TMP/tmp" SB_ROOT="$TL_REPO_ROOT" WORK_DIR="$W" \
    CODEX_BIN="$TL_TMP/cbin/codex" SB_LIVE_CODEX_USE_EXEC=1 CODEX_EXEC_TAIL_IDLE_TIMEOUT=2 "$@" \
    bash -c 'source "$1"; agent_invoke "$2" "do it"' _ "$ADAPTER" "$mode"
}

run_adapter permissive
assert_contains "permissive reaches the stub" "$TL_OUT" "stub-codex-done"
assert_contains "permissive: full-access sandbox" "$(cat "$ARGV")" "--sandbox danger-full-access"
assert_contains "permissive: approvals bypass" "$(cat "$ARGV")" "--dangerously-bypass-approvals-and-sandbox"
assert_not_contains "permissive: hook trust is NOT bypassed by default" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

run_adapter permissive SB_AGENT_CODEX_DELEGATE=1
assert_not_contains "delegate flag alone does not bypass hook trust" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

run_adapter permissive SB_AGENT_CODEX_DELEGATE=1 CODEX_BYPASS_HOOK_TRUST=1
assert_contains "explicit opt-in bypasses hook trust in permissive mode" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

run_adapter permissive CODEX_AUTO_TRUST_HOOKS=1
assert_contains "auto-trust opt-in implies the bypass in permissive mode" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

run_adapter permissive SB_E2E_ENTERPRISE_MATRIX=1 CODEX_BYPASS_HOOK_TRUST=0
assert_not_contains "an explicit 0 wins over the isolated-run default" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

run_adapter strict CODEX_BYPASS_HOOK_TRUST=1 CODEX_AUTO_TRUST_HOOKS=1 SB_AGENT_CODEX_DELEGATE=1
assert_contains "strict: workspace-write sandbox" "$(cat "$ARGV")" "--sandbox workspace-write"
assert_not_contains "strict: no full-access sandbox" "$(cat "$ARGV")" "danger-full-access"
assert_not_contains "strict: no approvals bypass" "$(cat "$ARGV")" "--dangerously-bypass-approvals-and-sandbox"
assert_not_contains "strict: never bypasses hook trust, even when opted in" "$(cat "$ARGV")" "--dangerously-bypass-hook-trust"

tl_results
