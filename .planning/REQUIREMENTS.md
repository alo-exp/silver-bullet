# Requirements: Silver Bullet v0.26.0

**Defined:** 2026-04-25
**Core Value:** Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually does" — 7 compliance layers, zero single-point-of-bypass, complete user hand-holding from start to finish.

## v1 Requirements

Requirements for v0.26.0. Each maps to roadmap phases.

### Bug Fixes

- [x] **BUG-01**: T2-1 test case in `tests/hooks/test-timeout-check.sh` passes (root cause identified; hook emits expected string or test expectation corrected with rationale)
- [x] **BUG-02**: `docs/internal/pre-release-quality-gate.md` stage-marker steps removed or corrected so `dev-cycle-check.sh` does not block their execution; hook regex tightened to avoid matching the pattern inside string literals (e.g. heredocs, `gh issue create` bodies)
- [x] **BUG-03**: `silver-add` `gh auth` OAuth scope check uses precise regex `grep -qE '(Token scopes|Scopes):.*\bproject\b'` instead of broad `grep -q 'project'`
- [x] **BUG-04**: `silver-remove` sed command replaced with portable tmpfile+mv pattern that works on both macOS and Linux/CI
- [x] **BUG-05**: `session-log-init.sh` sentinel TOCTOU fix uses UUID token file rather than locale-sensitive `lstart` string comparison

### CI Hardening

- [x] **CI-01**: GitHub Actions CI step added that fails the build when `docs/workflows/` and `templates/workflows/` diverge (diff step runs on every PR and push to main)
- [x] **CI-02**: GitHub Actions CI step added that fails the build if any `required_deploy` skill is absent from `all_tracked`, and if `.silver-bullet.json` skills diverge from `templates/silver-bullet.config.json.default`

### Skill Quality

- [x] **QUAL-01**: Session log discovery pattern (`ls | sort | tail -1`) standardized to `find docs/sessions -maxdepth 1 -name '*.md' -print | sort | tail -1` across `silver-add`, `silver-rem`, and `silver-release` skills
- [x] **QUAL-02**: `silver-rem` INDEX.md mutation steps include explicit `awk`/`sed` commands for both table-row insertion and pointer-line replacement (no prose-only instructions)
- [x] **QUAL-03**: `silver-scan` Step 4 adds a local-tracker cross-reference check (Step 4-iv): when `issue_tracker != 'github'`, grep `docs/issues/ISSUES.md` and `docs/issues/BACKLOG.md` to exclude already-filed candidates from re-presentation
- [x] **QUAL-04**: `silver-scan` summary block explains the two-pass counter structure (deferred items `CANDIDATE_COUNT` vs knowledge/lessons `KL_FOUND`) to avoid user confusion

### Release Ordering (Pre-completed)

- [x] **REL-01**: `silver-release` workflow reordered so `silver-create-release` (tag + GitHub Release) runs AFTER `gsd-complete-milestone`; `silver-create-release` updated to commit CHANGELOG.md entry and README version badge before creating the tag — eliminates mandatory post-release patch (committed: 94835ee)

## Future Requirements

### Stop Hook Robustness

- **STOP-01**: All known Stop hook false-positive scenarios enumerated, tested, and fixed (requires systematic audit — deferred to v0.27.0+)

### Agent SDK Integration

- **AGENT-01**: Hooks fire correctly in Claude Agent SDK / claude.ai/code session contexts (complex platform dependency — deferred)

## Out of Scope

| Feature | Reason |
|---------|--------|
| PATH layer parallelism | High effort dependency analysis + parallel design — deferred |
| SDLC coverage expansion (v0.11–v0.17) | 7-milestone initiative, too large for this release |
| Skill Gap Check / portals | Requires skill registry integration design |
| SB-only install path docs | Low-effort but not a bug — deferred to docs milestone |
| GSD comparison document | Research + writing — deferred to docs milestone |
| Interactive CLAUDE.md conflict resolution in /silver:init | Merge logic design needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | Phase 55 | Complete |
| BUG-02 | Phase 55 | Complete |
| BUG-03 | Phase 56 | Complete |
| BUG-04 | Phase 56 | Complete |
| BUG-05 | Phase 55 | Complete |
| CI-01 | Phase 57 | Complete |
| CI-02 | Phase 57 | Complete |
| QUAL-01 | Phase 56 | Complete |
| QUAL-02 | Phase 56 | Complete |
| QUAL-03 | Phase 58 | Complete |
| QUAL-04 | Phase 58 | Complete |
| REL-01 | Phase 55 | Complete |

**Coverage:**
- v1 requirements: 12 total (12/12 complete)
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-25*
*Last updated: 2026-04-25 — all 12 requirements complete (phases 55-58)*
