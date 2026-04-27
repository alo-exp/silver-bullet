#!/usr/bin/env bash
# Tests for compliance-status.sh composed-workflow display.
#
# Pass 1 contract (v0.29.x): the legacy single-file `.planning/WORKFLOW.md`
# parsing was retired. compliance-status now reads `.planning/workflows/`
# directory and reports `WORKFLOWS: N active` when files are present, or
# `FLOW: N/A (legacy mode)` when absent / empty.
#
# Pass 2 (deferred) will add per-workflow file parsing for richer FLOW N/M
# progress per active workflow id. Scenarios in this file are tagged
# `Pass1:` for behavior covered now and `Pass2:` for the deferred suite.
#
# Covers (Pass 1):
#   S1 — `WORKFLOWS: N active` shown when `.planning/workflows/<id>.md` files exist
#   S2 — `FLOW: N/A (legacy mode)` shown when neither WORKFLOW.md nor workflows/ dir
#   S3 — Bug-1 fix: workflow status shown in early-exit path (no state file)
#   S5 — Symlinked workflows dir ignored (security): falls back to legacy mode
#   S6 — Empty workflows/ dir → legacy mode fallback
#   S7 — Multiple concurrent workflow files → count accuracy
#
# Out-of-scope (re-introduced in Pass 2):
#   S4 — digit-row inflation guard (no longer applicable; no Flow Log parsing in Pass 1)
#
# All scenarios test compliance-status.sh in isolation via stdin JSON.

set -euo pipefail
source "$(dirname "$0")/helpers/common.sh"

echo "=== Compliance-Status Composed-Workflow Scenarios (Pass 1) ==="

# ── Scenario 1 (Pass 1): workflows/ dir with active files → WORKFLOWS: N active
echo "--- S1: .planning/workflows/<id>.md files present → WORKFLOWS: N active ---"
integration_setup
write_default_config

# Write 2 active workflow files (one composer per file)
mkdir -p "$TMPDIR_TEST/.planning/workflows"
touch "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T021500Z-B2C8RT-silver-bugfix.md"

# Put silver-quality-gates in state so we skip early-exit path
printf 'silver-quality-gates\n' >> "$TMPSTATE"

out=$(run_compliance_status)
assert_contains "S1.1: WORKFLOWS: N active appears in output" "$out" "WORKFLOWS: 2 active"
assert_not_contains "S1.2: legacy mode NOT shown when workflows/ has files" "$out" "N/A (legacy mode)"

integration_teardown

# ── Scenario 2 (Pass 1): no workflows/ dir → legacy mode shown ─────────────
echo "--- S2: No workflows/ dir → legacy mode string in output ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"
# No .planning/workflows directory at all

out=$(run_compliance_status)
assert_contains "S2.1: legacy mode shown when no workflows/ dir" "$out" "FLOW: N/A (legacy mode)"

integration_teardown

# ── Scenario 3 (Pass 1): early-exit path includes workflow status ──────────
echo "--- S3: workflows/ dir + no state file → workflow line in early-exit ---"
integration_setup
write_default_config

mkdir -p "$TMPDIR_TEST/.planning/workflows"
touch "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md"

# State file intentionally absent (don't write anything to TMPSTATE)
rm -f "$TMPSTATE"

out=$(run_compliance_status)
assert_contains "S3.1: workflow status appears in early-exit output" "$out" "WORKFLOWS: 1 active"
assert_not_contains "S3.2: legacy mode NOT shown when workflows/ has files (early-exit)" "$out" "N/A (legacy mode)"

integration_teardown

# Pass 2 will re-add: "S4 — digit-row inflation guard" once Flow Log parsing
# is reintroduced for per-workflow files.

# ── Scenario 5 (Pass 1): symlinked workflows/ dir → ignored, legacy mode ───
echo "--- S5: Symlinked workflows/ dir → ignored (security), legacy mode fallback ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning"
real_wf_dir="/tmp/sb-test-real-workflows-$$"
mkdir -p "$real_wf_dir"
touch "$real_wf_dir/20260428T015523Z-K4F7QA-silver-feature.md"
ln -s "$real_wf_dir" "$TMPDIR_TEST/.planning/workflows"

out=$(run_compliance_status)
assert_contains "S5.1: symlinked workflows/ dir ignored → legacy mode" "$out" "FLOW: N/A (legacy mode)"

rm -rf "$real_wf_dir"
integration_teardown

# ── Scenario 6 (Pass 1): empty workflows/ dir → legacy mode ────────────────
echo "--- S6: Empty workflows/ dir (no files) → legacy mode fallback ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning/workflows"
# No .md files in workflows/ — directory exists but is empty

out=$(run_compliance_status)
assert_contains "S6.1: empty workflows/ dir → legacy mode" "$out" "FLOW: N/A (legacy mode)"

integration_teardown

# ── Scenario 7 (Pass 1): multiple concurrent workflow files → count accuracy ─
echo "--- S7: Multiple concurrent workflows — count is accurate ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning/workflows"
touch "$TMPDIR_TEST/.planning/workflows/20260428T010000Z-AAAAAA-silver-feature.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T011000Z-BBBBBB-silver-bugfix.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T012000Z-CCCCCC-silver-research.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T013000Z-DDDDDD-silver-ui.md"

out=$(run_compliance_status)
assert_contains "S7.1: 4 active workflows counted correctly" "$out" "WORKFLOWS: 4 active"
assert_not_contains "S7.2: not inflated to 5" "$out" "WORKFLOWS: 5 active"

integration_teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
