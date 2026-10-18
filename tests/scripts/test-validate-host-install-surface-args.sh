#!/usr/bin/env bash
# validate-host-install-surface.sh argument handling, prerequisite checks and
# exit-code composition with stubbed sibling validators (the validators
# themselves and the structural checks are covered by
# test-validate-host-install-surface.sh).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

T="$TL_TMP/tree"
LOG="$TL_TMP/calls.log"
mkdir -p "$T/scripts/lib"
cp "$TL_REPO_ROOT/scripts/validate-host-install-surface.sh" "$T/scripts/"
cp "$TL_REPO_ROOT/scripts/lib/agent-bundle-paths.sh" "$T/scripts/lib/"
SCRIPT="$T/scripts/validate-host-install-surface.sh"

stub_validators() {
  local skill_rc="${1:-0}" budget_rc="${2:-0}"
  cat >"$T/scripts/validate-host-skill-surface.sh" <<S
#!/usr/bin/env bash
echo "skill-surface \$*" >>"$LOG"
exit $skill_rc
S
  cat >"$T/scripts/validate-claude-agent-token-budget.sh" <<S
#!/usr/bin/env bash
echo "token-budget \$*" >>"$LOG"
exit $budget_rc
S
  chmod +x "$T"/scripts/*.sh
  : >"$LOG"
}
# A read-only repo fixture the structural checks accept (the real checkout is only read).
REPO="$TL_REPO_ROOT"
run_validate() { tl_run timeout 60 bash "$SCRIPT" "$@"; }

# --- help and unknown arguments ----------------------------------------------------
stub_validators
run_validate --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints the usage header" "$TL_OUT" "Cross-host installation surface audit"
assert_contains "--help prints the usage lines" "$TL_OUT" "scripts/validate-host-install-surface.sh --cache-root PATH --host claude|codex|cursor"
run_validate -h
assert_eq "-h exits 0" 0 "$TL_STATUS"
run_validate --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "unknown argument: --bogus"

# A value flag given last has no value: clear usage error, nothing validated.
for flag in --repo-root --cache-root --host --max-claude-tokens; do
  stub_validators
  run_validate "$flag"
  assert_eq "$flag without a value exits 2" 2 "$TL_STATUS"
  assert_contains "$flag without a value is explained" "$TL_ERR" "validate-host-install-surface: $flag requires a value"
  assert_eq "$flag without a value validates nothing" "" "$(<"$LOG")"
done

# --- prerequisites -----------------------------------------------------------------------
for tool in python3 jq; do
  dir="$TL_TMP/path-no-$tool"
  mkdir -p "$dir"
  ln -sf "$(command -v dirname)" "$dir/dirname"
  if [[ "$tool" == python3 ]]; then ln -sf "$(command -v jq)" "$dir/jq"; else ln -sf "$(command -v python3)" "$dir/python3"; fi
  tl_run env PATH="$dir" "$(command -v timeout)" 60 "$(command -v bash)" "$SCRIPT" --repo-root "$REPO"
  assert_eq "missing $tool exits 1" 1 "$TL_STATUS"
  assert_contains "missing $tool named" "$TL_ERR" "validate-host-install-surface: $tool required"
done

# --- composition of the sibling validators -------------------------------------------------------
stub_validators 0 0
run_validate --repo-root "$REPO" --host claude --max-claude-tokens 1234
assert_eq "all validators green exits 0" 0 "$TL_STATUS"
assert_contains "OK verdict" "$TL_OUT" "validate-host-install-surface: OK — no cross-host installation bleed detected"
assert_contains "skill surface validator gets the repo root" "$(<"$LOG")" "skill-surface --repo-root $REPO"
assert_contains "token budget validator gets root and limit" "$(<"$LOG")" "token-budget --repo-root $REPO --max-tokens 1234"

stub_validators 0 0
run_validate --repo-root "$REPO" --host codex
assert_eq "codex-only run exits 0" 0 "$TL_STATUS"
assert_contains "skill surface validated for codex" "$(<"$LOG")" "skill-surface"
assert_not_contains "token budget is Claude-only" "$(<"$LOG")" "token-budget"

stub_validators 0 0
run_validate --repo-root "$REPO"
assert_contains "default token budget limit" "$(<"$LOG")" "--max-tokens 14000"

stub_validators 1 0
run_validate --repo-root "$REPO" --host claude
assert_eq "failing skill surface validator fails the audit" 1 "$TL_STATUS"
assert_not_contains "no OK verdict after a failure" "$TL_OUT" "OK — no cross-host"
assert_contains "token budget still checked" "$(<"$LOG")" "token-budget"

stub_validators 0 1
run_validate --repo-root "$REPO" --host claude
assert_eq "failing token budget validator fails the audit" 1 "$TL_STATUS"
assert_not_contains "no OK verdict after a budget failure" "$TL_OUT" "OK — no cross-host"

# Sibling validators that are missing or not executable are skipped.
rm -f "$T/scripts/validate-host-skill-surface.sh" "$T/scripts/validate-claude-agent-token-budget.sh"
run_validate --repo-root "$REPO" --host claude
assert_eq "missing sibling validators are skipped" 0 "$TL_STATUS"

# --- host / cache-root validation ----------------------------------------------------------------------
stub_validators
run_validate --repo-root "$REPO" --host nonsense
assert_eq "invalid host exits 2" 2 "$TL_STATUS"
assert_contains "invalid host named" "$TL_ERR" "invalid --host nonsense"
assert_eq "invalid host validates nothing" "" "$(<"$LOG")"

run_validate --cache-root "$TL_TMP/cache"
assert_eq "--cache-root without --host exits 2" 2 "$TL_STATUS"
assert_contains "--cache-root needs a host" "$TL_ERR" "--cache-root requires --host claude|codex|cursor"
assert_eq "cache mode never runs the repo validators" "" "$(<"$LOG")"

mkdir -p "$TL_TMP/cache/agents/claude/sb"
run_validate --cache-root "$TL_TMP/cache" --host claude
assert_eq "clean claude cache passes" 0 "$TL_STATUS"
assert_contains "cache verdict" "$TL_OUT" "cache OK for host=claude"
mkdir -p "$TL_TMP/cache/agents/codex"
run_validate --cache-root "$TL_TMP/cache" --host claude
assert_eq "foreign host bundle in the claude cache fails" 1 "$TL_STATUS"
assert_contains "cache violation reported" "$TL_ERR" "cache violations (claude)"

tl_results
