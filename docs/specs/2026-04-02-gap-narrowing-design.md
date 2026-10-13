# Silver Bullet — GSD-2 Gap Narrowing Design

**Date:** 2026-04-02
**Scope:** Strategies to narrow GSD-2 vs SB gaps within host coding-agent environments
**Out of scope:** Multi-provider support (#7), async Slack/Discord collaboration (#8)
**Reference:** `docs/gsd2-vs-sb-gap-analysis.md`
**Target workflow:** `docs/workflows/full-dev-cycle.md` (the installed 31-step linear workflow). Step references in this document use the numbered steps from that file.

---

## Architecture: Hybrid Hook + Skill

Mechanical/automatic capabilities are implemented as hooks. Semantic/deliberate capabilities are implemented as workflow steps or skills. Each capability lands in the right layer:

| Layer | Handles |
|-------|---------|
| **Hook (PostToolUse/PreToolUse)** | Session log initialization, CI status warnings after commits, virtual cost calculation scaffolding |
| **Skill / workflow step** | KNOWLEDGE.md updates, session log content, autonomy mode choice, model routing decisions, Agent Team dispatch |

---

## Gap 1 — Cross-Session Knowledge (#10) — HIGHEST PRIORITY

### KNOWLEDGE.md

A single file at `docs/KNOWLEDGE.md`. Two non-redundant parts:

**Part 1 — Gateway Index** (updated when docs change)

Points to each mandated doc with a one-line status summary. Never duplicates content:

```markdown
## Project Docs
- Master PRD              → docs/Master-PRD.md                  | [status]
- Architecture            → docs/Architecture-and-Design.md     | [status]
- Testing Strategy        → docs/Testing-Strategy-and-Plan.md   | [status]
- CI/CD                   → docs/CICD.md                        | [status]
- Active Workflow         → docs/workflows/full-dev-cycle.md
- Specs                   → docs/specs/                         | [N specs]
- Session Log             → docs/CHANGELOG.md                   | [last updated]
- Sessions                → docs/sessions/                      | [N sessions]
```

**Part 2 — Accumulated Intelligence** (append-only, runtime-authored per task)

Sections that grow over time with date-stamped entries:

- **Architecture patterns** — conventions and structural decisions that emerged
- **Known gotchas** — things that broke, edge cases, environment quirks
- **Key decisions** — what was chosen and why (lightweight ADR alternatives)
- **Recurring patterns** — reusable code patterns and abstractions that proved useful
- **Open questions** — unresolved design questions to revisit. Resolved questions are never edited; instead a new `[RESOLVED YYYY-MM-DD]: <resolution>` entry is appended directly below the original, preserving append-only semantics.

### Update Mechanism

- **Trigger**: Step 27 (Documentation) — the active runtime writes a KNOWLEDGE.md update with full task context before committing
- **Layer**: Skill (deliberate) — the active runtime synthesises what is worth capturing
- **Rule**: Additive only. Never delete or edit prior entries. Date-stamp every addition.
- **Session startup**: Phase −1.2 already loads all `docs/**/*.md` — KNOWLEDGE.md is automatically included

---

## Gap 2 — Observability (#9) + Virtual Cost (#3)

### Two-tier output

**Tier 1 — `docs/CHANGELOG.md`** (rolling, human-readable)

One entry per completed non-trivial task. Written by the active runtime at Step 27 (skill layer):

```markdown
## 2026-04-02 — [task slug]
**What**: one sentence description
**Commits**: abc1234, def5678
**Skills run**: brainstorming, write-spec, security, ...
**Virtual cost**: ~$0.04 (Sonnet, medium complexity)
**KNOWLEDGE.md**: updated (architecture patterns, known gotchas)
```

**Tier 2 — `docs/sessions/YYYY-MM-DD-<task-slug>.md`** (per-task detail)

Created for every non-trivial task with two-layer authorship:
- **Hook layer**: writes file header exactly once per task — triggered on the first tool call after the session mode prompt (Step 0) completes. A deduplication guard checks whether a session file for the current date+task-slug already exists before writing; if it does, the hook skips. Header contains: timestamp, model in use, session mode (interactive/autonomous). **Task slug derivation**: first 5 words of the user's opening task prompt, lowercased, spaces replaced with hyphens, non-alphanumeric characters stripped, truncated to 40 characters (e.g., `add-user-auth-to-api`).
- **Skill layer** (runtime, Step 27): fills in approach taken, files changed, skills invoked in order, Agent Teams dispatched, autonomous decisions made (if any), outcome, KNOWLEDGE.md additions.

### Virtual Cost (#3)

SB tracks **virtual cost** as a signal of task weight, not actual subscription spend. Rates based on current Anthropic API pricing.

**Calculation** (the active runtime estimates at Step 27):
- Model tier × complexity multiplier
- Complexity: simple (< 5 files, < 300 lines changed) / medium (5–15 files or 300–1000 lines changed, not architectural in scope) / complex (> 15 files, or > 1000 lines changed, or involves new architecture, migration, or cross-system integration)
- Rates: Sonnet base rate; Opus (claude-opus-4-6) at ~3× multiplier
- Labelled clearly as `~$X.XX (estimated)` — never presented as actual cost

Virtual cost surfaces in: CHANGELOG entry, session log header, KNOWLEDGE.md gateway index (rolling session total).

---

## Gap 3 — Autonomy (#1)

### Session-level mode

Set once at session start before any work begins:

> Run this session interactively or autonomously?
> - **Interactive** — I'll pause at decision points and phase gates (default)
> - **Autonomous** — I'll drive start to finish, surface blockers at the end

Stored in `/tmp/.silver-bullet-mode` for the session lifetime. **Fallback**: if the file is unreadable at any point mid-session, default to interactive and log the fallback in the session log under "Mode fallback." The chosen mode is also written to the session log header (by the hook) so it can be reconstructed if the tmp file is lost. All workflow steps and Agent Team dispatches read this flag.

### What changes in autonomous mode

**Phase gates removed**: no approval pauses between workflow phases. The active runtime proceeds immediately.

**Clarifying questions suppressed**: the active runtime makes best-judgment calls, logs each under "Autonomous decisions" in the session log, and continues.

**Priority order for stall vs. blocker detection**: genuine blocker detection runs first. Anti-stall applies only after a step has been confirmed as a non-blocker.

**Anti-stall rules** (core mechanism, applies to non-blocker stalls only):
- A stall is defined as the same tool call with identical arguments producing the same result 2+ times consecutively, or 3+ tool calls within a single step that produce no new state change (no new file written, no new decision reached, no new information surfaced)
- When a stall is detected: the active runtime makes the best-judgment decision available given current information, moves on, and logs the stall and decision under "Autonomous decisions" in the session log
- If a required skill cannot be invoked, the active runtime logs it as a blocker and continues to the next step
- If a step produces an error, the active runtime attempts one self-correction, then logs and proceeds — no retry loops
- Phase transitions happen automatically without waiting for user acknowledgment

**Genuine blockers** (missing credentials, ambiguous destructive operation — things that truly cannot be bypassed): take precedence over anti-stall rules. Queued in the session log under "Needs human review", skipped, and surfaced in the completion summary.

**Completion**: the active runtime outputs a structured summary — phases completed, autonomous decisions made, blockers queued, Agent Teams dispatched, commits made, virtual cost.

### Constraint

This is not GSD-2's walk-away mode. The session must remain open. Autonomous mode reduces interruptions and uses non-blocking execution — it does not survive a closed terminal.

---

## Gap 4 — Verified Completion + CI/CD (#2 + #6)

### Core principle

Verification is mechanical shell commands via CI — not LLM self-assessment.

### CI setup during SB init

Phase 3 of SB init checks for `.github/workflows/`. If absent, SB generates `ci.yml` tailored to the detected stack:

| Stack | Commands |
|-------|----------|
| Node.js | `npm run lint && npm run typecheck && npm test` |
| Python | `ruff check && mypy . && pytest` |
| Rust | `cargo clippy && cargo test` |
| Go | `go vet && go test ./...` |
| Other | Prompts user; stored in `.silver-bullet.json` under `"verify_commands"` |

### Verification in the workflow

**Step 28 — `/verification-before-completion`** extended:
- Runs configured verify commands locally first
- If local passes, checks remote CI status: `gh run list --limit 1 --json status,conclusion`
- **Autonomous mode**: polls CI status with `gh run list --limit 1 --json status,conclusion` every 30 seconds, up to a maximum of 20 retries (10 minutes total). If CI does not complete within that window, logs a timeout blocker under "Needs human review" and surfaces it in the completion summary before proceeding.
- **Interactive mode**: shows CI status, asks user to confirm. If status is `in_progress` when checked, the active runtime informs the user and waits for the user to confirm whether to re-check or proceed anyway.
- If CI red: logs failure, triggers `/systematic-debugging` automatically

**Step 30 — CI/CD pipeline**: If `ci.yml` is absent at Step 30, the active runtime must not invoke any deploy skill, must log a blocker in the session log under "Needs human review", and must surface the missing file to the user before stopping.

### Hook backstop

PostToolUse hook fires after every `git commit` or `git push`:
- Runs `gh run list --limit 1 --json status,conclusion`
- If previous run failed: prepends warning banner to the active runtime's next response
- Does not block — surfaces signal, the active runtime decides
- **Race condition note**: the hook result reflects the most recently completed CI run, not necessarily the run triggered by this push (GitHub may not have enqueued the new run within the hook's execution window). The Step 28 polling loop is the authoritative verification gate — the hook is an early-warning signal only.

---

## Gap 5 — Model Routing (#4) + Agent Teams + GSD Wave Execution (#5)

### Model routing

Default is always the latest Sonnet (claude-sonnet-4-6). No user friction for standard work.

**Phase-specific Opus prompts** — the active runtime asks at the start of two phases only:

1. **Planning phase** (before Step 3 — brainstorming):
   > Entering Planning phase. Use Opus for deeper reasoning, or stay on Sonnet?

2. **Design phase** (before Steps 5–8, if applicable):
   > Entering Design phase. Use Opus, or stay on Sonnet?

If Opus permitted → the active runtime switches to claude-opus-4-6 automatically for that phase, returns to Sonnet for Execution.

**Autonomous mode**: stays on Sonnet throughout. Escalates to Opus silently only if a planning step produces a measurably incomplete result — defined as: output is fewer than 5 lines, or contains placeholder text (`TBD`, `[TODO]`, `...`), or a step expected to produce a file produces none. Escalation is logged as an autonomous decision.

### Agent Teams throughout the workflow

Agent Teams (Agent tool with `isolation: "worktree"`) are used wherever steps are independent:

**Planning — Steps 9–16 (quality gates)**
All 8 quality dimensions dispatched as a single parallel Agent Team wave:
- One agent per dimension: modularity, reusability, scalability, security, reliability, usability, testability, extensibility
- Each agent reads spec + codebase, returns its assessment
- **Conflict resolution**: if two agents flag the same issue with contradictory findings, the more conservative/restrictive finding takes precedence. The active runtime authors a synthesis entry in the session log explaining the resolution rationale before proceeding to Step 17.
- The active runtime synthesises all results before proceeding to Step 17 (`/writing-plans`)

**Execution — Step 18**
GSD's wave-based execution (`/gsd:execute-phase`) drives overall execution orchestration. Each GSD wave dispatches Agent Teams for independent implementation units with `isolation: "worktree"` enforced per agent. Merge gate after each wave before the next begins.

**Review — Steps 19 and 21**
Steps 19 (`/code-review`) and 21 (`/receiving-code-review`) are covered by a parallel Agent Team: security review agent, performance agent, correctness agent. Results consolidated before the active runtime invokes `/receiving-code-review`. Step 20 (`/requesting-code-review` — external/peer review) is human-facing and runs sequentially after the agent wave resolves; it cannot be parallelised.

**Finalization — Steps 26–27**
Tech debt agent and documentation agents run in parallel where doc sections are independent. Documentation agents writing to `docs/` run in the **main worktree only** (no `isolation: "worktree"`), to avoid divergent doc file states that cannot be automatically merged. Only implementation-touching agents use worktree isolation.

**Autonomous mode**: all Agent Team dispatches use `run_in_background: true`.

---

## Implementation Scope

The following changes are required to implement this design:

| Component | Type | Gap(s) |
|-----------|------|--------|
| `docs/KNOWLEDGE.md` template | New file (SB init) | #10 |
| KNOWLEDGE.md update step in workflow | Workflow edit | #10 |
| Phase −1 context load (already loads docs/) | No change needed | #10 |
| `docs/CHANGELOG.md` template | New file (SB init) | #9 |
| `docs/sessions/` directory + session log template | New (SB init + hooks) | #9 |
| Session log hook (PostToolUse, once-per-task with dedup guard) | New hook | #9 |
| Virtual cost estimation in Step 27 | Workflow edit | #3 |
| CHANGELOG.md entry authorship in Step 27 | Workflow edit | #9 |
| Session mode prompt (interactive/autonomous) as Step 0 | New workflow step | #1 |
| Mode flag written to session log header + `/tmp/.silver-bullet-mode` | Hook + workflow | #1 |
| Mode flag read + fallback propagation to Agent Team dispatch calls | CLAUDE.md edit | #1 |
| Anti-stall rules in CLAUDE.md | CLAUDE.md edit | #1 |
| CI setup in Phase 3 (SB init) | SB init edit | #2, #6 |
| CI polling (Step 28) + Step 30 blocker rule | Workflow edit | #2, #6 |
| Post-commit CI status hook | New hook | #2, #6 |
| Opus prompt at Planning + Design phases | Workflow edit | #4 |
| Agent Team dispatch at Steps 9–16 with conflict resolution | Workflow edit | #5 |
| Agent Team dispatch at Steps 19–21 | Workflow edit | #5 |
| Agent Team dispatch at Steps 26–27 (main worktree for docs) | Workflow edit | #5 |
| GSD wave execution at Step 18 | Workflow edit (correct existing) | #5 |

---

*Generated: 2026-04-02 | Silver Bullet v0.2.0*
