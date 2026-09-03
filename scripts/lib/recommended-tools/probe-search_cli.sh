# shellcheck shell=bash
# search-cli probe — PATH + non-secret version. Consent/registry pattern (not Cursor-only).
# Official pin (v0.9.0): https://github.com/paperfoot/search-cli/blob/v0.9.0/README.md@v0.9.0
# Formula: https://github.com/paperfoot/homebrew-tap/blob/main/Formula/search-cli.rb@0.9.0
# Health is PATH plus `search --version`. Provider-missing is WARN (ready + evidence).
# Do not dump provider secrets or API keys. Do not copy Alumnium Cursor-only rt_host_supported.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
if [[ -n "${RT_HOOKS_LIB:-}" && -f "${RT_HOOKS_LIB}/recommended-tools-registry.sh" ]]; then
  # shellcheck source=../../../hooks/lib/recommended-tools-registry.sh
  source "${RT_HOOKS_LIB}/recommended-tools-registry.sh"
fi

rt_search_cli_pin_version() {
  local pin
  pin="$(sb_recommended_tool_install_pin search_cli 2>/dev/null || true)"
  printf '%s' "$pin" | jq -r '.version // "0.9.0"'
}

rt_search_cli_pin_argv() {
  local pin
  pin="$(sb_recommended_tool_install_pin search_cli 2>/dev/null || true)"
  printf '%s' "$pin" | jq -r '.argv // empty'
}

rt_search_cli_parse_version() {
  local raw="${1:-}"
  printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true
}

rt_search_cli_version_int() {
  local v="${1%%-*}"
  local maj min patch
  IFS='.' read -r maj min patch <<<"$v"
  maj="${maj:-0}"; min="${min:-0}"; patch="${patch:-0}"
  printf '%d' $((10#$maj * 1000000 + 10#$min * 1000 + 10#$patch))
}

rt_search_cli_package_manager_supported() {
  [[ "${RT_SEARCH_CLI_FORCE_UNSUPPORTED:-0}" == "1" ]] && return 1
  [[ "$(uname -s)" == "Darwin" ]] || return 1
  command -v brew >/dev/null 2>&1
}

rt_probe_search_cli_cli() {
  command -v search >/dev/null 2>&1
}

rt_probe_search_cli_version() {
  local out
  out="$(search --version </dev/null 2>/dev/null || true)"
  rt_search_cli_parse_version "$out"
}

rt_probe_search_cli_providers() {
  # Non-secret: `search config check` lists which providers have a key set (README v0.9.0).
  # Never dump config secrets or API keys.
  local out
  out="$(search config check </dev/null 2>/dev/null || true)"
  if printf '%s' "$out" | grep -qiE '(:[[:space:]]*set\b|\bok\b|configured)'; then
    return 0
  fi
  return 1
}

rt_search_cli_project_install_commands() {
  local cfg
  cfg="$(rt_project_config)" || { printf ''; return 0; }
  [[ -n "$cfg" && -f "$cfg" ]] || { printf ''; return 0; }
  jq -r '.recommended_tools.search_cli.install_commands[]? // empty' "$cfg" 2>/dev/null \
    | paste -sd ' && ' -
}

rt_probe_search_cli() {
  local tool_id="search_cli" consent activation="none" canonical repairable=0
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0
  local installed_ver pin_ver

  consent="$(rt_consent_for "$tool_id")"
  # Extra-tool: Cursor + Claude + Codex. Do not mark unsupported via rt_host_supported.
  case "$consent" in
    disabled) fd=1 ;;
    pending|"") fp=1 ;;
    enabled)
      if rt_is_suspended "$tool_id"; then
        fs=1
      elif ! rt_probe_search_cli_cli; then
        evidence+=("missing_cli")
        if rt_search_cli_package_manager_supported; then
          frp=1
          repairable=1
        else
          ff=1
          evidence+=("unsupported_package_manager")
        fi
      else
        installed_ver="$(rt_probe_search_cli_version)"
        pin_ver="$(rt_search_cli_pin_version)"
        if [[ -z "$installed_ver" ]]; then
          ff=1
          evidence+=("version_unproved")
        else
          activation="full"
          fr=1
          if [[ "$(rt_search_cli_version_int "$installed_ver")" -lt "$(rt_search_cli_version_int "$pin_ver")" ]]; then
            evidence+=("version_drift")
            if rt_search_cli_package_manager_supported; then
              repairable=1
            else
              evidence+=("unsupported_package_manager")
            fi
          elif [[ "$(rt_search_cli_version_int "$installed_ver")" -gt "$(rt_search_cli_version_int "$pin_ver")" ]]; then
            evidence+=("version_drift")
            repairable=0
          fi
          if ! rt_probe_search_cli_providers; then
            evidence+=("provider_missing")
          fi
          if ! rt_search_cli_package_manager_supported; then
            if [[ " ${evidence[*]} " != *" unsupported_package_manager "* ]]; then
              evidence+=("unsupported_package_manager")
            fi
          fi
        fi
      fi
      ;;
  esac

  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_search_cli() {
  local actions=() failures=()
  local project_cmd pin_argv

  if ! rt_mutation_allowed search_cli; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi

  pin_argv="$(rt_search_cli_pin_argv)"
  project_cmd="$(rt_search_cli_project_install_commands)"
  if [[ -n "$project_cmd" && -n "$pin_argv" && "$project_cmd" != "$pin_argv" ]]; then
    jq -n '{actions:[],failures:["install_pin_mismatch"],restart_required:false}'
    return 0
  fi

  local installed_ver pin_ver
  installed_ver="$(rt_probe_search_cli_version)"
  pin_ver="$(rt_search_cli_pin_version)"
  if [[ -n "$installed_ver" && -n "$pin_ver" ]] \
    && [[ "$(rt_search_cli_version_int "$installed_ver")" -gt "$(rt_search_cli_version_int "$pin_ver")" ]]; then
    jq -n '{actions:[],failures:[],restart_required:false}'
    return 0
  fi

  if ! rt_search_cli_package_manager_supported; then
    jq -n '{actions:[],failures:["unsupported_package_manager"],restart_required:false}'
    return 0
  fi

  if [[ -z "$pin_argv" ]]; then
    jq -n '{actions:[],failures:["install_pin_missing"],restart_required:false}'
    return 0
  fi

  # Registry pin only — never execute project-local install_commands.
  # shellcheck disable=SC2086
  if bash -lc "$pin_argv" >&2; then
    actions+=("brew_install_search_cli_pin")
  else
    failures+=("brew_install_failed")
  fi

  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    '{actions:$actions,failures:$failures,restart_required:false}'
}
