#!/usr/bin/env bash
# Run the APO authoring compliance suite (see docs/APO-AUTHORING-COMPLIANCE.md).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
FAILED=()

run_test() {
  local label="$1"
  shift
  echo ""
  echo "=== $label ==="
  if "$@"; then
    ((PASS++)) || true
    echo "OK: $label"
  else
    ((FAIL++)) || true
    FAILED+=("$label")
    echo "FAILED: $label" >&2
  fi
}

TESTS=(
  "apo-catalog-schema|bash tests/scripts/test-apo-catalog-schema.sh"
  "apo-catalog-sot|bash tests/scripts/test-apo-catalog-sot.sh"
  "apo-composition-sot|bash tests/scripts/test-apo-composition-sot.sh"
  "apo-derived-views|bash tests/scripts/test-apo-derived-views.sh"
  "apo-evidence-intent|bash tests/scripts/test-apo-evidence-intent.sh"
  "apo-hierarchy-integrity|bash tests/scripts/test-apo-hierarchy-integrity.sh"
  "atomic-flow-dedup|bash tests/scripts/test-atomic-flow-dedup.sh"
  "atomic-flow-nonredundancy|bash tests/scripts/test-atomic-flow-nonredundancy.sh"
  "atomic-flow-vloop|bash tests/scripts/test-atomic-flow-vloop.sh"
  "canonical-alias-mapping|bash tests/scripts/test-canonical-alias-mapping.sh"
  "composer-purity|bash tests/scripts/test-composer-purity.sh"
  "composition-triple-alignment|bash tests/scripts/test-composition-triple-alignment.sh"
  "dynamic-composition-audit|bash tests/scripts/test-dynamic-composition-audit.sh"
  "opted-in-tool-enforcement|bash tests/scripts/test-opted-in-tool-enforcement.sh"
  "parallel-scheduling-safety|bash tests/scripts/test-parallel-scheduling-safety.sh"
  "router-coverage|bash tests/scripts/test-router-coverage.sh"
  "site-doc-freshness|bash tests/scripts/test-site-doc-freshness.sh"
  "skill-hierarchy-classification|bash tests/scripts/test-skill-hierarchy-classification.sh"
  "step-vloop-runtime-rollup|bash tests/scripts/test-step-vloop-runtime-rollup.sh"
  "triple-alignment|bash tests/scripts/test-triple-alignment.sh"
  "user-intent-coverage|bash tests/scripts/test-user-intent-coverage.sh"
  "worker-template-parity|bash tests/scripts/test-worker-template-parity.sh"
  "agent-delegation-contract|bash tests/scripts/test-agent-delegation-contract.sh"
  "agent-delegation-catalog|bash tests/scripts/test-agent-delegation-catalog-contract.sh"
  "agent-delegate-common|bash tests/scripts/test-agent-delegate-common.sh"
  "generate-apo-artifacts|python3 scripts/generate-apo-artifacts.py --check"
)

for entry in "${TESTS[@]}"; do
  label="${entry%%|*}"
  cmd="${entry#*|}"
  # shellcheck disable=SC2086
  run_test "$label" bash -c "$cmd"
done

echo ""
echo "=== Summary ==="
echo "PASS: $PASS / ${#TESTS[@]}"
echo "FAIL: $FAIL / ${#TESTS[@]}"
if ((${#FAILED[@]})); then
  echo "Failed checks:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
