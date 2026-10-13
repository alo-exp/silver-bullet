#!/usr/bin/env bash
# Shared Silver Bullet host installer bootstrap and helpers.
# Sourced by scripts/install-{claude,codex,cursor}.sh — not executed directly.

if [[ -z "${REPO_ROOT:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

if [[ -z "${SB_INSTALL_COMMON_BOOTSTRAPPED:-}" ]]; then
  export SB_RTK_COMPAT_MODE="${SB_RTK_COMPAT_MODE:-verbatim}"
  # shellcheck source=../../hooks/lib/rtk-compat.sh
  source "${REPO_ROOT}/hooks/lib/rtk-compat.sh"
  # shellcheck source=agent-bundle-paths.sh
  source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
  SB_INSTALL_COMMON_BOOTSTRAPPED=1
  export SB_INSTALL_COMMON_BOOTSTRAPPED
fi

AGENT_RENDERER="${AGENT_RENDERER:-${REPO_ROOT}/scripts/render-agent-bundle.py}"
PUBLIC_RELEASE_ONLY="${PUBLIC_RELEASE_ONLY:-0}"

render_agent_bundle() {
  local agent="$1"

  mkdir -p "${REPO_ROOT}/agents" "${REPO_ROOT}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent "$agent" \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" "$agent")"
}

find_silver_bullet_project_root() {
  local search_dir="${1:-$PWD}"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s\n' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir=$(dirname "$search_dir")
  done
  return 1
}

# Usage: sb_install_parse_common_args "$@" --purge-flag PURGE_VAR [--extra case...]
# Sets PUBLIC_RELEASE_ONLY and optional purge variable from argv; leaves remainder in $@
sb_install_parse_common_args() {
  local purge_flag="${1:-}"
  shift
  local purge_var="${1:-}"
  shift
  local -a extra_cases=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    extra_cases+=("$1")
    shift
  done
  [[ "${1:-}" == "--" ]] && shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --public-release) PUBLIC_RELEASE_ONLY=1; shift ;;
      -h|--help)
        if declare -f usage >/dev/null 2>&1; then
          usage
        else
          printf 'Usage: see host install script --help\n' >&2
        fi
        exit 0
        ;;
      ${purge_flag})
        if [[ -n "$purge_var" ]]; then
          printf -v "$purge_var" '%s' 1
        fi
        shift
        ;;
      *)
        local matched=0
        local i=0
        while [[ $i -lt ${#extra_cases[@]} ]]; do
          if [[ "$1" == "${extra_cases[$i]}" ]]; then
            matched=1
            break
          fi
          i=$((i + 1))
        done
        if [[ "$matched" -eq 1 ]]; then
          shift
          continue
        fi
        printf 'Unknown argument: %s\n' "$1" >&2
        if declare -f usage >/dev/null 2>&1; then
          usage >&2
        fi
        exit 2
        ;;
    esac
  done
}

sb_install_public_release_banner() {
  local host_label="$1"
  local dev_source="$2"
  local pub_source="$3"
  if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
    printf '%s marketplace refreshed from public source %s\n' "$host_label" "$pub_source"
  else
    printf '%s marketplaces registered from %s\n' "$host_label" "$dev_source"
  fi
}
