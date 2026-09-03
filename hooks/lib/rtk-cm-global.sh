# shellcheck shell=bash
# RTK + Context Mode global setup — SB-independent apply/verify helpers.
# Sourced by: scripts/optimize-rtk-context-mode.sh, scripts/install-recommended-tools-global.sh

RTCM_ALL_HOSTS="claude codex cursor opencode hermes goose"
# shellcheck disable=SC2034  # consumed by install-recommended-tools-global.sh
RTCM_SUPPORTED_HOSTS="claude codex cursor opencode hermes"
# shellcheck disable=SC2034  # consumed by install-recommended-tools-global.sh
RTCM_UNSUPPORTED_HOSTS="goose"

rtcm_dry_run() {
  [[ "${RTCM_DRY_RUN:-0}" == "1" ]]
}

rtcm_validate_host() {
  local host="${1:-}"
  case " ${RTCM_ALL_HOSTS} " in
    *" ${host} "*) return 0 ;;
    *) return 1 ;;
  esac
}

rtcm_host_status() {
  local host="${1:-}"
  case "$host" in
    goose) printf '%s' "unsupported" ;;
    hermes) printf '%s' "partial" ;;
    *) printf '%s' "supported" ;;
  esac
}

rtcm_backup_file() {
  local path="${1:-}"
  [[ -f "$path" ]] || return 0
  if rtcm_dry_run; then
    printf 'DRY-RUN: backup %s -> %s.bak\n' "$path" "$path"
    return 0
  fi
  cp -p "$path" "${path}.bak"
}

rtcm_host_config_present() {
  local host="${1:-}"
  case "$host" in
    claude) [[ -d "${HOME}/.claude" ]] ;;
    codex) [[ -f "${HOME}/.codex/config.toml" ]] || [[ -d "${HOME}/.codex" ]] ;;
    cursor) [[ -d "${HOME}/.cursor" ]] ;;
    opencode) [[ -f "${HOME}/.config/opencode/opencode.json" ]] || [[ -d "${HOME}/.config/opencode" ]] ;;
    hermes) [[ -f "${HOME}/.hermes/config.yaml" ]] || [[ -d "${HOME}/.hermes" ]] ;;
    goose) [[ -f "${HOME}/.config/goose/config.yaml" ]] || [[ -d "${HOME}/.pi/agent" ]] ;;
    *) return 1 ;;
  esac
}

rtcm_detect_configured_hosts() {
  local h
  for h in $RTCM_ALL_HOSTS; do
    rtcm_host_config_present "$h" && printf '%s\n' "$h"
  done
}

rtcm_doctor_platform() {
  local host="${1:-}"
  case "$host" in
    claude|codex|cursor|opencode) printf '%s' "$host" ;;
    hermes|goose) printf '%s' "" ;;
    *) printf '%s' "cursor" ;;
  esac
}

rtcm_log_unsupported() {
  local host="${1:-}"
  printf 'SKIP: %s — RTK and Context Mode have no upstream integration (see docs/rtk-cm/verification/%s-verify-rtk-cm.md)\n' \
    "$host" "$host"
}
