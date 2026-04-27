---
name: forge-delegate
description: Delegate the current phase's implementation work from this Forge runtime to another runtime (Claude-SB, Codex-SB, OpenCode-SB, or another Forge) under the parent's existing phase-lock. Spawns the target runtime's CLI with SB_PHASE_LOCK_INHERITED=true so the child does not double-claim, then integrates the structured result into the parent phase artifacts.
version: 0.1.0
---

# /forge-delegate — Cross-Runtime Phase Delegation (Forge side)

Mirror of the Claude-SB-side `/forge-delegate` skill. The phase-ownership invariant is "one phase = one runtime at a time"; this skill is the controlled exception that lets the current Forge runtime hand off implementation to a sibling runtime *underneath* its existing claim.

## Pre-flight: Verify this Forge runtime owns a lock

```bash
helper="$(git rev-parse --show-toplevel 2>/dev/null)/.planning/scripts/phase-lock.sh"
if [[ ! -x "$helper" ]]; then
  echo "ERR: $helper not executable. /forge-delegate requires the multi-agent helper from Phase 70."
  exit 1
fi

phase=$(grep -E '^current_phase:' .planning/STATE.md 2>/dev/null | head -1 | sed -E 's/^current_phase:[[:space:]]*//' | tr -d ' "')
[[ -z "$phase" ]] && { echo "ERR: cannot resolve current phase from STATE.md."; exit 1; }

owner_runtime=$("$helper" peek "$phase" 2>/dev/null | jq -r '.agent_runtime // ""' 2>/dev/null)
[[ "$owner_runtime" != "forge" ]] && {
  printf 'ERR: phase %s is not owned by forge (current owner: %s).\n' "$phase" "${owner_runtime:-none}"
  exit 1
}
```

## Step 1: Choose the target runtime

The parent agent must specify which runtime to delegate to. Default mappings:
- `--target=claude` → spawn `claude -p <prompt>`
- `--target=codex`  → spawn `codex -p <prompt>` (or the configured Codex-SB CLI invocation)
- `--target=opencode` → spawn `opencode run <prompt>`
- `--target=forge` → spawn another `forge -p <prompt>` (sibling Forge instance)

If no `--target` is provided, default to `claude` (the most common reverse-delegation case).

## Step 2: Build the envelope

Same JSON shape as the Claude-side skill — the envelope is runtime-agnostic:

```json
{
  "phase": "<NNN>",
  "phase_dir": ".planning/phases/<NNN-slug>",
  "plan_paths": ["..."],
  "context_path": "...",
  "research_path": "...",
  "req_ids": ["..."],
  "read_first": [".planning/REQUIREMENTS.md", ".planning/STATE.md", ".planning/scripts/phase-lock.sh"],
  "extra_instructions": "<from $ARGUMENTS>",
  "result_contract": "FILES_CHANGED + ASSUMPTIONS + REQ-IDS markdown sections"
}
```

## Step 3: Spawn the target with SB_PHASE_LOCK_INHERITED=true

```bash
TIMEOUT_SEC=$(jq -r '.multi_agent.delegation_timeout_seconds // 1200' .silver-bullet.json 2>/dev/null)
TIMEOUT_SEC=${TIMEOUT_SEC:-1200}

case "$target" in
  claude)   cmd=(claude   -p "$prompt") ;;
  codex)    cmd=(codex    -p "$prompt") ;;
  opencode) cmd=(opencode run "$prompt") ;;
  forge)    cmd=(forge    -p "$prompt") ;;
  *)        echo "ERR: unknown --target=$target"; exit 1 ;;
esac

set +e
SB_PHASE_LOCK_INHERITED=true \
  timeout "${TIMEOUT_SEC}" "${cmd[@]}" > /tmp/delegate.$$.out 2> /tmp/delegate.$$.err
child_rc=$?
set -e
result=$(cat /tmp/delegate.$$.out)
rm -f /tmp/delegate.$$.out /tmp/delegate.$$.err
```

The child runtime's session-init MUST detect `SB_PHASE_LOCK_INHERITED=true` in its environment and:
- Skip the SessionStart trivial-bypass machinery if applicable.
- Have its `phase-lock-claim`/`phase-lock-heartbeat`/`phase-lock-release` agents/hooks short-circuit to ALLOW.
- Inherit the parent's phase context from the envelope, NOT acquire a separate lock.

Both Claude-SB (Phase 71 hooks) and Forge-SB (Phase 72 agents) honor this contract.

## Step 4: Handle timeout

Same as Claude-side: on `child_rc == 124`, preserve partial output, do NOT release the parent's lock, prompt the user to resume manually.

## Step 5: Parse and integrate

Same structured result contract:

```
## FILES_CHANGED
<repo-relative path per line>

## ASSUMPTIONS
<bullets>

## REQ-IDS
<comma-separated>
```

Append parsed sections to `${phase_dir}/${phase}-SUMMARY.md` under a `## Delegated to <target>` heading. The parent (this Forge runtime) retains the lock and continues normally after integration.

## Source / Mirror

The Claude-SB-side skill lives at `skills/forge-delegate/SKILL.md` (DELEG-01). Both sides use the same envelope and inheritance semantics.
