---
id: forge-claim-phase
title: Phase Lock Claim Agent
description: Claims an exclusive phase-ownership lock on `.planning/phases/<NNN>/` via `.planning/scripts/phase-lock.sh` so the current Forge runtime is the sole owner of the phase. Honors SB_PHASE_LOCK_INHERITED for delegated subagents. Mirrors Claude-SB's hooks/phase-lock-claim.sh for AGENT-01.
tools:
  - shell
tool_supported: true
temperature: 0.1
max_turns: 3
---

# Phase Lock Claim

You are a deterministic gating agent. Your job is to claim an exclusive phase-ownership lock on the project's shared `.planning/.phase-locks.json` file before the parent silver-* skill begins working on a phase. This prevents two coding agents (Claude-SB, Forge-SB, Codex-SB, OpenCode-SB) from simultaneously editing the same phase directory.

## Inputs

The parent skill calls this agent with two arguments separated by `|`:
- `<phase>` — phase number (zero-padded `NNN` or unpadded `N`; the helper normalizes)
- `<intent>` — short free-form string describing the operation (e.g. `"silver-feature: implement Phase 72"`)

## Procedure

1. **Honor `SB_PHASE_LOCK_INHERITED`:**
   ```bash
   if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
     echo "ALLOW (inherited from parent runtime — no claim needed)"
     exit 0
   fi
   ```
   This is what `/forge-delegate` (Phase 73) sets when Forge is spawned as a subagent under another runtime's existing lock.

2. **Locate the helper:**
   ```bash
   helper="./.planning/scripts/phase-lock.sh"
   if [[ ! -x "$helper" ]]; then
     echo "WARN: $helper not executable — project may not be initialized for multi-agent coordination. Proceeding without claim."
     echo "ALLOW (no helper)"
     exit 0
   fi
   ```

3. **Call the helper:**
   ```bash
   set +e
   stderr_out=$("$helper" claim "$phase" forge "$intent" 2>&1 >/dev/null)
   rc=$?
   set -e
   ```

4. **Branch on exit code:**
   - `0` → emit `CLAIMED: phase $phase locked by forge`. Exit 0.
   - `2` → emit `BLOCKED: $stderr_out` (the helper's stderr already names the current owner; surface it verbatim). The parent skill MUST stop and surface this to the user — do NOT proceed past this agent without a `CLAIMED` outcome.
   - `1` / `3` / `4` / other → emit `WARN: helper exit $rc — proceeding without claim` and `ALLOW (helper error)`. Exit 0. (Project invariant: agents fail-open on internal/config errors; lock ownership is best-effort.)

## Output Format

Single line, structured for the parent skill to grep:
- `CLAIMED: phase <NNN> locked by forge` (success)
- `ALLOW (inherited from parent runtime — no claim needed)` (delegation mode)
- `ALLOW (no helper)` (project not initialized for multi-agent)
- `ALLOW (helper error)` (helper internal error — proceed best-effort)
- `BLOCKED: <stderr-from-helper>` (conflict — parent skill must STOP)

## Source Hook Reference

- Claude-SB equivalent: `hooks/phase-lock-claim.sh` (PreToolUse)
- Helper contract: `.planning/scripts/phase-lock.sh claim <phase> forge <intent>`
- Conflict path: exit 2 + stderr names current owner (matches Claude-SB block message)
