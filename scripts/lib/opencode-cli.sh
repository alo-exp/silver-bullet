#!/usr/bin/env bash
# Canonical OpenCode CLI resolution for scripts/ and tests/live/ harnesses.
# Desktop OpenCode.app is NOT the automation CLI — use ~/.opencode/bin/opencode.

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
