# Policy C — Pi Codex GPT-5.6 Sol High

- **Rung identity:** Pi Codex GPT-5.6 Sol High (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - F-5-1
  - F-5-2
  - F-5-7
- **Mediums:**
  - F-5-3
  - F-5-4
  - F-5-5
  - F-5-6
  - F-5-8
  - F-5-9

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| F-5-1 | Known component id is not a command allowlist for install_commands |
| F-5-2 | Secret-safety tests omit stderr and receipts |
| F-5-7 | Phase 3 Omni install has no WS6 prerequisite or deferral rule |

### MED

| ID | Title |
|----|-------|
| F-5-3 | Every-key --fix is not proved beyond one five-tool fixture |
| F-5-4 | search_cli provider-missing WARN has no reconciler state mapping |
| F-5-5 | Non-TTY --fix without SB_DOCTOR_ASSUME_YES=1 is unspecified |
| F-5-6 | Failed or malformed reconciler apply has no observable outcome |
| F-5-8 | Omni five-CLI host matrix is not operationally defined |
| F-5-9 | Deferred Omni both requires and forbids a coverage-table row |

### LOW

| ID | Title |
|----|-------|
| F-5-10 | cross_tool docs_pin has no satisfiable pin semantics |

### NIT

| ID | Title |
|----|-------|
| — | **none** |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-5-1 | HIGH | ACCEPT | Pin install_commands to repo-owned registry/script or exact argv/digest; known id + swapped payload must refuse |
| F-5-2 | HIGH | ACCEPT | No-secret contract covers stdout, stderr, JSON, and receipts; JSON remains parseable |
| F-5-3 | MED | ACCEPT | Per-component repair-dispatch/plan tests for every advertised --fix; keep one live five-tool fixture |
| F-5-4 | MED | ACCEPT | Provider-missing is ready Health plus advisory warning evidence mapped to doctor WARN |
| F-5-5 | MED | ACCEPT | Non-TTY without assume-yes skips packages/network/daemon, nonzero exit, never hangs |
| F-5-6 | MED | ACCEPT | Failed/malformed apply is not applied, nonzero, stderr kept, receipt honest |
| F-5-7 | HIGH | ACCEPT | Phase 3 gated on landed WS6 installer; if absent, defer with no partial install --fix |
| F-5-8 | MED | ACCEPT | Omni requires the current doctor host CLI only; OpenCode row inspects opencode; Pi is Omni CLI identity not five-tool RT_VALID_HOST |
| F-5-9 | MED | ACCEPT | Deferred Omni is a coverage-table footnote, not an F4 schema row; rows exist only after phase 3 |
| F-5-10 | LOW | ACCEPT | cross_tool docs_pin is the SB five-tool/mutex contract at a Silver Bullet commit/ref |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-5-1 | HIGH | registry-pinned install_commands | ACCEPT | yes |
| F-5-2 | HIGH | secrets on stderr and receipts | ACCEPT | yes |
| F-5-3 | MED | per-component --fix dispatch | ACCEPT | yes |
| F-5-4 | MED | provider-missing WARN mapping | ACCEPT | yes |
| F-5-5 | MED | non-TTY skip/nonzero | ACCEPT | yes |
| F-5-6 | MED | failed-apply observation | ACCEPT | yes |
| F-5-7 | HIGH | Phase 3 WS6 installer gate | ACCEPT | yes |
| F-5-8 | MED | Omni current-host CLI | ACCEPT | yes |
| F-5-9 | MED | deferred Omni footnote | ACCEPT | yes |
| F-5-10 | LOW | cross_tool docs_pin | ACCEPT | yes |

