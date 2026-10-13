#!/usr/bin/env bash
set -euo pipefail
MAIN="/Users/shafqat/projects/silver-bullet/repo"
SB_ROOT="/private/tmp/sb-main-row11-fp"
WT="/Users/shafqat/projects/enterprise-grade-test-app-round9-claude"
BASELINE=8482e60
LOG11="$MAIN/.e2e-r9-pilot-rows-6-11-sequential.log"
LOG3="$MAIN/.e2e-r9-pilot-row3-live.log"
TL="$MAIN/.e2e-r9-claude-timeline.md"
LEDGER="$MAIN/.planning/enterprise-e2e/ROUND-9-LEDGER.md"
OUT="$MAIN/.e2e-r9-followup-row11-row3-result.json"
INNER3="$MAIN/.planning/enterprise-e2e/.r9-pilot-row3-launch-inner.sh"
SMOKE_ROWS=(1 3 6 11 21 22)

source "$MAIN/scripts/lib/enterprise-e2e-row-pass-registry.sh"
export SB_ROOT

fp() { enterprise_e2e_install_fingerprint; }
reg_count() { enterprise_e2e_row_pass_registry_pass_count "$(fp)"; }

commits_5b() {
  git -C "$WT" rev-list --count "${BASELINE}..HEAD" 2>/dev/null | tr -cd '0-9' || echo 0
}

log_line() { echo "- **$(date -u +%Y-%m-%dT%H:%M:%SZ)** $*" >>"$TL"; }

row11_done() {
  python3 - "$LOG11" <<'PY'
import sys
from pathlib import Path
log = Path(sys.argv[1])
text = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
start = text.rfind("=== PILOT row 11 start")
finish = text.rfind("=== PILOT row 11 finished")
sys.exit(0 if start >= 0 and finish > start else 1)
PY
}

row11_pass() {
  local ev="$WT/.planning/workflows/devops-terraform-validation.md"
  [[ -f "$ev" ]] || return 1
  enterprise_e2e_pilot_log_row_passed 11 "$LOG11" || return 1
  return 0
}

row3_done() {
  grep -q "=== pilot row3 finished" "$LOG3" 2>/dev/null || return 1
  return 0
}

row3_pass() {
  local ev="$WT/.planning/workflows/feature-currency.md"
  [[ -f "$ev" ]] || return 1
  enterprise_e2e_pilot_log_row_passed 3 "$LOG3" || return 1
  local c; c=$(commits_5b); [[ "${c:-0}" -ge 3 ]] || return 1
  return 0
}

register_row() {
  local row="$1" logref="$2" src="${3:-pilot}"
  SB_ROOT="$SB_ROOT" enterprise_e2e_row_pass_registry_record "$row" "$logref" true "$src"
}

smoke_subset_ok() {
  local fp="$1" missing=""
  for r in "${SMOKE_ROWS[@]}"; do
    SB_ROOT="$SB_ROOT" enterprise_e2e_row_pass_registry_has_pass "$r" || missing="${missing} ${r}"
  done
  [[ -z "$missing" ]]
}

write_result() {
  local r11="$1" r3="$2" smoke="$3"
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg r11 "$r11" --arg r3 "$r3" --arg smoke "$smoke" \
    --arg reg "$(reg_count)" --arg fp "$(fp)" \
    --argjson commits "$(commits_5b)" \
    '{ts, row11: $r11, row3: $r3, registry: ($reg + "/22"), install_fp: $fp, smoke_green: $smoke, commits_5b: $commits}' >"$OUT"
}

append_ledger() {
  local block="$1"
  printf '\n%s\n' "$block" >>"$LEDGER"
  # refresh status line (line 3)
  local reg; reg=$(reg_count)
  local smoke; smoke_subset_ok "$(fp)" && smoke="GREEN" || smoke="not GREEN"
  sed -i '' "3s|.*|**Status:** Registry **${reg}/22** on \`$(fp)\`; row **11**/**3** follow-up; smoke **${smoke}**|" "$LEDGER" 2>/dev/null || true
}

# --- Phase 1: poll row 11 (45m) ---
ROW11=IN_FLIGHT
end11=$((SECONDS+2700))
log_line "follow-up operator: poll row11 start (45m cap)"
while [ $SECONDS -lt $end11 ]; do
  d=$(tr -d ' \n' <"$MAIN/.e2e-r9-pilot-rows-6-11.pid" 2>/dev/null || true)
  alive=0; [[ -n "$d" ]] && kill -0 "$d" 2>/dev/null && alive=1
  log_line "row11-poll alive=$alive reg=$(reg_count)/22 commits=$(commits_5b) driver=$d"
  if row11_done; then break; fi
  if [[ "$alive" -eq 0 ]] && ! row11_done; then
    ROW11=FAIL
    log_line "row11-poll DRIVER_DEAD before finish"
    break
  fi
  sleep $((75 + RANDOM % 16))
done

if [[ "$ROW11" != FAIL ]]; then
  if row11_done; then
    if row11_pass; then
      ROW11=PASS
      register_row 11 ".e2e-r9-pilot-rows-6-11-sequential.log" pilot
      log_line "row11 **PASS** registered reg=$(reg_count)/22"
    else
      ROW11=FAIL
      log_line "row11 **FAIL** (evidence or matrix log)"
    fi
  else
    ROW11=TIMEOUT
    log_line "row11 poll TIMEOUT (45m)"
  fi
fi

append_ledger "**Follow-up operator row 11 ($(date -u +%Y-%m-%dT%H:%M:%SZ)):** **${ROW11}** — evidence \`devops-terraform-validation.md\` $([ -f "$WT/.planning/workflows/devops-terraform-validation.md" ] && echo present || echo missing); registry **$(reg_count)/22**. Log: [\`.e2e-r9-pilot-rows-6-11-sequential.log\`](../../.e2e-r9-pilot-rows-6-11-sequential.log)."

# --- Phase 2: launch row 3 (not blocked by row 11) ---
ROW3=SKIPPED
if [[ "$ROW11" != IN_FLIGHT ]]; then
  log_line "launch row3 tmux r9-pilot-row3"
  tmux kill-session -t r9-pilot-row3 2>/dev/null || true
  : >"$LOG3"
  tmux new-session -d -s r9-pilot-row3 "bash \"$INNER3\""
  ROW3=IN_FLIGHT
  end3=$((SECONDS+2700))
  while [ $SECONDS -lt $end3 ]; do
    d3=$(tr -d ' \n' <"$MAIN/.e2e-r9-pilot-row3.pid" 2>/dev/null || true)
    alive3=0; [[ -n "$d3" ]] && kill -0 "$d3" 2>/dev/null && alive3=1
    log_line "row3-poll alive=$alive3 reg=$(reg_count)/22 commits=$(commits_5b) driver=$d3"
    if row3_done; then break; fi
    if [[ "$alive3" -eq 0 ]] && ! row3_done; then
      ROW3=FAIL
      log_line "row3-poll DRIVER_DEAD before finish"
      break
    fi
    sleep $((75 + RANDOM % 16))
  done
  if [[ "$ROW3" == IN_FLIGHT ]]; then
    if row3_done; then
      if row3_pass; then
        ROW3=PASS
        register_row 3 ".e2e-r9-pilot-row3-live.log" pilot
        log_line "row3 **PASS** registered reg=$(reg_count)/22"
      else
        ROW3=FAIL
        log_line "row3 **FAIL** (evidence/matrix/§5b)"
      fi
    else
      ROW3=TIMEOUT
      log_line "row3 poll TIMEOUT (45m)"
    fi
  fi
  append_ledger "**Follow-up operator row 3 ($(date -u +%Y-%m-%dT%H:%M:%SZ)):** **${ROW3}** — \`feature-currency.md\` $([ -f "$WT/.planning/workflows/feature-currency.md" ] && echo present || echo missing); §5b commits **$(commits_5b)** since \`${BASELINE}\`; registry **$(reg_count)/22**. Log: [\`.e2e-r9-pilot-row3-live.log\`](../../.e2e-r9-pilot-row3-live.log)."
fi

SMOKE=N
if smoke_subset_ok "$(fp)"; then
  SMOKE=Y
  append_ledger "**Smoke matrix ($(date -u +%Y-%m-%dT%H:%M:%SZ)):** **GREEN** — registry rows **1,3,6,11,21,22** on \`$(fp)\` (**$(reg_count)/22** total)."
else
  append_ledger "**Smoke matrix ($(date -u +%Y-%m-%dT%H:%M:%SZ)):** **RED** — smoke subset missing on \`$(fp)\` (registry **$(reg_count)/22**)."
fi

write_result "$ROW11" "$ROW3" "$SMOKE"
log_line "follow-up operator DONE row11=$ROW11 row3=$ROW3 smoke=$SMOKE reg=$(reg_count)/22"
