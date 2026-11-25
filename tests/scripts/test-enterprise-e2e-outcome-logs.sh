#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-outcome-assessment.sh: registry lookups, routing
# rows, TUI-watch false-positive filter, log normalisation/scoring text and the log predicates.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

NOJQ="$(tl_path_without jq)"
REG="$TL_TMP/registry.json"
oa_registry "$REG" '{"criteria":[{"id":"OUT-A-01","blocking":true},{"id":"OUT-B-01","blocking":false},{"id":"OUT-C-01"}],
 "blocking_criteria":["OUT-Z-01"],"session_criteria":["OUT-S1","OUT-S2"],
 "workflow_row_map":{"3":["OUT-A-01","OUT-B-01"],"4":[]},"routing_only_rows":[1,7]}'

# --- repo root / registry path ---------------------------------------------
oa -- enterprise_e2e_outcome_repo_root
assert_eq "repo_root: SB_ROOT" "$OA_ROOT" "$TL_OUT"
e2e_call "$OA_LIB" -u SB_ROOT -- enterprise_e2e_outcome_repo_root
assert_eq "repo_root: derived from lib location" "$TL_REPO_ROOT" "$TL_OUT"
oa -- enterprise_e2e_outcome_registry_path
assert_eq "registry_path: default under root" "$OA_ROOT/docs/testing/outcome-criteria-registry.json" "$TL_OUT"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_registry_path
assert_eq "registry_path: override" "$REG" "$TL_OUT"

# --- criteria ids -----------------------------------------------------------
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_criteria_ids
assert_eq "criteria_ids: from registry" "OUT-A-01 OUT-B-01 OUT-C-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_criteria_ids
assert_eq "criteria_ids: fallback list size when registry missing" "27" "$(wc -l <<<"$TL_OUT" | tr -d ' ')"
assert_eq "criteria_ids: fallback first" "OUT-TAILOR-01" "$(head -1 <<<"$TL_OUT")"
assert_eq "criteria_ids: fallback last" "OUT-RELEASE-01" "$(tail -1 <<<"$TL_OUT")"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" "PATH=$NOJQ" -- enterprise_e2e_outcome_criteria_ids
assert_eq "criteria_ids: fallback list when jq missing" "27" "$(wc -l <<<"$TL_OUT" | tr -d ' ')"

# --- row criteria -----------------------------------------------------------
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_row_criteria 3
assert_eq "row_criteria: mapped row" "OUT-A-01 OUT-B-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_row_criteria 4
assert_eq "row_criteria: empty map entry" "" "$TL_OUT"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_row_criteria 99
assert_eq "row_criteria: unmapped row prints nothing" "" "$TL_OUT"
assert_eq "row_criteria: unmapped row succeeds" 0 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_row_criteria 1
assert_eq "row_criteria: fallback row 1" "OUT-TAILOR-01 OUT-ORCH-01 OUT-SKILL-01 OUT-HOOK-01 OUT-CODEINT-01 OUT-INTENT-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_row_criteria 3
assert_eq "row_criteria: fallback row 3" "OUT-GATES-01 OUT-VLOOP-01 OUT-PLAN-01 OUT-TRACE-01 OUT-ORCH-01 OUT-FLOW-01 OUT-INTENT-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_row_criteria 8
assert_eq "row_criteria: fallback other rows" "OUT-INTENT-01 OUT-SKILL-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"

# --- session criteria -------------------------------------------------------
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_session_criteria
assert_eq "session_criteria: from registry" "OUT-S1 OUT-S2" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_session_criteria
assert_eq "session_criteria: fallback" "OUT-SKILL-01 OUT-HOOK-01 OUT-ORCH-01 OUT-HANDOFF-01 OUT-CODEINT-01 OUT-KM-01 OUT-DECIDE-01 OUT-AUTO-01 OUT-NOOP-01 OUT-CLARIFY-01 OUT-HEAL-01 OUT-SUPER-01" "$(tr '\n' ' ' <<<"$TL_OUT" | sed 's/ $//')"

# --- routing row ------------------------------------------------------------
for r in 1 7; do
  oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_is_routing_row "$r"
  assert_eq "is_routing_row: registry row $r" 0 "$TL_STATUS"
done
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_is_routing_row 3
assert_eq "is_routing_row: registry says row 3 is not routing" 1 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_is_routing_row ""
assert_eq "is_routing_row: empty row" 1 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" -- enterprise_e2e_outcome_is_routing_row TC-01
assert_eq "is_routing_row: non-numeric row falls back to the row-1 rule" 1 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_is_routing_row 1
assert_eq "is_routing_row: fallback row 1" 0 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json" -- enterprise_e2e_outcome_is_routing_row 7
assert_eq "is_routing_row: fallback other row" 1 "$TL_STATUS"
oa "SB_E2E_OUTCOME_REGISTRY=$REG" "PATH=$NOJQ" -- enterprise_e2e_outcome_is_routing_row 7
assert_eq "is_routing_row: no jq knows only row 1" 1 "$TL_STATUS"

# --- routing evidence -------------------------------------------------------
W="$TL_TMP/w-route"
S="$TL_TMP/s-route"
mkdir -p "$W" "$S"
rev() { oa -- enterprise_e2e_outcome_routing_evidence_present "$@"; }
rev "$W" "$S"
assert_eq "routing evidence: nothing -> 1" 1 "$TL_STATUS"
: >"$W/ev.md"
rev "$W" "$S" ev.md
assert_eq "routing evidence: explicit evidence file" 0 "$TL_STATUS"
mkdir -p "$W/evdir"
rev "$W" "$S" evdir
assert_eq "routing evidence: explicit evidence directory" 0 "$TL_STATUS"
rev "$W" "$S" missing.md
assert_eq "routing evidence: explicit evidence absent" 1 "$TL_STATUS"
mkdir -p "$W/.planning/workflows/.archive/old"
rev "$W" "$S"
assert_eq "routing evidence: empty archive dir is not evidence" 1 "$TL_STATUS"
: >"$W/.planning/workflows/.archive/old/router-session.md"
rev "$W" "$S"
assert_eq "routing evidence: archived router-session.md" 0 "$TL_STATUS"
rm -rf "$W/.planning"
mkdir -p "$W/.planning/workflows"
: >"$W/.planning/workflows/router-session.md"
rev "$W" "$S"
assert_eq "routing evidence: live router-session.md" 0 "$TL_STATUS"
rm -rf "$W/.planning"
for skill in silver-router silver-context silver-feature silver-fast; do
  printf 'x\n%s\n' "$skill" >"$S/state"
  rev "$W" "$S"
  assert_eq "routing evidence: state lists $skill" 0 "$TL_STATUS"
done
printf 'silver-bugfix\n' >"$S/state"
rev "$W" "$S"
assert_eq "routing evidence: unrelated state" 1 "$TL_STATUS"

# --- compact excerpt --------------------------------------------------------
oa -- enterprise_e2e_outcome_watch_compact_excerpt "Hello, World 1! _x-Y"
assert_eq "compact excerpt: lower-cased alnum only" "helloworld1xy" "$TL_OUT"
oa -- enterprise_e2e_outcome_watch_compact_excerpt
assert_eq "compact excerpt: empty" "" "$TL_OUT"

# --- ANSI normalisation -----------------------------------------------------
ANSI="$TL_TMP/ansi.log"
printf 'a\033[31mred\033[0m b\033]0;title\007c\nplain\n' >"$ANSI"
oa -- enterprise_e2e_outcome_log_normalized "$ANSI"
assert_eq "normalized: CSI and OSC sequences stripped" "ared bc
plain" "$TL_OUT"
oa -- enterprise_e2e_outcome_log_normalized "$TL_TMP/absent.log"
assert_eq "normalized: missing file -> 1" 1 "$TL_STATUS"
oa -- enterprise_e2e_outcome_log_normalized ""
assert_eq "normalized: empty arg -> 1" 1 "$TL_STATUS"

# --- hook-deliberation false positives -------------------------------------
fp() { oa -- enterprise_e2e_outcome_watch_is_hook_deliberation_fp "$@"; }
while IFS='|' read -r phrase; do
  fp planning-file-guard "$phrase"
  assert_eq "fp: '$phrase'" 0 "$TL_STATUS"
done <<'PHRASES'
I could issue an SB OVERRIDE here
the sb override path
harness ignoring this
non-blocking notice
disposition menu shown
do not present options
so I need to proceed
let me continue
I have permission
canonical routing applies
matrix mode on
matrix mod
enterprise e2e run
the user has invoked this
orchestrator output follows
create workflow now
evidenc writes ok
evidence wries ok
blocks required workflow
workflow evidence writes
an override with a reason
subsequent planning-file-guard block
authorized for any planning-file-guard block
erride authorized for planning-file-guard blocks
survives the planning-file-guard
b override if needed for planning-file-guard
PHRASES
fp planning-file-guard "completely unrelated tool failure"
assert_eq "fp: unrelated excerpt without log is a real finding" 1 "$TL_STATUS"
fp planning-file-guard "unrelated" "$TL_TMP/absent.log"
assert_eq "fp: log path that does not exist" 1 "$TL_STATUS"
fp some-other-hook "I could issue an SB OVERRIDE here"
assert_eq "fp: other hook names are never filtered" 1 "$TL_STATUS"
fp
assert_eq "fp: no args" 1 "$TL_STATUS"
oa_log "$TL_TMP/fp1.log" "x" "[harness] ignoring hook warning" "y"
fp planning-file-guard "unrelated" "$TL_TMP/fp1.log"
assert_eq "fp: harness-ignoring line in the log excuses the finding" 0 "$TL_STATUS"
oa_log "$TL_TMP/fp2.log" "[harness] ignoring non-blocking hook" "Stop hook blocks completion"
fp planning-file-guard "unrelated" "$TL_TMP/fp2.log"
assert_eq "fp: harness-ignoring line plus a Stop-hook block is still a finding" 1 "$TL_STATUS"
oa_log "$TL_TMP/fp3.log" "[harness] ignoring hook" "session ended on hook block"
fp planning-file-guard "unrelated" "$TL_TMP/fp3.log"
assert_eq "fp: session-ended-on-hook-block also keeps the finding" 1 "$TL_STATUS"
oa_log "$TL_TMP/fp4.log" "nothing relevant"
fp planning-file-guard "unrelated" "$TL_TMP/fp4.log"
assert_eq "fp: log without harness-ignoring line" 1 "$TL_STATUS"

# --- hook blocker in the TUI watch file -------------------------------------
WATCH="$TL_TMP/watch.jsonl"
blk() { oa "$@" -- enterprise_e2e_outcome_watch_has_hook_blocker "$WATCH" "${BLK_ROW:-}" "${BLK_LOG:-}"; }
BLK_ROW="" BLK_LOG=""
oa -- enterprise_e2e_outcome_watch_has_hook_blocker "$TL_TMP/nowatch.jsonl"
assert_eq "blocker: no watch file" 1 "$TL_STATUS"
cat >"$WATCH" <<'JL'
{"severity":"annoyance","category":"hook","row":3,"message":"x","excerpt":"y"}
{"severity":"blocker","category":"tool","row":3,"message":"x","excerpt":"y"}
{"severity":"blocker","category":"hook","row":4,"message":"planning-file-guard","excerpt":"issue an SB OVERRIDE"}
JL
blk
assert_eq "blocker: only noise and a filtered false positive -> none" 1 "$TL_STATUS"
echo '{"severity":"blocker","category":"hook","row":4,"message":"completion-audit","excerpt":"denied"}' >>"$WATCH"
blk
assert_eq "blocker: a real hook blocker is reported" 0 "$TL_STATUS"
BLK_ROW=3 blk
assert_eq "blocker: row filter excludes other rows' blockers" 1 "$TL_STATUS"
BLK_ROW=4 blk
assert_eq "blocker: row filter keeps this row's blocker" 0 "$TL_STATUS"
BLK_ROW=0 blk
assert_eq "blocker: row 0 means no filtering" 0 "$TL_STATUS"
# blank lines from the filter output are skipped (jq stub prefixes the -c stream with an empty line)
REALJQ="$(command -v jq)"
tl_stub jq 'if [[ " $* " == *" -c "* ]]; then echo; fi; exec "'"$REALJQ"'" "$@"'
blk "PATH=$PATH"
assert_eq "blocker: empty line in filter output is skipped, real blocker still found" 0 "$TL_STATUS"
rm -f "$TL_BIN/jq"
# log-based exemption is forwarded to the false-positive filter
printf '%s\n' '{"severity":"blocker","category":"hook","row":5,"message":"planning-file-guard","excerpt":"unrelated words"}' >"$WATCH"
oa_log "$TL_TMP/bl.log" "[harness] ignoring non-blocking hook"
BLK_ROW=5 BLK_LOG="$TL_TMP/bl.log" blk
assert_eq "blocker: log excuses a planning-file-guard finding" 1 "$TL_STATUS"
BLK_ROW=5 BLK_LOG="" blk
assert_eq "blocker: same finding without the log counts" 0 "$TL_STATUS"
# grep fallback without jq
printf '%s\n' '{"severity": "blocker", "category": "hook"}' >"$WATCH"
BLK_ROW="" blk "PATH=$NOJQ"
assert_eq "blocker (no jq): blocker+hook strings" 0 "$TL_STATUS"
printf '%s\n' '{"severity": "blocker", "category": "tool"}' >"$WATCH"
blk "PATH=$NOJQ"
assert_eq "blocker (no jq): blocker without hook category" 1 "$TL_STATUS"
printf '%s\n' '{"severity": "warn", "category": "hook"}' >"$WATCH"
blk "PATH=$NOJQ"
assert_eq "blocker (no jq): hook category without blocker severity" 1 "$TL_STATUS"

# --- blocking criteria ------------------------------------------------------
blocking() { oa "$@" -- enterprise_e2e_outcome_is_blocking "$BLOCK_ID"; }
BLOCK_ID=OUT-Z-01; blocking "SB_E2E_OUTCOME_REGISTRY=$REG"
assert_eq "is_blocking: listed in blocking_criteria" 0 "$TL_STATUS"
BLOCK_ID=OUT-A-01; blocking "SB_E2E_OUTCOME_REGISTRY=$REG"
assert_eq "is_blocking: criterion flagged blocking" 0 "$TL_STATUS"
BLOCK_ID=OUT-B-01; blocking "SB_E2E_OUTCOME_REGISTRY=$REG"
assert_eq "is_blocking: criterion flagged non-blocking" 1 "$TL_STATUS"
BLOCK_ID=OUT-NOPE; blocking "SB_E2E_OUTCOME_REGISTRY=$REG"
assert_eq "is_blocking: unknown criterion" 1 "$TL_STATUS"
for id in OUT-AUTO-01 OUT-CLARIFY-01 OUT-NOOP-01 OUT-WORLD-01; do
  BLOCK_ID=$id; blocking "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json"
  assert_eq "is_blocking: fallback $id" 0 "$TL_STATUS"
done
BLOCK_ID=OUT-PLAN-01; blocking "SB_E2E_OUTCOME_REGISTRY=$TL_TMP/absent.json"
assert_eq "is_blocking: fallback non-blocking criterion" 1 "$TL_STATUS"
BLOCK_ID=OUT-AUTO-01; blocking "SB_E2E_OUTCOME_REGISTRY=$REG" "PATH=$NOJQ"
assert_eq "is_blocking: no jq uses the fallback list" 0 "$TL_STATUS"

# --- effective row log ------------------------------------------------------
eff() { oa -- enterprise_e2e_outcome_effective_row_log "${EFF_LOG-}"; }
oa_log "$TL_TMP/full.log" "content"
: >"$TL_TMP/empty.log"
EFF_LOG="$TL_TMP/full.log" eff
assert_eq "effective: non-empty log is used" "$TL_TMP/full.log" "$TL_OUT"
EFF_LOG="$TL_TMP/empty.log" eff
assert_eq "effective: empty log without transcript is returned as-is" "$TL_TMP/empty.log" "$TL_OUT"
EFF_LOG="" eff
assert_eq "effective: no log and no transcript -> nothing" "" "$TL_OUT"
TR="$OA_ROOT/tests/live/agents/codex/transcripts/latest.jsonl"
mkdir -p "$(dirname "$TR")"
echo '{}' >"$TR"
EFF_LOG="$TL_TMP/empty.log" eff
assert_eq "effective: empty log falls back to the codex transcript" "$TR" "$TL_OUT"
EFF_LOG="" eff
assert_eq "effective: no log falls back to the codex transcript" "$TR" "$TL_OUT"
EFF_LOG="$TL_TMP/full.log" eff
assert_eq "effective: transcript never beats a non-empty log" "$TL_TMP/full.log" "$TL_OUT"
rm -f "$TR"

# --- scoring text -----------------------------------------------------------
oa -- enterprise_e2e_outcome_log_scoring_text "$TL_TMP/absent.log"
assert_eq "scoring text: missing log -> 1" 1 "$TL_STATUS"
oa -- enterprise_e2e_outcome_log_scoring_text ""
assert_eq "scoring text: empty arg -> 1" 1 "$TL_STATUS"
oa -- enterprise_e2e_outcome_log_scoring_text "$ANSI"
assert_eq "scoring text: plain logs are just normalised" "ared bc
plain" "$TL_OUT"
cat >"$TL_TMP/stream.log" <<'SL'
HARNESS graphify: scope ok
--- HARNESS composite row 3
plain tui line

{"type":"assistant","text":"assistant says hello"}
{"type":"assistant","text":"  ","delta":"delta wins"}
{"type":"user","message":"user message"}
{"type":"result","content":"content text"}
{"type":"result","result":"final result"}
{"type":"result","text":5,"result":"non-string text falls through to the next key"}
{"type":"assistant"}
{"type":"tool_call","subtype":"started","tool_call":{"name":"Bash"}}
{"type":"tool_call","subtype":"completed","tool_call":{"toolName":"Read"}}
{"type":"tool_call","subtype":"started","tool_call":{"grepToolCall":{"args":{}}}}
{"type":"tool_call","subtype":"progress","tool_call":{"name":"Ignored"}}
{"type":"tool_call","subtype":"started"}
{"type":"readToolCall","text":"file body must not be scored"}
{not valid json
SL
oa -- enterprise_e2e_outcome_log_scoring_text "$TL_TMP/stream.log"
assert_eq "scoring text: stream-json reduced to scorable text" "HARNESS graphify: scope ok
--- HARNESS composite row 3
plain tui line
assistant says hello
delta wins
user message
content text
final result
non-string text falls through to the next key
TOOL: Bash
TOOL: Read
TOOL: grepToolCall" "$TL_OUT"
assert_not_contains "scoring text: invalid JSON line dropped" "$TL_OUT" "not valid json"

# --- log_matches ------------------------------------------------------------
oa_log "$TL_TMP/m.log" "The Quick Brown Fox"
m() { oa -- enterprise_e2e_outcome_log_matches "$@"; }
m "$TL_TMP/m.log" 'quick.*fox'
assert_eq "log_matches: case-insensitive ERE match" 0 "$TL_STATUS"
m "$TL_TMP/m.log" 'slow'
assert_eq "log_matches: no match" 1 "$TL_STATUS"
m "$TL_TMP/m.log" ''
assert_eq "log_matches: empty pattern" 1 "$TL_STATUS"
m "$TL_TMP/absent.log" 'fox'
assert_eq "log_matches: missing log" 1 "$TL_STATUS"
m "" 'fox'
assert_eq "log_matches: no log" 1 "$TL_STATUS"
m "$TL_TMP/m.log" '[unclosed'
assert_eq "log_matches: invalid regex is a non-match" 1 "$TL_STATUS"
printf 'ESC\033[1mBOLD\033[0m text\n' >"$TL_TMP/m2.log"
m "$TL_TMP/m2.log" 'ESCBOLD text'
assert_eq "log_matches: ANSI stripped before matching" 0 "$TL_STATUS"
echo '{"type":"assistant","text":"scored words"}' >"$TL_TMP/m3.log"
m "$TL_TMP/m3.log" 'scored words'
assert_eq "log_matches: matches reduced stream text" 0 "$TL_STATUS"
echo '{"type":"readToolCall","text":"file body words"}
HARNESS x' >"$TL_TMP/m4.log"
m "$TL_TMP/m4.log" 'file body words'
assert_eq "log_matches: embedded tool-call bodies are not scored" 1 "$TL_STATUS"
: >"$TL_TMP/m5.log"
mkdir -p "$(dirname "$TR")"
echo '{"type":"assistant","text":"from transcript"}' >"$TR"
m "$TL_TMP/m5.log" 'from transcript'
assert_eq "log_matches: empty log scored from the codex transcript" 0 "$TL_STATUS"
rm -f "$TR"

tl_results
