#!/usr/bin/env bash
# Tests for compliance-status.sh WORKFLOW.md path-progress display
#
# Covers:
#   S1 — FLOW N/M shown when WORKFLOW.md present and state file exists
#   S2 — PATH: N/A (legacy mode) shown when no WORKFLOW.md
#   S3 — Bug-1 fix: PATH progress shown in early-exit path (no state file)
#   S4 — Bug-2 fix: digit-starting rows in other WORKFLOW.md sections don't inflate total
#   S5 — Symlinked WORKFLOW.md ignored (falls back to legacy mode)
#   S6 — Empty / malformed WORKFLOW.md falls back to legacy mode
#   S7 — PATH count correct with mixed complete/pending rows
#
# All scenarios test compliance-status.sh in isolation via stdin JSON.

set -euo pipefail
source "$(dirname "$0")/helpers/common.sh"

echo "=== Compliance-Status PATH Progress Scenarios ==="

# ── Scenario 1: WORKFLOW.md present + state file → FLOW N/M shown ──────────
echo "--- S1: WORKFLOW.md present + state file → FLOW N/M in output ---"
integration_setup
write_default_config

# Write a WORKFLOW.md with 2 complete out of 4 paths
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'EOF'
# Workflow Manifest

## Composition
Intent: "test feature"
Composer: /silver:feature
Mode: interactive

## Flow Log
| # | Flow | Status | Artifacts | Exit |
|---|------|--------|-----------|------|
| 0 | BOOTSTRAP | complete | PROJECT.md | yes |
| 5 | PLAN | complete | PLAN.md | yes |
| 7 | EXECUTE | pending | — | no |
| 11 | VERIFY | pending | — | no |

## Heartbeat
Last-flow: 5
Last-beat: 2026-04-15T00:00:00Z

## Next Flow
FLOW 7 (EXECUTE)
EOF

# Put silver-quality-gates in state so we skip early-exit path
printf 'silver-quality-gates\n' >> "$TMPSTATE"

out=$(run_compliance_status)
assert_contains "S1.1: FLOW N/M appears in output" "$out" "FLOW 2/4"
assert_not_contains "S1.2: legacy mode NOT shown when WORKFLOW.md present" "$out" "N/A (legacy mode)"

integration_teardown

# ── Scenario 2: No WORKFLOW.md → PATH: N/A (legacy mode) shown ─────────────
echo "--- S2: No WORKFLOW.md → legacy mode string in output ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"
# No WORKFLOW.md

out=$(run_compliance_status)
assert_contains "S2.1: legacy mode shown when no WORKFLOW.md" "$out" "FLOW: N/A (legacy mode)"

integration_teardown

# ── Scenario 3 (Bug-1 fix): no state file + WORKFLOW.md → PATH shown ───────
echo "--- S3: Bug-1 fix — no state file + WORKFLOW.md → PATH in early-exit ---"
integration_setup
write_default_config

mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'EOF'
# Workflow Manifest

## Flow Log
| # | Flow | Status | Artifacts | Exit |
|---|------|--------|-----------|------|
| 0 | BOOTSTRAP | complete | PROJECT.md | yes |
| 5 | PLAN | pending | — | no |
| 7 | EXECUTE | pending | — | no |

## Heartbeat
Last-flow: 0

## Next Flow
FLOW 5 (PLAN)
EOF

# State file intentionally absent (don't write anything to TMPSTATE)
rm -f "$TMPSTATE"

out=$(run_compliance_status)
# Before Bug-1 fix: this would show "0 steps | Mode: interactive | GSD 0/5 ..."
# After fix: FLOW 1/3 must appear in the early-exit format string
assert_contains "S3.1: FLOW progress in early-exit output (Bug-1 regression)" "$out" "FLOW 1/3"
assert_not_contains "S3.2: legacy mode NOT shown when WORKFLOW.md present (early-exit)" "$out" "N/A (legacy mode)"

integration_teardown

# ── Scenario 4 (Bug-2 fix): digit-starting rows in other sections don't count ─
echo "--- S4: Bug-2 fix — other digit-starting rows don't inflate PATH total ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'EOF'
# Workflow Manifest

## Composition
Intent: "test"
Composer: /silver:feature
Mode: autonomous

## Flow Log
| # | Flow | Status | Artifacts | Exit |
|---|------|--------|-----------|------|
| 0 | BOOTSTRAP | complete | PROJECT.md | yes |
| 5 | PLAN | complete | PLAN.md | yes |
| 7 | EXECUTE | pending | — | no |

## Phase Iterations
| Phase | Status |
|-------|--------|
| 01 (feature-phase) | FLOW 5 complete, FLOW 7 pending |

## Autonomous Decisions
| Timestamp | Decision | Rationale |
|-----------|----------|-----------|
| 2026-04-15T10:00:00Z | Skipped FLOW 4 | No SPEC.md found |
| 2026-04-15T10:05:00Z | Auto-confirmed composition | autonomous mode |

## Heartbeat
Last-flow: 5

## Next Flow
FLOW 7 (EXECUTE)
EOF

out=$(run_compliance_status)
# Total rows: 3 in Path Log. Phase Iterations row starts with '| 01' and
# Autonomous Decisions rows start with '| 2026'. Bug-2 fix prevents those
# from being counted as Path Log entries.
# Correct: FLOW 2/3 (2 complete, 3 total)
# Buggy:   FLOW 2/6 (2 complete, 3+1+2=6 total)
assert_contains "S4.1: FLOW total is 3, not 6 (Bug-2 regression)" "$out" "FLOW 2/3"
assert_not_contains "S4.2: inflated count FLOW 2/6 not present" "$out" "FLOW 2/6"

integration_teardown

# ── Scenario 5: Symlinked WORKFLOW.md → ignored, legacy mode shown ──────────
echo "--- S5: Symlinked WORKFLOW.md → ignored (security), legacy mode fallback ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning"
real_wf="/tmp/sb-test-real-workflow-$$.md"
cat > "$real_wf" << 'EOF'
## Flow Log
| # | Flow | Status | Artifacts | Exit |
|---|------|--------|-----------|------|
| 0 | BOOTSTRAP | complete | PROJECT.md | yes |
EOF
ln -s "$real_wf" "$TMPDIR_TEST/.planning/WORKFLOW.md"

out=$(run_compliance_status)
assert_contains "S5.1: symlinked WORKFLOW.md ignored → legacy mode" "$out" "FLOW: N/A (legacy mode)"

rm -f "$real_wf"
integration_teardown

# ── Scenario 6: Malformed WORKFLOW.md (no Path Log rows) → legacy mode ──────
echo "--- S6: Malformed WORKFLOW.md (no path rows) → legacy mode fallback ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning"
echo "This file has no path log rows at all." > "$TMPDIR_TEST/.planning/WORKFLOW.md"

out=$(run_compliance_status)
assert_contains "S6.1: no valid path rows → legacy mode" "$out" "FLOW: N/A (legacy mode)"

integration_teardown

# ── Scenario 7: Mixed complete/pending rows → correct counts ────────────────
echo "--- S7: Mixed complete/pending — count accuracy across full 7-path composition ---"
integration_setup
write_default_config
printf 'silver-quality-gates\n' >> "$TMPSTATE"

mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'EOF'
# Workflow Manifest

## Flow Log
| # | Flow | Status | Artifacts | Exit |
|---|------|--------|-----------|------|
| 0 | BOOTSTRAP | complete | PROJECT.md, ROADMAP.md | yes |
| 1 | ORIENT | complete | intel/codebase.md | yes |
| 5 | PLAN | complete | PLAN.md | yes |
| 7 | EXECUTE | complete | SUMMARY.md | yes |
| 11 | VERIFY | pending | — | no |
| 13 | SHIP | pending | — | no |
| 17 | RELEASE | pending | — | no |

## Heartbeat
Last-flow: 7

## Next Flow
FLOW 11 (VERIFY)
EOF

out=$(run_compliance_status)
assert_contains "S7.1: 4 complete flows counted correctly" "$out" "FLOW 4/7"
assert_not_contains "S7.2: 7 total (not inflated)" "$out" "FLOW 4/8"
assert_not_contains "S7.3: 7 total (not inflated)" "$out" "FLOW 4/9"

integration_teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
