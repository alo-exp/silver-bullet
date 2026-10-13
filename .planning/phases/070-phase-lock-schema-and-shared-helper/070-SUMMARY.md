---
phase: 070-phase-lock-schema-and-shared-helper
title: Phase-Lock Schema + Shared Helper
status: complete
completed: 2026-04-28
requirements: [LOCK-01, LOCK-02, LOCK-03, LOCK-04, LOCK-05]
plans:
  - 070-01-PLAN.md  # config + .gitignore
  - 070-02-PLAN.md  # phase-lock.sh helper
  - 070-03-PLAN.md  # test-phase-lock.sh
commits:
  - cbecabe  # feat(070-01): add multi_agent config block + gitignore phase-lock files
  - 7b3ff98  # feat(070-02): add phase-lock.sh atomic lock primitive
  - fe7f548  # test(070-03): add test-phase-lock.sh covering all LOCK-05 cases
key-files:
  created:
    - .planning/scripts/phase-lock.sh                # 496 lines, executable
    - tests/scripts/test-phase-lock.sh               # 239 lines, executable, 37 assertions
  modified:
    - templates/silver-bullet.config.json.default    # +multi_agent block
    - .gitignore                                     # +.planning/.phase-locks.json{,.lock}
test-results: "37 passed, 0 failed"
---

# Phase 70: Phase-Lock Schema + Shared Helper — Summary

Foundational lock primitive for multi-agent phase coordination: lock-state schema,
shared bash helper with atomic claim/heartbeat/release/peek, and full unit-test
coverage. All later phases (71–73) build on this without re-implementing it.

## Plans Executed

| Wave | Plan      | Commit  | Files                                              |
| ---- | --------- | ------- | -------------------------------------------------- |
| 1    | 070-01    | cbecabe | templates/silver-bullet.config.json.default, .gitignore |
| 2    | 070-02    | 7b3ff98 | .planning/scripts/phase-lock.sh                    |
| 3    | 070-03    | fe7f548 | tests/scripts/test-phase-lock.sh                   |

## Requirement Satisfaction

### LOCK-01 — Lock-state schema and file location
- File: `.planning/.phase-locks.json` (gitignored) — top-level JSON object keyed by zero-padded phase number.
- Per-phase value shape: `{owner_id, agent_runtime, claimed_at, last_heartbeat_at, host, pid, intent}`.
- Empty file when no claims active = `{}`; absent file is treated as empty.
- Atomic writes via temp + rename under exclusive mutex; sidecar `.planning/.phase-locks.json.lock` for the mutex.
- **Implemented in:** `.planning/scripts/phase-lock.sh` (`_pl_read_json`, `_pl_write_json`).

### LOCK-02 — Shared helper API (claim / heartbeat / release / peek)
- Script: `.planning/scripts/phase-lock.sh` (executable).
- Four operations with exit codes per the contract:
  - `claim` 0 acquired/stolen-stale, 2 conflict, 3 unknown runtime, 4 usage.
  - `heartbeat` 0 updated, 2 not owned.
  - `release` 0 released or no-op, 2 owned by another.
  - `peek` 0 always; stdout empty=free, JSON=held, JSON+`expired:true`=stale.
- Phase normalization: `70` and `070` resolve to the same key `070` (octal-trap fixed by stripping leading zeros before `printf %03d`).
- Owner-id format: `<runtime>-<hostname-short>-<pid>`, e.g. `claude-MacBookPro-31323`.
- `SB_PHASE_LOCK_INHERITED=true` short-circuits `claim`/`heartbeat`/`release` to no-op exit 0 with INFO stderr; `peek` still works (forward-compat for Phase 73 / AGENT-04).
- `SB_PHASE_LOCK_FILE` overrides the lock file path (testability).
- **Mutex implementation note (deviation from CONTEXT.md `<specifics>` line 141):** The plan called for `flock(1)` exclusively. macOS does not ship `flock`, so the helper preferentially uses `flock` when present and falls back to a portable atomic-`mkdir` spin loop with a 60s stale-lockdir timeout. Both paths satisfy the LOCK-02 atomicity requirement and Plan 03's 10-way parallel test (1 success / 9 conflicts on this machine).

### LOCK-03 — Identity tag registry and runtime validation
- Default seed in `templates/silver-bullet.config.json.default`:
  ```json
  "multi_agent": {
    "identity_tags": ["claude", "forge", "codex", "opencode"],
    "stale_lock_ttl_seconds": 1800
  }
  ```
- Helper resolves tags from `.silver-bullet.json` (project-local) → template default → hard fallback `claude forge codex opencode`.
- Unknown runtime on `claim` exits 3 with stderr listing allowed tags.

### LOCK-04 — Stale-lock TTL with steal semantics
- Default TTL `1800` seconds, configurable via `multi_agent.stale_lock_ttl_seconds`.
- `claim` on stale lock emits `WARN: stealing stale lock from <prior-owner-id> (heartbeat <N>s ago, ttl <T>s)` to stderr and overwrites the entry.
- `peek` on stale lock prints the JSON with extra top-level `"expired": true` field.

### LOCK-05 — Unit tests covering all six required behaviors plus 10-way parallel atomicity
- Test file: `tests/scripts/test-phase-lock.sh` (239 lines, executable, hermetic via `SB_PHASE_LOCK_FILE`).
- 37 assertions across 11 logical test cases:
  1. claim-when-free
  2. claim-when-held-by-other → exit 2, stderr identifies owner
  3. heartbeat-extends-ttl (claimed_at unchanged)
  4. release-by-non-owner → exit 2, lock unchanged
  5. release-by-owner + release-on-free no-op
  6. stale-lock-steal (WARN stderr) + peek `expired:true`
  7. peek-returns-empty-for-free-phase
  8. **10-way parallel atomicity → exactly 1 success, 9 conflicts on this machine**
  9. `SB_PHASE_LOCK_INHERITED=true` no-op for claim/heartbeat/release; peek still works
  10. unknown runtime rejected (exit 3)
  11. phase normalization (`70` ≡ `070`)
- Final result: `Results: 37 passed, 0 failed`.

## Deviations from Plan

### 1. [Rule 3 — blocking environment issue] Portable mutex fallback when flock(1) is absent
- **Found during:** Plan 02 smoke testing.
- **Issue:** macOS does not ship `flock(1)`. The plan specified `flock` as a hard requirement.
- **Fix:** Helper detects `flock` at startup; if present uses it (Linux/CI path), otherwise uses an atomic-`mkdir` spin loop with 60s stale-lockdir cleanup. Both paths share the same `_pl_with_flock` wrapper interface, so the rest of the helper is unchanged.
- **Files modified:** `.planning/scripts/phase-lock.sh`.
- **Verification:** Plan 03 atomicity test (10-way parallel) produces exactly 1 success / 9 conflicts on macOS via the mkdir path.
- **Rationale:** Without this fallback, the helper would be unusable on macOS — the developer's primary platform — making LOCK-05 untestable locally. Behavior matches the spec semantically; only the implementation primitive differs.

### 2. [Rule 1 — bug] Octal interpretation of zero-padded phase numbers
- **Found during:** Plan 02 smoke testing — `claim 070` stored under key `056` (070 octal = 56 decimal) because `printf '%03d' 070` re-parses the input as octal.
- **Fix:** Strip leading zeros from numeric phase input before `printf %03d`; default to `0` if all-zeros.
- **Files modified:** `.planning/scripts/phase-lock.sh` (`_pl_normalize_phase`).
- **Coverage:** Plan 03 Test 11 ("phase normalization") asserts both `70` and `070` map to the same key.

### 3. [Rule 1 — design clarification] Ownership semantics: PID-strict for claim, runtime+host for release/heartbeat
- **Found during:** Plan 02 smoke testing — separate CLI invocations from the same agent could not release their own lock because owner_id includes PID.
- **Issue:** CONTEXT.md says owner_id = `<runtime>-<hostname>-<pid>`, but Plan 03 tests assume `release 070 claude` from a fresh CLI invocation succeeds (different PID), while the 10-way atomicity test assumes different-PID claims conflict (same runtime+host).
- **Fix:** Two-tier ownership model:
  - `claim`: strict owner_id equality (PID matters) → atomicity test passes.
  - `heartbeat` / `release`: runtime+host equality (PID flexible) → CLI ergonomics work.
- **Files modified:** `.planning/scripts/phase-lock.sh` (`_pl_owns_lock` helper used by `cmd_heartbeat` and `cmd_release`).
- **Rationale:** This is the only interpretation that satisfies both atomicity (LOCK-05 case 7) and release-by-owner (LOCK-05 case 1+5) with the spec as written. Cross-runtime and cross-host attempts are still rejected, preserving the safety properties.

### 4. [Rule 3 — test reliability] `set -e` in atomicity subshells
- **Found during:** Plan 03 first test run — atomicity loop intermittently failed with "rcs/2 not found" because the subshell inherited `set -e` from the parent test script and exited before writing the rc file when `claim` returned non-zero.
- **Fix:** Subshell wraps the call with `set +e` before invoking the helper, then captures `$?` explicitly.
- **Files modified:** `tests/scripts/test-phase-lock.sh` (atomicity loop).

## Out of Scope (deferred)

- Wiring `tests/scripts/test-phase-lock.sh` into `tests/run-all-tests.sh` — Plan 03 explicitly defers this to a follow-up; the test file stands on its own.
- Hook integration (Phase 71+).
- Forge custom-agent integration (Phase 72+).
- `/forge-delegate` skill consuming `SB_PHASE_LOCK_INHERITED` (Phase 73 — the helper already honors the env var as required for forward compat).

## Verification

```bash
bash tests/scripts/test-phase-lock.sh
# Results: 37 passed, 0 failed
```

## Self-Check: PASSED

- `.planning/scripts/phase-lock.sh` — exists, executable, syntax-clean
- `tests/scripts/test-phase-lock.sh` — exists, executable, syntax-clean, all assertions pass
- `templates/silver-bullet.config.json.default` — `multi_agent.identity_tags` and `multi_agent.stale_lock_ttl_seconds` present and exact
- `.gitignore` — `.planning/.phase-locks.json` and `.planning/.phase-locks.json.lock` both `git check-ignore`-confirmed
- Commits cbecabe, 7b3ff98, fe7f548 — present in `git log`
