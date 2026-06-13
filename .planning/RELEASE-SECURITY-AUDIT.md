# Release Security Audit - v0.39.0 Candidate

Date: 2026-06-12
Method: SENTINEL-style adversarial audit, two-pass release gate
Scope: SB-owned lifecycle absorption changes, hook enforcement, skill recording, release gates, installers, public release metadata

## Verdict

PASS after remediation.

## Pass 1 Finding

### SEC-1: State marker membership used regex matching

Severity: Medium

Affected files:

- `hooks/lib/required-skills.sh`
- `hooks/record-skill.sh`
- `hooks/workflow-chain-guard.sh`
- `hooks/compliance-status.sh`
- `hooks/stop-check.sh`
- `hooks/prompt-reminder.sh`
- `hooks/dev-cycle-check.sh`
- `hooks/completion-audit.sh`
- `hooks/record-requested-skill.sh`
- `scripts/deploy-gate-snippet.sh`

Several state-marker checks used `grep -qx` or `grep -nx` with unescaped dynamic marker names. The practical inputs are mostly controlled SB marker names, but release and workflow gates should treat markers as literal state records, never regular expressions. Regex semantics could create false positives/negatives for custom configured markers and weaken gate predictability.

Remediation:

- Replaced marker membership checks with `grep -Fqx --`.
- Replaced marker line lookup with `grep -Fnx --`.
- Re-ran hook suites that exercise skill recording, required-skill aliasing, release-gate markers, workflow admission, completion audit, prompt reminders, compliance status, and stop-check behavior.

### SEC-2: Live route-smoke accepted adapter bypass evidence

Severity: Medium

Affected files:

- `tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh`
- `tests/e2e-live/lib/skill-prompt.sh`
- `tests/e2e-live/test-e2e-live-suite.sh`

The live E2E release gate validated usable response text and workflow state, but
did not verify that a Codex/Kay route-smoke turn invoked the SB adapter before
any other command. A route could therefore do exploratory shell work, then still
pass when the harness recorded state after the fact. That weakens release-gate
integrity for the same surface that guards Quality Gates timing.

Remediation:

- Parse the captured JSONL transcript for each Codex/Kay `silver:*`
  route-smoke turn.
- Ignore hook bridge commands, then require exactly one real command:
  `silver-bullet invoke-skill <route>`.
- Treat route-smoke timeouts as failures rather than controlled fallback passes.
- Tighten the route-smoke prompt to name the exact first-and-only command.

### SEC-3: Desktop exec_command adapter receipts were not recorded

Severity: Medium

Affected files:

- `hooks/lib/tool-input.sh`
- `scripts/silver-bullet`
- `tests/hooks/test-record-skill.sh`

The Codex desktop `exec_command` tool supplies shell text in `tool_input.cmd`,
but the shared tool-input helper only read `tool_input.command`. As a result,
`record-skill` was registered for `exec_command` but could not extract
`bash scripts/silver-bullet invoke-skill <skill>` commands from this environment,
so fresh adapter receipts were not converted into runtime state. The same
release run found that required virtual marker `silver-tdd` could not be invoked
directly through the adapter even though it aliases to hidden skill `tdd`.

Remediation:

- `hooks/lib/tool-input.sh` now reads `tool_input.cmd` as a string or argv list.
- `scripts/silver-bullet` now resolves required-skill aliases before failing
  skill lookup, allowing `silver-tdd` to load the hidden `tdd` skill.
- `tests/hooks/test-record-skill.sh` covers desktop `exec_command` receipt
  recording and direct `silver-tdd` invocation.

## Pass 2 Checks

Clean after remediation:

- `shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh`
- `git diff --check`
- Targeted hook suites:
  - `bash tests/hooks/test-record-skill.sh`
  - `bash tests/hooks/test-record-requested-skill.sh`
  - `bash tests/hooks/test-required-skills-consistency.sh`
  - `bash tests/hooks/test-dependency-skill-check.sh`
  - `bash tests/hooks/test-forbidden-skill-check.sh`
  - `bash tests/hooks/test-workflow-chain-guard.sh`
  - `bash tests/hooks/test-completion-audit.sh`
  - `bash tests/hooks/test-compliance-status.sh`
  - `bash tests/hooks/test-prompt-reminder.sh`
  - `bash tests/hooks/test-stop-check.sh`
- `bash tests/e2e-live/test-e2e-live-suite.sh`
- `bash tests/e2e-live/run-e2e-live-tests.sh`
- Public stale-positioning scan for active release surfaces.
- Secret-pattern scan found no committed secrets. One historical docs line mentions `ANTHROPIC_API_KEY` by name only.

Local note: `gitleaks` and `semgrep` were not installed in this environment. The repository CI secret-scan workflow remains a required post-push release gate.

## Security Invariants Confirmed

- SB core lifecycle gates now use SB-owned markers by default.
- Legacy GSD/Superpowers markers remain compatibility aliases, not required dependency gates.
- Forbidden Superpowers execution modes are still blocked.
- Direct writes into third-party plugin cache paths remain blocked by hook guards.
- State-file paths are scoped to the active runtime state root.
- Codex `silver-bullet invoke-skill` recording requires a fresh adapter receipt before state is updated.
- Desktop `exec_command` payloads now feed the same adapter receipt recorder as
  Bash-shaped payloads.
- Release creation remains blocked until quality-gate markers, full-suite rerun, live matrices, verify-tests freshness, and release-commit CI are present.
