# Multi-Agent Coordination (v0.29.0)

> Any number of SB-bearing coding agents can cooperatively work on the same project folder. Each phase under `.planning/phases/<NNN>/` is owned by exactly one agent runtime at a time. Cross-runtime delegation is the controlled exception.

## The invariant

**One phase = one runtime at a time.** Coding agents that participate include:

| Runtime | Identity tag | Integration |
|---------|--------------|-------------|
| Claude Code (with Silver Bullet plugin) | `claude` | Hooks (`hooks/phase-lock-claim.sh` etc.) |
| Codex-SB | `codex` | Codex hooks and SB package |
| OpenCode-SB | `opencode` | OpenCode-compatible integration |

Identity tags are configurable via `multi_agent.identity_tags[]` in `.silver-bullet.json` (default: the three above). Adding a new runtime requires registering its tag and integrating it with the same `phase-lock.sh` helper.

## Lock state machine

```
                       claim <NNN> <runtime> <intent>
                              ┌─────────────────────────────┐
                              │                             │
                              ▼                             │
                          ┌───────┐    heartbeat <NNN>   ┌──┴────┐
              free  ────► │ HELD  │ ───────────────────► │ HELD  │
              empty       │ <RT>  │      refresh         │ <RT>  │
                          └───┬───┘     ttl=1800s        └───────┘
                              │
                       ┌──────┴──────┐
                       │             │
              release  │     ttl     │  no heartbeat for >1800s
              <NNN>    │   stale     │
              <RT>     │             │
                       │             │
                       ▼             ▼
                   ┌───────┐     ┌────────┐
                   │ free  │     │ STALE  │
                   │       │     │  <RT>  │
                   └───────┘     └───┬────┘
                                     │
                                     │ claim <NNN> <other-RT> "..."
                                     │ (steal — emits WARN to stderr)
                                     ▼
                                ┌───────────┐
                                │  HELD     │
                                │ <other-RT>│
                                └───────────┘
```

**State file:** `.planning/.phase-locks.json` (gitignored, atomic via `flock` on a sidecar). Keyed by zero-padded phase number → `{owner_id, agent_runtime, claimed_at, last_heartbeat_at, host, pid, intent}`.

## Two SB-bearing agents collaborating on the same milestone

Scenario: developer has Claude-SB and Codex-SB both running in the same project folder. Claude is working on Phase 70 while Codex is working on Phase 72.

1. **Claude opens its session.** `hooks/session-start` fires. Claude invokes `/silver:feature` for Phase 70.
2. **Claude claims Phase 70** via `hooks/phase-lock-claim.sh` on its first edit under `.planning/phases/070-*/`. The lock file gains `"070": {"agent_runtime": "claude", ...}`.
3. **Codex opens its own session.** `hooks/session-start` peeks `.planning/.phase-locks.json` and prints `OTHER-RUNTIME-LOCK: phase 070 is owned by claude (...)` in the session summary — informational, not blocking.
4. **Codex invokes `/silver:feature` for Phase 72.** The first edit under `.planning/phases/072-*/` claims the phase through `hooks/phase-lock-claim.sh`.
5. **Both runtimes work simultaneously on different phases.** Each runtime heartbeats its own phase via `hooks/phase-lock-heartbeat.sh`.
6. **Claude finishes Phase 70 and ships.** `hooks/phase-lock-release.sh` releases its lock.
7. **Codex finishes Phase 72.** Its release hook clears the Codex-owned lock at phase exit.

If Codex had tried to edit Phase 70 while Claude held it, `hooks/phase-lock-claim.sh` would block with `BLOCKED: phase 070 is locked by claude (...)`.

## Cross-runtime delegation

The phase-ownership invariant has one controlled exception: when a runtime that holds a lock wants to delegate the implementation work to a sibling runtime *underneath* its existing claim.

```
Claude holds phase 070 lock.
   │
   ├─► active runtime delegation mechanism
   │     ├─ peek confirms claude holds 070
   │     ├─ build envelope { phase, plan_paths, req_ids, ... }
   │     ├─ spawn child runtime with a bounded prompt
   │     │       env: SB_PHASE_LOCK_INHERITED=true
   │     │       timeout: 1200s (configurable)
   │     │
   │     │   In the child session:
   │     │      phase-lock claim → ALLOW (inherited)
   │     │      child does the implementation work
   │     │      emits structured result:
   │     │        ## FILES_CHANGED
   │     │        ## ASSUMPTIONS
   │     │        ## REQ-IDS
   │     │
   │     ├─ parse result, append to {phase}-SUMMARY.md
   │     └─ return to parent
   │
   └─► Claude continues Phase 070 with the delegated work integrated.
       Claude STILL owns the lock — never released.
```

**Key invariants for delegation:**

- The parent always owns the lock. Even on timeout or child failure, the parent retains ownership and the user resumes manually.
- The child runs with `SB_PHASE_LOCK_INHERITED=true`. SB hooks short-circuit their own claim/heartbeat/release to ALLOW under this env var — the child cannot double-claim or accidentally release the parent's lock.
- The result follows a strict markdown contract (`## FILES_CHANGED` / `## ASSUMPTIONS` / `## REQ-IDS`) so the parent can integrate without re-reading every file the child touched.
- `multi_agent.delegation_timeout_seconds` (default 1200) bounds the child's execution. On timeout, the child is killed, partial output is preserved by the active delegation mechanism, and the user is prompted.

## Configuration

`.silver-bullet.json`:
```json
{
  "multi_agent": {
    "identity_tags": ["claude", "codex", "opencode"],
    "stale_lock_ttl_seconds": 1800,
    "delegation_timeout_seconds": 1200
  }
}
```

| Key | Default | Meaning |
|-----|---------|---------|
| `identity_tags` | `["claude","codex","opencode"]` | Recognized runtime identity tags. Unknown tags rejected by `phase-lock.sh claim`. |
| `stale_lock_ttl_seconds` | `1800` | Lock expires after this many seconds without a heartbeat; another runtime may steal with a WARN. |
| `delegation_timeout_seconds` | `1200` | Child runtime delegation timeout. |

## Diagnostics

```bash
# Show all currently-held locks
cat .planning/.phase-locks.json | jq

# Peek a specific phase
.planning/scripts/phase-lock.sh peek 070

# Releasing your own stale claim (run by the runtime that holds it)
.planning/scripts/phase-lock.sh release 070 claude
```

## When NOT to use multi-agent coordination

- Solo development with a single coding agent on a single machine — the locks are no-ops with one runtime.
- Cross-machine coordination — `.planning/.phase-locks.json` lives in the working tree; multi-machine collaboration uses git, not the lock file. The lock is for cooperating agents on the **same** machine + working tree.

## See also

- `silver-bullet.md` §11 (Multi-Agent Coordination) — runtime contract for end-user projects
- `.planning/scripts/phase-lock.sh` — the canonical helper (Phase 70)
