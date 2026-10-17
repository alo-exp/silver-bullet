#!/usr/bin/env bash
# Tests for hooks/lib/agent-delegation-state.sh and hooks/agent-delegation-progress-surface.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_GUARD
# shellcheck source=../../hooks/lib/agent-delegation-state.sh
source "$TL_REPO_ROOT/hooks/lib/agent-delegation-state.sh"

ROOT="$TL_TMP/root"
mkdir -p "$ROOT/src" "$ROOT/hooks"
STATE="$(sb_agent_delegation_state_file)"

echo "=== normalize_path ==="
sb_agent_delegation_normalize_path "" "$ROOT" && rc=0 || rc=$?
assert_eq "empty path rejected" 1 "$rc"
assert_eq "relative path resolved against repo root" "$ROOT/src/a.txt" "$(sb_agent_delegation_normalize_path src/a.txt "$ROOT")"
assert_eq "absolute path kept" "$ROOT/src/a.txt" "$(sb_agent_delegation_normalize_path "$ROOT/src/a.txt" "$ROOT")"
# "." and ".." collapse lexically (realpath -m semantics) so the final location is what gets checked.
assert_eq "dot-dot collapsed" "$ROOT/src/a.txt" "$(sb_agent_delegation_normalize_path "$ROOT/src/../src/a.txt" "$ROOT")"
assert_eq "dot-dot through a missing dir collapsed" "$ROOT/src/x.txt" "$(sb_agent_delegation_normalize_path "$ROOT/newdir/../src/x.txt" "$ROOT")"
assert_eq "dot segments dropped" "$ROOT/src/a.txt" "$(sb_agent_delegation_normalize_path "$ROOT/./src/./a.txt" "$ROOT")"
assert_eq "dot-dot never climbs above /" "/x" "$(sb_agent_delegation_normalize_path "/../../x" "$ROOT")"
# Regression: a nonexistent parent must never be fabricated into "/<basename>". The nearest
# existing ancestor is resolved and the missing components are re-appended, so the scope check
# still works for a new file in a new subdirectory (writing src/newdir/a.txt into an owned src/).
assert_eq "missing parents re-appended to the resolved ancestor" "$ROOT/nodir/deep/file.txt" "$(sb_agent_delegation_normalize_path "$ROOT/nodir/deep/file.txt" "$ROOT")"
assert_eq "relative path under a missing dir resolved against the root" "$ROOT/missing/file.txt" "$(sb_agent_delegation_normalize_path "missing/file.txt" "$ROOT")"
assert_eq "filesystem root normalises to itself" "/" "$(sb_agent_delegation_normalize_path / "$ROOT")"
# An ancestor that cannot be entered (race with removal/permissions) fails closed.
sb_agent_delegation_normalize_path "$ROOT/src/a.txt" "$ROOT" >/dev/null && rc=0 || rc=$?
cd() { return 1; }
sb_agent_delegation_normalize_path "$ROOT/src/a.txt" "$ROOT" >/dev/null && rc=0 || rc=$?
unset -f cd
assert_eq "unenterable ancestor returns failure" 1 "$rc"
assert_eq "trailing .. resolves to the parent" "$ROOT" "$(sb_agent_delegation_normalize_path "$ROOT/src/.." "$ROOT")"

echo "=== active flag and fields ==="
assert_eq "default state file under runtime state dir" "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json" "$STATE"
sb_agent_delegation_is_active && rc=0 || rc=$?
assert_eq "inactive without state file" 1 "$rc"
assert_eq "read_field default without file" "dflt" "$(sb_agent_delegation_read_field host dflt)"
sb_agent_delegation_activate codex T9 "$ROOT" "[\"$ROOT/src\"]" "$ROOT/log"
assert_eq "activate writes active=true" true "$(jq -r .active "$STATE")"
assert_eq "activate writes host" codex "$(sb_agent_delegation_read_field host x)"
assert_eq "read_field falls back for an absent key" "dflt" "$(sb_agent_delegation_read_field nokey dflt)"
sb_agent_delegation_is_active && rc=0 || rc=$?
assert_eq "active after activate" 0 "$rc"
SB_AGENT_DELEGATE_GUARD=0 sb_agent_delegation_is_active && rc=0 || rc=$?
assert_eq "SB_AGENT_DELEGATE_GUARD=0 disables" 1 "$rc"
printf '{"active":false}\n' >"$STATE"
sb_agent_delegation_is_active && rc=0 || rc=$?
assert_eq "active=false is inactive" 1 "$rc"
printf 'not json' >"$STATE"
assert_eq "read_field falls back when state is not JSON" "dflt" "$(sb_agent_delegation_read_field host dflt)"
sb_agent_delegation_is_active && rc=0 || rc=$?
assert_eq "corrupt state is inactive" 1 "$rc"

echo "=== v2 flag ==="
sb_agent_delegation_v2_enabled && rc=0 || rc=$?
assert_eq "v2 default on" 0 "$rc"
SB_AGENT_DELEGATE_V2=0 sb_agent_delegation_v2_enabled && rc=0 || rc=$?
assert_eq "v2 rollback off" 1 "$rc"

echo "=== without jq ==="
NOJQ="$(tl_path_without jq)"
(
  PATH="$NOJQ"
  sb_agent_delegation_activate claude T7 "$ROOT" '["x"]' "$ROOT/log"
)
assert_contains "no-jq activate writes host" "$(cat "$STATE")" '"host":"claude"'
assert_contains "no-jq activate writes work_dir" "$(cat "$STATE")" "\"work_dir\":\"$ROOT\""
(
  PATH="$NOJQ"
  sb_agent_delegation_is_active
) && rc=0 || rc=$?
assert_eq "grep fallback detects active" 0 "$rc"
assert_eq "no-jq read_field returns the default" "dflt" "$(PATH="$NOJQ" sb_agent_delegation_read_field host dflt)"
printf '{"active": false}\n' >"$STATE"
( PATH="$NOJQ"; sb_agent_delegation_is_active ) && rc=0 || rc=$?
assert_eq "grep fallback detects inactive" 1 "$rc"
sb_agent_delegation_activate claude T7 "$ROOT" '[]' ""
# jq-less scope check uses work_dir; the jq-less read_field default is the repo root.
(
  PATH="$NOJQ"
  printf '{"active":true,"work_dir":"%s"}\n' "$ROOT/src" >"$STATE"
  sb_agent_delegation_path_in_scope "$ROOT/src/a.txt" "$ROOT"
) && rc=0 || rc=$?
assert_eq "no-jq: path under the repo root in scope" 0 "$rc"
(
  PATH="$NOJQ"
  sb_agent_delegation_path_in_scope "$ROOT/other.txt" "$ROOT"
) && rc=0 || rc=$?
assert_eq "no-jq: read_field cannot parse work_dir, so the repo root is the scope" 0 "$rc"
(
  PATH="$NOJQ"
  sb_agent_delegation_path_in_scope "$TL_TMP/elsewhere.txt" "$ROOT"
) && rc=0 || rc=$?
assert_eq "no-jq: path outside the repo root not in scope" 1 "$rc"

echo "=== path_in_scope ==="
sb_agent_delegation_deactivate
sb_agent_delegation_path_in_scope "$ROOT/src/a.txt" "$ROOT" && rc=0 || rc=$?
assert_eq "inactive: nothing in scope" 1 "$rc"
jq -n --arg r "$ROOT" '{active:true,host:"codex",task_id:"T1",work_dir:$r,
  ownership_scope:[($r+"/src"),"",($r+"/nodir/x"),"rel"]}' >"$STATE"
mkdir -p "$ROOT/rel" "$ROOT/.planning/agent-codex/T1"
sb_agent_delegation_path_in_scope "$ROOT/src/a.txt" "$ROOT" && rc=0 || rc=$?
assert_eq "file under owned dir in scope" 0 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/src" "$ROOT" && rc=0 || rc=$?
assert_eq "owned dir itself in scope" 0 "$rc"
sb_agent_delegation_path_in_scope "rel/f" "$ROOT" && rc=0 || rc=$?
assert_eq "relative scope entry resolved against the repo root" 0 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/srcx/a.txt" "$ROOT" && rc=0 || rc=$?
assert_eq "sibling with common prefix not in scope" 1 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/nodir/x/f" "$ROOT" && rc=0 || rc=$?
assert_eq "scope entry that does not exist yet still owns its subtree" 0 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/missing/deep/f" "$ROOT" && rc=0 || rc=$?
assert_eq "target with missing parent not in scope" 1 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/hooks/x.sh" "$ROOT" && rc=0 || rc=$?
assert_eq "hooks/ repair path exempt" 1 "$rc"
jq --arg r "$ROOT" '.ownership_scope=[$r]' "$STATE" >"$STATE.n" && mv "$STATE.n" "$STATE"
sb_agent_delegation_path_in_scope "$ROOT/.planning/agent-codex/T1/n.md" "$ROOT" && rc=0 || rc=$?
assert_eq "own evidence dir exempt even under an owned root" 1 "$rc"
sb_agent_delegation_path_in_scope "$ROOT/src/a" "$ROOT" && rc=0 || rc=$?
assert_eq "owned root covers children" 0 "$rc"

# A target that cannot be normalized while a delegation is active is treated as in scope (fail closed).
cd() { return 1; }
sb_agent_delegation_path_in_scope "$ROOT/src/a.txt" "$ROOT" && rc=0 || rc=$?
unset -f cd
assert_eq "unnormalizable target is in scope (fail closed)" 0 "$rc"

# A scope entry that cannot be normalized is skipped; the remaining entries still apply.
cd() { [[ "${1:-}" == "$ROOT/src" ]] && return 1; builtin cd "$@"; }
sb_agent_delegation_path_in_scope "$ROOT/rel/f" "$ROOT" && rc=0 || rc=$?
assert_eq "other scope entries still apply when one cannot be normalized" 0 "$rc"
mkdir -p "$ROOT/elsewhere"
jq --arg r "$ROOT" '.ownership_scope=[($r+"/src")]' "$STATE" >"$STATE.n" && mv "$STATE.n" "$STATE"
sb_agent_delegation_path_in_scope "$ROOT/elsewhere/f" "$ROOT" && rc=0 || rc=$?
unset -f cd
assert_eq "the only scope entry unnormalizable: unrelated target not in scope" 1 "$rc"

echo "=== deactivate ==="
sb_agent_delegation_deactivate
assert_file_absent "deactivate removes state" "$STATE"
sb_agent_delegation_deactivate
assert_file_absent "deactivate idempotent" "$STATE"
mkdir -p "$STATE"
sb_agent_delegation_deactivate && rc=0 || rc=$?
assert_eq "deactivate swallows rm failure" 0 "$rc"
rm -rf "$STATE"

echo "=== host tier ==="
assert_eq "claude parent blocks" block "$(SILVER_BULLET_RUNTIME=claude sb_agent_delegation_parent_host_tier)"
assert_eq "codex parent blocks" block "$(SILVER_BULLET_RUNTIME=codex sb_agent_delegation_parent_host_tier)"
assert_eq "cursor parent advises" advise "$(SILVER_BULLET_RUNTIME=cursor sb_agent_delegation_parent_host_tier)"
assert_eq "default blocks" block "$(unset SILVER_BULLET_RUNTIME; sb_agent_delegation_parent_host_tier)"

echo "=== progress surface ==="
SURF="$TL_REPO_ROOT/hooks/agent-delegation-progress-surface.sh"
LOG="$ROOT/d.log"
run_surface() { bash -c 'source "$1"; sb_agent_delegation_progress_surface' _ "$SURF"; }
assert_eq "inactive delegation: empty surface" "" "$(run_surface)"
sb_agent_delegation_activate codex T1 "$ROOT" '[]' "$LOG"
assert_eq "no log file: header only" "[SB delegation active] host=codex task_id=T1" "$(run_surface)"
printf 'a\nb\n' >"$LOG"
assert_eq "log lines appended after header" "[SB delegation active] host=codex task_id=T1
a
b" "$(run_surface)"
tl_stub tail 'exit 1'
assert_eq "tail failure leaves just the header" "[SB delegation active] host=codex task_id=T1" "$(run_surface)"
rm -f "$TL_BIN/tail"
printf 'x%.0s' $(seq 1 300) >"$LOG"; printf '\n' >>"$LOG"
for _ in 1 2 3 4 5 6 7 8; do printf 'y%.0s' $(seq 1 300) >>"$LOG"; printf '\n' >>"$LOG"; done
out="$(run_surface)"
assert_eq "surface truncated to 2048 chars" 2048 "${#out}"
# Redaction failure falls back to the raw lines.
printf 'plain\n' >"$LOG"
out="$(bash -c 'source "$1"; agent_delegate_redact_output() { return 1; }; sb_agent_delegation_progress_surface' _ "$SURF")"
assert_contains "redactor failure falls back to raw text" "$out" "plain"
# Staged copy with no sibling lib directory: sourcing still works, surface reports inactive.
staged="$(orch_stage_hook agent-delegation-progress-surface.sh)"
out="$(bash -c 'source "$1"; sb_agent_delegation_progress_surface; echo "rc=$?"' _ "$staged" 2>&1 || true)"
assert_contains "lib-less staged surface does not crash" "$out" "rc="

tl_results
