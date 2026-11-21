#!/usr/bin/env bash
# Replays the (synthetic, see tests/fixtures/rfl/README.md) Claude Agent-tool payload fixtures through
# hooks/review-fix-ladder-guard.sh: every known tool_response shape must end in a captured result or a
# failed attempt, never in a false CLEAN.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/testlib.sh
source "$REPO/tests/lib/testlib.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
GUARD="$REPO/hooks/review-fix-ladder-guard.sh"
CLI="$REPO/scripts/review-fix-ladder.py"
FIX="$REPO/tests/fixtures/rfl"

P="$TL_TMP/proj"
tl_git_repo "$P"
mkdir -p "$P/src"
printf 'x = 1\n' >"$P/src/a.py"
printf '# SB\n' >"$P/silver-bullet.md"
printf '{"sb_initiated": true}\n' >"$P/.silver-bullet.json"
git -C "$P" add -A && git -C "$P" commit -qm files
printf '{"goal":"g","scope":["src"],"key_tasks":["t"],"signals":[]}\n' >"$TL_TMP/charter.json"
cli() { (cd "$P" && python3 "$CLI" "$@"); }
RD="$P/.planning/rfl-demo"
cli --start --charter-file "$TL_TMP/charter.json" --run-id demo --rungs "sonnet:high sonnet:xhigh" >/dev/null
cli --approve --run-dir "$RD" >/dev/null

# render <fixture> <ticket> <prompt> [result-json]
render() { jq --arg c "$P" --arg t "$2" --arg p "$3" --arg r "${4:-}" '
  def sub: gsub("__CWD__"; $c) | gsub("__TICKET__"; $t) | gsub("__PROMPT__"; $p) | gsub("__RESULT__"; $r);
  walk(if type == "string" then sub else . end)' "$FIX/$1"; }
guard() { (cd "$P" && printf '%s' "$1" | bash "$GUARD" 2>/dev/null) || true; }
issue() { cli --issue-ticket review --run-dir "$RD" >"$TL_TMP/issued.json"; TICKET="$(jq -r .ticket "$TL_TMP/issued.json")"; PROMPT="$(jq -r .spawn.params.prompt "$TL_TMP/issued.json")"; }
phase() { cli --status --run-dir "$RD" | jq -r .phase; }
CLEAN='{"verdict":"CLEAN","findings":[]}'

for f in "$FIX"/*.json; do
  assert_eq "$(basename "$f") says it is synthetic" "synthetic" "$(jq -r '._fixture.source' "$f")"
done

# the pre fixtures (Agent and its Task alias, plain and namespaced) are allowed under a matching ticket
issue
assert_eq "claude-agent-pre.json: the exact spawn is allowed" "" "$(guard "$(render claude-agent-pre.json "$TICKET" "$PROMPT")")"
cli --cancel-ticket --run-dir "$RD" >/dev/null
issue
assert_eq "claude-agent-pre-namespaced.json: a namespaced plugin agent via the Task alias is allowed" "" "$(guard "$(render claude-agent-pre-namespaced.json "$TICKET" "$PROMPT")")"

# every post shape that carries a block is captured
assert_eq "claude-agent-post.json: captured" "" "$(guard "$(render claude-agent-post.json "$TICKET" "$PROMPT" "$CLEAN")")"
assert_eq "claude-agent-post.json: the review moved the run to triage" "triage" "$(phase)"
assert_file_exists "the captured review is on disk" "$RD/rung-01-sonnet-high/review.md"

# shapes without a block are failed attempts, never a captured verdict
rm -f "$SB_RUNTIME_STATE_DIR/rfl-live.json"  # a new session: the first run is no longer live
cli --start --charter-file "$TL_TMP/charter.json" --run-id two --rungs "sonnet:high sonnet:xhigh" >/dev/null
RD="$P/.planning/rfl-two"
cli --approve --run-dir "$RD" >/dev/null
# the string-shaped tool_response (plain text) is captured too
issue
assert_eq "claude-agent-post-string.json: captured" "" "$(guard "$(render claude-agent-post-string.json "$TICKET" "$PROMPT" "$CLEAN")")"
assert_eq "claude-agent-post-string.json: the review moved the run to triage" "triage" "$(phase)"
cli --abort two >/dev/null 2>&1 || true
rm -rf "$RD"; rm -f "$SB_RUNTIME_STATE_DIR/rfl-live.json"
cli --start --charter-file "$TL_TMP/charter.json" --run-id three --rungs "sonnet:high sonnet:xhigh" >/dev/null
RD="$P/.planning/rfl-three"
cli --approve --run-dir "$RD" >/dev/null
for shape in claude-agent-post-noverdict.json claude-agent-post-async.json; do
  issue
  guard "$(render "$shape" "$TICKET" "$PROMPT")" >/dev/null
  assert_eq "$shape: no verdict is recorded" "review" "$(phase)"
  assert_eq "$shape: it counts as a failed attempt" "no_verdict" "$(jq -r .outcome "$RD/tickets/$TICKET.json")"
  assert_file_absent "$shape: no review.md appears" "$RD/rung-01-sonnet-high/review.md"
  cli --status --run-dir "$RD" >/dev/null
done
assert_eq "two failed attempts skipped the rung, the ladder moved on" "2" "$(cli --status --run-dir "$RD" | jq -r .rung.index)"
issue
guard "$(render claude-agent-post-ratelimit.json "$TICKET" "$PROMPT")" >/dev/null
assert_eq "claude-agent-post-ratelimit.json: the run pauses" "paused_quota" "$(cli --status --run-dir "$RD" | jq -r .status)"
assert_file_exists "the quota classification is recorded" "$RD/rung-02-sonnet-xhigh/QUOTA-CLASSIFY.json"

# a payload from inside an RFL subagent may never edit
out="$(guard "$(render claude-subagent-edit.json x x)")"
assert_contains "claude-subagent-edit.json: an RFL role may not edit" "$out" "read-only"

tl_results
