#!/usr/bin/env bash
# Tests for hooks/lib/user-consent.sh (per-user consent store) and scripts/sb-consent.sh.
set -euo pipefail

# shellcheck source=../lib/testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib/user-consent.sh"
CLI="$TL_REPO_ROOT/scripts/sb-consent.sh"
# shellcheck source=../../hooks/lib/user-consent.sh
source "$LIB"

STORE="$HOME/.config/silver-bullet/consent.json"
PROJ="$TL_TMP/proj"
mkdir -p "$PROJ"
PROJ_KEY="$(cd -P "$PROJ" && pwd -P)"

reset_store() { rm -rf "$HOME/.config/silver-bullet"; }

echo "=== store location ==="
assert_eq "default store path" "$STORE" "$(sb_consent_store_path)"
assert_eq "absolute XDG_CONFIG_HOME honoured" "/x/cfg/silver-bullet/consent.json" "$(XDG_CONFIG_HOME=/x/cfg sb_consent_store_path)"
assert_eq "relative XDG_CONFIG_HOME ignored" "$STORE" "$(XDG_CONFIG_HOME=rel/cfg sb_consent_store_path)"

echo "=== validation helpers ==="
if sb_consent_tool_valid graphify; then tl_pass "graphify is a tool"; else tl_fail "graphify is a tool"; fi
if sb_consent_tool_valid evil; then tl_fail "unknown tool rejected"; else tl_pass "unknown tool rejected"; fi
if sb_consent_tool_valid ""; then tl_fail "empty tool rejected"; else tl_pass "empty tool rejected"; fi
if sb_consent_capability_valid wire; then tl_pass "wire is a capability"; else tl_fail "wire is a capability"; fi
if sb_consent_capability_valid root; then tl_fail "unknown capability rejected"; else tl_pass "unknown capability rejected"; fi

echo "=== project keys ==="
assert_eq "project key is the physical path" "$PROJ_KEY" "$(sb_consent_project_key "$PROJ")"
if sb_consent_project_key "$TL_TMP/missing" >/dev/null; then tl_fail "missing dir has no key"; else tl_pass "missing dir has no key"; fi
if sb_consent_project_key "" >/dev/null; then tl_fail "empty dir has no key"; else tl_pass "empty dir has no key"; fi
NL_DIR="$TL_TMP/new"$'\n'"line"
mkdir -p "$NL_DIR"
if sb_consent_project_key "$NL_DIR" >/dev/null; then tl_fail "newline path has no key"; else tl_pass "newline path has no key"; fi
MAIN="$TL_TMP/main"
mkdir -p "$MAIN/.git/worktrees/wt1" "$TL_TMP/wt1"
printf 'gitdir: %s/.git/worktrees/wt1\n' "$MAIN" >"$TL_TMP/wt1/.git"
assert_eq "worktree maps to its main checkout" "$(cd -P "$MAIN" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt1")"
mkdir -p "$TL_TMP/wt2"
printf 'gitdir: ../main/.git/worktrees/wt2' >"$TL_TMP/wt2/.git"
mkdir -p "$MAIN/.git/worktrees/wt2"
assert_eq "relative gitdir without newline maps too" "$(cd -P "$MAIN" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt2")"
mkdir -p "$TL_TMP/wt3"
printf 'gitdir: %s/gone/.git/worktrees/wt3\n' "$TL_TMP" >"$TL_TMP/wt3/.git"
assert_eq "worktree of a missing main checkout keeps its own key" "$(cd -P "$TL_TMP/wt3" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt3")"
mkdir -p "$TL_TMP/sub"
printf 'gitdir: %s/main/.git/modules/sub\n' "$TL_TMP" >"$TL_TMP/sub/.git"
assert_eq "submodule gitdir keeps its own key" "$(cd -P "$TL_TMP/sub" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/sub")"

echo "=== decisions ==="
reset_store
assert_eq "no store: unset" "unset" "$(sb_consent_decision graphify enforce "$PROJ")"
if sb_consent_store_mentions graphify; then tl_fail "no store mentions nothing"; else tl_pass "no store mentions nothing"; fi
assert_eq "unknown tool: unset" "unset" "$(sb_consent_decision evil enforce)"
assert_eq "unknown capability: unset" "unset" "$(sb_consent_decision graphify root)"

sb_consent_set granted graphify enforce machine test
assert_eq "machine grant" "granted" "$(sb_consent_decision graphify enforce)"
assert_eq "machine grant applies to a project" "granted" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "other capability stays unset" "unset" "$(sb_consent_decision graphify install)"
if sb_consent_store_mentions graphify; then tl_pass "store mentions graphify"; else tl_fail "store mentions graphify"; fi
if sb_consent_store_mentions rtk; then tl_fail "store does not mention rtk"; else tl_pass "store does not mention rtk"; fi
assert_eq "store mode 0600" "600" "$(stat -c %a "$STORE" 2>/dev/null || stat -f %Lp "$STORE")"
if sb_consent_granted graphify enforce; then tl_pass "sb_consent_granted"; else tl_fail "sb_consent_granted"; fi

sb_consent_set declined graphify enforce "$PROJ" test
assert_eq "project record wins over machine" "declined" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "machine record unchanged" "granted" "$(sb_consent_decision graphify enforce)"
if sb_consent_granted graphify enforce "$PROJ"; then tl_fail "declined is not granted"; else tl_pass "declined is not granted"; fi
assert_eq "project key recorded" "declined" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision' "$STORE")"
assert_eq "provenance recorded" "test" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.source' "$STORE")"
assert_match "timestamp recorded" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.at' "$STORE")"
assert_file_exists "previous version backed up" "${STORE}.bak"

echo "=== idempotence, log, unknown keys ==="
before="$(cat "$STORE")"
sb_consent_set declined graphify enforce "$PROJ" again
assert_eq "same decision changes nothing" "$before" "$(cat "$STORE")"
jq '.user_note = "keep me"' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted rtk install,wire machine test
assert_eq "unknown keys preserved" "keep me" "$(jq -r '.user_note' "$STORE")"
assert_eq "log records each change" "3" "$(jq '.log | length' "$STORE")"
assert_eq "log entry fields" "grant rtk machine install,wire" "$(jq -r '.log[-1] | "\(.action) \(.tool) \(.scope) \(.capabilities | join(","))"' "$STORE")"
chmod 640 "$STORE"
sb_consent_set declined rtk wire machine test
assert_eq "file mode kept across writes" "640" "$(stat -c %a "$STORE" 2>/dev/null || stat -f %Lp "$STORE")"
jq '.log = [range(0; 205) | {n: .}]' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted alumnium enforce machine test
assert_eq "log keeps the newest 200" "200" "$(jq '.log | length' "$STORE")"
jq '.log = "broken"' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted leanctx enforce machine test
assert_eq "non-array log restarts" "1" "$(jq '.log | length' "$STORE")"

echo "=== revoke and prune ==="
sb_consent_set unset graphify enforce "$PROJ" test
assert_eq "revoked project record falls back to machine" "granted" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "empty project entry pruned" "null" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k]' "$STORE")"
sb_consent_set unset rtk install,wire machine test
assert_eq "empty machine tool pruned" "null" "$(jq -r '.machine.rtk' "$STORE")"
sb_consent_set unset graphify install machine test
assert_eq "revoking a missing record is a no-op" "granted" "$(sb_consent_decision graphify enforce)"

echo "=== provenance labels ==="
sb_consent_set granted context_mode enforce machine $'evil\nline;$(id)`x`'
assert_eq "label stripped to printable safe characters" "evilline(id)x" "$(jq -r '.machine.context_mode.enforce.source' "$STORE")"
sb_consent_set granted agentmemory enforce machine $'\n\n'
assert_eq "empty label becomes cli" "cli" "$(jq -r '.machine.agentmemory.enforce.source' "$STORE")"

echo "=== errors ==="
tl_run sb_consent_set maybe graphify enforce machine
assert_eq "bad decision status" "2" "$TL_STATUS"
assert_contains "bad decision message" "$TL_ERR" "decision must be"
tl_run sb_consent_set granted evil enforce machine
assert_contains "bad tool message" "$TL_ERR" "unknown tool: evil"
tl_run sb_consent_set granted graphify "" machine
assert_contains "no capability message" "$TL_ERR" "no capability given"
tl_run sb_consent_set granted graphify enforce,root machine
assert_contains "bad capability message" "$TL_ERR" "unknown capability: root"
tl_run sb_consent_set granted graphify install "$PROJ"
assert_contains "install is machine-wide" "$TL_ERR" "install is machine-wide"
tl_run sb_consent_set granted graphify enforce "$TL_TMP/missing"
assert_contains "missing project dir" "$TL_ERR" "not a directory"
printf 'not json' >"$TL_TMP/bad.json"
cp "$STORE" "$TL_TMP/good.json"
cp "$TL_TMP/bad.json" "$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_eq "invalid store refused" "2" "$TL_STATUS"
assert_eq "invalid store left untouched" "not json" "$(cat "$STORE")"
assert_eq "invalid store reads as unset" "unset" "$(sb_consent_decision graphify enforce)"
printf '{"machine": []}' >"$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_contains "malformed machine section refused" "$TL_ERR" "not a valid consent store"
printf '[]' >"$STORE"
assert_eq "non-object store reads as unset" "unset" "$(sb_consent_decision graphify enforce)"
printf '{"machine":{"graphify":"text"}}' >"$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_contains "jq update failure reported" "$TL_ERR" "could not update"
rm -f "$STORE"
ln -s "$TL_TMP/good.json" "$STORE"
assert_eq "symlinked store is read" "granted" "$(sb_consent_decision graphify enforce)"
tl_run sb_consent_set granted rtk enforce machine
assert_contains "symlinked store is never written through" "$TL_ERR" "symlink"
rm -f "$STORE"
# The store directory cannot be created (a regular file stands where it must go) ...
printf 'x' >"$TL_TMP/notadir"
tl_run env XDG_CONFIG_HOME="$TL_TMP/notadir" bash -c "source '$LIB'; sb_consent_set granted rtk enforce machine"
assert_contains "uncreatable store dir reported" "$TL_ERR" "cannot create"
# ... or a temp file cannot be made in it (no permission tricks: the tests may run as root)
tl_stub mktemp 'exit 1'; hash -r
tl_run sb_consent_set granted rtk enforce machine
assert_contains "unwritable store dir reported" "$TL_ERR" "cannot write"
rm -f "$TL_BIN/mktemp"; hash -r
tl_stub mv 'exit 1'; hash -r
tl_run sb_consent_set granted rtk enforce machine
assert_contains "failed rename reported" "$TL_ERR" "could not replace"
rm -f "$TL_BIN/mv"; hash -r
assert_eq "failed rename leaves no temp file" "" "$(find "$HOME/.config/silver-bullet" -name '.consent.json.*' 2>/dev/null)"

echo "=== status lines ==="
reset_store
sb_consent_set granted leanctx enforce "$PROJ" test
lines="$(sb_consent_status_lines "$PROJ")"
assert_contains "status lists project grant" "$lines" "leanctx enforce granted"
assert_contains "status lists unset pairs" "$lines" "graphify install unset"
assert_eq "status covers every tool and capability" "21" "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"

echo "=== CLI ==="
reset_store
tl_run bash "$CLI" path
assert_eq "cli path" "$STORE" "$TL_OUT"
tl_run bash "$CLI" grant graphify --project "$PROJ" --source "sb:init (user said yes)"
assert_eq "cli grant status" "0" "$TL_STATUS"
assert_contains "cli grant summary" "$TL_OUT" "grant graphify: install=granted, wire=granted, enforce=granted"
assert_eq "grant --project: enforce for the project" "granted" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision' "$STORE")"
assert_eq "grant --project: install for the machine" "granted" "$(jq -r '.machine.graphify.install.decision' "$STORE")"
assert_eq "grant --project: enforce not machine-wide" "null" "$(jq -r '.machine.graphify.enforce' "$STORE")"
assert_eq "cli source label" "sb:init (user said yes)" "$(jq -r '.machine.graphify.install.source' "$STORE")"
tl_run bash "$CLI" check graphify enforce --project "$PROJ"
assert_eq "cli check granted exit 0" "0" "$TL_STATUS"
assert_eq "cli check prints decision" "granted" "$TL_OUT"
tl_run bash "$CLI" check graphify enforce
assert_eq "cli check unset exit 1" "1" "$TL_STATUS"
tl_run bash "$CLI" decline rtk --project "$PROJ"
assert_contains "decline --project notes untouched capabilities" "$TL_ERR" "records enforce only"
assert_eq "decline --project records enforce" "declined" "$(bash "$CLI" check rtk enforce --project "$PROJ" || true)"
assert_eq "decline --project leaves install unset" "unset" "$(bash "$CLI" check rtk install || true)"
tl_run bash "$CLI" decline leanctx --all-projects --capabilities enforce
assert_eq "decline --all-projects" "declined" "$(bash "$CLI" check leanctx enforce || true)"
tl_run bash "$CLI" grant all --all-projects --capabilities enforce
assert_eq "grant all status" "0" "$TL_STATUS"
assert_eq "grant all covers search_cli" "granted" "$(bash "$CLI" check search_cli enforce || true)"
tl_run bash "$CLI" revoke graphify --project "$PROJ"
assert_eq "revoke --project clears the project grant" "unset" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision // "unset"' "$STORE")"
assert_eq "revoke --project clears install" "unset" "$(bash "$CLI" check graphify install || true)"
tl_run bash "$CLI" status --project "$PROJ"
assert_contains "status header" "$TL_OUT" "Consent store: $STORE"
assert_contains "status project" "$TL_OUT" "Project: $PROJ_KEY"
assert_contains "status line" "$TL_OUT" "rtk enforce declined"
tl_run bash "$CLI" status
assert_not_contains "status without project omits project line" "$TL_OUT" "Project:"
tl_run bash "$CLI" --help
assert_contains "help" "$TL_OUT" "Usage: sb-consent.sh"
tl_run bash "$CLI"
assert_eq "no command is a usage error" "64" "$TL_STATUS"
for bad in "frobnicate" "path extra" "status extra" "check graphify" "check evil enforce" "check graphify root" \
  "grant" "grant evil --all-projects" "grant graphify" "grant graphify --all-projects --project $PROJ" \
  "grant graphify --all-projects --capabilities root" "grant graphify --bogus" "grant graphify --project" \
  "grant graphify --capabilities" "grant graphify --source"; do
  # shellcheck disable=SC2086 # word splitting builds the argument list on purpose
  tl_run bash "$CLI" $bad
  assert_eq "usage error: $bad" "64" "$TL_STATUS"
done
tl_run bash "$CLI" grant graphify --project "$TL_TMP/missing"
assert_eq "missing project dir" "2" "$TL_STATUS"
printf 'not json' >"$STORE"
tl_run bash "$CLI" grant rtk --all-projects
assert_eq "store write failure exits 2" "2" "$TL_STATUS"
tl_run bash "$CLI" grant rtk --project "$PROJ" --capabilities enforce
assert_eq "project write failure exits 2" "2" "$TL_STATUS"
rm -f "$STORE"
tl_run env PATH="$(tl_path_without jq)" bash "$CLI" path
assert_eq "jq required" "2" "$TL_STATUS"

tl_results
