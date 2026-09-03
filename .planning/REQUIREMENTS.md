# Requirements: Silver Bullet v0.37.0 SDLC Interception And Workflow Enforcement

**Defined:** 2026-05-19
**Core Value:** A single enforced SDLC workflow that turns intent into the right composed process, with no ad hoc technical work and no forgotten user requests.

## v1 Requirements

### SDLC Interception

- [x] **ORCH-01**: Silver Bullet intercepts non-trivial SDLC intent and routes it into a context-tailored composed workflow instead of allowing ad hoc execution. — **Satisfied** Phase 100
- [x] **ORCH-02**: Silver Bullet leaves Q&A, trivial instructions, and explicitly non-SDLC requests direct, without forcing workflow orchestration. — **Satisfied** Phase 100

### Clarify Composition

- [x] **ORCH-03**: `silver:clarify` preserves the problem exploration, solution ideation, assumption testing, and strategy exploration behaviors from `product-management:product-brainstorming`. — **Satisfied** Phase 101
- [x] **ORCH-04**: `silver:clarify` preserves the frame/diverge/provoke/converge/capture behaviors from `superpowers:brainstorming` and does not duplicate the PM brainstorming steps when both apply. — **Satisfied** Phase 101
- [x] **ORCH-05**: `silver:clarify` composes the preserved Product Management and Superpowers brainstorming behaviors with GSD discussion into one decision-ready brief. — **Satisfied** Phase 101

### SB-Owned Handoff

- [x] **ORCH-06**: When clarification shows that the next step is milestone creation, SB itself hands off to `gsd:new-milestone` and seeds milestone bootstrap from the clarification brief without requiring the user to restart the process manually. — **Satisfied** Phase 102

### Context Retention

- [x] **ORCH-08**: SB maintains long-running context across the session, tracks every requested item, and prevents omissions while orchestration is in progress. — **Satisfied** Phase 103

### Completion Verification

- [x] **ORCH-09**: Before the work is considered complete, SB verifies that the SE or coding agent's claims match actual completion and autonomously dispatches any missing follow-up work needed to satisfy the original intent. — **Satisfied** Phase 104

### AUI and Autonomy

- [x] **ORCH-10**: SB provides an AUI that hides GSD complexity and presents a high-level, natural SDLC journey to the user. — **Satisfied** Phase 105
- [x] **ORCH-11**: SB remains the master agentic loop, monitors both the SE agent and coding agent, intervenes when necessary, and keeps work moving when one agent returns but the next step is still unattended. — **Satisfied** Phase 105
- [x] **ORCH-12**: SB front-loads user information capture so autonomous work is maximized, and asks the user only when a crucial decision cannot be made safely on their behalf. — **Satisfied** Phase 105

## v2 Requirements

None yet. The current milestone is focused on the core orchestration and enforcement vision.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Q&A, trivial instructions, and explicitly non-SDLC requests being forced through workflow orchestration | These should remain direct and low-friction |
| Replacing GSD's execution engine | GSD owns execution; SB orchestrates and enforces |
| Modifying third-party plugin source files | Plugin boundary remains off-limits |
| Freestyle ad hoc SDLC work | Must go through a composed workflow first |
| One-off custom integrations outside the installed helper skill and connector ecosystem | Not part of this milestone |
| Codex helper-skill discoverability parity for Product Management and Engineering | Not required for v0.37.0 milestone scope |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORCH-01 | Phase 100 | Satisfied |
| ORCH-02 | Phase 100 | Satisfied |
| ORCH-03 | Phase 101 | Satisfied |
| ORCH-04 | Phase 101 | Satisfied |
| ORCH-05 | Phase 101 | Satisfied |
| ORCH-06 | Phase 102 | Satisfied |
| ORCH-08 | Phase 103 | Satisfied |
| ORCH-09 | Phase 104 | Satisfied |
| ORCH-10 | Phase 105 | Satisfied |
| ORCH-11 | Phase 105 | Satisfied |
| ORCH-12 | Phase 105 | Satisfied |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-05-19*
*Last updated: 2026-05-19 after v0.37.0 milestone closeout*
