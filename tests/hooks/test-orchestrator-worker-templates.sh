#!/usr/bin/env bash
# Regression: every flow token in default composer queues must resolve to an on-disk worker template.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_OS="$REPO_ROOT/hooks/lib/orchestrator-state.sh"
LIB_PARENT="$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
TEMPLATES="$REPO_ROOT/templates/orchestrator-workers"
CATALOG_INDEX="$REPO_ROOT/docs/generated/atomic-flow-index.json"
PASS=0
FAIL=0

# shellcheck source=hooks/lib/orchestrator-state.sh
source "$LIB_OS"
# shellcheck source=hooks/lib/orchestrator-parent.sh
source "$LIB_PARENT"

assert_template() {
  local skill="$1"
  local template
  template="$(sb_orchestrator_worker_template_for_skill "$skill")"
  if [[ -f "$TEMPLATES/${template}.md" ]]; then
    echo "PASS: $skill -> ${template}.md"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $skill -> missing $TEMPLATES/${template}.md"
    FAIL=$((FAIL + 1))
  fi
}

collect_queue_skills() {
  local composer="$1"
  local repo_root="${2:-}"
  local token skill
  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    case "$token" in
      FLOW-QUALITY-GATE|FLOW-QUALITY-GATE-PRESHIP|FLOW-DEVOPS-QUALITY-GATE-PRESHIP)
        skill="$(sb_orchestrator_flow_to_skill "$token")"
        ;;
      *)
        skill="$(sb_orchestrator_flow_to_skill "$token")"
        ;;
    esac
    printf '%s\n' "$skill"
  done < <(sb_orchestrator_queue_for_composer "$composer" "$repo_root" | tr ',' '\n')
}

assert_queue_matches_catalog() {
  local composer="$1"
  local expected actual
  expected="$(jq -r --arg composer "$composer" '.workflow_enforcement_queues[$composer] // [] | join(",")' "$CATALOG_INDEX")"
  actual="$(sb_orchestrator_default_queue_for_composer "$composer")"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $composer default queue matches catalog index"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $composer default queue drift"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# shellcheck source=hooks/lib/orchestrator-directive.sh
source "$REPO_ROOT/hooks/lib/orchestrator-directive.sh"

echo "=== orchestrator worker template coverage ==="

for composer in silver-feature silver-ui silver-devops silver-bugfix silver-deep-research silver-fast silver-release; do
  assert_queue_matches_catalog "$composer"
  echo "--- $composer queue ---"
  while IFS= read -r skill; do
    [[ -n "$skill" ]] || continue
    assert_template "$skill"
  done < <(collect_queue_skills "$composer" "")
done

# Explicit post-exec tokens referenced by sb_orchestrator_post_exec_queue
post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
while IFS= read -r skill; do
  [[ -n "$skill" ]] || continue
  assert_template "$skill"
done < <(printf '%s' "$post_exec" | tr ',' '\n' | while read -r t; do sb_orchestrator_flow_to_skill "$t"; done)

echo "--- template parity (repo vs plugin package) ---"
PARITY_FAIL=0
for f in "$TEMPLATES"/*.md; do
  base="$(basename "$f")"
  plugin="$REPO_ROOT/plugins/silver-bullet/templates/orchestrator-workers/$base"
  if [[ ! -f "$plugin" ]]; then
    echo "FAIL: plugin missing $base"
    PARITY_FAIL=$((PARITY_FAIL + 1))
    continue
  fi
  expected_file="$(mktemp)"
  sed 's|\${SB_RUNTIME_HOME_ROOT}|$HOME/.codex|g' "$f" > "$expected_file"
  if ! diff -q "$expected_file" "$plugin" >/dev/null 2>&1; then
    echo "FAIL: drift between templates/ and plugins/ for $base"
    PARITY_FAIL=$((PARITY_FAIL + 1))
  else
    echo "PASS: parity $base"
    PASS=$((PASS + 1))
  fi
  rm -f "$expected_file"
done
FAIL=$((FAIL + PARITY_FAIL))

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
