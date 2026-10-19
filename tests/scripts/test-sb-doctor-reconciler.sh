#!/usr/bin/env bash
# sb-doctor.sh D10: the generic five-tool manifest, the reconciler verdict table, deep
# probes, dry-run, --fix confirmation (including a real pseudo-terminal) and the
# reconciler apply step. The reconciler is a logging stub in the staged repo.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-doctor-stage.sh"
cd "$TL_TMP"
unset SB_DOCTOR_FIX SB_DOCTOR_FIX_SCOPE SB_DOCTOR_DEEP SB_DOCTOR_DRY_RUN SB_DOCTOR_FORMAT SB_DOCTOR_RECONCILER SB_DOCTOR_ASSUME_YES SB_DOCTOR_STUB_HOST_INSTALL
unset SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME FIVE_TOOL_STACK_HOME XDG_STATE_HOME XDG_DATA_HOME
hd_stage
hd_happy claude
C='SILVER_BULLET_RUNTIME=claude'
J='SB_DOCTOR_FORMAT=json'
run() { hd_run "$C" "$@"; }

comp() {  # id state consent [activation] [evidence-json]
  jq -nc --arg id "$1" --arg st "$2" --arg consent "$3" --arg act "${4:-none}" --argjson ev "${5:-[]}" \
    '{component:$id,consent:$consent,canonical_state:$st,activation_status:$act,evidence:$ev,repairable:($st=="repairable")}'
}
recon() { jq -nc --argjson c "$1" --argjson u "${2:-[]}" '{components:$c,unknown_keys:$u}'; }
CROSS_OK="$(comp cross_tool ready enabled full)"

# ---------- D10-generic: the global manifest ----------
mkdir -p "$TL_TMP/fts"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/fts/manifest.json"
run -- "$HD_PROJ"
assert_contains "manifest path from SB_GLOBAL_TOOLSTACK_MANIFEST" "$TL_OUT" "WARN: D10-generic — generic stack absent ($TL_TMP/fts/manifest.json)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST
export SB_GLOBAL_TOOLSTACK_HOME="$TL_TMP/fts"
run -- "$HD_PROJ"
assert_contains "manifest path from SB_GLOBAL_TOOLSTACK_HOME" "$TL_OUT" "generic stack absent ($TL_TMP/fts/instances.json)"
unset SB_GLOBAL_TOOLSTACK_HOME
export FIVE_TOOL_STACK_HOME="$TL_TMP/five"
run -- "$HD_PROJ"
assert_contains "manifest path from FIVE_TOOL_STACK_HOME" "$TL_OUT" "generic stack absent ($TL_TMP/five/manifest.json)"
unset FIVE_TOOL_STACK_HOME
export XDG_STATE_HOME="$TL_TMP/xdg"
run -- "$HD_PROJ"
assert_contains "manifest path from XDG_STATE_HOME" "$TL_OUT" "generic stack absent ($TL_TMP/xdg/five-tool-stack/manifest.json)"
unset XDG_STATE_HOME

# the runtime package: the real one validates a manifest it generated itself
rm -rf -- "${HD_ST:?}/scripts/lib/five_tool_runtime"
ln -s "$TL_REPO_ROOT/scripts/lib/five_tool_runtime" "$HD_ST/scripts/lib/five_tool_runtime"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/fts/manifest.json"
printf '{"schema":"wrong"}\n' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
run -- "$HD_PROJ"
assert_eq "an invalid manifest fails the audit" "1" "$TL_STATUS"
assert_contains "invalid manifest reported with details" "$TL_OUT" "FAIL: D10-generic — generic manifest malformed or partial ($SB_GLOBAL_TOOLSTACK_MANIFEST) — schema must be"
printf 'not json\n' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
run -- "$HD_PROJ"
assert_contains "unreadable manifest" "$TL_OUT" "FAIL: D10-generic — generic manifest malformed or partial"

# --fix repairs the manifest through the runtime CLI, then the re-run sees a valid one
run SB_DOCTOR_ASSUME_YES=1 -- --fix=host "$HD_PROJ"
assert_contains "repair output reaches stderr" "$TL_ERR" "}"
assert_contains "manifest valid after repair" "$TL_OUT" "PASS: D10-generic — generic manifest valid ($SB_GLOBAL_TOOLSTACK_MANIFEST)"
assert_eq "repaired manifest has the schema" "true" "$(jq -r '.schema | type == "string"' "$SB_GLOBAL_TOOLSTACK_MANIFEST")"
# local scope never touches the generic stack
printf 'not json\n' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
run -- --fix=local "$HD_PROJ"
assert_contains "local scope leaves a broken manifest alone" "$TL_OUT" "FAIL: D10-generic"
assert_eq "the broken manifest is untouched" "not json" "$(cat "$SB_GLOBAL_TOOLSTACK_MANIFEST")"

# stand-in runtime package: validation warnings, failing repair, unavailable runtime
hd_stage
printf 'x\n' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
run STUB_GENERIC=invalid -- "$HD_PROJ"
assert_contains "validation errors are listed" "$TL_OUT" "FAIL: D10-generic — generic manifest malformed or partial ($SB_GLOBAL_TOOLSTACK_MANIFEST) — broken"
run SB_DOCTOR_ASSUME_YES=1 STUB_RC_GENERIC=1 -- --fix=host "$HD_PROJ"
assert_contains "failed generic repair is reported" "$TL_OUT" "FAIL: D10-generic — generic repair failed: repair ran"
run SB_DOCTOR_ASSUME_YES=1 -- --fix=packages "$HD_PROJ"
assert_contains "repair is invoked with the manifest paths" "$(hd_logs)" "generic-repair repair --manifest $SB_GLOBAL_TOOLSTACK_MANIFEST --legacy-manifest $HOME/.silver-bullet/five-tool-stack/instances.json"
rm -f -- "${HD_ST:?}/scripts/lib/five_tool_runtime/runtime.py"
run -- "$HD_PROJ"
assert_contains "runtime package unavailable" "$TL_OUT" "FAIL: D10-generic — generic manifest malformed or partial ($SB_GLOBAL_TOOLSTACK_MANIFEST) — runtime validation unavailable"
unset SB_GLOBAL_TOOLSTACK_MANIFEST
hd_stage

# ---------- D10: verdict table ----------
R="$(recon "[$(comp graphify ready enabled full), $(comp agentmemory ready enabled none '["version_drift","other"]'), $(comp rtk disabled disabled), $(comp context_mode pending pending), $(comp leanctx unsupported n/a), $(comp alumnium suspended enabled), $(comp search_cli reload_required enabled pending), $(comp weird unknownstate enabled), $CROSS_OK]")"
run STUB_RECON_JSON="$R" -- "$HD_PROJ"
assert_eq "no failures keeps the audit green" "0" "$TL_STATUS"
assert_contains "ready component" "$TL_OUT" "PASS: D10-graphify — graphify ready (activation=full)"
assert_contains "ready with advisory evidence" "$TL_OUT" "WARN: D10-agentmemory — agentmemory ready with advisory (version_drift,other) (activation=none)"
assert_contains "disabled component" "$TL_OUT" "PASS: D10-rtk — rtk disabled (consent=disabled)"
assert_contains "pending component" "$TL_OUT" "PASS: D10-context_mode — context_mode pending (consent=pending)"
assert_contains "unsupported component" "$TL_OUT" "PASS: D10-leanctx — leanctx unsupported (consent=n/a)"
assert_contains "suspended component" "$TL_OUT" "WARN: D10-alumnium — alumnium suspended — retry /sb:init or /sb:update"
assert_contains "reload_required component" "$TL_OUT" "WARN: D10-search_cli — search_cli reload_required (activation=pending)"
assert_contains "unknown state" "$TL_OUT" "WARN: D10-weird — weird state=unknownstate"
assert_contains "routes with full activation" "$TL_OUT" "PASS: D10-routes — ten route owners + heartbeat OK"
R="$(recon "[$(comp rtk repairable enabled), $(comp graphify failed enabled), $(comp cross_tool ready enabled none)]")"
run STUB_RECON_JSON="$R" -- "$HD_PROJ"
assert_eq "repairable and failed components fail the audit" "1" "$TL_STATUS"
assert_contains "repairable component" "$TL_OUT" "FAIL: D10-rtk — rtk repairable — run /sb:doctor --fix"
assert_contains "failed component" "$TL_OUT" "FAIL: D10-graphify — graphify failed"
assert_contains "routes ready without full activation" "$TL_OUT" "PASS: D10-routes — cross_tool ready (activation=none)"
run STUB_RECON_JSON="$(recon "[$(comp cross_tool failed enabled partial)]")" -- "$HD_PROJ"
assert_contains "routes failing" "$TL_OUT" "FAIL: D10-routes — cross_tool failed (activation=partial) — run --fix=host"
run STUB_RECON_JSON="$(recon "[$(comp rtk ready enabled)]")" -- "$HD_PROJ"
assert_contains "cross_tool missing from the output" "$TL_OUT" "WARN: D10-routes — cross_tool component missing from reconciler output"
run STUB_RECON_JSON="$(recon "[$(comp cross_tool ready enabled none '["no_five_tool_consent"]')]")" -- "$HD_PROJ"
assert_contains "routes N/A without consent" "$TL_OUT" "PASS: D10-routes — cross_tool N/A until five-tool opt-in (no consent)"

# unknown keys warn and fail the run without poisoning the rest
run STUB_RECON_JSON="$(recon "[$CROSS_OK]" '["mystery","other"]')" -- "$HD_PROJ"
assert_eq "unknown keys exit 1" "1" "$TL_STATUS"
assert_contains "unknown keys warning" "$TL_OUT" "WARN: D10 — unknown_key (mystery,other); other components not FAIL-poisoned"
assert_contains "no FAIL for unknown keys" "$TL_OUT" "Silver Bullet doctor: "
assert_contains "overall still passes with zero FAIL checks" "$TL_OUT" "OVERALL: PASS"

# a component list jq cannot fully walk keeps what was read
run STUB_RECON_JSON='{"components":[{"component":"graphify","consent":"enabled","canonical_state":"ready","activation_status":"full","evidence":[]},5,{"component":"cross_tool","canonical_state":"ready","activation_status":"full"}]}' -- "$HD_PROJ"
assert_contains "partially walkable components: first component read" "$TL_OUT" "PASS: D10-graphify — graphify ready (activation=full)"
assert_contains "partially walkable components: routes" "$TL_OUT" "D10-routes"

# component names that smuggle line breaks into the one-line-per-component protocol
run STUB_RECON_JSON="$(jq -nc '{components:[{component:"\ngraphify",consent:"enabled",canonical_state:"ready",activation_status:"full",evidence:[]},{component:"\ncross_tool",consent:"enabled",canonical_state:"failed",activation_status:"none",evidence:[]},{component:"cross_tool",consent:"enabled",canonical_state:"ready",activation_status:"full",evidence:[]}],unknown_keys:[]}')" -- "$HD_PROJ"
assert_contains "blank protocol lines are skipped" "$TL_OUT" "PASS: D10-routes — ten route owners + heartbeat OK"
assert_not_contains "a smuggled cross_tool entry is not reported as a tool" "$TL_OUT" "D10-cross_tool"
# a payload whose unknown_keys cannot be read
run STUB_RECON_JSON='[]' -- "$HD_PROJ"
assert_contains "top-level array payload" "$TL_OUT" "WARN: D10-routes — cross_tool component missing from reconciler output"
assert_not_contains "no unknown_key warning for an unreadable list" "$TL_OUT" "unknown_key"
assert_contains "the audit still completes" "$TL_OUT" "OVERALL: PASS"

# ---------- D10: reconciler plumbing ----------
run STUB_RECON_JSON= -- "$HD_PROJ"
assert_contains "empty reconciler output" "$TL_OUT" "WARN: D10 — reconciler returned no JSON"
run STUB_RECON_JSON='not json' -- "$HD_PROJ"
assert_contains "malformed reconciler output" "$TL_OUT" "WARN: D10 — reconciler returned no JSON"
run STUB_RECON_RC=3 -- "$HD_PROJ"
assert_contains "non-zero reconciler status keeps its JSON" "$TL_OUT" "PASS: D10-graphify"
run STUB_RECON_ERR="reconciler says hello" -- "$HD_PROJ"
assert_contains "reconciler stderr is forwarded" "$TL_ERR" "reconciler says hello"
run SB_DOCTOR_RECONCILER="$TL_TMP/none.sh" -- "$HD_PROJ"
assert_contains "missing override reconciler" "$TL_OUT" "WARN: D10 — reconciler returned no JSON"
cat >"$TL_TMP/alt-reconciler.sh" <<'EOF'
#!/usr/bin/env bash
echo "alt $*" >>"$HD_LOG"
echo '{"components":[],"unknown_keys":[]}'
EOF
run SB_DOCTOR_RECONCILER="$TL_TMP/alt-reconciler.sh" -- "$HD_PROJ"
assert_contains "override reconciler is used" "$(hd_logs)" "alt --project-root $HD_PROJ --host claude --mode verify --scope all --format json"
assert_contains "no components: routes warning" "$TL_OUT" "WARN: D10-routes"
mv "$HD_ST/scripts/reconcile-recommended-tools.sh" "$HD_ST/scripts/reconcile-recommended-tools.off"
run -- "$HD_PROJ"
assert_contains "reconciler absent from the repo" "$TL_OUT" "PASS: D10 — reconciler unavailable; skipped"
mv "$HD_ST/scripts/reconcile-recommended-tools.off" "$HD_ST/scripts/reconcile-recommended-tools.sh"

# dry-run uses plan mode and skips hook smoke
run -- --dry-run "$HD_PROJ"
assert_contains "plan mode requested" "$(hd_logs)" "reconcile --project-root $HD_PROJ --host claude --mode plan --scope all --format json"
assert_contains "dry-run completion" "$TL_OUT" "PASS: D10 — dry-run plan complete (no writes)"
assert_contains "hook smoke skipped in dry-run" "$TL_OUT" "PASS: D11 — hook smoke skipped (dry-run)"
assert_not_contains "no hook ran in dry-run" "$(hd_logs)" "hook session-start"

# deep probes
tl_stub graphify-mcp 'echo "graphify-mcp $*" >>"$HD_LOG"; exit "${STUB_RC_MCP:-0}"'
run -- --deep "$HD_PROJ"
assert_contains "deep graphify handshake" "$TL_OUT" "PASS: D10-deep-graphify — graphify-mcp stdio handshake OK"
assert_contains "handshake arguments" "$(hd_logs)" "graphify-mcp --transport stdio"
run STUB_RC_MCP=1 -- --deep "$HD_PROJ"
assert_contains "deep graphify failure is only a warning" "$TL_OUT" "WARN: D10-deep-graphify — graphify-mcp stdio handshake failed"
assert_eq "deep failure keeps exit 0" "0" "$TL_STATUS"
run -- "$HD_PROJ"
assert_not_contains "no deep probe by default" "$TL_OUT" "D10-deep-graphify"
rm -f -- "${TL_BIN:?}/graphify-mcp"
NOMCP="$(hr_path_without graphify-mcp)"
hd_run "$C" PATH="$NOMCP" -- --deep "$HD_PROJ"
assert_not_contains "no deep probe without graphify-mcp" "$TL_OUT" "D10-deep-graphify"

# ---------- --fix: confirmation ----------
NEEDS="$(recon "[$(comp rtk repairable enabled), $CROSS_OK]")"
run STUB_RECON_JSON="$NEEDS" -- --fix "$HD_PROJ"
assert_eq "unconfirmed fix exits 1" "1" "$TL_STATUS"
assert_contains "confirmation instructions" "$TL_ERR" "sb-doctor: confirmation required for --fix=all (set SB_DOCTOR_ASSUME_YES=1)"
assert_contains "fix denied is recorded" "$TL_OUT" "FAIL: D10 — confirmation unobtainable; --fix not applied"
assert_not_contains "no apply without confirmation" "$(hd_logs)" "--mode apply"
run STUB_RECON_JSON= -- --fix=packages "$HD_PROJ"
assert_contains "an unreadable verdict needs confirmation" "$TL_ERR" "confirmation required for --fix=packages"
run STUB_RECON_JSON="$(recon "[$(comp rtk repairable disabled), $(comp rtk2 repairable enabled), $CROSS_OK]")" -- --fix "$HD_PROJ"
assert_not_contains "repairable but disabled or unmanaged: no confirmation" "$TL_ERR" "confirmation required"
run STUB_RECON_JSON="$NEEDS" -- --fix=local "$HD_PROJ"
assert_not_contains "local scope never asks" "$TL_ERR" "confirmation required"
run STUB_RECON_JSON="$NEEDS" -- --fix=host "$HD_PROJ"
assert_not_contains "host scope never asks" "$TL_ERR" "confirmation required"
run STUB_RECON_JSON="$NEEDS" SB_DOCTOR_ASSUME_YES=1 -- --fix "$HD_PROJ"
assert_not_contains "assume-yes skips the prompt" "$TL_ERR" "confirmation required"
assert_contains "apply announced" "$TL_ERR" "sb-doctor: --fix=all running reconciler doctor-fix apply"
assert_contains "apply request" "$(hd_logs)" "reconcile --project-root $HD_PROJ --host claude --mode apply --scope all --format json --entry-point doctor-fix"

# scope mapping for the apply call
for pair in "local:project" "host:host" "packages:packages" "all:all"; do
  run SB_DOCTOR_ASSUME_YES=1 -- "--fix=${pair%%:*}" "$HD_PROJ"
  assert_contains "fix=${pair%%:*} applies scope ${pair##*:}" "$(hd_logs)" "--mode apply --scope ${pair##*:} --format json --entry-point doctor-fix"
done

# apply outcomes
run SB_DOCTOR_ASSUME_YES=1 -- --fix "$HD_PROJ"
assert_contains "successful apply re-runs the audit" "$TL_OUT" "sb-doctor: re-running checks after --fix"
assert_eq "successful apply exits 0" "0" "$TL_STATUS"
assert_eq "the fix is applied once, the re-run only verifies" "1" "$(grep -c -- '--mode apply' "$HD_LOG")"
assert_eq "the generic repair also runs once" "1" "$(grep -c '^generic-repair' "$HD_LOG")"
assert_eq "the re-run verifies after the apply" "verify" "$(grep -- '--mode' "$HD_LOG" | tail -1 | sed 's/.*--mode \([a-z]*\).*/\1/')"
hd_run "$C" "$J" SB_DOCTOR_ASSUME_YES=1 -- --fix "$HD_PROJ"
assert_eq "the json summary reports the applied fix" "true" "$(jq -r '.fix_applied' <<<"$TL_OUT")"
run SB_DOCTOR_ASSUME_YES=1 STUB_RECON_RC=1 -- --fix "$HD_PROJ"
assert_contains "failed apply" "$TL_OUT" "FAIL: D10 — reconciler apply failed (receipt not success)"
assert_not_contains "no re-run after a failed apply" "$TL_OUT" "re-running checks"
run SB_DOCTOR_ASSUME_YES=1 STUB_RECON_JSON='{"ok":false,"components":[],"unknown_keys":[]}' -- --fix "$HD_PROJ"
assert_contains "apply reporting ok=false" "$TL_OUT" "FAIL: D10 — reconciler apply failed (receipt not success)"
run SB_DOCTOR_ASSUME_YES=1 STUB_RECON_JSON= -- --fix "$HD_PROJ"
assert_contains "apply with empty output" "$TL_OUT" "FAIL: D10 — reconciler apply returned empty or malformed JSON"
run SB_DOCTOR_ASSUME_YES=1 STUB_RECON_JSON='nope' -- --fix "$HD_PROJ"
assert_contains "apply with malformed output" "$TL_OUT" "FAIL: D10 — reconciler apply returned empty or malformed JSON"
run SB_DOCTOR_ASSUME_YES=1 SB_DOCTOR_RECONCILER="$TL_TMP/none.sh" -- --fix "$HD_PROJ"
assert_not_contains "no stub reconciler means no apply announcement" "$TL_ERR" "running reconciler doctor-fix apply"
run SB_DOCTOR_ASSUME_YES=1 -- --fix --dry-run "$HD_PROJ"
assert_not_contains "dry-run never applies" "$(hd_logs)" "--mode apply"

# ---------- --fix: interactive confirmation on a real terminal ----------
PTY="$TL_TMP/pty-run.py"
cat >"$PTY" <<'PY'
import os, pty, select, signal, sys, time

reply = sys.argv[1].encode().decode("unicode_escape").encode("latin-1")
argv = sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
buf = b""
sent = False
deadline = time.time() + 45
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 1)
    if r:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
        if not sent and b"[y/N]" in buf:
            os.write(fd, reply)
            sent = True
timed_out = False
# the terminal closes slightly before the process is reapable: poll briefly
grace = time.time() + 10
done, status = os.waitpid(pid, os.WNOHANG)
while done == 0 and time.time() < grace:
    time.sleep(0.05)
    done, status = os.waitpid(pid, os.WNOHANG)
if done == 0:
    # still running after the deadline (for example a second prompt): never hang CI
    timed_out = True
    os.kill(pid, signal.SIGKILL)
    _, status = os.waitpid(pid, 0)
sys.stdout.write(buf.decode("utf-8", "replace"))
if timed_out:
    sys.stdout.write("\nPTY-TIMEOUT\n")
sys.stdout.write("\nPTY-EXIT=%d\n" % os.waitstatus_to_exitcode(status))
PY
pty_doctor() {  # reply -> output with PTY-EXIT=
  local reply="$1"; shift
  : >"$HD_LOG"
  TL_OUT="$(env STUB_RECON_JSON="$NEEDS" SILVER_BULLET_RUNTIME=claude python3 "$PTY" "$reply" bash "$HD_ST/scripts/sb-doctor.sh" "$@" 2>&1)"
}
pty_doctor 'y\n' --fix "$HD_PROJ"
assert_not_contains "no terminal run hits the deadline" "$TL_OUT" "PTY-TIMEOUT"
assert_contains "terminal prompt shown" "$TL_OUT" "sb-doctor: apply --fix=all? [y/N]"
assert_contains "answering y applies the fix" "$(hd_logs)" "--mode apply --scope all"
assert_contains "answering y re-runs the audit" "$TL_OUT" "sb-doctor: re-running checks after --fix"
assert_eq "the apply was asked once" "1" "$(grep -c -- '--mode apply' "$HD_LOG")"
pty_doctor 'YES\n' --fix "$HD_PROJ"
assert_contains "answering YES applies the fix" "$(hd_logs)" "--mode apply"
pty_doctor 'n\n' --fix "$HD_PROJ"
assert_not_contains "answering n applies nothing" "$(hd_logs)" "--mode apply"
assert_contains "answering n is a denied fix" "$TL_OUT" "FAIL: D10 — confirmation unobtainable; --fix not applied"
assert_contains "answering n exits 1" "$TL_OUT" "PTY-EXIT=1"
pty_doctor '\n' --fix "$HD_PROJ"
assert_contains "an empty answer is a no" "$TL_OUT" "confirmation unobtainable"
pty_doctor '\x04' --fix "$HD_PROJ"
assert_contains "end of input is a no" "$TL_OUT" "confirmation unobtainable"
assert_not_contains "end of input applies nothing" "$(hd_logs)" "--mode apply"

tl_results
