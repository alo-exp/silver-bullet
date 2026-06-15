# shellcheck shell=bash
# Canonical quality-gates mode detection — shared by record-skill, completion-audit,
# workflow-chain-guard, and skills/silver-quality-gates Step 0.

sb_qg_find_artifact() {
  local repo_root="$1"
  local pattern="$2"
  local f
  for f in \
    "$repo_root/.planning/$pattern" \
    "$repo_root/.planning/phases"/*/"$pattern" \
    "$repo_root/.planning/phases"/*/*-"$pattern"; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    printf '%s' "$f"
    return 0
  done
  return 1
}

sb_qg_artifact_has_body() {
  local file="$1"
  local body
  body="$(grep -vE '^#|^$|^\s*$|^\|[-: ]+\|' "$file" 2>/dev/null | head -5 | tr -d '[:space:]' || true)"
  [[ -n "$body" ]]
}

sb_qg_verification_passed() {
  local file="$1"
  grep -qiE 'status:[[:space:]]*passed' "$file" 2>/dev/null
}

# Returns design or adversarial (matches silver-quality-gates SKILL Step 0).
sb_qg_detect_mode() {
  local repo_root="$1"
  local plan_file verify_file
  plan_file="$(sb_qg_find_artifact "$repo_root" "PLAN.md" 2>/dev/null || true)"
  verify_file="$(sb_qg_find_artifact "$repo_root" "VERIFICATION.md" 2>/dev/null || true)"
  if [[ -n "$plan_file" && -n "$verify_file" ]] \
     && sb_qg_artifact_has_body "$plan_file" \
     && sb_qg_artifact_has_body "$verify_file" \
     && sb_qg_verification_passed "$verify_file"; then
    printf 'adversarial'
    return 0
  fi
  printf 'design'
}

sb_qg_mode_marker() {
  case "${1:-design}" in
    adversarial) printf 'silver-quality-gates-adversarial' ;;
    *) printf 'silver-quality-gates-design' ;;
  esac
}

sb_dqg_mode_marker() {
  case "${1:-design}" in
    adversarial) printf 'devops-quality-gates-adversarial' ;;
    *) printf 'devops-quality-gates-design' ;;
  esac
}

sb_qg_state_has_marker() {
  local state_contents="$1"
  local marker="$2"
  printf '%s\n' "$state_contents" | grep -Fqx -- "$marker" 2>/dev/null
}

# Pre-plan chain: design marker or legacy silver-quality-gates only.
sb_qg_preplan_marker_recorded() {
  local state_contents="$1"
  sb_qg_state_has_marker "$state_contents" "silver-quality-gates-design" && return 0
  sb_qg_state_has_marker "$state_contents" "silver-quality-gates" && return 0
  return 1
}

# Delivery gate: adversarial marker required when VERIFICATION.md passed.
sb_qg_pre_ship_marker_recorded() {
  local state_contents="$1"
  sb_qg_state_has_marker "$state_contents" "silver-quality-gates-adversarial"
}

sb_qg_repo_requires_pre_ship_marker() {
  local repo_root="$1"
  local plan_file verify_file
  plan_file="$(sb_qg_find_artifact "$repo_root" "PLAN.md" 2>/dev/null || true)"
  verify_file="$(sb_qg_find_artifact "$repo_root" "VERIFICATION.md" 2>/dev/null || true)"
  [[ -n "$plan_file" && -n "$verify_file" ]] \
    && sb_qg_artifact_has_body "$plan_file" \
    && sb_qg_artifact_has_body "$verify_file" \
    && sb_qg_verification_passed "$verify_file"
}

# DevOps IaC quality gates — same design/adversarial split as product QG.
sb_dqg_preplan_marker_recorded() {
  local state_contents="$1"
  sb_qg_state_has_marker "$state_contents" "devops-quality-gates-design" && return 0
  sb_qg_state_has_marker "$state_contents" "devops-quality-gates" && return 0
  return 1
}

sb_dqg_pre_ship_marker_recorded() {
  local state_contents="$1"
  sb_qg_state_has_marker "$state_contents" "devops-quality-gates-adversarial"
}
