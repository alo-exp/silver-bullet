#!/usr/bin/env bash
# Contract tests for multi-ai-worker-v1 OpenCode delegation mode.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/opencode-cli.sh
source "$REPO_ROOT/scripts/lib/opencode-cli.sh"
# shellcheck source=scripts/agent-opencode/lib.sh
source "$REPO_ROOT/scripts/agent-opencode/lib.sh"

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

if agent_opencode_validate_multi_ai_worker_mode "ocg-mimo-v2.5" lite "$REPO_ROOT"; then
  pass "allowlisted lite profile accepted"
else
  fail "allowlisted lite profile rejected"
fi

if agent_opencode_validate_multi_ai_worker_mode "not-real-profile" lite "$REPO_ROOT" 2>/dev/null; then
  fail "unknown profile should be rejected"
else
  pass "unknown profile rejected"
fi

if agent_opencode_pin_mimo_model_env 2>/dev/null; then
  pass "default mimo pin unchanged"
else
  fail "default mimo pin failed"
fi

(
  export SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1
  unset SB_MULTI_AI_OCG_VALIDATED SB_MULTI_AI_OCG_PROFILE
  export OPENCODE_MODEL=evil-model
  export OPENCODE_MODEL_PROVIDER=opencode-go
  export OPENCODE_RUN_MODEL=opencode-go/mimo-v2.5
  if agent_opencode_apply_runtime_env 2>/dev/null; then
    echo "unvalidated multi-ai mode must not skip mimo pin" >&2
    exit 1
  fi
) && pass "unvalidated multi-ai mode cannot skip mimo pin" || fail "unvalidated multi-ai mode skipped mimo pin"

(
  export SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1
  export SB_MULTI_AI_OCG_VALIDATED=1
  export SB_MULTI_AI_OCG_PROFILE=ocg-mimo-v2.5
  export OPENCODE_MODEL=evil-model
  export OPENCODE_MODEL_PROVIDER=opencode-go
  export OPENCODE_RUN_MODEL=opencode-go/evil-model
  if agent_opencode_apply_runtime_env 2>/dev/null; then
    echo "forged VALIDATED must not accept evil-model" >&2
    exit 1
  fi
) && pass "forged VALIDATED cannot bypass model check" || fail "forged VALIDATED bypassed model check"

if agent_opencode_apply_multi_ai_worker_env "ocg-mimo-v2.5" lite "$REPO_ROOT" && \
   [[ "${OPENCODE_MODEL}" == "mimo-v2.5" && "${OPENCODE_RUN_MODEL}" == "opencode-go/mimo-v2.5" ]]; then
  pass "ocg profile maps to opencode run model"
else
  fail "ocg profile opencode model mapping"
fi

(
  export SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1
  export SB_MULTI_AI_OCG_VALIDATED=1
  export SB_MULTI_AI_OCG_PROFILE=ocg-mimo-v2.5
  export OPENCODE_MODEL=ocg-mimo-v2.5
  export OPENCODE_MODEL_PROVIDER=evil-provider
  export OPENCODE_RUN_MODEL=opencode-go/ocg-mimo-v2.5
  if agent_opencode_apply_runtime_env 2>/dev/null; then
    echo "forged provider must be rejected" >&2
    exit 1
  fi
) && pass "forged provider cannot bypass model check" || fail "forged provider bypassed model check"


# CLI-only source must expose apply via lazy facade (delegate contract).
(
  unset SB_MULTI_AI_OPENCODE_WORKER_LOADED
  # shellcheck source=scripts/lib/opencode-cli.sh
  source "$REPO_ROOT/scripts/lib/opencode-cli.sh"
  if ! declare -F agent_opencode_apply_multi_ai_worker_env >/dev/null; then
    echo "apply facade missing after cli-only source" >&2
    exit 1
  fi
  agent_opencode_apply_multi_ai_worker_env "ocg-mimo-v2.5" lite "$REPO_ROOT" || exit 1
) && pass "cli-only source apply facade works" || fail "cli-only source apply facade broken"

echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
