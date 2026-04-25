# Silver Bullet — Retrospectives

## v0.25.0 Issue Capture & Retrospective Scan (2026-04-24)

**Shipped:** 2026-04-24 | **Phases:** 49-54 | **Plans:** 11 | **Requirements:** 24/24

### What Went Well

- **Single-day execution**: All 6 phases completed in ~34 minutes of wall-clock execution time across 113 commits — the wave-based execution model continues to deliver velocity.
- **Security gate caught real issues**: SENTINEL identified SEC-01 (silver-rem `awk -v` injection) during Phase 50; the fix (using `ENVIRON[]` instead) became a documented architectural decision.
- **Pre-release quality gate discipline**: 4-stage quality gate (Rounds 8 and 9 both clean) gave high confidence before tagging — no post-release hotfixes needed.
- **Forensics audit approach**: Dedicating a full phase (52) to audit silver-forensics against gsd-forensics before implementing silver-scan prevented building on a shaky foundation. All 13 gaps caught and fixed.
- **Sequential processing decision**: The decision to enforce sequential session log processing in silver-scan (rather than parallel) was identified early as a correctness requirement (`/silver-add` sequencing constraint prevents duplicate IDs).

### What Was Hard

- **CI false positive (FIXME literal)**: The `test-skill-integrity.sh` CI test uses `grep -ciE '\[TODO\]|\[TBD\]|FIXME'` — no brackets required for FIXME. The word `FIXME` appeared in silver-scan's keyword list documentation, triggering a false positive. Required a post-tag fix commit before the release was clean.
- **UAT gate CWD mismatch**: The `uat-gate.sh` hook checks `.planning/UAT.md` relative to CWD. When Claude Code's primary working directory is a different project (Sourcevo), the hook fires against the wrong directory. Milestone completion steps had to be executed manually.
- **REQUIREMENTS.md traceability table stale**: All 24 entries showed "Pending" status in the original REQUIREMENTS.md despite full implementation — required manual update during archival.

### What to Do Differently

- **Skill integrity test**: Document that `FIXME` is a bare keyword match (no brackets). Consider updating the test comment or adding a known-false-positive exemption mechanism for documentation prose.
- **UAT.md earlier**: Create the UAT checklist earlier in the milestone (not just before gsd-complete-milestone) so the hook never blocks at the wrong moment.
- **VERIFICATION.md for early phases**: Phases 49-52 completed without VERIFICATION.md files (code inspection only). For future milestones, run `/gsd-validate-phase` per phase rather than deferring to the quality gate.
- **VALIDATION.md (Nyquist)**: 0/6 phases had VALIDATION.md files. Advisory only, but worth tracking.

### Tech Debt Deferred

| Item | Severity | Filed |
|------|----------|-------|
| Phases 049-052 missing VERIFICATION.md | Advisory | GSD backlog |
| silver-rem `${INSIGHT:0:60}` bash-only substring | Low | GitHub #61 advisory |
| silver-add SKILL.md 370L (soft doc limit 300L) | Low | GitHub #62 advisory |
| silver-rem SKILL.md 372L (soft doc limit 300L) | Low | GitHub #62 advisory |
| 0/6 phases have VALIDATION.md (Nyquist) | Advisory | GSD backlog |

### Metrics

| Metric | Value |
|--------|-------|
| Timeline | 2026-04-24 → 2026-04-24 (single day) |
| Phases | 6/6 |
| Plans | 11/11 |
| Requirements | 24/24 |
| Execution time | ~34 min |
| Commits | 113 |
| Pre-release gate rounds | 9 (rounds 8 + 9 clean) |
| Security findings | 3 (2 MEDIUM, 1 LOW — all fixed) |
| Quality gate result | PASS (9 dimensions, adversarial mode) |

---

## v0.26.0 Bug Fixes, CI Hardening & Skill Quality (2026-04-25)

**Shipped:** 2026-04-25 | **Phases:** 55-58 | **Plans:** Hotfix-style | **Requirements:** 12/12

### What Went Well

- **Hotfix execution model worked cleanly**: All 4 phases executed as direct commits rather than full gsd-execute-phase workflow. 1339-test suite (18/18 hooks) + 4-stage pre-release quality gate provided equivalent coverage without the planning overhead.
- **SENTINEL v2.3 security audit uncovered real gaps**: Three High findings (H-1/H-2/H-3) in `spec-session-record.sh`, `uat-gate.sh`, `roadmap-freshness.sh` — unvalidated YAML content injected into JSON hook output. Allowlist regex + jq encoding eliminates the injection surface. Finding real issues in hardening mode confirms the value of SENTINEL runs before every release.
- **Release ordering fix (REL-01) eliminated the recurring patch cycle**: Reordering `silver-create-release` to run after `gsd-complete-milestone` archival commits ensures the git tag lands after all milestone artifacts are on the branch. The root cause of every "requires immediate patch" release was this ordering bug.
- **CI jq assertions fill a long-standing coverage gap**: The `required_deploy`/`all_tracked` skill list divergence was previously only caught manually — it missed multiple releases. Automation on every PR means it can't drift silently again.
- **UUID token TOCTOU fix is locale-independent**: The previous `lstart`-based sentinel comparison was a latent correctness bug on non-English systems. UUID token file approach works identically everywhere.

### What Was Hard

- **No formal PLAN.md / VERIFICATION.md artifacts**: Hotfix execution leaves no PLAN.md or VERIFICATION.md files. Evidence of correctness is distributed across git history, the test suite, and pre-release quality gate rounds rather than consolidated per-phase.
- **SENTINEL content injection surface not obvious from code review**: The three H-1/H-2/H-3 hooks looked safe on casual inspection. The injection surface only appeared under adversarial analysis (attacker-controlled YAML field values flowing into JSON shell output). Standard code review would likely miss this class of finding.
- **dev-cycle-check.sh line count over limit**: Phase 55 brought the hook to 312 lines (project soft limit 300). Extracting validation helpers was deferred as SB-B-3 to keep the milestone scope tight.

### What to Do Differently

- **VERIFICATION.md even for hotfix phases**: A one-page verification checklist per phase takes 2 minutes but permanently documents what was tested. Worth the overhead even for tiny phases.
- **Add SENTINEL to CI pre-commit (not just pre-release)**: Running SENTINEL only at release means injection findings accumulate between releases. A lightweight static check on hook files at commit time would catch earlier.
- **Enforce line-count limit at PR time**: The CI workflow already has jq assertions — add a `wc -l` check on all hooks/*.sh files against the 300-line soft limit so SB-B-3 surfaces automatically rather than during milestone audit.

### Tech Debt Deferred

| Item | Severity | Filed |
|------|----------|-------|
| `dev-cycle-check.sh` 312L (vs 300L limit, +4%) — extract validators to `hooks/lib/dev-cycle-validators.sh` | Low | SB-B-3 |
| Phases 55-58 missing VERIFICATION.md | Advisory | GSD backlog |
| `session-log-init.sh` disown-before-touch race (disk-full edge) | Low | Code review I1 |
| `dev-cycle-check.sh` quote-exemption bypass path (narrow) | Low | Code review I2 |
| Stop hook false-positive audit (STOP-01) | Medium | Deferred to v0.27.0+ |

### Metrics

| Metric | Value |
|--------|-------|
| Timeline | 2026-04-25 → 2026-04-25 (single day) |
| Phases | 4/4 |
| Requirements | 12/12 |
| Commits | 26 (since v0.25.1) |
| Files changed | 42 (+2,052 / -228) |
| Pre-release gate rounds | 2 consecutive clean rounds |
| Security findings | 3 High (H-1/H-2/H-3 — all fixed pre-release) |
| Quality gate result | PASS — SENTINEL v2.3 Rounds 2+3 CLEAR |
