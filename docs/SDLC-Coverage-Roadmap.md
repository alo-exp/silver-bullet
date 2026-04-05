# Silver Bullet — SDLC Coverage Roadmap

**Created:** 2026-04-06 | **Based on:** `docs/sdlc-gap-analysis.md`
**Purpose:** Translate gap analysis into a versioned roadmap for expanding Silver Bullet toward genuine end-to-end SDLC coverage.

---

## Current State (v0.10.0)

Silver Bullet covers phases 3–8 of the SDLC strongly, with partial coverage of phases 1, 2, and 5. The two ends — discovery/validation (phases 1–2) and production operations (phases 9–12) — are absent or documentation-only.

| SDLC Phase | v0.10.0 Status |
|------------|---------------|
| 1. Discovery & Requirements | ⚠️ AI-inferred — no validation gate |
| 2. Architecture & Design | ⚠️ Conditional on plugin availability |
| 3. Development | ✅ Full GSD execution engine |
| 4. Code Review | ✅ Three-skill triad with ordering enforcement |
| 5. Security | ⚠️ Design checklist only — no scanner integration |
| 6. Testing | ⚠️ Strategy document only — no test execution gate |
| 7. Quality Gates | ✅ 8 dimensions, hard-stop enforcement |
| 8. Release & Deployment | ✅ PR + deploy checklist + release skill |
| 9. Post-Deployment Monitoring | ❌ Absent |
| 10. Incident Response | ❌ Plugin exists, not woven into workflow |
| 11. Feedback & Iteration | ❌ Tech-debt notes only |
| 12. Compliance & Governance | ❌ Absent |

---

## Milestone 1: Test Execution Gate (v0.11)

**Target:** Close GAP 3 — the most impactful gap because it currently allows full workflow completion with zero passing tests.

**What to build:**
- A `/verify-tests` skill (or extend `/gsd:verify-work`) that runs `npm test` / `pytest` / `go test` / `cargo test` and confirms they pass before allowing the PR create step
- Add `verify-tests` to `required_deploy` in the default config
- Hook enforcement: `completion-audit.sh` checks for `verify-tests` in state before allowing `gh pr create`
- Config: `testing.test_command` in `.silver-bullet.json` for project-specific test commands

**Success criterion:** A PR cannot be created unless the test suite was run AND passed within the current session.

**Effort:** Medium — requires running a command and capturing its exit code.

---

## Milestone 2: Security Scanner Integration (v0.12)

**Target:** Close GAP 2 — the gap between "security was considered" and "security was tested."

**What to build:**
- A `/security-scan` skill that automates at least one security check based on project type:
  - JS/TS: `npm audit` for dependency vulnerabilities
  - Python: `pip-audit` or `safety`
  - Any: `git secrets --scan` for credential leaks
- Add `security-scan` to `required_deploy` in the default config
- Results captured in `.planning/SECURITY-SCAN.md`
- The `/quality-gates` skill updated to reference security scanner results if present

**Success criterion:** Dependency vulnerabilities or credential leaks trigger a visible warning (non-blocking for Low, blocking for High/Critical) before PR creation.

**Effort:** Medium — project-type detection + subprocess execution + result parsing.

---

## Milestone 3: Post-Deployment Observability (v0.13)

**Target:** Close GAP 1 — the current hard stop at `/gsd:ship`.

**What to build:**
- A `/post-deploy-check` skill that guides Claude through post-deployment validation:
  - Smoke test commands (configurable in `.silver-bullet.json`)
  - SLO baseline capture (error rate, latency p95)
  - Alerting rule verification
- Add a new `POST-DEPLOY` section to `full-dev-cycle.md` after `/gsd:ship`
- `completion-audit.sh` new tier: `gh release create` requires `post-deploy-check` in state

**Success criterion:** The workflow does not end at PR creation — it ends when production health is confirmed.

**Effort:** High — requires external service integrations (monitoring platform APIs).

---

## Milestone 4: Requirements Validation Gate (v0.14)

**Target:** Close GAP 4 — structured discovery before development begins.

**What to build:**
- A `/requirements-review` skill that produces a `REQUIREMENTS.md` with:
  - User stories with acceptance criteria (Given/When/Then format)
  - Definition of Done at feature level
  - Out-of-scope explicitly listed
- Add `requirements-review` to `required_planning` or as a pre-planning step
- Gate: `dev-cycle-check.sh` Stage A check extended to verify `requirements-review` is recorded before source edits begin

**Success criterion:** Source code cannot be written until requirements are reviewed and acceptance criteria are defined.

**Effort:** Medium — skill creation + hook extension.

---

## Milestone 5: Release Management (v0.15)

**Target:** Close GAP 5 — the gap between "PR merged" and "release published."

**What to build:**
- Extend `/create-release` with:
  - Semantic versioning validation (`patch` / `minor` / `major` classification)
  - CHANGELOG.md auto-generation from commit messages + PR body
  - Migration guide template for breaking changes
- A `/release-notes` skill that produces user-facing release documentation
- Config: `release.version_strategy` in `.silver-bullet.json`

**Success criterion:** Every release has a CHANGELOG entry, semantic version bump justification, and migration notes if there are breaking changes.

**Effort:** Medium — git log parsing + template generation.

---

## Milestone 6: Incident→Fix Feedback Loop (v0.16)

**Target:** Close GAP 6 — weave `/incident-response` into the devops-cycle workflow.

**What to build:**
- Extend `devops-cycle.md` with a mandatory post-incident step:
  - `/incident-response` required after every fast-path incident fix
  - Post-incident review (PIR) template added to docs/
  - Incident learnings automatically linked back to tech-debt tracking
- A `/runbooks` skill that generates operational runbooks from the incident response notes

**Success criterion:** An incident fix cannot be closed without a PIR document and at least one tech-debt item created.

**Effort:** Medium — workflow extension + template creation.

---

## Milestone 7: Feedback & Iteration Loop (v0.17)

**Target:** Close GAP 11 — connect post-ship observations back to requirements.

**What to build:**
- A `/retrospective` skill that produces a session retrospective with:
  - What was built vs. what was planned
  - What went well / what to improve
  - Action items fed back into the next milestone's `REQUIREMENTS.md`
- A `/feature-flag-lifecycle` skill for progressive rollout management
- `gsd:complete-milestone` extended to require retrospective completion

**Success criterion:** Every milestone ends with a retrospective that is automatically linked to the next milestone's discovery phase.

**Effort:** Medium — skill creation + workflow extension.

---

## Long-Term Vision (v1.0)

When all milestones complete, Silver Bullet will cover 11 of 12 SDLC phases (Compliance & Governance remains out of scope for the developer-focused tool). The compliance model will expand from invocation-based to artifact-based for the 4 most critical phases:

1. **Testing**: Pass/fail determined by test suite execution, not strategy document existence
2. **Security**: Vulnerability count/severity from scanner output, not design review completion
3. **Deployment**: Health signal from production, not PR creation
4. **Requirements**: Acceptance criteria existence, not conversation summary

The remaining gap — Compliance & Governance (phase 12) — is addressed via the DevOps workflow's audit trail (session logs, state files, git history) but is not orchestrated by Silver Bullet.

---

## What This Roadmap Is NOT

This roadmap does NOT include:
- Complete rewrite of the enforcement model (invocation → outcome) — too architectural, deferred to post-v1.0
- DAST (dynamic security testing) — requires live environment, out of scope for pre-deploy workflow
- Performance testing at scale — infrastructure-dependent, addressed via DevOps plugins
- Multi-repo / monorepo support — architectural prerequisite needed first
