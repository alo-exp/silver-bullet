#!/usr/bin/env bash
# P2 harness: require two consecutive strict-clean enterprise E2E rounds (gate files).
#
# Usage:
#   bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host claude
#   bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh ROUND-5-GATES.md ROUND-6-GATES.md
#   SB_E2E_GATES_ROUND1=... SB_E2E_GATES_ROUND2=... bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --json
set -euo pipefail

# Resolve repo root even when invoked via scripts/enterprise-e2e/lib/deterministic/ symlink.
if [[ -z "${SB_ROOT:-}" ]]; then
  _e2e_root_candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$_e2e_root_candidate" != "/" ]]; do
    if [[ -f "${_e2e_root_candidate}/scripts/enterprise-e2e/config/hosts.json" ]]; then
      SB_ROOT="$_e2e_root_candidate"
      break
    fi
    _e2e_root_candidate="$(dirname "$_e2e_root_candidate")"
  done
  SB_ROOT="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
fi
export SB_ROOT
JSON_OUT=0
HOST_ARG=""
ROUND1="${SB_E2E_GATES_ROUND1:-${SB_E2E_GATES_ROUND1_FILE:-}}"
ROUND2="${SB_E2E_GATES_ROUND2:-${SB_E2E_GATES_ROUND2_FILE:-}}"

usage() {
  cat <<'EOF'
Verify two consecutive strict-clean rounds from ROUND-*-GATES.md gate tables.

Options:
  --host claude|codex|cursor   Default gate file pair for host track
  --json                       Machine-readable result on stdout
  -h, --help

Args (optional): path to round N gates, path to round N+1 gates.
Env: SB_E2E_GATES_ROUND1, SB_E2E_GATES_ROUND2 (or *_FILE), SB_ROOT.

Exit 0 when both rounds show strict-clean PASS; exit 1 otherwise.
EOF
}

enterprise_e2e_consecutive_rounds_resolve_host_defaults() {
  local host="$1" root="$2"
  case "$host" in
    claude)
      printf '%s\n' "${ROUND1:-${root}/.planning/enterprise-e2e/ROUND-5-GATES.md}"
      printf '%s\n' "${ROUND2:-${root}/.planning/enterprise-e2e/ROUND-6-GATES.md}"
      ;;
    codex)
      printf '%s\n' "${ROUND1:-${root}/.planning/enterprise-e2e/ROUND-CODEX-1-GATES.md}"
      printf '%s\n' "${ROUND2:-${root}/.planning/enterprise-e2e/ROUND-CODEX-2-GATES.md}"
      ;;
    cursor)
      printf '%s\n' "${ROUND1:-${root}/.planning/enterprise-e2e/ROUND-CURSOR-1-GATES.md}"
      printf '%s\n' "${ROUND2:-${root}/.planning/enterprise-e2e/ROUND-CURSOR-2-GATES.md}"
      ;;
    *)
      echo "enterprise-e2e-consecutive-rounds-check: unknown host track: $host" >&2
      return 2
      ;;
  esac
}

# stdout: pass | fail | pending | missing | unknown
enterprise_e2e_gates_strict_clean_status() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "missing"
    return 0
  fi

  local raw=""
  raw="$(awk -F'|' '
    $0 ~ /\|/ && ($2 ~ /Round strict-clean/ || $2 ~ /Round clean \(zero new issues vs baseline\)/) {
      cell = $3
      gsub(/^[ \t]+|[ \t]+$/, "", cell)
      print cell
      exit
    }
  ' "$file" 2>/dev/null || true)"

  if [[ -z "$raw" ]]; then
    echo "unknown"
    return 0
  fi

  local norm="${raw//\*\*/}"
  norm="$(printf '%s' "$norm" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  local upper
  upper="$(printf '%s' "$norm" | tr '[:lower:]' '[:upper:]')"

  if [[ "$upper" == PASS* ]] || [[ "$norm" =~ ^[Pp]ass ]]; then
    echo "pass"
    return 0
  fi
  if [[ "$upper" == FAIL* ]] || [[ "$upper" == "NO" ]] || [[ "$upper" == NO* ]]; then
    echo "fail"
    return 0
  fi
  if [[ "$upper" == PENDING* ]] || [[ "$upper" == *PENDING* ]]; then
    echo "pending"
    return 0
  fi
  if [[ "$upper" == *IN\ PROGRESS* ]] || [[ "$upper" == *NOT\ CLEAN* ]]; then
    echo "fail"
    return 0
  fi

  echo "unknown"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --host)
      [[ $# -ge 2 ]] || { echo "Missing value for --host" >&2; exit 2; }
      HOST_ARG="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$ROUND1" ]]; then
        ROUND1="$1"
      elif [[ -z "$ROUND2" ]]; then
        ROUND2="$1"
      else
        echo "Unexpected extra argument: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  if [[ -z "$ROUND1" ]]; then
    ROUND1="$1"
  elif [[ -z "$ROUND2" ]]; then
    ROUND2="$1"
  else
    echo "Unexpected extra argument: $1" >&2
    exit 2
  fi
  shift
done

if [[ -n "$HOST_ARG" ]]; then
    read -r ROUND1 < <(enterprise_e2e_consecutive_rounds_resolve_host_defaults "$HOST_ARG" "$SB_ROOT" | sed -n '1p')
    read -r ROUND2 < <(enterprise_e2e_consecutive_rounds_resolve_host_defaults "$HOST_ARG" "$SB_ROOT" | sed -n '2p')
elif [[ -z "$ROUND1" || -z "$ROUND2" ]]; then
  host="${SB_E2E_LIVE_RUNTIME:-${SILVER_BULLET_RUNTIME:-claude}}"
    read -r _default1 < <(enterprise_e2e_consecutive_rounds_resolve_host_defaults "$host" "$SB_ROOT" | sed -n '1p')
    read -r _default2 < <(enterprise_e2e_consecutive_rounds_resolve_host_defaults "$host" "$SB_ROOT" | sed -n '2p')
    ROUND1="${ROUND1:-$_default1}"
    ROUND2="${ROUND2:-$_default2}"
fi

# Resolve relative paths against SB_ROOT
resolve_gate_path() {
  local p="$1"
  if [[ "$p" == /* ]]; then
    printf '%s\n' "$p"
  elif [[ -f "$p" ]]; then
    printf '%s\n' "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  else
    printf '%s\n' "${SB_ROOT}/${p}"
  fi
}

ROUND1="$(resolve_gate_path "$ROUND1")"
ROUND2="$(resolve_gate_path "$ROUND2")"

status1="$(enterprise_e2e_gates_strict_clean_status "$ROUND1")"
status2="$(enterprise_e2e_gates_strict_clean_status "$ROUND2")"
ok=0
if [[ "$status1" == pass && "$status2" == pass ]]; then
  ok=1
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq required for --json" >&2
    exit 2
  fi
  jq -n \
    --argjson ok "$ok" \
    --arg round1_path "$ROUND1" \
    --arg round1_status "$status1" \
    --arg round2_path "$ROUND2" \
    --arg round2_status "$status2" \
    '{
      ok: (($ok | tonumber) == 1),
      consecutive_strict_clean_pair: (if ($ok | tonumber) == 1 then "pass" else "fail" end),
      round1: { path: $round1_path, strict_clean: $round1_status },
      round2: { path: $round2_path, strict_clean: $round2_status }
    }'
else
  echo "enterprise-e2e consecutive strict-clean pair:"
  echo "  round1: ${ROUND1} → ${status1}"
  echo "  round2: ${ROUND2} → ${status2}"
fi

if [[ "$ok" -eq 1 ]]; then
  exit 0
fi

echo "enterprise-e2e-consecutive-rounds-check: FAIL — need 2/2 consecutive strict-clean PASS (got round1=${status1}, round2=${status2})" >&2
echo "  round1: ${ROUND1}" >&2
echo "  round2: ${ROUND2}" >&2
exit 1
