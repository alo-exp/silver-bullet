# Silver New Workflow — Audit Mode Scenario

## Skill: silver-new-workflow
## Context: Read-only compliance audit for existing catalog-backed workflows

### Scenario: Audit an existing workflow

**Trigger:** "Audit workflow compliance for silver-feature"

**Workflow:**
1. Parent detects Audit mode from trigger (`audit workflow`, `WF-SILVER-*`, or `--audit` flag).
2. Parent resolves target → `silver-feature`, `WF-SILVER-FEATURE`.
3. Parent runs `bash scripts/audit-workflow-compliance.sh --target silver-feature`.
4. Parent writes `.planning/workflow-audit-feature-<date>.md` with per-category PASS/FAIL.
5. Parent returns VERDICT and remediation links — **no edits** to skills, hooks, or catalog.

### Scenario: Validate via workflow id

**Trigger:** `/sb:new-workflow --audit WF-SILVER-NEW-WORKFLOW`

**Workflow:**
1. Resolve `WF-SILVER-NEW-WORKFLOW` → `silver-new-workflow`.
2. Run compliance suite; expect PASS for a known-good meta workflow.
3. Document verdict only.

### Scenario: Convert vs Audit disambiguation

**Trigger:** `/sb:new-workflow skills/silver-legacy/SKILL.md` (no audit flag)

**Mode:** Convert — gap review and promotion path.

**Trigger:** `/sb:new-workflow --audit skills/silver-legacy/SKILL.md`

**Mode:** Audit — read-only compliance report only.
