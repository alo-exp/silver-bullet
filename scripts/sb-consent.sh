#!/usr/bin/env bash
# Silver Bullet consent CLI: record and query per-user consent for the opt-in tool stack
# (Graphify, agentmemory, Alumnium, search-cli, RTK, Context Mode, LeanCTX).
#
# Consent lives in the user's own config (see `sb-consent.sh path`), never in a repository.
# A project's .silver-bullet.json can only recommend or disable a tool. The store format and
# the Bash API are documented in hooks/lib/user-consent.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../hooks/lib/user-consent.sh
source "${SCRIPT_DIR}/../hooks/lib/user-consent.sh"

usage() {
  cat <<'USAGE'
Usage: sb-consent.sh <command> [arguments]

Record and query your consent for Silver Bullet's opt-in tools. Consent is stored per user
(see `path`); a repository's .silver-bullet.json can recommend or disable a tool but never
grants consent.

Commands:
  path                                    print the consent store path
  status [--project DIR]                  every tool and capability with its decision
  check TOOL CAPABILITY [--project DIR]   print the decision; exit 0 only when granted
  grant TOOL   (--project DIR | --all-projects) [--capabilities LIST] [--source TEXT]
  decline TOOL (--project DIR | --all-projects) [--capabilities LIST] [--source TEXT]
  revoke TOOL  (--project DIR | --all-projects) [--capabilities LIST] [--source TEXT]

TOOL        graphify agentmemory alumnium search_cli rtk context_mode leanctx, or all
CAPABILITY  install  install or upgrade the tool on this machine
            wire     change machine-wide host configuration for it
            enforce  let Silver Bullet's hooks apply the tool's blocking gates
LIST        comma-separated capabilities (default: install,wire,enforce)

--project DIR records enforce for DIR's project only (DIR may be any directory inside the
project; the directory holding .silver-bullet.json is recorded). install and wire are machine-wide, so
grant and revoke record them for the machine; decline --project records enforce only.
--all-projects records every listed capability for the machine (all projects).

Exit status: 0 success (check: granted), 1 check: not granted, 2 error, 64 usage error.
USAGE
}

usage_error() {
  printf 'sb-consent: %s\n' "$1" >&2
  printf 'Run sb-consent.sh --help for usage.\n' >&2
  exit 64
}

command -v jq >/dev/null 2>&1 || { printf 'sb-consent: jq is required\n' >&2; exit 2; }

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

project=""
all_projects=0
caps="install,wire,enforce"
source_label="sb-consent.sh"
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || usage_error "--project needs a directory"
      project="$2"
      shift 2
      ;;
    --all-projects) all_projects=1; shift ;;
    --capabilities)
      [[ $# -ge 2 ]] || usage_error "--capabilities needs a list"
      caps="$2"
      shift 2
      ;;
    --source)
      [[ $# -ge 2 ]] || usage_error "--source needs a label"
      source_label="$2"
      shift 2
      ;;
    -*) usage_error "unknown option: $1" ;;
    *) positional+=("$1"); shift ;;
  esac
done
if [[ -n "$project" && ! -d "$project" ]]; then
  printf 'sb-consent: not a directory: %s\n' "$project" >&2
  exit 2
fi

# --project may name any directory inside the project: record the directory that holds
# .silver-bullet.json (what the gates look up), else the directory itself.
if [[ -n "$project" ]]; then
  _sb_probe="$(cd -P -- "$project" && pwd -P)"
  while [[ "$_sb_probe" != "/" && ! -f "$_sb_probe/.silver-bullet.json" ]]; do
    _sb_probe="$(dirname "$_sb_probe")"
  done
  if [[ -f "$_sb_probe/.silver-bullet.json" ]]; then
    project="$_sb_probe"
  fi
fi

record() { # decision
  local decision="$1" tool tools enforce_caps="" machine_caps="" cap
  [[ ${#positional[@]} -eq 1 ]] || usage_error "${cmd} takes exactly one TOOL"
  if [[ "${positional[0]}" == "all" ]]; then
    tools="${SB_RECOMMENDED_TOOL_IDS[*]}"
  else
    sb_consent_tool_valid "${positional[0]}" || usage_error "unknown tool: ${positional[0]}"
    tools="${positional[0]}"
  fi
  [[ -n "$project" || "$all_projects" == 1 ]] || usage_error "${cmd} needs --project DIR or --all-projects"
  [[ -z "$project" || "$all_projects" == 0 ]] || usage_error "use either --project or --all-projects"
  for cap in ${caps//,/ }; do
    sb_consent_capability_valid "$cap" || usage_error "unknown capability: ${cap}"
    if [[ -n "$project" && "$cap" == "enforce" ]]; then
      enforce_caps="enforce"
    elif [[ -n "$project" && "$decision" == "declined" ]]; then
      printf 'sb-consent: decline --project records enforce only; %s is unchanged\n' "$cap" >&2
    else
      machine_caps="${machine_caps:+${machine_caps},}${cap}"
    fi
  done
  for tool in $tools; do
    if [[ -n "$enforce_caps" ]]; then
      sb_consent_set "$decision" "$tool" "$enforce_caps" "$project" "$source_label" || exit 2
    fi
    if [[ -n "$machine_caps" ]]; then
      sb_consent_set "$decision" "$tool" "$machine_caps" machine "$source_label" || exit 2
    fi
    printf '%s %s: %s\n' "$cmd" "$tool" "$(sb_consent_status_summary "$tool" "$project")"
  done
}

sb_consent_status_summary() {
  local tool="$1" dir="${2:-}" cap out=""
  for cap in $SB_CONSENT_CAPABILITIES; do
    out="${out:+${out}, }${cap}=$(sb_consent_decision "$tool" "$cap" "$dir")"
  done
  printf '%s' "$out"
}

case "$cmd" in
  path)
    [[ ${#positional[@]} -eq 0 ]] || usage_error "path takes no arguments"
    printf '%s\n' "$(sb_consent_store_path)"
    ;;
  status)
    [[ ${#positional[@]} -eq 0 ]] || usage_error "status takes no arguments"
    printf 'Consent store: %s\n' "$(sb_consent_store_path)"
    if [[ -n "$project" ]]; then
      printf 'Project: %s\n' "$(sb_consent_project_key "$project")"
    fi
    sb_consent_status_lines "$project"
    ;;
  check)
    [[ ${#positional[@]} -eq 2 ]] || usage_error "check takes TOOL and CAPABILITY"
    sb_consent_tool_valid "${positional[0]}" || usage_error "unknown tool: ${positional[0]}"
    sb_consent_capability_valid "${positional[1]}" || usage_error "unknown capability: ${positional[1]}"
    decision="$(sb_consent_decision "${positional[0]}" "${positional[1]}" "$project")"
    printf '%s\n' "$decision"
    [[ "$decision" == "granted" ]] || exit 1
    ;;
  grant) record granted ;;
  decline) record declined ;;
  revoke) record unset ;;
  -h|--help|help) usage ;;
  "") usage >&2; exit 64 ;;
  *) usage_error "unknown command: ${cmd}" ;;
esac
