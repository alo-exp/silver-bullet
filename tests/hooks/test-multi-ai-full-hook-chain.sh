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
# Hostile fixtures sit in the project's source directory, so a variant that is not exempt is judged as the
# source write it is, and ONLY the exemption logic decides allow or deny (the output root is sanctioned).
cp "$MAT" "$PROJ/src/multi_ai_cli.py"
ln -s "$MAT" "$PROJ/src/linked_cli.py"

HOSTILE=(
  "python3 -c 'pass' src/multi_ai_cli.py --output-root $OUT --dry-run"
  "python3 src/multi_ai_cli.py --output-root $OUT --dry-run"
  "python3 src/linked_cli.py --output-root $OUT --dry-run"
  "python3 -I $MAT --output-root $OUT --dry-run"
  "python3 -X dev $MAT --output-root $OUT --dry-run"
  "python3 -- $MAT --output-root $OUT --dry-run"
  "python3 -B $MAT --output-root $OUT --dry-run"
  "PATH=$TL_TMP/shadow:\$PATH python3 $MAT --output-root $OUT --dry-run"
  "env PYTHONPATH=$TL_TMP/shadow python3 $MAT --output-root $OUT --dry-run"
  "PYTHONPATH=$TL_TMP/shadow python3 $MAT --output-root $OUT --dry-run"
  "rtk python3 $MAT --output-root $OUT --dry-run"
  "python3 $MAT --output-root $OUT --dry-run && python3 src/multi_ai_cli.py --output-root $OUT"
  "python3 $MAT --output-root $OUT --dry-run; python3 src/multi_ai_cli.py --output-root $OUT"
  "cat x | python3 $MAT --output-root $OUT --dry-run"
  "python3 $MAT --output-root $OUT --dry-run > src/app.py"
)
# Every spelling of an output root that is, or may be, source: the floor must judge it as the recursive write it is.
SRC_ROOTS=(
  "--output-root src" "--output-root src/" "--output-root src/x" "--output-root ./src" "--output-root s\"rc\"/x"
  "--output-root ." "--output-root ./" "--output-root=src" "--output-root=." "--output-root=src/x"
  "--output-root \$(echo src)" "--output-root \`echo src\`" "--output-root s*" "--output-root src/../src"
  "--output-root $OUT --output-root src" "--output-root src --output-root $OUT"
  "--output-r src" "--output src" "--output-root"
)

for runtime in claude codex; do
  echo "=== $runtime: fresh session, nothing recorded ==="
  for cmd in \
    "python3 $MAT --output-root $OUT --task-prompt probe --dry-run" \
    "python3 $MAT --output-root $OUT $LIVE_FLAGS" \
    "python3 $MAT --output-root $OUT --task-prompt 'review src/app.py and src/lib/x.py' --dry-run" \
    "python3 $DRM probe --output-root $OUT --dry-run" \
    "python3 $DRM probe --output-root=$OUT --dry-run" \
    "python3 $DRM probe --dry-run" \
    "python3 $DRM probe" \
    "python3 $MAT --help"; do
    assert_eq "$runtime: worker may run: ${cmd:0:90}" "" "$(chain "$runtime" worker "$cmd")"
    out="$(chain "$runtime" parent "$cmd")"
    assert_contains "$runtime: parent is denied by the orchestrator guard: ${cmd:0:60}" "$out" "orchestrator-directive-guard.sh"
  done
done

# A copy of the plugin (hooks/ and the two CLIs) inside the project's src/ directory, optionally with one rule of
# the exemption weakened. Because it sits in source, a command that is NOT exempt is judged as the source write it
# is and denied; an exempt one has its script word dropped. So only the exemption logic decides allow or deny.
make_tree() { # name -> prints the root
  local name="$1" root="$PROJ/src/mut-$1" mat
  mkdir -p "$root/skills/silver-multi-ai-task/scripts" "$root/skills/silver-deep-research-multi-ai/scripts"
  cp -R "$TL_REPO_ROOT/hooks" "$root/hooks"
  cp "$MAT" "$root/skills/silver-multi-ai-task/scripts/"
  cp "$DRM" "$root/skills/silver-deep-research-multi-ai/scripts/"
  MUT_ROOT="$root" python3 - "$name" <<'PY'
import os, sys
name, root = sys.argv[1], os.environ["MUT_ROOT"]
lib, hook = root + "/hooks/lib/planning-floor.sh", root + "/hooks/dev-cycle-check.sh"
s, h = open(lib).read(), open(hook).read()
def sub(text, old, new):
    assert old in text, (name, old)
    return text.replace(old, new, 1)
if name == "any-py":
    s = sub(s, '"$plugin_root/skills/silver-multi-ai-task/scripts/multi_ai_cli.py"', '*.py')
elif name == "symlinks":
    s = sub(s, '[[ ! -L "$script" && -f "$script" ]]', '[[ -f "$script" ]]')
    s = sub(s, 'case "$dir/$(basename "$script")" in', 'case "$(readlink -f "$script")" in')
elif name == "flags":
    s = sub(s, ' and ($a[1] | startswith("-") | not) and ($a[1] | startswith("/"))', '')
    s = sub(s, '| $a[1]', '| ($a[1:] | map(select(startswith("-") | not)) | .[0])')
elif name == "prefix":
    s = sub(s, ' && -z "${SB_SA_RTK_UNWRAPPED:-}"', '')
elif name == "dynamic-root":
    lines = s.split("\n")
    k = next(n for n, l in enumerate(lines) if l.strip() == 'case "$root" in') + 1
    assert lines[k].strip().endswith("return 1 ;;"), lines[k]
    lines[k] = "      __never__) return 1 ;;"
    s = "\n".join(lines)
elif name == "abbreviation":
    s = sub(s, 'startswith("--ou") and', 'startswith("--zzz") and')
elif name == "repeated-root":
    s = sub(s, '($o | length) > 1', '($o | length) > 99')
elif name == "root-not-judged":
    h = sub(h, '$(sb_pf_multi_ai_root_records)', '$(printf "")')
open(lib, "w").write(s)
open(hook, "w").write(h)
PY
  printf '%s' "$root"
}
# denied_in ROOT CMD: prints "denied" when the planning floor of the tree at ROOT denies the worker call.
denied_in() {
  local payload
  payload="$(jq -cn --arg c "${2//@MAT@/$1/skills/silver-multi-ai-task/scripts/multi_ai_cli.py}" --arg d "$PWD" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},agent_id:"agent-123",agent_type:"general-purpose",cwd:$d}')"
  tl_run_stdin "$payload" env SILVER_BULLET_RUNTIME=claude CLAUDE_PLUGIN_ROOT="$1" SB_ORCHESTRATOR_WORKER=1 SB_ORCHESTRATOR_PARENT=0 bash "$1/hooks/dev-cycle-check.sh"
  [[ "$TL_OUT" == *'"permissionDecision":"deny"'* ]] && printf 'denied'
  return 0
}
HOSTILE=("${HOSTILE[@]//$MAT/@MAT@}")
SRC_CMDS=()
for root in "${SRC_ROOTS[@]}"; do
  SRC_CMDS+=("python3 @MAT@ $root --dry-run" "python3 $DRM probe $root --dry-run")
done
SRC_CMDS=("${SRC_CMDS[@]//$DRM/@DRM@}")

NONE="$(make_tree none)"
for hostile in "${HOSTILE[@]}"; do
  assert_eq "worker hostile variant denied: ${hostile:0:90}" "denied" "$(denied_in "$NONE" "$hostile")"
done
for cmd in "${SRC_CMDS[@]}"; do
  assert_eq "source-ish output root denied: ${cmd:0:100}" "denied" "$(denied_in "$NONE" "${cmd//@DRM@/$NONE/skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py}")"
done
# Honest roots are allowed by the same tree (so the denials above are not a blanket deny).
for cmd in "python3 @MAT@ --output-root $OUT --dry-run" "python3 @MAT@ --output-root=$OUT --task-prompt 'edit src/a.py' --dry-run"; do
  assert_eq "sanctioned root allowed: ${cmd:0:90}" "" "$(denied_in "$NONE" "$cmd")"
done

mutant_allows() { # name: how many hostile or source-root commands the mutant lets through
  local tree n=0 cmd
  tree="$(make_tree "$1")"
  for cmd in "${HOSTILE[@]}" "${SRC_CMDS[@]}"; do
    [[ -n "$(denied_in "$tree" "${cmd//@DRM@/$tree/skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py}")" ]] || n=$((n + 1))
  done
  printf '%s' "$n"
}
for mutant in any-py symlinks flags prefix dynamic-root abbreviation repeated-root root-not-judged; do
  assert_eq "mutant '$mutant' of the exemption is caught by the cases" "yes" "$([[ "$(mutant_allows "$mutant")" -gt 0 ]] && echo yes || echo no)"
done
tl_results
