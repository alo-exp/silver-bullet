# Policy C — Cursor Grok 4.6 High

- **Rung identity:** Cursor Grok 4.6 High (`grok` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - F-4-1

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| F-4-1 | search_cli host support unspecified vs Alumnium Cursor-only rt_host_supported |

### LOW

| ID | Title |
|----|-------|
| F-4-2 | rt_scope_includes_component current-system map is two-way vs live three-way |
| F-4-3 | I-24 packages/scope not on test plan, SKILL examples, or prompt |
| F-4-4 | Unqualified PATH Health ban vs locked PATH+version |
| F-4-5 | D10-routes no-consent PASS vs F2 PASS N/A |
| F-4-6 | Missing provider-missing and PATH-without-version test rows; required_when_enabled false |

### NIT

| ID | Title |
|----|-------|
| F-4-7 | Implementer prompt omits omniroute key and hermetic vendor-doctor |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-4-1 | MED | ACCEPT | Lock search_cli D10 on Cursor/Claude/Codex; do not copy Alumnium fu=1; five-tool/cross_tool stay Cursor-only |
| F-4-2 | LOW | ACCEPT | Document live three-way rt_scope_includes_component including cross_tool |
| F-4-3 | LOW | ACCEPT | Name --fix=packages and rt_scope_includes_component on SKILL examples, test plan, and prompt |
| F-4-4 | LOW | ACCEPT | Qualify PATH/command -v ban as alone; search_cli remains PATH+version |
| F-4-5 | LOW | ACCEPT | no_five_tool_consent is PASS not PASS N/A; coverage N/A rule matches live recorder |
| F-4-6 | LOW | ACCEPT | Add WARN and PATH-without-version rows; keep required_when_enabled false |
| F-4-7 | NIT | ACCEPT | Prompt names omniroute/D10-omniroute and hermetic vendor-doctor path |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-4-1 | MED | search_cli host support | ACCEPT | yes |
| F-4-2 | LOW | three-way scope map | ACCEPT | yes |
| F-4-3 | LOW | packages propagation | ACCEPT | yes |
| F-4-4 | LOW | PATH Health alone | ACCEPT | yes |
| F-4-5 | LOW | D10-routes PASS vs PASS N/A | ACCEPT | yes |
| F-4-6 | LOW | search_cli test rows and required_when_enabled | ACCEPT | yes |
| F-4-7 | NIT | prompt omniroute and vendor-doctor | ACCEPT | yes |

