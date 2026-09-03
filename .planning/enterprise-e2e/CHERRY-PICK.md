# Cherry-pick log — enterprise E2E round 6

## 2026-07-02 — wire row-pass registry after cursor cherry-pick

| Field | Value |
|-------|-------|
| Fix | `fix(e2e): wire row-pass registry after cursor cherry-pick` |
| main base | `6f86e144` (cherry-pick Cursor strict-clean harness) |
| Files | `tests/scripts/test-claude-agent-surface-isolation.sh`, `docs/testing/outcome-criteria-registry.json`, `.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md` |

**Why:** Cherry-pick `6f86e144` wired structural checks for `test-claude-agent-surface-isolation.sh` and OUT-SURFACE-01 scoring in `enterprise-e2e-outcome-assessment.sh` but omitted the test script and registry/rubric entry (27/28 criteria). `test-outcome-assessment.sh` failed 84/86.

**Verify:**

```bash
bash tests/scripts/test-outcome-assessment.sh          # 87/87
bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh  # 184/184
bash tests/scripts/test-enterprise-e2e-test-app-branch.sh       # 21/21
```

## 2026-06-30 — routing-only row 1 outcome scoring

| Field | Value |
|-------|-------|
| Fix | `fix(e2e): routing-only row 1 outcome scoring without WBS supervisor` |
| round6 | `af5449bd` on `enterprise-e2e/round6` |
| main | `ee62a820` on `main` |
| Files | `scripts/lib/enterprise-e2e-outcome-assessment.sh`, `docs/testing/outcome-criteria-registry.json`, `tests/scripts/test-outcome-assessment.sh` |

**Why:** Matrix row 1 (`silver-router`) is routing-only. Harness incorrectly required WBS supervisor (`OUT-SUPER-01`), worker handoff, and treated annoyance-level hook watch noise as BLOCK failures.

**Row 1 re-score:** Evidence PASS retained; `enterprise_e2e_outcome_row_passes` → PASS after fix (no TUI re-run; driver **84198** on row 3).

**Verify:**

```bash
bash tests/scripts/test-outcome-assessment.sh
# fixture row 1 enterprise_e2e_outcome_row_passes (routing-only) → PASS
```
