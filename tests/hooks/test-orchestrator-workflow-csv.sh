#!/usr/bin/env bash
# P0-2: Workflow Flow Log row labels must match orchestrator CSV mapping order.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
WORKFLOWS="${REPO_ROOT}/scripts/workflows.sh"
PASS=0
FAIL=0

TEST_RUN_ID="$$"
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT:-/tmp}/.silver-bullet/orch-wf-csv-${TEST_RUN_ID}"
mkdir -p "$SB_TEST_DIR"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"

# shellcheck source=/dev/null
source "$LIB"

cleanup() {
  rm -rf "$WORK" "${WORK_NO_SPEC:-}" "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    echo "  expected: [$expected]"
    echo "  actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_all_complete() {
  local wf="$1"
  local pending
  pending="$(awk -F'|' '/^\| [0-9]+ \|/ { gsub(/ /,"",$4); if ($4 != "complete") print $0 }' "$wf" || true)"
  if [[ -z "$pending" ]]; then
    echo "PASS: all flow rows terminal after complete-flow sweep"
    PASS=$((PASS + 1))
  else
    echo "FAIL: incomplete flow rows remain:"
    printf '%s\n' "$pending"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
git -C "$WORK" init -q
git -C "$WORK" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init
mkdir -p "$WORK/.planning/workflows" "$WORK/scripts"
cp "$WORKFLOWS" "$WORK/scripts/workflows.sh"
chmod +x "$WORK/scripts/workflows.sh"
cat >"$WORK/.planning/SPEC.md" <<'EOF'
spec-version: 1.0
# test spec
EOF

wid="$(cd "$WORK" && sb_orchestrator_on_composer_start silver-feature "csv alignment test" "$WORK")"
[[ -n "$wid" ]] || { echo "FAIL: composer start returned empty workflow id"; exit 1; }

wf_file="$WORK/.planning/workflows/${wid}.md"
[[ -f "$wf_file" ]] || { echo "FAIL: workflow file missing at $wf_file"; exit 1; }

expected_csv="$(sb_orchestrator_flow_csv_for_workflows silver-feature "$WORK")"
IFS=',' read -ra expected_labels <<< "$expected_csv"

row_labels=()
while IFS= read -r row; do
  label="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
  [[ -n "$label" ]] && row_labels+=("$label")
done < <(awk -F'|' '/^\| [0-9]+ \|/ { print $0 }' "$wf_file")

actual_csv="$(IFS=,; printf '%s' "${row_labels[*]}")"
assert_eq "flow log labels match orchestrator CSV order" "$expected_csv" "$actual_csv"

for label in "${expected_labels[@]}"; do
  (cd "$WORK" && bash scripts/workflows.sh complete-flow "$wid" "$label" >/dev/null)
done
assert_all_complete "$wf_file"

assert_eq "silver-handoff label maps to design handoff" "DESIGN HANDOFF" "$(sb_orchestrator_flow_label_for_token silver-handoff)"
assert_eq "flow design handoff token label" "DESIGN HANDOFF" "$(sb_orchestrator_flow_label_for_token FLOW-DESIGN-HANDOFF)"
assert_eq "silver-ensure-docs label maps to document" "DOCUMENT" "$(sb_orchestrator_flow_label_for_token silver-ensure-docs)"
assert_eq "flow document token label" "DOCUMENT" "$(sb_orchestrator_flow_label_for_token FLOW-DOCUMENT)"
assert_eq "security atom label maps to security" "SECURITY" "$(sb_orchestrator_flow_label_for_token security)"
assert_eq "silver-secure atom label maps to secure" "SECURE" "$(sb_orchestrator_flow_label_for_token silver-secure)"
assert_eq "silver-deep-research csv uses document label" "CLARIFY,RESEARCH,DOCUMENT,VALIDATE" "$(sb_orchestrator_flow_csv_for_workflows silver-deep-research)"

WORK_NO_SPEC=$(mktemp -d)
git -C "$WORK_NO_SPEC" init -q
git -C "$WORK_NO_SPEC" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init
mkdir -p "$WORK_NO_SPEC/.planning/workflows" "$WORK_NO_SPEC/scripts"
cp "$WORKFLOWS" "$WORK_NO_SPEC/scripts/workflows.sh"
chmod +x "$WORK_NO_SPEC/scripts/workflows.sh"

no_spec_wid="$(cd "$WORK_NO_SPEC" && sb_orchestrator_on_composer_start silver-feature "csv no spec alignment test" "$WORK_NO_SPEC")"
no_spec_wf_file="$WORK_NO_SPEC/.planning/workflows/${no_spec_wid}.md"
expected_no_spec_csv="$(sb_orchestrator_flow_csv_for_workflows silver-feature "$WORK_NO_SPEC")"
no_spec_csv="$(awk -F'|' '/^\| [0-9]+ \|/ { gsub(/^ +| +$/,"",$3); labels = labels "," $3 } END { sub(/^,/, "", labels); print labels }' "$no_spec_wf_file")"
assert_eq "flow log includes conditional SPECIFY when SPEC.md absent" "$expected_no_spec_csv" "$no_spec_csv"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
