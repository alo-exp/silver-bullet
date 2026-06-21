#!/usr/bin/env bash
# P0-2: Workflow Flow Log row labels must match orchestrator CSV mapping order.
set -euo pipefail

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
  rm -rf "$WORK" "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true
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

expected_csv="$(sb_orchestrator_flow_csv_for_workflows silver-feature)"
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

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
