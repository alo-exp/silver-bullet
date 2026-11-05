#!/usr/bin/env bash
# hooks/pr-traceability.sh: PR body update, SPEC.md bookkeeping and degradation paths.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/pr-traceability.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
mkdir -p "$EC_PROJ/.planning"
PR_URL="https://example.test/o/r/pull/7"
export TL_TMP_EDIT="$TL_TMP/edited.md" TL_TMP_EDIT_ARGS="$TL_TMP/edit.args" TL_TMP_PRURL="$PR_URL" TL_TMP_BODY="existing body"

tl_stub gh '
case "$*" in
  "pr view --json url --jq .url") printf "%s" "$TL_TMP_PRURL" ;;
  "pr view --json body --jq .body") printf "%s" "$TL_TMP_BODY" ;;
  "pr edit "*) printf "%s\n" "$*" >"$TL_TMP_EDIT_ARGS"; cp "${@: -1}" "$TL_TMP_EDIT" ;;
esac'

PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title x"}}'
run_hook() { # [payload] [hook]
  local payload="${1:-$PAYLOAD}" hook="${2:-$HOOK}"
  tl_run_stdin "$payload" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$hook"
}
reset() {
  rm -f "${TL_TMP_EDIT:?}" "${TL_TMP_EDIT_ARGS:?}" "${SD:?}/spec-session" "${EC_PROJ:?}/.planning/SPEC.md" "${EC_PROJ:?}/.planning/VALIDATION.md"
  printf 'spec-version=1.2.3\njira-id=PROJ-12\n' >"$SD/spec-session"
}

# ---- gating -----------------------------------------------------------------
reset
run_hook '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
assert_eq "non-shell tool ignored" "" "$TL_OUT"
run_hook '{"tool_name":"Bash","tool_input":{"command":"gh pr list"}}'
assert_eq "other gh command ignored" "" "$TL_OUT"
rm -f "$SD/spec-session"
run_hook
assert_eq "no spec session: silent" "" "$TL_OUT"
assert_file_absent "no spec session: PR untouched" "$TL_TMP_EDIT"
reset
PATH="$(tl_path_without jq)" run_hook
assert_contains "jq missing: visible warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
mkdir -p "$TL_TMP/outside"
rm -f "${SD:?}/project-root"
tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$TL_TMP/outside" "$HOOK"
assert_eq "outside an SB project: silent" "" "$TL_OUT"

# ---- successful update ------------------------------------------------------
reset
printf 'FINDING [WARN] <b>bold</b> & `tick`\nFINDING [FAIL] ignored\n' >"$EC_PROJ/.planning/VALIDATION.md"
cat >"$EC_PROJ/.planning/SPEC.md" <<'EOF'
# Spec
<!-- Populated automatically by the hook -->

## Acceptance Criteria
EOF
run_hook
assert_contains "success message" "$TL_OUT" "Spec traceability added to PR description."
body="$(cat "$TL_TMP_EDIT")"
assert_contains "existing body preserved" "$body" "existing body"
assert_contains "spec version" "$body" "(v1.2.3)"
assert_contains "jira id" "$body" "- JIRA: PROJ-12"
assert_contains "WARN finding listed" "$body" "FINDING [WARN]"
assert_contains "HTML escaped" "$body" "&lt;b&gt;bold&lt;/b&gt; &amp; tick"
assert_not_contains "FAIL finding excluded" "$body" "FINDING [FAIL]"
assert_not_contains "backticks stripped from warnings" "$body" '`tick`'
assert_contains "edit targets the PR url" "$(cat "$TL_TMP_EDIT_ARGS")" "pr edit $PR_URL --body-file"
spec="$(cat "$EC_PROJ/.planning/SPEC.md")"
assert_contains "SPEC.md gains the PR entry" "$spec" "- PR: $PR_URL | Date: $(date '+%Y-%m-%d') | Spec-version: 1.2.3"
assert_file_absent "SPEC temp file removed" "$EC_PROJ/.planning/SPEC.md.tmp"
run_hook
assert_eq "SPEC.md entry inserted only once" "1" "$(grep -cF "$PR_URL" "$EC_PROJ/.planning/SPEC.md")"

# No VALIDATION.md: None placeholder; invalid session values degrade
reset
printf 'spec-version=abc\njira-id=bad\n' >"$SD/spec-session"
run_hook
body="$(cat "$TL_TMP_EDIT")"
assert_contains "invalid version becomes unknown" "$body" "(vunknown)"
assert_contains "invalid jira id becomes n/a" "$body" "- JIRA: n/a"
assert_contains "no validation file: None" "$body" '```
None
```'
assert_file_absent "no SPEC.md: none created" "$EC_PROJ/.planning/SPEC.md"

# gh edit failure is tolerated
tl_stub gh '
case "$*" in
  "pr view --json url --jq .url") printf "%s" "$TL_TMP_PRURL" ;;
  "pr view --json body --jq .body") exit 1 ;;
  "pr edit "*) exit 1 ;;
esac'
reset
run_hook
assert_contains "gh failures tolerated" "$TL_OUT" "Spec traceability added"

# ---- degradation ------------------------------------------------------------
tl_stub gh 'exit 0'
reset
run_hook
assert_contains "no PR url: skipped with warning" "$TL_OUT" "Could not determine PR URL"
rm -f "${TL_BIN:?}/gh"
reset
# The hook also probes /opt/homebrew/bin/gh and /usr/local/bin/gh by absolute path, so
# hiding gh from PATH is not enough: shadow `command -v` for gh in the hook's environment.
command() {
  if [[ "${1:-}" == "-v" ]]; then
    case "${2:-}" in gh|/opt/homebrew/bin/gh|/usr/local/bin/gh) return 1 ;; esac
  fi
  builtin command "$@"
}
export -f command
run_hook
unset -f command
assert_contains "gh missing everywhere: warning" "$TL_OUT" "gh CLI not found"

# ---- library fallbacks ------------------------------------------------------
ec_stage_hooks "$TL_TMP/farm" tool-input.sh nofollow-guard.sh jq-gate.sh
tl_stub gh '
case "$*" in
  "pr view --json url --jq .url") printf "%s" "$TL_TMP_PRURL" ;;
  "pr view --json body --jq .body") printf "%s" "$TL_TMP_BODY" ;;
  "pr edit "*) cp "${@: -1}" "$TL_TMP_EDIT" ;;
esac'
reset
run_hook '{}' "$TL_TMP/farm/hooks/pr-traceability.sh"
assert_eq "no tool-input lib: empty payload is ignored" "" "$TL_OUT"
run_hook "$PAYLOAD" "$TL_TMP/farm/hooks/pr-traceability.sh"
assert_contains "fallback jq extraction handles gh pr create" "$TL_OUT" "Spec traceability added"
run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$TL_TMP/farm/hooks/pr-traceability.sh"
assert_eq "fallback jq extraction ignores other commands" "" "$TL_OUT"
ec_stage_hooks "$TL_TMP/farm2" -
reset
run_hook "$PAYLOAD" "$TL_TMP/farm2/hooks/pr-traceability.sh"
assert_contains "no lib directory at all: still works" "$TL_OUT" "Spec traceability added"

tl_results
