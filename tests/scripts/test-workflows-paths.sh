#!/usr/bin/env bash
# scripts/workflows.sh: repo-root resolution, argument errors, flow-row mutation edge cases,
# id generation fault paths, listing/active edge cases. Always in temporary projects.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

WF="$TL_REPO_ROOT/scripts/workflows.sh"
P="$TL_TMP/proj"
mkdir -p "$P/.git" "$P/sub/deeper"
inp() { local d="$1"; shift; pushd "$d" >/dev/null; tl_run "$@"; popd >/dev/null; }
wf() { inp "$P" bash "$WF" "$@"; }
WDIR="$P/.planning/workflows"

# --- repo root resolution ------------------------------------------------------
inp "$P/sub/deeper" bash "$WF" start silver-feature "from subdir"
assert_eq "start from nested dir succeeds" 0 "$TL_STATUS"
ID="$TL_OUT"
assert_file_exists "workflow lives under the .git root" "$WDIR/$ID.md"
assert_file_absent "no .planning created in the subdir" "$P/sub/deeper/.planning"

mkdir -p "$TL_TMP/plain/x"
inp "$TL_TMP/plain/x" bash "$WF" list
assert_eq "outside any repo exits 1" 1 "$TL_STATUS"
assert_contains "outside repo message" "$TL_ERR" "workflows.sh: not inside a repo (no .planning/ or .git/ found)"

mkdir -p "$TL_TMP/planonly/.planning" "$TL_TMP/planonly/y"
inp "$TL_TMP/planonly/y" bash "$WF" start silver-bugfix
assert_eq ".planning marker also resolves the root" 0 "$TL_STATUS"
assert_file_exists "workflow under .planning root" "$TL_TMP/planonly/.planning/workflows/$TL_OUT.md"

# --- dispatch ------------------------------------------------------------------
for a in "" -h --help; do
  if [[ -z "$a" ]]; then wf; else wf "$a"; fi
  assert_eq "help '$a' exits 0" 0 "$TL_STATUS"
  assert_contains "help '$a' text" "$TL_OUT" "workflows.sh — composed-workflow lifecycle helper"
done
wf frobnicate
assert_eq "unknown command exits 1" 1 "$TL_STATUS"
assert_contains "unknown command message" "$TL_ERR" "workflows.sh: unknown command: frobnicate"

# --- start: argument errors, sanitising, flows -----------------------------------
wf start
assert_eq "start without composer fails" 1 "$TL_STATUS"
assert_contains "start usage" "$TL_ERR" "usage: workflows.sh start <composer>"
wf start ":/:"
assert_eq "composer that sanitises to empty fails" 1 "$TL_STATUS"
assert_contains "invalid composer message" "$TL_ERR" "workflows.sh: invalid composer name"

wf start "SB:Feature/X y" "ship it" " explore , ,plan,, ship "
assert_eq "messy composer/flows start" 0 "$TL_STATUS"
ID2="$TL_OUT"
assert_match "composer sanitised in id" '-sb-feature-x-y$' "$ID2"
body="$(cat "$WDIR/$ID2.md")"
assert_contains "raw composer kept in frontmatter" "$body" "composer: SB:Feature/X y"
assert_contains "flow 1 trimmed" "$body" "| 1 | explore | pending | - | - |"
assert_contains "blank flow entries skipped, numbering continues" "$body" "| 2 | plan | pending | - | - |"
assert_contains "flow 3 trimmed" "$body" "| 3 | ship | pending | - | - |"
assert_not_contains "no fourth row" "$body" "| 4 |"
assert_eq "workflow file is private (umask 0077)" 600 "$(stat -c %a "$WDIR/$ID2.md" 2>/dev/null || stat -f %Lp "$WDIR/$ID2.md")"

# only separators in the flow list -> default unspecified row
wf start silver-x "intent" " , ,"
assert_contains "all-blank flow list falls back to the unspecified row" "$(cat "$WDIR/$TL_OUT.md")" "| 1 | (unspecified) | pending | - | - |"

# id generation: no base32 -> hex fallback; empty suffix -> refused
PATH="$(tl_path_without base32)" wf start silver-hex
assert_eq "start without base32 succeeds" 0 "$TL_STATUS"
assert_match "hex fallback suffix is 6 hex chars" '^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}-silver-hex$' "$TL_OUT"
tl_stub base32 'exit 0'
BEFORE="$(find "$WDIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
wf start silver-nosuffix
assert_eq "empty random suffix is rejected" 1 "$TL_STATUS"
assert_contains "invalid id message" "$TL_ERR" "workflows.sh: failed to generate valid id ("
assert_eq "no file created for the rejected id" "$BEFORE" "$(find "$WDIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
rm -f "${TL_BIN:?}/base32"

# --- heartbeat / get / id validation ----------------------------------------------
wf heartbeat
assert_eq "heartbeat without id fails" 1 "$TL_STATUS"
assert_contains "heartbeat invalid id" "$TL_ERR" "invalid workflow id"
wf heartbeat 20260101T000000Z-abc123-ghost
assert_eq "heartbeat unknown id fails" 1 "$TL_STATUS"
assert_contains "heartbeat not found" "$TL_ERR" "workflow not found: 20260101T000000Z-abc123-ghost"
wf get 20260101T000000Z-abc123-ghost
assert_contains "get not found" "$TL_ERR" "workflow not found"

# a symlink never counts as a workflow (no reads/writes through it)
echo "secret" >"$TL_TMP/target.md"
LINKID=20260101T000000Z-abc123-linked
ln -s "$TL_TMP/target.md" "$WDIR/$LINKID.md"
wf heartbeat "$LINKID"
assert_eq "heartbeat refuses a symlinked workflow" 1 "$TL_STATUS"
wf complete-flow "$LINKID" plan
assert_eq "complete-flow refuses a symlinked workflow" 1 "$TL_STATUS"
wf complete "$LINKID"
assert_eq "complete refuses a symlinked workflow" 1 "$TL_STATUS"
assert_eq "symlink target untouched" "secret" "$(cat "$TL_TMP/target.md")"
rm -f "${WDIR:?}/$LINKID.md"

# --- complete-flow ----------------------------------------------------------------
wf complete-flow
assert_eq "complete-flow without args fails" 1 "$TL_STATUS"
assert_contains "complete-flow usage" "$TL_ERR" "usage: workflows.sh complete-flow <id> <flow-name>"
wf complete-flow "$ID"
assert_eq "complete-flow without a flow name fails" 1 "$TL_STATUS"
assert_contains "complete-flow without a name shows usage" "$TL_ERR" "usage: workflows.sh complete-flow"

wf start silver-feature "rows" "plan,ship,plan"
RID="$TL_OUT"; RF="$WDIR/$RID.md"
# in-progress row keeps its started timestamp (regression: it used to become a literal \2)
sed -i 's/^| 1 | plan | pending | - | - |$/| 1 | plan | in-progress | 2026-01-01T00:00:00Z | - |/' "$RF"
wf complete-flow "$RID" plan
assert_eq "complete-flow in-progress row ok" 0 "$TL_STATUS"
row1="$(grep '^| 1 | plan ' "$RF")"
assert_match "started timestamp preserved" '^\| 1 \| plan \| complete \| 2026-01-01T00:00:00Z \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z \|$' "$row1"
assert_not_contains "no literal backreference leaked" "$row1" '\2'
# duplicate flow names: first matching *incomplete* row only, then the next one
assert_contains "second 'plan' row untouched by first call" "$(cat "$RF")" "| 3 | plan | pending | - | - |"
wf complete-flow "$RID" plan
assert_match "second call completes the next plan row" '\| 3 \| plan \| complete \| - \| ' "$(grep '^| 3 | plan ' "$RF")"
assert_contains "ship still pending" "$(cat "$RF")" "| 2 | ship | pending | - | - |"
# whitespace-insensitive matching
wf start silver-feature "ws" "my flow"
WID="$TL_OUT"
wf complete-flow "$WID" "myflow"
assert_match "name match ignores spaces" '\| 1 \| my flow \| complete \| - \| ' "$(grep '^| 1 | my' "$WDIR/$WID.md")"
# unknown flow / already complete: file content unchanged
before="$(cat "$RF")"
wf complete-flow "$RID" nonexistent
assert_eq "unknown flow is a no-op" 0 "$TL_STATUS"
assert_eq "unknown flow leaves the file unchanged" "$before" "$(cat "$RF")"
wf complete-flow "$RID" ship
wf complete-flow "$RID" ship
assert_eq "re-completing a completed flow is a no-op" 0 "$TL_STATUS"
assert_eq "no stray temp files left behind" 0 "$(find "$WDIR" -maxdepth 1 -name '*.md.*' | wc -l | tr -d ' ')"

# --- complete -----------------------------------------------------------------------
wf complete
assert_eq "complete without id fails" 1 "$TL_STATUS"
wf complete 20260101T000000Z-abc123-ghost
assert_eq "complete unknown id fails" 1 "$TL_STATUS"
assert_contains "complete unknown id message" "$TL_ERR" "workflow not found"
wf complete "$RID"
assert_eq "complete succeeds" 0 "$TL_STATUS"
arch="$(cat "$WDIR/.archive/$RID.md")"
assert_contains "archived status complete" "$arch" "status: complete"
assert_contains "archived completed_at" "$arch" "completed_at: "
assert_file_absent "removed from active dir" "$RF"
# frontmatter without a status line still gets completed_at before the closing ---
printf -- '---\nworkflow_id: x\n---\nbody\n' >"$WDIR/20260101T000000Z-nostat-bare.md"
wf complete 20260101T000000Z-nostat-bare
assert_eq "complete without status line ok" 0 "$TL_STATUS"
assert_match "completed_at inserted before closing marker" '^---'$'\n''workflow_id: x'$'\n''completed_at: .*'$'\n''---'$'\n''body' "$(cat "$WDIR/.archive/20260101T000000Z-nostat-bare.md")"

# --- list / active ------------------------------------------------------------------
Q="$TL_TMP/q"; mkdir -p "$Q/.git"
inp "$Q" bash "$WF" list
assert_eq "list without a workflows dir is empty" "" "$TL_OUT"
assert_eq "list without a workflows dir exits 0" 0 "$TL_STATUS"
inp "$Q" bash "$WF" active
assert_eq "active without a workflows dir fails" 1 "$TL_STATUS"
assert_contains "active without dir message" "$TL_ERR" "workflows.sh: no active workflows"
mkdir -p "$Q/.planning/workflows/dir.md"
inp "$Q" bash "$WF" list
assert_eq "directories named *.md are not listed" "" "$TL_OUT"
inp "$Q" bash "$WF" active
assert_eq "directories named *.md are not active workflows" 1 "$TL_STATUS"
assert_contains "no active when only dirs" "$TL_ERR" "no active workflows"
inp "$Q" bash "$WF" start silver-a
ONE="$TL_OUT"
inp "$Q" bash "$WF" active
assert_eq "single active path" "$Q/.planning/workflows/$ONE.md" "$TL_OUT"
inp "$Q" bash "$WF" start silver-b
inp "$Q" bash "$WF" active
assert_eq "two active fails" 1 "$TL_STATUS"
assert_contains "multiple message" "$TL_ERR" "multiple active workflows; pass id explicitly"

# --- defence in depth: complete-flow refuses a symlink that appears after the lookup ----------
ln -s "$TL_TMP/target.md" "$TL_TMP/link-to-target.md"
OUT="$(cd "$P" && bash -c '
  script="$1"; link="$2"; set --
  source "$script" >/dev/null
  _workflow_file() { printf "%s" "$link"; }
  cmd_complete_flow x plan 2>&1
  echo "rc=$?"
' _ "$WF" "$TL_TMP/link-to-target.md" || true)"
assert_contains "symlink race is refused" "$OUT" "workflows.sh: refusing to write through symlink: $TL_TMP/link-to-target.md"
assert_eq "symlink target still untouched after race refusal" "secret" "$(cat "$TL_TMP/target.md")"

tl_results
