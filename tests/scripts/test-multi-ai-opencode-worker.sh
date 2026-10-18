#!/usr/bin/env bash
# scripts/lib/multi-ai-opencode-worker.sh: registry lookup, pool/worker validation, env apply/assert.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# shellcheck source=../../scripts/lib/multi-ai-opencode-worker.sh
source "$TL_REPO_ROOT/scripts/lib/multi-ai-opencode-worker.sh"

SB="$TL_TMP/sb"
REG_DIR="$SB/skills/silver-multi-ai-task/reference"
mkdir -p "$REG_DIR"
cat >"$REG_DIR/model-family-registry-v1.json" <<'JSON'
{"aliases":{"ocg-alias":"real-model"},
 "ocg_lite_pool":["ocg-alias","ocg-plain"],
 "ocg_regular_pool":["ocg-reg"]}
JSON
EMPTY="$TL_TMP/sb-empty"
mkdir -p "$EMPTY/skills/silver-multi-ai-task/reference"
echo '{"ocg_lite_pool":[],"ocg_regular_pool":[]}' >"$EMPTY/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
NOREG="$TL_TMP/sb-none"; mkdir -p "$NOREG"

assert_eq "registry path" "/x/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" "$(agent_opencode_registry_path /x)"
assert_eq "registry path default root" "./skills/silver-multi-ai-task/reference/model-family-registry-v1.json" "$(agent_opencode_registry_path)"

# profile -> run model
assert_eq "alias resolves via registry" real-model "$(agent_opencode_profile_to_run_model ocg-alias "$SB")"
assert_eq "ocg- prefix stripped when no alias" plain "$(agent_opencode_profile_to_run_model ocg-plain "$SB")"
assert_eq "non-ocg passthrough" foo "$(agent_opencode_profile_to_run_model foo "$SB")"
assert_eq "no registry strips prefix" abc "$(agent_opencode_profile_to_run_model ocg-abc "$NOREG")"
assert_eq "default root arg" zzz "$(cd "$TL_TMP" && agent_opencode_profile_to_run_model zzz)"
NOJQ="$(tl_path_without jq)"
assert_eq "no jq falls back to prefix strip" alias "$(PATH="$NOJQ" agent_opencode_profile_to_run_model ocg-alias "$SB")"

# unparseable registry: alias lookup yields nothing, pool count falls back to 0
BAD="$TL_TMP/sb-bad"
mkdir -p "$BAD/skills/silver-multi-ai-task/reference"
echo 'not json' >"$BAD/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
assert_eq "invalid registry falls back to prefix strip" xyz "$(agent_opencode_profile_to_run_model ocg-xyz "$BAD")"
rc=0; err="$(agent_opencode_validate_multi_ai_pool_mode lite "$BAD" 2>&1)" || rc=$?
assert_eq "invalid registry pool rc" 2 "$rc"; assert_contains "invalid registry pool msg" "$err" "empty OCG pool lite"

# validate pool
rc=0; agent_opencode_validate_multi_ai_pool_mode lite "$SB" || rc=$?
assert_eq "lite pool valid" 0 "$rc"
rc=0; agent_opencode_validate_multi_ai_pool_mode regular "$SB" || rc=$?
assert_eq "regular pool valid" 0 "$rc"
rc=0; agent_opencode_validate_multi_ai_pool_mode "" "$SB" || rc=$?
assert_eq "empty arg defaults to lite" 0 "$rc"
rc=0; err="$(agent_opencode_validate_multi_ai_pool_mode huge "$SB" 2>&1)" || rc=$?
assert_eq "bad pool rc" 2 "$rc"; assert_contains "bad pool msg" "$err" "pool must be lite or regular (got huge)"
rc=0; err="$(agent_opencode_validate_multi_ai_pool_mode lite "$NOREG" 2>&1)" || rc=$?
assert_eq "missing registry rc" 2 "$rc"; assert_contains "missing registry msg" "$err" "missing model family registry"
rc=0; err="$(PATH="$NOJQ" agent_opencode_validate_multi_ai_pool_mode lite "$SB" 2>&1)" || rc=$?
assert_eq "pool no jq rc" 2 "$rc"; assert_contains "pool no jq msg" "$err" "jq required for multi-ai-pool-v1"
rc=0; err="$(agent_opencode_validate_multi_ai_pool_mode regular "$EMPTY" 2>&1)" || rc=$?
assert_eq "empty pool rc" 2 "$rc"; assert_contains "empty pool msg" "$err" "empty OCG pool regular"

# validate worker
rc=0; agent_opencode_validate_multi_ai_worker_mode ocg-alias lite "$SB" || rc=$?
assert_eq "lite worker valid" 0 "$rc"
rc=0; agent_opencode_validate_multi_ai_worker_mode ocg-reg regular "$SB" || rc=$?
assert_eq "regular worker valid" 0 "$rc"
rc=0; err="$(agent_opencode_validate_multi_ai_worker_mode ocg-reg lite "$SB" 2>&1)" || rc=$?
assert_eq "not allowlisted rc" 2 "$rc"; assert_contains "not allowlisted msg" "$err" "profile ocg-reg not allowlisted for pool lite"
rc=0; err="$(agent_opencode_validate_multi_ai_worker_mode ocg-alias bogus "$SB" 2>&1)" || rc=$?
assert_eq "worker bad pool rc" 2 "$rc"; assert_contains "worker bad pool msg" "$err" "pool must be lite or regular"
rc=0; err="$(agent_opencode_validate_multi_ai_worker_mode ocg-alias lite "$NOREG" 2>&1)" || rc=$?
assert_eq "worker missing registry rc" 2 "$rc"; assert_contains "worker missing registry msg" "$err" "missing model family registry"
rc=0; err="$(PATH="$NOJQ" agent_opencode_validate_multi_ai_worker_mode ocg-alias lite "$SB" 2>&1)" || rc=$?
assert_eq "worker no jq rc" 2 "$rc"; assert_contains "worker no jq msg" "$err" "jq required for multi-ai-worker-v1"
rc=0; agent_opencode_validate_multi_ai_worker_mode ocg-alias "" "$SB" || rc=$?
assert_eq "worker empty pool defaults to lite" 0 "$rc"

# apply env
rc=0; agent_opencode_apply_multi_ai_worker_env ocg-alias lite "$SB" || rc=$?
assert_eq "apply ok" 0 "$rc"
assert_eq "mode exported" multi-ai-worker-v1 "$SB_AGENT_OPENCODE_DELEGATION_MODE"
assert_eq "profile exported" ocg-alias "$SB_MULTI_AI_OCG_PROFILE"
assert_eq "pool exported" lite "$SB_MULTI_AI_OCG_POOL"
assert_eq "validated exported" 1 "$SB_MULTI_AI_OCG_VALIDATED"
assert_eq "model exported" real-model "$OPENCODE_MODEL"
assert_eq "provider exported" opencode-go "$OPENCODE_MODEL_PROVIDER"
assert_eq "run model exported" opencode-go/real-model "$OPENCODE_RUN_MODEL"

# assert env (valid)
rc=0; agent_opencode_assert_validated_multi_ai_env "$SB" || rc=$?
assert_eq "assert valid env" 0 "$rc"

# forged / incomplete env cases
chk() { # name expected-substr  (env assignments via subshell body in $3)
  local rc=0 out
  out="$(eval "$3" 2>&1)" || rc=$?
  assert_eq "$1 rc" 2 "$rc"
  assert_contains "$1 msg" "$out" "$2"
}
chk "forged: wrong mode" "incomplete or forged" 'SB_AGENT_OPENCODE_DELEGATION_MODE=x agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "forged: not validated" "incomplete or forged" 'SB_MULTI_AI_OCG_VALIDATED=0 agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "forged: no profile" "incomplete or forged" 'SB_MULTI_AI_OCG_PROFILE= agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "profile not allowlisted" "not allowlisted" 'SB_MULTI_AI_OCG_PROFILE=ocg-reg agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "model mismatch" "OPENCODE_MODEL must match validated multi-ai profile ocg-alias (expected run model real-model)" 'OPENCODE_MODEL=other agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "run model mismatch" "OPENCODE_MODEL must match" 'OPENCODE_RUN_MODEL=bad agent_opencode_assert_validated_multi_ai_env "$SB"'
chk "provider mismatch" "OPENCODE_MODEL_PROVIDER must be opencode-go (got other)" 'OPENCODE_MODEL_PROVIDER=other agent_opencode_assert_validated_multi_ai_env "$SB"'
# unset pool defaults to lite
rc=0; (unset SB_MULTI_AI_OCG_POOL; agent_opencode_assert_validated_multi_ai_env "$SB") || rc=$?
assert_eq "pool defaults to lite" 0 "$rc"
# default root arg (no registry in cwd)
rc=0; (cd "$TL_TMP" && agent_opencode_assert_validated_multi_ai_env) 2>/dev/null || rc=$?
assert_eq "default sb_root without registry fails" 2 "$rc"

# apply propagates validation failure and does not export
rc=0; (agent_opencode_apply_multi_ai_worker_env ocg-reg lite "$SB") 2>/dev/null || rc=$?
assert_eq "apply rejects non-allowlisted" 2 "$rc"
rc=0; (unset OPENCODE_MODEL SB_MULTI_AI_OCG_PROFILE; agent_opencode_apply_multi_ai_worker_env ocg-reg lite "$SB" 2>/dev/null || true; echo "${OPENCODE_MODEL:-unset}") >"$TL_TMP/o" || rc=$?
assert_eq "apply failure leaves env untouched" unset "$(cat "$TL_TMP/o")"

tl_results
