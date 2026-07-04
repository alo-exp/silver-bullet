#!/usr/bin/env bash
# Rollback routing: SB_AGENT_DELEGATE_V2 and migration_map targets.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
# shellcheck source=hooks/lib/orchestrator-parent.sh
source "$REPO_ROOT/hooks/lib/orchestrator-parent.sh"

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

echo "=== agent-delegation rollback tests ==="

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

# V2=0: legacy delegate bash allowed without fallback flag
unset SB_AGENT_DELEGATE_V2
export SB_AGENT_DELEGATE_DIRECT_FALLBACK=0
sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-codex-delegate.sh --work-dir /tmp' \
  && check "V2=0 allows delegate bash" pass || check "V2=0 allows delegate bash" fail

# V2=1 without fallback: blocked
export SB_AGENT_DELEGATE_V2=1
! sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-codex-delegate.sh --work-dir /tmp' \
  && check "V2=1 blocks direct delegate without fallback" pass || check "V2=1 blocks direct delegate without fallback" fail

export SB_AGENT_DELEGATE_DIRECT_FALLBACK=1
sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-cursor-delegate.sh --work-dir /tmp' \
  && check "V2=1 allows delegate with DIRECT_FALLBACK" pass || check "V2=1 allows delegate with DIRECT_FALLBACK" fail

# Substring spoof blocked
! sb_orchestrator_parent_delegate_bash_allowed 'echo agent-codex-delegate.sh not a real invoke' \
  && check "substring spoof blocked" pass || check "substring spoof blocked" fail

map_codex="$(jq -r '.migration_map.skill_to_entity["silver-agent-codex"]' "$CATALOG")"
map_cursor="$(jq -r '.migration_map.skill_to_entity["silver-agent-cursor"]' "$CATALOG")"
[[ "$map_codex" == "AF-AGENT-DELEGATE" ]] \
  && check "post-flip codex maps AF-AGENT-DELEGATE" pass || check "post-flip codex maps AF-AGENT-DELEGATE" fail
[[ "$map_cursor" == "AF-AGENT-DELEGATE" ]] \
  && check "post-flip cursor maps AF-AGENT-DELEGATE" pass || check "post-flip cursor maps AF-AGENT-DELEGATE" fail

# Legacy map check (pre-flip or post-flip rollback)
[[ "$map_codex" == "AF-EXECUTE" || "$map_codex" == "AF-AGENT-DELEGATE" ]] \
  && check "codex maps to known AF" pass || check "codex maps to known AF" fail

worker_map="$(jq -r '.migration_map.skill_to_entity["silver-agent-worker"]' "$CATALOG")"
[[ "$worker_map" == "AF-AGENT-DELEGATE" ]] && check "worker skill maps delegation AF" pass || check "worker skill maps delegation AF" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
