#!/usr/bin/env bash
# Unit tests for hooks/lib/doc-scheme-gate.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/doc-scheme-gate.sh
source "$TL_REPO_ROOT/hooks/lib/doc-scheme-gate.sh"
# the sealed-state accessor the hooks that call the gate have loaded
# shellcheck source=../../hooks/lib/integrity.sh
source "$TL_REPO_ROOT/hooks/lib/integrity.sh"

ST="$SB_RUNTIME_STATE_DIR"
R="$TL_TMP/repo"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
NEW=2000000000   # 2033: always "this session"
SESSION=1000

# --- mtime / status helpers ---------------------------------------------------
mkdir -p "$TL_TMP/m"; echo x >"$TL_TMP/m/f"; touch -d "@$NEW" "$TL_TMP/m/f"
assert_eq "mtime: regular file" "$NEW" "$(sb_doc_scheme__mtime_epoch "$TL_TMP/m/f")"
assert_eq "mtime: missing file => 0" 0 "$(sb_doc_scheme__mtime_epoch "$TL_TMP/m/none")"
tl_stub uname 'echo Darwin'
tl_stub stat 'if [[ "$1" == "-f" ]]; then echo 4242; else exit 1; fi'
hash -r
assert_eq "mtime: Darwin uses stat -f" 4242 "$(sb_doc_scheme__mtime_epoch "$TL_TMP/m/f")"
tl_stub stat 'echo notanumber'; hash -r
assert_eq "mtime: non-numeric stat output => 0" 0 "$(sb_doc_scheme__mtime_epoch "$TL_TMP/m/f")"
rm -f "$TL_BIN/uname" "$TL_BIN/stat"; hash -r
tl_stub uname 'echo Darwin'; tl_stub stat 'exit 1'; hash -r
assert_eq "mtime: Darwin stat failure => 0" 0 "$(sb_doc_scheme__mtime_epoch "$TL_TMP/m/f")"
rm -f "$TL_BIN/uname" "$TL_BIN/stat"; hash -r
r=0; sb_doc_scheme__mtime_epoch "$TL_TMP/m/f" >/dev/full 2>/dev/null || r=$?
assert_eq "mtime: output write failure is reported" 1 "$r"
r=0; sb_doc_scheme__mtime_epoch "$TL_TMP/m/none" >/dev/full 2>/dev/null || r=$?
assert_eq "mtime: fallback output write failure is reported" 1 "$r"
for s in updated "not-needed:covered" "n/a:internal"; do assert_eq "status valid: $s" 0 "$(rc sb_doc_scheme__status_valid "$s")"; done
for s in "" pending "not-needed" "updated-ish"; do assert_eq "status invalid: '$s'" 1 "$(rc sb_doc_scheme__status_valid "$s")"; done

# --- key_state -----------------------------------------------------------------------
rm -rf "$R"; mkdir -p "$R/docs/knowledge" "$R/docs/learnings"
sb_doc_scheme__key_state "$R" 2026-03 "docs/knowledge/YYYY-MM.md"
assert_eq "key_state: knowledge label" "docs/knowledge/2026-03*.md" "$SB_DOC_KEY_LABEL"; assert_eq "key_state: knowledge missing" 0 "$SB_DOC_KEY_EXISTS"
echo a >"$R/docs/knowledge/2026-03.md"; echo b >"$R/docs/knowledge/2026-03-extra.md"; echo c >"$R/docs/knowledge/2026-04.md"
touch -d "@1500000000" "$R/docs/knowledge/2026-03.md"; touch -d "@$NEW" "$R/docs/knowledge/2026-03-extra.md"
ln -s "$R/docs/knowledge/2026-04.md" "$R/docs/knowledge/2026-03-link.md"
sb_doc_scheme__key_state "$R" 2026-03 "docs/knowledge/YYYY-MM.md"
assert_eq "key_state: knowledge newest matching file wins" "1 $NEW" "$SB_DOC_KEY_EXISTS $SB_DOC_KEY_MTIME"
sb_doc_scheme__key_state "$R" 2026-03 "docs/learnings/YYYY-MM.md"
assert_eq "key_state: learnings label" "docs/learnings/2026-03*.md" "$SB_DOC_KEY_LABEL"; assert_eq "key_state: learnings missing" 0 "$SB_DOC_KEY_EXISTS"
echo l >"$R/docs/learnings/2026-03.md"; touch -d "@1600000000" "$R/docs/learnings/2026-03.md"
ln -s "$R/docs/learnings/2026-03.md" "$R/docs/learnings/2026-03-link.md"
sb_doc_scheme__key_state "$R" 2026-03 "docs/learnings/YYYY-MM.md"
assert_eq "key_state: learnings found (symlink ignored)" "1 1600000000" "$SB_DOC_KEY_EXISTS $SB_DOC_KEY_MTIME"
echo p >"$R/README.md"; touch -d "@$NEW" "$R/README.md"
sb_doc_scheme__key_state "$R" 2026-03 README.md
assert_eq "key_state: plain file" "1 $NEW README.md" "$SB_DOC_KEY_EXISTS $SB_DOC_KEY_MTIME $SB_DOC_KEY_LABEL"
sb_doc_scheme__key_state "$R" 2026-03 MISSING.md
assert_eq "key_state: plain file missing" 0 "$SB_DOC_KEY_EXISTS"
ln -s "$R/README.md" "$R/LINK.md"; sb_doc_scheme__key_state "$R" 2026-03 LINK.md
assert_eq "key_state: symlink does not count" 0 "$SB_DOC_KEY_EXISTS"

# --- gap report -----------------------------------------------------------------------
rm -rf "$ST/doc-scheme-gaps"; mkdir -p "$ST/doc-scheme-gaps"
echo '{}' >"$ST/doc-scheme-gaps/-tmp-my-repo.json"
SILVER_BULLET_SESSION_ID="sess 1" sb_doc_scheme__write_gap_report task "/tmp/my repo" "$ST" "task/1" 2 chk.json contract.json $'  - one\n  - two\n'
gp="$SB_DOC_SCHEME_GAP_REPORT_PATH"
assert_eq "gap report: path scoped by repo/session/task" "$ST/doc-scheme-gaps/-tmp-my-repo__sess 1__task-1.json" "$gp"
assert_eq "gap report: issue count" 2 "$(jq .files "$gp")"; assert_eq "gap report: mode" task "$(jq -r .mode "$gp")"
assert_eq "gap report: session id" "sess 1" "$(jq -r .session_id "$gp")"
assert_file_absent "gap report: legacy repo-only file removed" "$ST/doc-scheme-gaps/my-repo.json"
echo "S-FILE" >"$ST/session-start-time"
sb_doc_scheme__write_gap_report delivery /r "$ST" "" "" a b ""
assert_contains "gap report: session id from marker file" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "__S-FILE__unknown-task.json"
rm -f "$ST/session-start-time"
sb_doc_scheme__write_gap_report delivery / "$ST" t "" a b ""
assert_contains "gap report: no session => nosession; empty slug => repo" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "-__nosession__t.json"
sb_doc_scheme__write_gap_report delivery "" "$ST" "" "" a b ""
assert_contains "gap report: empty repo slug falls back to 'repo'" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "/repo__nosession__unknown-task.json"
sb_doc_scheme__write_gap_report delivery /r "$ST" "///" "" a b ""
assert_contains "gap report: unsafe task id sanitised" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "__---.json"

# gap report resilience: unreadable marker, empty slugs, rm failure
rm -f "$ST/session-start-time"; echo "X" >"$ST/session-start-time"
mkdir -p "$TL_TMP/trfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/trfail/tr"; chmod +x "$TL_TMP/trfail/tr"
PATH="$TL_TMP/trfail:$PATH" sb_doc_scheme__write_gap_report delivery /r "$ST" t "" a b ""
assert_contains "gap report: unreadable marker => nosession" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "__nosession__"
rm -f "$ST/session-start-time"
mkdir -p "$TL_TMP/sedfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/sedfail/sed"; chmod +x "$TL_TMP/sedfail/sed"
PATH="$TL_TMP/sedfail:$PATH" sb_doc_scheme__write_gap_report delivery /r "$ST" t "" a b "" 2>/dev/null || true
assert_contains "gap report: slug helpers failing => placeholders" "$SB_DOC_SCHEME_GAP_REPORT_PATH" "/repo__nosession__unknown-task.json"
mkdir -p "$TL_TMP/rmfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/rmfail/rm"; chmod +x "$TL_TMP/rmfail/rm"
PATH="$TL_TMP/rmfail:$PATH" sb_doc_scheme__write_gap_report delivery /r "$ST" t "" a b ""
assert_file_exists "gap report: legacy cleanup failure tolerated" "$SB_DOC_SCHEME_GAP_REPORT_PATH"

# --- enforce ----------------------------------------------------------------------------
EMITTED="$TL_TMP/emitted"
emit() { printf '%s' "$1" >"$EMITTED"; }
setup_repo() {
  rm -rf "$R" "$EMITTED" "$ST/doc-scheme-gaps" "$ST"/doc-scheme-baseline-*
  mkdir -p "$R/docs/knowledge"
  echo "# scheme" >"$R/docs/doc-scheme.md"
  cat >"$R/docs/doc-scheme.json" <<'JSON'
{"enforcement":{"enabled":true,"granularity_levels":[2,3]},
 "mandatory_updated_docs":["docs/CHANGELOG.md"],
 "required_docs":[{"key":"docs/CHANGELOG.md","required_sections":["Added"]},{"key":"docs/ARCH.md","mandatory_updated":false,"required_sections":[]}]}
JSON
  echo "log" >"$R/docs/CHANGELOG.md"; echo "arch" >"$R/docs/ARCH.md"
  touch -d "@$NEW" "$R/docs/CHANGELOG.md" "$R/docs/ARCH.md"
  cat >"$R/docs/task-doc-checklist.json" <<'JSON'
{"task_id":"T-1","task_granularity":2,"docs":{"docs/CHANGELOG.md":"updated","docs/ARCH.md":"not-needed:unchanged"},"sections":{"docs/CHANGELOG.md":{"Added":"updated"}}}
JSON
  touch -d "@$NEW" "$R/docs/task-doc-checklist.json"
  echo "$SESSION" >"$ST/session-start-time"
}
run_enforce() { # mode
  ER=0
  (sb_doc_scheme_gate_enforce "${1:-task}" "$R" "$ST" emit) || ER=$?
}
blocked() { [[ -f "$EMITTED" ]]; }
setup_repo; run_enforce
assert_eq "enforce: compliant repo passes" 0 "$ER"; assert_file_absent "enforce: nothing emitted" "$EMITTED"
rm -f "$R/docs/doc-scheme.md" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: repo without a scheme is not governed" "$EMITTED"
setup_repo; rm -f "$R/docs/doc-scheme.md"; run_enforce
assert_contains "enforce: missing policy file" "$(cat "$EMITTED")" "Missing required policy file: docs/doc-scheme.md"
assert_contains "enforce: names the gap report" "$(cat "$EMITTED")" "doc-scheme-gaps"
assert_contains "enforce: task label" "$(cat "$EMITTED")" "Task completion blocked"
setup_repo; rm -f "$R/docs/doc-scheme.json"; run_enforce delivery
assert_contains "enforce: missing contract" "$(cat "$EMITTED")" "Missing required contract file"
assert_contains "enforce: delivery label" "$(cat "$EMITTED")" "Delivery blocked"
setup_repo; rm -f "$R/docs/doc-scheme.json"; ln -s "$TL_TMP/x" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: symlinked contract counts as missing" "$(cat "$EMITTED")" "Missing required contract file"
setup_repo; rm -f "$ST/session-start-time"; run_enforce
assert_contains "enforce: missing session marker" "$(cat "$EMITTED")" "Missing/invalid session marker"
setup_repo; echo abc >"$ST/session-start-time"; run_enforce
assert_contains "enforce: invalid session marker" "$(cat "$EMITTED")" "Missing/invalid session marker"
setup_repo; echo "not-a-number" >"$TL_TMP/custom-marker"
ER=0; (SILVER_BULLET_SESSION_START_FILE="$TL_TMP/custom-marker" sb_doc_scheme_gate_enforce task "$R" "$ST" emit) || ER=$?
assert_file_absent "enforce: marker override outside the state root is ignored (default marker used)" "$EMITTED"
setup_repo; echo "$SESSION" >"$ST/alt-marker"
ER=0; TILDE_MARKER='~'"/${ST#"$HOME"/}/alt-marker"; (SILVER_BULLET_SESSION_START_FILE="$TILDE_MARKER" sb_doc_scheme_gate_enforce task "$R" "$ST" emit) || ER=$?
assert_file_absent "enforce: ~-relative marker inside the state root honoured" "$EMITTED"
setup_repo; echo '{ nope' >"$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: malformed contract" "$(cat "$EMITTED")" "is malformed"
setup_repo; jq '.enforcement.enabled=false' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; rm -f "$R/docs/task-doc-checklist.json"; run_enforce
assert_file_absent "enforce: disabled in the contract" "$EMITTED"

setup_repo; jq 'del(.task_granularity)' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: missing granularity" "$(cat "$EMITTED")" "Missing numeric task granularity"
assert_contains "enforce: lists enforced levels" "$(cat "$EMITTED")" "Contract enforces these levels: 2 3."
# R9-09: the granularity is written by the agent, so it cannot switch the gate off by itself: an out-of-scope value
# is honoured only when the recorded state shows the session ran the sanctioned small-change flow (silver-fast).
low_gran_empty() { # a granularity-1 checklist with no doc coverage at all
  jq '.task_granularity=1 | .docs={}' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"
  touch -d "@$NEW" "$R/docs/task-doc-checklist.json"
}
setup_repo; low_gran_empty; rm -f "$ST/state"; run_enforce
assert_contains "enforce: an agent-set out-of-scope granularity does not skip the gate (R9-09)" "$(cat "$EMITTED")" "Missing checklist entry: docs/CHANGELOG.md"
setup_repo; low_gran_empty; printf 'silver-quality-gates\nsilver-fast\n' >"$ST/state"; run_enforce
assert_file_absent "enforce: granularity out of scope is honoured for a recorded silver-fast session" "$EMITTED"
setup_repo; low_gran_empty; printf 'silver-fast-not-really\n' >"$ST/state"; run_enforce
assert_contains "enforce: only the exact silver-fast record counts" "$(cat "$EMITTED")" "Missing checklist entry"
setup_repo; low_gran_empty; printf 'silver-fast\n' >"$TL_TMP/outside-state"; ER=0; (SILVER_BULLET_STATE_FILE="$TL_TMP/outside-state" sb_doc_scheme_gate_enforce task "$R" "$ST" emit) || ER=$?
assert_contains "enforce: a state file outside the state directory is ignored" "$(cat "$EMITTED")" "Missing checklist entry"
setup_repo; low_gran_empty; printf 'silver-fast\n' >"$ST/state-x"; ER=0; (SILVER_BULLET_STATE_FILE="$ST/state-x" sb_doc_scheme_gate_enforce task "$R" "$ST" emit) || ER=$?
assert_file_absent "enforce: SILVER_BULLET_STATE_FILE inside the state directory is read" "$EMITTED"
rm -f "$ST/state" "$ST/state-x"
setup_repo; jq '.task_granularity=1' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_file_absent "enforce: a complete checklist at an out-of-scope granularity still passes" "$EMITTED"
setup_repo; low_gran_empty; printf 'silver-fast\n' >"$ST/state"
(unset -f sb_integrity_state_contents; ER=0; sb_doc_scheme_gate_enforce task "$R" "$ST" emit) || true
assert_contains "enforce: without the verified-state accessor nothing counts as recorded" "$(cat "$EMITTED")" "Missing checklist entry"
rm -f "$ST/state"
setup_repo; jq '.task_granularity="two"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: non-numeric granularity" "$(cat "$EMITTED")" "Missing numeric task granularity"
setup_repo; jq 'del(.enforcement.granularity_levels)' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: default levels (2,3) cover granularity 2" "$EMITTED"
setup_repo; jq '.enforcement.granularity_levels=[]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: empty levels fall back to 2,3" "$EMITTED"
setup_repo; jq '.enforcement.granularity_levels=[5]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: custom levels exclude granularity 2" "$EMITTED"

setup_repo; rm -f "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: missing checklist" "$(cat "$EMITTED")" "Missing numeric task granularity"
setup_repo; rm -f "$R/docs/task-doc-checklist.json"; ln -s "$TL_TMP/nowhere" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: symlinked checklist rejected" "$(cat "$EMITTED")" "Missing checklist"
setup_repo; touch -d "@500" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: stale checklist" "$(cat "$EMITTED")" "Stale checklist"
setup_repo; echo '{"task_id":"T","task_granularity":2,"docs":[]}' >"$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: docs must be an object" "$(cat "$EMITTED")" "Invalid checklist: .docs object missing"
setup_repo; jq '.required_docs=[]|.mandatory_updated_docs=[]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: empty required_docs" "$(cat "$EMITTED")" "required_docs[] is empty"
setup_repo; jq 'del(.docs["docs/ARCH.md"])' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: missing checklist entry" "$(cat "$EMITTED")" "Missing checklist entry: docs/ARCH.md"
setup_repo; jq '.docs["docs/ARCH.md"]="whenever"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: invalid status" "$(cat "$EMITTED")" "Invalid checklist status: docs/ARCH.md -> whenever"
setup_repo; jq '.docs["docs/CHANGELOG.md"]="not-needed:skip"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: mandatory doc must be 'updated'" "$(cat "$EMITTED")" "Required status 'updated': docs/CHANGELOG.md"
setup_repo; jq '.mandatory_updated_docs=[]|.required_docs[1].mandatory_updated=true' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: per-doc mandatory_updated flag honoured" "$(cat "$EMITTED")" "Required status 'updated': docs/ARCH.md"
setup_repo; rm -f "$R/docs/CHANGELOG.md"; run_enforce
assert_contains "enforce: updated but missing" "$(cat "$EMITTED")" "Missing file marked updated: docs/CHANGELOG.md"
setup_repo; touch -d "@500" "$R/docs/CHANGELOG.md"; run_enforce
assert_contains "enforce: updated but stale" "$(cat "$EMITTED")" "Stale file marked updated: docs/CHANGELOG.md"
setup_repo; jq 'del(.sections)' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: missing section entry" "$(cat "$EMITTED")" "Missing section checklist entry: docs/CHANGELOG.md :: Added"
setup_repo; jq '.sections["docs/CHANGELOG.md"].Added="maybe"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_contains "enforce: invalid section status" "$(cat "$EMITTED")" "Invalid section status: docs/CHANGELOG.md :: Added -> maybe"
assert_contains "enforce: remediation command names the task" "$(cat "$EMITTED")" "--task T-1 --gaps"

# R9-09: removing or weakening the scheme files is detected against what git has at HEAD
reset_docs() { rm -f "$EMITTED"; git -C "$R" checkout -q -- docs; echo more >>"$R/docs/CHANGELOG.md"; touch -d "@$NEW" "$R/docs/CHANGELOG.md" "$R/docs/task-doc-checklist.json"; }
setup_repo; git -C "$R" init -q; git -C "$R" add -A; git -C "$R" -c user.email=a@b -c user.name=n commit -q -m base
echo more >>"$R/docs/CHANGELOG.md"; touch -d "@$NEW" "$R/docs/CHANGELOG.md"
rm -f "$R/docs/doc-scheme.md" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: deleting both scheme files does not switch the gate off (R9-09)" "$(cat "$EMITTED")" "Missing required policy file: docs/doc-scheme.md"
reset_docs
rm -f "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: deleting the contract of a governed repo is a gap" "$(cat "$EMITTED")" "Missing required contract file"
reset_docs
jq '.enforcement.enabled=false' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: switching enforcement off against HEAD is a gap (R9-09)" "$(cat "$EMITTED")" "weakens the contract on the default branch"
reset_docs
jq 'del(.enforcement.enabled)' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: a missing enabled key means enabled, as at HEAD" "$EMITTED"
reset_docs
jq '.enforcement.granularity_levels=[3]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: narrowing the enforced levels against HEAD is a gap (R9-09)" "$(cat "$EMITTED")" "weakens the contract on the default branch"
reset_docs
jq '.enforcement.granularity_levels=[2,3,4]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: widening the enforced levels is fine" "$EMITTED"
reset_docs
jq 'del(.enforcement.granularity_levels)' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: dropping the levels falls back to the defaults, which HEAD also had" "$EMITTED"
reset_docs
jq '.mandatory_updated_docs=[]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: dropping a mandatory doc against HEAD is a gap (R9-09)" "$(cat "$EMITTED")" "weakens the contract on the default branch"
reset_docs
jq '.required_docs += [{"key":"docs/NEW.md","mandatory_updated":false,"required_sections":[]}]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"
jq '.docs["docs/NEW.md"]="not-needed:x"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"; run_enforce
assert_file_absent "enforce: adding a governed doc is not weakening" "$EMITTED"
reset_docs
echo '{ not json' >"$R/docs/doc-scheme.json"; run_enforce
assert_contains "enforce: a malformed contract is still reported as malformed" "$(cat "$EMITTED")" "malformed"
reset_docs
jq '.enforcement.granularity_levels="abc"' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: a contract the comparison cannot read is not reported as weakened" "$EMITTED"
reset_docs
printf '{ not json' >"$R/docs/doc-scheme.json"; git -C "$R" add docs/doc-scheme.json; git -C "$R" -c user.email=a@b -c user.name=n commit -q -m "break HEAD contract"
git -C "$R" show HEAD:docs/doc-scheme.json >/dev/null
printf '%s' '{"enforcement":{"enabled":false},"required_docs":[{"key":"docs/CHANGELOG.md","required_sections":[]}]}' >"$R/docs/doc-scheme.json"; rm -f "$EMITTED" "$ST"/doc-scheme-baseline-*; run_enforce
assert_file_absent "enforce: a HEAD contract that is not JSON gives nothing to compare with" "$EMITTED"
git -C "$R" checkout -q HEAD~1 -- docs
git -C "$R" -c user.email=a@b -c user.name=n commit -q -m "restore HEAD contract"
git -C "$R" rm -q --cached docs/doc-scheme.md docs/doc-scheme.json; git -C "$R" -c user.email=a@b -c user.name=n commit -q -m untrack
rm -f "$EMITTED" "$R/docs/doc-scheme.md" "$R/docs/doc-scheme.json" "$ST"/doc-scheme-baseline-*; run_enforce
assert_file_absent "enforce: a repo whose scheme git does not track is not governed once the files are gone" "$EMITTED"

# R9-09 (review r1): the baseline is the default branch, so a commit on this branch cannot redefine the contract
gitq() { git -C "$R" -c user.email=a@b -c user.name=n "$@"; }
dirty_log() { echo more >>"$R/docs/CHANGELOG.md"; touch -d "@$NEW" "$R/docs/CHANGELOG.md" "$R/docs/task-doc-checklist.json"; }
fresh_branch_repo() { # a repo whose default branch (origin/main) holds the scheme, with a work branch on top
  setup_repo; git -C "$R" init -q -b main; git -C "$R" add -A; gitq commit -q -m base
  git -C "$R" update-ref refs/remotes/origin/main HEAD
  git -C "$R" checkout -q -b work
}
fresh_branch_repo
assert_eq "baseline: the merge-base with origin/main" "$(git -C "$R" rev-parse origin/main)" "$(sb_doc_scheme__baseline "$R")"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
assert_eq "baseline: origin/HEAD is preferred" "$(git -C "$R" rev-parse origin/main)" "$(sb_doc_scheme__baseline "$R")"
git -C "$R" rm -q --cached docs/CHANGELOG.md; gitq commit -q -m "work commit"
assert_eq "baseline: a commit on the work branch does not move it" "$(git -C "$R" rev-parse origin/main)" "$(sb_doc_scheme__baseline "$R")"
git -C "$R" rm -q docs/doc-scheme.md docs/doc-scheme.json; gitq commit -q -m "delete the scheme"
dirty_log; rm -f "$EMITTED"; run_enforce delivery
assert_contains "enforce: a committed deletion of the scheme is still a gap on delivery (R9-09)" "$(cat "$EMITTED")" "Missing required policy file: docs/doc-scheme.md"
fresh_branch_repo
jq '.enforcement.enabled=false' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; git -C "$R" add -A; gitq commit -q -m "weaken"
dirty_log; rm -f "$EMITTED"; run_enforce delivery
assert_contains "enforce: a committed weakening is a gap on delivery (R9-09)" "$(cat "$EMITTED")" "weakens the contract on the default branch"
for edit in '.required_docs[0].key="docs/OTHER.md"|a governed doc was dropped or renamed' '.required_docs[0].path="docs/ARCH.md"|a governed doc was repointed' '.sync.task_checklist_path="docs/other-checklist.json"|the checklist was repointed' '.sync.doc_scheme_md_path="docs/other.md"|the policy file was repointed'; do
  fresh_branch_repo
  jq "${edit%%|*}" "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; git -C "$R" add -A; gitq commit -q -m "edit"
  dirty_log; rm -f "$EMITTED"; run_enforce delivery
  assert_contains "enforce: ${edit#*|} (committed) is weakening" "$(cat "$EMITTED")" "${edit#*|}"
done
# Sealed baseline (H6 r2): the first use records the baseline commit; moving the default branch onto a later commit
# (git branch -f main HEAD / git update-ref refs/remotes/origin/main HEAD) cannot move it.
rm -f "$ST"/doc-scheme-baseline-*
fresh_branch_repo
SEALED="$(git -C "$R" rev-parse origin/main)"
assert_eq "sealed baseline: first use computes it" "$SEALED" "$(sb_doc_scheme__baseline "$R")"
assert_eq "sealed baseline: and records it in the state dir" "$SEALED" "$(cat "$ST"/doc-scheme-baseline-* | tr -d '\n')"
git -C "$R" rm -q docs/doc-scheme.md docs/doc-scheme.json; gitq commit -q -m "delete the scheme"
git -C "$R" branch -f main HEAD; git -C "$R" update-ref refs/remotes/origin/main HEAD
assert_eq "sealed baseline: git branch -f main HEAD / update-ref origin/main HEAD cannot move it" "$SEALED" "$(sb_doc_scheme__baseline "$R")"
assert_eq "sealed baseline: the repo still counts as governed" "0" "$(sb_doc_scheme__head_tracks "$R" && echo 0 || echo 1)"
dirty_log; rm -f "$EMITTED"; run_enforce delivery
assert_contains "sealed baseline: the deletion is still a gap on delivery after the branch was moved" "$(cat "$EMITTED")" "Missing required policy file: docs/doc-scheme.md"
# a record that is not an ancestor of HEAD (another branch, a rewritten history) or not a commit is ignored and replaced
printf '%s' "0000000000000000000000000000000000000000" >"$(ls "$ST"/doc-scheme-baseline-* | head -1)"
assert_eq "sealed baseline: an unknown commit in the record is recomputed" "$(git -C "$R" merge-base HEAD main)" "$(sb_doc_scheme__baseline "$R")"
printf 'garbage' >"$(ls "$ST"/doc-scheme-baseline-* | head -1)"
assert_eq "sealed baseline: a malformed record is recomputed" "$(git -C "$R" merge-base HEAD main)" "$(sb_doc_scheme__baseline "$R")"
git -C "$R" checkout -q --orphan other; gitq commit -q --allow-empty -m other
assert_eq "sealed baseline: a record that is not an ancestor of HEAD is recomputed" "$(git -C "$R" merge-base HEAD main 2>/dev/null || echo HEAD)" "$(sb_doc_scheme__baseline "$R")"
# a symlinked record is never followed or written through
rm -f "$ST"/doc-scheme-baseline-*; fresh_branch_repo
KEY="$(printf '%s' "$(cd "$R" && pwd -P)" | cksum | cut -d' ' -f1)"
ln -s "$TL_TMP/elsewhere" "$ST/doc-scheme-baseline-$KEY"
sb_doc_scheme__baseline "$R" >/dev/null
assert_file_absent "sealed baseline: nothing is written through a symlinked record" "$TL_TMP/elsewhere"
rm -f "$ST"/doc-scheme-baseline-*
# without origin: the local main is the baseline; with no default branch at all it is HEAD
fresh_branch_repo; git -C "$R" update-ref -d refs/remotes/origin/main
assert_eq "baseline: the local main when there is no origin" "$(git -C "$R" rev-parse main)" "$(sb_doc_scheme__baseline "$R")"
rm -f "$ST"/doc-scheme-baseline-*
git -C "$R" branch -q -m main trunk
assert_eq "baseline: no default branch at all falls back to HEAD" HEAD "$(sb_doc_scheme__baseline "$R")"

# R1-17: a touch is not an update when git can say otherwise
setup_repo
git -C "$R" init -q; git -C "$R" add -A; git -C "$R" -c user.email=a@b -c user.name=n commit -q -m base
FUT=$(( $(date +%s) + 3600 ))
echo "$FUT" >"$ST/session-start-time"
touch -d "@$((FUT + 3600))" "$R/docs/CHANGELOG.md" "$R/docs/ARCH.md" "$R/docs/task-doc-checklist.json"
run_enforce
assert_contains "enforce: a touched doc with no git change is not an update" "$(cat "$EMITTED")" "File marked updated has no change in git since the session started: docs/CHANGELOG.md"
rm -f "$EMITTED"; echo more >>"$R/docs/CHANGELOG.md"; touch -d "@$((FUT + 3600))" "$R/docs/CHANGELOG.md"; run_enforce
assert_file_absent "enforce: an uncommitted change counts as an update" "$EMITTED"
git -C "$R" add -A; git -C "$R" -c user.email=a@b -c user.name=n commit -q -m "update changelog"
echo "$(( $(date +%s) - 60 ))" >"$ST/session-start-time"
touch -d "@$(date +%s)" "$R/docs/CHANGELOG.md" "$R/docs/ARCH.md" "$R/docs/task-doc-checklist.json"
run_enforce
assert_file_absent "enforce: a commit made since the session started counts as an update" "$EMITTED"
setup_repo; run_enforce
assert_file_absent "enforce: outside a git work tree the modification time stands alone" "$EMITTED"

# knowledge / learnings keys with the "current" month, pinned so the test cannot flake at a month boundary
MONTH=2026-03
real_date="$(command -v date)"
tl_stub date "if [[ \"\$1\" == '+%Y-%m' ]]; then echo $MONTH; else exec $real_date \"\$@\"; fi"; hash -r
setup_repo
jq '.required_docs += [{"key":"docs/knowledge/YYYY-MM.md","required_sections":[]},{"key":"docs/learnings/YYYY-MM.md","required_sections":[]}]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"
jq '.docs["docs/knowledge/YYYY-MM.md"]="updated"|.docs["docs/learnings/YYYY-MM.md"]="n/a:none"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"
run_enforce
assert_contains "enforce: monthly doc marked updated but absent" "$(cat "$EMITTED")" "Missing file marked updated: docs/knowledge/$MONTH*.md"
rm -f "$EMITTED"; echo k >"$R/docs/knowledge/$MONTH.md"; touch -d "@$NEW" "$R/docs/knowledge/$MONTH.md"; run_enforce
assert_file_absent "enforce: monthly doc satisfied" "$EMITTED"

rm -f "$TL_BIN/date"; hash -r

# absolute checklist path from the contract
setup_repo; mv "$R/docs/task-doc-checklist.json" "$R/abs-checklist.json"
jq '.sync.task_checklist_path="/abs-checklist.json"' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: absolute checklist path resolved under the repo" "$EMITTED"
setup_repo; mv "$R/docs/task-doc-checklist.json" "$R/docs/custom.json"
jq '.sync.task_checklist_path="docs/custom.json"' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"; run_enforce
assert_file_absent "enforce: relative checklist path from the contract" "$EMITTED"

# blank entries in the contract are skipped
setup_repo
jq '.enforcement.granularity_levels=["",2]|.mandatory_updated_docs=["","docs/CHANGELOG.md"]|.required_docs += [{"key":"","required_sections":[]}]|.required_docs[0].required_sections=["","Added"]' "$R/docs/doc-scheme.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/doc-scheme.json"
run_enforce
assert_file_absent "enforce: blank levels, keys and sections are ignored" "$EMITTED"

# jq failures reading the contract
setup_repo
real_jq="$(command -v jq)"
tl_stub jq "if [[ \"\$*\" == *'task_checklist_path'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
run_enforce
rm -f "$TL_BIN/jq"; hash -r
assert_file_absent "enforce: unreadable checklist path falls back to the default" "$EMITTED"
setup_repo
tl_stub jq "if [[ \"\$*\" == *'.enforcement.enabled'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
run_enforce
rm -f "$TL_BIN/jq"; hash -r
assert_file_absent "enforce: unreadable enabled flag counts as disabled" "$EMITTED"
setup_repo
tl_stub jq "if [[ \"\$*\" == *'.docs[\$k]'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
run_enforce
rm -f "$TL_BIN/jq"; hash -r
assert_contains "enforce: unreadable checklist status counts as missing" "$(cat "$EMITTED")" "Missing checklist entry"
setup_repo
tl_stub jq "if [[ \"\$*\" == *'.sections[\$k]'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
run_enforce
rm -f "$TL_BIN/jq"; hash -r
assert_contains "enforce: unreadable section status counts as missing" "$(cat "$EMITTED")" "Missing section checklist entry"
setup_repo
tl_stub jq "if [[ \"\$*\" == *'granularity_levels'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
run_enforce
rm -f "$TL_BIN/jq"; hash -r
assert_file_absent "enforce: unreadable levels fall back to 2,3" "$EMITTED"

# jq failing while reading required docs / mandatory docs / required sections
jqfail() { tl_stub jq "if [[ \"\$*\" == *'$1'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r; }
jqunstub() { rm -f "$TL_BIN/jq"; hash -r; }
setup_repo; jqfail 'required_docs[]?.key'; run_enforce; jqunstub
assert_contains "enforce: unreadable required_docs => empty-contract issue" "$(cat "$EMITTED")" "required_docs[] is empty"
setup_repo
jq '.docs["docs/CHANGELOG.md"]="not-needed:skip"' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"
jqfail 'mandatory_updated_docs'; run_enforce; jqunstub
assert_file_absent "enforce: unreadable mandatory list enforces nothing mandatory" "$EMITTED"
setup_repo
jq 'del(.sections)' "$R/docs/task-doc-checklist.json" >"$R/c.t" && mv "$R/c.t" "$R/docs/task-doc-checklist.json"; touch -d "@$NEW" "$R/docs/task-doc-checklist.json"
jqfail 'required_sections'; run_enforce; jqunstub
assert_file_absent "enforce: unreadable section list checks no sections" "$EMITTED"

tl_results
