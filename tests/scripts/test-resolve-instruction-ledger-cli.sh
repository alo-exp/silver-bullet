#!/usr/bin/env bash
# scripts/resolve-instruction-ledger.sh: list/done/deferred against a scoped ledger in the sandbox state dir.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

CLI="$TL_REPO_ROOT/scripts/resolve-instruction-ledger.sh"
LEDGER="$SB_RUNTIME_STATE_DIR/instruction-ledger.json"
REPO="$TL_TMP/repo"
tl_git_repo "$REPO"
WT="$(cd "$REPO" && git rev-parse --show-toplevel)"

run() { tl_run bash -c 'cd "$1" && shift && timeout 20 bash "$@"' _ "$REPO" "$CLI" "$@"; }

write_ledger() { # scope-branch
  jq -n --arg b "$1" --arg w "$WT" '{
    scope:{branch:$b, worktree:$w},
    intents:[{id:"I1",label:"Ship the feature",status:"pending",children:[
      {id:"I1.1",label:"write alpha module",status:"pending"},
      {id:"I1.2",label:"write beta module",status:"pending"}]}]}' >"$LEDGER"
}

# --- help / unknown ---------------------------------------------------------------------------
for a in "" -h --help help; do
  if [[ -z "$a" ]]; then run; else run "$a"; fi
  assert_eq "usage for '${a:-<none>}' exits 0" 0 "$TL_STATUS"
  assert_contains "usage text for '${a:-<none>}'" "$TL_OUT" "resolve-instruction-ledger.sh done <item-id-or-label> --evidence"
done
run frobnicate
assert_eq "unknown command -> 2" 2 "$TL_STATUS"
assert_contains "unknown command message" "$TL_ERR" "ERROR: unknown command: frobnicate"
assert_contains "usage on stderr" "$TL_ERR" "Usage:"

# --- list ------------------------------------------------------------------------------------------------
rm -f "$LEDGER"
run list
assert_eq "list without ledger exits 0" 0 "$TL_STATUS"
assert_contains "list without ledger msg" "$TL_OUT" "No instruction ledger at $LEDGER"
write_ledger feature/test
run list
assert_eq "list ok" 0 "$TL_STATUS"
assert_contains "list header" "$TL_OUT" "Instruction ledger — unresolved items:"
assert_contains "list pending leaf alpha" "$TL_OUT" "- [I1.1] write alpha module"
assert_contains "list pending leaf beta" "$TL_OUT" "- [I1.2] write beta module"
write_ledger some/other-branch
run list
assert_eq "foreign list exits 0" 0 "$TL_STATUS"
assert_contains "foreign list message" "$TL_OUT" "Ledger scope mismatches current branch/worktree"
assert_file_absent "foreign ledger cleared by list" "$LEDGER"

# --- argument validation for done/deferred --------------------------------------------------------
write_ledger feature/test
run "done"
assert_eq "done without selector -> 2" 2 "$TL_STATUS"
assert_contains "selector required" "$TL_ERR" "item selector and --evidence are required"
run "done" I1.1
assert_eq "done without evidence -> 2" 2 "$TL_STATUS"
run "done" I1.1 --evidence
assert_eq "dangling --evidence ends with a usage error (does not loop)" 2 "$TL_STATUS"
run "done" I1.1 --evidence ""
assert_eq "empty evidence -> 2" 2 "$TL_STATUS"
run "done" I1.1 --bogus x
assert_eq "unknown flag -> 2" 2 "$TL_STATUS"
assert_contains "unknown flag msg" "$TL_ERR" "ERROR: unknown argument: --bogus"
run deferred "" --evidence why
assert_eq "empty selector -> 2" 2 "$TL_STATUS"
assert_eq "ledger untouched by invalid calls" '["pending","pending","pending"]' "$(jq -c '[.. | objects | select(has("status")) | .status]' "$LEDGER")"

# --- resolve --------------------------------------------------------------------------------------------------
run "done" I1.1 --evidence "tests green"
assert_eq "resolve by id" 0 "$TL_STATUS"
assert_contains "ok line" "$TL_OUT" "OK: marked I1.1 as done"
assert_contains "pending summary after partial resolve" "$TL_OUT" "- [I1.2] write beta module"
assert_eq "leaf status written" "done" "$(jq -r '.intents[0].children[0].status' "$LEDGER")"
assert_eq "leaf evidence written" "tests green" "$(jq -r '.intents[0].children[0].evidence' "$LEDGER")"
run deferred "beta" --evidence=postponed
assert_eq "resolve by unique label substring, --evidence= form" 0 "$TL_STATUS"
assert_contains "ok deferred" "$TL_OUT" "OK: marked beta as deferred"
assert_contains "fully resolved" "$TL_OUT" "Instruction ledger fully resolved."
assert_eq "deferred leaf status" deferred "$(jq -r '.intents[0].children[1].status' "$LEDGER")"
assert_eq "deferred evidence" postponed "$(jq -r '.intents[0].children[1].evidence' "$LEDGER")"
assert_eq "parent auto-resolved" "done" "$(jq -r '.intents[0].status' "$LEDGER")"

# --- failures -----------------------------------------------------------------------------------------------------------
write_ledger feature/test
run "done" module --evidence x
assert_eq "ambiguous selector -> 1" 1 "$TL_STATUS"
assert_contains "ambiguous message" "$TL_ERR" "could not resolve item module as done"
run "done" nomatch --evidence x
assert_eq "no match -> 1" 1 "$TL_STATUS"
write_ledger some/other-branch
run "done" I1.1 --evidence x
assert_eq "foreign ledger -> 1" 1 "$TL_STATUS"
assert_file_absent "foreign ledger dropped on resolve" "$LEDGER"
run "done" I1.1 --evidence x
assert_eq "missing ledger -> 1" 1 "$TL_STATUS"

tl_results
