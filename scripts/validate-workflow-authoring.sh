#!/usr/bin/env bash
# Validate workflow authoring surfaces for a catalog-backed SB workflow slug.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

slug="new-workflow"
audit_mode=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) slug="${2:-}"; shift $(( $# >= 2 ? 2 : 1 )) ;;
    --audit)
      audit_mode=1
      shift
      if [[ $# -gt 0 && "$1" != --* ]]; then
        exec bash scripts/audit-workflow-compliance.sh --target "$1" "${@:2}"
      fi
      ;;
    --target)
      exec bash scripts/audit-workflow-compliance.sh --target "${2:-}" "${@:3}"
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ "$audit_mode" -eq 1 ]]; then
  exec bash scripts/audit-workflow-compliance.sh --slug "$slug"
fi

skill="silver-${slug}"
if [[ -f "skills/${slug}/SKILL.md" ]]; then
  skill="$slug"
fi
wf_id="WF-SILVER-$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
if [[ "$skill" == "silver" ]]; then
  wf_id="WF-SILVER-ROUTER"
fi
fail=0
pass() { echo "PASS: $1"; }
fail_msg() { echo "FAIL: $1" >&2; fail=1; }

if [[ -f "skills/${skill}/SKILL.md" ]]; then pass "skill exists"; else fail_msg "missing skills/${skill}/SKILL.md"; fi
if grep -q "\"${skill}\"" scripts/generate-apo-catalog.py; then pass "catalog generator mapping"; else fail_msg "generate-apo-catalog.py missing ${skill}"; fi
if jq -e --arg id "$wf_id" '.workflows[] | select(.id == $id)' docs/apo-catalog.json >/dev/null; then pass "catalog workflow"; else fail_msg "missing ${wf_id}"; fi
if jq -e --arg s "$skill" '.migration_map.skill_to_entity[$s]' docs/apo-catalog.json >/dev/null; then pass "skill_to_entity"; else fail_msg "skill_to_entity missing ${skill}"; fi
if grep -q "$skill" hooks/lib/orchestrator-state.sh; then pass "orchestrator composer"; else fail_msg "orchestrator-state missing ${skill}"; fi
if grep -q "${skill}\|${slug}" skills/silver/SKILL.md; then pass "router"; else fail_msg "router missing ${skill}"; fi
if [[ "$slug" == "new-workflow" ]]; then
  if [[ -f docs/NEW-WORKFLOW.md ]]; then pass "runbook"; else fail_msg "missing docs/NEW-WORKFLOW.md"; fi
fi
exit "$fail"
