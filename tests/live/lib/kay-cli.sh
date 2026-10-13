#!/usr/bin/env bash

resolve_kay_cli_path() {
  local requested="${1:-${CODEX_BIN:-}}"
  local candidate=""
  local base_home
  local homes=()

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if [[ -x "$candidate" && "$(basename "$candidate")" == "kay" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="$(command -v kay 2>/dev/null || true)"
  if [[ -x "$candidate" && "$(basename "$candidate")" == "kay" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  for base_home in "${SB_LIVE_ORIGINAL_HOME:-}" "${HOME:-}"; do
    [[ -n "$base_home" ]] || continue
    homes+=("$base_home")
  done

  for base_home in "${homes[@]}"; do
    for candidate in \
      "$base_home/.local/bin/kay" \
      "$base_home/.kay/packages/standalone/current/kay"
    do
      if [[ -x "$candidate" && "$(basename "$candidate")" == "kay" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done

  return 1
}
