#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-parent.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SB_ORCHESTRATOR_WORKER_MARKER_TTL_SECONDS SILVER_BULLET_PROJECT_ROOT SB_AGENT_DELEGATE_DIRECT_FALLBACK
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh"
# shellcheck source=../../hooks/lib/orchestrator-state.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"

NOJQ="$(tl_path_without jq)"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
MARKER="$(sb_orchestrator_worker_marker_file)"

echo "=== mode from config ==="
assert_eq "no config: parent" parent "$(sb_orchestrator_mode_from_config)"
assert_eq "missing config file: parent" parent "$(sb_orchestrator_mode_from_config "$TL_TMP/none.json")"
assert_eq "configured parent" parent "$(sb_orchestrator_mode_from_config "$PROJ/.silver-bullet.json")"
printf '{"orchestrator_mode":"worker"}' >"$TL_TMP/c.json"
assert_eq "any other mode collapses to parent" parent "$(sb_orchestrator_mode_from_config "$TL_TMP/c.json")"
printf '{}' >"$TL_TMP/c.json"
assert_eq "unset mode defaults to parent" parent "$(sb_orchestrator_mode_from_config "$TL_TMP/c.json")"
printf 'garbage' >"$TL_TMP/c.json"
assert_eq "corrupt config: parent" parent "$(sb_orchestrator_mode_from_config "$TL_TMP/c.json")"
assert_eq "no jq: parent" parent "$(PATH="$NOJQ" sb_orchestrator_mode_from_config "$PROJ/.silver-bullet.json")"

echo "=== marker file ==="
assert_eq "marker path" "$SB_RUNTIME_STATE_DIR/orchestrator-worker-active.json" "$MARKER"

echo "=== worker session detection ==="
worker() { sb_orchestrator_is_worker_session && echo yes || echo no; }
assert_eq "no signals: not a worker" no "$(worker)"
assert_eq "SB_ORCHESTRATOR_WORKER=1" yes "$(SB_ORCHESTRATOR_WORKER=1 worker)"
assert_eq "SB_ORCHESTRATOR_WORKER=true" yes "$(SB_ORCHESTRATOR_WORKER=true worker)"
assert_eq "SB_ORCHESTRATOR_PARENT=0" yes "$(SB_ORCHESTRATOR_PARENT=0 worker)"
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"spawned_at":"%s"}' "$now_iso" >"$MARKER"
assert_eq "fresh marker: worker" yes "$(worker)"
assert_eq "explicit parent=1 beats a fresh marker" no "$(SB_ORCHESTRATOR_PARENT=1 worker)"
assert_eq "explicit parent=true beats a fresh marker" no "$(SB_ORCHESTRATOR_PARENT=true worker)"
printf '{"spawned_at":"2001-01-01T00:00:00Z"}' >"$MARKER"
assert_eq "stale marker: not a worker" no "$(worker)"
assert_eq "stale marker within a huge ttl" yes "$(SB_ORCHESTRATOR_WORKER_MARKER_TTL_SECONDS=999999999 worker)"
printf '{"spawned_at":"not-a-date"}' >"$MARKER"
assert_eq "unparseable spawned_at: not a worker" no "$(worker)"
printf '{"other":1}' >"$MARKER"
assert_eq "marker without spawned_at: not a worker" no "$(worker)"
printf '{"other":1}' >"$MARKER"
assert_eq "marker without spawned_at, no jq: not a worker" no "$(PATH="$NOJQ" worker)"
printf '{"spawned_at":"%s"}' "$now_iso" >"$MARKER"
assert_eq "no jq: grep fallback reads a fresh marker" yes "$(PATH="$NOJQ" worker)"
printf '{"spawned_at":"2001-01-01T00:00:00Z"}' >"$MARKER"
assert_eq "no jq: grep fallback reads a stale marker" no "$(PATH="$NOJQ" worker)"
rm -f "$MARKER"
printf '{"spawned_at":"%s"}' "$now_iso" >"$TL_TMP/real-marker"
ln -s "$TL_TMP/real-marker" "$MARKER"
assert_eq "symlinked marker ignored" no "$(worker)"
rm -f "$MARKER"
# macOS date flavours: stub `date` so the BSD branches are exercised deterministically.
real_date="$(command -v date)"
cat >"$TL_BIN/date" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"-ju -f"*) [[ -n "\${STUB_JU:-}" ]] && { echo "\$STUB_JU"; exit 0; }; exit 1 ;;
  *"-j -f"*) [[ -n "\${STUB_J:-}" ]] && { echo "\$STUB_J"; exit 0; }; exit 1 ;;
  "+%s") echo 100000 ;;
  *) exec "$real_date" "\$@" ;;
esac
STUB
chmod +x "$TL_BIN/date"
printf '{"spawned_at":"2024-01-01T00:00:00Z"}' >"$MARKER"
assert_eq "BSD date -ju: recent spawn is a worker" yes "$(STUB_JU=99000 worker)"
assert_eq "BSD date -ju: old spawn is not" no "$(STUB_JU=1000 worker)"
assert_eq "BSD date -j: recent spawn is a worker" yes "$(STUB_J=99000 worker)"
assert_eq "BSD date -j: old spawn is not" no "$(STUB_J=1000 worker)"
rm -f "$TL_BIN/date" "$MARKER"

echo "=== workspace boundary ==="
( cd "$TL_TMP" && mkdir -p plain/.git && cd plain && sb_orchestrator_workspace_has_boundary ) && rc=0 || rc=$?
assert_eq "outside an SB project: no boundary" 1 "$rc"
( cd "$PROJ" && sb_orchestrator_workspace_has_boundary ) && rc=0 || rc=$?
assert_eq "inside an SB project: boundary" 0 "$rc"
( unset -f sb_find_project_config_walk_only; cd "$PROJ" && sb_orchestrator_workspace_has_boundary ) && rc=0 || rc=$?
assert_eq "no walk function: no boundary" 1 "$rc"

echo "=== guard applies to workspace ==="
( cd "$TL_TMP/plain" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "no boundary: guard does not apply" 1 "$rc"
( cd "$PROJ" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "boundary, no queue: guard applies" 0 "$rc"
( unset -f sb_find_project_root_walk_only; cd "$PROJ" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "no root resolver: guard does not apply" 1 "$rc"
orch_write_state "$(jq -n --arg r "$PROJ" '{current_flow:"silver-plan",repo_root:$r}')"
( cd "$PROJ" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "queue belongs to this project: guard applies" 0 "$rc"
orch_write_state '{"current_flow":"silver-plan","repo_root":"/somewhere/else"}'
( cd "$PROJ" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "queue from another project: guard does not apply" 1 "$rc"
rm -f "$(orch_state_file)"

echo "=== parent session ==="
parent() { (cd "${1:-$PROJ}" && sb_orchestrator_is_parent_session && echo yes || echo no); }
assert_eq "SB project, no worker signals: parent" yes "$(parent)"
assert_eq "worker env: not parent" no "$(SB_ORCHESTRATOR_WORKER=1 parent)"
assert_eq "outside a project: not parent" no "$(parent "$TL_TMP/plain")"
assert_eq "explicit parent=1 in a project" yes "$(SB_ORCHESTRATOR_PARENT=1 parent)"
assert_eq "explicit parent=true in a project" yes "$(SB_ORCHESTRATOR_PARENT=true parent)"
assert_eq "no jq: parent by default" yes "$(PATH="$NOJQ" parent)"
( unset -f sb_find_project_config_walk_only; cd "$PROJ"; sb_orchestrator_is_parent_session ) && rc=0 || rc=$?
assert_eq "no config resolver: not parent" 1 "$rc"

echo "=== worker template names ==="
while IFS='=' read -r skill want; do
  assert_eq "template for $skill" "$want" "$(sb_orchestrator_worker_template_for_skill "$skill")"
done <<'MAP'
FLOW-BOOTSTRAP=BOOTSTRAP
silver-init=BOOTSTRAP
FLOW-ORIENT=ORIENT
silver-scan=ORIENT
silver-context=ORIENT
silver-clarify=CLARIFY
DECIDE=DECIDE
silver-deep-research=DECIDE
silver-ingest=SPECIFY
devops-skill-router=DEVOPS-SKILL-ROUTER
REVIEW REQUEST=REVIEW-REQUEST
silver-review-request=REVIEW-REQUEST
REVIEW TRIAGE=REVIEW-TRIAGE
silver-review-triage=REVIEW-TRIAGE
silver-branch-finish=BRANCH-FINISH
silver-completion-audit=COMPLETION-AUDIT
silver-plan=PLAN
silver-new-workflow=NEW-WORKFLOW
DESIGN CONTRACT=DESIGN-CONTRACT
silver-ui-contract=DESIGN-CONTRACT
silver-execute=EXECUTE
UI QUALITY=UI-QUALITY
silver-ui-review=UI-QUALITY
silver-review=REVIEW
security=SECURITY
silver-secure=SECURE
silver-verify=VERIFY
QUALITY GATE=QUALITY-GATE
devops-quality-gates=QUALITY-GATE
silver-ship=SHIP
silver-forensics=DEBUG
DESIGN HANDOFF=DESIGN-HANDOFF
silver-handoff=DESIGN-HANDOFF
silver-ensure-docs=DOCUMENT
silver-create-release=RELEASE
silver-blast-radius=BLAST-RADIUS
silver-validate=VALIDATE
silver-fast=FAST
silver=ROUTER
silver-orchestrator=ROUTER
silver-agent-codex=AGENT-DELEGATE
silver-agent-pi=AGENT-DELEGATE
silver-brandnew=BRANDNEW
plainthing=PLAINTHING
MAP

echo "=== worker template path ==="
mkdir -p "$PROJ/templates/orchestrator-workers" "$PROJ/.silver-bullet/orchestrator-workers"
: >"$PROJ/templates/orchestrator-workers/PLAN.md"
assert_eq "template found under templates/" "$PROJ/templates/orchestrator-workers/PLAN.md" "$(sb_orchestrator_worker_template_path "$PROJ" PLAN)"
: >"$PROJ/.silver-bullet/orchestrator-workers/PLAN.md"
assert_eq "project copy wins" "$PROJ/.silver-bullet/orchestrator-workers/PLAN.md" "$(sb_orchestrator_worker_template_path "$PROJ" PLAN)"
sb_orchestrator_worker_template_path "$PROJ" NOPE >/dev/null && rc=0 || rc=$?
assert_eq "missing template fails" 1 "$rc"
sb_orchestrator_worker_template_path "" PLAN >/dev/null && rc=0 || rc=$?
assert_eq "empty root fails" 1 "$rc"

echo "=== mark / clear worker spawn ==="
sb_orchestrator_mark_worker_spawn "" && rc=0 || rc=$?
assert_eq "empty skill rejected" 1 "$rc"
( PATH="$NOJQ"; sb_orchestrator_mark_worker_spawn silver-plan ) && rc=0 || rc=$?
assert_eq "no jq rejected" 1 "$rc"
assert_file_absent "nothing written on rejection" "$MARKER"
sb_orchestrator_mark_worker_spawn silver-plan "" "the args"
assert_eq "marker skill" silver-plan "$(jq -r .skill "$MARKER")"
assert_eq "marker template derived" PLAN "$(jq -r .template "$MARKER")"
assert_eq "marker args" "the args" "$(jq -r .args "$MARKER")"
assert_match "marker timestamp" '^[0-9]{4}-' "$(jq -r .spawned_at "$MARKER")"
assert_eq "fresh marker makes this a worker" yes "$(worker)"
sb_orchestrator_mark_worker_spawn silver-plan CUSTOM
assert_eq "explicit template" CUSTOM "$(jq -r .template "$MARKER")"
sb_orchestrator_clear_worker_marker
assert_file_absent "clear removes the marker" "$MARKER"
sb_orchestrator_clear_worker_marker

echo "=== queue pending ==="
rm -f "$(orch_state_file)"
sb_orchestrator_parent_queue_pending && rc=0 || rc=$?
assert_eq "no state file" 1 "$rc"
orch_write_state '{"current_flow":"silver-plan"}'
sb_orchestrator_parent_queue_pending && rc=0 || rc=$?
assert_eq "current_flow set: pending" 0 "$rc"
( PATH="$NOJQ"; sb_orchestrator_parent_queue_pending ) && rc=0 || rc=$?
assert_eq "no jq: not pending" 1 "$rc"
orch_write_state '{"current_flow":""}'
sb_orchestrator_parent_queue_pending && rc=0 || rc=$?
assert_eq "empty current_flow" 1 "$rc"
orch_write_state '{"current_flow":null}'
sb_orchestrator_parent_queue_pending && rc=0 || rc=$?
assert_eq "null current_flow" 1 "$rc"
printf 'garbage' >"$(orch_state_file)"
sb_orchestrator_parent_queue_pending && rc=0 || rc=$?
assert_eq "corrupt state" 1 "$rc"
( unset -f sb_orchestrator_state_file; export SB_RUNTIME_STATE_DIR="$TL_TMP/alt"; mkdir -p "$TL_TMP/alt"
  echo '{"current_flow":"x"}' >"$TL_TMP/alt/orchestrator.json"; sb_orchestrator_parent_queue_pending ) && rc=0 || rc=$?
assert_eq "falls back to the default state path" 0 "$rc"

echo "=== normalize repo root ==="
sb_orchestrator_normalize_repo_root "" && rc=0 || rc=$?
assert_eq "empty root" 1 "$rc"
ln -sfn "$PROJ" "$TL_TMP/link"
assert_eq "realpath resolves symlinks" "$PROJ" "$(sb_orchestrator_normalize_repo_root "$TL_TMP/link")"
assert_eq "nonexistent root: input echoed" "/no/such/dir" "$(sb_orchestrator_normalize_repo_root /no/such/dir)"
nort="$(tl_path_without realpath)"
assert_eq "no realpath: pwd of the directory" "$PROJ" "$(PATH="$nort" sb_orchestrator_normalize_repo_root "$PROJ")"
assert_eq "no realpath, missing dir: input echoed" "/no/such/dir" "$(PATH="$nort" sb_orchestrator_normalize_repo_root /no/such/dir)"

echo "=== state applies to project ==="
applies() { sb_orchestrator_state_applies_to_project "$@" && echo yes || echo no; }
assert_eq "empty root" no "$(applies "")"
rm -f "$(orch_state_file)"
assert_eq "no queue" no "$(applies "$PROJ")"
orch_write_state "$(jq -n --arg r "$TL_TMP/link" '{current_flow:"a",repo_root:$r}')"
assert_eq "stored root matches through a symlink" yes "$(applies "$PROJ")"
orch_write_state '{"current_flow":"a","repo_root":"/elsewhere"}'
assert_eq "stored root differs" no "$(applies "$PROJ")"
orch_write_state '{"current_flow":"a","repo_root":null,"workflow_id":"WF1"}'
assert_eq "workflow file missing" no "$(applies "$PROJ")"
mkdir -p "$PROJ/.planning/workflows"
: >"$PROJ/.planning/workflows/WF1.md"
assert_eq "workflow file present" yes "$(applies "$PROJ")"
rm -f "$PROJ/.planning/workflows/WF1.md"
ln -s "$TL_TMP/real-marker" "$PROJ/.planning/workflows/WF1.md"
assert_eq "symlinked workflow file rejected" no "$(applies "$PROJ")"
orch_write_state '{"current_flow":"a"}'
assert_eq "no root and no workflow id: unprovable" no "$(applies "$PROJ")"
orch_write_state '{"current_flow":"a","repo_root":"","workflow_id":null}'
assert_eq "empty/null identifiers: unprovable" no "$(applies "$PROJ")"
( unset -f sb_orchestrator_state_file; export SB_RUNTIME_STATE_DIR="$TL_TMP/none"; applies "$PROJ" ) >/dev/null

echo "=== worker bash allowance ==="
sb_orchestrator_worker_allows_bash Bash && rc=0 || rc=$?
assert_eq "non-worker: no bash" 1 "$rc"
for t in Bash exec_command Shell; do
  SB_ORCHESTRATOR_WORKER=1 sb_orchestrator_worker_allows_bash "$t" && rc=0 || rc=$?
  assert_eq "worker may use $t" 0 "$rc"
done
SB_ORCHESTRATOR_WORKER=1 sb_orchestrator_worker_allows_bash Edit && rc=0 || rc=$?
assert_eq "worker may not Edit" 1 "$rc"

echo "=== spawn label ==="
assert_eq "codex label" "spawn_agent (multi_agent_v1.spawn_agent)" "$(SILVER_BULLET_RUNTIME=codex sb_orchestrator_spawn_tool_label)"
assert_eq "claude label" "Agent (Claude subagent)" "$(SILVER_BULLET_RUNTIME=claude sb_orchestrator_spawn_tool_label)"
assert_eq "cursor label" "Task worker" "$(SILVER_BULLET_RUNTIME=cursor sb_orchestrator_spawn_tool_label)"
assert_eq "unset runtime defaults to Task worker" "Task worker" "$(unset SILVER_BULLET_RUNTIME; sb_orchestrator_spawn_tool_label)"

echo "=== parent tool allowance ==="
for t in Task Subagent Agent spawn_agent multi_agent_v1.spawn_agent Read Grep Glob SemanticSearch WebSearch WebFetch AskQuestion SwitchMode UpdateCurrentStep CallMcpTool FetchMcpResource Skill; do
  sb_orchestrator_parent_tool_allowed "$t" && rc=0 || rc=$?
  assert_eq "parent may use $t" 0 "$rc"
done
for t in Edit Write Bash MultiEdit; do
  sb_orchestrator_parent_tool_allowed "$t" && rc=0 || rc=$?
  assert_eq "parent may not use $t" 1 "$rc"
done

echo "=== invoke-skill adapter extraction ==="
x() { sb_orchestrator_extract_invoke_skill_adapter "$1"; }
x "" >/dev/null && rc=0 || rc=$?
assert_eq "empty command" 1 "$rc"
assert_eq "direct silver-bullet invocation" silver-plan "$(x 'silver-bullet invoke-skill silver-plan')"
assert_eq "path-qualified binary" silver-plan "$(x '/usr/local/bin/silver-bullet invoke-skill silver-plan --flag')"
assert_eq "env prefix and assignments" silver-plan "$(x 'env A=1 B=2 silver-bullet invoke-skill silver-plan')"
assert_eq "assignments only prefix" silver-plan "$(x 'A=1 silver-bullet invoke-skill silver-plan')"
assert_eq "bash -c wrapper" silver-plan "$(x "bash -c 'silver-bullet invoke-skill silver-plan'")"
assert_eq "sh -lc wrapper" silver-plan "$(x "sh -lc 'silver-bullet invoke-skill silver-plan'")"
assert_eq "nested wrappers" silver-plan "$(x "bash -c \"sh -c 'silver-bullet invoke-skill silver-plan'\"")"
assert_eq "bash script path" silver-plan "$(x 'bash /opt/bin/silver-bullet invoke-skill silver-plan')"
assert_eq "bash with flags before script" silver-plan "$(x 'bash -x /opt/bin/silver-bullet invoke-skill silver-plan')"
assert_eq "other command: nothing" "" "$(x 'ls -la' || true)"
assert_eq "silver-bullet other subcommand: nothing" "" "$(x 'silver-bullet status' || true)"
assert_eq "silver-bullet without skill arg: nothing" "" "$(x 'silver-bullet invoke-skill' || true)"
assert_eq "bash running another script: nothing" "" "$(x 'bash ./other.sh invoke-skill silver-plan' || true)"
assert_eq "bash script without invoke-skill: nothing" "" "$(x 'bash /opt/silver-bullet status foo' || true)"
assert_eq "bash with a dangling -c flag: nothing" "" "$(x 'bash -c' || true)"
assert_eq "assignment-only command: nothing" "" "$(x 'A=1' || true)"
assert_eq "unbalanced quoting: nothing" "" "$(x "bash -c 'silver-bullet invoke-skill" || true)"
assert_eq "bare env: nothing" "" "$(x 'env' || true)"
( PATH="$(tl_path_without python3)"; sb_orchestrator_extract_invoke_skill_adapter 'silver-bullet invoke-skill silver-plan' ) >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "no python3: extraction fails" 1 "$rc"

echo "=== delegate bash allowance ==="
d() { sb_orchestrator_parent_delegate_bash_allowed "$1" && echo yes || echo no; }
assert_eq "empty command" no "$(d "")"
assert_eq "unrelated command" no "$(d "ls scripts")"
assert_eq "delegate script without fallback" no "$(d "bash scripts/agent-codex-delegate.sh --task t")"
for s in "scripts/agent-codex-delegate.sh" "./scripts/agent-cursor-delegate.sh x" "/repo/scripts/agent-claude-delegate.sh" "scripts/agent-opencode-delegate.sh" "scripts/agent-pi-delegate.sh" "scripts/agent-codex/invoke.sh x" "scripts/agent-claude/invoke.sh" "scripts/agent-opencode/invoke.sh" "scripts/agent-pi/invoke.sh"; do
  assert_eq "fallback allows $s" yes "$(SB_AGENT_DELEGATE_DIRECT_FALLBACK=1 d "bash $s")"
done
assert_eq "spoofed substring is not a delegate" no "$(SB_AGENT_DELEGATE_DIRECT_FALLBACK=1 d "echo myscripts/agent-codex-delegate.shx")"
assert_eq "fallback never widens to other commands" no "$(SB_AGENT_DELEGATE_DIRECT_FALLBACK=1 d "rm -rf /")"

echo "=== ledger resolve bash allowance ==="
l() { sb_orchestrator_parent_resolve_ledger_bash_allowed "$1" && echo yes || echo no; }
assert_eq "empty" no "$(l "")"
assert_eq "plain script" yes "$(l "scripts/resolve-instruction-ledger.sh list")"
assert_eq "bash wrapper" yes "$(l "bash ./scripts/resolve-instruction-ledger.sh done 3")"
assert_eq "quoted" yes "$(l "bash 'scripts/resolve-instruction-ledger.sh'")"
assert_eq "other script" no "$(l "scripts/other.sh")"
assert_eq "suffix spoof" no "$(l "scripts/resolve-instruction-ledger.sh.bak")"

echo "=== parent bash allowance ==="
b() { sb_orchestrator_parent_bash_allowed "$1" && echo yes || echo no; }
assert_eq "empty" no "$(b "")"
assert_eq "router skill adapter allowed" yes "$(b "silver-bullet invoke-skill silver")"
assert_eq "flow-atom adapter refused" no "$(b "silver-bullet invoke-skill silver-plan")"
assert_eq "ledger resolver allowed" yes "$(b "scripts/resolve-instruction-ledger.sh list")"
assert_eq "delegate script via fallback" yes "$(SB_AGENT_DELEGATE_DIRECT_FALLBACK=1 b "bash scripts/agent-codex-delegate.sh")"
assert_eq "delegate script without fallback" no "$(b "bash scripts/agent-codex-delegate.sh")"
assert_eq "read-only command allowed" yes "$(b "git status")"
assert_eq "mutating command refused" no "$(b "rm -rf build")"
# Without the tool-input classifier the parent has no read-only allowance.
staged="$TL_TMP/staged"
mkdir -p "$staged"
cp "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh" "$staged/"
assert_eq "no classifier available: refused" no "$(bash -c 'source "$1"; sb_orchestrator_parent_bash_allowed "git status" && echo yes || echo no' _ "$staged/orchestrator-parent.sh")"

echo "=== parent skill allowance ==="
s() { sb_orchestrator_parent_skill_allowed "$1" && echo yes || echo no; }
for k in silver silver-orchestrator silver-agent-codex silver-agent-cursor silver-agent-claude silver-agent-opencode silver-agent-pi; do
  assert_eq "$k allowed" yes "$(s "$k")"
done
assert_eq "flow atom refused" no "$(s silver-plan)"
# Canonicalisation fallback when the shared helper is not loaded.
assert_eq "sb alias (fallback)" yes "$(s sb)"
assert_eq "sb:orchestrator (fallback)" yes "$(s sb:orchestrator)"
assert_eq "sb-agent-pi (fallback)" yes "$(s sb-agent-pi)"
assert_eq "sb:plan (fallback)" no "$(s sb:plan)"
assert_eq "other namespace (fallback)" no "$(s other:thing)"
sb_skill_canonical_name() { printf 'silver-agent-pi'; }
assert_eq "shared canonicaliser wins" yes "$(s whatever)"
unset -f sb_skill_canonical_name

echo "=== parent context block ==="
orch_make_project "$TL_TMP/p2"
blk="$(cd "$TL_TMP/p2" && SILVER_BULLET_RUNTIME=claude sb_orchestrator_parent_context_block)"
assert_contains "banner" "$blk" "SB ORCHESTRATOR PARENT MODE (mandatory)"
assert_contains "host spawn label" "$blk" "spawn Agent (Claude subagent)"
assert_eq "worker sessions get no banner" "" "$(cd "$TL_TMP/p2" && SB_ORCHESTRATOR_WORKER=1 sb_orchestrator_parent_context_block)"
assert_eq "non-project gets no banner" "" "$(cd "$TL_TMP/plain" && sb_orchestrator_parent_context_block)"

tl_results
