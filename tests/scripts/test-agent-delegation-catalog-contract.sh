#!/usr/bin/env bash
# Catalog contract tests for AF-AGENT-DELEGATE (post-flip: host skills map to delegation AF).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
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

echo "=== agent-delegation catalog contract tests ==="

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

jq -e '.atomic_flows[] | select(.id=="AF-AGENT-DELEGATE")' "$CATALOG" >/dev/null \
  && check "AF-AGENT-DELEGATE exists" pass || check "AF-AGENT-DELEGATE exists" fail

jq -e '.workflows[] | select(.id=="WF-AGENT-DELEGATE-ENTRY")' "$CATALOG" >/dev/null \
  && check "WF-AGENT-DELEGATE-ENTRY exists" pass || check "WF-AGENT-DELEGATE-ENTRY exists" fail

jq -e '.artifacts[] | select(.id=="ART-AGENT-DELEGATE")' "$CATALOG" >/dev/null \
  && check "ART-AGENT-DELEGATE exists" pass || check "ART-AGENT-DELEGATE exists" fail

jq -e '.evidence_records[] | select(.id=="EV-AF-AGENT-DELEGATE")' "$CATALOG" >/dev/null \
  && check "EV-AF-AGENT-DELEGATE exists" pass || check "EV-AF-AGENT-DELEGATE exists" fail

jq -e '.evidence_records[] | select(.id=="EV-DELEGATE-DEGRADED-FALLBACK")' "$CATALOG" >/dev/null \
  && check "EV-DELEGATE-DEGRADED-FALLBACK exists" pass || check "EV-DELEGATE-DEGRADED-FALLBACK exists" fail

for step in FS-DELEGATE-BRIEF FS-DELEGATE-GUARD_ON FS-DELEGATE-LAUNCH FS-DELEGATE-VERIFY FS-DELEGATE-MENTOR FS-DELEGATE-GUARD_OFF; do
  jq -e --arg s "$step" '.flow_steps[] | select(.id==$s)' "$CATALOG" >/dev/null \
    && check "flow step $step" pass || check "flow step $step" fail
done

map_codex="$(jq -r '.migration_map.skill_to_entity["silver-agent-codex"]' "$CATALOG")"
map_cursor="$(jq -r '.migration_map.skill_to_entity["silver-agent-cursor"]' "$CATALOG")"
map_worker="$(jq -r '.migration_map.skill_to_entity["silver-agent-worker"]' "$CATALOG")"

map_claude="$(jq -r '.migration_map.skill_to_entity["silver-agent-claude"]' "$CATALOG")"
[[ "$map_codex" == "AF-AGENT-DELEGATE" ]] && check "silver-agent-codex maps AF-AGENT-DELEGATE" pass \
  || check "silver-agent-codex maps AF-AGENT-DELEGATE" fail
[[ "$map_cursor" == "AF-AGENT-DELEGATE" ]] && check "silver-agent-cursor maps AF-AGENT-DELEGATE" pass \
  || check "silver-agent-cursor maps AF-AGENT-DELEGATE" fail
[[ "$map_claude" == "AF-AGENT-DELEGATE" ]] && check "silver-agent-claude maps AF-AGENT-DELEGATE" pass \
  || check "silver-agent-claude maps AF-AGENT-DELEGATE" fail
[[ "$map_worker" == "AF-AGENT-DELEGATE" ]] && check "silver-agent-worker maps AF-AGENT-DELEGATE" pass \
  || check "silver-agent-worker maps AF-AGENT-DELEGATE" fail

parallel="$(jq -r '.atomic_flows[] | select(.id=="AF-AGENT-DELEGATE") | .execution.parallelizable' "$CATALOG")"
[[ "$parallel" == "false" ]] && check "AF-AGENT-DELEGATE not parallelizable" pass \
  || check "AF-AGENT-DELEGATE not parallelizable" fail

repair="$(jq -r '.atomic_flows[] | select(.id=="AF-AGENT-DELEGATE") | .v_loop.repair.max_attempts' "$CATALOG")"
[[ "$repair" == "2" ]] && check "repair.max_attempts is 2" pass || check "repair.max_attempts is 2" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
