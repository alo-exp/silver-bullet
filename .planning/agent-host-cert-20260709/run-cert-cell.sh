#!/usr/bin/env bash
# Run one 5×3 agent-host cert cell and write result.md
set -euo pipefail

SB_ROOT="${SB_ROOT:-/Users/shafqat/projects/silver-bullet/repo}"
BASELINE=8482e60cdea0f8d4a8a5c37f1e93cd527ff412fa
export PATH="${HOME}/.opencode/bin:${PATH}"

# Cert cells run worker CLIs in test-app worktrees — avoid five-tool double-compression deadlocks.
export SB_ORCHESTRATOR_WORKER=1
export SB_ORCHESTRATOR_PARENT=0
export RTK_DISABLED=1
export SB_AGENT_CERT_RUN=1
export LEANCTX_SB_ROUTED_MODE=0
export CONTEXT_MODE_HOOKS_ACTIVE=0
export CLAUDE_LIVE_TIMEOUT=900
export CLAUDE_INTERACTIVE_TIMEOUT=900
export CODEX_EXEC_TIMEOUT=900
export CODEX_INTERACTIVE_TIMEOUT=900
export CLAUDE_PERMISSION_MODE=bypassPermissions
export SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=0

usage() {
  cat <<'EOF'
Usage: run-cert-cell.sh <CELL>

CELL examples: C1 C2 C5 L1 L2 L3 L4 X1 X2 X3 X5
EOF
}

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
CELL="$1"

case "$CELL" in
  C1) PARENT=cursor WORKER=cursor APP=cursor AGENT=agent-cursor FLOOR=2048 LOGNAME=cursor-run.log USE_PRINT=0 USE_EXEC=0 ;;
  C2) PARENT=cursor WORKER=claude APP=claude AGENT=agent-claude FLOOR=512 LOGNAME=claude-run.log USE_PRINT=1 USE_EXEC=0 ;;
  C3) echo "C3 already PASS — skip"; exit 0 ;;
  C4) echo "C4 already PASS — skip"; exit 0 ;;
  C5) PARENT=cursor WORKER=pi APP=pi AGENT=agent-pi FLOOR=512 LOGNAME=pi-run.log USE_PRINT=0 USE_EXEC=0 ;;
  L1) PARENT=claude WORKER=cursor APP=cursor AGENT=agent-cursor FLOOR=2048 LOGNAME=cursor-run.log PARENT_AGENT=agent-claude WORKER_DIRECT=1 ;;
  L2) PARENT=claude WORKER=claude APP=claude AGENT=agent-claude FLOOR=512 LOGNAME=claude-run.log PARENT_AGENT=agent-claude DIRECT_CHILD=1 USE_PRINT=1 ;;
  L3) PARENT=claude WORKER=codex APP=codex AGENT=agent-codex FLOOR=512 LOGNAME=codex-run.log PARENT_AGENT=agent-claude WORKER_DIRECT=1 USE_EXEC=1 ;;
  L4) PARENT=claude WORKER=opencode APP=opencode AGENT=agent-opencode FLOOR=512 LOGNAME=opencode-run.log PARENT_AGENT=agent-claude WORKER_DIRECT=1 ;;
  L5) echo "L5 already PASS — skip"; exit 0 ;;
  X1) PARENT=codex WORKER=cursor APP=cursor AGENT=agent-cursor FLOOR=2048 LOGNAME=cursor-run.log PARENT_AGENT=agent-codex WORKER_DIRECT=1 ;;
  X2) PARENT=codex WORKER=claude APP=claude AGENT=agent-claude FLOOR=512 LOGNAME=claude-run.log PARENT_AGENT=agent-codex WORKER_DIRECT=1 USE_PRINT=1 ;;
  X3) PARENT=codex WORKER=codex APP=codex AGENT=agent-codex FLOOR=512 LOGNAME=codex-run.log PARENT_AGENT=agent-codex DIRECT_CHILD=1 USE_EXEC=1 ;;
  X4) echo "X4 already PASS — skip"; exit 0 ;;
  X5) PARENT=codex WORKER=pi APP=pi AGENT=agent-pi FLOOR=512 LOGNAME=pi-run.log PARENT_AGENT=agent-codex WORKER_DIRECT=1 ;;
  *) printf 'Unknown cell: %s\n' "$CELL" >&2; exit 2 ;;
esac

WORK_DIR="/Users/shafqat/projects/enterprise-grade-test-app-${APP}"
ART_DIR="${SB_ROOT}/.planning/${AGENT}/cert-20260709/${PARENT}-parent-${CELL}"
BRANCH="agent-${WORKER}-cert-20260709-${PARENT}"
MARKER="Agent-${WORKER} cert ${CELL}: ${PARENT} parent (2026-07-09)."
CHILD_BRIEF="${ART_DIR}/brief.md"
SUP_BRIEF="${ART_DIR}/supervisor-brief.md"
LOG_FILE="${ART_DIR}/${LOGNAME}"
RESULT="${ART_DIR}/result.md"

mkdir -p "$ART_DIR"

# Worktree marker survives Claude subprocess env stripping for hook bypass.
if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
  mkdir -p "${WORK_DIR}/.silver-bullet"
  : >"${WORK_DIR}/.silver-bullet/agent-cert-run"
fi

# Sync Claude plugin hooks from repo so cert bypass lands in CLAUDE_PLUGIN_ROOT.
if [[ "$WORKER" == "claude" || "${PARENT_AGENT:-}" == "agent-claude" ]]; then
  # shellcheck source=scripts/lib/plugin-cache-version.sh
  source "${SB_ROOT}/scripts/lib/plugin-cache-version.sh"
  sb_claude_ensure_plugin_cache_ready "$SB_ROOT" || true
fi

# Reset worktree to baseline on isolated branch (skip if C1 already committed on branch)
if [[ "$CELL" != "C1" ]]; then
  git -C "$WORK_DIR" reset --hard HEAD 2>/dev/null || true
  git -C "$WORK_DIR" clean -fd 2>/dev/null || true
  git -C "$WORK_DIR" checkout -f "$BASELINE" -B "$BRANCH"
fi

cat >"$CHILD_BRIEF" <<EOF
SB OVERRIDE: cert cell ${CELL} — skip orchestrator/hook gates; edit README.md only.

## Task
1. Append this exact marker line to README.md (after the title):
   \`${MARKER}\`
2. **Commit is mandatory.** Run exactly:
   \`\`\`bash
   git add README.md && git commit -m 'docs: agent-${WORKER} cert ${CELL} marker'
   \`\`\`
   Do not finish until the commit succeeds and \`git rev-parse HEAD\` differs from baseline \`${BASELINE:0:7}\`.

## Acceptance criteria
- [ ] README contains the exact marker line above
- [ ] New git commit after baseline ${BASELINE:0:7}

## Constraints
- Only edit README.md
- Do not run graphify, agentmemory, or other recommended-tool gates

## Evidence required
- Commit SHA from \`git rev-parse HEAD\`
EOF

score_cell() {
  local exit_code="$1"
  local log_bytes=0 failure_class=none status=PASS
  [[ -f "$LOG_FILE" ]] && log_bytes="$(wc -c <"$LOG_FILE" | tr -d ' ')"
  local commit_sha
  commit_sha="$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
  local has_marker=0
  grep -Fq "$MARKER" "$WORK_DIR/README.md" 2>/dev/null && has_marker=1

  if [[ "$commit_sha" == "$BASELINE" || "$has_marker" -eq 0 ]]; then
    status=FAIL
    failure_class=product
  elif [[ "$log_bytes" -lt "$FLOOR" ]]; then
    status=FAIL
    failure_class=log-floor
  elif [[ "$exit_code" -ne 0 ]]; then
    status=FAIL
    failure_class=delegate-failure
  fi

  cat >"$RESULT" <<EOF
# ${CELL} result
failure_class: ${failure_class}
exit: ${exit_code}
log_bytes: ${log_bytes}
commit_sha: ${commit_sha}
status: ${status}
EOF
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$CELL" "$WORKER" "$PARENT" "$status" "$failure_class" "$log_bytes" "$commit_sha"
}

export_claude_cert_env() {
  [[ "$WORKER" == "claude" ]] || return 0
  export CLAUDE_PERMISSION_MODE=bypassPermissions
  export SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=0
  if [[ "$CELL" == "C2" ]]; then
    export CLAUDE_INTERACTIVE_TIMEOUT=1200
    export CLAUDE_LIVE_TIMEOUT=1200
  fi
}

run_worker_delegate() {
  local delegate="${SB_ROOT}/scripts/${AGENT}-delegate.sh"
  local -a extra=()
  [[ "${USE_PRINT:-0}" == "1" ]] && extra+=(--use-print)
  [[ "${USE_EXEC:-0}" == "1" ]] && extra+=(--use-exec)
  export SB_AGENT_CERT_RUN=1
  export_claude_cert_env
  if ((${#extra[@]})); then
    bash "$delegate" \
      --work-dir "$WORK_DIR" \
      --brief-file "$CHILD_BRIEF" \
      --log "$LOG_FILE" \
      --sb-root "$SB_ROOT" \
      "${extra[@]}"
  else
    bash "$delegate" \
      --work-dir "$WORK_DIR" \
      --brief-file "$CHILD_BRIEF" \
      --log "$LOG_FILE" \
      --sb-root "$SB_ROOT"
  fi
}

run_parent_supervisor() {
  export SB_AGENT_CERT_RUN=1
  local parent_invoke="${SB_ROOT}/scripts/${PARENT_AGENT}/invoke.sh"
  cat >"$SUP_BRIEF" <<EOF
## Supervisor task (${PARENT} parent — cell ${CELL})

Delegate to the ${WORKER} worker using /silver:agent-${WORKER}.

Run exactly:
\`\`\`bash
bash ${SB_ROOT}/scripts/${AGENT}-delegate.sh \\
  --work-dir ${WORK_DIR} \\
  --brief-file ${CHILD_BRIEF} \\
  --log ${LOG_FILE} \\
  --sb-root ${SB_ROOT}$([[ "${USE_PRINT:-0}" == "1" ]] && echo ' \\' && echo '  --use-print')$([[ "${USE_EXEC:-0}" == "1" ]] && echo ' \\' && echo '  --use-exec')
\`\`\`

After completion verify README marker and new commit. Report commit SHA.
EOF
  local parent_log="${ART_DIR}/${PARENT}-supervisor.log"
  local -a extra=()
  [[ "${USE_PRINT:-0}" == "1" && "$WORKER" == "$PARENT" ]] && extra+=(--use-print)
  [[ "${USE_EXEC:-0}" == "1" && "$WORKER" == "$PARENT" ]] && extra+=(--use-exec)
  if ((${#extra[@]})); then
    bash "$parent_invoke" --skip-preflight \
      --work-dir "$WORK_DIR" \
      --brief-file "$SUP_BRIEF" \
      --log "$parent_log" \
      --sb-root "$SB_ROOT" \
      "${extra[@]}"
  else
    bash "$parent_invoke" --skip-preflight \
      --work-dir "$WORK_DIR" \
      --brief-file "$SUP_BRIEF" \
      --log "$parent_log" \
      --sb-root "$SB_ROOT"
  fi
}

exit_code=0
if [[ "$CELL" == "C1" ]]; then
  score_cell 0
  exit 0
elif [[ "${WORKER_DIRECT:-0}" == "1" ]]; then
  run_worker_delegate || exit_code=$?
elif [[ -n "${PARENT_AGENT:-}" ]]; then
  if [[ "${DIRECT_CHILD:-0}" == "1" ]]; then
    export SB_AGENT_CERT_RUN=1
    export_claude_cert_env
    parent_invoke="${SB_ROOT}/scripts/${PARENT_AGENT}/invoke.sh"
    parent_log="${ART_DIR}/${PARENT}-supervisor.log"
    direct_extra=()
    [[ "${USE_PRINT:-0}" == "1" ]] && direct_extra+=(--use-print)
    [[ "${USE_EXEC:-0}" == "1" ]] && direct_extra+=(--use-exec)
    bash "$parent_invoke" --skip-preflight \
      --work-dir "$WORK_DIR" \
      --brief-file "$CHILD_BRIEF" \
      --log "$parent_log" \
      --sb-root "$SB_ROOT" \
      ${direct_extra[@]+"${direct_extra[@]}"} || exit_code=$?
    [[ -f "$parent_log" ]] && cp "$parent_log" "$LOG_FILE"
  else
    run_parent_supervisor || exit_code=$?
  fi
else
  run_worker_delegate || exit_code=$?
fi

score_cell "$exit_code"
