#!/usr/bin/env bash
# Canonical Pi CLI resolution for scripts/ and tests/live/ harnesses.

resolve_native_pi_cli_path() {
  local requested="${1:-${PI_BIN:-}}"
  local candidate=""

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if [[ -x "$candidate" && "$(basename "$candidate")" == "pi" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  for candidate in /opt/homebrew/bin/pi "${HOME}/.local/bin/pi"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(command -v pi 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" && "$(basename "$candidate")" == "pi" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

# MiMo V2.5 via opencode-go — mandatory for SB delegation (no model drift).
agent_pi_pin_mimo_model_env() {
  export PI_PROVIDER="${PI_PROVIDER:-opencode-go}"
  export PI_MODEL="${PI_MODEL:-mimo-v2.5}"

  if [[ "$PI_PROVIDER" != "opencode-go" ]]; then
    printf 'ERROR: PI_PROVIDER must be opencode-go (got %s)\n' "$PI_PROVIDER" >&2
    return 2
  fi
  if [[ "$PI_MODEL" != "mimo-v2.5" ]]; then
    printf 'ERROR: PI_MODEL must be mimo-v2.5 (got %s)\n' "$PI_MODEL" >&2
    return 2
  fi
  return 0
}
