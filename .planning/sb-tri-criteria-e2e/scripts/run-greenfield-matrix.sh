#!/usr/bin/env bash
# Run full greenfield matrix: Claude + Codex × TC-01/02/03
# Skips cells that already have a scored greenfield PASS in runs/*/ledger.json.
set -euo pipefail

SB_ROOT="${SB_ROOT:-/Users/shafqat/projects/silver-bullet/repo}"
WORK_DIR="${SB_TRI_CRITERIA_WORK_DIR:-/Users/shafqat/projects/enterprise-grade-test-app}"
RUNS_ROOT="${SB_ROOT}/.planning/sb-tri-criteria-e2e/runs"
LOG_ROOT="${RUNS_ROOT}/greenfield-batch-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$LOG_ROOT"

export SB_ROOT SB_TRI_CRITERIA_WORK_DIR="$WORK_DIR" SILVER_BULLET_UPDATE_CHECK_DISABLED=1

greenfield_cell_passed() {
  local host="$1" track="$2"
  local ledger verdict gf host_val track_val fixture_sha baseline_sha
  baseline_sha="565e825de6ce"
  while IFS= read -r ledger; do
    [[ -f "$ledger" ]] || continue
    verdict="$(jq -r '.verdict // ""' "$ledger" 2>/dev/null || true)"
    gf="$(jq -r '.greenfield // false' "$ledger" 2>/dev/null || true)"
    host_val="$(jq -r '.host // ""' "$ledger" 2>/dev/null || true)"
    track_val="$(jq -r '.track_id // .row_id // ""' "$ledger" 2>/dev/null || true)"
    fixture_sha="$(jq -r '.fixture_sha // ""' "$ledger" 2>/dev/null || true)"
    if [[ "$verdict" == "PASS" && "$gf" == "true" && "$host_val" == "$host" && "$track_val" == "$track" ]]; then
      if [[ -n "$fixture_sha" && "$fixture_sha" != "$baseline_sha" && "$fixture_sha" != "unknown" ]]; then
        printf '%s\n' "$ledger"
        return 0
      fi
    fi
  done < <(find "$RUNS_ROOT" -maxdepth 2 -name 'ledger.json' -print 2>/dev/null | sort -r)
  return 1
}

run_one() {
  local host="$1" track="$2"
  local log="${LOG_ROOT}/${host}-${track}.log"
  local prior
  if prior="$(greenfield_cell_passed "$host" "$track")"; then
    echo "=== SKIP ${host} ${track} (greenfield PASS: ${prior}) ===" | tee -a "$log"
    return 0
  fi
  echo "=== START ${host} ${track} $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" | tee -a "$log"
  cd "$WORK_DIR" && git checkout main >/dev/null 2>&1 || true
  if bash "${SB_ROOT}/scripts/sb-tri-criteria-e2e.sh" live --host "$host" --track "$track" --greenfield >>"$log" 2>&1; then
    echo "=== PASS ${host} ${track} ===" | tee -a "$log"
    return 0
  fi
  echo "=== FAIL ${host} ${track} ===" | tee -a "$log"
  return 1
}

fail=0
for host in codex claude; do
  for track in TC-01 TC-02 TC-03; do
    run_one "$host" "$track" || fail=$((fail + 1))
  done
done

echo "batch_log=$LOG_ROOT"
echo "failures=$fail"
exit "$fail"
