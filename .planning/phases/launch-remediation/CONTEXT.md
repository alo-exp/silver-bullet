# Launch Remediation — Context

**Source:** Pre-launch adversarial review (2026-06-14); product direction addendum (2026-06-14).  
**Goal:** Close gaps between SB's stated orchestration/V&V vision and hook-enforced reality.

**Related:** [Pre-launch adversarial review](../../../docs/audits/pre-launch-adversarial-review-2026-06.md) · [PLAN.md](./PLAN.md) · [PROGRESS.md](./PROGRESS.md)

---

## Locked decisions — Autonomous Orchestration Vision

**Status:** LOCKED (2026-06-14). Supersedes implicit "guided workflow" UX assumptions in skills and audit framing.

### Product intent (verbatim)

1. **NOT flow-guided UX** — SB does **not** walk users through flows step-by-step.
2. **Minimal user input** — only critical clarifications, design decisions, and preferences.
3. **Autonomous orchestration** — SB drives the entire process autonomously.
4. **Automatic flow chaining** — when one flow ends, SB automatically launches the next most logical flow to achieve user intent.
5. **Full software scope** — if user intent is entire software, SB handles that mostly autonomously.
6. **SessionStart prerequisites** — at each session start, SB checks prerequisites exist; reinstalls if missing.
7. **SB-initiated projects only** — SB activates only for sessions in SB-initiated projects/workspaces (not arbitrary repos).

### Implications for remediation priorities

| Vision pillar | Current SB reality | Remediation impact |
|---------------|-------------------|-------------------|
| Not flow-guided | `silver-feature` et al. expose composition proposals, step banners, supervision-loop instructions agent must inline | Wave 0: hide step UX; drive via orchestrator state, not skill narration |
| Minimal input | Router Step 8 ambiguity prompts; clarify/spec steps ask many questions | Wave 0: default autonomous decisions; user prompts only on `decision_class: blocking` |
| Autonomous orchestration | Host agent implements; SB records skills + gates delivery | Wave 0+: orchestrator owns intent → plan → chain; agent is executor |
| Auto flow chaining | Supervision loop is **skill text only**; no hook advances next flow | **New epic** — hook or daemon `next-flow` after skill completion |
| Full software scope | Phase/milestone model; no cross-milestone intent persistence | Roadmap: intent graph + ROADMAP auto-advance |
| SessionStart prerequisites | jq warn-only; no dep reinstall | Wave 0: prerequisite probe + repair script in `session-start` |
| SB-initiated only | Any tree with `.silver-bullet.json` + `silver-bullet.md` activates | Wave 0: `sb_initiated` marker set only by `silver:init`; hooks ignore others |

### Relationship to C-01 (outcome checklist)

C-01 (per-prompt outcomes) remains necessary but **not sufficient** for autonomous orchestration:

- Outcomes verify *what* must be true for this turn.
- Autonomous vision requires *who drives the next turn* — currently the host agent, not SB.
- Reframe C-01: outcomes are **orchestrator checkpoints**, not a user-facing checklist UI.

### Relationship to flow composition (M-05, C-06)

- Composition proposals and `workflows.sh` manual start are **implementation debt** against vision #1 and #4.
- Target: orchestrator writes workflow instance + first flow atomically at route time; no `Approve composition? [Y/n]` except explicit user override preference.

### Relationship to skill theater (C-02)

- Autonomous mode increases theater risk if chaining is skill-instruction-only.
- Strict evidence (C-02) + **mechanical next-flow** must ship together before marketing autonomous orchestration.

---

## Locked decisions — Adversarial review remediation

### D-01 — Per-prompt outcome checklist (C-01)

| Field | Decision |
|-------|----------|
| Artifact | `${SB_RUNTIME_STATE_DIR}/outcomes-session.json` (session-scoped, not committed) |
| Seed hook | `UserPromptSubmit` → `outcomes-check.sh` generates outcome rows from prompt + route class |
| Verify hook | `Stop` / `SubagentStop` → same script; blocks when required outcomes lack `status: done` + non-empty `evidence` |
| Auto-pass | Trivial bypass, read-only sessions (HOOK-14), empty skill state |
| Agent duty | Router (`silver`) Step 2.5 displays outcomes; agent updates evidence fields before declaring done |

**Rationale:** Committed `OUTCOMES.md` per prompt would pollute git; state-dir JSON matches branch/session model.

### D-02 — Outcome verification / substance (C-02)

| Field | Decision |
|-------|----------|
| Schema | Existing `docs/evidence-schema.md` + `scripts/validate-evidence-findings.sh` |
| Delivery default | `SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1` at final delivery unless project sets `hooks.evidence_schema.strict: false` in `.silver-bullet.json` |
| Artifact gates | Keep `completion-audit.sh` file-existence checks; add minimum line/word counts for REVIEW/VERIFICATION via validator |

**Rationale:** Warn-first was insufficient; strict at delivery closes skill theater without breaking mid-session commits.

### D-03 — Stop hook two-tier model (C-03)

**Decision:** Update docs to match runtime (planning floor at Stop; full `required_deploy` at delivery). Do **not** restore full deploy check on Stop — v0.30.0 #85 rationale stands (ad-hoc edits, per-commit release skill).

**Files:** `silver-bullet.md`, `templates/silver-bullet.md.base`, `docs/ENFORCEMENT.md` (if present).

### D-04 — jq bootstrap (C-04)

**Decision:** `silver:init` already hard-stops. Delivery hooks (`completion-audit`, `stop-check`) **block** when jq missing. Informational hooks remain warn-only.

### D-05 — Capability tier honesty (C-05)

**Decision:** `session-start` injects tier banner from shared `hooks/lib/capability-tier.sh`. `silver:ship` / delivery messages include tier caveat when `< hook-enforced`.

### D-06 — required_deploy vs required_release (H-04)

| List | Contents |
|------|----------|
| `required_deploy` | PR/deploy skills **without** `silver-create-release` |
| `required_release` | `silver-create-release` (+ future release-only skills) |
| Gate | `gh pr create` → deploy list only; `gh release create` → deploy ∪ release |

### D-07 — VERIFY skip (H-01)

Invalidate stale verification when `src_pattern` files change after `VERIFICATION.md` mtime (mirror verify-tests freshness).

### D-08 — Bugfix chain (H-02)

`workflow-chain-guard` requires `silver-quality-gates silver-context silver-plan` for `silver-bugfix` composer.

### D-09 — UAT on ship (H-07)

`uat-gate.sh` also gates `silver-ship` / `silver:ship` when `.planning/SPEC.md` exists (project has acceptance criteria).

### D-10 — VFY-01 (H-08)

Block `docs(*-*): complete` plan-seal commits when `silver-completion-audit` not recorded since last plan start (plan-boundary check in `completion-audit.sh` Tier 1).

## Claude's discretion

- MEDIUM/LOW items: implement when wave capacity allows; document deferrals in PROGRESS.md.
- Q&A routing (H-05): narrow exceptions — "how to fix" routes to `silver:bugfix` or `silver:clarify`, not bare Q&A.

## Open questions

- **Wave 0 vs launch messaging:** Ship Waves 1–5 as "expert framework" while Wave 0 is in progress, or hold public launch until 0.3+0.4 land?
- **sb_initiated migration:** Grandfather existing dogfood repo vs require one-time `silver:init` replay?

None blocking Waves 1–5 execution (complete). Wave 0 planning is locked; implementation pending.
