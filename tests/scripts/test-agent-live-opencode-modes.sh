#!/usr/bin/env bash
# scripts/agent-opencode-delegate.sh delegation modes (default, multi-ai-worker-v1, multi-ai-pool-v1)
# with a scripted adapter, a staged model registry and a stub cohort script. Split from
# test-agent-live-opencode-delegate.sh to keep each file well under 30 s.
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
  tl_run timeout 60 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" "$@"
}

alh_script "0|ok-output"

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
tl_run timeout 60 env OPENCODE_MODEL=other bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "pool mode with a drifted model fails the MiMo pin" "2" "$TL_STATUS"
assert_contains "pool mode drifted model message" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5"
tl_run timeout 60 env COHORT_RC=4 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "a failing cohort propagates its status" "4" "$TL_STATUS"
mv "$SB/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py" "$TL_TMP/cohort.py.moved"
run_od --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "a missing cohort script fails" "1" "$TL_STATUS"
assert_contains "a missing cohort script message" "$TL_ERR" "missing OCG cohort script"
mv "$TL_TMP/cohort.py.moved" "$SB/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py"

# fault injection: a read-only SB_ORCHESTRATOR_PARENT makes the last export of the lightweight env step fail
BASHENV="$TL_TMP/readonly-delegate.env"
cat >"$BASHENV" <<'ENVEOF'
[[ -z "${ORIG_BASH_ENV:-}" ]] || source "$ORIG_BASH_ENV"
readonly SB_ORCHESTRATOR_PARENT=0
ENVEOF
alh_script "0|ok"
tl_run timeout 60 env ORIG_BASH_ENV="${BASH_ENV:-}" BASH_ENV="$BASHENV" bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --no-escalate
assert_eq "a failing lightweight env step fails the delegation" "1" "$TL_STATUS"
assert_contains "the failing export is visible" "$TL_ERR" "readonly variable"
assert_eq "a failing lightweight env step never reaches the adapter" "0" "$(alh_attempts)"
tl_run timeout 60 env ORIG_BASH_ENV="${BASH_ENV:-}" BASH_ENV="$BASHENV" bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --delegation-mode multi-ai-pool-v1 --cohort-request "$TL_TMP/cohort/request.json" --no-escalate
assert_eq "a failing lightweight env step fails the pool cohort" "1" "$TL_STATUS"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results
