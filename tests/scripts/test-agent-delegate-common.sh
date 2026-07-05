#!/usr/bin/env bash
# Structural tests for scripts/lib/agent-delegate-common.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
CURSOR="${REPO_ROOT}/scripts/agent-cursor-delegate.sh"

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

echo "=== agent-delegate-common structural tests ==="

[[ -f "$COMMON" ]] && check "common lib exists" pass || check "common lib exists" fail

# shellcheck source=../../scripts/lib/agent-delegate-common.sh
source "$COMMON"

# Redaction
redacted="$(agent_delegate_redact_output 'token=sk-abc1234567890 ghp_abcdefghijklmnopqrstuvwxyz')"
! grep -q 'sk-abc' <<<"$redacted" && check "redacts sk-* prefix" pass || check "redacts sk-* prefix" fail
! grep -q 'ghp_abc' <<<"$redacted" && check "redacts ghp_* prefix" pass || check "redacts ghp_* prefix" fail
grep -q 'REDACTED' <<<"$redacted" && check "redaction marker present" pass || check "redaction marker present" fail

# Quota detection
agent_delegate_is_quota_error 'HTTP 429 rate limit' && check "quota error 429" pass || check "quota error 429" fail
! agent_delegate_is_quota_error 'success output' && check "non-quota passes" pass || check "non-quota passes" fail

# Brief secret rejection
agent_delegate_brief_has_secrets 'api_key=foo' && check "brief secret detection" pass || check "brief secret detection" fail
! agent_delegate_brief_has_secrets 'safe brief text' && check "safe brief passes" pass || check "safe brief passes" fail

# Path canonicalization
tmpd="$(mktemp -d)"
rel="${tmpd}/brief.md"
echo 'ok' >"$rel"
canon="$(agent_delegate_canonicalize_path "$rel")"
[[ "$canon" == /* ]] && check "canonicalize to absolute" pass || check "canonicalize to absolute" fail
rm -rf "$tmpd"

# Failure class normalization
[[ "$(agent_delegate_normalize_failure_class 0 '' '')" == "success" ]] && check "failure class success" pass || check "failure class success" fail
[[ "$(agent_delegate_normalize_failure_class 1 '429 quota' '')" == "quota" ]] && check "failure class quota" pass || check "failure class quota" fail

# Exec-mode log append (header preserved, body appended)
append_log="$(mktemp)"
agent_delegate_write_log_header "$append_log" "test-delegate" "/tmp/work" "$REPO_ROOT" 1
agent_delegate_append_invoke_output "$append_log" $'exec stdout line 1\nexec stdout line 2\n'
grep -q 'exec stdout line 1' "$append_log" && grep -q 'test-delegate' "$append_log" && check "append invoke output to log" pass || check "append invoke output to log" fail
rm -f "$append_log"

# Wrapper sourcing
grep -q 'agent-delegate-common.sh' "$CURSOR" && check "cursor sources common lib" pass || check "cursor sources common lib" fail
grep -q 'agent_delegate_clear_matrix_env' "$CURSOR" && check "cursor clears matrix env" pass || check "cursor clears matrix env" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$CURSOR" && check "cursor no inline matrix unset" pass || check "cursor no inline matrix unset" fail

bash -n "$COMMON" && check "common lib shell syntax" pass || check "common lib shell syntax" fail
bash -n "$CURSOR" && check "cursor wrapper shell syntax" pass || check "cursor wrapper shell syntax" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
