#!/usr/bin/env bash
# Canonical Codex CLI resolution for scripts/ and tests/live/ harnesses.

resolve_native_codex_cli_path() {
  local requested="${1:-${CODEX_BIN:-}}"
  local candidate=""

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if [[ -x "$candidate" && "$(basename "$candidate")" == "codex" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="/Applications/Codex.app/Contents/Resources/codex"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(command -v codex 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" && "$(basename "$(python3 - "$candidate" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
)")" == "codex" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}
