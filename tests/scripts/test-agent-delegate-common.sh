#!/usr/bin/env bash
# Structural tests for scripts/lib/agent-delegate-common.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
CODEX="${REPO_ROOT}/scripts/agent-codex-delegate.sh"
CURSOR="${REPO_ROOT}/scripts/agent-cursor-delegate.sh"
CLAUDE="${REPO_ROOT}/scripts/agent-claude-delegate.sh"

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

# Redaction — build fake tokens without contiguous secret literals (gitleaks-safe)
fake_sk="$(printf '%s-%s' 'sk' 'abc1234567890')"
fake_ghp="$(printf '%s%s' 'ghp_' 'abcdefghijklmnopqrstuvwxyz')"
redacted="$(agent_delegate_redact_output "token=${fake_sk} ${fake_ghp}")"
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

# Workdir evidence append
evidence_dir="$(mktemp -d)"
git -C "$evidence_dir" init -q
git -C "$evidence_dir" config user.email "test@local"
git -C "$evidence_dir" config user.name "Test"
echo 'marker' >"${evidence_dir}/README.md"
git -C "$evidence_dir" add README.md
git -C "$evidence_dir" commit -q -m 'test commit'
evidence_log="$(mktemp)"
agent_delegate_append_workdir_evidence "$evidence_log" "$evidence_dir" 'test prompt'
grep -q '=== workdir evidence ===' "$evidence_log" && check "workdir evidence section" pass || check "workdir evidence section" fail
grep -q 'git_head=' "$evidence_log" && check "workdir evidence git head" pass || check "workdir evidence git head" fail
grep -q 'test commit' "$evidence_log" && check "workdir evidence git log" pass || check "workdir evidence git log" fail
rm -f "$evidence_log"
rm -rf "$evidence_dir"

# Wrapper sourcing
grep -q 'agent-delegate-common.sh' "$CODEX" && check "codex sources common lib" pass || check "codex sources common lib" fail
grep -q 'agent-delegate-common.sh' "$CURSOR" && check "cursor sources common lib" pass || check "cursor sources common lib" fail
grep -q 'agent_delegate_clear_matrix_env' "$CODEX" && check "codex clears matrix env" pass || check "codex clears matrix env" fail
grep -q 'agent_delegate_clear_matrix_env' "$CURSOR" && check "cursor clears matrix env" pass || check "cursor clears matrix env" fail
grep -q 'agent-delegate-common.sh' "$CLAUDE" && check "claude sources common lib" pass || check "claude sources common lib" fail
grep -q 'agent_delegate_clear_matrix_env' "$CLAUDE" && check "claude clears matrix env" pass || check "claude clears matrix env" fail
grep -q 'SB_AGENT_CLAUDE_LOG_FLOOR' "$CLAUDE" && check "claude log floor env" pass || check "claude log floor env" fail
grep -q 'agent_delegate_append_invoke_output' "$CLAUDE" && check "claude print log append" pass || check "claude print log append" fail
grep -q 'SB_AGENT_CODEX_LOG_FLOOR' "$CODEX" && check "codex log floor env" pass || check "codex log floor env" fail
grep -q 'agent_delegate_append_invoke_output' "$CODEX" && check "codex exec log append" pass || check "codex exec log append" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$CODEX" && check "codex no inline matrix unset" pass || check "codex no inline matrix unset" fail

grep -q 'SB_AGENT_CERT_RUN' "$COMMON" && check "cert run bypass in common lib" pass || check "cert run bypass in common lib" fail
grep -q 'cert-bypass.sh' "$REPO_ROOT/hooks/graphify-gate.sh" && check "graphify gate sources cert-bypass" pass || check "graphify gate sources cert-bypass" fail

bash -n "$COMMON" && check "common lib shell syntax" pass || check "common lib shell syntax" fail
bash -n "$CODEX" && check "codex wrapper shell syntax" pass || check "codex wrapper shell syntax" fail
bash -n "$CURSOR" && check "cursor wrapper shell syntax" pass || check "cursor wrapper shell syntax" fail
bash -n "$CLAUDE" && check "claude wrapper shell syntax" pass || check "claude wrapper shell syntax" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
