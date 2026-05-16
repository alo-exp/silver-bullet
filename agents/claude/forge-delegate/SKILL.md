---
name: forge-delegate
description: Delegate the current phase's implementation work from Claude-SB to a Forge subagent under the parent's existing phase-lock. Spawns `forge -p <envelope>` with SB_PHASE_LOCK_INHERITED=true so the child does not double-claim, then integrates the structured Forge result into the parent phase artifacts.
argument-hint: "[<extra-instructions-for-forge>]"
version: 0.1.0
---

# /forge-delegate — Cross-Runtime Phase Delegation (Claude-SB side)

The phase-ownership invariant is "one phase = one runtime at a time". `/forge-delegate` is the controlled exception: when the user wants Forge to do the implementation work *underneath* Claude's existing claim, this skill packages the phase context into an envelope, spawns Forge as a subprocess with `SB_PHASE_LOCK_INHERITED=true` in its environment, waits for the structured result, and integrates it into the parent phase's working artifacts.

The child Forge process **inherits** the parent's lock — it does NOT acquire its own. When `/forge-delegate` returns, the parent (Claude) still owns the lock and continues normally.

## Pre-flight: Verify the parent owns a lock

Before spawning Forge, the parent must already hold an active lock on the current phase. If not, refuse to delegate:

```bash
helper="$(git rev-parse --show-toplevel 2>/dev/null)/.planning/scripts/phase-lock.sh"
if [[ ! -x "$helper" ]]; then
  echo "ERR: $helper not executable. /forge-delegate requires the multi-agent helper from Phase 70."
  exit 1
fi

# Resolve current phase from STATE.md or PWD
phase=$(grep -E '^current_phase:' .planning/STATE.md 2>/dev/null | head -1 | sed -E 's/^current_phase:[[:space:]]*//' | tr -d ' "')
if [[ -z "$phase" ]]; then
  echo "ERR: cannot resolve current phase from STATE.md. Set current_phase: <NNN> first."
  exit 1
fi

owner_json=$("$helper" peek "$phase" 2>/dev/null)
owner_runtime=$(printf '%s' "$owner_json" | jq -r '.agent_runtime // ""' 2>/dev/null)
if [[ "$owner_runtime" != "claude" ]]; then
  printf 'ERR: phase %s is not owned by claude (current owner: %s).\n' "$phase" "${owner_runtime:-none}"
  printf '/forge-delegate can only delegate when this runtime holds the lock.\n'
  printf 'Run: .planning/scripts/phase-lock.sh claim %s claude "<intent>"\n' "$phase"
  exit 1
fi
```

## Step 1: Build the delegation envelope

The envelope is a single JSON document that gives Forge everything it needs to work without re-reading the entire repo:

```json
{
  "phase": "<NNN>",
  "phase_dir": ".planning/phases/<NNN-slug>",
  "plan_paths": [".planning/phases/<NNN-slug>/<NNN>-01-PLAN.md", "..."],
  "context_path": ".planning/phases/<NNN-slug>/<NNN>-CONTEXT.md",
  "research_path": ".planning/phases/<NNN-slug>/<NNN>-RESEARCH.md",
  "req_ids": ["LOCK-01", "HOOK-02", "..."],
  "read_first": [
    ".planning/REQUIREMENTS.md",
    ".planning/STATE.md",
    ".planning/scripts/phase-lock.sh",
    "<any phase-specific reference files>"
  ],
  "extra_instructions": "<from $ARGUMENTS, may be empty>",
  "result_contract": "FILES_CHANGED + ASSUMPTIONS + REQ-IDS markdown sections"
}
```

Build it from the current phase's artifacts:

```bash
phase_dir=$(ls -d .planning/phases/${phase}-*/ 2>/dev/null | head -1 | sed 's:/$::')
plans_json=$(ls "${phase_dir}"/*-PLAN.md 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))')
req_ids_json=$(grep -E '^- \[ \] \*\*[A-Z]+-[0-9]+\*\*' .planning/REQUIREMENTS.md 2>/dev/null | grep -E "Phase ${phase}|${phase##0##0}" | sed -E 's/^- \[ \] \*\*([A-Z]+-[0-9]+)\*\*.*/\1/' | jq -Rsc 'split("\n") | map(select(length > 0))')

envelope=$(jq -n \
  --arg phase "$phase" \
  --arg phase_dir "$phase_dir" \
  --argjson plans "$plans_json" \
  --arg context "${phase_dir}/${phase}-CONTEXT.md" \
  --arg research "${phase_dir}/${phase}-RESEARCH.md" \
  --argjson req_ids "$req_ids_json" \
  --arg extra "${ARGUMENTS:-}" \
  '{
    phase: $phase, phase_dir: $phase_dir,
    plan_paths: $plans,
    context_path: $context, research_path: $research,
    req_ids: $req_ids,
    read_first: [".planning/REQUIREMENTS.md", ".planning/STATE.md", ".planning/scripts/phase-lock.sh"],
    extra_instructions: $extra,
    result_contract: "FILES_CHANGED + ASSUMPTIONS + REQ-IDS markdown sections"
  }')
```

## Step 2: Spawn Forge with SB_PHASE_LOCK_INHERITED=true

Use the Forge CLI's `-p` flag to pipe a non-interactive prompt. The child must run with `SB_PHASE_LOCK_INHERITED=true` in its environment so its own `forge-claim-phase` agent (and the helper itself) short-circuits to ALLOW without acquiring a separate lock.

```bash
TIMEOUT_SEC=$(jq -r '.multi_agent.delegation_timeout_seconds // 1200' .silver-bullet.json 2>/dev/null)
TIMEOUT_SEC=${TIMEOUT_SEC:-1200}

prompt=$(cat <<PROMPT_END
You are Forge running as a subagent under Claude-SB's existing phase-lock. Do NOT claim a new lock — \`SB_PHASE_LOCK_INHERITED=true\` is set in your environment, and your custom agents (forge-claim-phase / forge-heartbeat-phase / forge-release-phase) will correctly short-circuit to ALLOW.

Your task is to implement the phase described by the envelope below. Read every file listed in \`read_first\`, then every plan in \`plan_paths\`, then execute the plans in order.

When done, return your output in this **structured markdown contract** so the parent (Claude) can integrate it:

## FILES_CHANGED
<one absolute or repo-relative path per line>

## ASSUMPTIONS
<bullets of any decisions you made that weren't pre-locked in CONTEXT.md>

## REQ-IDS
<comma-separated list of req-ids you addressed, e.g. LOCK-01, LOCK-02, HOOK-03>

## ENVELOPE
$envelope
PROMPT_END
)

set +e
SB_PHASE_LOCK_INHERITED=true \
  timeout "${TIMEOUT_SEC}" forge -p "$prompt" > /tmp/forge-delegate.$$.out 2>/tmp/forge-delegate.$$.err
forge_rc=$?
set -e
result=$(cat /tmp/forge-delegate.$$.out)
err_out=$(cat /tmp/forge-delegate.$$.err)
rm -f /tmp/forge-delegate.$$.out /tmp/forge-delegate.$$.err
```

If the `forge` binary is not on PATH or returns 127, abort with a clear error and instructions to install Forge.

## Step 3: Handle timeout

If `forge_rc == 124` (timeout exit):

```
⚠️ /forge-delegate: Forge subagent exceeded the ${TIMEOUT_SEC} s timeout.
Partial output captured at /tmp/forge-delegate-<pid>.out (preserved).

Parent's lock on phase <NNN> is intact — Claude still owns it.

What to do next:
- Review the partial output and decide whether to manually continue, retry,
  or release the phase for another runtime.
- To increase the timeout: set multi_agent.delegation_timeout_seconds in
  .silver-bullet.json
```

Do NOT release the parent's lock on timeout — Claude retains ownership and the user resumes manually.

## Step 4: Parse and integrate the structured result

When `forge_rc == 0`, parse the three required sections from `$result`:

```bash
files_changed=$(printf '%s' "$result" | awk '/^## FILES_CHANGED$/{flag=1;next}/^## /{flag=0}flag' | grep -v '^$')
assumptions=$(printf '%s'   "$result" | awk '/^## ASSUMPTIONS$/{flag=1;next}/^## /{flag=0}flag')
req_ids=$(printf '%s'       "$result" | awk '/^## REQ-IDS$/{flag=1;next}/^## /{flag=0}flag' | grep -v '^$' | tr -d ' ')
```

If any section is missing, treat the result as malformed — display the raw output and let the user decide whether to integrate manually.

Append the parsed sections to the active phase's working `${phase_dir}/${phase}-SUMMARY.md` draft (creating it if absent):

```markdown
## Delegated to Forge

**Files changed (by Forge):**
${files_changed}

**Forge assumptions:**
${assumptions}

**Req-IDs addressed:**
${req_ids}
```

## Step 5: Verify and continue

After integration, run a quick verify in the parent (Claude) session:

1. `git status` — see what Forge actually changed.
2. Spot-check 1–2 of the listed files to confirm the work matches the plan.
3. If satisfied, the parent continues with whatever follow-up steps come next in the phase's flow (verification, summary, ship).

The parent's phase-lock remains held throughout — Claude owns the phase before, during, and after the delegation.

## Source / Mirror

The Forge-side mirror lives at `forge/skills/forge-delegate/SKILL.md` (DELEG-02) for the symmetric case where Forge delegates work to Claude or to another Forge instance. Both sides use the same envelope shape and `SB_PHASE_LOCK_INHERITED=true` semantics.
