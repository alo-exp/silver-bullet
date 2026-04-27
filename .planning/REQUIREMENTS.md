# Requirements: Silver Bullet v0.28.0

**Milestone:** v0.28.0 — Complete Forge Port — Silver Bullet + All Dependencies
**Defined:** 2026-04-27
**Core Value:** Forge coding agent users get 100% of Silver Bullet's structured workflow enforcement and guidance — same outcome as Claude Desktop, different runtime.

---

## v1 Requirements

### SB Workflow Orchestration Skills (Phase 65)

- [ ] **PORT-SB-01**: Forge user can trigger silver-fast (quick 1–3 file changes with gsd-quick bypass) via Forge skill
- [ ] **PORT-SB-02**: Forge user can trigger silver-init (project setup — AGENTS.md + planning scaffold) via Forge skill
- [ ] **PORT-SB-03**: Forge user can trigger silver-spec (AI-guided spec elicitation, writes SPEC.md) via Forge skill
- [ ] **PORT-SB-04**: Forge user can trigger silver-validate (pre-build spec validation against SPEC.md) via Forge skill
- [ ] **PORT-SB-05**: Forge user can trigger silver-ingest (import JIRA/Figma/Google Docs into SPEC.md + DESIGN.md) via Forge skill
- [ ] **PORT-SB-06**: Forge user can trigger silver-release (cross-artifact review → deploy-checklist → gsd-ship ordering) via Forge skill
- [ ] **PORT-SB-07**: Forge user can trigger silver-migrate (migrate project to new SB version) via Forge skill
- [ ] **PORT-SB-08**: Forge user can trigger silver-update (update Forge port skills to latest version) via Forge skill
- [ ] **PORT-SB-09**: Forge user can trigger silver-scan (retrospective session scan for deferred items) via Forge skill

### SB Quality & Review Skills (Phase 65)

- [ ] **PORT-SB-10**: Forge user can trigger silver-quality-gates (all 9 quality dimensions, auto-detects design-time vs pre-ship mode) via Forge skill
- [ ] **PORT-SB-11**: Forge user can trigger silver-blast-radius (change impact and rollback assessment) via Forge skill
- [ ] **PORT-SB-12**: Forge user can trigger silver-forensics (session post-mortem reconstruction) via Forge skill
- [ ] **PORT-SB-13**: Forge user can trigger silver-review-stats (review analytics — round counts, patterns) via Forge skill
- [ ] **PORT-SB-14**: Forge user can trigger devops-quality-gates (7-dimension IaC quality check) via Forge skill
- [ ] **PORT-SB-15**: Forge user can trigger devops-skill-router (IaC vendor selection guidance) via Forge skill

### SB Capture & Filing Skills (Phase 65)

- [ ] **PORT-SB-16**: Forge user can trigger silver-add (classify + file item to GitHub Issues + project board) via Forge skill
- [ ] **PORT-SB-17**: Forge user can trigger silver-remove (close GitHub issue as "not planned") via Forge skill
- [ ] **PORT-SB-18**: Forge user can trigger silver-rem (record knowledge/lessons insight to monthly docs/) via Forge skill
- [ ] **PORT-SB-19**: Forge user can trigger silver-create-release (create GitHub release with changelog entry) via Forge skill

### SB Artifact Review Skills (Phase 66)

- [ ] **PORT-SB-20**: Forge user can trigger artifact-reviewer (2-pass review loop for any artifact type) via Forge skill
- [ ] **PORT-SB-21**: Forge user can trigger artifact-review-assessor (assess review round quality) via Forge skill
- [ ] **PORT-SB-22**: Forge user can trigger all 9 review-* skills (review-spec, review-design, review-requirements, review-roadmap, review-context, review-research, review-ingestion-manifest, review-uat, review-cross-artifact) via Forge skills

### Superpowers Skills (Phase 66)

- [ ] **PORT-SP-01**: Forge user can trigger systematic-debugging (hypothesis-driven debug cycle) via Forge skill
- [ ] **PORT-SP-02**: Forge user can trigger dispatching-parallel-agents (parallel subagent dispatch pattern) via Forge skill
- [ ] **PORT-SP-03**: Forge user can trigger executing-plans (plan execution with wave-based progress) via Forge skill
- [ ] **PORT-SP-04**: Forge user can trigger subagent-driven-development (SDD pattern for delegated implementation) via Forge skill
- [ ] **PORT-SP-05**: Forge user can trigger using-git-worktrees (worktree-based parallel development) via Forge skill
- [ ] **PORT-SP-06**: Forge user can trigger verification-before-completion (verification gate before declaring done) via Forge skill
- [ ] **PORT-SP-07**: Forge skill finishing-branch updated to latest Superpowers finishing-a-development-branch content

### Anthropic Engineering Skills (Phase 67)

- [ ] **PORT-KW-01**: Forge user can trigger all 10 engineering/* skills (system-design, documentation, deploy-checklist, testing-strategy, architecture, standup, tech-debt, code-review, debug, incident-response) via Forge skills

### Anthropic Design Skills (Phase 67)

- [ ] **PORT-KW-02**: Forge user can trigger all 7 design/* skills (design-critique, research-synthesis, user-research, design-handoff, design-system, ux-copy, accessibility-review) via Forge skills

### Anthropic Product Management Skills (Phase 67)

- [ ] **PORT-KW-03**: Forge user can trigger all 8 product-management/* skills (metrics-review, synthesize-research, write-spec, competitive-brief, sprint-planning, product-brainstorming, stakeholder-update, roadmap-update) via Forge skills

### Anthropic Marketing Skills (Phase 67)

- [ ] **PORT-KW-04**: Forge user can trigger all 8 marketing/* skills (campaign-plan, competitive-brief, brand-review, performance-report, seo-audit, draft-content, content-creation, email-sequence) via Forge skills

### Installer & Templates (Phase 68)

- [ ] **INST-01**: forge-sb-install.sh installs all ~67 skills (SB + Superpowers + Knowledge-Work) to ~/forge/skills/ and .forge/skills/
- [ ] **INST-02**: Global AGENTS.md template routes to all new skill groups with accurate trigger phrases
- [ ] **INST-03**: AGENTS.project.template updated with references to knowledge-work capabilities
- [ ] **INST-04**: Installation runs via `bash forge-sb-install.sh` (local) and `curl -sL ... | bash` (remote) without errors

### End-to-End Verification (Phase 69)

- [ ] **VERIF-01**: A Forge test app copy exists (cloned from existing SB test app) with forge-sb-install.sh applied — AGENTS.md + all skills present
- [ ] **VERIF-02**: Feature development workflow (silver → silver-feature path) runs end-to-end in Forge test app — brainstorm, spec, quality gates, plan, execute, review, verify, ship all work
- [ ] **VERIF-03**: Bug fix workflow (silver → silver-bugfix path) runs end-to-end in Forge test app
- [ ] **VERIF-04**: DevOps workflow (silver → silver-devops path) runs end-to-end in Forge test app
- [ ] **VERIF-05**: Release workflow (silver → silver-release path) runs end-to-end in Forge test app
- [ ] **VERIF-06**: All 9 quality gate dimensions produce correct QUALITY-GATES.md output in Forge test app
- [ ] **VERIF-07**: Forge test app workflow outcomes are documented in a parity report confirming equivalence to SB on Claude Desktop

## Out of Scope

| Feature | Reason |
|---------|--------|
| Hook-based enforcement (completion-audit, stop-check, etc.) | Forge has no hook system; enforcement is instruction-based only |
| silver-bullet.md §0 session-start automation | No hook equivalent in Forge; users run skills explicitly |
| UI workflow (silver-ui path) standalone test | silver-ui builds on silver-feature; covered by PORT-SB in feature workflow test |
| anthropic-skills:* port (schedule, xlsx, pdf, etc.) | Admin/utility skills not part of SB's core development workflow |
| Automatic SB/GSD version check on session start | Forge has no SessionStart hook; excluded by design |
| Plugin system replication | Forge uses SKILL.md files only — plugin boundaries don't apply |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PORT-SB-01 | Phase 65 | Pending |
| PORT-SB-02 | Phase 65 | Pending |
| PORT-SB-03 | Phase 65 | Pending |
| PORT-SB-04 | Phase 65 | Pending |
| PORT-SB-05 | Phase 65 | Pending |
| PORT-SB-06 | Phase 65 | Pending |
| PORT-SB-07 | Phase 65 | Pending |
| PORT-SB-08 | Phase 65 | Pending |
| PORT-SB-09 | Phase 65 | Pending |
| PORT-SB-10 | Phase 65 | Pending |
| PORT-SB-11 | Phase 65 | Pending |
| PORT-SB-12 | Phase 65 | Pending |
| PORT-SB-13 | Phase 65 | Pending |
| PORT-SB-14 | Phase 65 | Pending |
| PORT-SB-15 | Phase 65 | Pending |
| PORT-SB-16 | Phase 65 | Pending |
| PORT-SB-17 | Phase 65 | Pending |
| PORT-SB-18 | Phase 65 | Pending |
| PORT-SB-19 | Phase 65 | Pending |
| PORT-SB-20 | Phase 66 | Pending |
| PORT-SB-21 | Phase 66 | Pending |
| PORT-SB-22 | Phase 66 | Pending |
| PORT-SP-01 | Phase 66 | Pending |
| PORT-SP-02 | Phase 66 | Pending |
| PORT-SP-03 | Phase 66 | Pending |
| PORT-SP-04 | Phase 66 | Pending |
| PORT-SP-05 | Phase 66 | Pending |
| PORT-SP-06 | Phase 66 | Pending |
| PORT-SP-07 | Phase 66 | Pending |
| PORT-KW-01 | Phase 67 | Pending |
| PORT-KW-02 | Phase 67 | Pending |
| PORT-KW-03 | Phase 67 | Pending |
| PORT-KW-04 | Phase 67 | Pending |
| INST-01 | Phase 68 | Pending |
| INST-02 | Phase 68 | Pending |
| INST-03 | Phase 68 | Pending |
| INST-04 | Phase 68 | Pending |
| VERIF-01 | Phase 69 | Pending |
| VERIF-02 | Phase 69 | Pending |
| VERIF-03 | Phase 69 | Pending |
| VERIF-04 | Phase 69 | Pending |
| VERIF-05 | Phase 69 | Pending |
| VERIF-06 | Phase 69 | Pending |
| VERIF-07 | Phase 69 | Pending |

**Coverage:**
- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-27*
*Last updated: 2026-04-27 — traceability expanded to individual requirement rows after roadmap creation*
