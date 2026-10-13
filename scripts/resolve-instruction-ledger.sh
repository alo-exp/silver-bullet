#!/usr/bin/env bash
# Sanctioned writer for instruction-ledger leaf status (SB-BUG-D #250).
#
# Direct Edit/Write of ${SB_RUNTIME_STATE_DIR}/instruction-ledger.json is blocked
# by state tamper guards. Agents must use this helper (or the library function
# sb_instruction_ledger_resolve_item) to mark leaf items done/deferred.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PLUGIN_ROOT}/hooks/lib"

# shellcheck source=../hooks/lib/runtime-paths.sh
source "${LIB_DIR}/runtime-paths.sh"
# shellcheck source=../hooks/lib/instruction-ledger.sh
source "${LIB_DIR}/instruction-ledger.sh"

usage() {
  cat <<'USAGE'
Usage:
  resolve-instruction-ledger.sh list
  resolve-instruction-ledger.sh done <item-id-or-label> --evidence "<text>"
  resolve-instruction-ledger.sh deferred <item-id-or-label> --evidence "<text>"

Marks a leaf instruction-ledger item done or deferred with required evidence.
Do not Edit instruction-ledger.json directly — state tamper guards block it.
USAGE
}

cmd="${1:-}"
case "$cmd" in
  -h|--help|help|"")
    usage
    exit 0
    ;;
  list)
    outfile="$(sb_instruction_ledger_file)"
    if [[ ! -f "$outfile" ]]; then
      printf 'No instruction ledger at %s\n' "$outfile"
      exit 0
    fi
    if sb_instruction_ledger_scope_mismatch "$PWD" 2>/dev/null; then
      printf 'Ledger scope mismatches current branch/worktree — ignoring foreign ledger.\n'
      sb_instruction_ledger_clear
      exit 0
    fi
    sb_instruction_ledger_pending_summary || true
    exit 0
    ;;
  done|deferred)
    shift
    selector="${1:-}"
    evidence=""
    shift || true
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --evidence)
          evidence="${2:-}"
          shift 2 || true
          ;;
        --evidence=*)
          evidence="${1#--evidence=}"
          shift
          ;;
        *)
          printf 'ERROR: unknown argument: %s\n' "$1" >&2
          usage >&2
          exit 2
          ;;
      esac
    done
    if [[ -z "$selector" || -z "$evidence" ]]; then
      printf 'ERROR: item selector and --evidence are required\n' >&2
      usage >&2
      exit 2
    fi
    if ! sb_instruction_ledger_resolve_item "$selector" "$cmd" "$evidence"; then
      printf 'ERROR: could not resolve item %q as %s (missing ledger, ambiguous match, or foreign scope)\n' \
        "$selector" "$cmd" >&2
      exit 1
    fi
    printf 'OK: marked %q as %s\n' "$selector" "$cmd"
    if sb_instruction_ledger_all_resolved; then
      printf 'Instruction ledger fully resolved.\n'
    else
      sb_instruction_ledger_pending_summary || true
    fi
    exit 0
    ;;
  *)
    printf 'ERROR: unknown command: %s\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
