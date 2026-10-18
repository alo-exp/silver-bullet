# shellcheck shell=bash
# Helpers for the agent-* live-harness tests (delegates, pi invoke, autonomous driver).
# Everything here is sandbox-only: the "host adapter" is a scripted stub and host CLIs are
# recording stubs. Source after tests/lib/testlib.sh and tl_init.

# alh_stage_sb DIR HOST: stage an SB root whose tests/live/agents/HOST/agent.sh is a scripted stub.
#
# The stub records to $ALH_RECORD, counts invocations in $ALH_COUNT and plays one
# "rc|text" line per attempt from $ALH_SCRIPT (the last line repeats). Environment
# variables named in $ALH_ENV_KEYS are written to the record on every invoke.
# ALH_WRITE_LOG=text appends text to $CLAUDE_INTERACTIVE_LOG_FILE (adapter that writes the TUI log).
# ALH_TERM_SELF=1 makes the stub send SIGTERM to its own subshell ($BASHPID) mid-invoke.
# ALH_RM_WORKDIR=1 makes the stub delete $WORK_DIR (adapter that cleans up after itself).
# ALH_RM_LOG=1 makes the stub delete $CLAUDE_INTERACTIVE_LOG_FILE (adapter that loses the log).
alh_stage_sb() {
  local sb="$1" host="$2"
  mkdir -p "$sb/tests/live/agents/$host"
  cat >"$sb/tests/live/agents/$host/agent.sh" <<'EOF'
agent_preflight() {
  printf 'preflight\n' >>"$ALH_RECORD"
}
agent_invoke() {
  local n key line rc text
  n=$(( $(cat "$ALH_COUNT" 2>/dev/null || echo 0) + 1 ))
  printf '%s' "$n" >"$ALH_COUNT"
  printf 'invoke n=%s mode=%s prompt=%s\n' "$n" "$1" "$2" >>"$ALH_RECORD"
  for key in ${ALH_ENV_KEYS:-}; do
    printf 'env %s=%s\n' "$key" "${!key-<unset>}" >>"$ALH_RECORD"
  done
  if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
    printf 'config-dir-present %s\n' "$([[ -d "$CLAUDE_CONFIG_DIR" ]] && echo yes || echo no)" >>"$ALH_RECORD"
    printf 'config-trust-present %s\n' "$([[ -f "$CLAUDE_CONFIG_DIR/.claude.json" ]] && echo yes || echo no)" >>"$ALH_RECORD"
  fi
  line="$(sed -n "${n}p" "$ALH_SCRIPT")"
  [[ -n "$line" ]] || line="$(tail -n 1 "$ALH_SCRIPT")"
  rc="${line%%|*}"
  text="${line#*|}"
  if [[ -n "${ALH_WRITE_LOG:-}" ]]; then
    printf '%s' "$ALH_WRITE_LOG" >>"${CLAUDE_INTERACTIVE_LOG_FILE:?}"
  fi
  if [[ "${ALH_RM_LOG:-}" == "1" ]]; then
    rm -f "${CLAUDE_INTERACTIVE_LOG_FILE:-}"
  fi
  if [[ "${ALH_TERM_SELF:-}" == "1" ]]; then
    kill -TERM "$BASHPID"
  fi
  if [[ "${ALH_RM_WORKDIR:-}" == "1" ]]; then
    rm -rf "${WORK_DIR:?}"
  fi
  printf '%b' "$text"
  return "$rc"
}
EOF
}

# alh_script LINE...: write the per-attempt "rc|text" script and reset record/count.
alh_script() {
  : >"$ALH_RECORD"
  rm -f "$ALH_COUNT"
  printf '%s\n' "$@" >"$ALH_SCRIPT"
}

# alh_attempts: number of times the stub adapter was invoked.
alh_attempts() {
  cat "$ALH_COUNT" 2>/dev/null || echo 0
}

# alh_rec: the stub's record.
alh_rec() {
  cat "$ALH_RECORD"
}

# alh_env KEY: value recorded for KEY on the last invoke ("" when never recorded).
alh_env() {
  { grep "^env $1=" "$ALH_RECORD" || true; } | tail -1 | sed "s/^env $1=//"
}
