# Policy C — Pi Codex GPT-5.6 Sol Extra High

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - F-6-1
- **Mediums:**
  - F-6-2
  - F-6-3
  - F-6-4
  - F-6-7
  - F-6-8

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| F-6-1 | Phase 3 omits Omni reconciler registration/dispatch |

### MED

| ID | Title |
|----|-------|
| F-6-2 | --fix=all does not prove composed multi-failure convergence |
| F-6-3 | Vendor-doctor skip has no deterministic final D10 state |
| F-6-4 | /sb:doctor alias is documented, not proven executable |
| F-6-7 | Omni busy/provider-expired lack status and repair mappings |
| F-6-8 | search_cli docs_pin can drift from brew-resolved version |

### LOW

| ID | Title |
|----|-------|
| F-6-5 | TTY confirmation omits decline/EOF/partial-apply semantics |
| F-6-6 | search_cli host support ignores OS/package-manager |

### NIT

| ID | Title |
|----|-------|
| — | **none** |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-6-1 | HIGH | ACCEPT | Phase 3 requires registry, RT_COMPONENT_IDS/extra-tool, rt_run_component, scopes, SKILL, N/A-vs-FAIL — not an inert JSON key |
| F-6-2 | MED | ACCEPT | --fix=all is one invocation that converges all eligible failures; close live first-match break; two-failure fixture |
| F-6-3 | MED | ACCEPT | Vendor skip is not Health evidence; remaining class checks decide; skip never PASSes the component alone |
| F-6-4 | MED | ACCEPT | Phase 2 test: /sb:doctor and /silver:doctor resolve to the same runner and forward --fix/--dry-run |
| F-6-5 | LOW | ACCEPT | TTY decline/EOF: confirm guarded scopes before any writes; no writes; nonzero; receipt not-applied |
| F-6-6 | LOW | ACCEPT | Agent-host Cursor/Claude/Codex stays; brew repair is macOS Homebrew only; missing brew skips packages with Diagnosis |
| F-6-7 | MED | ACCEPT | Busy → WARN no restart; provider expired → WARN, OAuth manual; restart only a dead daemon |
| F-6-8 | MED | ACCEPT | Versioned formula pin in docs_pin; installed version drift is WARN |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-6-1 | HIGH | Omni reconciler registration | ACCEPT | yes |
| F-6-2 | MED | --fix=all composition | ACCEPT | yes |
| F-6-3 | MED | vendor-doctor skip state | ACCEPT | yes |
| F-6-4 | MED | /sb:doctor executable alias | ACCEPT | yes |
| F-6-5 | LOW | TTY decline/EOF | ACCEPT | yes |
| F-6-6 | LOW | search_cli package platform | ACCEPT | yes |
| F-6-7 | MED | Omni busy/expired | ACCEPT | yes |
| F-6-8 | MED | search_cli versioned docs_pin | ACCEPT | yes |

