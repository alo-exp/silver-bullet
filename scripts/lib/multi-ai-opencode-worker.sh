#!/usr/bin/env bash
# Multi-AI OpenCode worker-v1 policy (sourced by multi-AI paths / lazy from opencode-cli).
# Keep shared scripts/lib/opencode-cli.sh focused on CLI resolve + default mimo pin.

agent_opencode_registry_path() {
  local sb_root="${1:-.}"
  printf '%s/skills/silver-multi-ai-task/reference/model-family-registry-v1.json\n' "$sb_root"
}

agent_opencode_profile_to_run_model() {
  local profile_id="$1"
  local sb_root="${2:-.}"
  local reg run_model
  reg="$(agent_opencode_registry_path "$sb_root")"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    run_model="$(jq -r --arg p "$profile_id" '.aliases[$p] // empty' "$reg" 2>/dev/null || true)"
    if [[ -n "$run_model" ]]; then
      printf '%s\n' "$run_model"
      return 0
    fi
  fi
  if [[ "$profile_id" == ocg-* ]]; then
    printf '%s\n' "${profile_id#ocg-}"
    return 0
  fi
  printf '%s\n' "$profile_id"
}

agent_opencode_validate_multi_ai_pool_mode() {
  local pool="${1:-lite}"
  local sb_root="${2:-.}"
  if [[ "$pool" != "lite" && "$pool" != "regular" ]]; then
    printf 'ERROR: multi-ai pool must be lite or regular (got %s)\n' "$pool" >&2
    return 2
  fi
  local reg
  reg="$(agent_opencode_registry_path "$sb_root")"
  [[ -f "$reg" ]] || {
    printf 'ERROR: missing model family registry at %s\n' "$reg" >&2
    return 2
  }
  if ! command -v jq >/dev/null 2>&1; then
    printf 'ERROR: jq required for multi-ai-pool-v1 validation\n' >&2
    return 2
  fi
  local key="ocg_lite_pool"
  [[ "$pool" == "regular" ]] && key="ocg_regular_pool"
  local count
  count="$(jq -r --arg k "$key" '.[$k] | length' "$reg" 2>/dev/null || echo 0)"
  if [[ "$count" -lt 1 ]]; then
    printf 'ERROR: empty OCG pool %s in registry\n' "$pool" >&2
    return 2
  fi
  return 0
}

agent_opencode_validate_multi_ai_worker_mode() {
  local profile_id="$1"
  local pool="${2:-lite}"
  local sb_root="${3:-.}"
  if [[ "$pool" != "lite" && "$pool" != "regular" ]]; then
    printf 'ERROR: multi-ai pool must be lite or regular (got %s)\n' "$pool" >&2
    return 2
  fi
  local reg
  reg="$(agent_opencode_registry_path "$sb_root")"
  [[ -f "$reg" ]] || {
    printf 'ERROR: missing model family registry at %s\n' "$reg" >&2
    return 2
  }
  if ! command -v jq >/dev/null 2>&1; then
    printf 'ERROR: jq required for multi-ai-worker-v1 profile validation\n' >&2
    return 2
  fi
  local key="ocg_lite_pool"
  [[ "$pool" == "regular" ]] && key="ocg_regular_pool"
  if ! jq -e --arg p "$profile_id" --arg k "$key" '.[$k] | index($p) != null' "$reg" >/dev/null; then
    printf 'ERROR: profile %s not allowlisted for pool %s\n' "$profile_id" "$pool" >&2
    return 2
  fi
  return 0
}

agent_opencode_apply_multi_ai_worker_env() {
  local profile_id="$1"
  local pool="${2:-lite}"
  local sb_root="${3:-.}"
  agent_opencode_validate_multi_ai_worker_mode "$profile_id" "$pool" "$sb_root" || return $?
  local run_model
  run_model="$(agent_opencode_profile_to_run_model "$profile_id" "$sb_root")"
  export SB_AGENT_OPENCODE_DELEGATION_MODE="multi-ai-worker-v1"
  export SB_MULTI_AI_OCG_PROFILE="$profile_id"
  export SB_MULTI_AI_OCG_POOL="$pool"
  export SB_MULTI_AI_OCG_VALIDATED=1
  export OPENCODE_MODEL="$run_model"
  export OPENCODE_MODEL_PROVIDER="opencode-go"
  export OPENCODE_RUN_MODEL="opencode-go/${run_model}"
  return 0
}

agent_opencode_assert_validated_multi_ai_env() {
  local sb_root="${1:-.}"
  if [[ "${SB_AGENT_OPENCODE_DELEGATION_MODE:-}" != "multi-ai-worker-v1" || "${SB_MULTI_AI_OCG_VALIDATED:-}" != "1" || -z "${SB_MULTI_AI_OCG_PROFILE:-}" ]]; then
    printf 'ERROR: incomplete or forged multi-ai-worker env; use agent_opencode_apply_multi_ai_worker_env\n' >&2
    return 2
  fi
  agent_opencode_validate_multi_ai_worker_mode "${SB_MULTI_AI_OCG_PROFILE}" "${SB_MULTI_AI_OCG_POOL:-lite}" "$sb_root" || return $?
  local expected
  expected="$(agent_opencode_profile_to_run_model "${SB_MULTI_AI_OCG_PROFILE}" "$sb_root")"
  if [[ "${OPENCODE_MODEL:-}" != "$expected" || "${OPENCODE_RUN_MODEL:-}" != "opencode-go/${expected}" ]]; then
    printf 'ERROR: OPENCODE_MODEL must match validated multi-ai profile %s (expected run model %s)\n' "${SB_MULTI_AI_OCG_PROFILE}" "$expected" >&2
    return 2
  fi
  if [[ "${OPENCODE_MODEL_PROVIDER:-}" != "opencode-go" ]]; then
    printf 'ERROR: OPENCODE_MODEL_PROVIDER must be opencode-go (got %s)\n' "${OPENCODE_MODEL_PROVIDER:-}" >&2
    return 2
  fi
  return 0
}

