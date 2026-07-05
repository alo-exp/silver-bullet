#!/usr/bin/env bash
# Read-only compliance audit for catalog-backed SB workflows.
# Resolves target from workflow id, composer slug, or SKILL.md path.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GUARD="${REPO_ROOT}/hooks/workflow-chain-guard.sh"
ORCH_LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
CATALOG="${REPO_ROOT}/docs/apo-catalog.json"

target=""
slug=""
skill=""
wf_id=""
fail=0

pass_cat() { echo "PASS [$1]: $2"; }
fail_cat() { echo "FAIL [$1]: $2" >&2; fail=1; }
remediation() { echo "  → $1"; }

usage() {
  cat <<'EOF'
Usage: audit-workflow-compliance.sh [--target <wf-id|slug|path>] [--slug <slug>]
  --target   WF-SILVER-*, silver-<name>, <name>, or path to SKILL.md
  --slug     Composer slug suffix (e.g. feature, new-workflow)
EOF
  exit 2
}

strip_audit_prefix() {
  local s="$1"
  s="${s#--audit}"
  s="${s#--validate}"
  s="${s#audit}"
  s="${s#validate}"
  s="${s# }"
  printf '%s' "$s"
}

resolve_from_slug() {
  slug="$1"
  skill="silver-${slug}"
  wf_id="WF-SILVER-$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
}

resolve_target() {
  local raw="$1"
  raw="$(strip_audit_prefix "$raw")"
  [[ -z "$raw" ]] && return 1

  if [[ "$raw" =~ ^WF- ]]; then
    wf_id="$raw"
    local catalog_slug owning_skill
    catalog_slug="$(jq -r --arg id "$wf_id" '.workflows[] | select(.id == $id) | .slug // empty' "$CATALOG")"
    owning_skill="$(jq -r --arg id "$wf_id" '.workflows[] | select(.id == $id) | .owning_skill // empty' "$CATALOG")"
    [[ -z "$catalog_slug" ]] && return 1
    if [[ -n "$owning_skill" ]]; then
      skill="$owning_skill"
      if [[ "$skill" == silver-* ]]; then
        slug="${skill#silver-}"
      else
        slug="$skill"
      fi
    elif [[ "$wf_id" =~ ^WF-SILVER- ]]; then
      slug="${catalog_slug#silver-}"
      if [[ "$catalog_slug" == silver-* ]]; then
        skill="$catalog_slug"
      else
        skill="silver-${catalog_slug}"
      fi
    else
      slug="$catalog_slug"
      skill=""
    fi
    return 0
  fi

  if [[ -f "$raw" && "$raw" == *SKILL.md ]]; then
    skill="$(basename "$(dirname "$raw")")"
    slug="${skill#silver-}"
    wf_id="WF-SILVER-$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
    return 0
  fi

  if [[ "$raw" == silver-* ]]; then
    skill="$raw"
    slug="${skill#silver-}"
    wf_id="WF-SILVER-$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
    return 0
  fi

  if [[ -f "skills/silver-${raw}/SKILL.md" ]]; then
    resolve_from_slug "$raw"
    return 0
  fi

  local by_slug
  by_slug="$(jq -r --arg s "silver-${raw}" '.workflows[] | select(.slug == $s) | .id' "$CATALOG" | head -1)"
  if [[ -n "$by_slug" ]]; then
    wf_id="$by_slug"
    skill="silver-${raw}"
    slug="$raw"
    return 0
  fi

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="${2:-}"; shift 2 ;;
    --slug) resolve_from_slug "${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) target="$1"; shift ;;
  esac
done

if [[ -n "$target" ]]; then
  resolve_target "$target" || { echo "FAIL: cannot resolve target: $target" >&2; exit 2; }
elif [[ -z "$slug" ]]; then
  usage
fi

is_composer=0
[[ -n "$skill" && "$wf_id" =~ ^WF-SILVER- ]] && is_composer=1

echo "=== workflow compliance audit ==="
echo "target: skill=${skill:-N/A} slug=${slug} wf_id=${wf_id} composer=${is_composer}"
echo

# --- Category: structural ---
echo "--- structural ---"
if [[ "$is_composer" -eq 1 ]]; then
  if bash scripts/validate-workflow-authoring.sh --slug "$slug"; then
    pass_cat structural "validate-workflow-authoring.sh"
  else
    fail_cat structural "validate-workflow-authoring.sh"
    remediation "docs/NEW-WORKFLOW.md — authoring checklist"
  fi
else
  pass_cat structural "component workflow — composer structural checks N/A"
fi

# --- Category: migration_map ---
echo "--- migration_map ---"
if [[ "$is_composer" -eq 1 ]]; then
  if jq -e --arg s "$skill" '.migration_map.skill_to_entity[$s]' "$CATALOG" >/dev/null 2>&1; then
    entity="$(jq -r --arg s "$skill" '.migration_map.skill_to_entity[$s]' "$CATALOG")"
    pass_cat migration_map "skill_to_entity ${skill} → ${entity}"
  else
    fail_cat migration_map "skill_to_entity missing for ${skill}"
    remediation "scripts/generate-apo-catalog.py — migration_map.skill_to_entity"
  fi
else
  pass_cat migration_map "component workflow — skill_to_entity N/A"
fi

# --- Category: catalog workflow ---
echo "--- catalog ---"
if jq -e --arg id "$wf_id" '.workflows[] | select(.id == $id)' "$CATALOG" >/dev/null 2>&1; then
  pass_cat catalog "workflow ${wf_id} present"
  tree_len="$(jq -r --arg id "$wf_id" '.workflows[] | select(.id == $id) | .composition_tree | length' "$CATALOG")"
  if [[ "$tree_len" -gt 0 ]]; then
    pass_cat catalog "composition_tree has ${tree_len} node(s)"
  else
    fail_cat catalog "composition_tree empty for ${wf_id}"
    remediation "docs/composable-flows-contracts.md — composition_tree"
  fi
  if [[ "$is_composer" -eq 1 ]]; then
    if jq -e --arg id "$wf_id" '.workflows[] | select(.id == $id) | .enforcement_queue' "$CATALOG" >/dev/null 2>&1; then
      pass_cat catalog "enforcement_queue declared"
    else
      fail_cat catalog "enforcement_queue missing for ${wf_id}"
      remediation "docs/APO-AUTHORING-COMPLIANCE.md — enforcement_queue"
    fi
  else
    pass_cat catalog "component workflow — enforcement_queue N/A"
  fi
  bad_refs="$(jq -r --arg id "$wf_id" '
    (.atomic_flows | map(.id)) as $afs |
    (.workflows | map(.id)) as $wfs |
    .workflows[] | select(.id == $id) | .composition_tree[]? |
    if .kind == "atomic_flow" and (.ref | IN($afs[]) | not) then "AF:" + .ref
    elif .kind == "workflow" and (.ref | IN($wfs[]) | not) then "WF:" + .ref
    else empty end
  ' "$CATALOG" | paste -sd, - || true)"
  if [[ -z "$bad_refs" ]]; then
    pass_cat catalog "composition_tree refs resolve"
  else
    fail_cat catalog "orphan composition refs: ${bad_refs}"
    remediation "docs/composable-flows-contracts.md — composer purity"
  fi
else
  fail_cat catalog "workflow ${wf_id} missing"
  remediation "docs/apo-catalog.json — regenerate via scripts/generate-apo-catalog.py"
fi

# --- Category: triple alignment (SKILL ↔ guard ↔ orchestrator pre-exec) ---
echo "--- triple_alignment ---"
# shellcheck source=/dev/null
source "$ORCH_LIB"

normalize_token() {
  local t="$1"
  t="${t#silver:}"
  t="${t#silver-}"
  case "$t" in
    FLOW-QUALITY-GATE|FLOW-QUALITY-GATE-PRESHIP) t="quality-gates" ;;
    FLOW-DEVOPS-QUALITY-GATE-PRESHIP) t="devops-quality-gates" ;;
  esac
  printf '%s' "$t" | tr '[:upper:]' '[:lower:]'
}

to_sorted_csv() {
  local -a items=()
  local item
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    items+=("$(normalize_token "$item")")
  done
  [[ ${#items[@]} -eq 0 ]] && printf '' && return
  printf '%s\n' "${items[@]}" | LC_ALL=C sort -u | paste -sd, -
}

parse_skill_pre_exec() {
  local composer="$1"
  local skill_file="${REPO_ROOT}/skills/${composer}/SKILL.md"
  local -a tokens=()
  local line t

  [[ -f "$skill_file" ]] || return 1

  if grep -q '^\*\*Pre-execution' "$skill_file"; then
    line="$(awk '/^\*\*Pre-execution/ {
      block=$0
      while (getline > 0) {
        if ($0 ~ /^\*\*Post-execution/) break
        block=block " " $0
      }
      print block
      exit
    }' "$skill_file")"
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      [[ "$t" == "silver:spec" || "$t" == "spec" ]] && continue
      tokens+=("$t")
    done < <(printf '%s' "$line" | grep -oE '`[^`]+`' | tr -d '`')
  elif grep -q '^## Enforcement queue' "$skill_file"; then
    line="$(awk '/^## Enforcement queue/{found=1;next} found && /^## /{exit} found && /`[^`]+`/{print; exit}' "$skill_file")"
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      [[ "$t" == *conditional* ]] && continue
      tokens+=("$t")
    done < <(printf '%s' "$line" | grep -oE '`[^`]+`' | tr -d '`' | head -4)
  elif [[ "$composer" == "silver-fast" ]]; then
    line="$(grep -F 'for Tier 2 requires' "$skill_file" | head -1 || true)"
    for t in silver-quality-gates silver-plan silver-validate; do
      grep -qF "$t" <<< "$line" && tokens+=("$t")
    done
  elif [[ "$composer" == "silver-release" ]]; then
    tokens+=("silver-quality-gates")
  fi

  [[ ${#tokens[@]} -eq 0 ]] && return 1
  to_sorted_csv "${tokens[@]}"
}

parse_guard_pre_exec() {
  local composer="$1"
  local markers_line
  local -a markers=()
  local m

  markers_line="$(sed -n "/^  ${composer})\$/,/^  ;;/p" "$GUARD" | grep 'required_markers=' | head -1 || true)"
  markers_line="${markers_line#*required_markers=(}"
  markers_line="${markers_line%)}"
  for m in $markers_line; do
    markers+=("$m")
  done

  case "$composer" in
    silver-feature|silver-ui|silver-devops|silver-fast|silver-new-workflow|silver-refactor|silver-test)
      markers+=("silver-validate")
      ;;
  esac

  [[ ${#markers[@]} -eq 0 ]] && return 1
  to_sorted_csv "${markers[@]}"
}

parse_orchestrator_pre_exec() {
  local composer="$1"
  local queue pre=() token
  queue="$(sb_orchestrator_default_queue_for_composer "$composer")"

  case "$composer" in
    silver-release)
      to_sorted_csv "$(printf '%s' "$queue" | cut -d, -f1)"
      return
      ;;
    silver-deep-research)
      to_sorted_csv silver-clarify silver-deep-research
      return
      ;;
    silver-new-workflow)
      to_sorted_csv silver-clarify silver-scan silver-plan silver-validate
      return
      ;;
  esac

  IFS=',' read -ra parts <<< "$queue"
  for token in "${parts[@]}"; do
    [[ "$token" == "silver-execute" ]] && break
    pre+=("$token")
  done
  to_sorted_csv "${pre[@]}"
}

if [[ "$is_composer" -eq 1 ]]; then
  if [[ -f "${REPO_ROOT}/skills/${skill}/SKILL.md" ]]; then
    skill_set="$(parse_skill_pre_exec "$skill" 2>/dev/null || true)"
    guard_set="$(parse_guard_pre_exec "$skill" 2>/dev/null || true)"
    orch_set="$(parse_orchestrator_pre_exec "$skill" 2>/dev/null || true)"

    if [[ -n "$skill_set" && -n "$guard_set" && "$skill_set" == "$guard_set" ]]; then
      pass_cat triple_alignment "SKILL pre-exec == guard markers"
    elif [[ -z "$skill_set" ]]; then
      fail_cat triple_alignment "SKILL pre-exec markers not parseable"
      remediation "skills/${skill}/SKILL.md — Enforcement queue / Pre-execution section"
    else
      fail_cat triple_alignment "SKILL pre-exec [${skill_set}] != guard [${guard_set}]"
      remediation "hooks/workflow-chain-guard.sh — required_markers for ${skill}"
    fi

    if [[ -n "$guard_set" && -n "$orch_set" && "$guard_set" == "$orch_set" ]]; then
      pass_cat triple_alignment "guard markers == orchestrator pre-execute"
    else
      fail_cat triple_alignment "guard [${guard_set}] != orchestrator [${orch_set}]"
      remediation "hooks/lib/orchestrator-state.sh — sb_orchestrator_default_queue_for_composer ${skill}"
    fi
  else
    fail_cat triple_alignment "missing skills/${skill}/SKILL.md"
  fi
else
  pass_cat triple_alignment "component workflow — triple alignment N/A"
fi

# --- Category: orchestrator registration ---
echo "--- orchestrator ---"
if [[ "$is_composer" -eq 1 ]]; then
  if grep -q "$skill" "$ORCH_LIB"; then
    pass_cat orchestrator "composer registered in orchestrator-state.sh"
  else
    fail_cat orchestrator "composer missing from orchestrator-state.sh"
    remediation "hooks/lib/orchestrator-state.sh"
  fi
else
  pass_cat orchestrator "component workflow — orchestrator registration N/A"
fi

# --- Category: flow steps / V-loops (catalog entity resolves) ---
echo "--- flow_steps ---"
if [[ "$is_composer" -eq 1 ]]; then
  entity="$(jq -r --arg s "$skill" '.migration_map.skill_to_entity[$s] // empty' "$CATALOG")"
else
  entity=""
fi
if [[ -n "$entity" ]]; then
  if [[ "$entity" == AF-* ]]; then
    if jq -e --arg id "$entity" '.atomic_flows[] | select(.id == $id)' "$CATALOG" >/dev/null 2>&1; then
      vloop="$(jq -r --arg id "$entity" '.atomic_flows[] | select(.id == $id) | .v_loop.id // .v_loop.ref // empty' "$CATALOG")"
      if [[ -n "$vloop" ]]; then
        pass_cat flow_steps "atomic flow ${entity} has v_loop ${vloop}"
      else
        fail_cat flow_steps "atomic flow ${entity} missing v_loop"
        remediation "docs/composable-flows-contracts.md — V-loop per AF"
      fi
    else
      fail_cat flow_steps "atomic flow ${entity} not in catalog"
    fi
  else
    pass_cat flow_steps "skill maps to workflow-level entity ${entity}"
  fi
elif [[ "$is_composer" -eq 0 ]]; then
  pass_cat flow_steps "component workflow — entity mapping N/A"
else
  fail_cat flow_steps "skill_to_entity empty for composer ${skill}"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "VERDICT: PASS"
  exit 0
fi
echo "VERDICT: FAIL"
exit 1
