# Multi-Agent Coordination (v0.29.0)

> Any number of SB-bearing coding agents can cooperatively work on the same project folder. Each phase under `.planning/phases/<NNN>/` is owned by exactly one agent runtime at a time. Cross-runtime delegation is the controlled exception.

## The invariant

**One phase = one runtime at a time.** Coding agents that participate include:

| Runtime | Identity tag | Integration |
|---------|--------------|-------------|
| Claude Code (with Silver Bullet plugin) | `claude` | Hooks (`hooks/phase-lock-claim.sh` etc.) |
| Forge (with Silver Bullet for Forge) | `forge` | Custom agents (`forge/agents/forge-claim-phase.md` etc.) |
| Codex-SB | `codex` | (future) |
| OpenCode-SB | `opencode` | (future) |

Identity tags are configurable via `multi_agent.identity_tags[]` in `.silver-bullet.json` (default: the four above). Adding a new runtime requires registering its tag and integrating it with the same `phase-lock.sh` helper.

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

Scenario: developer has Claude-SB and Forge-SB both running in the same project folder. Claude is working on Phase 70 while Forge is working on Phase 72.

1. **Claude opens its session.** `hooks/session-start` fires. Claude invokes `/silver:feature` for Phase 70.
2. **Claude claims Phase 70** via `hooks/phase-lock-claim.sh` on its first edit under `.planning/phases/070-*/`. The lock file gains `"070": {"agent_runtime": "claude", ...}`.
3. **Forge opens its own session.** `forge-session-init` peeks `.planning/.phase-locks.json` and prints `OTHER-RUNTIME-LOCK: phase 070 is owned by claude (...)` in the session summary — informational, not blocking.
4. **Forge invokes `/silver:feature` for Phase 72.** The skill's "Multi-Agent Phase Coordination" section directs it to invoke `forge-claim-phase 072 "<intent>"`. Forge gets `CLAIMED: phase 072 locked by forge`.
5. **Both runtimes work simultaneously on different phases.** Claude's `PostToolUse/Bash` heartbeats Phase 70 every 5 min via `hooks/phase-lock-heartbeat.sh`; Forge's parent skill calls `forge-heartbeat-phase 072` periodically.
6. **Claude finishes Phase 70 and ships.** `hooks/phase-lock-release.sh` (Stop) releases. Forge's session-init on next session no longer reports the claude lock.
7. **Forge finishes Phase 72.** Parent skill invokes `forge-release-phase 072` at phase exit.

If Forge had tried to claim Phase 70 while Claude held it, `forge-claim-phase` would have returned `BLOCKED: phase 070 is locked by claude (...)` and Forge's parent skill would stop.

## Cross-runtime delegation: `/forge-delegate`

The phase-ownership invariant has one controlled exception: when a runtime that holds a lock wants to delegate the implementation work to a sibling runtime *underneath* its existing claim.

```
Claude holds phase 070 lock.
   │
   ├─► /forge-delegate
   │     ├─ peek confirms claude holds 070
   │     ├─ build envelope { phase, plan_paths, req_ids, ... }
   │     ├─ spawn  forge -p <prompt>
   │     │       env: SB_PHASE_LOCK_INHERITED=true
   │     │       timeout: 1200s (configurable)
   │     │
   │     │   In Forge's child session:
   │     │      forge-claim-phase → ALLOW (inherited)
   │     │      forge does the implementation work
   │     │      emits structured result:
   │     │        ## FILES_CHANGED
   │     │        ## ASSUMPTIONS
   │     │        ## REQ-IDS
   │     │
   │     ├─ parse result, append to {phase}-SUMMARY.md
   │     └─ return to parent
   │
   └─► Claude continues Phase 070 with Forge's work integrated.
       Claude STILL owns the lock — never released.
```

**Key invariants for delegation:**

- The parent always owns the lock. Even on timeout or child failure, the parent retains ownership and the user resumes manually.
- The child runs with `SB_PHASE_LOCK_INHERITED=true`. Both Claude-SB hooks and Forge-SB agents short-circuit their own claim/heartbeat/release to ALLOW under this env var — the child cannot double-claim or accidentally release the parent's lock.
- The result follows a strict markdown contract (`## FILES_CHANGED` / `## ASSUMPTIONS` / `## REQ-IDS`) so the parent can integrate without re-reading every file the child touched.
- `multi_agent.delegation_timeout_seconds` (default 1200) bounds the child's execution. On timeout (rc=124), the child is killed, partial output is preserved at `/tmp/forge-delegate-<pid>.out`, and the user is prompted.

## Configuration

`.silver-bullet.json`:
```json
{
  "multi_agent": {
    "identity_tags": ["claude", "forge", "codex", "opencode"],
    "stale_lock_ttl_seconds": 1800,
    "delegation_timeout_seconds": 1200
  }
}
```

| Key | Default | Meaning |
|-----|---------|---------|
| `identity_tags` | `["claude","forge","codex","opencode"]` | Recognized runtime identity tags. Unknown tags rejected by `phase-lock.sh claim`. |
| `stale_lock_ttl_seconds` | `1800` | Lock expires after this many seconds without a heartbeat; another runtime may steal with a WARN. |
| `delegation_timeout_seconds` | `1200` | `/forge-delegate` child runtime timeout. |

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
- `forge/PARITY.md` — Forge runtime parity table including phase-ownership model
- `.planning/scripts/phase-lock.sh` — the canonical helper (Phase 70)
