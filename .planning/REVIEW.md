---
phase: release-review
reviewed: 2026-06-12T08:45:00Z
depth: adversarial
scope: v0.39.0 dependency absorption release candidate
findings:
  block: 0
  warn: 0
  info: 3
status: clean-after-fix
---

# Release Code Review Report

## Review Request

Scope: assess whether the dependency absorption objective was fulfilled before
cutting the release.

High-risk areas:

- Required skill defaults and legacy alias handling.
- Hook admission/completion behavior.
- Installer defaults for Codex and Claude.
- Generated package parity.
- Public docs and Help Center claims.
- Remaining GSD/Superpowers/Anthropic lifecycle references that imply a hard
  dependency.

Blockers for release:

- Current required planning/deploy lists contain absorbed lifecycle dependency
  markers.
- Default installers bootstrap absorbed lifecycle plugins.
- Public docs claim GSD/Superpowers/Anthropic knowledge-work plugins are
  required for core SB workflows.
- Generated Codex/Claude bundles diverge from source skills/templates.

## Pass 1 Findings

### INFO-1: Public Help Center Had Stale Lifecycle Copy

Several Help Center pages still described current behavior as routing through
GSD execution, GSD verification, GSD fast/quick, GSD UI contract/review, and
GSD release/documentation steps.

Affected surfaces included:

- `site/help/concepts/composable-workflow.html`
- `site/help/concepts/cost-optimization.html`
- `site/help/concepts/routing-logic.html`
- `site/help/concepts/verification.html`
- `site/help/concepts/artifact-review-assessor.html`
- `site/help/concepts/preferences.html`
- `site/help/concepts/documentation.html`
- `site/help/workflows/index.html`
- `site/help/workflows/silver-clarify.html`
- `site/help/workflows/silver-fast.html`
- `site/help/workflows/silver-ui.html`
- `site/help/workflows/silver-bugfix.html`
- `site/help/workflows/silver-release.html`
- `site/help/workflows/silver-devops.html`
- `site/help/workflows/silver-research.html`
- `site/help/search.js`

Severity: INFO, because runtime behavior was already SB-owned, but public docs
would mislead users and fail the release public-content gate.

Disposition: fixed in this release candidate by rewriting these pages around
SB-owned lifecycle skills and optional external extension boundaries.

## Pass 2 Findings

No blocking findings.

### INFO-2: Live Route-Smoke Could Mask Adapter Bypass

The live full-surface harness could report a green route-smoke turn when an
agent produced a usable response and later state was backfilled, even if the
agent did exploratory shell work instead of invoking the SB adapter first.

Issue: https://github.com/alo-exp/silver-bullet/issues/220

Severity: INFO for the release objective, because product behavior was fixed by
the same release candidate, but gate integrity required a regression guard
before release.

Disposition: fixed. Codex/Kay route-smoke turns now parse the captured JSONL
transcript, ignore hook bridge commands, require the first and only real command
to be `silver-bullet invoke-skill <route>`, and fail route-smoke timeouts instead
of accepting them as controlled fallback passes.

### INFO-3: Desktop `exec_command` Did Not Record Adapter Receipts

During the release-gate run, SB hooks enforced the planning floor for
`apply_patch`, but `record-skill` did not create runtime state after
`exec_command` ran `bash scripts/silver-bullet invoke-skill <skill>`.

Issue: https://github.com/alo-exp/silver-bullet/issues/221

Severity: INFO for the release objective, because the failure was in Codex
desktop hook parity rather than the lifecycle absorption content, but it directly
affected SB's ability to prove its own gates in this environment.

Disposition: fixed. `hooks/lib/tool-input.sh` now reads desktop
`tool_input.cmd`, `scripts/silver-bullet` resolves required-skill aliases, and
`tests/hooks/test-record-skill.sh` covers both desktop `exec_command` recording
and the `silver-tdd` virtual marker.

Evidence:

- Active Help Center stale-reference scan returned no matches for current
  `gsd:*`, `gsd-*`, Superpowers helper markers, or retired review/TDD/completion
  markers.
- Required planning/deploy JSON checks passed for `.silver-bullet.json`,
  `templates/silver-bullet.config.json.default`, and
  `plugins/silver-bullet/templates/silver-bullet.config.json.default`.
- `bash tests/e2e-live/test-e2e-live-suite.sh` passed with static assertions for
  transcript validation and route-smoke timeout failure.
- `bash tests/hooks/test-record-skill.sh` passed with regressions for
  `tool_input.cmd` and `silver-tdd`.
- `bash tests/e2e-live/run-e2e-live-tests.sh` passed after the route-smoke
  transcript guard was added.
- `git diff --check` passed.

## Result

PASS after fixing INFO-1. The dependency absorption objective is satisfied for
the reviewed runtime, packaging, and active public documentation surfaces.
