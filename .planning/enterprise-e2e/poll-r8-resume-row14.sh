#!/usr/bin/env bash
# Poll R8 resume batch after row-14 kill (driver-based, no orchestrator).
set -o pipefail
MAIN=/Users/shafqat/projects/silver-bullet/repo
SB_ROOT=/private/tmp/sb-main-row11-fp
LOG="$SB_ROOT/.e2e-r8-claude-resume-fp-live.log"
LEDGER="$SB_ROOT/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
OUT="$MAIN/.e2e-r8-resume-after-47290-poll-result.json"
POLL_LOG="$MAIN/.e2e-r8-resume-after-47290-poll.log"
export SB_E2E_INSTALL_FP=claude@89e2ab8f96a1+724a435c9991
DRIVER="${1:-$(cat "$MAIN/.e2e-r8-driver.pid" 2>/dev/null || true)}"
MAX_SEC=$((24 * 3600))
STUCK_SEC=$((45 * 60))
start=$(date +%s)
last_row=""
last_change=$(date +%s)
done_reason=""

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$POLL_LOG"; }
driver_alive() { [[ -n "$DRIVER" ]] && kill -0 "$DRIVER" 2>/dev/null; }

log "poll start driver=$DRIVER log=$LOG max=${MAX_SEC}s stuck=${STUCK_SEC}s"

while true; do
  elapsed=$(( $(date +%s) - start ))
  if grep -q '=== Matrix summary ===' "$LOG" 2>/dev/null; then
    done_reason=matrix_summary
    log "DONE: matrix summary"
    break
  fi
  if ! driver_alive; then
    done_reason=driver_dead
    log "DONE: driver $DRIVER exited"
    break
  fi
  if (( elapsed >= MAX_SEC )); then
    done_reason=checkpoint_24h
    log "CHECKPOINT: 24h"
    break
  fi
  row=$(grep -E '^=== Row ' "$LOG" 2>/dev/null | tail -1 || true)
  if [[ -n "$row" && "$row" != "$last_row" ]]; then
    last_row="$row"
    last_change=$(date +%s)
    log "progress: $row"
  fi
  stuck=$(( $(date +%s) - last_change ))
  hint=$(grep -E '^=== Row |OUTCOMES: all applicable|FAIL: outcome' "$LOG" 2>/dev/null | tail -3 | tr '\n' ' ' | cut -c1-220)
  log "poll elapsed=${elapsed}s driver=1 row=${last_row:-?} stuck=${stuck}s hint=${hint:-(none)}"
  sleep $((60 + RANDOM % 31))
done

export SB_ROOT SB_E2E_LEDGER_FILE="$LEDGER" SB_E2E_INSTALL_FP
source "$MAIN/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
reconcile=$(enterprise_e2e_ledger_reconcile_status)
read -r pass_count _ _ < <(enterprise_e2e_ledger_pass_summary "$LEDGER")
source "$MAIN/scripts/lib/enterprise-e2e-row-pass-registry.sh"
registry=$(enterprise_e2e_row_pass_registry_pass_count "$SB_E2E_INSTALL_FP")

jq -n \
  --arg done_reason "$done_reason" \
  --argjson elapsed "$elapsed" \
  --arg driver_pid "${DRIVER:-}" \
  --arg reconcile "$reconcile" \
  --argjson pass_count "${pass_count:-0}" \
  --argjson registry_pass "${registry:-0}" \
  --arg last_row "${last_row:-}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{done_reason:$done_reason,elapsed_sec:$elapsed,driver_pid:($driver_pid|tonumber?//$driver_pid),reconcile_status:$reconcile,pass_count:$pass_count,registry_pass:$registry_pass,last_row:$last_row,completed_at:$ts}' \
  >"$OUT"
log "poll finished reason=$done_reason registry=${registry}/22"
