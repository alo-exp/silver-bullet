#!/usr/bin/env bash
# silver-add.sh — structured audit finding fingerprint, dedup, prioritization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  silver-add.sh fingerprint --domain D --scope S --finding F
  silver-add.sh dedup --fingerprint FP [--root DIR]
  silver-add.sh prioritize --impact N --risk N --evidence-strength N --effort N
  silver-add.sh adapter-dedup --fingerprint FP [--root DIR]
  silver-add.sh adapter-create --payload JSON [--root DIR]

Fingerprint formula (canonical, shared with scripts/lib/evidence_common.py):
  sha256(normalize(domain) + "\n" + normalize(scope) + "\n" + normalize(finding))
EOF
}

py_fingerprint() {
  local domain="$1" scope="$2" finding="$3"
  PYTHONPATH="${SCRIPT_DIR}/lib" python3 -c '
import sys
from evidence_common import audit_fingerprint
print(audit_fingerprint(sys.argv[1], sys.argv[2], sys.argv[3]))
' "$domain" "$scope" "$finding"
}

py_prioritize() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys

impact, risk, evidence, effort = (int(x) for x in sys.argv[1:5])
score = impact + risk + evidence - effort
print(score)
PY
}

cmd_fingerprint() {
  local domain="" scope="" finding=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) domain="${2:-}"; shift 2 ;;
      --scope) scope="${2:-}"; shift 2 ;;
      --finding) finding="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; return 1 ;;
    esac
  done
  if [[ -z "$domain" || -z "$scope" || -z "$finding" ]]; then
    echo "fingerprint requires --domain, --scope, and --finding" >&2
    return 1
  fi
  py_fingerprint "$domain" "$scope" "$finding"
}

cmd_dedup() {
  local fp="" root="$PWD"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fingerprint) fp="${2:-}"; shift 2 ;;
      --root) root="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; return 1 ;;
    esac
  done
  if [[ -z "$fp" ]]; then
    echo "dedup requires --fingerprint" >&2
    return 1
  fi

  local hit=""
  for file in "$root/docs/issues/ISSUES.md" "$root/docs/issues/BACKLOG.md"; do
    [[ -f "$file" ]] || continue
    if grep -qF "$fp" "$file"; then
      hit="$file"
      break
    fi
  done

  if [[ -z "$hit" && -f "$root/.silver-bullet/scan-state.json" ]]; then
    if jq -e --arg fp "$fp" '.fingerprints[$fp] // empty' "$root/.silver-bullet/scan-state.json" >/dev/null 2>&1; then
      hit="$root/.silver-bullet/scan-state.json"
    fi
  fi

  if [[ -n "$hit" ]]; then
    echo "duplicate:$hit"
    return 0
  fi
  echo "unique"
}

cmd_prioritize() {
  local impact="" risk="" evidence="" effort=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --impact) impact="${2:-}"; shift 2 ;;
      --risk) risk="${2:-}"; shift 2 ;;
      --evidence-strength) evidence="${2:-}"; shift 2 ;;
      --effort) effort="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; return 1 ;;
    esac
  done
  for v in impact risk evidence effort; do
    if [[ -z "${!v}" ]]; then
      echo "prioritize requires --impact, --risk, --evidence-strength, --effort" >&2
      return 1
    fi
  done
  py_prioritize "$impact" "$risk" "$evidence" "$effort"
}

read_adapter_config() {
  local root="$1"
  local cfg="$root/.silver-bullet.json"
  if [[ ! -f "$cfg" ]]; then
    echo "missing config: $cfg" >&2
    return 1
  fi
  CREATE_CMD=$(jq -r '.issue_tracker_adapter.create_issue_command // empty' "$cfg")
  DEDUPE_CMD=$(jq -r '.issue_tracker_adapter.dedupe_command // empty' "$cfg")
  TRACKER=$(jq -r '.issue_tracker // "local"' "$cfg")
}

cmd_adapter_dedup() {
  local fp="" root="$PWD"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fingerprint) fp="${2:-}"; shift 2 ;;
      --root) root="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; return 1 ;;
    esac
  done
  if [[ -z "$fp" ]]; then
    echo "adapter-dedup requires --fingerprint" >&2
    return 1
  fi

  read_adapter_config "$root" || return 1

  if [[ -z "$DEDUPE_CMD" || "$DEDUPE_CMD" == "null" ]]; then
    cmd_dedup --fingerprint "$fp" --root "$root"
    return $?
  fi

  local payload
  payload=$(jq -n --arg fp "$fp" --arg schema "silver-triage-issue-v1" \
    '{schema: $schema, fingerprint: $fp, action: "dedupe"}')

  local result
  if ! result=$(printf '%s' "$payload" | bash -c "$DEDUPE_CMD" 2>&1); then
    echo "adapter dedupe command failed: $result" >&2
    return 1
  fi

  local status id url
  status=$(printf '%s' "$result" | jq -r '.status // empty' 2>/dev/null || true)
  id=$(printf '%s' "$result" | jq -r '.id // empty' 2>/dev/null || true)
  url=$(printf '%s' "$result" | jq -r '.url // empty' 2>/dev/null || true)

  if [[ "$status" == "duplicate" && -n "$id" ]]; then
    echo "duplicate:$id"
    if [[ -n "$url" ]]; then
      echo "url:$url" >&2
    fi
    return 0
  fi

  cmd_dedup --fingerprint "$fp" --root "$root"
}

cmd_adapter_create() {
  local payload="" root="$PWD"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --payload) payload="${2:-}"; shift 2 ;;
      --root) root="${2:-}"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; return 1 ;;
    esac
  done
  if [[ -z "$payload" ]]; then
    echo "adapter-create requires --payload JSON" >&2
    return 1
  fi

  read_adapter_config "$root" || return 1

  if [[ "$TRACKER" != "custom" ]]; then
    echo "adapter-create requires issue_tracker=custom (got: $TRACKER)" >&2
    return 1
  fi
  if [[ -z "$CREATE_CMD" || "$CREATE_CMD" == "null" || "$CREATE_CMD" == "REPLACE_ME" ]]; then
    echo "issue_tracker_adapter.create_issue_command is not configured" >&2
    return 1
  fi

  if ! printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    echo "adapter-create payload is not valid JSON" >&2
    return 1
  fi

  local result
  if ! result=$(printf '%s' "$payload" | bash -c "$CREATE_CMD" 2>&1); then
    echo "adapter create command failed: $result" >&2
    return 1
  fi

  if ! printf '%s' "$result" | jq -e '.id and .status' >/dev/null 2>&1; then
    echo "adapter create command returned invalid JSON (need id, status): $result" >&2
    return 1
  fi

  printf '%s\n' "$result"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    fingerprint) cmd_fingerprint "$@" ;;
    dedup) cmd_dedup "$@" ;;
    prioritize) cmd_prioritize "$@" ;;
    adapter-dedup) cmd_adapter_dedup "$@" ;;
    adapter-create) cmd_adapter_create "$@" ;;
    -h|--help|"") usage ;;
    *) echo "Unknown command: $cmd" >&2; usage >&2; return 1 ;;
  esac
}

main "$@"
