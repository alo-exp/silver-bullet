---
quick_id: 260410-lsp
description: Update automatic model routing scheme
date: 2026-04-10
---

# Summary: Update Model Routing Scheme

## Changes

### model-profiles.cjs
- Added 5 missing agents: `gsd-code-reviewer`, `gsd-security-auditor`, `gsd-code-fixer`, `gsd-advisor-researcher`, `gsd-assumptions-analyzer`
- Reorganized agents into semantic categories (Design, Review, Verification, Deep reasoning, Execution, Research, Structured output)
- Updated balanced profile: all Design/Review/Verification agents → Opus, Execution/Research → Sonnet, Structured output → Haiku
- Moved `gsd-research-synthesizer` from sonnet → haiku in balanced (structured consolidation, no complex reasoning)
- Promoted `gsd-roadmapper` from sonnet → opus in balanced (design agent)
- Promoted all review/verification agents from sonnet → opus in balanced

### model-profiles.md
- Synced profile table with model-profiles.cjs
- Added category headers to table for clarity
- Updated balanced profile philosophy description
- Updated design rationale sections

## Balanced Profile Summary

| Category | Model | Agents |
|----------|-------|--------|
| Design | Opus | planner, roadmapper, ui-researcher |
| Review | Opus | plan-checker, code-reviewer, security-auditor, integration-checker, ui-checker, ui-auditor |
| Verification | Opus | verifier, doc-verifier, nyquist-auditor |
| Deep reasoning | Opus | debugger |
| Execution | Sonnet | executor, code-fixer, doc-writer |
| Research | Sonnet | phase-researcher, project-researcher, advisor-researcher |
| Structured output | Haiku | codebase-mapper, research-synthesizer, assumptions-analyzer |
