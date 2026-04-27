---
id: forge-heartbeat-phase
title: Phase Lock Heartbeat Agent
description: Refreshes the phase-ownership lock's last_heartbeat_at so it doesn't expire under the stale-TTL steal rule. Invoked by long-running parent skills (gsd-execute-phase, gsd-verify-work) periodically. Honors SB_PHASE_LOCK_INHERITED. Mirrors Claude-SB's hooks/phase-lock-heartbeat.sh for AGENT-02.
tools:
  - shell
tool_supported: true
temperature: 0.1
max_turns: 3
---

# Phase Lock Heartbeat

You refresh the phase-lock so it doesn't expire while the parent silver-* skill is still working on the phase. The lock's stale-TTL (default 1800 s) means another runtime may steal it after 30 minutes of inactivity; long-running phases must heartbeat well before that.

## Inputs

The parent skill calls this agent with one argument:
- `<phase>` — the phase number being heartbeated.

## Procedure

1. **Honor `SB_PHASE_LOCK_INHERITED`:**
   ```bash
   if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
     echo "ALLOW (inherited)"
     exit 0
   fi
   ```

2. **Locate the helper:**
   ```bash
   helper="./.planning/scripts/phase-lock.sh"
   if [[ ! -x "$helper" ]]; then
     echo "ALLOW (no helper)"
     exit 0
   fi
   ```

3. **Call the helper:**
   ```bash
   set +e
   "$helper" heartbeat "$phase" forge >/dev/null 2>&1
   rc=$?
   set -e
   ```

4. **Branch on exit code:**
   - `0` → emit `HEARTBEAT-OK: phase $phase`. Exit 0.
   - `2` → emit `WARN: phase $phase not owned by this runtime/host — heartbeat skipped`. Exit 0 (non-blocking — heartbeat failure must not stop the skill).
   - other → emit `WARN: helper exit $rc — heartbeat skipped`. Exit 0.

## Output Format

- `HEARTBEAT-OK: phase <NNN>` (success)
- `ALLOW (inherited)` (delegation mode)
- `ALLOW (no helper)` (project not initialized)
- `WARN: phase <NNN> not owned by this runtime/host — heartbeat skipped` (lock has been stolen or released; parent skill should NOT continue editing without re-claiming)
- `WARN: helper exit <rc> — heartbeat skipped`

## Cadence Guidance for Parent Skills

Heartbeat once per:
- start of a long-running task (`gsd-execute-phase` per wave, `gsd-verify-work` per pass)
- every ~10–15 minutes of continuous work within a single phase
- before any operation that may take > 5 minutes (build, test suite, deploy)

The default stale-TTL is 1800 s (30 min); cadence above gives ~3–5x safety margin.

## Source Hook Reference

- Claude-SB equivalent: `hooks/phase-lock-heartbeat.sh` (PostToolUse) — that hook is throttled to once per 5 minutes per phase via mtime. The Forge side has no equivalent throttle here because the parent skill drives cadence directly; the helper itself is idempotent.
- Helper contract: `.planning/scripts/phase-lock.sh heartbeat <phase> forge`
