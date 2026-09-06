#!/usr/bin/env bash
# Claude/OmniRoute checkpoint-stub idle: a 779-byte "analysis in progress"
# expect-file must not disable the zero-byte guard until PI_RUN_TIMEOUT.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/agent-host-exec.sh
source "${REPO_ROOT}/scripts/lib/agent-host-exec.sh"

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

echo "=== agent-pi Claude/Omni checkpoint-stub idle ==="

SKILL="${REPO_ROOT}/docs/AGENT-PI-OMNIROUTE.md"
grep -q 'PI_NI_ZERO_BYTE_IDLE' "$SKILL" \
  && check "docs document PI_NI_ZERO_BYTE_IDLE" pass \
  || check "docs document PI_NI_ZERO_BYTE_IDLE" fail
grep -q 'checkpoint stub' "$SKILL" \
  && check "docs document checkpoint stub idle" pass \
  || check "docs document checkpoint stub idle" fail
grep -q 'pi-zero-byte-guard.py' "${REPO_ROOT}/scripts/lib/agent-host-exec.sh" \
  && check "agent-host-exec.sh calls pi-zero-byte-guard.py" pass \
  || check "agent-host-exec.sh calls pi-zero-byte-guard.py" fail
bash -n "${REPO_ROOT}/scripts/lib/agent-host-exec.sh" \
  && check "agent-host-exec.sh shell syntax" pass \
  || check "agent-host-exec.sh shell syntax" fail
python3 -m py_compile "${REPO_ROOT}/scripts/lib/pi-zero-byte-guard.py" \
  && check "pi-zero-byte-guard.py compiles" pass \
  || check "pi-zero-byte-guard.py compiles" fail

TMP="$(mktemp -d "${TMPDIR:-/tmp}/agent-pi-claude-idle-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "${TMP}/work" "${TMP}/bin"
HOSTBIN="${TMP}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"${HOSTBIN}/pi"
chmod +x "${HOSTBIN}/pi"

CHECKPOINT=$'# Pi claude/claude-opus-5-xhigh\n\nRFL round 2 — REVIEW-ONLY.\nAll three byte-identical.\nDetailed findings follow below (analysis in progress at this checkpoint; final report replaces this content).\n\nNOT CLEAN\n'
CHECKPOINT_FILE="${TMP}/work/review-checkpoint.md"
printf '%s' "$CHECKPOINT" >"$CHECKPOINT_FILE"
ckpt_bytes="$(wc -c <"$CHECKPOINT_FILE" | tr -d ' ')"
[[ "$ckpt_bytes" -lt 2500 ]] && check "fixture checkpoint is under 2500 bytes ($ckpt_bytes)" pass \
  || check "fixture checkpoint is under 2500 bytes ($ckpt_bytes)" fail

(
  unset PI_EXPECT_FILE_MIN_BYTES
  agent_host_pi_file_is_stub "$CHECKPOINT_FILE"
) && check "checkpoint 'analysis in progress' is a stub" pass \
  || check "checkpoint 'analysis in progress' is a stub" fail

(
  unset PI_EXPECT_FILE_MIN_BYTES
  ! agent_host_pi_file_ok "$CHECKPOINT_FILE"
) && check "checkpoint stub is not file_ok" pass \
  || check "checkpoint stub is not file_ok" fail

PADDED="${TMP}/work/review-checkpoint-padded.md"
python3 - "$CHECKPOINT_FILE" "$PADDED" <<'PY'
import sys
body = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write(body + ("x" * 3000))
PY
(
  unset PI_EXPECT_FILE_MIN_BYTES
  agent_host_pi_file_is_stub "$PADDED" && ! agent_host_pi_file_ok "$PADDED"
) && check "padded checkpoint stub still rejected at >=2500" pass \
  || check "padded checkpoint stub still rejected at >=2500" fail

if (
  export PATH="${HOSTBIN}:$PATH" PI_BIN="${HOSTBIN}/pi" PI_PROVIDER=omniroute PI_MODEL="claude/claude-opus-5-high"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi non-interactive "${TMP}/work" "write review.md" permissive
  printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -x -- '--thinking' >/dev/null \
    && printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -x -- 'off' >/dev/null \
    && printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -x -- '--no-extensions' >/dev/null \
    && printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep 'COMPLETE deliverable' >/dev/null
); then
  check "claude NI argv has thinking-off, --no-extensions, complete-write prompt" pass
else
  check "claude NI argv has thinking-off, --no-extensions, complete-write prompt" fail
fi

SLEEP_PI="${TMP}/sleep-pi"
cat >"$SLEEP_PI" <<'EOF'
#!/usr/bin/env bash
sleep 30
exit 0
EOF
chmod +x "$SLEEP_PI"

STALL_EXPECT="${TMP}/work/review-stall.md"
cp "$CHECKPOINT_FILE" "$STALL_EXPECT"
STALL_START="$(date +%s)"
set +e
(
  export PATH="${HOSTBIN}:$PATH"
  export PI_BIN="$SLEEP_PI"
  export PI_MODEL="claude/claude-opus-5-high"
  export PI_NI_ZERO_BYTE_IDLE_SEC=2
  export PI_RUN_TIMEOUT=30
  unset PI_EXPECT_FILE_MIN_BYTES
  AGENT_HOST_ARGV=("$SLEEP_PI")
  agent_host_run_pi_until_file "$STALL_EXPECT"
)
stall_rc=$?
set -e
STALL_ELAPSED=$(( $(date +%s) - STALL_START ))
[[ "$stall_rc" -eq 124 ]] && check "checkpoint stub idle kill exits 124" pass \
  || check "checkpoint stub idle kill exits 124" fail
[[ "$STALL_ELAPSED" -lt 15 ]] && check "checkpoint stub idle kill under 15s (not hard 30s)" pass \
  || check "checkpoint stub idle kill under 15s (not hard 30s)" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
