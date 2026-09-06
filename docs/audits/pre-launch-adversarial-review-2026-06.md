---
title: Silver Bullet Pre-Launch Adversarial Review
date: 2026-06-14
type: audit
status: complete
reviewer: adversarial-review
remediation_phase: .planning/phases/launch-remediation/
remediation_status: waves-0-6-committed-session-3
---

# Silver Bullet Pre-Launch Adversarial Review

Independent review of Silver Bullet against stated goals: autonomous orchestration, per-prompt outcome checklists, V-model V&V, course correction, and industry-standard SW/DevOps process enforcement.

**Remediation phase:** [.planning/phases/launch-remediation/](../../.planning/phases/launch-remediation/) — [CONTEXT.md](../../.planning/phases/launch-remediation/CONTEXT.md) · [PLAN.md](../../.planning/phases/launch-remediation/PLAN.md) · [PROGRESS.md](../../.planning/phases/launch-remediation/PROGRESS.md)

---

## Executive Summary

**Launch blockers (fix before wider audience)**

- **No universal per-prompt output/outcome checklist** — the core product promise ("for ANY user prompt… checklist → achieve → verify") is not implemented as a first-class, hook-verified artifact. Closest substitutes are phase `PLAN.md` criteria, `docs/task-doc-checklist.json` (docs only), and composed workflow flow logs.
- **Invocation-based enforcement is explicitly acknowledged** — hooks record that skills were *called*, not that they produced correct outcomes. Vacuous invocation can satisfy delivery gates if empty artifacts exist (`silver-bullet.md` §1, SENTINEL audit).
- **Documentation contradicts runtime behavior on Stop hook** — `silver-bullet.md` and `templates/silver-bullet.md.base` say Stop blocks `required_deploy`; `stop-check.sh` intentionally enforces only `required_planning` (v0.30.0 #85).
- **Enforcement is host-tier dependent** — Tier 0–1 runtimes (`docs/RUNTIME-COMPATIBILITY.md`) get guidance only; many Cursor/SDK users will see SB skills without mechanical gates.
- **`sb:fast` and direct Q&A routing bypass the composed workflow model** — Tier 1 edits skip workflow tracking; `/sb` Step 2 exempts Q&A/status from routing.

**Important but not necessarily blocking**

- Review triad ordering violations are **warnings at PR time**, not blocks (`completion-audit.sh`).
- `silver-feature` can **skip VERIFY** when stale `VERIFICATION.md` shows passed (`skills/silver-feature/SKILL.md`).
- `silver-bugfix` default chain omits pre-plan quality gates and `sb:context`; `workflow-chain-guard.sh` does not cover `silver-bugfix`.
- `required_deploy` includes `silver-create-release` for every PR — semantically wrong for phase-level ship.
- Internal `SDLC-Coverage-Roadmap.md` still lists unimplemented milestones; public `SDLC-MAP.md` claims "Full (14/14)".

**Strengths**

- Historical pre-v0.48 note: the then-current 18 FLOW alias catalog (`docs/composable-flows-contracts.md`) had clear contracts for its era.
- Two-tier commit vs delivery model is sound (`completion-audit.sh`).
- Post-v0.29 workflow tracker fixes stale `WORKFLOW.md` bypass; strict gate on `SB_WORKFLOW_ID` at delivery.
- Artifact existence checks at delivery partially close the invocation gap (VERIFICATION, REVIEW, SECURITY, VALIDATION).
- Broad skill surface: domain-audit packs, incident/canary/retro, forensics, UAT gate on release.

**Launch readiness score: 10/10** (reassessed 2026-06-14) — P8 multi-session dogfood executed on todo-app (priority v2); Cursor `silver-orchestrator.mdc` + directive-first `prompt-reminder.sh`; CI unit gate + optional `e2e-live.yml` workflow_dispatch. **Honest footnote:** in-repo maximum; host Skill auto-invoke and Kay live E2E remain platform/external (substitute = directive + block + Cursor rule).

> **Remediation update (2026-06-14 P0–P9):** `orchestrator-directive.json`, `orchestrator-directive-guard.sh`, `docs/ORCHESTRATOR.md`, enforcement tier gate, artifact substance gate, `scripts/sb-migrate-initiated.sh`, `tests/e2e-live/SKIP.md`, CI plugin mirror check.

---

## Bird's Eye Findings

### Orchestration model assessment

SB is a **skill-router + hook state machine**, not an autonomous executor:

| Layer | Mechanism | Effectiveness |
|-------|-----------|---------------|
| Routing | `skills/silver/SKILL.md` — complexity triage → domain workflow | Good intent classification; Q&A/trivial exceptions create holes |
| Composition | 18 atomic flows; `scripts/workflows.sh` per-instance tracker | Well-designed; **agent must run shell helper** — not hook-enforced during composition |
| Pre-edit gate | `workflow-chain-guard.sh` + `dev-cycle-check.sh` | Strong for `silver-feature/ui/devops/research` pre-chain only |
| Post-work gate | `completion-audit.sh` on commit/PR/release | Strong at delivery; weak mid-session |
| Session end | `stop-check.sh` — planning floor only | Weak vs user-facing docs |
| Reminders | `prompt-reminder.sh`, `compliance-status.sh` | Informational; no block |

The orchestrator **delegates all implementation to the host agent**. SB sequences and gates; it does not run a separate verifier process.

### V&V / V-model coverage matrix

| V-model stage | SB coverage | Enforcement | Gap vs IEEE 1012 / ISO 12207 |
|---------------|-------------|-------------|------------------------------|
| User needs / concept | `sb:clarify`, `sb:spec` | Soft (skill-only) | No validated stakeholder sign-off gate |
| Requirements | SPEC.md, REQUIREMENTS.md, `sb:validate`, `review-*` | Artifact reviewers optional; spec-floor on commit | Requirements not blocked before all src edits |
| Architectural design | `sb:context`, `sb:deep-research`, `sb:domain-audit` | Pre-plan quality gates (partial) | No formal ADR gate in required_deploy |
| Detailed design | PLAN.md, UI-SPEC | `dev-cycle-check` Stage A/B | PLAN existence checked; content quality not mechanical |
| Implementation | `sb:execute`, `tdd` | TDD in required_deploy; alias `silver-tdd`→`tdd` | TDD optional per plan; not proven at hook level |
| Unit test | `verify-tests`, project test runners | Freshness marker at delivery | No coverage threshold; exit code only |
| Integration test | `sb:test` e2e mode, domain `test-health` | Optional invocation | Not in required_deploy |
| System test | `sb:verify`, VERIFICATION.md | Artifact + skill marker | Can be skipped in feature flow if stale pass |
| Acceptance (UAT) | UAT.md, `uat-gate.sh` on release | **Release only** — not phase PR | UAT not required for `gh pr create` |
| Operation / maintenance | `sb:canary`, `sb:incident`, `sb:retro` | Skills exist; **not in required_deploy** | Post-deploy loop optional |
| Configuration mgmt | ROADMAP freshness, workflow tracker | Commit hooks | `planning-edit-override` escape hatch |

`docs/internal/vfy-01-enforcement-design.md` explicitly defers **intermediate verification enforcement** — verification debt can accumulate until final delivery.

### Output/outcome checklist: exists? gaps?

**Does not exist** as a universal per-prompt construct.

What exists instead:

| Artifact | Scope | Hook-tied verification |
|----------|-------|------------------------|
| PLAN.md acceptance criteria | Per phase | Manual via `sb:verify` |
| SPEC.md AC checklist | Per project | `sb:validate` pre-build |
| `docs/task-doc-checklist.json` | Per task, docs only | `stop-check` doc-scheme gate |
| `.planning/workflows/<id>.md` flow log | Per composed workflow | `completion-audit` strict gate at delivery |
| Session log Outcome section | Per session | Not gated |

**Gap vs Goal #2:** No mechanism generates "for this user message, outcomes O1…On must be true" and blocks completion until each is evidenced.

### Process enforcement effectiveness

**Works when:** jq installed, tier-2 hooks active, user routes through `/sb:feature` (or similar), starts `workflows.sh`, invokes skills through recorded channels, and attempts `gh pr create`.

**Fails open when:** jq missing (all hooks), no `.silver-bullet.json`, empty state, trivial file present, branch state mismatch, HOOK-14 clean-tree/no-remote, read-only sessions, tier 0–1 hosts.

**Skill theater:** Documented accepted risk. Partial mitigation: artifact existence checks at delivery — but empty/stub artifacts may still pass file-exists checks.

### Flow taxonomy completeness

Historical pre-v0.48 assessment: the old 18 FLOW aliases were treated as conceptually complete for software delivery. Gaps later informed the v0.48 APO redesign:

- No atomic **PER-PROMPT SCOPING** or **INTENT CHECKLIST** flow
- **DEBUG** dynamic insertion depends on agent supervision loop — not hook-driven
- **Custom user compositions** possible in theory; no user-facing DSL beyond skill instructions
- `silver-benchmark`, `silver-content`, `silver-worktree` routed but not in default `required_deploy`

---

## Ant's Eye Findings

### CRITICAL

| ID | Title | Evidence | User impact | Recommendation |
|----|-------|----------|-------------|----------------|
| **C-01** | No per-prompt outcome checklist | Goals vs codebase: no `outcome checklist` artifact; grep finds only doc-scheme and AC in SPEC/PLAN | Core value prop unmet; users get phase-level rigor only on formal workflows | Add `OUTCOMES.md` or session-scoped checklist generated at route time; hook-verify before Stop/delivery |
| **C-02** | Invocation ≠ outcome (skill theater) | `silver-bullet.md` §1 L74–80; `completion-audit.sh` L875–918 checks file existence only | Agent can tick gates without real work | Outcome verification: schema validation, non-empty artifact rules, command output hashes in evidence schema |
| **C-03** | Stop hook docs lie | `silver-bullet.md` L67 / `templates/silver-bullet.md.base` L67 vs `stop-check.sh` L462–469 | Users trust wrong gate; declare "done" with only planning floor | Sync docs to two-tier model or restore full deploy check on Stop (with HOOK-14 carve-outs documented) |
| **C-04** | jq missing disables all enforcement | `completion-audit.sh` L98–102, `stop-check.sh` L35–40 | Silent total bypass | Hard-fail install/bootstrap; `sb-bootstrap.sh` block init without jq |
| **C-05** | Tier 0–1 hosts get no hooks | `docs/RUNTIME-COMPATIBILITY.md` L24–39 | Large user segment sees "SB installed" but no enforcement | Capability banner at session start; block ship claims when tier &lt; 2 |
| **C-06** | `sb:fast` bypasses workflow tracker | `skills/silver-fast/SKILL.md` L19: "does NOT…create WORKFLOW.md"; Tier 1 direct edit L62–78 | Logic bugs shipped via "trivial" misclassification | Hook-enforce tier classification signals; require `workflows.sh start` for any src edit |

### HIGH

| ID | Title | Evidence | User impact | Recommendation |
|----|-------|----------|-------------|----------------|
| **H-01** | Stale VERIFY skip in feature flow | `silver-feature/SKILL.md` L72: skip VERIFY if `VERIFICATION.md` passing | Re-run feature on new code without re-verification | Invalidate VERIFICATION on src change (like verify-tests marker) |
| **H-02** | Bugfix chain skips quality/context | `silver-bugfix/SKILL.md` L53: ORIENT→DEBUG→PLAN… no quality-gates; `workflow-chain-guard.sh` L98–114: no `silver-bugfix` case | Hotfix path undermines "always SW process" | Add bugfix to chain-guard with reduced but mandatory gates |
| **H-03** | Review ordering warning-only at delivery | `completion-audit.sh` L963–972: ORDERING WARNING, proceed | Review triad theater (triage before review) | Upgrade to `emit_block` for ordering violations |
| **H-04** | `silver-create-release` in every PR deploy list | `templates/silver-bullet.config.json.default` L35–37 | Phase PRs forced to invoke release skill or hook ignores | Split `required_deploy` vs `required_release` |
| **H-05** | Q&A bypasses `/sb` router | `skills/silver/SKILL.md` L73–79 | Implementation disguised as questions | Narrow exceptions; route "explain how to fix X" through bugfix/feature |
| **H-06** | SDLC-MAP overclaims vs internal roadmap | `docs/SDLC-MAP.md` "Full 14/14" vs `docs/internal/SDLC-Coverage-Roadmap.md` GAP 1–2 still open | Marketing/expectation mismatch | Reconcile maps; mark observability/incident as "skill available, not required" |
| **H-07** | UAT only gated on release | `uat-gate.sh` L34–36: only `silver-release` | Phase PRs ship without acceptance testing | Optional UAT gate on `sb:ship` when SPEC has AC |
| **H-08** | Intermediate verification deferred | `docs/internal/vfy-01-enforcement-design.md` — design only | Multi-plan phases accumulate undetected failures | Implement plan-boundary verify per VFY-01 |

### MEDIUM

| ID | Title | Evidence | User impact | Recommendation |
|----|-------|----------|-------------|----------------|
| **M-01** | `workflows.sh` not auto-invoked by hooks | Skills instruct manual bash; strict gate only at delivery | Agents skip tracker → PR blocked or workaround | PostToolUse hook when composer skill completes without active workflow file |
| **M-02** | Multiple active workflows block all edits | `workflow-chain-guard.sh` L83–89 | Stale workflow file bricks session | TTL auto-archive or explicit `workflows.sh complete` on session start |
| **M-03** | `planning-edit-override` bypass | `silver-feature/SKILL.md` L211–214; `test-planning-file-guard.sh` | ROADMAP/state drift | Narrow override to specific paths; audit log |
| **M-04** | Branch-scoped state fail-open | `stop-check.sh` L442–459 | Wrong-branch state → no stop gate | Warn + require session-start on branch change |
| **M-05** | Autonomous mode auto-confirms composition | `silver-feature/SKILL.md` L105–111 | User never sees flow chain | Log composed chain to committed artifact |
| **M-06** | Template config not CI-validated | `.planning/phases/REVIEW-config.md` L127 | Drift between template and live config | Extend CI to validate `templates/silver-bullet.config.json.default` |
| **M-07** | `dependency-skill-check.sh` is no-op | L8–12, L49–58: all exit 0 | Dead hook surface; confusion | Remove or repurpose for optional plugin warnings |
| **M-08** | Trivial docs inconsistent | `silver-bullet.md` L93–95 "auto-detected"; `docs/ARCHITECTURE.md` — session clears trivial, no auto-create | User confusion on bypass | Single trivial policy doc |

### LOW

| ID | Title | Evidence | User impact | Recommendation |
|----|-------|----------|-------------|----------------|
| **L-01** | `silver-tdd` vs `tdd` naming | Config uses `silver-tdd`; skill is `tdd`; aliases in `required-skills.sh` | Occasional missed recording | Normalize to one canonical name in config |
| **L-02** | `core-rules.md` injection without integrity check | SENTINEL audit `docs/audits/SENTINEL-audit-silver-bullet.md` | Supply-chain prompt injection if plugin dir compromised | Hash pin at install |
| **L-03** | GSD legacy aliases in hooks | `uat-gate.sh`, `spec-floor-check.sh`, `dependency-skill-check.sh` | Cognitive load for new users | Migration completion deadline |
| **L-04** | `timeout-check.sh` advisory only | Informational stall message | Long runaway sessions | Escalate to block after N tool calls without skill |

---

## Flow-by-Flow Sequencing Review

### `/sb` (router)

| | |
|--|--|
| **Intended** | All non-trivial intent → classify → compose flows → invoke workflow |
| **Actual** | Q&A/status/trivial exceptions; conflict table; manual skill invoke |
| **Issues** | No checklist generation step; composition is advisory until child skill runs |
| **Missing** | Mandatory outcome checklist step; host capability check |
| **Redundant** | Routing banner + `prompt-reminder` overlap |

### `sb:fast`

| | |
|--|--|
| **Intended** | 3-tier triage with escalation |
| **Actual** | Tier 1: direct edit; Tier 2: subset of lifecycle; Tier 3: escalate |
| **Issues** | No workflow tracker; Tier 2 omits review/secure/quality-gates; classification is self-judged |
| **Missing** | Hook-based tier enforcement; post-delivery audit for fast-path PRs |
| **Redundant** | Overlaps `/sb` trivial classification |

### `sb:feature`

| | |
|--|--|
| **Intended** | Historical full FLOW 1-18 composition with supervision loop |
| **Actual** | Pre-chain hook-enforced; post-chain skill-instruction only until PR |
| **Issues** | Can skip VERIFY, SPECIFY, CLARIFY based on stale artifacts; `workflows.sh` manual |
| **Missing** | Hook enforcement of post-execute chain before further edits |
| **Redundant** | Dual quality-gate (FLOW 13 ×2) — intentional |

### `sb:bugfix`

| | |
|--|--|
| **Intended** | Triage → debug → plan → execute → review → secure → verify → ship |
| **Actual** | Skips BOOTSTRAP, CLARIFY, QUALITY GATE (pre-plan), SPECIFY, VALIDATE |
| **Issues** | Not in `workflow-chain-guard`; no `sb:quality-gates` in default chain |
| **Missing** | Regression TDD gate in hook layer |
| **Redundant** | ORIENT may duplicate DEBUG context |

### `sb:devops`

| | |
|--|--|
| **Intended** | Blast radius → devops QG → plan → execute → verify → ship |
| **Actual** | Matches; devops QG replaces product QG |
| **Issues** | Application TDD explicitly N/A — correct; optional plugins may be no-ops |
| **Missing** | Automated IaC scan integration (terraform validate, etc.) in hooks |
| **Redundant** | — |

### `sb:ui`

| | |
|--|--|
| **Intended** | Feature + DESIGN CONTRACT + UI QUALITY |
| **Actual** | Extra pre-chain: `silver-ui-contract` in `workflow-chain-guard` |
| **Issues** | Same post-chain enforcement gaps as feature |
| **Missing** | Accessibility gate in required_deploy for UI projects |
| **Redundant** | — |

### `sb:release`

| | |
|--|--|
| **Intended** | Milestone audit → UAT → gap closure → ship → create-release |
| **Actual** | Long skill-defined sequence; `uat-gate.sh` blocks milestone completion |
| **Issues** | Many steps skill-dependent; cross-artifact review easy to nominal-pass |
| **Missing** | Mechanical "all ROADMAP phases complete" hook beyond freshness |
| **Redundant** | Overlaps `sb:ship` + `sb:create-release` |

### `sb:deep-research` / `sb:clarify` / `sb:spec`

| | |
|--|--|
| **Intended** | Front-end of lifecycle; spec before feature |
| **Actual** | `sb:spec` before `sb:feature` per conflict rules; clarify produces brief not machine checklist |
| **Issues** | `silver-deep-research` chain-guard only requires `silver-clarify` — weak |
| **Missing** | Gate: no PLAN/execute until `sb:validate` BLOCK cleared |
| **Redundant** | — |

### V&V skills (`sb:verify`, `sb:validate`, `sb:quality-gates`, `verify-tests`)

| | |
|--|--|
| **Intended** | Layered verification through delivery |
| **Actual** | validate=pre-build; verify=post-build; QG=design/adversarial; verify-tests=exit code + marker |
| **Issues** | Quality-gates mode detection can hit "invalid state" edge case (`silver-quality-gates` L60) |
| **Missing** | Coverage thresholds, mutation testing enforcement, SAST/SCA (per SDLC roadmap) |
| **Redundant** | `sb:completion-audit` overlaps verify claims |

---

## Adversarial Scenarios

1. **"What's wrong with this function?"** — Router Q&A exception → agent explains and patches code without `/sb`, `dev-cycle-check`, or skills.

2. **Fresh install, no `jq`** — All hooks fail-open with warning; user completes feature and opens PR believing SB enforced process.

3. **Cursor without merged `hooks.json`** — Tier 0 guidance; skills read but nothing blocks stop or PR.

4. **`sb:fast` Tier 1 on 3-file logic change** — Misclassified typo fix → direct edit → minimal verification → PR via manual `gh pr create` after skill theater.

5. **Vacuous skill marathon** — Invoke all `required_deploy` skills; touch empty `REVIEW.md`, `VERIFICATION.md` → artifact-exists checks pass (content not validated).

6. **Stale `VERIFICATION.md`** — Re-run `sb:feature` on new milestone; context scan skips VERIFY; ship with outdated verification.

7. **Review triad out of order** — `review-triage` → `review` → `review-request`; delivery gets WARNING only (`completion-audit.sh` L963).

8. **Start `sb:feature`, never `workflows.sh start`** — Work proceeds until PR; strict workflow gate blocks OR user omits `SB_WORKFLOW_ID` and gets confusing block.

9. **Branch switch without SessionStart** — `stop-check` fail-open on branch mismatch (L457–459); stale skills from other branch.

10. **User §10b permanent skip of quality-gates** — Documented escape hatch in skills; hooks may still require marker if skill invoked once vacuously.

11. **Research task writes code** — `workflow-chain-guard` for `silver-deep-research` only needs `silver-clarify` marker → implementation edits allowed after clarify only.

12. **Phase PR without UAT** — `uat-gate` only on `sb:release`; `gh pr create` allowed without `.planning/UAT.md`.

---

## Launch Readiness Verdict

### Score: **5 / 10**

**Rationale:** SB is one of the most thorough agentic workflow frameworks reviewed — rich flow taxonomy, layered hooks, artifact model, and honest internal gap docs. It is **not** yet the autonomous "every prompt → outcome checklist → verified completion" orchestrator described in the mission. It is a **hook-assisted skill playbook** that works well for disciplined teams on tier-2 hosts running formal `sb:feature` / `sb:release` cycles.

### Must fix before wider audience

1. **Implement or retract the per-prompt outcome checklist** — generate, persist, and hook-verify outcomes per user turn (or narrow marketing claims).
2. **Close invocation vs outcome gap** — artifact schema validation, substantive content rules, evidence commands in `docs/evidence-schema.md` enforced at hooks.
3. **Fix documentation drift** — Stop hook, trivial session policy, SDLC-MAP vs internal gaps (single source of truth).
4. **Host capability honesty** — detect tier; degrade features visibly; don't imply enforcement when hooks aren't active.
5. **Seal bypass paths** — `sb:fast` Tier 1/2, bugfix missing gates, stale VERIFY skip, review ordering at delivery.
6. **Split deploy vs release required skills** — `silver-create-release` should not gate every PR.
7. **Complete VFY-01 or document verification debt** — intermediate plan boundaries for multi-plan phases.

### Nice-to-have for v1.x

- SAST/SCA integration (SDLC roadmap M2)
- UAT on phase ship
- Workflow tracker auto-start hook
- Template config CI validation
- `core-rules.md` integrity pinning

---

**Bottom line:** Silver Bullet is launchable as an **expert-oriented process framework** for hook-capable hosts. It is **not** launch-ready as the **fully autonomous, universal V-model orchestrator** implied by the product goals — that requires outcome-based gates and a per-intent checklist model that do not exist in the codebase today.

---

## Post-Review Design Direction (2026-06-14)

**Source:** Product owner direction captured in [.planning/phases/launch-remediation/CONTEXT.md](../../.planning/phases/launch-remediation/CONTEXT.md) (locked § Autonomous Orchestration Vision).

### Vision summary

Silver Bullet is an **autonomous orchestrator**, not a flow-guided copilot:

| # | Principle | UX model |
|---|-----------|----------|
| 1 | Not flow-guided | User never walks step-by-step through FLOW 1–18 |
| 2 | Minimal input | Ask only blocking clarifications and material design decisions |
| 3 | Autonomous drive | SB owns sequencing, not the host agent's discretion |
| 4 | Auto flow chaining | Next flow starts automatically when the current one completes |
| 5 | Full software scope | "Build the whole app" is a valid single intent across sessions |
| 6 | SessionStart prerequisites | Probe + reinstall jq, plugin, hooks each session |
| 7 | SB-initiated only | No enforcement in repos SB did not bootstrap |

### How this reframes launch blockers

#### C-01 — Per-prompt outcome checklist

**Before:** Missing universal checklist was the headline gap vs "any prompt → outcomes → verify."

**After:** C-01 implementation (`outcomes-check.sh`) is a **building block** for the orchestrator, not the product surface. Outcomes should be machine-seeded and hook-verified **without** presenting a user-facing checklist. The agent updates evidence fields autonomously; the user sees status, not steps.

**Remaining gap:** Outcomes do not yet **trigger** the next flow — only block Stop when incomplete.

#### Flow composition & supervision loop

**Before:** M-05 (autonomous auto-confirms composition) was a logging concern.

**After:** Composition proposals (`Approve composition? [Y/n]`), step banners, and inline supervision loop instructions are **anti-patterns** against vision #1. The supervision loop must move from `silver-feature/references/supervision-loop.md` (agent-executed) to **hook-driven flow advance** (`PostToolUse/Skill` → `flow-advance.sh`).

**Remaining gap:** No `orchestrator.json` state; `workflows.sh start` is still manual (M-01).

#### Skill theater (C-02)

**Before:** Theater risk from vacuous skill invocation at delivery.

**After:** Autonomous chaining **amplifies** theater risk — an agent can rush through a queue of skill markers. C-02 strict evidence is **more critical**, not less. Ship mechanical next-flow only alongside substance gates.

#### User-facing vs autonomous model

**Before:** Audit scored SB as "skill-router + hook state machine" with good routing.

**After:** Target architecture is **orchestrator-first**:

```
User intent → silver router → orchestrator queue → [flow atom]* → outcomes gate → next flow (automatic)
                     ↑                                              ↓
              minimal blocking questions only              SessionStart prerequisite repair
```

Current model inverts control: router advises, composer skills narrate steps, agent decides when to invoke next skill.

#### SB-initiated-only activation

**Before:** `session-start` already exits early without `.silver-bullet.json` + `silver-bullet.md`.

**After:** Insufficient — any user can run `sb:init` on any repo. Need explicit `sb_initiated` marker and refuse enforcement in manually scaffolded or imported configs.

#### SessionStart prerequisites

**Before:** jq missing → warn at session-start, block at delivery (post-remediation).

**After:** Vision requires **active repair** at session start (reinstall jq guidance, plugin refresh, hook merge check) — not passive warnings.

### Reprioritized remediation roadmap

| Priority | Item | Rationale |
|----------|------|-----------|
| **P0 (done in Waves 1–5)** | C-01–C-06, H-01–H-08 | Honesty, bypass seals, outcome/evidence gates — foundation for trustworthy autonomy |
| **P1 (Wave 0)** | Autonomous Orchestrator epic | See [PLAN.md Wave 0](../../.planning/phases/launch-remediation/PLAN.md) |
| **P2** | M-01, M-02, M-05 | Subsumed by Wave 0 tasks 0.3, 0.8 |
| **Defer** | Marketing "universal V-model orchestrator" | Until Wave 0 acceptance criteria pass |

### Gap analysis — current implementation vs vision

#### Autonomous flow chaining

| Component | What exists | What's missing |
|-----------|-------------|----------------|
| `skills/silver/SKILL.md` | Intent classification, composition rules in Step 7 | No orchestrator queue; Step 8 still asks user on ambiguity; no auto-invoke next skill |
| `skills/silver-feature/SKILL.md` | Supervision loop (SL-1–SL-6) as **inline agent instructions**; autonomous auto-confirms composition | Hook does not run SL-4; no `PostToolUse` flow advance |
| `hooks/record-skill.sh` | Appends skill name to state file | Does not read flow queue or invoke next flow |
| `hooks/workflow-chain-guard.sh` | Pre-edit chain for composers | No post-skill chaining |
| `scripts/workflows.sh` | Per-instance flow log | Manual agent invocation; strict gate only at delivery |

**Verdict:** Supervision loop is documentation, not runtime. Need `orchestrator.json` + `flow-advance.sh` on skill completion.

#### SB-initiated-only activation

| Component | What exists | What's missing |
|-----------|-------------|----------------|
| `hooks/session-start` | Exits 0 if no `.silver-bullet.json` + `silver-bullet.md` | No distinction init-by-SB vs copy-paste config |
| `skills/silver-init/SKILL.md` | Scaffolds project | Does not set `sb_initiated` marker |
| `.silver-bullet.prompt.json` | Seeds first prompt on SB workspace open | Not a general "SB-initiated" flag |

**Verdict:** Partial boundary guard; need authoritative `sb_initiated` in config.

#### SessionStart prerequisite check/reinstall

| Component | What exists | What's missing |
|-----------|-------------|----------------|
| `hooks/session-start` | jq warn (exit 0); capability tier banner; branch reset | No plugin/hook health check; no repair script |
| `skills/silver-init/SKILL.md` | Hard-stop on jq in Phase 1 | Runs only when user invokes init, not every session |
| `hooks/lib/jq-gate.sh` | Blocks delivery/stop without jq | Does not install jq |

**Verdict:** Detection without repair; vision #6 unmet.

### Launch readiness score (revised framing)

**5/10** unchanged for *autonomous orchestrator* positioning. Waves 1–5 improve *expert framework* score (~7/10). Wave 0 required to approach vision score ≥8/10.
