#!/usr/bin/env bash
# The multi-AI skills (silver-multi-ai-task, silver-deep-research-multi-ai) under the orchestrator
# parent guard, the planning-file guard and the agent-delegation guard, on the Claude and Codex
# runtimes: a worker session runs the CLI and it works for its sanctioned output directory;
# the parent session, protected planning files and an active delegation's scope stay protected,
# and the CLI itself refuses the places the hooks cannot see it write to.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_GUARD SB_AGENT_CERT_RUN SILVER_BULLET_PROJECT_ROOT \
  SB_ORCHESTRATOR_PARENT SB_ORCHESTRATOR_WORKER CLAUDECODE CLAUDE_CODE CODEX_SANDBOX CODEX_CI \
  CODEX_THREAD_ID CODEX_INTERNAL_ORIGINATOR_OVERRIDE SB_AGENT_CODEX_DELEGATE CURSOR_AGENT CURSOR_TRACE_ID SB_HOST
# shellcheck source=../../hooks/lib/agent-delegation-state.sh
source "$TL_REPO_ROOT/hooks/lib/agent-delegation-state.sh"

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/src" "$PROJ/.planning/agent-codex/T1"
: >"$PROJ/.planning/ROADMAP.md"
cd "$PROJ"

MAT="$TL_REPO_ROOT/skills/silver-multi-ai-task/scripts/multi_ai_cli.py"
DRM="$TL_REPO_ROOT/skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py"
OK_OUT=".planning/multi-ai/run-1"
CMD_TASK="python3 $MAT --output-root $OK_OUT --task-prompt probe --dry-run"
CMD_DR="python3 $DRM probe --output-root $OK_OUT --dry-run"
CMD_ROADMAP="echo x > .planning/ROADMAP.md"

hook() { # hook CMD [env...]  (prints the hook's output)
  local name="$1" cmd="$2"
  shift 2
  tl_run_stdin "$(tl_hook_json PreToolUse Bash "$cmd")" env "$@" bash "$TL_REPO_ROOT/hooks/$name"
  printf '%s' "$TL_OUT"
}

for runtime in claude codex; do
  echo "=== runtime: $runtime ==="
  for cmd in "$CMD_TASK" "$CMD_DR"; do
    label="${cmd:8:14}"
    out="$(hook orchestrator-directive-guard.sh "$cmd" SILVER_BULLET_RUNTIME=$runtime SB_ORCHESTRATOR_PARENT=1)"
    assert_contains "$runtime: parent session may not run the CLI itself ($label)" "$out" "ORCHESTRATOR PARENT"
    out="$(hook orchestrator-directive-guard.sh "$cmd" SILVER_BULLET_RUNTIME=$runtime SB_ORCHESTRATOR_PARENT=0 SB_ORCHESTRATOR_WORKER=1)"
    assert_eq "$runtime: a worker session runs the CLI ($label)" "" "$out"
    out="$(hook planning-file-guard.sh "$cmd" SILVER_BULLET_RUNTIME=$runtime)"
    assert_eq "$runtime: planning-file-guard lets the CLI write its sanctioned output directory ($label)" "" "$out"
  done
  out="$(hook planning-file-guard.sh "$CMD_ROADMAP" SILVER_BULLET_RUNTIME=$runtime)"
  assert_contains "$runtime: planning-file-guard still denies a protected planning file" "$out" "PLANNING FILE GUARD"
  out="$(hook orchestrator-directive-guard.sh "$CMD_ROADMAP" SILVER_BULLET_RUNTIME=$runtime SB_ORCHESTRATOR_WORKER=1)"
  assert_not_contains "$runtime: the worker exemption is not a parent block" "$out" "ORCHESTRATOR PARENT"
done

echo "=== active agent delegation ==="
sb_agent_delegation_activate codex T1 "$PROJ" "[\"$PROJ/src\"]" "$PROJ/.planning/agent-codex/T1/delegate.log"
out="$(hook agent-delegation-guard.sh "$CMD_TASK")"
assert_eq "delegation guard lets the CLI run for a directory outside the owned scope" "" "$out"
out="$(hook agent-delegation-guard.sh "echo x > src/owned.txt")"
assert_contains "delegation guard still denies a write into the owned scope" "$out" "Active external-agent delegation"
tl_run env SB_HOST=claude python3 "$MAT" --output-root "$PROJ/src/multi-ai" --dry-run
assert_eq "the CLI refuses an output root inside the owned scope (exit)" 2 "$TL_STATUS"
assert_contains "the CLI refuses an output root inside the owned scope (code)" "$TL_OUT" "OUTPUT_ROOT_NOT_ALLOWED"
assert_file_absent "nothing was created in the owned scope" "$PROJ/src/multi-ai"
tl_run env SB_HOST=codex python3 "$DRM" probe --output-root "$PROJ/src/research" --dry-run
assert_eq "the deep-research CLI refuses it too" 2 "$TL_STATUS"
tl_run env SB_HOST=claude python3 "$MAT" --output-root "$PROJ/.planning/agent-codex/T1/multi-ai" --dry-run
assert_eq "the sanctioned evidence directory of the delegation is accepted" 0 "$TL_STATUS"
tl_run env SB_HOST=claude python3 "$MAT" --output-root "$PROJ/$OK_OUT" --dry-run
assert_eq "the CLI accepts its sanctioned output directory during a delegation" 0 "$TL_STATUS"
sb_agent_delegation_deactivate

echo "=== runtime state and plugin cache are never an output root ==="
for protected in "$SB_RUNTIME_STATE_DIR/run" "$HOME/.claude/plugins/cache/x/run" "$HOME/.codex/.silver-bullet/run"; do
  tl_run env SB_HOST=claude python3 "$MAT" --output-root "$protected" --task-prompt probe
  assert_eq "refused (exit): ${protected#"$HOME"/}" 2 "$TL_STATUS"
  assert_contains "refused (code): ${protected#"$HOME"/}" "$TL_OUT" "OUTPUT_ROOT_NOT_ALLOWED"
  assert_file_absent "nothing written: ${protected#"$HOME"/}" "$protected"
done

echo "=== system directories are never an output root (both CLIs) ==="
for sysdir in /etc /etc/sb-fu1 /usr/sb-fu1 /usr/local/sb-fu1 /bin/sb-fu1 /sbin/sb-fu1 /lib/sb-fu1 /lib64/sb-fu1 /sys/sb-fu1 /proc/sb-fu1 /dev/sb-fu1 /boot/sb-fu1 /var/lib/sb-fu1 /opt/sb-fu1; do
  tl_run env SB_HOST=claude python3 "$MAT" --output-root "$sysdir" --dry-run
  assert_eq "multi-ai-task refuses $sysdir (exit)" 2 "$TL_STATUS"
  assert_contains "multi-ai-task refuses $sysdir (code and reason)" "$TL_OUT" "OUTPUT_ROOT_NOT_ALLOWED"
  assert_contains "multi-ai-task names the system directory for $sysdir" "$TL_OUT" "system directory"
  tl_run env SB_HOST=claude python3 "$DRM" probe --output-root "$sysdir" --dry-run
  assert_eq "deep-research refuses $sysdir (exit)" 2 "$TL_STATUS"
  assert_contains "deep-research refuses $sysdir (code)" "$TL_OUT" "OUTPUT_ROOT_NOT_ALLOWED"
done
assert_file_absent "nothing was created under /opt" /opt/sb-fu1
# A project that lives under a system tree (Docker WORKDIR /usr/src/app, /var/www/app, /opt/app) keeps its own output
# roots: allowed when the resolved root is INSIDE the project root (git toplevel, else the .silver-bullet.json
# walk-up root) wherever the CLI is started in it; outside the project the system trees stay refused. A real /usr or /var
# cannot be created without root, so the harness switch stands a temp tree in for one.
SYS="$(mktemp -d)"; mkdir -p "$SYS/usr/src/app/src/deep" "$SYS/usr/bin" "$SYS/var/www/app/src" "$SYS/var/www/other"
printf '{}\n' >"$SYS/usr/src/app/.silver-bullet.json"; printf '{}\n' >"$SYS/var/www/app/.silver-bullet.json"
git -C "$SYS/var/www/other" init -q
run_in() { # DIR TREE args...: python3 args... started in DIR with TREE standing in for a system tree
  tl_run bash -c 'cd "$1"; tree="$2"; shift 2; SILVER_BULLET_TEST_HOOK_ENFORCED=1 SB_MULTI_AI_TEST_SYSTEM_TREE="$tree" SB_HOST=claude python3 "$@"' _ "$@"
}
for cli in "$MAT" "$DRM"; do
  extra=(); [[ "$cli" == "$DRM" ]] && extra=(probe)
  run_in "$SYS/usr/src/app" "$SYS/usr" "$cli" "${extra[@]}" --output-root "$SYS/usr/src/app/.planning/multi-ai/run-1" --dry-run
  assert_eq "$(basename "$cli"): a project at a /usr/src/app-like path keeps its .planning output root" 0 "$TL_STATUS"
  run_in "$SYS/var/www/app/src" "$SYS/var" "$cli" "${extra[@]}" --output-root "$SYS/var/www/app/.planning/multi-ai/run-1" --dry-run
  assert_eq "$(basename "$cli"): started from a subdirectory (/var/www/app/src) the project-root output is allowed" 0 "$TL_STATUS"
  run_in "$SYS/var/www/app/src" "$SYS/var" "$cli" "${extra[@]}" --output-root "$SYS/var/www/other/out" --dry-run
  assert_eq "$(basename "$cli"): another tree under the same system root is outside the project" 2 "$TL_STATUS"
  run_in "$SYS/usr/src/app" "$SYS/usr" "$cli" "${extra[@]}" --output-root "$SYS/usr/bin/x" --dry-run
  assert_eq "$(basename "$cli"): a system path outside the project is refused" 2 "$TL_STATUS"
  tl_run bash -c 'cd "$1" && shift && SB_HOST=claude python3 "$@"' _ "$SYS/usr/src/app" "$cli" "${extra[@]}" --output-root /etc/sb-fu1 --dry-run
  assert_eq "$(basename "$cli"): /etc is refused even from inside a project" 2 "$TL_STATUS"
  tl_run bash -c 'cd "$1" && shift && SB_HOST=claude python3 "$@"' _ "$SYS/usr/src/app" "$cli" "${extra[@]}" --output-root /usr/bin/x --dry-run
  assert_eq "$(basename "$cli"): the real /usr/bin is refused outside the project" 2 "$TL_STATUS"
done
# the harness switch is ignored without the test variable
tl_run bash -c 'cd "$1/usr/src/app" && SB_MULTI_AI_TEST_SYSTEM_TREE="$1/usr" SB_HOST=claude env -u SILVER_BULLET_TEST_HOOK_ENFORCED python3 "$2" --output-root "$1/usr/bin/x" --dry-run' _ "$SYS" "$MAT"
assert_eq "the test-only system tree is ignored without the harness switch" 0 "$TL_STATUS"
# a git toplevel is the project root (no .silver-bullet.json needed), and a missing git falls back to the config walk-up
tl_run bash -c 'cd "$1/var/www/other" && SILVER_BULLET_TEST_HOOK_ENFORCED=1 SB_MULTI_AI_TEST_SYSTEM_TREE="$1/var" SB_HOST=claude python3 "$2" --output-root "$1/var/www/other/.planning/multi-ai/r" --dry-run' _ "$SYS" "$MAT"
assert_eq "a git toplevel is the project root" 0 "$TL_STATUS"
PYBIN="$(command -v python3)"
tl_run bash -c 'cd "$1/var/www/app/src" && PATH=/nonexistent SILVER_BULLET_TEST_HOOK_ENFORCED=1 SB_MULTI_AI_TEST_SYSTEM_TREE="$1/var" SB_HOST=claude "$3" "$2" --output-root "$1/var/www/app/.planning/multi-ai/r" --dry-run' _ "$SYS" "$MAT" "$PYBIN"
assert_eq "without git the .silver-bullet.json walk-up root is the project" 0 "$TL_STATUS"
rm -rf "$SYS"
# the system temp directory stays usable
VARTMP="$(mktemp -d /var/tmp/sb-fu1-tmp.XXXXXX)"
tl_run env SB_HOST=claude TMPDIR="$VARTMP" python3 "$MAT" --output-root "$VARTMP/out" --dry-run
assert_eq "a temp directory that lives under /var stays usable (macOS)" 0 "$TL_STATUS"
rm -rf "$VARTMP"

echo "=== a live run through stub backends works from a worker on either host ==="
STUB="$TL_TMP/stub-cursor-agent"
printf '#!/usr/bin/env bash\necho %q\n' '{"result":"stubbed","sources":[],"confidence":"high"}' >"$STUB"
chmod +x "$STUB"
for host in claude codex; do
  run_out="$PROJ/$OK_OUT-live-$host"
  tl_run env SB_HOST=$host SB_ORCHESTRATOR_WORKER=1 SB_ORCHESTRATOR_PARENT=0 SB_CURSOR_BIN="$STUB" \
    python3 "$MAT" --output-root "$run_out" --task-prompt probe --ocg-pool none --cursor-pool none --include-only composer-2.5
  assert_eq "$host: live run through the stub exits 0" 0 "$TL_STATUS"
  assert_eq "$host: the run reports that host" "$([[ $host == claude ]] && echo claude-code || echo codex)" "$(jq -r .host <<<"$TL_OUT")"
  assert_eq "$host: one authoritative worker result" 1 "$(jq -r .authoritative_count <<<"$TL_OUT")"
  assert_file_exists "$host: result index written under the output root" "$run_out/result-index.json"
  assert_eq "$host: only the output root was written" "" "$(git -C "$PROJ" status --porcelain -- . ':!.planning/multi-ai' ':!.silver-bullet.json' ':!silver-bullet.md' ':!.planning/ROADMAP.md' | tr -d ' ')"
done

echo "=== a missing backend CLI is a backend error, not a host error ==="
tl_run env SB_HOST=claude SB_CURSOR_BIN="$TL_TMP/no-such-cli" python3 "$MAT" --output-root "$PROJ/$OK_OUT-missing" \
  --task-prompt probe --ocg-pool none --cursor-pool none --include-only composer-2.5
assert_eq "all workers failed: exit 1" 1 "$TL_STATUS"
assert_contains "names the backend CLI" "$TL_OUT" "cursor CLI not found"
assert_not_contains "never a host error" "$TL_OUT" "UNSUPPORTED_HOST"
assert_eq "reports the missing backend" '["cursor"]' "$(jq -c .missing_backends <<<"$TL_OUT")"

tl_results
