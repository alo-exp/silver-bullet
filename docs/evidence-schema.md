# SB Cross-Domain Evidence Schema

Silver Bullet normalizes every quality finding across domain audits, quality
gates, code review, test engineering, UI review, security, and verification
into one evidence shape. This schema is the contract for parity with broad
audit surfaces while preserving SB's BLOCK/WARN/INFO and confidence bands
instead of numeric theater.

## Canonical Finding Fields

| Field | Required | Values / content |
|-------|----------|------------------|
| `domain` | Yes | Pack or surface name (`code-health`, `test-health`, `security`, `modularity`, `ui-system`, …) |
| `scope` | Yes | File, route, service, workflow, command, or artifact under review |
| `severity` | Yes | `BLOCK`, `WARN`, or `INFO` |
| `confidence` | Yes | `HIGH`, `MEDIUM`, or `LOW` based on direct evidence quality |
| `evidence` | Yes | File path with line, command output, screenshot, trace, log, or artifact pointer |
| `finding` | Yes | One-sentence description of the defect, risk, or gap |
| `required_action` | Yes | Fix now, file via `sb:add`, accept risk, or not applicable |
| `owner_workflow` | Yes | Owning SB route (`sb:feature`, `sb:bugfix`, `sb:ui`, `sb:devops`, `sb:release`, utility route) |
| `blocking_status` | Yes | `blocks ship`, `blocks release`, `does not block`, or `needs user decision` |
| `backlog_decision` | When deferred | `fixed now`, `filed via sb:add`, `accepted risk`, or `not applicable` |

Do not accept generic claims such as "looks good" or "tests pass" without the
specific evidence pointer that made the claim true.

## Artifact Mapping

| Workflow | Primary artifact | Finding table location |
|----------|------------------|------------------------|
| `sb:domain-audit` | `DOMAIN-AUDIT.md` | `## Findings` |
| `sb:quality-gates` | dimension notes in phase or release context | per-dimension finding rows |
| `sb:review` | `REVIEW.md` | findings section |
| `sb:test` | `TEST-ENGINEERING.md` | quality / anti-pattern findings |
| `sb:ui-review` | `UI-REVIEW.md` | findings section |
| `sb:secure` | `SECURITY.md` | threat / mitigation findings |
| `sb:verify` | `VERIFICATION.md` | gap findings with evidence |

## Severity And Blocking Rules

- `BLOCK` with `HIGH` or `MEDIUM` confidence on a critical gate blocks ship
  unless the user explicitly accepts the risk and the acceptance is recorded.
- `WARN` findings route to `sb:review-triage` or `sb:add` when not
  fixed in the current pass.
- `INFO` findings are advisory unless tied to a release or security invariant.

## Backlog Handoff

When `backlog_decision` is `filed via sb:add`, pass a structured finding to
`sb:add` with domain, scope, severity, evidence pointer, and fingerprint.
See `docs/external-review-policy.md` for review enrichment and
`sb:add` for fingerprinting and prioritization.

## Owning Skills

- `skills/silver-domain-audit/SKILL.md` — pack catalog and critical gates
- `skills/silver-quality-gates/SKILL.md` — eight core dimensions
- `skills/silver-review/SKILL.md` — authoritative code review artifact
- `skills/silver-test/SKILL.md` — test-health findings
- `skills/silver-ui-review/SKILL.md` — UI and accessibility findings
