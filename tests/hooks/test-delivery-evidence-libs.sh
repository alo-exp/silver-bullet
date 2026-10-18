#!/usr/bin/env bash
# Unit tests for hooks/lib/artifact-substance-gate.sh and hooks/lib/evidence-schema-gate.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/artifact-substance-gate.sh
source "$TL_REPO_ROOT/hooks/lib/artifact-substance-gate.sh"
# shellcheck source=../../hooks/lib/evidence-schema-gate.sh
source "$TL_REPO_ROOT/hooks/lib/evidence-schema-gate.sh"

R="$TL_TMP/repo"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
WARN="$TL_TMP/warn"; BLOCK="$TL_TMP/block"
emit_warn() { printf '%s' "$1" >"$WARN"; }
emit_block() { printf '%s' "$1" >"$BLOCK"; }
reset() { rm -rf "$R" "$WARN" "$BLOCK"; mkdir -p "$R/.planning/phases/01-a"; }
enforce() { # strict state
  ER=0
  (sb_artifact_substance_gate_enforce "$R" emit_warn emit_block "$1" "${2:-}") || ER=$?
}
GOOD_V=$'# Verification\n\n```bash\n$ make test\nok\n```\n'
GOOD_R=$'# Review\n\nNo findings.\n'
ROUNDS2=$'## Round 1\nclean\n## Round 2\nclean\n'

# --- helper predicates -----------------------------------------------------------
reset
echo "x" >"$R/.planning/VERIFICATION.md"
assert_eq "find: planning root artifact" "$R/.planning/VERIFICATION.md" "$(_sb_substance_find_artifact "$R" VERIFICATION.md)"
rm -f "$R/.planning/VERIFICATION.md"; echo x >"$R/.planning/phases/01-a/VERIFICATION.md"
assert_eq "find: phase artifact" "$R/.planning/phases/01-a/VERIFICATION.md" "$(_sb_substance_find_artifact "$R" VERIFICATION.md)"
rm -f "$R/.planning/phases/01-a/VERIFICATION.md"; echo x >"$R/.planning/phases/01-a/01-VERIFICATION.md"
assert_eq "find: prefixed phase artifact" "$R/.planning/phases/01-a/01-VERIFICATION.md" "$(_sb_substance_find_artifact "$R" VERIFICATION.md)"
rm -f "$R/.planning/phases/01-a/01-VERIFICATION.md"; ln -s "$TL_TMP/x" "$R/.planning/VERIFICATION.md"
assert_eq "find: symlink ignored" 1 "$(rc _sb_substance_find_artifact "$R" VERIFICATION.md)"
rm -f "$R/.planning/VERIFICATION.md"
printf '# only heading\n\n| --- | --- |\n' >"$TL_TMP/stub1"; assert_eq "stub: headings and table rules only" 0 "$(rc _sb_substance_is_stub "$TL_TMP/stub1")"
printf 'real content TODO later\n' >"$TL_TMP/stub2"; assert_eq "stub: TODO marker" 0 "$(rc _sb_substance_is_stub "$TL_TMP/stub2")"
printf 'real content here\n' >"$TL_TMP/stub3"; assert_eq "stub: real content" 1 "$(rc _sb_substance_is_stub "$TL_TMP/stub3")"
assert_eq "stub: unreadable file counts as stub" 0 "$(rc _sb_substance_is_stub "$TL_TMP/missing")"
printf '```bash\nls\n```\n' >"$TL_TMP/c1"; assert_eq "command output: fenced block" 0 "$(rc _sb_substance_has_command_output "$TL_TMP/c1")"
printf '$ pytest -q\n' >"$TL_TMP/c2"; assert_eq "command output: shell prompt line" 0 "$(rc _sb_substance_has_command_output "$TL_TMP/c2")"
printf 'plain text\n' >"$TL_TMP/c3"; assert_eq "command output: none" 1 "$(rc _sb_substance_has_command_output "$TL_TMP/c3")"

# --- enforce: VERIFICATION ----------------------------------------------------------------
reset; enforce 1
assert_eq "enforce: no artifacts => ok" 0 "$ER"; assert_file_absent "enforce: nothing emitted" "$BLOCK"
printf '# V\n' >"$R/.planning/VERIFICATION.md"; enforce 1
assert_contains "verification stub blocks" "$(cat "$BLOCK")" "VERIFICATION.md is empty or stub-only"
printf 'prose but no command output\n' >"$R/.planning/VERIFICATION.md"; rm -f "$BLOCK"; enforce 1
assert_contains "verification without command output blocks" "$(cat "$BLOCK")" "missing fenced command output"
printf '%s' "$GOOD_V" >"$R/.planning/VERIFICATION.md"; rm -f "$BLOCK"; enforce 1
assert_file_absent "good verification passes" "$BLOCK"
rm -f "$BLOCK"; printf '# V\n' >"$R/.planning/VERIFICATION.md"; enforce 0
assert_contains "non-strict mode warns" "$(cat "$WARN")" "ARTIFACT SUBSTANCE GATE"; assert_file_absent "non-strict mode does not block" "$BLOCK"
assert_eq "strict block exits 0 from the gate" 0 "$ER"

# state-scoped checks
rm -f "$WARN" "$BLOCK"; enforce 1 $'silver-plan\n'
assert_file_absent "state without review/verify markers skips both" "$BLOCK"
enforce 1 $'silver-verify\n'
assert_contains "state with silver-verify checks VERIFICATION" "$(cat "$BLOCK")" "VERIFICATION.md"
printf '%s' "$GOOD_V" >"$R/.planning/VERIFICATION.md"
printf '# R\n' >"$R/.planning/REVIEW.md"; rm -f "$BLOCK"; enforce 1 $'silver-verify\n'
assert_file_absent "state with only silver-verify ignores REVIEW" "$BLOCK"

# --- enforce: REVIEW ------------------------------------------------------------------------
reset; printf '# R\n' >"$R/.planning/REVIEW.md"; enforce 1 $'silver-review\n'
assert_contains "review stub blocks" "$(cat "$BLOCK")" "REVIEW.md is empty or stub-only"
printf 'some prose without sections\n' >"$R/.planning/REVIEW.md"; rm -f "$BLOCK"; enforce 1 $'silver-review\n'
assert_contains "review without findings blocks" "$(cat "$BLOCK")" "missing findings section"
printf '%s' "$GOOD_R" >"$R/.planning/REVIEW.md"; rm -f "$BLOCK"; enforce 1 $'silver-review\n'
assert_contains "review without rounds file blocks" "$(cat "$BLOCK")" "REVIEW-ROUNDS.md missing"
printf '## Round 1\nclean\n' >"$R/.planning/REVIEW-ROUNDS.md"; rm -f "$BLOCK"; enforce 1 $'silver-review\n'
assert_contains "one round blocks" "$(cat "$BLOCK")" "has 1 round(s)"
printf 'no rounds here\n' >"$R/.planning/REVIEW-ROUNDS.md"; rm -f "$BLOCK"; enforce 1 $'silver-review\n'
assert_contains "zero rounds blocks" "$(cat "$BLOCK")" "has 0 round(s)"
printf '%s' "$ROUNDS2" >"$R/.planning/REVIEW-ROUNDS.md"; rm -f "$BLOCK"; enforce 1 $'silver-review\n'
assert_file_absent "two rounds pass" "$BLOCK"
rm -f "$R/.planning/REVIEW-ROUNDS.md"; ln -s "$TL_TMP/rounds" "$R/.planning/REVIEW-ROUNDS.md"
enforce 1 $'silver-review\n'
assert_contains "symlinked rounds file counts as missing" "$(cat "$BLOCK")" "REVIEW-ROUNDS.md missing"
rm -f "$R/.planning/REVIEW-ROUNDS.md" "$BLOCK"
reset; enforce 1
assert_file_absent "no state, no artifacts: both checks run and pass" "$BLOCK"

# --- enforce: PLAN ----------------------------------------------------------------------------
reset; printf '# P\n' >"$R/.planning/PLAN.md"; enforce 1 $'silver-plan\n'
assert_contains "plan stub blocks" "$(cat "$BLOCK")" "PLAN.md is empty or stub-only"
printf 'some prose\n' >"$R/.planning/PLAN.md"; rm -f "$BLOCK"; enforce 1 $'silver-plan\n'
assert_contains "plan without tasks blocks" "$(cat "$BLOCK")" "PLAN.md missing task/acceptance"
printf 'Task 1: do it\n' >"$R/.planning/PLAN.md"; rm -f "$BLOCK"; enforce 1 $'silver-plan\n'
assert_file_absent "good plan passes" "$BLOCK"
rm -f "$R/.planning/PLAN.md"; enforce 1 $'silver-plan\n'
assert_file_absent "missing plan is not an error here" "$BLOCK"

# ======================= evidence schema gate =====================================================
reset
V="$R/scripts/validate-evidence-findings.sh"; mkdir -p "$R/scripts"
cat >"$V" <<'SH'
#!/usr/bin/env bash
echo "$*" >"${EV_ARGV:-/dev/null}"
printf '%s' "${EV_JSON-}"
exit "${EV_RC:-0}"
SH
export EV_ARGV="$TL_TMP/evargv"
ev() { rm -f "$WARN" "$BLOCK"; EVR=0; (sb_evidence_schema_gate_enforce "$@") || EVR=$?; }
CLEAN='{"artifacts_scanned":2,"warnings":[],"errors":[]}'
DIRTY='{"artifacts_scanned":2,"warnings":[{"path":"a.md","message":"bad col"}],"errors":[{"path":"b.md","message":"no table"}]}'

assert_eq "script path: repo script" "$V" "$(_sb_evidence_gate__script_path "$R")"
mv "$V" "$TL_TMP/v.sh"; mkdir -p "$R/plugins/silver-bullet/scripts"; cp "$TL_TMP/v.sh" "$R/plugins/silver-bullet/scripts/validate-evidence-findings.sh"
assert_eq "script path: plugin copy" "$R/plugins/silver-bullet/scripts/validate-evidence-findings.sh" "$(_sb_evidence_gate__script_path "$R")"
rm -rf "$R/plugins"
assert_eq "script path: none" 1 "$(rc _sb_evidence_gate__script_path "$R")"
ev task "$R" emit_warn emit_block; assert_eq "task mode: no-op" 0 "$EVR"
ev delivery "$R" emit_warn emit_block; assert_file_absent "no validator: fail open, silent" "$WARN"
mv "$TL_TMP/v.sh" "$V"
EV_JSON="$CLEAN" ev delivery "$R" emit_warn emit_block
assert_eq "clean scan: silent" 0 "$EVR"; assert_file_absent "clean scan: no warning" "$WARN"
assert_eq "non-strict argv" "$R --json" "$(cat "$EV_ARGV")"
EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
assert_contains "dirty scan: warning" "$(cat "$WARN")" "1 warning(s), 1 error(s)"
assert_contains "dirty scan: lists findings" "$(cat "$WARN")" "a.md: bad col"
assert_contains "dirty scan: lists errors" "$(cat "$WARN")" "b.md: no table"
assert_file_absent "dirty scan (non-strict) does not block" "$BLOCK"
SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
assert_contains "strict: blocks" "$(cat "$BLOCK")" "EVIDENCE SCHEMA GATE"
assert_eq "strict argv" "$R --strict --json" "$(cat "$EV_ARGV")"
SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 EV_JSON="$CLEAN" ev delivery "$R" emit_warn emit_block
assert_file_absent "strict + clean: no block" "$BLOCK"
EV_JSON="" ev delivery "$R" emit_warn emit_block
assert_contains "empty validator output: warns" "$(cat "$WARN")" "validator failed to run"
EV_JSON="not json" ev delivery "$R" emit_warn emit_block
assert_contains "invalid validator output: warns" "$(cat "$WARN")" "validator failed to run"
EV_RC=1 EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
assert_contains "validator non-zero exit still parsed" "$(cat "$WARN")" "EVIDENCE SCHEMA"
EV_JSON='{"artifacts_scanned":1,"warnings":[{"path":"p","message":"m"}],"errors":[]}' ev delivery "$R" emit_warn emit_block
assert_contains "warnings-only scan reports 0 errors" "$(cat "$WARN")" "0 error(s)"
SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 EV_RC=1 EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
assert_contains "strict: validator failing exit is tolerated and still blocks" "$(cat "$BLOCK")" "EVIDENCE SCHEMA GATE"
EV_JSON='{"artifacts_scanned":1,"warnings":true,"errors":true}' ev delivery "$R" emit_warn emit_block
assert_file_absent "unmeasurable counts are treated as zero: silent" "$WARN"
PATH="$(tl_path_without python3)" EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
assert_contains "no python3: skipped with notice" "$(cat "$WARN")" "python3 unavailable"
tl_stub jq 'if [[ "$*" == *"| join"* ]]; then exit 1; fi; exec '"$(command -v jq)"' "$@"'; hash -r
EV_JSON="$DIRTY" ev delivery "$R" emit_warn emit_block
rm -f "$TL_BIN/jq"; hash -r
assert_file_absent "message rendering failure: no warning emitted" "$WARN"

tl_results
