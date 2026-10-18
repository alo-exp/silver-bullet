#!/usr/bin/env bash
# scripts/agent-opencode-delegate.sh with a scripted adapter (staged SB root), a staged model
# registry and a stub cohort script. No OpenCode CLI, network or real model is ever used.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/agent-live-helpers.sh"
tl_init

DELEGATE="$TL_REPO_ROOT/scripts/agent-opencode-delegate.sh"
SB="$TL_TMP/sb"
W="$TL_TMP/work"
mkdir -p "$W" "$TL_TMP/tmp" "$TL_TMP/ocbin"
alh_stage_sb "$SB" opencode

export ALH_RECORD="$TL_TMP/record"
export ALH_COUNT="$TL_TMP/count"
export ALH_SCRIPT="$TL_TMP/script"
export ALH_ENV_KEYS="OPENCODE_BIN OPENCODE_WORK_DIR SB_LIVE_OPENCODE_USE_INTERACTIVE OPENCODE_MODEL OPENCODE_MODEL_PROVIDER OPENCODE_RUN_MODEL SB_AGENT_OPENCODE_DELEGATION_MODE SB_MULTI_AI_OCG_PROFILE SB_MULTI_AI_OCG_POOL SB_MULTI_AI_OCG_VALIDATED SB_AGENT_OPENCODE_DELEGATE SB_ORCHESTRATOR_WORKER RTK_DISABLED OPENCODE_RUN_TIMEOUT SB_ROOT WORK_DIR CLAUDE_INTERACTIVE_LOG_FILE"

for cli in claude expect codex pi; do
  tl_stub "$cli" "printf '%s %s\n' $cli \"\$*\" >>'$TL_TMP/unexpected-cli.log'; exit 99"
done
tl_stub sleep "printf '%s\n' \"\$*\" >>'$TL_TMP/sleep.log'; exit 0"

# the CLI the delegate resolves: a recording stub named opencode (resolution requires the name)
OC="$TL_TMP/ocbin/opencode"
printf '#!/usr/bin/env bash\nprintf "cwd=%%s\\n" "$PWD"; printf "argv:%%s\\n" "$@"; exit 7\n' >"$OC"
chmod +x "$OC"

# staged registry + cohort script
mkdir -p "$SB/skills/silver-multi-ai-task/reference" "$SB/skills/silver-multi-ai-task/scripts"
cat >"$SB/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" <<'EOF'
{"aliases":{"ocg-x":"x-model"},"ocg_lite_pool":["ocg-x","ocg-plain"],"ocg_regular_pool":["ocg-y"]}
EOF
cat >"$SB/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py" <<EOF
import sys, os
with open("$TL_TMP/cohort-args", "w") as fh:
    fh.write(" ".join(sys.argv[1:]) + "|" + os.getcwd() + "\n")
print("cohort-done")
sys.exit(int(os.environ.get("COHORT_RC", "0")))
EOF

export TL_TMP
export TMPDIR="$TL_TMP/tmp"
export OPENCODE_BIN="$OC"
export SB_AGENT_MODE_TUI_AVAILABLE=0
unset SB_AGENT_SKIP_PREFLIGHT OPENCODE_MODEL OPENCODE_MODEL_PROVIDER OPENCODE_RUN_MODEL

run_od() {
  tl_run bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" "$@"
}

alh_script "0|ok-output"

# ---------------------------------------------------------------- argument handling
tl_run bash "$DELEGATE" --help
assert_eq "opencode delegate --help exits 0" "0" "$TL_STATUS"
assert_contains "opencode delegate --help usage" "$TL_OUT" "Usage: agent-opencode-delegate.sh --work-dir PATH"
tl_run bash "$DELEGATE" --bogus
assert_eq "opencode delegate unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "opencode delegate unknown arg named" "$TL_ERR" "unknown argument: --bogus"

for flag in --work-dir --prompt --prompt-file --brief-file --log --mode --sb-root --control-dir --max-turns --max-wall-sec --idle-sec --task-id --delegation-mode --multi-ai-profile --multi-ai-pool --cohort-request --cohort-output; do
  tl_run bash "$DELEGATE" "$flag"
  assert_eq "opencode delegate $flag without value exits 2" "2" "$TL_STATUS"
  assert_contains "opencode delegate $flag without value message" "$TL_ERR" "$flag requires a value"
done

tl_run bash "$DELEGATE" --prompt hi
assert_eq "opencode delegate without --work-dir exits 2" "2" "$TL_STATUS"
assert_contains "opencode delegate without --work-dir message" "$TL_ERR" "--work-dir must point to an existing directory"
run_od --mode bogus --prompt hi
assert_eq "opencode delegate invalid --mode exits 2" "2" "$TL_STATUS"
run_od
assert_eq "opencode delegate without a prompt exits 2" "2" "$TL_STATUS"
run_od --prompt 'password: hunter2'
assert_eq "opencode delegate refuses a prompt with secrets" "2" "$TL_STATUS"
run_od --interactive --non-interactive --prompt hi
assert_eq "opencode delegate opposite aliases exit 2" "2" "$TL_STATUS"
assert_eq "no adapter ran for rejected invocations" "0" "$(alh_attempts)"

mkdir -p "$TL_TMP/rel/out"
printf 'brief text\n' >"$TL_TMP/rel/brief.txt"
printf 'prompt text\n' >"$TL_TMP/rel/prompt.txt"
alh_script "0|rel-ok"
pushd "$TL_TMP/rel" >/dev/null
tl_run env SB_AGENT_OPENCODE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir ../work --brief-file brief.txt --log out/run.log
popd >/dev/null
assert_eq "relative brief/log/work-dir run exits 0" "0" "$TL_STATUS"
assert_contains "brief content became the prompt" "$(alh_rec)" "prompt=brief text"
assert_eq "relative work dir is made absolute" "$W" "$(alh_env OPENCODE_WORK_DIR)"
assert_file_exists "relative --log landed under the cwd" "$TL_TMP/rel/out/run.log"
alh_script "0|rel-ok"
pushd "$TL_TMP/rel" >/dev/null
run_od --prompt-file prompt.txt
popd >/dev/null
assert_contains "prompt file content became the prompt" "$(alh_rec)" "prompt=prompt text"

# ---------------------------------------------------------------- pinned NI exec
alh_script "0|unused"
tl_run bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --non-interactive --prompt "pinned prompt"
assert_eq "pinned NI propagates the exec'd CLI status" "7" "$TL_STATUS"
assert_contains "pinned NI runs in the work dir" "$TL_OUT" "cwd=$W"
assert_contains "pinned NI runs opencode run" "$TL_OUT" "argv:run"
assert_contains "pinned NI pins the model" "$TL_OUT" "argv:opencode-go/mimo-v2.5"
assert_contains "pinned NI passes the prompt" "$TL_OUT" "argv:pinned prompt"
assert_eq "pinned NI never reached the adapter" "0" "$(alh_attempts)"
tl_run env OPENCODE_BIN="$TL_TMP/no-such-opencode" bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --non-interactive --prompt p
assert_eq "pinned NI without a CLI exits 3" "3" "$TL_STATUS"
assert_contains "pinned NI without a CLI message" "$TL_ERR" "mode-unavailable"

# ---------------------------------------------------------------- default delegation (MiMo pin)
alh_script "0|ok-output"
run_od --prompt "do the thing"
assert_eq "default delegation exits 0" "0" "$TL_STATUS"
assert_eq "default delegation prints the adapter output" "ok-output" "$TL_OUT"
assert_contains "adapter got mode and prompt" "$(alh_rec)" "invoke n=1 mode=permissive prompt=do the thing"
assert_eq "model pinned to mimo-v2.5" "mimo-v2.5" "$(alh_env OPENCODE_MODEL)"
assert_eq "provider pinned to opencode-go" "opencode-go" "$(alh_env OPENCODE_MODEL_PROVIDER)"
assert_eq "run model pinned" "opencode-go/mimo-v2.5" "$(alh_env OPENCODE_RUN_MODEL)"
assert_eq "NI delegation is not interactive" "0" "$(alh_env SB_LIVE_OPENCODE_USE_INTERACTIVE)"
assert_eq "OPENCODE_BIN reaches the adapter" "$OC" "$(alh_env OPENCODE_BIN)"
assert_eq "SB_ROOT reaches the adapter" "$SB" "$(alh_env SB_ROOT)"
assert_eq "delegate flag exported" "1" "$(alh_env SB_AGENT_OPENCODE_DELEGATE)"
assert_eq "worker flag exported" "1" "$(alh_env SB_ORCHESTRATOR_WORKER)"
assert_eq "run timeout default" "900" "$(alh_env OPENCODE_RUN_TIMEOUT)"
assert_eq "no multi-ai delegation mode in the default path" "<unset>" "$(alh_env SB_AGENT_OPENCODE_DELEGATION_MODE)"

# lightweight off: delegate flag not forced
alh_script "0|ok"
tl_run env SB_AGENT_OPENCODE_LIGHTWEIGHT=0 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "lightweight off still runs" "0" "$TL_STATUS"
assert_eq "lightweight off does not force the delegate flag" "<unset>" "$(alh_env SB_AGENT_OPENCODE_DELEGATE)"

# a drifted model fails the delegation before the adapter runs
alh_script "0|ok"
tl_run env OPENCODE_MODEL=other bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --no-escalate
assert_eq "a drifted model fails the delegation" "2" "$TL_STATUS"
assert_contains "a drifted model is reported" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5"
assert_eq "a drifted model never reaches the adapter" "0" "$(alh_attempts)"

# ---------------------------------------------------------------- interactive
alh_script "0|interactive-ok"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --interactive
assert_eq "interactive pin with a TUI exits 0" "0" "$TL_STATUS"
assert_eq "interactive run selects the TUI" "1" "$(alh_env SB_LIVE_OPENCODE_USE_INTERACTIVE)"
tl_run bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --interactive
assert_eq "interactive pin without a TUI exits 3" "3" "$TL_STATUS"
assert_contains "interactive pin without a TUI says mode-unavailable" "$TL_ERR" "mode-unavailable"

# ---------------------------------------------------------------- delegation modes
run_od --prompt p --delegation-mode bogus
assert_eq "an invalid --delegation-mode exits 2" "2" "$TL_STATUS"
assert_contains "an invalid --delegation-mode message" "$TL_ERR" "invalid --delegation-mode bogus"

alh_script "0|ok"
run_od --prompt p --multi-ai-profile ocg-x --no-escalate
assert_eq "--multi-ai-profile without worker mode fails" "2" "$TL_STATUS"
assert_contains "--multi-ai-profile without worker mode message" "$TL_ERR" "--multi-ai-profile requires --delegation-mode multi-ai-worker-v1"
assert_eq "--multi-ai-profile without worker mode never reaches the adapter" "0" "$(alh_attempts)"

run_od --prompt p --delegation-mode multi-ai-worker-v1 --no-escalate
assert_eq "worker mode without a profile fails" "2" "$TL_STATUS"
assert_contains "worker mode without a profile message" "$TL_ERR" "--multi-ai-profile required for multi-ai-worker-v1"

alh_script "0|worker-ok"
run_od --prompt p --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-x
assert_eq "worker mode with an allowlisted profile exits 0" "0" "$TL_STATUS"
assert_eq "worker mode delegation mode reaches the adapter" "multi-ai-worker-v1" "$(alh_env SB_AGENT_OPENCODE_DELEGATION_MODE)"
assert_eq "worker mode profile reaches the adapter" "ocg-x" "$(alh_env SB_MULTI_AI_OCG_PROFILE)"
assert_eq "worker mode pool defaults to lite" "lite" "$(alh_env SB_MULTI_AI_OCG_POOL)"
assert_eq "worker mode run model comes from the registry alias" "opencode-go/x-model" "$(alh_env OPENCODE_RUN_MODEL)"
assert_eq "worker mode marks the env validated" "1" "$(alh_env SB_MULTI_AI_OCG_VALIDATED)"

alh_script "0|worker-ok"
run_od --prompt p --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-plain
assert_eq "an unaliased ocg- profile strips its prefix" "opencode-go/plain" "$(alh_env OPENCODE_RUN_MODEL)"

run_od --prompt p --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-nope --no-escalate
assert_eq "a non-allowlisted profile fails" "2" "$TL_STATUS"
assert_contains "a non-allowlisted profile message" "$TL_ERR" "profile ocg-nope not allowlisted for pool lite"
alh_script "0|worker-ok"
run_od --prompt p --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-y --multi-ai-pool regular
assert_eq "the regular pool allows its own profiles" "0" "$TL_STATUS"
run_od --prompt p --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-y --multi-ai-pool huge --no-escalate
assert_eq "an unknown pool fails" "2" "$TL_STATUS"
assert_contains "an unknown pool message" "$TL_ERR" "multi-ai pool must be lite or regular"

# ---------------------------------------------------------------- pool cohort
run_od --delegation-mode multi-ai-pool-v1
assert_eq "pool mode without --cohort-request exits 2" "2" "$TL_STATUS"
assert_contains "pool mode without --cohort-request message" "$TL_ERR" "--cohort-request required for multi-ai-pool-v1"

mkdir -p "$TL_TMP/cohort"
printf '{}\n' >"$TL_TMP/cohort/request.json"
rm -f "$TL_TMP/cohort-args"
pushd "$TL_TMP/cohort" >/dev/null
run_od --delegation-mode multi-ai-pool-v1 --cohort-request request.json --cohort-output out.json --multi-ai-pool regular
popd >/dev/null
assert_eq "pool cohort run exits 0" "0" "$TL_STATUS"
assert_eq "pool cohort prints the cohort output" "cohort-done" "$TL_OUT"
assert_eq "cohort script got canonical request/output paths and ran in the work dir" \
  "--request $TL_TMP/cohort/request.json --output $TL_TMP/cohort/out.json|$W" "$(cat "$TL_TMP/cohort-args")"
assert_contains "pool cohort announces its start" "$TL_ERR" '"type":"ocg.pool.cohort.start","pool":"regular"'
rm -f "$TL_TMP/cohort-args"
run_od --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json"
assert_eq "pool cohort without output exits 0" "0" "$TL_STATUS"
assert_eq "cohort script gets only --request when no output is given" "--request $TL_TMP/cohort/request.json|$W" "$(cat "$TL_TMP/cohort-args")"

run_od --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --multi-ai-pool huge --no-escalate
assert_eq "pool mode with an unknown pool fails" "2" "$TL_STATUS"
run_od --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --multi-ai-profile ocg-x --no-escalate
assert_eq "pool mode ignores a profile and still runs" "0" "$TL_STATUS"
tl_run env COHORT_RC=4 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "a failing cohort propagates its status" "4" "$TL_STATUS"
mv "$SB/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py" "$TL_TMP/cohort.py.moved"
run_od --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "a missing cohort script fails" "1" "$TL_STATUS"
assert_contains "a missing cohort script message" "$TL_ERR" "missing OCG cohort script"
mv "$TL_TMP/cohort.py.moved" "$SB/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py"

# ---------------------------------------------------------------- recommended-tools preflight
alh_script "0|ok"
tl_run bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "preflight without the enterprise lib warns and continues" "0" "$TL_STATUS"
assert_contains "preflight warns about the missing enterprise lib" "$TL_ERR" "missing enterprise preflight lib"
mkdir -p "$SB/scripts/enterprise-e2e/lib"
printf 'enterprise_e2e_code_intel_preflight() { return 1; }\n' >"$SB/scripts/enterprise-e2e/lib/core.sh"
alh_script "0|ok"
tl_run bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "preflight failure exits 2" "2" "$TL_STATUS"
assert_contains "preflight failure message" "$TL_ERR" "recommended-tools preflight failed"
assert_eq "preflight failure never reaches the adapter" "0" "$(alh_attempts)"
rm -rf "$SB/scripts"

# ---------------------------------------------------------------- missing adapter / CLI
MISSING_SB="$TL_TMP/sb-missing"
mkdir -p "$MISSING_SB"
tl_run bash "$DELEGATE" --sb-root "$MISSING_SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "missing adapter exits 1" "1" "$TL_STATUS"
assert_contains "missing adapter message" "$TL_ERR" "missing OpenCode live adapter at $MISSING_SB/tests/live/agents/opencode/agent.sh"
NOOC_PATH="$(tl_path_without opencode)"
tl_run env PATH="$NOOC_PATH" OPENCODE_BIN= bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "missing OpenCode CLI exits 1" "1" "$TL_STATUS"
assert_contains "missing OpenCode CLI message" "$TL_ERR" "native OpenCode CLI not found"

# ---------------------------------------------------------------- quota retry loop
rm -f "$TL_TMP/sleep.log"
alh_script "1|HTTP 429 rate limit hit"
tl_run env AGENT_OPENCODE_QUOTA_RETRY_MAX=2 AGENT_OPENCODE_QUOTA_RETRY_INTERVAL=3 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --no-escalate
assert_eq "exhausted quota retries exit 1" "1" "$TL_STATUS"
assert_eq "a retriable quota error is attempted max+1 times" "3" "$(alh_attempts)"
assert_contains "retry progress is reported" "$TL_ERR" "[agent-opencode] quota retry 2/3 after 3s"
assert_contains "exhaustion is reported" "$TL_ERR" "[agent-opencode] quota retries exhausted"
assert_eq "the retry interval was slept between attempts" "3 3" "$(tr '\n' ' ' <"$TL_TMP/sleep.log" | sed 's/ $//')"
alh_script "1|HTTP 429 rate limit hit" "0|recovered"
tl_run env AGENT_OPENCODE_QUOTA_RETRY_MAX=2 AGENT_OPENCODE_QUOTA_RETRY_INTERVAL=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "recovery after a quota error exits 0" "0" "$TL_STATUS"
assert_eq "recovery output" "recovered" "$TL_OUT"
rm -f "$TL_TMP/sleep.log"
alh_script "1|Claude 5-hour quota has been exhausted. Resets in 2hr 32min"
run_od --prompt p --no-escalate
assert_eq "a 5-hour quota window exits 1" "1" "$TL_STATUS"
assert_eq "a 5-hour quota window is not retried" "1" "$(alh_attempts)"
assert_contains "5-hour quota window is left to the RFL schedule" "$TL_ERR" "skip short retry (RFL schedule)"
alh_script "1|plain failure"
run_od --prompt p --no-escalate
assert_eq "a non-quota failure is not retried" "1" "$(alh_attempts)"
alh_script "5|exit five"
run_od --prompt p --no-escalate
assert_eq "the adapter's exit status is propagated" "5" "$TL_STATUS"

# ---------------------------------------------------------------- logging
LOG="$TL_TMP/logs/run.log"
mkdir -p "$TL_TMP/logs"
big="$(head -c 700 /dev/zero | tr '\0' 'y')"
rm -f "$LOG"
alh_script "0|${big} token=abc123 done"
run_od --prompt p --log "$LOG"
assert_eq "run with a log exits 0" "0" "$TL_STATUS"
log_text="$(cat "$LOG")"
assert_contains "log header names the delegate and default model" "$log_text" "=== agent-opencode-delegate"
assert_contains "log header records the model and mode" "$log_text" "model=opencode-go/mimo-v2.5 mode=default"
assert_contains "log has the adapter output" "$log_text" "$big"
assert_contains "secrets are redacted in the log" "$log_text" "token=[REDACTED]"
assert_not_contains "the raw secret is gone from the log" "$log_text" "abc123"
assert_contains "log has the workdir evidence" "$log_text" "=== workdir evidence ==="
assert_contains "log has the footer" "$log_text" "=== agent-opencode-delegate complete exit=0 attempt=1 ==="
rm -f "$LOG"
alh_script "0|${big}"
run_od --prompt p --log "$LOG" --delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-x
assert_contains "worker mode log header names the profile" "$(cat "$LOG")" "model=opencode-go/ocg-x mode=multi-ai-worker-v1"

rm -f "$LOG"
alh_script "0|tiny"
tl_run env SB_AGENT_OPENCODE_LOG_FLOOR=100000 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --no-escalate
assert_eq "a log below the floor forces exit 1" "1" "$TL_STATUS"
assert_contains "log floor failure is explained" "$TL_ERR" "log below floor"
rm -f "$LOG"
alh_script "0|tiny"
tl_run env SB_AGENT_OPENCODE_LOG_FLOOR=10 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "SB_AGENT_OPENCODE_LOG_FLOOR lowers the floor" "0" "$TL_STATUS"

# the adapter removing its log: header + evidence recreate it, so the log still exists
rm -f "$LOG"
alh_script "0|${big}"
tl_run env ALH_RM_LOG=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "a log removed by the adapter is rebuilt" "0" "$TL_STATUS"
assert_file_exists "the rebuilt log exists" "$LOG"

# ---------------------------------------------------------------- failure -> result normalisation -> D4 escalation
alh_script "1|first wave failed" "0|escalated wave ok"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-1
assert_eq "an escalated retry that succeeds exits 0" "0" "$TL_STATUS"
assert_eq "the escalated retry output is final" "escalated wave ok" "$TL_OUT"
assert_eq "the escalated retry ran the adapter twice" "2" "$(alh_attempts)"
assert_eq "the escalated retry is interactive" "1" "$(alh_env SB_LIVE_OPENCODE_USE_INTERACTIVE)"
TD="$W/.planning/agent-opencode/esc-1"
assert_file_exists "failure left an escalation note" "$TD/escalation.md"
assert_contains "a missing result.md is normalised to a failing skeleton" "$(cat "$TD/result.md")" "incomplete / result-missing"
alh_script "1|first wave failed" "0|should not run"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-2 --no-escalate
assert_eq "--no-escalate keeps the failure" "1" "$TL_STATUS"
assert_eq "--no-escalate runs the adapter once" "1" "$(alh_attempts)"
alh_script "1|first wave failed" "0|should not run"
run_od --prompt p --task-id esc-3
assert_eq "an unavailable escalation keeps the failure" "1" "$TL_STATUS"
assert_contains "the unavailable escalation is recorded" "$(cat "$W/.planning/agent-opencode/esc-3/mode.json")" "escalate-unavailable"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results
