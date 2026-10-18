#!/usr/bin/env bash
# Behavior of scripts/lib/agent-delegate-common.sh: quota retry limits, pinned NI exec, prompt
# resolution, log/evidence helpers, failure classification and the recommended-tools preflight.
# The library is staged with stub collaborators (quota resolver, enterprise preflight, guard).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

ST="$TL_TMP/stage"
k2_stage_agent_lib "$ST"
export FAKE_LOG="$TL_TMP/fake.log"; : >"$FAKE_LOG"
# shellcheck source=/dev/null
source "$ST/scripts/lib/agent-delegate-common.sh"

# ---------------- quota retry max ----------------
unset SB_AM_QUOTA_RETRY SB_AM_CONCRETE_PIN SB_AM_RESOLVED MY_MAX CLAUDE_MODEL CLAUDE_EFFORT CLAUDE_PRINT_VERBOSE PI_PROVIDER PI_MODEL \
  SB_AGENT_EXPECT_FILE PI_EXPECT_FILE SB_AGENT_CERT_RUN SB_AGENT_SKIP_PREFLIGHT
assert_eq "retry max: default (not pinned)" "5" "$(agent_delegate_quota_retry_max MY_MAX)"
assert_eq "retry max: explicit default" "9" "$(agent_delegate_quota_retry_max MY_MAX 9)"
assert_eq "retry max: env wins" "2" "$(MY_MAX=2 agent_delegate_quota_retry_max MY_MAX 9)"
assert_eq "retry max: quota-retry flag uses default" "5" "$(SB_AM_QUOTA_RETRY=1 agent_delegate_quota_retry_max MY_MAX)"
assert_eq "retry max: quota-retry flag honors env" "3" "$(SB_AM_QUOTA_RETRY=1 MY_MAX=3 agent_delegate_quota_retry_max MY_MAX)"
assert_eq "retry max: pinned NI defaults to 0" "0" "$(SB_AM_CONCRETE_PIN=1 SB_AM_RESOLVED=non-interactive agent_delegate_quota_retry_max MY_MAX)"
assert_eq "retry max: pinned NI honors env" "4" "$(SB_AM_CONCRETE_PIN=1 SB_AM_RESOLVED=non-interactive MY_MAX=4 agent_delegate_quota_retry_max MY_MAX)"
assert_eq "retry max: pinned interactive uses default" "5" "$(SB_AM_CONCRETE_PIN=1 SB_AM_RESOLVED=interactive agent_delegate_quota_retry_max MY_MAX)"
SB_AM_CONCRETE_PIN=1 SB_AM_RESOLVED=non-interactive agent_delegate_is_pinned_ni && tl_pass "pinned NI detected" || tl_fail "pinned NI detected"
agent_delegate_is_pinned_ni && tl_fail "not pinned by default" || tl_pass "not pinned by default"

# ---------------- exec_pinned_ni ----------------
STUBS="$TL_TMP/stubs"; mkdir -p "$STUBS" "$TL_TMP/w"
printf '#!/usr/bin/env bash\necho "claude-ran cwd=$PWD args=$*"\nexit 11\n' >"$STUBS/claude"; chmod +x "$STUBS/claude"
tl_stub pi 'echo "PI $*" >>"$FAKE_LOG"; exit 0'
pinned() { # <env...> -- args : run exec_pinned_ni in a throwaway shell (it may exec)
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  tl_run env "${envs[@]}" bash -c 'source "$1"; shift; shopt -s execfail; agent_delegate_exec_pinned_ni "$@"' _ "$ST/scripts/lib/agent-delegate-common.sh" "$@"
}
pinned X=1 -- bogus "$TL_TMP/w" prompt
assert_eq "pinned: unresolvable host returns 3" 3 "$TL_STATUS"
assert_contains "pinned: mode-unavailable reported" "$TL_ERR" "ERROR: mode-unavailable"
pinned CLAUDE_BIN="$STUBS/claude" -- claude "$TL_TMP/no-such" prompt
assert_eq "pinned: missing work dir returns 1" 1 "$TL_STATUS"
pinned CLAUDE_BIN="$STUBS/claude" SB_AGENT_HOST_ARGV_FILE="$TL_TMP/argv.txt" -- claude "$TL_TMP/w" "go go" strict
assert_eq "pinned: exec hands over to the CLI (its exit status)" 11 "$TL_STATUS"
assert_contains "pinned: ran in work dir with strict permission" "$TL_OUT" "claude-ran cwd=$TL_TMP/w args=--print --model sonnet --effort low --permission-mode acceptEdits --verbose go go"
assert_contains "pinned: argv dumped" "$(cat "$TL_TMP/argv.txt")" "go go"
printf '#!/nonexistent/interpreter\n' >"$STUBS/claude"
pinned CLAUDE_BIN="$STUBS/claude" -- claude "$TL_TMP/w" "go"
assert_eq "pinned: exec failure returns 3" 3 "$TL_STATUS"
assert_contains "pinned: exec failure reported" "$TL_ERR" "ERROR: mode-unavailable"
: >"$FAKE_LOG"
pinned PI_EXPECT_FILE="$TL_TMP/expect.md" GUARD_PLAN=4 FAKE_LOG="$FAKE_LOG" -- pi "$TL_TMP/w" "pi prompt"
assert_eq "pinned: pi with expect file returns guard status, no exec" 4 "$TL_STATUS"
assert_contains "pinned: guard got the expect file and argv" "$(cat "$FAKE_LOG")" "expect=$TL_TMP/expect.md"
assert_contains "pinned: guard ran in the work dir" "$(cat "$FAKE_LOG")" "cwd=$TL_TMP/w"
: >"$FAKE_LOG"
pinned FAKE_LOG="$FAKE_LOG" -- pi "$TL_TMP/w" "plain pi"
assert_eq "pinned: pi without expect file execs the CLI" 0 "$TL_STATUS"
assert_contains "pinned: direct pi argv" "$(cat "$FAKE_LOG")" "PI -p --provider opencode-go --model mimo-v2.5 plain pi"

# ---------------- canonicalize / matrix env ----------------
assert_eq "canonicalize: empty prints nothing" "" "$(agent_delegate_canonicalize_path "")"
assert_eq "canonicalize: absolute unchanged" "/a/b.md" "$(agent_delegate_canonicalize_path /a/b.md)"
echo x >"$TL_TMP/w/rel.md"
assert_eq "canonicalize: relative made absolute" "$TL_TMP/w/rel.md" "$(cd "$TL_TMP/w" && agent_delegate_canonicalize_path rel.md)"
export SB_E2E_ENTERPRISE_MATRIX=1 SB_E2E_LEDGER_FILE=x SB_E2E_MATRIX_BATCH_PID=1 SB_E2E_MATRIX_FORCE=1 SB_E2E_MATRIX_MONITOR_PID_FILE=x \
  SB_E2E_MATRIX_MONITOR_STATUS_FILE=x SB_E2E_TUI_FINDINGS=x SB_E2E_TUI_OFFSETS=x SB_E2E_LIVE_TEST_LOCK_FILE=x KEEP_ME=1
agent_delegate_clear_matrix_env
left=""
for v in SB_E2E_ENTERPRISE_MATRIX SB_E2E_LEDGER_FILE SB_E2E_MATRIX_BATCH_PID SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_MONITOR_PID_FILE \
  SB_E2E_MATRIX_MONITOR_STATUS_FILE SB_E2E_TUI_FINDINGS SB_E2E_TUI_OFFSETS SB_E2E_LIVE_TEST_LOCK_FILE; do
  [[ -z "${!v+x}" ]] || left="$left $v"
done
assert_eq "clear matrix env: all matrix vars unset" "" "$left"
assert_eq "clear matrix env: unrelated vars kept" "1" "${KEEP_ME}"

# an env var that cannot be unset does not abort the cleanup
tl_run bash -c "source '$ST/scripts/lib/agent-delegate-common.sh'; export SB_E2E_LEDGER_FILE=x SB_E2E_TUI_OFFSETS=y; readonly SB_E2E_LEDGER_FILE; agent_delegate_clear_matrix_env; echo rc=\$? ledger=\${SB_E2E_LEDGER_FILE:-unset} offsets=\${SB_E2E_TUI_OFFSETS:-unset}"
assert_contains "clear matrix env: readonly var tolerated, others still cleared" "$TL_OUT" "rc=0 ledger=x offsets=unset"

# ---------------- quota detection / short-retry gate ----------------
agent_delegate_is_quota_error "Token Plan exhausted" && tl_pass "quota: token plan" || tl_fail "quota: token plan"
agent_delegate_is_quota_error "all fine" && tl_fail "quota: clean output" || tl_pass "quota: clean output is not quota"

cat >"$ST/scripts/review-fix-ladder.py" <<'PY'
import json, os, sys
if os.environ.get("RESOLVER_FAIL"):
    sys.exit(2)
print(os.environ.get("RESOLVER_JSON", "{}"))
PY
blocks() { if RESOLVER_JSON="$1" agent_delegate_quota_blocks_short_retry "blob" 2>/dev/null; then echo yes; else echo no; fi; }
assert_eq "short-retry blocked when resolver says should_short_retry=false" yes "$(blocks '{"should_short_retry": false}')"
assert_eq "short-retry allowed when true" no "$(blocks '{"should_short_retry": true}')"
assert_eq "short-retry allowed when field missing" no "$(blocks '{}')"
assert_eq "short-retry allowed when resolver fails" no "$(RESOLVER_FAIL=1 blocks '{"should_short_retry": false}')"
assert_eq "short-retry allowed when json garbled" no "$(blocks 'not json')"
mv "$ST/scripts/review-fix-ladder.py" "$ST/scripts/rfl.bak"
assert_eq "short-retry allowed when resolver missing" no "$(blocks '{"should_short_retry": false}')"
mv "$ST/scripts/rfl.bak" "$ST/scripts/review-fix-ladder.py"

# ---------------- redaction ----------------
fake_sk="$(printf '%s-%s' 'sk' 'abc1234567890')"
fake_ghp="$(printf '%s%s' 'ghp_' 'abcdefghijklmnopqrstuvwxyz')"
out="$(agent_delegate_redact_output "Authorization: Bearer hunter2 password = swordfish ${fake_sk} ${fake_ghp} keep")"
assert_contains "redact: key/value patterns" "$out" "Authorization=[REDACTED]"
assert_contains "redact: sk key" "$out" "sk-[REDACTED]"
assert_contains "redact: ghp token" "$out" "ghp_[REDACTED]"
assert_not_contains "redact: secret value gone" "$out" "swordfish"
assert_contains "redact: plain text kept" "$out" "keep"
agent_delegate_redact_log_file "$TL_TMP/nolog"
assert_file_absent "redact file: missing file stays missing" "$TL_TMP/nolog"
printf 'token=abc123\nok line\n' >"$TL_TMP/log.txt"
agent_delegate_redact_log_file "$TL_TMP/log.txt"
assert_eq "redact file: rewritten in place" "token=[REDACTED]
ok line" "$(cat "$TL_TMP/log.txt")"

# ---------------- resolve_prompt ----------------
tl_run agent_delegate_resolve_prompt "$TL_TMP/nobrief" "" ""
assert_eq "prompt: missing brief file" 2 "$TL_STATUS"
assert_contains "prompt: missing brief message" "$TL_ERR" "brief file not found"
printf 'do the thing\n' >"$TL_TMP/brief.md"
tl_run agent_delegate_resolve_prompt "$TL_TMP/brief.md" "$TL_TMP/ignored" "ignored"
assert_eq "prompt: brief wins" "do the thing" "$TL_OUT"
printf 'api_key: hunter2\n' >"$TL_TMP/secret.md"
tl_run agent_delegate_resolve_prompt "$TL_TMP/secret.md" "" ""
assert_eq "prompt: secret in brief" 2 "$TL_STATUS"
assert_contains "prompt: secret in brief message" "$TL_ERR" "brief contains secret patterns"
tl_run agent_delegate_resolve_prompt "" "$TL_TMP/nofile" ""
assert_eq "prompt: missing prompt file" 2 "$TL_STATUS"
assert_contains "prompt: missing prompt file message" "$TL_ERR" "prompt file not found"
tl_run agent_delegate_resolve_prompt "" "$TL_TMP/brief.md" "ignored"
assert_eq "prompt: prompt file used" "do the thing" "$TL_OUT"
tl_run agent_delegate_resolve_prompt "" "$TL_TMP/secret.md" ""
assert_eq "prompt: secret in prompt file" 2 "$TL_STATUS"
assert_contains "prompt: secret in prompt file message" "$TL_ERR" "prompt file contains secret patterns"
tl_run agent_delegate_resolve_prompt "" "" "inline prompt"
assert_eq "prompt: inline text" "inline prompt" "$TL_OUT"
tl_run agent_delegate_resolve_prompt "" "" "password: x"
assert_eq "prompt: secret inline" 2 "$TL_STATUS"
assert_contains "prompt: secret inline message" "$TL_ERR" "prompt contains secret patterns"
tl_run agent_delegate_resolve_prompt "" "" ""
assert_eq "prompt: nothing provided" 2 "$TL_STATUS"
assert_contains "prompt: nothing provided message" "$TL_ERR" "provide --prompt, --prompt-file, or --brief-file"
agent_delegate_brief_has_secrets "x ${fake_sk}" && tl_pass "secrets: sk key" || tl_fail "secrets: sk key"
agent_delegate_brief_has_secrets "x ${fake_ghp}" && tl_pass "secrets: ghp token" || tl_fail "secrets: ghp token"

# ---------------- work dir ----------------
tl_run agent_delegate_validate_work_dir ""
assert_eq "work dir: empty rejected" 2 "$TL_STATUS"
assert_contains "work dir: message" "$TL_ERR" "--work-dir must point to an existing directory"
tl_run agent_delegate_validate_work_dir "$TL_TMP/w"
assert_eq "work dir: existing accepted" 0 "$TL_STATUS"
tl_run agent_delegate_resolve_work_dir "$TL_TMP/nonexistent"
assert_eq "resolve work dir: missing rejected" 2 "$TL_STATUS"
tl_run bash -c "cd '$TL_TMP' && source '$ST/scripts/lib/agent-delegate-common.sh' && agent_delegate_resolve_work_dir w"
assert_eq "resolve work dir: made absolute" "$TL_TMP/w" "$TL_OUT"

# ---------------- log header / footer / append ----------------
LOG="$TL_TMP/logs/run.log"
agent_delegate_write_log_header "" host "$TL_TMP/w" /sb 1
agent_delegate_write_log_header "$LOG" "claude-delegate" "$TL_TMP/w" /sb 2 "extra=1"
assert_contains "header: banner" "$(cat "$LOG")" "=== claude-delegate "
assert_contains "header: fields" "$(cat "$LOG")" "work_dir=$TL_TMP/w
sb_root=/sb
attempt=2"
assert_contains "header: extra line" "$(cat "$LOG")" "extra=1"
agent_delegate_write_log_footer "$TL_TMP/logs/missing.log" 0 1 host
assert_file_absent "footer: missing log not created" "$TL_TMP/logs/missing.log"
agent_delegate_write_log_footer "" 0 1 host
agent_delegate_write_log_footer "$LOG" 3 2 "claude-delegate"
assert_contains "footer: completion line" "$(cat "$LOG")" "=== claude-delegate complete exit=3 attempt=2 ==="
agent_delegate_append_invoke_output "" "x"
agent_delegate_append_invoke_output "$LOG" ""
agent_delegate_append_invoke_output "$LOG" "INVOKE-OUTPUT"
assert_contains "append output: appended" "$(cat "$LOG")" "INVOKE-OUTPUT"
FB="$TL_TMP/logs/fallback.log"
agent_delegate_write_fallback_log "" h /w /sb 1 0 "out"
agent_delegate_write_fallback_log "$FB" "host" "$TL_TMP/w" /sb 3 7 "secret=abc tail"
assert_contains "fallback log: exit and attempt" "$(cat "$FB")" "attempt=3
exit=7"
assert_contains "fallback log: output redacted" "$(cat "$FB")" "secret=[REDACTED] tail"

# ---------------- workdir evidence ----------------
EV="$TL_TMP/logs/evidence.log"
agent_delegate_append_workdir_evidence "" "$TL_TMP/w"
agent_delegate_append_workdir_evidence "$EV" "$TL_TMP/nonexistent"
assert_file_absent "evidence: missing work dir writes nothing" "$EV"
agent_delegate_append_workdir_evidence "$EV" "$TL_TMP/w" "hello"
assert_contains "evidence: non-repo" "$(cat "$EV")" "git=not-a-repo"
assert_contains "evidence: prompt bytes" "$(cat "$EV")" "prompt_bytes=5"
assert_contains "evidence: directory listing" "$(cat "$EV")" "rel.md"
REPO="$TL_TMP/repo"; tl_git_repo "$REPO"
printf '# Title\nline2\n' >"$REPO/README.md"; echo dirty >"$REPO/untracked.txt"
EV2="$TL_TMP/logs/evidence2.log"
agent_delegate_append_workdir_evidence "$EV2" "$REPO"
assert_contains "evidence: git head" "$(cat "$EV2")" "git_head="
assert_contains "evidence: last commit" "$(cat "$EV2")" "init"
assert_contains "evidence: status shows untracked" "$(cat "$EV2")" "?? untracked.txt"
assert_contains "evidence: file list" "$(cat "$EV2")" "$REPO/README.md"
assert_contains "evidence: readme preview" "$(cat "$EV2")" "readme_preview=
# Title"
assert_not_contains "evidence: no prompt bytes when no prompt" "$(cat "$EV2")" "prompt_bytes"
REPO2="$TL_TMP/repo2"; tl_git_repo "$REPO2"
EV3="$TL_TMP/logs/evidence3.log"
agent_delegate_append_workdir_evidence "$EV3" "$REPO2"
assert_not_contains "evidence: no readme section without README" "$(cat "$EV3")" "readme_preview"

# every probe failing is tolerated and recorded as best-effort evidence
REPO3="$TL_TMP/repo3"; tl_git_repo "$REPO3"
printf '# R\n' >"$REPO3/README.md"
git() { case "$*" in *"rev-parse HEAD"*|*"log -3"*|*" status "*) return 1 ;; esac; command git "$@"; }
head() { case "$*" in *-20*|*README*) return 1 ;; esac; command head "$@"; }
EV4="$TL_TMP/logs/evidence4.log"
rc=0; agent_delegate_append_workdir_evidence "$EV4" "$REPO3" || rc=$?
unset -f git head
assert_eq "evidence: failing probes do not fail the helper" 0 "$rc"
assert_contains "evidence: head falls back to none" "$(cat "$EV4")" "git_head=none"
assert_contains "evidence: sections still emitted" "$(cat "$EV4")" "readme_preview="
ls() { return 1; }
EV5="$TL_TMP/logs/evidence5.log"
rc=0; agent_delegate_append_workdir_evidence "$EV5" "$TL_TMP/w" || rc=$?
unset -f ls
assert_eq "evidence: failing ls tolerated" 0 "$rc"
assert_contains "evidence: non-repo marker still written" "$(cat "$EV5")" "git=not-a-repo"
# ---------------- log floor / workflow markers ----------------
printf '%0100d' 0 >"$TL_TMP/floor.log"
tl_run agent_delegate_check_log_floor "" 10 host
assert_eq "floor: no log passes" 0 "$TL_STATUS"
tl_run agent_delegate_check_log_floor "$TL_TMP/floor.log" 50 host
assert_eq "floor: above floor passes" 0 "$TL_STATUS"
assert_contains "floor: size reported" "$TL_ERR" "[host] log: $TL_TMP/floor.log (100 B)"
tl_run agent_delegate_check_log_floor "$TL_TMP/floor.log" 500 host
assert_eq "floor: below floor fails" 1 "$TL_STATUS"
assert_contains "floor: failure class reported" "$TL_ERR" "log below floor (100 B < 500 B) — failure_class=log-floor"

unset SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS
printf 'nothing here\n' >"$TL_TMP/mk.log"
tl_run agent_delegate_check_workflow_markers "$TL_TMP/mk.log" host
assert_eq "markers: disabled by default" 0 "$TL_STATUS"
export SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1
tl_run agent_delegate_check_workflow_markers "$TL_TMP/nolog" host
assert_eq "markers: missing log passes" 0 "$TL_STATUS"
tl_run agent_delegate_check_workflow_markers "$TL_TMP/mk.log" host
assert_eq "markers: no activity fails" 1 "$TL_STATUS"
assert_contains "markers: failure class" "$TL_ERR" "failure_class=no-workflow-markers"
printf 'used 1234 tokens\n' >"$TL_TMP/mk.log"
tl_run agent_delegate_check_workflow_markers "$TL_TMP/mk.log" host
assert_eq "markers: token counter passes" 0 "$TL_STATUS"
printf 'Bash(ls)\n' >"$TL_TMP/mk.log"
tl_run agent_delegate_check_workflow_markers "$TL_TMP/mk.log" host
assert_eq "markers: tool activity passes" 0 "$TL_STATUS"
printf 'used 0 tokens\n' >"$TL_TMP/mk.log"
tl_run agent_delegate_check_workflow_markers "$TL_TMP/mk.log" host
assert_eq "markers: zero tokens is not activity" 1 "$TL_STATUS"
unset SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS

# ---------------- result skeleton / state marker / degraded evidence ----------------
agent_delegate_write_result_skeleton "" h t 0
agent_delegate_write_result_skeleton "$TL_TMP/res/RESULT.md" "codex" "task-9" 4
assert_contains "skeleton: fields" "$(cat "$TL_TMP/res/RESULT.md")" "| host | codex |"
assert_contains "skeleton: task and exit" "$(cat "$TL_TMP/res/RESULT.md")" "| task_id | task-9 |
| exit_code | 4 |"
assert_contains "skeleton: pending audit status" "$(cat "$TL_TMP/res/RESULT.md")" "## STATUS
pending-audit"
agent_delegate_write_state_marker "" h t 0 ok
agent_delegate_write_state_marker "$TL_TMP/marker" "cursor" "t-1" 3 "quota"
assert_eq "state marker: json fields" "cursor|t-1|3|quota" "$(jq -r '[.host,.task_id,.exit_code,.failure_class]|join("|")' "$TL_TMP/marker/state.json")"
agent_delegate_write_degraded_fallback_evidence "" h t trig why
agent_delegate_write_degraded_fallback_evidence "$TL_TMP/deg" "codex" "t-2" "quota" 'said "no"'
agent_delegate_write_degraded_fallback_evidence "$TL_TMP/deg" "codex" "t-3" "quota" 'again'
assert_eq "degraded evidence: two jsonl records" 2 "$(wc -l <"$TL_TMP/deg/degraded-fallback.jsonl" | tr -d ' ')"
assert_eq "degraded evidence: record fields and escaped quotes" "EV-DELEGATE-DEGRADED-FALLBACK|codex|quota|t-2|said \"no\"" \
  "$(head -1 "$TL_TMP/deg/degraded-fallback.jsonl" | jq -r '[.evidence_id,.host,.trigger,.task_id,.reason]|join("|")')"

# ---------------- failure class ----------------
fc() { SB_AM_FAILURE_CLASS="${FC_PRE:-}" agent_delegate_normalize_failure_class "$@"; }
assert_eq "class: preset class wins" "custom" "$(FC_PRE=custom fc 1 "x")"
assert_eq "class: success" "success" "$(fc 0 "anything")"
assert_eq "class: mode-unavailable" "mode-unavailable" "$(fc 3 "ERROR: mode-unavailable")"
assert_eq "class: mode-conflict" "mode-conflict" "$(fc 2 "ERROR: mode-conflict (x)")"
assert_eq "class: escalate-unavailable" "escalate-unavailable" "$(fc 3 "escalate-unavailable")"
assert_eq "class: max-turns" "max-turns" "$(fc 1 "hit max-turns")"
assert_eq "class: hook-trust" "hook-trust" "$(fc 1 "needs hook-trust")"
assert_eq "class: quota" "quota" "$(fc 1 "HTTP 429")"
printf 'tiny' >"$TL_TMP/tiny.log"
assert_eq "class: log floor (default 512)" "log-floor" "$(fc 1 "boom" "$TL_TMP/tiny.log")"
assert_eq "class: log floor via SB_AGENT_DELEGATE_LOG_FLOOR" "delegate-failure" "$(SB_AGENT_DELEGATE_LOG_FLOOR=2 fc 1 "boom" "$TL_TMP/tiny.log")"
assert_eq "class: codex floor overrides" "log-floor" "$(SB_AGENT_CODEX_LOG_FLOOR=100 SB_AGENT_DELEGATE_LOG_FLOOR=2 fc 1 "boom" "$TL_TMP/tiny.log")"
assert_eq "class: missing log file falls through" "delegate-failure" "$(fc 1 "boom" "$TL_TMP/nolog")"
assert_eq "class: generic failure" "delegate-failure" "$(fc 1 "boom")"

# ---------------- preflight ----------------
SBR="$TL_TMP/sbroot"; mkdir -p "$SBR/scripts/enterprise-e2e/lib"
cat >"$SBR/scripts/enterprise-e2e/lib/core.sh" <<EOS
enterprise_e2e_code_intel_preflight() {
  echo "preflight sb=\$1 work=\$2 flag=\$3 runtime=\${SILVER_BULLET_RUNTIME:-} host=\${SB_RUNTIME_HOST:-}" >>"$TL_TMP/pre.log"
  [[ -z "\${PRE_FAIL:-}" ]]
}
sb_agentmemory_record_usage() {
  echo "record \$1" >>"$TL_TMP/pre.log"
  [[ -z "\${REC_FAIL:-}" ]]
}
EOS
PW="$TL_TMP/pw"; mkdir -p "$PW"
pre() { # [env...] -- args
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$TL_TMP/pre.log"
  tl_run env "${envs[@]}" bash -c 'source "$1"; shift; eval "${SETUP:-:}"; agent_delegate_preflight_recommended_tools "$@"' _ "$ST/scripts/lib/agent-delegate-common.sh" "$@"
}
pre SETUP='SB_AM_SKIP_PREFLIGHT=1' -- "$PW" "$SBR" claude
assert_eq "preflight: SB_AM_SKIP_PREFLIGHT skips" "" "$(cat "$TL_TMP/pre.log")"
assert_eq "preflight: skip returns 0" 0 "$TL_STATUS"
pre SB_AGENT_SKIP_PREFLIGHT=1 -- "$PW" "$SBR" claude
assert_eq "preflight: SB_AGENT_SKIP_PREFLIGHT skips" "" "$(cat "$TL_TMP/pre.log")"
pre SETUP='SB_AM_CONCRETE_PIN=1; SB_AM_RESOLVED=non-interactive' -- "$PW" "$SBR" claude
assert_eq "preflight: pinned NI skips" "" "$(cat "$TL_TMP/pre.log")"
pre SB_AGENT_CERT_RUN=1 -- "$PW" "$SBR" claude
assert_eq "preflight: cert run (1) skips" "" "$(cat "$TL_TMP/pre.log")"
pre SB_AGENT_CERT_RUN=true -- "$PW" "$SBR" claude
assert_eq "preflight: cert run (true) skips" "" "$(cat "$TL_TMP/pre.log")"
mkdir -p "$PW/.silver-bullet"; : >"$PW/.silver-bullet/agent-cert-run"
pre X=1 -- "$PW" "$SBR" claude
assert_eq "preflight: cert marker file skips" "" "$(cat "$TL_TMP/pre.log")"
rm -rf "$PW/.silver-bullet"
pre X=1 -- "" "$SBR" claude
assert_eq "preflight: empty work dir is a no-op" 0 "$TL_STATUS"
assert_eq "preflight: empty work dir runs nothing" "" "$(cat "$TL_TMP/pre.log")"
pre X=1 -- "$PW" "$TL_TMP/nosb" claude
assert_eq "preflight: missing sb root is a no-op" "" "$(cat "$TL_TMP/pre.log")"
pre X=1 -- "$PW" "" claude
assert_eq "preflight: empty sb root is a no-op" 0 "$TL_STATUS"
mkdir -p "$TL_TMP/emptysb"
pre X=1 -- "$PW" "$TL_TMP/emptysb" claude
assert_eq "preflight: missing core lib warns and passes" 0 "$TL_STATUS"
assert_contains "preflight: warning text" "$TL_ERR" "WARN: missing enterprise preflight lib at $TL_TMP/emptysb/scripts/enterprise-e2e/lib/core.sh"
pre X=1 -- "$PW" "$SBR" codex
assert_eq "preflight: success" 0 "$TL_STATUS"
assert_eq "preflight: runs with host runtime and no config record" "preflight sb=$SBR work=$PW flag=0 runtime=codex host=codex" "$(cat "$TL_TMP/pre.log")"
pre PRE_FAIL=1 -- "$PW" "$SBR" cursor
assert_eq "preflight: failure returns 1" 1 "$TL_STATUS"
assert_contains "preflight: failure message" "$TL_ERR" "ERROR: recommended-tools preflight failed (host=cursor work_dir=$PW)"
echo '{}' >"$PW/.silver-bullet.json"
pre X=1 -- "$PW" "$SBR"
assert_eq "preflight: default host claude + usage recorded" "preflight sb=$SBR work=$PW flag=0 runtime=claude host=claude
record $PW/.silver-bullet.json" "$(cat "$TL_TMP/pre.log")"
pre REC_FAIL=1 -- "$PW" "$SBR" claude
assert_eq "preflight: usage recording failure is tolerated" 0 "$TL_STATUS"

tl_results
