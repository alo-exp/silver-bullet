# Phase 71: Claude-SB Lock Hooks — Context

**Gathered:** 2026-04-28
**Status:** Ready for planning
**Source:** REQUIREMENTS.md (HOOK-01..HOOK-04) + Phase 70 helper contract + RESEARCH.md addendum

<domain>
## Phase Boundary

Wires Claude-SB into the phase-lock helper delivered by Phase 70. Three new hook scripts, registration in `hooks/hooks.json`, and informational integration into `completion-audit.sh` / `stop-check.sh`.

Out of scope:
- Forge-side integration (Phase 72)
- `/forge-delegate` skill (Phase 73 — but HOOK-* must honor `SB_PHASE_LOCK_INHERITED=true` as a session-level skip, since a delegated subagent inherits its parent's lock)
- User-facing docs (Phase 74)

</domain>

<decisions>
## Implementation Decisions

### New hook scripts
1. `hooks/phase-lock-claim.sh` — fired as `PreToolUse` on `Edit` / `Write` / `MultiEdit` whose target path resolves under `.planning/phases/<NNN>/`. Determines `<NNN>` from the path, calls `.planning/scripts/phase-lock.sh claim <NNN> claude "<intent>"`. On conflict (helper exit 2), exits 2 with a clear stderr block-message identifying the current owner — Claude Code interprets exit-2 from PreToolUse as a block.
2. `hooks/phase-lock-heartbeat.sh` — fired as `PostToolUse` on `Edit` / `Write` / `MultiEdit` / `Bash`. Resolves the active phase(s) via the session-claim manifest (see HOOK-03). Throttled to once per 5 minutes per phase via touch+mtime check on `~/.claude/.silver-bullet/heartbeat-<NNN>` (real file, not symlink). Uses `sb_safe_write` from `hooks/lib/nofollow-guard.sh`.
3. `hooks/phase-lock-release.sh` — fired as `Stop` and `SubagentStop`. Reads `~/.claude/.silver-bullet/claimed-phases-<session>.txt`, calls `phase-lock.sh release <NNN> claude` for each entry, deletes the manifest on success.

### Session-claim manifest
- File: `~/.claude/.silver-bullet/claimed-phases-<session>.txt`
- `<session>` = Claude Code session id; if unavailable, fall back to a timestamp+pid combo (`$(date +%s)-$$`).
- One line per claimed phase number (zero-padded, e.g. `070`).
- `phase-lock-claim.sh` appends to the manifest after a successful claim (de-duplicated).
- `phase-lock-release.sh` reads it on Stop/SubagentStop and releases each entry.
- Path validation: must remain under `~/.claude/` — reject anything else (mirrors existing `SILVER_BULLET_STATE_FILE` policy).

### `SB_PHASE_LOCK_INHERITED` semantics in hooks
- All three hook scripts check `[[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]` at the very top, after the standard `trap 'exit 0' ERR` line. If set, exit 0 immediately with no side effects. This is the session-level kill-switch for delegated subagents (Phase 73 will set this env var when spawning a sibling runtime).

### Path-to-phase resolution
- Helper function `_resolve_phase_from_path(path)` in a new tiny lib `hooks/lib/phase-path.sh`:
  - Match regex: `\.planning/phases/([0-9]{3})[-/]`
  - If match → emit padded phase number (`070`), exit 0.
  - If no match → emit empty + exit 0 (caller treats as "not a phase-locked path").
- Used by `phase-lock-claim.sh` to extract the phase from a tool's `tool_input.file_path`.

### Heartbeat throttle
- File: `~/.claude/.silver-bullet/heartbeat-<NNN>`
- If file exists and `now - mtime < 300 s` → exit 0 (skip heartbeat).
- Otherwise: call `phase-lock.sh heartbeat <NNN> claude`; on success `touch` the throttle file via `sb_safe_write`.
- Throttle file is per-phase, not per-session, because heartbeats are about lock liveness regardless of session.

### `hooks/hooks.json` registration
Add new entries in the appropriate event arrays:
- **PreToolUse** matchers: append entries for `Edit`, `Write`, `MultiEdit` → `phase-lock-claim.sh`. Existing entries unchanged.
- **PostToolUse** matchers: append entries for `Edit`, `Write`, `MultiEdit`, `Bash` → `phase-lock-heartbeat.sh`.
- **Stop** and **SubagentStop**: append entry → `phase-lock-release.sh`.

Each new hook entry is its own object in the matcher's `hooks[]` array — do not merge with existing scripts.

### `completion-audit.sh` / `stop-check.sh` informational integration
- After existing skill-completion logic, add a non-blocking lock-owner peek:
  ```bash
  current_phase=$(_resolve_phase_from_path "$(pwd)" 2>/dev/null || true)
  if [[ -n "${current_phase}" ]] && command -v jq >/dev/null 2>&1; then
    owner_json=$(.planning/scripts/phase-lock.sh peek "${current_phase}" 2>/dev/null || true)
    if [[ -z "${owner_json}" ]]; then
      printf 'WARN: phase %s has no active lock — proceeding anyway\n' "${current_phase}" >&2
    elif [[ "$(printf '%s' "${owner_json}" | jq -r '.agent_runtime // ""')" != "claude" ]]; then
      printf 'WARN: phase %s is currently locked by %s — proceeding anyway\n' "${current_phase}" "$(printf '%s' "${owner_json}" | jq -r '.owner_id // "?"')" >&2
    fi
  fi
  ```
- This is **informational only** — do NOT change exit codes; the existing skill-completion gate is the only blocking criterion. Lock ownership is orthogonal.

### Session-init heartbeat throttle dir
- `session-start` creates `~/.claude/.silver-bullet/` if missing (already does for `state` and `branch`). No new logic needed beyond ensuring the dir exists when heartbeat hook fires.

### Tests
- `tests/hooks/test-phase-lock-claim.sh` — claim-on-edit, conflict-blocks-edit-via-exit-2, manifest-appended, SB_PHASE_LOCK_INHERITED-bypass.
- `tests/hooks/test-phase-lock-heartbeat.sh` — fires-when-stale, skips-when-recent (throttle), SB_PHASE_LOCK_INHERITED-bypass.
- `tests/hooks/test-phase-lock-release.sh` — releases-each-manifest-entry-on-Stop, deletes-manifest-after, SB_PHASE_LOCK_INHERITED-bypass.
- Tests run via `bash tests/run-all-tests.sh` (existing harness — wire entries into the runner).

### Manifest cleanup safety
- If `phase-lock-release.sh` runs but the helper reports "non-owner" (helper exit non-zero on release), log a warning to stderr but continue clearing other manifest entries. Stop/SubagentStop must never block.

</decisions>

<canonical_refs>
## Canonical References

### Phase 70 helper (the dependency)
- `.planning/scripts/phase-lock.sh` — claim/heartbeat/release/peek operations. Exit codes: 0=ok, 2=conflict, 3=unknown-runtime, 4=non-owner, 1=internal error.
- `.planning/phases/070-phase-lock-schema-and-shared-helper/070-SUMMARY.md` — design notes
- `tests/scripts/test-phase-lock.sh` — pattern reference for hook tests

### Existing hook patterns to mirror
- `hooks/completion-audit.sh` — fail-open ERR trap, jq probe, exit-1-on-block pattern
- `hooks/dev-cycle-check.sh` — PreToolUse path-extraction + exit-2-block pattern
- `hooks/lib/required-skills.sh` — config-read pattern
- `hooks/lib/workflow-utils.sh` — shared lib pattern (where `phase-path.sh` will live)
- `hooks/lib/nofollow-guard.sh` — `sb_safe_write` for the throttle and manifest files

### Hook manifest
- `hooks/hooks.json` — JSON manifest where new hooks register

### Tests
- `tests/hooks/test-completion-audit.sh` — pattern reference
- `tests/run-all-tests.sh` — runner

### Project invariants
- `CLAUDE.md` — jq required, ERR trap (`trap 'exit 0' ERR`), state files under `~/.claude/`, plugin boundary

</canonical_refs>

<specifics>
## Specific Ideas

- Hook scripts read tool input from stdin (Claude Code hook protocol — JSON object). `tool_input.file_path` is the field to parse for Edit/Write/MultiEdit.
- For Bash hooks (heartbeat), there is no file_path — heartbeat fires for any active phase in the session manifest.
- The block message on `phase-lock-claim.sh` conflict should include: phase number, current owner runtime, current owner id, intent, and a hint: "wait or run `.planning/scripts/phase-lock.sh peek <phase>` for details."
- All hooks `trap 'exit 0' ERR` to satisfy the project invariant that hooks never block Claude on internal errors.

</specifics>

<deferred>
## Deferred Ideas

- `/phase-status` user command (could be Phase 74 doc-task or follow-up).
- Auto-release on branch-change (today release fires only on Stop/SubagentStop).
- Heartbeat coalescing across sessions on the same phase — single-session per phase is the working assumption; HOOK-04's lock-owner check warns on cross-session.

</deferred>

---

*Phase: 071-claude-sb-lock-hooks*
*Context gathered: 2026-04-28*
