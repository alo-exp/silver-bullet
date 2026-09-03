#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/silver-scan.sh"
PASS=0
FAIL=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF -- "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $path"
    (( FAIL++ )) || true
  fi
}

assert_json_eq() {
  local desc="$1" json="$2" expr="$3" expected="$4"
  local actual
  actual="$(jq -r "$expr" <<<"$json")"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    (( FAIL++ )) || true
  fi
}

make_workspace() {
  WORKDIR="$(mktemp -d)"
  mkdir -p "$WORKDIR/docs/sessions" "$WORKDIR/docs/issues" "$WORKDIR/docs/knowledge" "$WORKDIR/docs/learnings"
  cat > "$WORKDIR/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  _LEGACY_TRACKER=$(printf '%s%s' gs d)
  cat > "$WORKDIR/.silver-bullet.json" <<EOF
{
  "project": {
    "name": "scan-test",
    "active_workflow": "full-dev-cycle"
  },
  "issue_tracker": "${_LEGACY_TRACKER}"
}
EOF
  mkdir -p "$WORKDIR/.silver-bullet"
}

run_scan() {
  local mode="${1:-interactive}"
  ( cd "$WORKDIR" && "$SCRIPT" scan --mode "$mode" --format json )
}

run_file() {
  local candidate_id="$1"
  ( cd "$WORKDIR" && "$SCRIPT" file --candidate-id "$candidate_id" --format json )
}

run_record() {
  local candidate_id="$1"
  ( cd "$WORKDIR" && "$SCRIPT" record --candidate-id "$candidate_id" --format json )
}

cleanup() {
  rm -rf "${WORKDIR:-}"
  rm -rf "${FAKE_BIN:-}"
}
trap cleanup EXIT

echo "=== silver-scan helper tests ==="

make_workspace

scan="$(run_scan interactive)"
assert_json_eq "no-session summary uses zero scans" "$scan" '.summary.sessions_scanned' '0'
assert_json_eq "no-session summary has no candidates" "$scan" '.summary.total_candidates' '0'

rm -rf "$WORKDIR"
make_workspace
cat > "$WORKDIR/docs/sessions/2026-05-12-alpha.md" <<'EOF'
# Session Log — Alpha

## Needs human review

- Investigate flaky CI on release branch

## Knowledge & Learnings additions

- Atomic tmpfile+mv keeps JSON writes safe.
EOF
cat > "$WORKDIR/docs/sessions/2026-05-13-beta.md" <<'EOF'
# Session Log — Beta

## Needs human review

- Investigate flaky CI on release branch

## Autonomous decisions

- Defer polishing the empty state copy until after content model stabilizes.
EOF
cat > "$WORKDIR/docs/sessions/2026-05-14-gamma.md" <<'EOF'
# Session Log — Gamma

## Needs human review

- Fix failing integration test for session scan
EOF

scan="$(run_scan interactive)"
assert_json_eq "duplicate filtering collapses repeated candidate" "$scan" '.summary.duplicates_filtered' '2'
assert_json_eq "first scan found four unique candidates" "$scan" '.summary.total_candidates' '4'

candidate_bug="$(jq -r '.candidates[] | select(.kind=="deferred") | .candidate_id' <<<"$scan" | head -n 1)"
candidate_knowledge="$(jq -r '.candidates[] | select(.kind=="knowledge") | .candidate_id' <<<"$scan" | head -n 1)"

file_result="$(run_file "$candidate_bug")"
record_result="$(run_record "$candidate_knowledge")"
assert_json_eq "issue filing recorded as filed" "$file_result" '.candidate.status' 'filed'
assert_json_eq "knowledge capture recorded as recorded" "$record_result" '.candidate.status' 'recorded'

scan_again="$(run_scan interactive)"
assert_json_eq "second scan skips already-scanned sessions" "$scan_again" '.summary.sessions_skipped_already_scanned' '3'
assert_json_eq "second scan has no remaining candidates" "$scan_again" '.summary.total_candidates' '0'

rm -rf "$WORKDIR"
make_workspace
cat > "$WORKDIR/docs/sessions/2026-05-15-local.md" <<'EOF'
# Session Log — Local tracker

## Needs human review

- Fix broken release note generation

## Autonomous decisions

- Update the installation docs before releasing the next cut.
EOF

scan="$(run_scan interactive)"
bug_candidate="$(jq -r '.candidates[] | select(.category=="bug") | .candidate_id' <<<"$scan" | head -n 1)"
docs_candidate="$(jq -r '.candidates[] | select(.category=="docs") | .candidate_id' <<<"$scan" | head -n 1)"

bug_filed="$(run_file "$bug_candidate")"
docs_filed="$(run_file "$docs_candidate")"
assert_file_exists "local issue tracker file created" "$WORKDIR/docs/issues/ISSUES.md"
assert_file_exists "local backlog file created" "$WORKDIR/docs/issues/BACKLOG.md"
assert_file_contains "bug entry appended to issues" "$WORKDIR/docs/issues/ISSUES.md" "Fix broken release note generation"
assert_file_contains "docs entry appended to backlog" "$WORKDIR/docs/issues/BACKLOG.md" "Update the installation docs before releasing the next cut."
assert_json_eq "local bug filed" "$bug_filed" '.candidate.status' 'filed'
assert_json_eq "local docs filed" "$docs_filed" '.candidate.status' 'filed'

rm -rf "$WORKDIR"
make_workspace
FAKE_RUNTIME="$(mktemp -d)"
mkdir -p "$FAKE_RUNTIME/sessions/index" "$FAKE_RUNTIME/projects/active" "$FAKE_RUNTIME/sessions/archived"

cat > "$FAKE_RUNTIME/projects/active/matched.jsonl" <<EOF
{"payload":{"cwd":"$WORKDIR"},"message":{"content":"## Needs human review\n\n- Fix active transcript scan coverage"}}
EOF
cat > "$FAKE_RUNTIME/sessions/archived/matched-archived.jsonl" <<EOF
{"payload":{"git_project_root":"$WORKDIR"},"message":{"content":"## Needs human review\n\n- Fix archived transcript scan coverage"}}
EOF
cat > "$FAKE_RUNTIME/projects/active/deleted.jsonl" <<EOF
{"payload":{"cwd":"$WORKDIR"},"message":{"content":"## Needs human review\n\n- Deleted sessions should not scan"}}
EOF
cat > "$FAKE_RUNTIME/projects/active/unmatched.jsonl" <<'EOF'
{"payload":{"cwd":"/tmp/not-this-project"},"message":{"content":"## Needs human review\n\n- Ignore another project"}}
EOF
cat > "$FAKE_RUNTIME/sessions/index/catalog.jsonl" <<EOF
{"rollout_path":"$FAKE_RUNTIME/projects/active/matched.jsonl","payload":{"cwd":"$WORKDIR"}}
{"rollout_path":"$FAKE_RUNTIME/projects/active/deleted.jsonl","payload":{"cwd":"$WORKDIR"},"deleted":true}
{"rollout_path":"$FAKE_RUNTIME/projects/active/unmatched.jsonl","payload":{"cwd":"/tmp/not-this-project"}}
EOF

preflight="$(cd "$WORKDIR" && KAY_HOME="$FAKE_RUNTIME" "$SCRIPT" scan --agent-env kay --preflight --format json)"
assert_json_eq "preflight selected explicit kay env" "$preflight" '.preflight.selected_agent_env' 'kay'
assert_json_eq "preflight skipped deleted catalog row" "$preflight" '.preflight.deleted_skipped_count' '1'
assert_json_eq "preflight counted one archived source" "$preflight" '.preflight.source_counts.archived' '1'
assert_json_eq "preflight reports no candidates" "$preflight" '.candidates | length' '0'
if [[ ! -f "$WORKDIR/.silver-bullet/scan-state.json" ]]; then
  echo "PASS: preflight has no scan-state side effects"
  (( PASS++ )) || true
else
  echo "FAIL: preflight created scan-state"
  (( FAIL++ )) || true
fi

scan="$(cd "$WORKDIR" && KAY_HOME="$FAKE_RUNTIME" "$SCRIPT" scan --agent-env kay --format json)"
assert_json_eq "scan saw explicit kay env" "$scan" '.preflight.selected_agent_env' 'kay'
assert_json_eq "scan found active and archived candidates" "$scan" '.summary.total_candidates' '2'
assert_json_eq "scan kept deleted transcript out" "$scan" '[.candidates[].title | contains("Deleted sessions should not scan")] | any' 'false'

rm -rf "$WORKDIR" "$FAKE_RUNTIME"
make_workspace
FAKE_BIN="$(mktemp -d)"
cat > "$FAKE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GH_LOG_FILE}"
case "$1 $2" in
  "label create") printf 'label-created\n' ;;
  "issue create") printf 'https://github.com/alo-exp/silver-bullet/issues/999\n' ;;
  "issue list") printf '[]\n' ;;
  *) printf 'ok\n' ;;
esac
EOF
chmod +x "$FAKE_BIN/gh"
export PATH="$FAKE_BIN:$PATH"
export GH_LOG_FILE="$WORKDIR/gh.log"

cat > "$WORKDIR/.silver-bullet.json" <<'EOF'
{
  "project": {
    "name": "scan-test",
    "active_workflow": "full-dev-cycle"
  },
  "issue_tracker": "github"
}
EOF
cat > "$WORKDIR/docs/sessions/2026-05-16-github.md" <<'EOF'
# Session Log — GitHub

## Needs human review

- Fix failing GitHub issue filing path for silver scan
EOF

scan="$(run_scan autonomous)"
assert_json_eq "autonomous scan auto-files the issue" "$scan" '.summary.auto_filed' '1'
assert_file_contains "gh issue create invoked" "$WORKDIR/gh.log" "issue create"
assert_file_contains "gh issue create carries filed-by-silver-bullet" "$WORKDIR/gh.log" "filed-by-silver-bullet"
assert_file_contains "gh issue create carries bug label" "$WORKDIR/gh.log" "--label bug"
assert_file_contains "gh issue create body references session source" "$WORKDIR/gh.log" "docs/sessions/2026-05-16-github.md"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
