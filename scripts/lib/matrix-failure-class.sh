#!/usr/bin/env bash
# Classify enterprise E2E matrix failures: harness | product | environmental.
#
# Usage:
#   source scripts/lib/matrix-failure-class.sh
#   matrix_failure_class_from_snippet "$log_tail"
#   matrix_failure_class_from_file /path/to/row-attempt.log
set -euo pipefail

matrix_failure_class_from_snippet() {
  local snippet="${1:-}"
  [[ -n "$snippet" ]] || {
    printf '%s\n' "product"
    return 0
  }

  if printf '%s\n' "$snippet" | grep -qiE \
    '429|token[[:space:]]+plan|usage[[:space:]]+limit|rate[[:space:]]+limit|quota'; then
    printf '%s\n' "environmental"
    return 0
  fi
  if printf '%s\n' "$snippet" | grep -qiE \
    'ENOTFOUND|ECONNREFUSED|ConnectionRefused|Unable to connect|network error|ETIMEDOUT|EAI_AGAIN'; then
    printf '%s\n' "environmental"
    return 0
  fi
  if printf '%s\n' "$snippet" | grep -qiE \
    'expect|harness|Bypass Permissions|missing close-bracket|accept_bypass|claude-interactive-invoke|ANSI|exp_continue|spawn'; then
    printf '%s\n' "harness"
    return 0
  fi
  if printf '%s\n' "$snippet" | grep -qiE \
    'Stop hook error|hookEventName|planning-file-guard|completion-audit|orchestrator-directive'; then
    printf '%s\n' "product"
    return 0
  fi

  printf '%s\n' "product"
}

matrix_failure_class_from_file() {
  local log_file="${1:-}"
  local window="${2:-200}"
  if [[ ! -f "$log_file" ]]; then
    printf '%s\n' "product"
    return 0
  fi
  matrix_failure_class_from_snippet "$(tail -n "$window" "$log_file" 2>/dev/null || true)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <log-file-or-snippet>" >&2
    exit 2
  fi
  if [[ -f "$1" ]]; then
    matrix_failure_class_from_file "$1" "${2:-200}"
  else
    matrix_failure_class_from_snippet "$1"
  fi
fi
