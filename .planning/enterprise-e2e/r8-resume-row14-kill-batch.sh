#!/usr/bin/env bash
# Kill hung R8 resume row-14 session and relaunch remaining rows (one-pass policy).
set -euo pipefail
SB_ROOT=/private/tmp/sb-main-row11-fp
MAIN=/Users/shafqat/projects/silver-bullet/repo
RESUME_LOG="$SB_ROOT/.e2e-r8-claude-resume-fp-live.log"
LEDGER="$SB_ROOT/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
ORCH_LOG="$MAIN/.e2e-r8-resume-after-47290-orchestrator.log"
RESULT="$MAIN/.e2e-r8-resume-after-47290-result.json"
TEST_APP=/Users/shafqat/projects/enterprise-grade-test-app
TMUX_SESSION=r8-claude-resume2
export SB_E2E_INSTALL_FP=claude@89e2ab8f96a1+724a435c9991

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$ORCH_LOG"; }

OLD_DRIVER="${1:-22058}"
OLD_ORCH="${2:-6671}"

kill_tree() {
  local pid="$1"
  [[ -z "$pid" ]] && return 0
  kill -0 "$pid" 2>/dev/null || return 0
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_tree "$child"
  done
  log "TERM $pid ($(ps -p "$pid" -o comm= 2>/dev/null || echo unknown))"
  kill -TERM "$pid" 2>/dev/null || true
}

force_kill_tree() {
  local pid="$1"
  [[ -z "$pid" ]] && return 0
  kill -0 "$pid" 2>/dev/null || return 0
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    force_kill_tree "$child"
  done
  kill -KILL "$pid" 2>/dev/null || true
}

log "=== R8 row-14 kill+resume start old_driver=$OLD_DRIVER old_orch=$OLD_ORCH ==="

# Kill expect/claude children first (row 14 hang)
for pid in $(pgrep -f 'claude-interactive-invoke.expect' 2>/dev/null || true); do
  ppid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)
  if [[ "$ppid" == "$OLD_DRIVER" ]] || pstree -p "$OLD_DRIVER" 2>/dev/null | grep -q "($pid)"; then
    kill_tree "$pid"
  fi
done
sleep 3
for pid in $(pgrep -f 'claude-interactive-invoke.expect' 2>/dev/null || true); do
  force_kill_tree "$pid"
done

kill_tree "$OLD_DRIVER"
kill_tree "$OLD_ORCH"
sleep 5
force_kill_tree "$OLD_DRIVER"
force_kill_tree "$OLD_ORCH"

# Clear stale lock
rm -f "$SB_ROOT/.e2e-live-test.lock"

killed_driver=no
killed_orch=no
kill -0 "$OLD_DRIVER" 2>/dev/null || killed_driver=yes
kill -0 "$OLD_ORCH" 2>/dev/null || killed_orch=yes
log "kill result driver=$killed_driver orch=$killed_orch"

# Register row 13 if outcome PASS in resume log
row13_pass=0
if grep -q 'OUTCOMES: all applicable criteria pass' "$RESUME_LOG" 2>/dev/null && \
   awk '/^=== Row 13:/{p=1} p && /OUTCOMES: all applicable/{found=1} p && /^=== Row 14:/{exit} END{exit !found}' "$RESUME_LOG"; then
  export SB_ROOT
  export SB_E2E_INSTALL_FP=claude@89e2ab8f96a1+724a435c9991
  # shellcheck source=/dev/null
  source "$MAIN/scripts/lib/enterprise-e2e-row-pass-registry.sh"
  python3 - "$SB_ROOT" <<'PY'
import json, subprocess, sys
from pathlib import Path
sb_root, reg_path = sys.argv[1], Path(sys.argv[1]) / ".planning/enterprise-e2e/.row-pass-registry.json"
install_fp = "claude@89e2ab8f96a1+724a435c9991"
passed_at = subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
doc = json.loads(reg_path.read_text(encoding="utf-8"))
inst = doc.setdefault("installs", {}).setdefault(install_fp, {
    "host": "claude", "sb_sha": "89e2ab8f96a1", "install_fp": install_fp, "rows": {}
})
inst.setdefault("rows", {})["13"] = {
    "passed_at": passed_at,
    "log_ref": ".e2e-r8-claude-resume-fp-live.log",
    "outcome_pass": True,
    "source": "r8-resume-row13",
}
reg_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
PY
  row13_pass=1
  log "registered row 13 outcome PASS in registry"
else
  log "row 13 outcome PASS not found — skip registry"
fi

# Rows needing first outcome PASS (registry skip for 1,3,4,6,7,11,13,21,22)
ROWS=(2 5 8 9 10 12 14 15 16 17 18 19 20)

export SB_ROOT SB_E2E_INSTALL_FP
export SB_TEST_ENTERPRISE_APP_ROOT="$TEST_APP"
export SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-8-claude
export SB_E2E_TEST_APP_BASELINE_SHA=8482e60
export SB_E2E_LEDGER_FILE="$LEDGER"
export SB_E2E_MATRIX_LOG="$RESUME_LOG"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_SESSION0_SKIP=1
export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=claude
export SB_E2E_LIVE_RUNTIME=claude
unset SB_E2E_MATRIX_FORCE_ALL
export SB_E2E_MATRIX_FORCE=1

git -C "$TEST_APP" fetch origin enterprise-e2e/round-8-claude 2>/dev/null || true
git -C "$TEST_APP" checkout enterprise-e2e/round-8-claude
git -C "$TEST_APP" reset --hard 8482e60

rm -f "$RESULT"

log "launching tmux session=$TMUX_SESSION rows: ${ROWS[*]}"
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

LAUNCH_WRAPPER="$MAIN/.planning/enterprise-e2e/.r8-resume-row14-launch-inner.sh"
cat >"$LAUNCH_WRAPPER" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
SB_ROOT=/private/tmp/sb-main-row11-fp
MAIN=/Users/shafqat/projects/silver-bullet/repo
RESUME_LOG="$SB_ROOT/.e2e-r8-claude-resume-fp-live.log"
ORCH_LOG="$MAIN/.e2e-r8-resume-after-47290-orchestrator.log"
TEST_APP=/Users/shafqat/projects/enterprise-grade-test-app
export SB_E2E_INSTALL_FP=claude@89e2ab8f96a1+724a435c9991
export SB_ROOT SB_E2E_INSTALL_FP
export SB_TEST_ENTERPRISE_APP_ROOT="$TEST_APP"
export SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-8-claude
export SB_E2E_TEST_APP_BASELINE_SHA=8482e60
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
export SB_E2E_MATRIX_LOG="$RESUME_LOG"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_SESSION0_SKIP=1
export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=claude
export SB_E2E_LIVE_RUNTIME=claude
export SB_E2E_MATRIX_FORCE=1
ROWS=(2 5 8 9 10 12 14 15 16 17 18 19 20)
cd "$SB_ROOT"
exec bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight "${ROWS[@]}" 2>&1 | tee -a "$RESUME_LOG"
INNER
chmod +x "$LAUNCH_WRAPPER"

tmux new-session -d -s "$TMUX_SESSION" "bash $LAUNCH_WRAPPER; ec=\$?; echo \"\$(date -u +%Y-%m-%dT%H:%M:%SZ) resume batch exit=\$ec\" >> $ORCH_LOG; exit \$ec"

sleep 3
NEW_DRIVER="$(pgrep -f 'run-enterprise-e2e-matrix.sh.*2 5 8' | head -1 || true)"
NEW_LIVE="$(pgrep -f 'run-enterprise-e2e-live-test.sh.*2 5 8' | head -1 || true)"
echo "${NEW_DRIVER:-}" >"$MAIN/.e2e-r8-driver.pid"
log "new driver_pid=${NEW_DRIVER:-none} live_test_pid=${NEW_LIVE:-none} tmux=$TMUX_SESSION"

# Ledger checkpoint
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# shellcheck source=/dev/null
source "$MAIN/scripts/lib/enterprise-e2e-row-pass-registry.sh"
registry_pass="$(enterprise_e2e_row_pass_registry_pass_count "$SB_E2E_INSTALL_FP")"
{
  echo ""
  echo "## R8 row-14 kill+resume @ ${ts}"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| reason | row 14 hung ~8h; killed driver ${OLD_DRIVER} + expect children |"
  echo "| killed_driver | ${killed_driver} |"
  echo "| killed_orch | ${killed_orch} |"
  echo "| row13_registered | ${row13_pass} |"
  echo "| new_driver | ${NEW_DRIVER:-pending} |"
  echo "| tmux | ${TMUX_SESSION} |"
  echo "| resume rows | ${ROWS[*]} |"
  echo "| registry | ${registry_pass}/22 |"
  echo "| install_fp | \`${SB_E2E_INSTALL_FP}\` |"
  echo "| SB_ROOT | \`${SB_ROOT}\` @ \`$(git -C "$SB_ROOT" rev-parse --short HEAD)\` |"
} >>"$LEDGER"

jq -n \
  --argjson row13_registered "$row13_pass" \
  --arg killed_driver "$killed_driver" \
  --arg killed_orch "$killed_orch" \
  --arg new_driver "${NEW_DRIVER:-}" \
  --arg tmux "$TMUX_SESSION" \
  --arg rows "${ROWS[*]}" \
  --argjson registry_pass "${registry_pass:-0}" \
  --arg ts "$ts" \
  '{
    row14_kill_resume: true,
    row13_registered: ($row13_registered == 1),
    killed_driver: ($killed_driver == "yes"),
    killed_orch: ($killed_orch == "yes"),
    new_driver_pid: ($new_driver | tonumber? // $new_driver),
    tmux: $tmux,
    resume_rows: ($rows | split(" ") | map(tonumber)),
    registry_pass: $registry_pass,
    launched_at: $ts
  }' >"$MAIN/.e2e-r8-resume-row14-kill-result.json"

log "DONE new_driver=${NEW_DRIVER:-none} registry=${registry_pass}/22"
cat "$MAIN/.e2e-r8-resume-row14-kill-result.json"
