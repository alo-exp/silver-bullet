# Release Security Audit - v0.38.0 Candidate

Date: 2026-06-11
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
- Release creation remains blocked until quality-gate markers, full-suite rerun, live matrices, verify-tests freshness, and release-commit CI are present.

