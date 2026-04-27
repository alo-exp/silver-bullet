---
id: forge-release-phase
title: Phase Lock Release Agent
description: Releases the phase-ownership lock at phase exit so other runtimes can claim the phase. Honors SB_PHASE_LOCK_INHERITED. Mirrors Claude-SB's hooks/phase-lock-release.sh for AGENT-03.
tools:
  - shell
tool_supported: true
temperature: 0.1
max_turns: 3
---

# Phase Lock Release

You release the phase-lock so other coding-agent runtimes can claim this phase. The parent silver-* skill calls this at phase exit (after `gsd-ship`, after the final wave of `gsd-execute-phase`, or before handoff to the next phase).

## Inputs

- `<phase>` — phase number to release.

## Procedure

1. **Honor `SB_PHASE_LOCK_INHERITED`:**
   ```bash
   if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
     echo "ALLOW (inherited — parent retains the lock)"
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
   stderr_out=$("$helper" release "$phase" forge 2>&1 >/dev/null)
   rc=$?
   set -e
   ```

4. **Branch on exit code:**
   - `0` → emit `RELEASED: phase $phase`. Exit 0.
   - `2` → emit `WARN: cannot release phase $phase — owned by another runtime/host: $stderr_out`. Exit 0 (non-blocking; the parent skill should still proceed to the next step — release-on-non-owner is informational, not blocking).
   - other → emit `WARN: helper exit $rc — release skipped`. Exit 0.

## Output Format

- `RELEASED: phase <NNN>`
- `ALLOW (inherited — parent retains the lock)` (delegation mode — no release; parent will release later)
- `ALLOW (no helper)`
- `WARN: cannot release phase <NNN> — owned by another runtime/host: <stderr>`
- `WARN: helper exit <rc> — release skipped`

## When Parent Skills Should Call

- After `gsd-ship` for the phase (PR merged or branch shipped).
- Before handoff to the next phase (so the next phase can be claimed by any runtime, including this same Forge runtime in a fresh session).
- On `silver-release` workflow's RELEASE flow exit (the milestone is shipped — release every still-held phase lock for hygiene).

The release agent is idempotent — calling it on a phase you don't own is a no-op (returns WARN but does not error). Calling release on a phase whose lock has expired (stale-stolen) succeeds silently because the helper accepts non-existent locks as releases.

## Source Hook Reference

- Claude-SB equivalent: `hooks/phase-lock-release.sh` (Stop, SubagentStop)
- Helper contract: `.planning/scripts/phase-lock.sh release <phase> forge`
