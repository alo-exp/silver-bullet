#!/usr/bin/env bash
# Replays EVERY PreToolUse hook that hooks.json registers for Bash, in a fresh SB session with no skill
# recorded, for a worker and for a parent payload on the claude and codex runtimes: the multi-AI CLIs
# (dry run and live through stub backends) run in a worker, a parent is denied by the orchestrator guard,
# and hostile variants (python -c, a copy in the project, a symlink, PATH shadowing, chaining) are denied.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_GUARD SB_AGENT_CERT_RUN SILVER_BULLET_PROJECT_ROOT \
  SB_ORCHESTRATOR_PARENT SB_ORCHESTRATOR_WORKER CLAUDECODE CLAUDE_CODE CODEX_SANDBOX CODEX_CI CODEX_THREAD_ID \
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE SB_AGENT_CODEX_DELEGATE CURSOR_AGENT CURSOR_TRACE_ID SB_HOST

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/src"
git -C "$PROJ" add -A >/dev/null 2>&1 || true
cd "$PROJ"
MAT="$TL_REPO_ROOT/skills/silver-multi-ai-task/scripts/multi_ai_cli.py"
DRM="$TL_REPO_ROOT/skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py"
OUT=".planning/multi-ai/run-1"
cp "$MAT" "$PROJ/multi_ai_cli.py"
ln -s "$MAT" "$PROJ/linked_cli.py"
mkdir -p "$TL_TMP/shadow"

# The hook commands registered for the Bash tool, in order, without duplicates.
HOOKS="$(jq -r '.hooks.PreToolUse[] | select(.matcher | test("(^|\\|)(Bash)(\\||$)") or . == ".*") | .hooks[].command' "$TL_REPO_ROOT/hooks/hooks.json" \
  | sed 's/^"//; s/"$//; s#\${CLAUDE_PLUGIN_ROOT}#'"$TL_REPO_ROOT"'#' | awk '!seen[$0]++')"
[[ "$(wc -l <<<"$HOOKS")" -ge 10 ]] || { echo "FAIL: too few Bash hooks found"; exit 1; }

# chain RUNTIME ROLE COMMAND: prints "hook: output" for every hook that denied.
chain() {
  local runtime="$1" role="$2" cmd="$3" payload hook denied=""
  local env_args=(SILVER_BULLET_RUNTIME="$runtime" CLAUDE_PLUGIN_ROOT="$TL_REPO_ROOT")
  if [[ "$role" == worker ]]; then
    payload="$(jq -cn --arg c "$cmd" --arg d "$PWD" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},agent_id:"agent-123",agent_type:"general-purpose",cwd:$d}')"
    env_args+=(SB_ORCHESTRATOR_WORKER=1 SB_ORCHESTRATOR_PARENT=0)
  else
    payload="$(jq -cn --arg c "$cmd" --arg d "$PWD" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}')"
    env_args+=(SB_ORCHESTRATOR_PARENT=1)
  fi
  while IFS= read -r hook; do
    tl_run_stdin "$payload" env "${env_args[@]}" bash "$hook"
    if [[ "$TL_STATUS" == 2 || "$TL_OUT" == *'"permissionDecision":"deny"'* ]]; then
      denied="${denied}${hook##*/}: ${TL_OUT:0:160}${TL_ERR:0:120}"$'\n'
    fi
  done <<<"$HOOKS"
  printf '%s' "$denied"
}

LIVE_FLAGS="--task-prompt probe --ocg-pool none --cursor-pool none --include-only composer-2.5"
for runtime in claude codex; do
  echo "=== $runtime: fresh session, nothing recorded ==="
  for cmd in \
    "python3 $MAT --output-root $OUT --task-prompt probe --dry-run" \
    "python3 $MAT --output-root $OUT $LIVE_FLAGS" \
    "python3 $DRM probe --output-root $OUT --dry-run" \
    "python3 $MAT --help"; do
    assert_eq "$runtime: worker may run: ${cmd:0:60}" "" "$(chain "$runtime" worker "$cmd")"
    out="$(chain "$runtime" parent "$cmd")"
    assert_contains "$runtime: parent is denied by the orchestrator guard: ${cmd:0:60}" "$out" "orchestrator-directive-guard.sh"
  done
  for hostile in \
    "python3 -c 'import os; os.system(\"true\")' --output-root src/x" \
    "python3 multi_ai_cli.py --output-root src/x --dry-run" \
    "python3 linked_cli.py --output-root src/x --dry-run" \
    "PATH=$TL_TMP/shadow:\$PATH python3 $MAT --output-root src/x --dry-run" \
    "env PYTHONPATH=$TL_TMP/shadow python3 $MAT --output-root src/x --dry-run" \
    "python3 $MAT --output-root $OUT --dry-run && python3 multi_ai_cli.py --output-root src/x" \
    "python3 $MAT --output-root src/x --dry-run > src/app.py" \
    "cat x | python3 $MAT --output-root src/x --dry-run" \
    "python3 $MAT --output-root src/x --dry-run" \
    "python3 $DRM probe --output-root src/x --dry-run"; do
    assert_contains "$runtime: worker hostile variant denied: ${hostile:0:70}" "$(chain "$runtime" worker "$hostile")" ": "
  done
done
tl_results
