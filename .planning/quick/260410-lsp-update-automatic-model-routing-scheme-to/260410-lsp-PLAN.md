---
quick_id: 260410-lsp
description: Update model routing to add missing agents and revise balanced profile
tasks: 2
---

# Quick Plan: Update Model Routing Scheme

## Task 1: Update model-profiles.cjs

**Files:** `~/.claude/get-shit-done/bin/lib/model-profiles.cjs`
**Action:** Add missing agents and update balanced profile assignments

### Missing agents to add:
- `gsd-security-auditor` (used in secure-phase.md)
- `gsd-advisor-researcher` (used in discuss-phase.md)
- `gsd-code-reviewer` (used in code-review.md, quick.md, code-review-fix.md)
- `gsd-code-fixer` (used in code-review-fix.md)
- `gsd-assumptions-analyzer` (used in discuss-phase-assumptions.md)

### New balanced profile assignments:

**Opus (Design/Review/Verification):**
- gsd-planner → opus (design)
- gsd-roadmapper → opus (design)
- gsd-verifier → opus (verification)
- gsd-plan-checker → opus (review)
- gsd-integration-checker → opus (review)
- gsd-ui-researcher → opus (design)
- gsd-ui-checker → opus (review)
- gsd-ui-auditor → opus (review)
- gsd-code-reviewer → opus (review) [NEW]
- gsd-security-auditor → opus (review) [NEW]
- gsd-doc-verifier → opus (verification)
- gsd-nyquist-auditor → opus (verification)
- gsd-debugger → opus (needs deep reasoning)

**Sonnet (Default — execution & research):**
- gsd-executor → sonnet
- gsd-phase-researcher → sonnet
- gsd-project-researcher → sonnet
- gsd-doc-writer → sonnet
- gsd-advisor-researcher → sonnet [NEW]
- gsd-code-fixer → sonnet [NEW]

**Haiku (Structured output, no complex reasoning):**
- gsd-codebase-mapper → haiku
- gsd-research-synthesizer → haiku
- gsd-assumptions-analyzer → haiku [NEW]

**Verify:** Run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs resolve-model gsd-code-reviewer --raw` and confirm it returns expected model.

## Task 2: Update model-profiles.md reference doc

**Files:** `~/.claude/get-shit-done/references/model-profiles.md`
**Action:** Sync the profile table with the updated model-profiles.cjs, add missing agents, update balanced column values.
