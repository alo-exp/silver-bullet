# Phase 70: Phase-Lock Schema + Shared Helper — Context

**Gathered:** 2026-04-28
**Status:** Ready for planning
**Source:** Derived from REQUIREMENTS.md (LOCK-01..05) + RESEARCH.md addendum (phase-ownership model)

<domain>
## Phase Boundary

Phase 70 delivers the foundational lock primitive that every later phase (71–73) builds on:

- A **lock-state file** at `.planning/.phase-locks.json` (gitignored, atomic via `flock`).
- A **shared bash helper** at `.planning/scripts/phase-lock.sh` exposing 4 atomic operations (`claim`, `heartbeat`, `release`, `peek`).
- **Identity tag** registry seeded with `claude`, `forge`, `codex`, `opencode`, configurable via `multi_agent.identity_tags[]` in `templates/silver-bullet.config.json.default`.
- **Stale-lock TTL** (default 1800 s, configurable via `multi_agent.stale_lock_ttl_seconds`) with steal semantics on `claim`.
- **Unit tests** at `tests/scripts/test-phase-lock.sh` covering all six required behaviors plus 10-way parallel atomicity.

Out of scope for Phase 70 (handled in later phases):
- Hook integration (Phase 71)
- Forge custom-agent integration (Phase 72)
- `/forge-delegate` skill and `SB_PHASE_LOCK_INHERITED` semantics in user code (Phase 73 — but the helper MUST honor the env var as a no-op condition since later phases depend on it)
- Multi-agent integration tests (Phase 74)

</domain>

<decisions>
## Implementation Decisions

### Lock file location and format
- Path: `.planning/.phase-locks.json` (relative to repo root)
- Gitignored: yes — must be added to `.gitignore` if not already covered
- Top-level shape: JSON object keyed by zero-padded phase number (`"070"`, `"071"`, …)
- Per-phase value shape:
  ```json
  {
    "owner_id": "<short id, e.g. claude-shafqat-mac-23456>",
    "agent_runtime": "claude",
    "claimed_at": "<ISO 8601 UTC>",
    "last_heartbeat_at": "<ISO 8601 UTC>",
    "host": "<hostname>",
    "pid": 23456,
    "intent": "<free-form short string passed by caller>"
  }
  ```
- File is created on first `claim` (do not pre-create on repo init).
- Empty file (no claims yet) is `{}` — `peek` on any phase returns empty.

### Helper script API
- Path: `.planning/scripts/phase-lock.sh` (executable, `+x`)
- Shebang: `#!/usr/bin/env bash`; `set -euo pipefail`
- Operations (each holds an exclusive `flock` on a sidecar lockfile `.planning/.phase-locks.json.lock` for the entire read-modify-write):
  1. `phase-lock.sh claim <phase> <runtime> <intent>` — exit 0 on success (lock acquired or stale-stolen with stderr warning); exit non-zero on conflict (active lock by another runtime); writes/updates the entry with current timestamp, host, pid.
  2. `phase-lock.sh heartbeat <phase> <runtime>` — exit 0 if caller owns the lock and `last_heartbeat_at` was updated; exit non-zero if no lock or non-self lock.
  3. `phase-lock.sh release <phase> <runtime>` — exit 0 if caller owned the lock and entry was removed; exit non-zero if not the owner. Releasing a non-existent lock is a no-op (exit 0).
  4. `phase-lock.sh peek <phase>` — prints the lock JSON to stdout (or empty string if free or stale); exit 0 always. Stale entries are emitted with an extra top-level `"expired": true` field for callers that want to detect them without parsing timestamps.
- Phase argument accepts both padded (`070`) and unpadded (`70`) forms; the helper normalizes to padded.
- Atomic write pattern: `(read JSON) | jq ... > tmpfile && mv tmpfile .planning/.phase-locks.json` under flock.

### Identity tags
- Default seed list in `templates/silver-bullet.config.json.default`:
  ```json
  "multi_agent": {
    "identity_tags": ["claude", "forge", "codex", "opencode"],
    "stale_lock_ttl_seconds": 1800
  }
  ```
- Helper reads identity tags from `.silver-bullet.json` (project-local) → falls back to the template default if absent.
- Unknown runtime tag on `claim` exits non-zero with a clear message.

### Stale-lock TTL
- Default: 1800 s (30 min)
- Configurable via `multi_agent.stale_lock_ttl_seconds`
- A lock is stale when `now - last_heartbeat_at > ttl`.
- `peek` reports stale locks with `"expired": true` but does not delete them.
- `claim` may steal a stale lock — emits `WARN: stealing stale lock from <prior-owner-id> (heartbeat <N>s ago, ttl <T>s)` to stderr and proceeds.

### `SB_PHASE_LOCK_INHERITED` env var (forward-compat for Phase 73)
- When `SB_PHASE_LOCK_INHERITED=true` is set in the helper's environment, `claim`, `heartbeat`, and `release` operations are **no-ops that exit 0** with an info line on stderr (`INFO: phase-lock <op> skipped — SB_PHASE_LOCK_INHERITED=true`).
- `peek` still works normally regardless of the env var.
- This must be implemented in Phase 70 because the AGENT-04 / DELEG-01 phases depend on it; AGENT-04 (Phase 72) explicitly tests this no-op behavior.

### Unit tests
- Test runner: bats-style or plain bash `assert`-helpers (match existing pattern in `tests/scripts/`)
- Test file: `tests/scripts/test-phase-lock.sh`
- Setup: each test creates a temp `.planning/.phase-locks.json` under a temp dir and invokes the helper with `--lock-file <path>` (helper must accept this for testability) or via a `SB_PHASE_LOCK_FILE` env override.
- Required test cases (from LOCK-05):
  1. claim-when-free → success, file mutated correctly
  2. claim-when-held-by-other → exit non-zero, stderr identifies current owner
  3. heartbeat-extends-ttl → `last_heartbeat_at` is updated
  4. release-by-non-owner → exit non-zero, lock unchanged
  5. stale-lock-steal → warning on stderr, lock now owned by stealer
  6. peek-returns-empty-for-free-phase → empty stdout, exit 0
  7. atomicity under 10 parallel `claim` attempts → exactly 1 succeeds, 9 fail with conflict (use `wait` and exit-code aggregation)
- Plus: env-var inheritance test — `SB_PHASE_LOCK_INHERITED=true ./phase-lock.sh claim 999 claude noop` exits 0 without mutating the file.

### Config overrides
- New section in `templates/silver-bullet.config.json.default`:
  ```json
  "multi_agent": {
    "identity_tags": ["claude", "forge", "codex", "opencode"],
    "stale_lock_ttl_seconds": 1800
  }
  ```
- Helper resolves config via `jq`-based reads against `.silver-bullet.json` (project-local, optional) merged onto the default template.

### .gitignore
- Add `.planning/.phase-locks.json` and `.planning/.phase-locks.json.lock` to `.gitignore` if not already covered.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Foundation research
- `.planning/research/2026-04-27-forge-claude-coexistence/RESEARCH.md` — full coexistence analysis. Sections 5–6 propose the original Option A (per-skill cooperation, superseded). The **Addendum** (line 246+) supersedes Option A with the phase-ownership model implemented here.

### Project requirements
- `.planning/REQUIREMENTS.md` — LOCK-01 through LOCK-05 are the v1 requirements addressed by this phase.

### Existing helper / lib patterns to mimic
- `hooks/lib/required-skills.sh` — single-source-of-truth lib pattern (jq-based config reads)
- `hooks/lib/workflow-utils.sh` — shared regex/utilities pattern
- `hooks/lib/nofollow-guard.sh` — flock + atomic write reference
- `tests/scripts/test-semantic-compress.sh` — test pattern reference (temp dir, env override, assertions)

### Config defaults file
- `templates/silver-bullet.config.json.default` — where the new `multi_agent` section lives

### Plugin invariants
- `CLAUDE.md` — repo invariants: jq required, `trap 'exit 0' ERR` pattern, state files under `~/.claude/` (does NOT apply here — `.phase-locks.json` is project-local, not user-state)
- `silver-bullet.md` — runtime contract

</canonical_refs>

<specifics>
## Specific Ideas

- **Use `flock(1)`** on a sidecar `.lock` file rather than locking the JSON file itself — simpler, more portable across macOS/Linux, no risk of corrupting the JSON on a partial write.
- **`jq` is mandatory** (consistent with existing `hooks/lib/*.sh` policy). Helper checks `command -v jq` at start; if absent, emits `ERR: jq required` to stderr and exits non-zero. Do NOT fail-open here — unlike hooks, this helper's correctness is critical; silent fail-open would let a runtime believe it owns a lock that was never written.
- **Owner-id format:** `<runtime>-<hostname>-<pid>` (e.g. `claude-shafqat-mac-23456`). This is enough to disambiguate within a single machine; cross-machine coordination is out of scope.
- **`peek` output contract:** when free, prints empty string + exit 0 (callers can `[[ -z "$(peek)" ]]`). When held, prints valid JSON to stdout. When stale, prints valid JSON with extra `"expired": true` field.
- **Lock file directory creation:** if `.planning/` exists but `.planning/.phase-locks.json` does not, the helper creates it as `{}` on first `claim`. If `.planning/` itself does not exist, exit non-zero with a clear message — the helper is for projects already initialized for SB.

</specifics>

<deferred>
## Deferred Ideas

- **Cross-machine lock visibility** — out of scope; multi-machine coordination is via git, not the lock file.
- **Per-phase TTL tuning** — single global TTL is sufficient for v0.29.0.
- **Push notifications when locks change** — file-based polling via `peek` is sufficient; revisit only if multi-agent latency complaints emerge.
- **Lock visualization / `/phase-status` command** — Phase 71+ may add this, not part of Phase 70.

</deferred>

---

*Phase: 070-phase-lock-schema-and-shared-helper*
*Context gathered: 2026-04-28*
