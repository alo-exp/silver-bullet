#!/usr/bin/env bash
# scripts/lib/opencode-cli.sh and scripts/lib/pi-cli.sh: CLI resolution, model pinning
# and the multi-ai invoke-model policy. All CLIs are stubs in a sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# Run a snippet in a fresh bash that sources the lib; prints "rc=N" after the output.
run_lib() {
  local lib="$1" snippet="$2"
  tl_run bash -c "source '$lib'; $snippet"
}
OC="$TL_REPO_ROOT/scripts/lib/opencode-cli.sh"
PI="$TL_REPO_ROOT/scripts/lib/pi-cli.sh"

mkdir -p "$TL_TMP/fake" "$TL_TMP/other"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/fake/opencode"; chmod +x "$TL_TMP/fake/opencode"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/fake/pi"; chmod +x "$TL_TMP/fake/pi"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/other/notopencode"; chmod +x "$TL_TMP/other/notopencode"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/other/notpi"; chmod +x "$TL_TMP/other/notpi"

# ---------------- pi-cli ----------------
# requested absolute path with basename pi
run_lib "$PI" "resolve_native_pi_cli_path '$TL_TMP/fake/pi'"
assert_eq "pi: requested abs path" "$TL_TMP/fake/pi" "$TL_OUT"
# requested via PI_BIN env
tl_run env PI_BIN="$TL_TMP/fake/pi" bash -c "source '$PI'; resolve_native_pi_cli_path"
assert_eq "pi: PI_BIN env" "$TL_OUT" "$TL_TMP/fake/pi"
# requested name resolved through PATH
tl_run env PATH="$TL_TMP/fake:$PATH" bash -c "source '$PI'; resolve_native_pi_cli_path pi"
assert_eq "pi: requested name via PATH" "$TL_TMP/fake/pi" "$TL_OUT"
# requested file with wrong basename is rejected, falls through to ~/.local/bin/pi
mkdir -p "$HOME/.local/bin"
cp "$TL_TMP/fake/pi" "$HOME/.local/bin/pi"
run_lib "$PI" "resolve_native_pi_cli_path '$TL_TMP/other/notpi'"
assert_eq "pi: wrong basename falls back to ~/.local/bin" "$HOME/.local/bin/pi" "$TL_OUT"
rm -f "$HOME/.local/bin/pi"
# fallback to pi on PATH
tl_run env PATH="$TL_TMP/fake:$PATH" bash -c "source '$PI'; resolve_native_pi_cli_path"
assert_eq "pi: PATH fallback" "$TL_TMP/fake/pi" "$TL_OUT"
# nothing available
NOPI="$(tl_path_without pi)"
tl_run env PATH="$NOPI" bash -c "source '$PI'; resolve_native_pi_cli_path '$TL_TMP/other/notpi'; echo rc=\$?"
assert_contains "pi: not found returns 1" "$TL_OUT" "rc=1"

# pin: defaults
run_lib "$PI" "agent_pi_pin_mimo_model_env; echo \"rc=\$? \$PI_PROVIDER \$PI_MODEL\""
assert_eq "pi: pin defaults" "rc=0 opencode-go mimo-v2.5" "$TL_OUT"
tl_run env PI_PROVIDER=other bash -c "source '$PI'; agent_pi_pin_mimo_model_env; echo rc=\$?"
assert_contains "pi: provider drift rejected" "$TL_ERR" "PI_PROVIDER must be opencode-go (got other)"
assert_contains "pi: provider drift rc 2" "$TL_OUT" "rc=2"
tl_run env PI_MODEL=gpt bash -c "source '$PI'; agent_pi_pin_mimo_model_env; echo rc=\$?"
assert_contains "pi: model drift rejected" "$TL_ERR" "PI_MODEL must be mimo-v2.5 (got gpt)"
assert_contains "pi: model drift rc 2" "$TL_OUT" "rc=2"

# ---------------- opencode-cli ----------------
run_lib "$OC" "resolve_native_opencode_cli_path '$TL_TMP/fake/opencode'"
assert_eq "oc: requested abs path" "$TL_TMP/fake/opencode" "$TL_OUT"
tl_run env OPENCODE_BIN="$TL_TMP/fake/opencode" bash -c "source '$OC'; resolve_native_opencode_cli_path"
assert_eq "oc: OPENCODE_BIN env" "$TL_OUT" "$TL_TMP/fake/opencode"
tl_run env PATH="$TL_TMP/fake:$PATH" bash -c "source '$OC'; resolve_native_opencode_cli_path opencode"
assert_eq "oc: requested name via PATH" "$TL_TMP/fake/opencode" "$TL_OUT"
mkdir -p "$HOME/.opencode/bin"
cp "$TL_TMP/fake/opencode" "$HOME/.opencode/bin/opencode"
run_lib "$OC" "resolve_native_opencode_cli_path '$TL_TMP/other/notopencode'"
assert_eq "oc: wrong basename falls back to ~/.opencode/bin" "$HOME/.opencode/bin/opencode" "$TL_OUT"
rm -f "$HOME/.opencode/bin/opencode"
tl_run env PATH="$TL_TMP/fake:$PATH" bash -c "source '$OC'; resolve_native_opencode_cli_path"
assert_eq "oc: PATH fallback" "$TL_TMP/fake/opencode" "$TL_OUT"
NOOC="$(tl_path_without opencode)"
tl_run env PATH="$NOOC" bash -c "source '$OC'; resolve_native_opencode_cli_path '$TL_TMP/other/notopencode'; echo rc=\$?"
assert_contains "oc: not found returns 1" "$TL_OUT" "rc=1"

# pin
run_lib "$OC" "agent_opencode_pin_mimo_model_env; echo \"rc=\$? \$OPENCODE_MODEL \$OPENCODE_MODEL_PROVIDER \$OPENCODE_RUN_MODEL\""
assert_eq "oc: pin defaults" "rc=0 mimo-v2.5 opencode-go opencode-go/mimo-v2.5" "$TL_OUT"
tl_run env OPENCODE_MODEL=x bash -c "source '$OC'; agent_opencode_pin_mimo_model_env; echo rc=\$?"
assert_contains "oc: model drift" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5 (got x)"
assert_contains "oc: model drift rc" "$TL_OUT" "rc=2"
tl_run env OPENCODE_MODEL_PROVIDER=x bash -c "source '$OC'; agent_opencode_pin_mimo_model_env; echo rc=\$?"
assert_contains "oc: provider drift" "$TL_ERR" "OPENCODE_MODEL_PROVIDER must be opencode-go (got x)"
tl_run env OPENCODE_RUN_MODEL=x bash -c "source '$OC'; agent_opencode_pin_mimo_model_env; echo rc=\$?"
assert_contains "oc: run model drift" "$TL_ERR" "OPENCODE_RUN_MODEL must be opencode-go/mimo-v2.5 (got x)"

# worker policy missing next to the lib: warning, functions from the policy absent
mkdir -p "$TL_TMP/lonely"
cp "$OC" "$TL_TMP/lonely/opencode-cli.sh"
tl_run bash -c "source '$TL_TMP/lonely/opencode-cli.sh'; declare -F agent_opencode_validate_multi_ai_pool_mode >/dev/null && echo has || echo none"
assert_contains "oc: missing worker policy warns" "$TL_ERR" "multi-ai-opencode-worker.sh missing"
assert_eq "oc: missing worker policy defines nothing" "none" "$TL_OUT"

# ---------------- enforce_invoke_model_policy ----------------
# Registry fixture: one lite and one regular profile.
SB="$TL_TMP/sbroot"
mkdir -p "$SB/skills/silver-multi-ai-task/reference"
cat >"$SB/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" <<'JSON'
{"aliases":{"ocg-kimi":"kimi-k2"},"ocg_lite_pool":["ocg-kimi"],"ocg_regular_pool":["ocg-kimi"]}
JSON

enforce() { # <env assignments...> -- <args>
  local envs=() args=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift; args=("$@")
  tl_run env "${envs[@]}" bash -c "source '$OC'; agent_opencode_enforce_invoke_model_policy \"\$@\"; echo rc=\$?" _ "${args[@]}"
}

# pool mode validated -> pool validation against explicit root
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-pool-v1 SB_MULTI_AI_OCG_VALIDATED=1 SB_MULTI_AI_OCG_POOL=regular -- "$SB"
assert_contains "enforce: pool mode ok" "$TL_OUT" "rc=0"
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-pool-v1 SB_MULTI_AI_OCG_VALIDATED=1 SB_MULTI_AI_OCG_POOL=bogus -- "$SB"
assert_contains "enforce: pool mode bad pool" "$TL_ERR" "multi-ai pool must be lite or regular"
assert_contains "enforce: pool mode bad pool rc" "$TL_OUT" "rc=2"
# without an explicit root the repo root is derived from the lib location (real registry present)
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-pool-v1 SB_MULTI_AI_OCG_VALIDATED=1 --
assert_contains "enforce: default sb_root resolves repo registry" "$TL_OUT" "rc=0"

# worker-v1 with validated env and profile -> asserts the env is consistent
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1 SB_MULTI_AI_OCG_VALIDATED=1 SB_MULTI_AI_OCG_PROFILE=ocg-kimi SB_MULTI_AI_OCG_POOL=lite OPENCODE_MODEL=kimi-k2 OPENCODE_MODEL_PROVIDER=opencode-go OPENCODE_RUN_MODEL=opencode-go/kimi-k2 -- "$SB"
assert_contains "enforce: worker env consistent" "$TL_OUT" "rc=0"
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1 SB_MULTI_AI_OCG_VALIDATED=1 SB_MULTI_AI_OCG_PROFILE=ocg-kimi SB_MULTI_AI_OCG_POOL=lite OPENCODE_MODEL=kimi-k2 OPENCODE_MODEL_PROVIDER=other OPENCODE_RUN_MODEL=opencode-go/kimi-k2 -- "$SB"
assert_contains "enforce: worker provider drift rejected" "$TL_OUT" "rc=2"
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1 SB_MULTI_AI_OCG_VALIDATED=1 SB_MULTI_AI_OCG_PROFILE=ocg-kimi SB_MULTI_AI_OCG_POOL=lite OPENCODE_MODEL=wrong OPENCODE_RUN_MODEL=opencode-go/wrong -- "$SB"
assert_contains "enforce: worker env drift rejected" "$TL_OUT" "rc=2"

# forged / incomplete multi-ai env
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1 --
assert_contains "enforce: forged worker env message" "$TL_ERR" "incomplete or forged multi-ai-worker env"
assert_contains "enforce: forged worker env rc" "$TL_OUT" "rc=2"
enforce SB_MULTI_AI_OCG_PROFILE=ocg-kimi --
assert_contains "enforce: lone profile is forged" "$TL_OUT" "rc=2"
enforce SB_MULTI_AI_OCG_VALIDATED=1 --
assert_contains "enforce: lone validated flag is forged" "$TL_OUT" "rc=2"
# pool mode set but not validated (and no other flag) is not caught by the forged guard
enforce SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-pool-v1 --
assert_contains "enforce: unvalidated pool mode falls to default pin" "$TL_OUT" "rc=0"

# nothing set -> default pin; drifted pin rejected
enforce X=1 --
assert_contains "enforce: default pin ok" "$TL_OUT" "rc=0"
enforce OPENCODE_MODEL=drift --
assert_contains "enforce: default pin drift rejected" "$TL_OUT" "rc=2"

tl_results
