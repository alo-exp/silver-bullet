#!/usr/bin/env bash
# P0-1: Assert composer SKILL.md pre-execution markers align with
# workflow-chain-guard.sh and orchestrator-state.sh (pre-silver-execute tokens).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="${REPO_ROOT}/hooks/workflow-chain-guard.sh"
LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

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
  if [[ $# -eq 0 ]]; then
    printf ''
    return
  fi
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    items+=("$(normalize_token "$item")")
  done
  if [[ ${#items[@]} -eq 0 ]]; then
    printf ''
    return
  fi
  printf '%s\n' "${items[@]}" | LC_ALL=C sort -u | paste -sd, -
}

assert_sets_equal() {
  local label="$1" a="$2" b="$3"
  if [[ "$a" == "$b" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  left:  [$a]"
    echo "  right: [$b]"
    FAIL=$((FAIL + 1))
  fi
}

parse_skill_pre_exec() {
  local composer="$1"
  local skill="${REPO_ROOT}/skills/${composer}/SKILL.md"
  local -a tokens=()
  local line t

  [[ -f "$skill" ]] || return 1

  if grep -q '^\*\*Pre-execution' "$skill"; then
    line="$(awk '/^\*\*Pre-execution/ {
      block=$0
      while (getline > 0) {
        if ($0 ~ /^\*\*Post-execution/) break
        block=block " " $0
      }
      print block
      exit
    }' "$skill")"
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      # silver-spec / clarify --spec are conditional when SPEC.md is absent, not default pre-exec.
      [[ "$t" == "silver:spec" || "$t" == "spec" ]] && continue
      [[ "$t" == "silver:clarify --spec" || "$t" == "clarify --spec" ]] && continue
      tokens+=("$t")
    done < <(printf '%s' "$line" | grep -oE '`[^`]+`' | tr -d '`')
  elif grep -q '^## Enforcement queue' "$skill"; then
    line="$(awk '/^## Enforcement queue/{found=1;next} found && /^## /{exit} found && /`[^`]+`/{print; exit}' "$skill")"
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      [[ "$t" == *conditional* ]] && continue
      tokens+=("$t")
    done < <(printf '%s' "$line" | grep -oE '`[^`]+`' | tr -d '`' | head -4)
  elif [[ "$composer" == "silver-fast" ]]; then
    line="$(grep -F 'for Tier 2 requires' "$skill" | head -1 || true)"
    for t in silver-quality-gates silver-plan silver-validate; do
      grep -qF "$t" <<< "$line" && tokens+=("$t")
    done
  elif [[ "$composer" == "silver-release" ]]; then
    tokens+=("silver-quality-gates")
  fi

  if [[ ${#tokens[@]} -eq 0 ]]; then
    return 1
  fi
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

  if [[ ${#markers[@]} -eq 0 ]]; then
    printf ''
    return 1
  fi
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
      # Research has no implementation execute atom. The chain guard only gates
      # the pre-artifact clarify/decide portion so the documentation atom can edit.
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

COMPOSERS=(
  silver
  silver-feature
  silver-ui
  silver-devops
  silver-bugfix
  silver-deep-research
  silver-fast
  silver-release
  silver-new-workflow
  silver-benchmark
  silver-canary
  silver-content
  silver-deploy
  silver-forensics
  silver-incident
  silver-refactor
  silver-retro
  silver-test
)

echo "=== composition triple alignment ==="
for composer in "${COMPOSERS[@]}"; do
  skill_set="$(parse_skill_pre_exec "$composer" || true)"
  guard_set="$(parse_guard_pre_exec "$composer" || true)"
  orch_set="$(parse_orchestrator_pre_exec "$composer")"

  assert_sets_equal "${composer}: SKILL pre-exec == guard markers" "$skill_set" "$guard_set"
  assert_sets_equal "${composer}: guard markers == orchestrator pre-execute" "$guard_set" "$orch_set"
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
