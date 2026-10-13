# Policy C — Cursor Gemini 3.7 Flash High

- **Rung identity:** Cursor Gemini 3.7 Flash High (`gemini` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:** none

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| — | **none** |

### LOW

| ID | Title |
|----|-------|
| F-3-1 | Phase 1 omits rt_scope_includes_component packages for search_cli |

### NIT

| ID | Title |
|----|-------|
| F-3-2 | Duplicate stale checks.sh test-plan rows |
| F-3-3 | Self-nested .planning freeze links from PRD |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-3-1 | LOW | ACCEPT | Phase 1 step 2 must add search_cli to rt_scope_includes_component packages (host only if MCP/hooks exist) |
| F-3-2 | NIT | ACCEPT | Merge duplicate stale checks.sh test rows |
| F-3-3 | NIT | ACCEPT | Use sibling router_subagent_surfaces_85bf9f09.plan.md from the PRD |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-3-1 | LOW | rt_scope_includes_component packages | ACCEPT | yes |
| F-3-2 | NIT | Duplicate checks.sh rows | ACCEPT | yes |
| F-3-3 | NIT | Sibling freeze links | ACCEPT | yes |

