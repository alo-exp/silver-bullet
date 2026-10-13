#!/usr/bin/env bash
# Structural contract for /sb:agent-pi skill and delegate wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-agent-pi/SKILL.md"
WRAPPER="${REPO_ROOT}/scripts/agent-pi-delegate.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== agent-pi skill structural tests ==="

if [[ -f "$SKILL" ]]; then
  check "SKILL.md exists" pass
else
  check "SKILL.md exists" fail
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

grep -qE '^name: silver-agent-pi$' "$SKILL" && check "frontmatter name silver-agent-pi" pass || check "frontmatter name silver-agent-pi" fail
grep -q 'user-invocable: true' "$SKILL" && check "user-invocable" pass || check "user-invocable" fail
grep -q '/sb:agent-pi' "$SKILL" && check "route documented" pass || check "route documented" fail
grep -q 'pi -p' "$SKILL" && check "references pi -p harness" pass || check "references pi -p harness" fail
grep -q 'mimo-v2.5' "$SKILL" && check "documents mimo-v2.5 model policy" pass || check "documents mimo-v2.5 model policy" fail
grep -q 'opencode-go' "$SKILL" && check "documents opencode-go provider" pass || check "documents opencode-go provider" fail
grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$SKILL" && check "excludes matrix env" pass || check "excludes matrix env" fail
grep -q 'agent-pi-delegate.sh' "$SKILL" && check "references delegate wrapper" pass || check "references delegate wrapper" fail
grep -q 'agentmemory' "$SKILL" && check "documents agentmemory capture" pass || check "documents agentmemory capture" fail
grep -q 'graphify' "$SKILL" && check "documents graphify capture" pass || check "documents graphify capture" fail
grep -q 'AF-AGENT-DELEGATE' "$SKILL" && check "documents AF-AGENT-DELEGATE" pass || check "documents AF-AGENT-DELEGATE" fail
grep -q 'SB_AGENT_DELEGATE_V2' "$SKILL" && check "documents V2 default-on flag" pass || check "documents V2 default-on flag" fail
grep -q 'AGENT-DELEGATE' "$SKILL" && check "documents native worker template" pass || check "documents native worker template" fail

[[ -x "$WRAPPER" ]] && check "delegate wrapper executable" pass || check "delegate wrapper executable" fail
grep -q 'tests/live/agents/pi/agent.sh' "$WRAPPER" && check "wrapper uses live agent adapter" pass || check "wrapper uses live agent adapter" fail
grep -q 'agent_preflight' "$WRAPPER" && check "wrapper calls agent_preflight" pass || check "wrapper calls agent_preflight" fail
grep -q 'agent_delegate_canonicalize_path' "$WRAPPER" && check "wrapper canonicalizes log/brief paths" pass || check "wrapper canonicalizes log/brief paths" fail
grep -q 'absolute' "$SKILL" && check "documents absolute path policy" pass || check "documents absolute path policy" fail
grep -q 'AGENT_PI_QUOTA_RETRY' "$WRAPPER" && check "wrapper quota retry env" pass || check "wrapper quota retry env" fail
grep -q 'SB_AGENT_PI_LIGHTWEIGHT' "$WRAPPER" && check "wrapper lightweight env default" pass || check "wrapper lightweight env default" fail
grep -q 'SB_ORCHESTRATOR_WORKER' "$WRAPPER" && check "wrapper orchestrator worker bypass" pass || check "wrapper orchestrator worker bypass" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$WRAPPER" && check "wrapper omits matrix env" pass || check "wrapper omits matrix env" fail
grep -q 'agent_pi_pin_mimo_model_env' "$WRAPPER" && check "wrapper pins mimo model" pass || check "wrapper pins mimo model" fail

LIB="${REPO_ROOT}/scripts/agent-pi/lib.sh"
grep -q 'PI_RUN_TIMEOUT' "$LIB" && check "harness run timeout env" pass || check "harness run timeout env" fail
grep -q 'agent_pi_apply_runtime_env' "$LIB" && check "harness disables RTK for logs" pass || check "harness disables RTK for logs" fail
grep -q 'PI_RUN_TAIL_IDLE_TIMEOUT' "${REPO_ROOT}/tests/live/agents/pi/agent.sh" && check "adapter run tail idle timeout" pass || check "adapter run tail idle timeout" fail

grep -q 'scripts/agent-pi/' "$SKILL" && check "references agent-pi harness dir" pass || check "references agent-pi harness dir" fail
grep -q 'SB_AGENT_PI_LOG_FLOOR' "$SKILL" && check "documents log floor" pass || check "documents log floor" fail
grep -q 'Security (delegation boundary)' "$SKILL" && check "security section" pass || check "security section" fail
grep -q 'E2E-081' "$SKILL" && check "R9 E2E-081 learning" pass || check "R9 E2E-081 learning" fail

AGENT_DIR="${REPO_ROOT}/scripts/agent-pi"
for script in lib.sh env.sh preflight.sh monitor.sh invoke.sh; do
  path="${AGENT_DIR}/${script}"
  if [[ -f "$path" ]]; then
    check "agent-pi/${script} exists" pass
    bash -n "$path" && check "agent-pi/${script} shell syntax" pass || check "agent-pi/${script} shell syntax" fail
  else
    check "agent-pi/${script} exists" fail
  fi
done

bash "${AGENT_DIR}/preflight.sh" --dry-run >/dev/null 2>&1 && check "preflight dry-run" pass || check "preflight dry-run" fail
bash "${AGENT_DIR}/env.sh" >/dev/null 2>&1 && check "env.sh runs" pass || check "env.sh runs" fail
TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/agent-pi-monitor-XXXXXX")"
printf 'Submitted prompt\npi -p\nactivity\n' >"$TMP_LOG"
monitor_out="$(bash "${AGENT_DIR}/monitor.sh" --log "$TMP_LOG" --once 2>/dev/null || true)"
grep -q 'prompt submitted' <<<"$monitor_out" \
  && check "monitor --once smoke" pass || check "monitor --once smoke" fail
rm -f "$TMP_LOG"

grep -q 'agent-pi/invoke' "${REPO_ROOT}/hooks/lib/orchestrator-parent.sh" \
  && check "orchestrator allows invoke.sh" pass || check "orchestrator allows invoke.sh" fail
grep -q 'silver-agent-pi' "${REPO_ROOT}/hooks/lib/orchestrator-parent.sh" \
  && check "orchestrator skill allowlist" pass || check "orchestrator skill allowlist" fail

bash -n "$WRAPPER" && check "wrapper shell syntax" pass || check "wrapper shell syntax" fail

runtime_out="$(
  bash -c '
    set -euo pipefail
    source "'"${REPO_ROOT}"'/scripts/agent-pi/lib.sh"
    unset RTK_DISABLED PI_RUN_TIMEOUT PI_RUN_TAIL_IDLE_TIMEOUT
    agent_pi_apply_runtime_env
    printf "RTK=%s TIMEOUT=%s TAIL=%s PROVIDER=%s MODEL=%s\n" \
      "${RTK_DISABLED:-}" "${PI_RUN_TIMEOUT:-}" \
      "${PI_RUN_TAIL_IDLE_TIMEOUT:-}" "${PI_PROVIDER:-}" "${PI_MODEL:-}"
  '
)"
grep -q 'RTK=1' <<<"$runtime_out" && check "direct path RTK_DISABLED=1" pass || check "direct path RTK_DISABLED=1" fail
grep -q 'PROVIDER=opencode-go' <<<"$runtime_out" && check "direct path provider pin default" pass || check "direct path provider pin default" fail
grep -q 'MODEL=mimo-v2.5' <<<"$runtime_out" && check "direct path model pin default" pass || check "direct path model pin default" fail
grep -q 'agent_pi_apply_runtime_env' "$WRAPPER" \
  && check "delegate calls agent_pi_apply_runtime_env" pass || check "delegate calls agent_pi_apply_runtime_env" fail

# --expect-file --continue fail-fast on 401 / non-zero EXIT
# shellcheck source=scripts/lib/agent-host-exec.sh
source "${REPO_ROOT}/scripts/lib/agent-host-exec.sh"
if agent_host_pi_is_auth_failure 'ERROR: 401 invalid_api_key Missing API key'; then
  check "401 invalid_api_key is auth failure" pass
else
  check "401 invalid_api_key is auth failure" fail
fi
if agent_host_pi_is_auth_failure 'OpenCode: insufficient balance'; then
  check "insufficient balance is auth failure" pass
else
  check "insufficient balance is auth failure" fail
fi
if agent_host_pi_is_auth_failure 'I will write clarifications.md next.'; then
  check "plan-only text is not auth failure" fail
else
  check "plan-only text is not auth failure" pass
fi
if agent_host_pi_should_continue 0 'I will write the output file.'; then
  check "EXIT 0 plan-only may continue" pass
else
  check "EXIT 0 plan-only may continue" fail
fi
if agent_host_pi_should_continue 1 'ERROR: 401 invalid_api_key'; then
  check "EXIT 1 401 must not continue" fail
else
  check "EXIT 1 401 must not continue" pass
fi
if agent_host_pi_should_continue 1 'generic failure without auth'; then
  check "EXIT 1 generic must not continue" fail
else
  check "EXIT 1 generic must not continue" pass
fi
if agent_host_pi_should_continue 0 'HTTP 401 invalid_api_key'; then
  check "EXIT 0 with 401 must not continue" fail
else
  check "EXIT 0 with 401 must not continue" pass
fi
if agent_host_pi_should_continue 124 'zero-byte-idle kill'; then
  check "EXIT 124 idle kill must not continue" fail
else
  check "EXIT 124 idle kill must not continue" pass
fi

hint="$(agent_host_pi_surface_auth_hint 'upstream: insufficient balance on OmniRoute' 2>&1 || true)"
grep -q 'first-hop billing' <<<"$hint" && grep -qi 'insufficient balance' <<<"$hint" \
  && check "surfaces first-hop insufficient balance" pass \
  || check "surfaces first-hop insufficient balance" fail

TMP_PI="$(mktemp -d "${TMPDIR:-/tmp}/agent-pi-invoke-401-XXXXXX")"
trap 'rm -rf "$TMP_PI"' EXIT
FAKE_DELEGATE="${TMP_PI}/delegate.sh"
FAKE_PI="${TMP_PI}/pi"
PI_ARGV_LOG="${TMP_PI}/pi-argv.log"
EXPECT_OUT="${TMP_PI}/work/clarifications.md"
mkdir -p "${TMP_PI}/work"
cat >"$FAKE_DELEGATE" <<'EOF'
#!/usr/bin/env bash
printf 'ERROR: 401 invalid_api_key Missing API key\n' >&2
exit 1
EOF
chmod +x "$FAKE_DELEGATE"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${PI_ARGV_LOG}"
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$EXPECT_OUT" \
      --prompt 'write clarifications.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 1 ]] && check "invoke.sh 401 exits 1" pass || check "invoke.sh 401 exits 1" fail
grep -q 'fail-fast: skipping --continue' <<<"$invoke_out" \
  && check "invoke.sh 401 skips continue" pass || check "invoke.sh 401 skips continue" fail
if [[ -f "$PI_ARGV_LOG" ]] && grep -q -- '--continue' "$PI_ARGV_LOG"; then
  check "invoke.sh 401 does not call pi --continue" fail
else
  check "invoke.sh 401 does not call pi --continue" pass
fi
if grep -q 'fresh pi -p rewrite' <<<"$invoke_out"; then
  check "invoke.sh 401 does not fresh-rewrite" fail
else
  check "invoke.sh 401 does not fresh-rewrite" pass
fi

cat >"$FAKE_DELEGATE" <<'EOF'
#!/usr/bin/env bash
printf 'I will write clarifications.md next.\n'
exit 0
EOF
: >"$PI_ARGV_LOG"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  printf 'ok\n' >"${EXPECT_OUT}"
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    PI_EXPECT_FILE_MIN_BYTES=1 \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$EXPECT_OUT" \
      --prompt 'write clarifications.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 0 ]] && check "invoke.sh EXIT 0 missing file continues" pass \
  || check "invoke.sh EXIT 0 missing file continues" fail
grep -q -- '--continue' "$PI_ARGV_LOG" \
  && check "invoke.sh plan-only calls pi --continue" pass \
  || check "invoke.sh plan-only calls pi --continue" fail
[[ -f "$EXPECT_OUT" ]] && check "invoke.sh continue writes expect-file" pass \
  || check "invoke.sh continue writes expect-file" fail
grep -q -- '--tools' "$PI_ARGV_LOG" && grep -q 'write' "$PI_ARGV_LOG" \
  && check "invoke.sh continue argv includes write tool" pass \
  || check "invoke.sh continue argv includes write tool" fail
grep -q 'write tool' "$PI_ARGV_LOG" \
  && check "invoke.sh continue prompt demands write tool" pass \
  || check "invoke.sh continue prompt demands write tool" fail
if grep -qE "(^|[[:space:]])I will write" "$PI_ARGV_LOG"; then
  check "invoke.sh continue prompt is not a plan sentence" fail
else
  check "invoke.sh continue prompt is not a plan sentence" pass
fi

# plan-only + first continue still missing file → second continue hop writes
rm -f "$EXPECT_OUT"
: >"$PI_ARGV_LOG"
CONT_COUNT_FILE="${TMP_PI}/cont-count"
printf '0\n' >"$CONT_COUNT_FILE"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  n=\$(cat "${CONT_COUNT_FILE}")
  n=\$((n + 1))
  printf '%s\\n' "\$n" >"${CONT_COUNT_FILE}"
  if [[ "\$n" -ge 2 ]]; then
    printf 'ok\\n' >"${EXPECT_OUT}"
  else
    printf 'I will write it next.\\n'
  fi
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    PI_EXPECT_FILE_MIN_BYTES=1 \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$EXPECT_OUT" \
      --prompt 'write clarifications.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 0 ]] && check "invoke.sh second continue writes after first miss" pass \
  || check "invoke.sh second continue writes after first miss" fail
[[ "$(cat "$CONT_COUNT_FILE" | tr -d '[:space:]')" == "2" ]] \
  && check "invoke.sh retries continue when file still missing" pass \
  || check "invoke.sh retries continue when file still missing" fail
[[ -f "$EXPECT_OUT" ]] && check "invoke.sh expect-file exists after second continue" pass \
  || check "invoke.sh expect-file exists after second continue" fail
grep -q 'hop 2/2' <<<"$invoke_out" \
  && check "invoke.sh logs continue hop 2/2" pass \
  || check "invoke.sh logs continue hop 2/2" fail

# plan-only + both continue hops still missing file → EXIT 1
rm -f "$EXPECT_OUT"
: >"$PI_ARGV_LOG"
printf '0\n' >"$CONT_COUNT_FILE"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  n=\$(cat "${CONT_COUNT_FILE}")
  n=\$((n + 1))
  printf '%s\\n' "\$n" >"${CONT_COUNT_FILE}"
  printf 'I will write it next.\\n'
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$EXPECT_OUT" \
      --prompt 'write clarifications.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 1 ]] && check "invoke.sh both continues missing file exits 1" pass \
  || check "invoke.sh both continues missing file exits 1" fail
grep -q 'ERROR: expected file missing, too small, or IN_PROGRESS stub after pi -p' <<<"$invoke_out" \
  && check "invoke.sh both continues missing file errors" pass \
  || check "invoke.sh both continues missing file errors" fail
[[ "$(cat "$CONT_COUNT_FILE" | tr -d '[:space:]')" == "2" ]] \
  && check "invoke.sh both-miss still attempts two continue hops" pass \
  || check "invoke.sh both-miss still attempts two continue hops" fail
grep -q 'fresh pi -p rewrite' <<<"$invoke_out" \
  && check "invoke.sh both-miss then attempts fresh pi -p rewrite" pass \
  || check "invoke.sh both-miss then attempts fresh pi -p rewrite" fail
[[ ! -f "$EXPECT_OUT" ]] && check "invoke.sh both-miss does not create expect-file" pass \
  || check "invoke.sh both-miss does not create expect-file" fail

# plan-only + both continue hops still missing → fresh pi -p (not --continue) writes
rm -f "$EXPECT_OUT"
: >"$PI_ARGV_LOG"
printf '0\n' >"$CONT_COUNT_FILE"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  n=\$(cat "${CONT_COUNT_FILE}")
  n=\$((n + 1))
  printf '%s\\n' "\$n" >"${CONT_COUNT_FILE}"
  printf 'I will write it next.\\n'
else
  printf 'ok\\n' >"${EXPECT_OUT}"
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    PI_PROVIDER=omniroute PI_MODEL='cursor/grok-4.6-high' \
    PI_EXPECT_FILE_MIN_BYTES=1 \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$EXPECT_OUT" \
      --prompt 'UNIQUE_BRIEF_TOKEN write clarifications.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 0 ]] && check "invoke.sh fresh rewrite writes after continue hops miss" pass \
  || check "invoke.sh fresh rewrite writes after continue hops miss" fail
[[ "$(cat "$CONT_COUNT_FILE" | tr -d '[:space:]')" == "2" ]] \
  && check "invoke.sh fresh rewrite still used two continue hops first" pass \
  || check "invoke.sh fresh rewrite still used two continue hops first" fail
[[ -f "$EXPECT_OUT" ]] && check "invoke.sh expect-file exists after fresh rewrite" pass \
  || check "invoke.sh expect-file exists after fresh rewrite" fail
grep -q 'fresh pi -p rewrite' <<<"$invoke_out" \
  && check "invoke.sh logs fresh pi -p rewrite" pass \
  || check "invoke.sh logs fresh pi -p rewrite" fail
grep -q 'not --continue' <<<"$invoke_out" \
  && check "invoke.sh logs rewrite is not --continue" pass \
  || check "invoke.sh logs rewrite is not --continue" fail
compgen -G "${TMP_PI}/work/.pi-fresh-rewrite."* >/dev/null \
  && check "invoke.sh fresh rewrite uses new session dir under work-dir" pass \
  || check "invoke.sh fresh rewrite uses new session dir under work-dir" fail
rewrite_lines="$(grep -vE '(^|[[:space:]])--continue([[:space:]]|$)' "$PI_ARGV_LOG" || true)"
grep -q -- '-p' <<<"$rewrite_lines" \
  && check "invoke.sh rewrite argv is pi -p without --continue" pass \
  || check "invoke.sh rewrite argv is pi -p without --continue" fail
grep -q -- '--session-dir' <<<"$rewrite_lines" \
  && check "invoke.sh rewrite argv sets --session-dir in new work dir" pass \
  || check "invoke.sh rewrite argv sets --session-dir in new work dir" fail
grep -q 'UNIQUE_BRIEF_TOKEN' <<<"$rewrite_lines" \
  && check "invoke.sh rewrite prompt includes original brief" pass \
  || check "invoke.sh rewrite prompt includes original brief" fail
grep -q -- '--tools' <<<"$rewrite_lines" && grep -q 'write' <<<"$rewrite_lines" \
  && check "invoke.sh grok rewrite argv includes write tool" pass \
  || check "invoke.sh grok rewrite argv includes write tool" fail
grep -q -- '--thinking' <<<"$rewrite_lines" \
  && check "invoke.sh grok rewrite keeps thinking-off rails" pass \
  || check "invoke.sh grok rewrite keeps thinking-off rails" fail
p_fresh="$(agent_host_pi_fresh_rewrite_prompt /tmp/review.md 'BRIEF BODY')"
grep -q 'not --continue' <<<"$p_fresh" && grep -q 'BRIEF BODY' <<<"$p_fresh" \
  && check "fresh rewrite prompt carries brief and forbids --continue" pass \
  || check "fresh rewrite prompt carries brief and forbids --continue" fail
if grep -qE '(^|[[:space:]])I will write' <<<"$p_fresh"; then
  check "fresh rewrite prompt is not a plan sentence" fail
else
  check "fresh rewrite prompt is not a plan sentence" pass
fi

# PI_CONTINUE overrides hop-1 prompt; relative expect-file resolves to work-dir
rm -f "$EXPECT_OUT" "${TMP_PI}/work/review.md"
: >"$PI_ARGV_LOG"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  printf 'ok\\n' >"${TMP_PI}/work/review.md"
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    PI_CONTINUE='Call the write tool now to ./review.md' \
    PI_EXPECT_FILE_MIN_BYTES=1 \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file review.md \
      --prompt 'write review.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 0 ]] && check "invoke.sh relative expect-file against work-dir continues" pass \
  || check "invoke.sh relative expect-file against work-dir continues" fail
[[ -f "${TMP_PI}/work/review.md" ]] && check "invoke.sh relative expect-file lands in work-dir" pass \
  || check "invoke.sh relative expect-file lands in work-dir" fail
grep -q 'Call the write tool now to ./review.md' "$PI_ARGV_LOG" \
  && check "invoke.sh PI_CONTINUE overrides hop-1 prompt" pass \
  || check "invoke.sh PI_CONTINUE overrides hop-1 prompt" fail

p1="$(agent_host_pi_continue_prompt /tmp/review.md 1)"
p2="$(agent_host_pi_continue_prompt /tmp/review.md 2)"
grep -q 'write tool' <<<"$p1" && grep -q './review.md' <<<"$p1" \
  && check "continue hop-1 prompt demands write tool" pass \
  || check "continue hop-1 prompt demands write tool" fail
if grep -qE '(^|[[:space:]])I will write' <<<"$p1"; then
  check "continue hop-1 prompt is not a plan sentence" fail
else
  check "continue hop-1 prompt is not a plan sentence" pass
fi
grep -q 'write tool' <<<"$p2" && grep -q 'already failed' <<<"$p2" \
  && check "continue hop-2 prompt retries after plan sentence" pass \
  || check "continue hop-2 prompt retries after plan sentence" fail
p_env="$(PI_CONTINUE='Call the write tool now to custom.md' agent_host_pi_continue_prompt /tmp/review.md 1)"
[[ "$p_env" == 'Call the write tool now to custom.md' ]] \
  && check "PI_CONTINUE env overrides default hop-1 prompt" pass \
  || check "PI_CONTINUE env overrides default hop-1 prompt" fail
grep -q 'IN_PROGRESS stub' <<<"$p1" \
  && check "continue hop-1 prompt names IN_PROGRESS stub" pass \
  || check "continue hop-1 prompt names IN_PROGRESS stub" fail

# Default min 2500 + IN_PROGRESS stub content must not count as done.
pi_write_padded() {
  python3 - "$1" "$2" "${3:-2500}" <<'PY'
import sys
path, body, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
open(path, "w", encoding="utf-8").write(body + ("x" * n))
PY
}
STUB_SMALL="${TMP_PI}/work/stub-small.md"
pi_write_padded "$STUB_SMALL" $'IN_PROGRESS: official report being completed this process after independent re-hash.\nDo not treat this stub as final. Overwrite follows hash + freeze re-audit.\nPlaceholder body so this path exists before independent checks land.\n' 1200
(
  unset PI_EXPECT_FILE_MIN_BYTES
  ! agent_host_pi_file_ok "$STUB_SMALL"
) && check "default min rejects ~1.4KB IN_PROGRESS stub" pass \
  || check "default min rejects ~1.4KB IN_PROGRESS stub" fail
STUB_LARGE="${TMP_PI}/work/stub-large.md"
pi_write_padded "$STUB_LARGE" $'IN_PROGRESS: still writing the official report.\nDo not treat this stub as final.\n' 3000
(
  unset PI_EXPECT_FILE_MIN_BYTES
  agent_host_pi_file_is_stub "$STUB_LARGE" && ! agent_host_pi_file_ok "$STUB_LARGE"
) && check "IN_PROGRESS header rejects even when >=2500 bytes" pass \
  || check "IN_PROGRESS header rejects even when >=2500 bytes" fail
OK_LARGE="${TMP_PI}/work/ok-large.md"
pi_write_padded "$OK_LARGE" $'# verify-2.md\nCLEAN / VERIFY_PASS\n' 2500
(
  unset PI_EXPECT_FILE_MIN_BYTES
  agent_host_pi_file_ok "$OK_LARGE"
) && check "default min accepts >=2500 non-stub file" pass \
  || check "default min accepts >=2500 non-stub file" fail
printf 'ok\n' >"${TMP_PI}/work/tiny-ok.md"
(
  unset PI_EXPECT_FILE_MIN_BYTES
  ! agent_host_pi_file_ok "${TMP_PI}/work/tiny-ok.md"
) && check "default min 2500 rejects 3-byte non-stub file" pass \
  || check "default min 2500 rejects 3-byte non-stub file" fail
(
  PI_EXPECT_FILE_MIN_BYTES=1
  agent_host_pi_file_ok "${TMP_PI}/work/tiny-ok.md"
) && check "PI_EXPECT_FILE_MIN_BYTES=1 still accepts 3-byte non-stub" pass \
  || check "PI_EXPECT_FILE_MIN_BYTES=1 still accepts 3-byte non-stub" fail

# First hop writes IN_PROGRESS stub → continue must still run and overwrite.
STUB_EXPECT="${TMP_PI}/work/verify-2.md"
rm -f "$STUB_EXPECT"
: >"$PI_ARGV_LOG"
cat >"$FAKE_DELEGATE" <<EOF
#!/usr/bin/env bash
python3 - "${STUB_EXPECT}" <<'PY'
import sys
open(sys.argv[1], "w", encoding="utf-8").write(
    "IN_PROGRESS: official report being completed.\\n"
    "Do not treat this stub as final.\\n"
    "Placeholder body so this path exists.\\n"
    + ("x" * 1200)
)
PY
printf 'I will finish verify-2.md next.\\n'
exit 0
EOF
chmod +x "$FAKE_DELEGATE"
cat >"$FAKE_PI" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >>"${PI_ARGV_LOG}"
if printf '%s' "\$*" | grep -qE '(^|[[:space:]])--continue([[:space:]]|$)'; then
  python3 - "${STUB_EXPECT}" <<'PY'
import sys
open(sys.argv[1], "w", encoding="utf-8").write(
    "# verify-2.md\\nCLEAN / VERIFY_PASS\\n" + ("x" * 2500)
)
PY
fi
exit 0
EOF
chmod +x "$FAKE_PI"
set +e
invoke_out="$(
  unset PI_EXPECT_FILE_MIN_BYTES
  SB_AGENT_PI_DELEGATE="$FAKE_DELEGATE" PI_BIN="$FAKE_PI" \
    bash "${AGENT_DIR}/invoke.sh" \
      --work-dir "${TMP_PI}/work" \
      --expect-file "$STUB_EXPECT" \
      --prompt 'write verify-2.md' 2>&1
)"
invoke_rc=$?
set -e
[[ "$invoke_rc" -eq 0 ]] && check "invoke.sh IN_PROGRESS stub continues" pass \
  || check "invoke.sh IN_PROGRESS stub continues" fail
grep -q -- '--continue' "$PI_ARGV_LOG" \
  && check "invoke.sh stub does not skip continue hops" pass \
  || check "invoke.sh stub does not skip continue hops" fail
grep -q 'IN_PROGRESS stub' <<<"$invoke_out" \
  && check "invoke.sh logs stub as reason to continue" pass \
  || check "invoke.sh logs stub as reason to continue" fail
if grep -q '^IN_PROGRESS' "$STUB_EXPECT"; then
  check "invoke.sh continue overwrites IN_PROGRESS stub" fail
else
  check "invoke.sh continue overwrites IN_PROGRESS stub" pass
fi
(
  unset PI_EXPECT_FILE_MIN_BYTES
  agent_host_pi_file_ok "$STUB_EXPECT"
) && check "invoke.sh overwritten stub is file_ok" pass \
  || check "invoke.sh overwritten stub is file_ok" fail

# Qwen/Grok/Claude NI write-first rails (thinking off); MiMo must not get them.
HOSTBIN="${TMP_PI}/host-bin"
mkdir -p "$HOSTBIN"
printf '#!/usr/bin/env bash\nexit 0\n' >"${HOSTBIN}/pi"
chmod +x "${HOSTBIN}/pi"
if (
  export PATH="${HOSTBIN}:$PATH" PI_BIN="${HOSTBIN}/pi" PI_PROVIDER=omniroute PI_MODEL="opencode-go/qwen3.8-max"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi non-interactive "${TMP_PI}/work" "write review.md" permissive
  grep -x -- '--thinking' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- 'off' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- '--no-context-files' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- '--no-skills' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")"
); then
  check "qwen3.8-max NI argv has thinking-off rails" pass
else
  check "qwen3.8-max NI argv has thinking-off rails" fail
fi
if (
  export PATH="${HOSTBIN}:$PATH" PI_BIN="${HOSTBIN}/pi" PI_PROVIDER=omniroute PI_MODEL="cursor/grok-4.6-high"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi non-interactive "${TMP_PI}/work" "write review.md" permissive
  grep -x -- '--thinking' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- 'off' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")"
); then
  check "grok NI argv still has thinking-off rails" pass
else
  check "grok NI argv still has thinking-off rails" fail
fi
if (
  export PATH="${HOSTBIN}:$PATH" PI_BIN="${HOSTBIN}/pi" PI_PROVIDER=omniroute PI_MODEL="claude/claude-opus-5-high"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi non-interactive "${TMP_PI}/work" "write review.md" permissive
  grep -x -- '--thinking' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- 'off' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- '--no-context-files' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -x -- '--no-skills' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")" \
    && grep -F -- 'read,bash,edit,write' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")"
); then
  check "claude/claude-opus-5-high NI argv has thinking-off rails" pass
else
  check "claude/claude-opus-5-high NI argv has thinking-off rails" fail
fi
if (
  export PATH="${HOSTBIN}:$PATH" PI_BIN="${HOSTBIN}/pi" PI_PROVIDER=opencode-go PI_MODEL="mimo-v2.5"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi non-interactive "${TMP_PI}/work" "write review.md" permissive
  ! grep -x -- '--thinking' >/dev/null <<<"$(printf '%s\n' "${AGENT_HOST_ARGV[@]}")"
); then
  check "mimo-v2.5 NI argv has no thinking-off rails" pass
else
  check "mimo-v2.5 NI argv has no thinking-off rails" fail
fi

# Qwen 120s-from-t=0 hang SLA vs Gemini/MiniMax/DeepSeek 600s first-byte window.
# PI_NI_ZERO_BYTE_IDLE_SEC override still wins (keeps the Qwen 124 cases fast).
(
  unset PI_NI_ZERO_BYTE_IDLE_SEC PI_NI_ZERO_BYTE_IDLE_QWEN_SEC PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC
  [[ "$(agent_host_pi_zero_byte_idle_sec 'opencode-go/qwen3.8-max')" == "120" ]]
) && check "qwen first-byte idle default is 120s from t=0" pass \
  || check "qwen first-byte idle default is 120s from t=0" fail
(
  unset PI_NI_ZERO_BYTE_IDLE_SEC PI_NI_ZERO_BYTE_IDLE_QWEN_SEC PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC
  [[ "$(agent_host_pi_zero_byte_idle_sec 'cursor/gemini-3.7-flash-high')" == "600" ]]
) && check "gemini is not on 120s empty-stdout kill (default 600s)" pass \
  || check "gemini is not on 120s empty-stdout kill (default 600s)" fail
(
  unset PI_NI_ZERO_BYTE_IDLE_SEC PI_NI_ZERO_BYTE_IDLE_QWEN_SEC PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC
  [[ "$(agent_host_pi_zero_byte_idle_sec 'minimax-m2.5')" == "600" ]] \
    && [[ "$(agent_host_pi_zero_byte_idle_sec 'deepseek-v3.2')" == "600" ]] \
    && [[ "$(agent_host_pi_zero_byte_idle_sec 'cursor/grok-4.6-high')" == "600" ]]
) && check "minimax/deepseek/grok first-byte idle default is 600s" pass \
  || check "minimax/deepseek/grok first-byte idle default is 600s" fail
(
  unset PI_NI_ZERO_BYTE_IDLE_SEC PI_NI_ZERO_BYTE_IDLE_QWEN_SEC PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC
  [[ "$(agent_host_pi_zero_byte_idle_sec 'claude/claude-opus-5-high')" == "600" ]]
) && check "claude is not on 120s empty-stdout kill (default 600s)" pass \
  || check "claude is not on 120s empty-stdout kill (default 600s)" fail

# Zero-byte idle kill from t=0 for Qwen-class hangs (do not wait ~11 min).
SLEEP_PI="${TMP_PI}/sleep-pi"
cat >"$SLEEP_PI" <<'EOF'
#!/usr/bin/env bash
sleep 30
exit 0
EOF
chmod +x "$SLEEP_PI"
IDLE_EXPECT="${TMP_PI}/work/review-idle.md"
rm -f "$IDLE_EXPECT"
IDLE_START="$(date +%s)"
set +e
(
  export PATH="${HOSTBIN}:$PATH"
  export PI_BIN="$SLEEP_PI"
  export PI_MODEL="opencode-go/qwen3.8-max"
  export PI_NI_ZERO_BYTE_IDLE_SEC=2
  export PI_RUN_TIMEOUT=30
  AGENT_HOST_ARGV=("$SLEEP_PI")
  agent_host_run_pi_until_file "$IDLE_EXPECT"
)
idle_rc=$?
set -e
IDLE_ELAPSED=$(( $(date +%s) - IDLE_START ))
[[ "$idle_rc" -eq 124 ]] && check "qwen zero-byte idle kill exits 124" pass \
  || check "qwen zero-byte idle kill exits 124" fail
[[ "$IDLE_ELAPSED" -lt 15 ]] && check "qwen zero-byte idle kill under 15s (not 11m)" pass \
  || check "qwen zero-byte idle kill under 15s (not 11m)" fail
[[ ! -f "$IDLE_EXPECT" ]] && check "qwen zero-byte idle kill does not write expect-file" pass \
  || check "qwen zero-byte idle kill does not write expect-file" fail

# Gemini silent for a few seconds must not 124 when the 120s Qwen SLA is not in force.
GEMINI_SLEEP_PI="${TMP_PI}/gemini-sleep-pi"
printf '#!/usr/bin/env bash\nsleep 3\nexit 0\n' >"$GEMINI_SLEEP_PI"
chmod +x "$GEMINI_SLEEP_PI"
GEMINI_EXPECT="${TMP_PI}/work/review-gemini-idle.md"
rm -f "$GEMINI_EXPECT"
GEMINI_START="$(date +%s)"
set +e
(
  export PATH="${HOSTBIN}:$PATH"
  export PI_BIN="$GEMINI_SLEEP_PI"
  export PI_MODEL="cursor/gemini-3.7-flash-high"
  unset PI_NI_ZERO_BYTE_IDLE_SEC
  export PI_RUN_TIMEOUT=8
  AGENT_HOST_ARGV=("$GEMINI_SLEEP_PI")
  agent_host_pi_run_argv_zero_byte_guard "$GEMINI_EXPECT"
)
gemini_idle_rc=$?
set -e
GEMINI_ELAPSED=$(( $(date +%s) - GEMINI_START ))
[[ "$gemini_idle_rc" -ne 124 ]] && check "gemini empty stdout under 120s is not idle-killed" pass \
  || check "gemini empty stdout under 120s is not idle-killed" fail
[[ "$GEMINI_ELAPSED" -ge 2 && "$GEMINI_ELAPSED" -lt 15 ]] \
  && check "gemini silent mock reaches natural exit (not 120s Qwen SLA)" pass \
  || check "gemini silent mock reaches natural exit (not 120s Qwen SLA)" fail

# Named OmniRoute Gemini + --expect-file must not fall through to pin_mimo.
GEMINI_PIN_DIR="${TMP_PI}/gemini-pin"
mkdir -p "${GEMINI_PIN_DIR}/work" "${GEMINI_PIN_DIR}/bin"
GEMINI_PIN_EXPECT="${GEMINI_PIN_DIR}/work/review.md"
rm -f "$GEMINI_PIN_EXPECT"
cat >"${GEMINI_PIN_DIR}/bin/pi" <<'EOF'
#!/usr/bin/env bash
sleep 1
exit 0
EOF
chmod +x "${GEMINI_PIN_DIR}/bin/pi"
set +e
gemini_pin_out="$(
  PATH="${GEMINI_PIN_DIR}/bin:$PATH"
  export PI_BIN="${GEMINI_PIN_DIR}/bin/pi"
  export PI_PROVIDER=omniroute
  export PI_MODEL="cursor/gemini-3.7-flash-high"
  bash "${AGENT_DIR}/invoke.sh" \
    --work-dir "${GEMINI_PIN_DIR}/work" \
    --expect-file "$GEMINI_PIN_EXPECT" \
    --prompt 'write review.md' \
    --interaction-mode non-interactive \
    --skip-preflight 2>&1
)"
gemini_pin_rc=$?
set -e
if grep -q 'PI_PROVIDER must be opencode-go' <<<"$gemini_pin_out"; then
  check "gemini expect-file does not fall through to pin_mimo" fail
else
  check "gemini expect-file does not fall through to pin_mimo" pass
fi
[[ "$gemini_pin_rc" -ne 2 ]] && check "gemini expect-file invoke is not pin_mimo EXIT 2" pass \
  || check "gemini expect-file invoke is not pin_mimo EXIT 2" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
