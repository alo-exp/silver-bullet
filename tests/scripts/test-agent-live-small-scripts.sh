#!/usr/bin/env bash
# Small agent-* harness scripts: bundle path helpers, delegation cleanup, env.sh for
# all four hosts, and the invoke.sh aliases that forward to the delegates.
# No host CLI is launched: delegates are replaced by recording stubs in a staged tree.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPTS="$TL_REPO_ROOT/scripts"

# ---------------------------------------------------------------- agent-bundle-paths.sh
# shellcheck source=../../scripts/lib/agent-bundle-paths.sh
source "$SCRIPTS/lib/agent-bundle-paths.sh"

assert_eq "bundle rel claude" "agents/claude" "$(sb_agent_bundle_rel claude)"
assert_eq "bundle rel codex" "host-bundles/codex" "$(sb_agent_bundle_rel codex)"
assert_eq "bundle rel cursor" "host-bundles/cursor" "$(sb_agent_bundle_rel cursor)"
rc=0
err="$(sb_agent_bundle_rel nope 2>&1 >/dev/null)" || rc=$?
assert_eq "bundle rel unknown host fails" "1" "$rc"
assert_contains "bundle rel unknown host names host" "$err" "unknown host: nope"
rc=0
err="$(sb_agent_bundle_rel 2>&1 >/dev/null)" || rc=$?
assert_eq "bundle rel empty host fails" "1" "$rc"
assert_contains "bundle rel empty host message" "$err" "unknown host: "

assert_eq "bundle root with repo root" "/r/agents/claude" "$(sb_agent_bundle_root /r claude)"
assert_eq "bundle root without repo root" "host-bundles/codex" "$(sb_agent_bundle_root '' codex)"
rc=0
err="$(sb_agent_bundle_root /r nope 2>&1)" || rc=$?
assert_eq "bundle root propagates unknown host failure" "1" "$rc"
assert_contains "bundle root unknown host message" "$err" "unknown host: nope"

assert_eq "cache rel claude" "agents/claude" "$(sb_agent_cache_rel claude)"
assert_eq "cache rel codex" "skill-source" "$(sb_agent_cache_rel codex)"
assert_eq "cache rel cursor" "skill-source" "$(sb_agent_cache_rel cursor)"
rc=0
err="$(sb_agent_cache_rel nope 2>&1 >/dev/null)" || rc=$?
assert_eq "cache rel unknown host fails" "1" "$rc"
assert_contains "cache rel unknown host message" "$err" "sb_agent_cache_rel: unknown host: nope"

# ---------------------------------------------------------------- agent-delegation-cleanup.sh
CLEANUP="$SCRIPTS/agent-delegation-cleanup.sh"
STATE_FILE="$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
write_active() { printf '{"active":true,"host":"claude"}\n' >"$STATE_FILE"; }

tl_run bash "$CLEANUP" --help
assert_eq "cleanup --help exits 0" "0" "$TL_STATUS"
assert_contains "cleanup --help prints usage" "$TL_OUT" "Usage: agent-delegation-cleanup.sh [--force]"
tl_run bash "$CLEANUP" -h
assert_eq "cleanup -h exits 0" "0" "$TL_STATUS"

write_active
tl_run bash "$CLEANUP"
assert_eq "cleanup refuses while delegation active" "1" "$TL_STATUS"
assert_contains "cleanup says still active" "$TL_ERR" "delegation still active"
assert_file_exists "cleanup keeps active state without --force" "$STATE_FILE"

tl_run bash "$CLEANUP" --force
assert_eq "cleanup --force exits 0" "0" "$TL_STATUS"
assert_contains "cleanup --force reports cleared" "$TL_OUT" "agent-delegation state cleared"
assert_file_absent "cleanup --force removes state" "$STATE_FILE"

printf '{"active":false}\n' >"$STATE_FILE"
tl_run bash "$CLEANUP"
assert_eq "cleanup with inactive state exits 0" "0" "$TL_STATUS"
assert_contains "cleanup reports nothing active" "$TL_OUT" "no active delegation"
assert_file_absent "cleanup removes inactive state file" "$STATE_FILE"

tl_run bash "$CLEANUP"
assert_eq "cleanup with no state file exits 0" "0" "$TL_STATUS"

# ---------------------------------------------------------------- agent-mode/ctl.sh
CTL="$SCRIPTS/agent-mode/ctl.sh"
CDIR="$TL_TMP/ctl"
mkdir -p "$CDIR"

tl_run bash "$CTL" --help
assert_eq "ctl --help exits 0" "0" "$TL_STATUS"
assert_contains "ctl --help prints usage" "$TL_OUT" "Usage: scripts/agent-mode/ctl.sh"

tl_run bash "$CTL" --bogus
assert_eq "ctl unknown argument exits 2" "2" "$TL_STATUS"
assert_contains "ctl unknown argument named" "$TL_ERR" "unknown argument: --bogus"
assert_contains "ctl unknown argument prints usage to stderr" "$TL_ERR" "Usage:"

tl_run env -u SB_AGENT_CONTROL_DIR bash "$CTL" status
assert_eq "ctl without control dir exits 2" "2" "$TL_STATUS"
assert_contains "ctl without control dir message" "$TL_ERR" "--control-dir or SB_AGENT_CONTROL_DIR required"

tl_run bash "$CTL" --control-dir "$TL_TMP/absent" status
assert_eq "ctl missing control dir exits 2" "2" "$TL_STATUS"
assert_contains "ctl missing control dir message" "$TL_ERR" "control dir missing (interactive-only)"

tl_run bash "$CTL" --control-dir "$CDIR"
assert_eq "ctl without operation exits 2" "2" "$TL_STATUS"
assert_contains "ctl without operation prints usage" "$TL_ERR" "Usage:"

tl_run bash "$CTL" --control-dir "$CDIR" status
assert_eq "ctl without cmd.fifo exits 2" "2" "$TL_STATUS"
assert_contains "ctl without cmd.fifo message" "$TL_ERR" "cmd.fifo missing (not interactive)"

# Regular files stand in for the fifos: python opens them the same way and nothing blocks.
: >"$CDIR/cmd.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" send 'hello "world"'
assert_eq "ctl send exits 0" "0" "$TL_STATUS"
assert_eq "ctl send payload" '{"op": "send", "text": "hello \"world\""}' "$(cat "$CDIR/cmd.fifo")"

: >"$CDIR/cmd.fifo"
tl_run env SB_AGENT_CONTROL_DIR="$CDIR" bash "$CTL" key Enter
assert_eq "ctl key exits 0 (env control dir)" "0" "$TL_STATUS"
assert_eq "ctl key payload" '{"op": "key", "name": "Enter"}' "$(cat "$CDIR/cmd.fifo")"

: >"$CDIR/cmd.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" stop
assert_eq "ctl stop exits 0" "0" "$TL_STATUS"
assert_eq "ctl stop is sent as abort" '{"op": "abort"}' "$(cat "$CDIR/cmd.fifo")"
: >"$CDIR/cmd.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" abort
assert_eq "ctl abort payload" '{"op": "abort"}' "$(cat "$CDIR/cmd.fifo")"

: >"$CDIR/cmd.fifo"
printf 'SCREEN-LINE\nsecond\n' >"$CDIR/reply.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" snapshot
assert_eq "ctl snapshot exits 0" "0" "$TL_STATUS"
assert_eq "ctl snapshot payload" '{"op": "snapshot"}' "$(cat "$CDIR/cmd.fifo")"
assert_contains "ctl snapshot prints reply" "$TL_OUT" "SCREEN-LINE"

: >"$CDIR/cmd.fifo"
printf 'partial-no-newline' >"$CDIR/reply.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" status
assert_eq "ctl status exits 0 on unterminated reply" "0" "$TL_STATUS"
assert_eq "ctl status prints unterminated reply" "partial-no-newline" "$TL_OUT"

: >"$CDIR/cmd.fifo"
: >"$CDIR/reply.fifo"
tl_run bash "$CTL" --control-dir "$CDIR" status
assert_eq "ctl status exits 0 on empty reply" "0" "$TL_STATUS"
assert_eq "ctl status prints nothing for empty reply" "" "$TL_OUT"

# Failure to open the fifos times out after ~8s each; run both waits concurrently.
BADDIR1="$TL_TMP/ctl-bad-cmd"
BADDIR2="$TL_TMP/ctl-bad-reply"
mkdir -p "$BADDIR1/cmd.fifo" "$BADDIR2"
: >"$BADDIR2/cmd.fifo"
bash "$CTL" --control-dir "$BADDIR1" key y >"$TL_TMP/bad1.out" 2>"$TL_TMP/bad1.err" &
pid1=$!
bash "$CTL" --control-dir "$BADDIR2" snapshot >"$TL_TMP/bad2.out" 2>"$TL_TMP/bad2.err" &
pid2=$!
rc1=0
rc2=0
wait "$pid1" || rc1=$?
wait "$pid2" || rc2=$?
assert_eq "ctl unopenable cmd.fifo exits 2" "2" "$rc1"
assert_contains "ctl unopenable cmd.fifo message" "$(cat "$TL_TMP/bad1.err")" "could not open cmd.fifo"
assert_eq "ctl missing reply.fifo exits 2" "2" "$rc2"
assert_contains "ctl missing reply.fifo message" "$(cat "$TL_TMP/bad2.err")" "could not open reply.fifo"

# ---------------------------------------------------------------- env.sh (all hosts)
unset_delegate_env() {
  unset SB_AGENT_CLAUDE_LIGHTWEIGHT SB_AGENT_CODEX_LIGHTWEIGHT SB_AGENT_OPENCODE_LIGHTWEIGHT \
    SB_AGENT_PI_LIGHTWEIGHT SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT PI_MODEL PI_PROVIDER \
    OPENCODE_MODEL OPENCODE_MODEL_PROVIDER OPENCODE_RUN_MODEL
}
unset_delegate_env

for host in claude codex opencode pi; do
  ENVSH="$SCRIPTS/agent-$host/env.sh"
  tl_run bash "$ENVSH" --help
  assert_eq "$host env --help exits 0" "0" "$TL_STATUS"
  assert_contains "$host env --help usage" "$TL_OUT" "Usage: env.sh [--export]"

  tl_run bash "$ENVSH" --nope
  assert_eq "$host env unknown arg exits 2" "2" "$TL_STATUS"
  assert_contains "$host env unknown arg message" "$TL_ERR" "unknown argument: --nope"

  tl_run env CODEX_BIN= bash "$ENVSH"
  assert_eq "$host env summary exits 0" "0" "$TL_STATUS"
  assert_contains "$host env summary prefix" "$TL_OUT" "agent-$host env:"
  assert_contains "$host env summary worker" "$TL_OUT" "worker=1"

  tl_run env SB_E2E_ENTERPRISE_MATRIX=1 bash "$ENVSH" --export
  assert_eq "$host env --export exits 0" "0" "$TL_STATUS"
  assert_contains "$host env --export has worker line" "$TL_OUT" "export SB_ORCHESTRATOR_WORKER=1"
  assert_contains "$host env --export has parent line" "$TL_OUT" "export SB_ORCHESTRATOR_PARENT=0"
  assert_contains "$host env --export has rtk line" "$TL_OUT" "export RTK_DISABLED=1"
  assert_not_contains "$host env --export has no summary line" "$TL_OUT" "agent-$host env:"
done

tl_run bash "$SCRIPTS/agent-claude/env.sh"
assert_eq "claude env summary line" \
  "agent-claude env: lightweight=1 worker=1 interactive=1 ready_timeout=120" "$TL_OUT"
tl_run bash "$SCRIPTS/agent-codex/env.sh"
assert_match "codex env summary line" '^agent-codex env: lightweight=1 worker=1 ready_timeout=120$' "$TL_OUT"
tl_run bash "$SCRIPTS/agent-opencode/env.sh"
assert_eq "opencode env summary line" \
  "agent-opencode env: model=mimo-v2.5 provider=opencode-go lightweight=1 worker=1" "$TL_OUT"
tl_run bash "$SCRIPTS/agent-pi/env.sh"
assert_eq "pi env summary line" \
  "agent-pi env: model=mimo-v2.5 provider=opencode-go lightweight=1 worker=1" "$TL_OUT"

# --export output must be eval-able and reproduce the environment, quoting included.
tl_run env SB_ORCHESTRATOR_WORKER='two words' bash "$SCRIPTS/agent-claude/env.sh" --export
assert_contains "export quotes values with spaces" "$TL_OUT" "export SB_ORCHESTRATOR_WORKER=two\\ words"
evaled="$(env -i PATH="$PATH" bash -c 'eval "$1"; printf "%s|%s" "$CLAUDE_USE_INTERACTIVE" "$SB_AGENT_CLAUDE_DELEGATE"' _ "$TL_OUT")"
assert_eq "export output evals to the delegate env" "1|1" "$evaled"

# A pinned model that violates the MiMo policy makes env.sh fail (errexit) instead of printing.
tl_run env PI_MODEL=other bash "$SCRIPTS/agent-pi/env.sh"
assert_eq "pi env fails for a non-pinned model" "2" "$TL_STATUS"
assert_contains "pi env names the violation" "$TL_ERR" "PI_MODEL must be mimo-v2.5"
tl_run env OPENCODE_MODEL=other bash "$SCRIPTS/agent-opencode/env.sh"
assert_eq "opencode env fails for a non-pinned model" "2" "$TL_STATUS"
assert_contains "opencode env names the violation" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5"

# ---------------------------------------------------------------- invoke.sh aliases
for host in claude codex opencode; do
  FAKE="$TL_TMP/fake-$host"
  mkdir -p "$FAKE/scripts/agent-$host"
  cp "$SCRIPTS/agent-$host/invoke.sh" "$FAKE/scripts/agent-$host/invoke.sh"

  tl_run bash "$FAKE/scripts/agent-$host/invoke.sh" --work-dir /x
  assert_eq "$host invoke without delegate exits 1" "1" "$TL_STATUS"
  assert_contains "$host invoke names missing delegate" "$TL_ERR" "missing delegate: $FAKE/scripts/agent-$host-delegate.sh"

  # present but not executable is still "missing": the guard is -x
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/scripts/agent-$host-delegate.sh"
  tl_run bash "$FAKE/scripts/agent-$host/invoke.sh"
  assert_eq "$host invoke with non-executable delegate exits 1" "1" "$TL_STATUS"

  cat >"$FAKE/scripts/agent-$host-delegate.sh" <<EOF
#!/usr/bin/env bash
printf 'delegate-args:%s\n' "\$*"
exit 7
EOF
  chmod +x "$FAKE/scripts/agent-$host-delegate.sh"
  tl_run bash "$FAKE/scripts/agent-$host/invoke.sh" --skip-preflight --work-dir /x --prompt "a b"
  assert_eq "$host invoke propagates delegate exit status" "7" "$TL_STATUS"
  assert_eq "$host invoke forwards every flag unchanged" "delegate-args:--skip-preflight --work-dir /x --prompt a b" "$TL_OUT"
done

tl_results
