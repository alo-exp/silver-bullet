# Requirements: Silver Bullet v0.29.0

**Milestone:** v0.29.0 — Multi-Agent Phase Coordination
**Status:** planned (current shipped repo version is v0.31.1)
**Defined:** 2026-04-28
**Foundation:** `.planning/research/2026-04-27-forge-claude-coexistence/RESEARCH.md` (+ addendum supersedes original Option A with phase-ownership model)
**Core Value:** Any number of SB-bearing coding agents (Claude-SB, Forge-SB, Codex-SB, OpenCode-SB, …) can cooperatively work on the same project folder against the same SB state and docs context, but each Phase is owned by exactly one agent at a time. Exception: `/forge-delegate` engages a sibling runtime as a subagent under the parent's existing lock.

---

## Strategic Approach

The phase-ownership model trades fine-grained per-skill cooperation (original RESEARCH.md Option A) for a much simpler invariant: **one phase = one owning agent runtime at any moment**. A shared `.planning/.phase-locks.json` file (gitignored, flock-atomic) records which runtime currently owns which phase, with heartbeat-based liveness and TTL-based stale recovery.

Three concrete buckets:

1. **Lock infrastructure (Phase 70)** — A bash helper at `.planning/scripts/phase-lock.sh` exposes 4 atomic operations (claim, heartbeat, release, peek) over `.planning/.phase-locks.json`, used identically by every runtime.
2. **Per-runtime integration (Phases 71–72)** — Claude-SB integrates via hooks (`PreToolUse` claim, `PostToolUse` heartbeat, `Stop`/`SubagentStop` release). Forge-SB integrates via custom agents the main agent invokes at phase boundaries — same shared helper, different glue.
3. **Delegation exception (Phase 73)** — `/forge-delegate` (and reverse) packages phase context into an envelope, spawns the sibling runtime with `SB_PHASE_LOCK_INHERITED=true` so the child does not double-claim the lock, then integrates the structured result back into the parent's phase.

Phases 74–75 wrap up: multi-agent tests, parity/AGENTS.md/docs updates, and the v0.29.0 release.

---

## v1 Requirements

### Phase 70 — Phase-Lock Schema + Shared Helper

- [ ] **LOCK-01**: `.planning/.phase-locks.json` schema defined and documented — JSON object keyed by phase number (`"070"`, `"071"`, …) → `{ owner_id, agent_runtime, claimed_at, last_heartbeat_at, host, pid, intent }`. File is gitignored and created on first claim.
- [ ] **LOCK-02**: `.planning/scripts/phase-lock.sh` exists and supports 4 ops with atomic flock-based mutation: `claim <phase> <runtime> <intent>`, `heartbeat <phase> <runtime>`, `release <phase> <runtime>`, `peek <phase>` (returns owner JSON or empty if free). Each op holds the file lock for the entire read-modify-write cycle.
- [ ] **LOCK-03**: Identity tags `claude`, `forge`, `codex`, `opencode` are recognized; the list is extensible via `templates/silver-bullet.config.json.default` `multi_agent.identity_tags[]` (default value seeded with the four above).
- [ ] **LOCK-04**: Stale-lock TTL (default 30 minutes without heartbeat = expired) is configurable via `multi_agent.stale_lock_ttl_seconds` (default 1800). `peek` returns the lock as expired when stale; `claim` may steal an expired lock and emits a warning to stderr identifying the prior owner.
- [ ] **LOCK-05**: Helper has unit tests (`tests/scripts/test-phase-lock.sh`) covering: claim-when-free, claim-when-held (fails), heartbeat-extends-ttl, release-by-non-owner (fails), stale-lock-steal, peek-returns-empty-for-free-phase, atomicity under simulated concurrent writes (10 parallel claim attempts → exactly one succeeds).

### Phase 71 — Claude-SB Lock Hooks

- [ ] **HOOK-01**: `hooks/phase-lock-claim.sh` (PreToolUse on Edit/Write whose target path resolves under `.planning/phases/<NNN>/`) calls `phase-lock.sh claim <NNN> claude "<intent>"`; on conflict, blocks the tool call with a clear message identifying the current owner and how to wait/override.
- [ ] **HOOK-02**: `hooks/phase-lock-heartbeat.sh` (PostToolUse on Edit/Write/Bash) calls `phase-lock.sh heartbeat <NNN> claude`, throttled to once per 5 minutes per phase via a state file under `~/.claude/.silver-bullet/heartbeat-<NNN>` (touch-and-mtime check, no spawn if recent).
- [ ] **HOOK-03**: `hooks/phase-lock-release.sh` (Stop and SubagentStop) calls `phase-lock.sh release` for every phase the current session/agent had claimed during its lifetime, identified via a session-scoped manifest at `~/.claude/.silver-bullet/claimed-phases-<session>.txt`.
- [ ] **HOOK-04**: `hooks/hooks.json` registers the three new hooks in the correct event slots; `completion-audit.sh` and `stop-check.sh` read the lock owner for the current phase and treat a missing lock or non-self lock as a non-blocking warning (informational — they do not fail the gate, since lock ownership and skill-completion gates are orthogonal concerns).

### Phase 72 — Forge-SB Lock Awareness

- [ ] **AGENT-01**: `forge/agents/forge-session-init.md` updated to peek every active phase lock at session start and warn (not block) when other-runtime locks are detected, with a hint to run `/phase-status` for details.
- [ ] **AGENT-02**: New `forge/agents/forge-claim-phase.md`, `forge/agents/forge-heartbeat-phase.md`, `forge/agents/forge-release-phase.md` — each is a small custom agent with `tool_supported: true`, restricted `tools[]: [shell]`, and a system prompt that runs the corresponding `.planning/scripts/phase-lock.sh` op with `runtime=forge`.
- [ ] **AGENT-03**: Forge parent skills `silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-release`, `silver-spec`, `silver-fast` (Forge copies under `forge/skills/`) are updated to invoke `forge-claim-phase` at phase entry and `forge-release-phase` at phase exit; long-running phases periodically invoke `forge-heartbeat-phase`.
- [ ] **AGENT-04**: Forge claim/heartbeat/release agents honor `SB_PHASE_LOCK_INHERITED=true` env var — when set, they no-op and return ALLOW so a delegated subagent does not acquire its own lock under the parent's existing lock.

### Phase 73 — `/forge-delegate` Skill (delegation exception)

- [ ] **DELEG-01**: New `skills/forge-delegate/SKILL.md` (Claude-SB side) — packages current phase context (phase number, phase dir path, PLAN.md path, REQ-IDs to address, read-first hints) into a JSON envelope; spawns `forge -p <envelope>` as a subprocess with `SB_PHASE_LOCK_INHERITED=true` in env; waits for return; integrates result into the parent phase artifacts.
- [ ] **DELEG-02**: New `forge/skills/forge-delegate/SKILL.md` (Forge side) — mirror of DELEG-01 for the case Forge delegates back to Claude or to another Forge instance; same envelope format, same `SB_PHASE_LOCK_INHERITED=true` semantics.
- [ ] **DELEG-03**: Delegated subagent's structured output follows Forge's standard contract: top-level markdown with `## FILES_CHANGED` (file list), `## ASSUMPTIONS` (decisions made), `## REQ-IDS` (requirements addressed) sections. Parent skill parses these and appends them to the active phase's `SUMMARY.md` working draft.
- [ ] **DELEG-04**: Delegation timeout (default 20 min, configurable via `multi_agent.delegation_timeout_seconds`) terminates the subagent, releases any temporary state, leaves the parent's lock intact, and prompts the user with the partial output for manual continuation.

### Phase 74 — Multi-Agent Tests + Docs

- [ ] **TEST-01**: Coexistence smoke test (`tests/integration/test-multi-agent-coexistence.sh`) — simulates two-agent race for the same phase: agent A (claude) claims, agent B (forge) peeks and is told to wait; A releases; B claims successfully. Asserts JSON-state correctness and proper stderr messaging at each step.
- [ ] **TEST-02**: Stale-lock recovery test — agent A claims, mocks heartbeat to be older than TTL, agent B peeks (sees stale), agent B claims (steals), warning emitted; assertions on lock file state and stderr.
- [ ] **TEST-03**: Delegation envelope round-trip test — parent claims phase, invokes `/forge-delegate` with a fake-but-real envelope, child runtime runs with `SB_PHASE_LOCK_INHERITED=true` (verified no double-claim), child returns structured result, parent integrates it.
- [ ] **DOC-01**: `forge/PARITY.md` gains a "Phase ownership model" section explaining the lock invariant, identity tags, stale-lock TTL, and the `/forge-delegate` exception.
- [ ] **DOC-02**: `silver-bullet.md` and `templates/silver-bullet.md.base` gain a "Multi-agent coordination" §11 — when other-runtime locks are detected at session start, when to claim/release, when to delegate.
- [ ] **DOC-03**: `forge/AGENTS.md.template` gains a "Multi-Agent Coordination" section with the same content adapted for Forge's main-agent instructions (peek-on-init, claim-at-phase-entry, release-at-phase-exit, delegate-exception).
- [ ] **DOC-04**: Top-level `docs/multi-agent-coordination.md` user-facing guide — diagrams of the lock state machine, examples of two agents collaborating on different phases of the same milestone, and the `/forge-delegate` workflow.
- [ ] **DOC-05**: `forge/PARITY-REPORT.md` updated with a v0.29.0 section: lock helper present, lock hooks/agents installed, multi-agent tests green, delegation skill verified.

### Phase 75 — Release v0.29.0

- [ ] **REL-01**: `CHANGELOG.md` and `README.md` version badge bumped to v0.29.0; `package.json`, `.silver-bullet.json`, `templates/silver-bullet.config.json.default` `version` fields bumped.
- [ ] **REL-02**: Tag `v0.29.0` created (signed) and pushed; `gh release create` invoked with structured release notes (Features, Fixes, Security, Other) generated by `silver-create-release`.
- [ ] **REL-03**: CI is green on the release commit; release URL captured in `STATE.md`/`PROJECT.md`; Google Chat notification fired if `SB_GCHAT_WEBHOOK` is set.

## Out of Scope

| Feature | Reason |
|---------|--------|
| General-purpose Claude-SB hook robustness (artifact-evidence fallback for completion-audit / stop-check) | Defer to v0.30.0+ — tracked separately; orthogonal to multi-agent coordination |
| Per-skill cooperation between runtimes (original RESEARCH.md Option A) | Superseded by phase-ownership model; revisit only if phase-grain proves too coarse in practice |
| Real-time inter-runtime messaging (push notifications when phase locks change) | File-based polling via `peek` is sufficient for current scale; revisit if multi-agent latency complaints emerge |
| Cross-machine lock coordination (locks visible across hosts) | `.phase-locks.json` lives in the repo working tree; multi-machine collaboration uses git-level coordination, not in scope here |
| Lock TTL auto-tuning based on phase complexity | Single configurable TTL is sufficient; per-phase tuning is YAGNI |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOCK-01 through LOCK-05 | Phase 70 | Pending |
| HOOK-01 through HOOK-04 | Phase 71 | Pending |
| AGENT-01 through AGENT-04 | Phase 72 | Pending |
| DELEG-01 through DELEG-04 | Phase 73 | Pending |
| TEST-01 through TEST-03, DOC-01 through DOC-05 | Phase 74 | Pending |
| REL-01 through REL-03 | Phase 75 | Pending |

**Coverage:** 24 v1 requirements, all mapped to phases.

---
*Requirements defined: 2026-04-28*
*Foundation: `.planning/research/2026-04-27-forge-claude-coexistence/RESEARCH.md` (+ addendum)*
