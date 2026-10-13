#!/usr/bin/env bash
# Canonical OpenCode CLI resolution for scripts/ and tests/live/ harnesses.
# Desktop OpenCode.app is NOT the automation CLI — use ~/.opencode/bin/opencode.
# Multi-AI worker-v1 policy lives in multi-ai-opencode-worker.sh (sourced below).

resolve_native_opencode_cli_path() {
  local requested="${1:-${OPENCODE_BIN:-}}"
  local candidate=""

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if [[ -x "$candidate" && "$(basename "$candidate")" == "opencode" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="${HOME}/.opencode/bin/opencode"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(command -v opencode 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" && "$(basename "$candidate")" == "opencode" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

# MiMo V2.5 via opencode-go — mandatory for SB delegation (no model drift).
agent_opencode_pin_mimo_model_env() {
  export OPENCODE_MODEL="${OPENCODE_MODEL:-mimo-v2.5}"
  export OPENCODE_MODEL_PROVIDER="${OPENCODE_MODEL_PROVIDER:-opencode-go}"
  export OPENCODE_RUN_MODEL="${OPENCODE_RUN_MODEL:-opencode-go/mimo-v2.5}"

  if [[ "$OPENCODE_MODEL" != "mimo-v2.5" ]]; then
    printf 'ERROR: OPENCODE_MODEL must be mimo-v2.5 (got %s)\n' "$OPENCODE_MODEL" >&2
    return 2
  fi
  if [[ "$OPENCODE_MODEL_PROVIDER" != "opencode-go" ]]; then
    printf 'ERROR: OPENCODE_MODEL_PROVIDER must be opencode-go (got %s)\n' "$OPENCODE_MODEL_PROVIDER" >&2
    return 2
  fi
  if [[ "$OPENCODE_RUN_MODEL" != "opencode-go/mimo-v2.5" ]]; then
    printf 'ERROR: OPENCODE_RUN_MODEL must be opencode-go/mimo-v2.5 (got %s)\n' "$OPENCODE_RUN_MODEL" >&2
    return 2
  fi
  return 0
}

# Load multi-AI worker policy so single-source callers (delegate) get apply/assert/validate.
_AGENT_OPENCODE_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/multi-ai-opencode-worker.sh
if [[ -f "${_AGENT_OPENCODE_CLI_DIR}/multi-ai-opencode-worker.sh" ]]; then
  source "${_AGENT_OPENCODE_CLI_DIR}/multi-ai-opencode-worker.sh"
else
  printf 'WARN: multi-ai-opencode-worker.sh missing; multi-ai-worker-v1 policy unavailable
' >&2
fi
unset _AGENT_OPENCODE_CLI_DIR

agent_opencode_enforce_invoke_model_policy() {
  local sb_root="${1:-}"
  if [[ -z "$sb_root" ]]; then
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sb_root="$(cd "${here}/../.." && pwd)"
  fi
  if [[ "${SB_AGENT_OPENCODE_DELEGATION_MODE:-}" == "multi-ai-pool-v1" && "${SB_MULTI_AI_OCG_VALIDATED:-}" == "1" ]]; then
    agent_opencode_validate_multi_ai_pool_mode "${SB_MULTI_AI_OCG_POOL:-lite}" "$sb_root"
    return $?
  fi
  if [[ "${SB_AGENT_OPENCODE_DELEGATION_MODE:-}" == "multi-ai-worker-v1" && "${SB_MULTI_AI_OCG_VALIDATED:-}" == "1" && -n "${SB_MULTI_AI_OCG_PROFILE:-}" ]]; then
    agent_opencode_assert_validated_multi_ai_env "$sb_root"
    return $?
  fi
  if [[ "${SB_AGENT_OPENCODE_DELEGATION_MODE:-}" == "multi-ai-worker-v1" || -n "${SB_MULTI_AI_OCG_PROFILE:-}" || "${SB_MULTI_AI_OCG_VALIDATED:-}" == "1" ]]; then
    if [[ "${SB_AGENT_OPENCODE_DELEGATION_MODE:-}" == "multi-ai-pool-v1" ]]; then
      agent_opencode_validate_multi_ai_pool_mode "${SB_MULTI_AI_OCG_POOL:-lite}" "$sb_root"
      return $?
    fi
    printf 'ERROR: incomplete or forged multi-ai-worker env; use agent_opencode_apply_multi_ai_worker_env\n' >&2
    return 2
  fi
  agent_opencode_pin_mimo_model_env
}

